[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    [string]$Generation = 'G3',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $SkipBuild) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $msbuild = if (Test-Path -LiteralPath $vswhere) {
        & $vswhere -all -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath |
            ForEach-Object { Join-Path $_ 'MSBuild\Current\Bin\MSBuild.exe' } |
            Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1
    }
    if (-not $msbuild) { throw 'MSBuild with the Visual C++ x64 toolchain was not found.' }

    $commonProject = Join-Path $repoRoot 'src\driver\EndpointsCommon\EndpointsCommon.vcxproj'
    $packageProject = Join-Path $repoRoot 'src\driver\Package\package.vcxproj'

    # Package.vcxproj does not declare EndpointsCommon as a ProjectReference even
    # though the kernel driver links EndpointsCommon.lib, so build it explicitly.
    & $msbuild $commonProject /t:Rebuild "/p:Configuration=$Configuration" /p:Platform=x64 `
        /p:SpectreMitigation=false /verbosity:minimal
    if ($LASTEXITCODE -ne 0) { throw "EndpointsCommon build failed with exit code $LASTEXITCODE." }

    # Spectre libraries are not part of the minimal hackathon toolchain. This is a
    # test-only build setting and must not be used for a production driver.
    & $msbuild $packageProject /t:Rebuild "/p:Configuration=$Configuration" /p:Platform=x64 `
        /p:SpectreMitigation=false /p:ApiValidator_Enable=false `
        /p:SkipPackageVerification=true /p:Inf2CatUseLocalTime=true /verbosity:minimal
    if ($LASTEXITCODE -ne 0) { throw "Driver package build failed with exit code $LASTEXITCODE." }
}

$outputRoot = Join-Path $repoRoot "src\driver\Package\x64\$Configuration"
$packageDir = Join-Path $outputRoot 'package'
$certificate = Join-Path $outputRoot 'package.cer'
$required = @(
    'LITVirtualAudioCable.sys',
    'ComponentizedAudioSample.inf',
    'ComponentizedAudioSampleExtension.inf',
    'ComponentizedApoSample.inf',
    'litvirtualaudiocable.cat'
)
foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $packageDir $name))) {
        throw "Build output is incomplete; missing $name"
    }
}

$stageRoot = Join-Path $env:TEMP "LIT-Virtual-Audio-Cable-$Generation-x64-$Configuration"
if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
New-Item -ItemType Directory -Path $stageRoot | Out-Null
Get-ChildItem -LiteralPath $packageDir -File | Copy-Item -Destination $stageRoot
if (Test-Path -LiteralPath $certificate) {
    Copy-Item -LiteralPath $certificate -Destination (Join-Path $stageRoot 'LITVirtualAudioCable-Test.cer')
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install-test-driver.ps1') -Destination $stageRoot

$notes = @"
LIT Virtual Audio Cable - $Generation x64 $Configuration

Target: Windows 11 build 22621+ or Windows Server 2025.
Hardware ID: Root\LIT_VirtualAudioCable
Format: 48 kHz, 16-bit, stereo PCM

Install from an elevated PowerShell in the repository:
  powershell -ExecutionPolicy Bypass -File .\scripts\install-test-driver.ps1

The installer stages every INF in the component graph, updates an existing
device when present, and enables the Windows Audio services required on Server.
This is a test-signed hackathon build, not a production driver.
"@
Set-Content -LiteralPath (Join-Path $stageRoot 'PACKAGE-NOTES.txt') -Value $notes

$distDir = Join-Path $repoRoot 'dist'
$zipPath = Join-Path $distDir "LIT-Virtual-Audio-Cable-$Generation-x64-$Configuration.zip"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $stageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Created $zipPath" -ForegroundColor Green
