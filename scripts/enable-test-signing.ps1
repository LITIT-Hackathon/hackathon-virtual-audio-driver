[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$logFile = Join-Path $repoRoot 'testsigning-enable.log'

$nativeSystemDirectory = if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Join-Path $env:WINDIR 'Sysnative'
} else {
    Join-Path $env:WINDIR 'System32'
}
$bcdedit = Join-Path $nativeSystemDirectory 'bcdedit.exe'
$shutdown = Join-Path $nativeSystemDirectory 'shutdown.exe'

foreach ($requiredTool in $bcdedit, $shutdown) {
    if (-not (Test-Path -LiteralPath $requiredTool)) {
        throw "Required Windows system tool was not found: $requiredTool"
    }
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell session.'
}

& $bcdedit /set testsigning on 2>&1 | Tee-Object -FilePath $logFile
if ($LASTEXITCODE -ne 0) {
    throw "BCDEdit failed with exit code $LASTEXITCODE. The computer will not restart."
}

& $shutdown /r /t 15 /c 'LIT virtual audio driver test-signing restart'
if ($LASTEXITCODE -ne 0) {
    throw "Shutdown scheduling failed with exit code $LASTEXITCODE."
}

