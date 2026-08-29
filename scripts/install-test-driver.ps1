[CmdletBinding()]
param([string]$PackagePath)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$hardwareId = 'Root\LIT_VirtualAudioCable'
$logFile = Join-Path $repoRoot 'install-test-driver.log'

# A 32-bit PowerShell process is redirected away from the native System32
# directory. Sysnative provides access to the native Windows tools in that case.
$nativeSystemDirectory = if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Join-Path $env:WINDIR 'Sysnative'
} else {
    Join-Path $env:WINDIR 'System32'
}
$bcdedit = Join-Path $nativeSystemDirectory 'bcdedit.exe'
$certutil = Join-Path $nativeSystemDirectory 'certutil.exe'
$pnputil = Join-Path $nativeSystemDirectory 'pnputil.exe'

foreach ($requiredTool in $bcdedit, $certutil, $pnputil) {
    if (-not (Test-Path -LiteralPath $requiredTool)) {
        throw "Required Windows system tool was not found: $requiredTool"
    }
}

function Write-InstallLog {
    param([string]$Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line
    Add-Content -LiteralPath $logFile -Value $line
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell session.'
}

$testSigning = (& $bcdedit /enum '{current}' 2>&1 | Out-String)
if ($testSigning -notmatch '(?im)^testsigning\s+Yes\s*$') {
    throw 'TESTSIGNING is not enabled. Run scripts\enable-test-signing.ps1 as Administrator, then restart Windows.'
}

if (-not $PackagePath) {
    $packageZip = Get-ChildItem (Join-Path $repoRoot 'dist') -Filter 'LIT-Virtual-Audio-Cable-G*-x64-Debug.zip' -File |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $packageZip) { throw 'No LIT driver ZIP was found under dist.' }

    $extractRoot = Join-Path $env:TEMP 'LIT-Virtual-Audio-Cable-package'
    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
    Expand-Archive -LiteralPath $packageZip.FullName -DestinationPath $extractRoot -Force
    $PackagePath = $extractRoot
}

$packageDir = (Resolve-Path -LiteralPath $PackagePath).Path
$driverInf = Join-Path $packageDir 'ComponentizedAudioSample.inf'
if (-not (Test-Path -LiteralPath $driverInf)) {
    throw "Required driver INF was not found: $driverInf"
}

$devcon = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\Tools' -Filter devcon.exe -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\x64\\devcon\.exe$' } |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $devcon) {
    throw 'x64 devcon.exe was not found. Install the Windows Driver Kit (WDK), then rerun this script.'
}

Set-Content -LiteralPath $logFile -Value "LIT Virtual Audio Cable installation started $(Get-Date -Format o)"
Write-InstallLog "Package: $packageDir"
Write-InstallLog "DevCon: $devcon"

$certificate = Get-ChildItem -LiteralPath $packageDir -Filter '*.cer' -File -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($certificate) {
    Write-InstallLog "Importing public test certificate: $($certificate.Name)"
    foreach ($store in 'Root', 'TrustedPublisher') {
        & $certutil -addstore $store $certificate.FullName 2>&1 |
            Tee-Object -FilePath $logFile -Append
        if ($LASTEXITCODE -ne 0) { throw "Failed to import the test certificate into $store." }
    }
}

# Stage the entire component graph before creating/updating the root device.
foreach ($inf in Get-ChildItem -LiteralPath $packageDir -Filter '*.inf' -File) {
    Write-InstallLog "Staging $($inf.Name)"
    & $pnputil /add-driver $inf.FullName /install 2>&1 |
        Tee-Object -FilePath $logFile -Append
    if ($LASTEXITCODE -ne 0) { throw "PnPUtil failed while staging $($inf.Name)." }
}

$existingOutput = & $devcon findall $hardwareId 2>&1 | Out-String
if ($existingOutput -match '(?i)LIT Virtual Audio Cable|ROOT\\MEDIA') {
    Write-InstallLog 'Updating the existing LIT virtual audio device.'
    & $devcon update $driverInf $hardwareId 2>&1 | Tee-Object -FilePath $logFile -Append
} else {
    Write-InstallLog 'Creating the LIT virtual audio root device.'
    & $devcon install $driverInf $hardwareId 2>&1 | Tee-Object -FilePath $logFile -Append
}
if ($LASTEXITCODE -ne 0) { throw 'DevCon failed to install or update the LIT virtual audio device.' }

# Windows Server can keep these services disabled. The MEDIA adapter may then
# report Started while no MMDEVAPI AudioEndpoint devices exist.
foreach ($serviceName in 'AudioEndpointBuilder', 'Audiosrv') {
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    Set-Service -Name $serviceName -StartupType Automatic
    if ($service.Status -ne 'Running') { Start-Service -Name $serviceName }
    Write-InstallLog "$serviceName is running and configured for automatic startup."
}

& $pnputil /scan-devices 2>&1 | Tee-Object -FilePath $logFile -Append
Start-Sleep -Seconds 5

$device = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -eq 'LIT Virtual Audio Cable' } |
    Select-Object -First 1
$endpoints = Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction SilentlyContinue |
    # Windows commonly prefixes endpoint names with "Speakers" or "Microphone",
    # for example: "Speakers (LIT Virtual Cable Input)".
    Where-Object { $_.FriendlyName -like '*LIT Virtual Cable*' }

Write-InstallLog "Adapter status: $(if ($device) { $device.Status } else { 'NOT FOUND' })"
if ($endpoints) {
    Write-InstallLog 'LIT audio endpoints:'
    $endpoints | Format-Table Status, FriendlyName, InstanceId -AutoSize |
        Out-String | Tee-Object -FilePath $logFile -Append | Write-Host
    Write-Host 'Installation succeeded.' -ForegroundColor Green
    exit 0
}

Write-InstallLog 'No LIT AudioEndpoint devices were enumerated.'
Get-Service AudioEndpointBuilder, Audiosrv |
    Format-Table Name, Status, StartType -AutoSize |
    Out-String | Tee-Object -FilePath $logFile -Append | Write-Host
throw "The adapter installed, but its audio endpoints were not enumerated. See $logFile"
