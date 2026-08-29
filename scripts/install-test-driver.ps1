[CmdletBinding()]
param(
    [string]$PackagePath,
    [switch]$CleanInstall
)

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
    $pnpOutput = & $pnputil /add-driver $inf.FullName /install 2>&1
    $pnpExitCode = $LASTEXITCODE
    $pnpOutput | Tee-Object -FilePath $logFile -Append

    # Some Windows Server builds return a non-zero code when the package is
    # already present even though PnPUtil reports that it is installed and
    # up-to-date. Treat that idempotent result as success.
    $pnpText = $pnpOutput | Out-String
    $alreadyInstalled = $pnpText -match '(?i)driver package added successfully' -and
        $pnpText -match '(?i)already exists|up-to-date'
    if ($pnpExitCode -ne 0 -and -not $alreadyInstalled) {
        throw "PnPUtil failed while staging $($inf.Name) (exit code $pnpExitCode)."
    }
    if ($pnpExitCode -ne 0) {
        Write-InstallLog "PnPUtil exit code $pnpExitCode accepted because the package is already installed and up-to-date."
    }
}

$existingOutput = & $devcon findall $hardwareId 2>&1 | Out-String
if ($CleanInstall -and $existingOutput -match '(?i)LIT Virtual Audio Cable|ROOT\\MEDIA') {
    Write-InstallLog 'Removing the existing LIT root device for a clean interface re-enumeration.'
    & $devcon remove $hardwareId 2>&1 | Tee-Object -FilePath $logFile -Append
    if ($LASTEXITCODE -ne 0) { throw 'DevCon failed to remove the existing LIT virtual audio device.' }
    & $pnputil /scan-devices 2>&1 | Tee-Object -FilePath $logFile -Append
    Start-Sleep -Seconds 2
    $existingOutput = ''
}

if ($existingOutput -match '(?i)LIT Virtual Audio Cable|ROOT\\MEDIA') {
    Write-InstallLog 'Updating the existing LIT virtual audio device.'
    & $devcon update $driverInf $hardwareId 2>&1 | Tee-Object -FilePath $logFile -Append
} else {
    Write-InstallLog 'Creating the LIT virtual audio root device.'
    & $devcon install $driverInf $hardwareId 2>&1 | Tee-Object -FilePath $logFile -Append
}
if ($LASTEXITCODE -ne 0) { throw 'DevCon failed to install or update the LIT virtual audio device.' }

# Windows Server can keep these services disabled. In addition, removing and
# recreating a root MEDIA device can leave its SWD\MMDEVAPI children registered
# but not present. Restart the complete audio service stack after the KS
# interfaces exist so AudioEndpointBuilder performs a fresh discovery pass.
foreach ($serviceName in 'AudioEndpointBuilder', 'Audiosrv') {
    Set-Service -Name $serviceName -StartupType Automatic
}

$audioService = Get-Service -Name Audiosrv -ErrorAction Stop
if ($audioService.Status -ne 'Stopped') {
    Write-InstallLog 'Stopping Windows Audio before rebuilding MMDEVAPI endpoints.'
    Stop-Service -Name Audiosrv -Force -ErrorAction Stop
}

$endpointBuilder = Get-Service -Name AudioEndpointBuilder -ErrorAction Stop
if ($endpointBuilder.Status -ne 'Stopped') {
    Write-InstallLog 'Restarting Audio Endpoint Builder for a fresh endpoint discovery pass.'
    Stop-Service -Name AudioEndpointBuilder -Force -ErrorAction Stop
}

Start-Service -Name AudioEndpointBuilder -ErrorAction Stop
Start-Service -Name Audiosrv -ErrorAction Stop
Write-InstallLog 'AudioEndpointBuilder and Audiosrv are running and configured for automatic startup.'

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
$mmDeviceRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio'
$registeredEndpoints = foreach ($flow in 'Render', 'Capture') {
    Get-ChildItem -LiteralPath (Join-Path $mmDeviceRoot $flow) -ErrorAction SilentlyContinue |
        Where-Object {
            (Get-ItemProperty -LiteralPath (Join-Path $_.PSPath 'Properties') -ErrorAction SilentlyContinue).PSObject.Properties.Value -like '*LIT Virtual*'
        } |
        ForEach-Object { [pscustomobject]@{ Flow = $flow; EndpointId = $_.PSChildName } }
}
if ($registeredEndpoints) {
    Write-InstallLog 'MMDEVAPI records exist, but their AudioEndpoint PnP nodes are not present:'
    $registeredEndpoints | Format-Table -AutoSize |
        Out-String | Tee-Object -FilePath $logFile -Append | Write-Host
}
Get-Service AudioEndpointBuilder, Audiosrv |
    Format-Table Name, Status, StartType -AutoSize |
    Out-String | Tee-Object -FilePath $logFile -Append | Write-Host
throw "The adapter installed, but its audio endpoints were not enumerated. See $logFile"
