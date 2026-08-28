[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$packageDir = Join-Path $repoRoot 'src\driver\Package\x64\Debug\package'
$certificate = Join-Path $repoRoot 'src\driver\Package\x64\Debug\package.cer'
$driverInf = Join-Path $packageDir 'ComponentizedAudioSample.inf'
$devcon = 'C:\Program Files (x86)\Windows Kits\10\Tools\10.0.28000.0\x64\devcon.exe'
$logFile = Join-Path $repoRoot 'install-test-driver.log'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell session.'
}

foreach ($requiredFile in @($certificate, $driverInf, $devcon)) {
    if (-not (Test-Path -LiteralPath $requiredFile)) {
        throw "Required file not found: $requiredFile"
    }
}

& certutil.exe -addstore Root $certificate 2>&1 | Tee-Object -FilePath $logFile
if ($LASTEXITCODE -ne 0) { throw 'Failed to add the WDK certificate to Root.' }

& certutil.exe -addstore TrustedPublisher $certificate 2>&1 | Tee-Object -FilePath $logFile -Append
if ($LASTEXITCODE -ne 0) { throw 'Failed to add the WDK certificate to TrustedPublisher.' }

& $devcon install $driverInf 'Root\LIT_VirtualAudioCable' 2>&1 | Tee-Object -FilePath $logFile -Append
if ($LASTEXITCODE -ne 0) { throw 'DevCon failed to install the LIT virtual audio device.' }

& pnputil.exe /enum-devices /deviceid 'Root\LIT_VirtualAudioCable' /drivers 2>&1 |
    Tee-Object -FilePath $logFile -Append

