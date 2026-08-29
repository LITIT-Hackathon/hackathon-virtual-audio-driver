[CmdletBinding()]
param(
    # Folder obtained by extracting dist\LIT-Virtual-Audio-Cable-G2-x64-Debug.zip.
    [Parameter(Mandatory)] [string] $PackageDirectory,
    [string] $DevConPath
)

$ErrorActionPreference = 'Stop'

$packageDir = (Resolve-Path -LiteralPath $PackageDirectory -ErrorAction Stop).Path
$driverInf = Join-Path $packageDir 'ComponentizedAudioSample.inf'
$hardwareId = 'Root\LIT_VirtualAudioCable'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell session.'
}

foreach ($requiredFile in @(
    $driverInf,
    (Join-Path $packageDir 'LITVirtualAudioCable.sys'),
    (Join-Path $packageDir 'litvirtualaudiocable.cat'),
    (Join-Path $packageDir 'ComponentizedApoSample.inf'),
    (Join-Path $packageDir 'ComponentizedAudioSampleExtension.inf')
)) {
    if (-not (Test-Path -LiteralPath $requiredFile)) {
        throw "Required file not found: $requiredFile"
    }
}

if (-not $DevConPath) {
    $DevConPath = @(Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\Tools' -Filter devcon.exe -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\x64\\devcon\.exe$' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName)
}
if (-not $DevConPath -or -not (Test-Path -LiteralPath $DevConPath -PathType Leaf)) {
    throw 'DevCon x64 was not found. Install the Windows Driver Kit or pass -DevConPath with the full path to devcon.exe.'
}

Write-Host 'Certificate-free demo install: no certificate is added to Root or TrustedPublisher.' -ForegroundColor Cyan
Write-Host 'This works only in the current Windows session after Advanced startup > Startup Settings > press 7/F7 (Disable driver signature enforcement).' -ForegroundColor Yellow
Write-Host 'Do not use TESTSIGNING and do not change Secure Boot or BitLocker for this path.' -ForegroundColor Yellow

& $DevConPath install $driverInf $hardwareId
if ($LASTEXITCODE -ne 0) { throw 'DevCon failed to install the LIT virtual audio device. Verify that this session was started with F7 driver-signature enforcement disabled.' }

& pnputil.exe /enum-devices /deviceid $hardwareId /drivers
if ($LASTEXITCODE -ne 0) { throw 'PnPUtil could not enumerate the LIT virtual audio device after installation.' }

