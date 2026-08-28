[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$logFile = Join-Path $repoRoot 'testsigning-enable.log'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell session.'
}

& bcdedit.exe /set testsigning on 2>&1 | Tee-Object -FilePath $logFile
if ($LASTEXITCODE -ne 0) {
    throw "BCDEdit failed with exit code $LASTEXITCODE. The computer will not restart."
}

& shutdown.exe /r /t 15 /c 'LIT virtual audio driver test-signing restart'
if ($LASTEXITCODE -ne 0) {
    throw "Shutdown scheduling failed with exit code $LASTEXITCODE."
}

