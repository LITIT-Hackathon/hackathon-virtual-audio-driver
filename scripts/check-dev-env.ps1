[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'
$problems = [System.Collections.Generic.List[string]]::new()

Write-Host 'LIT VAD development environment check'
Write-Host ('Windows: ' + [Environment]::OSVersion.VersionString)

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path $vswhere) {
    $installation = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($installation) {
        Write-Host "Visual Studio C++: $installation"
        $msbuild = Join-Path $installation 'MSBuild\Current\Bin\MSBuild.exe'
        Write-Host ("MSBuild: " + $(if (Test-Path $msbuild) { $msbuild } else { 'MISSING' }))
        if (-not (Test-Path $msbuild)) { $problems.Add('MSBuild was not found in the Visual Studio installation.') }
    } else {
        $problems.Add('Visual Studio with the x64 C++ toolchain was not found.')
    }
} else {
    $problems.Add('vswhere/Visual Studio was not found.')
}

$kitsRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'
$sdkVersions = if (Test-Path "$kitsRoot\Include") {
    Get-ChildItem "$kitsRoot\Include" -Directory | Select-Object -ExpandProperty Name
}
if ($sdkVersions) {
    Write-Host ('Windows SDK/WDK include versions: ' + ($sdkVersions -join ', '))
} else {
    $problems.Add('Windows SDK/WDK include directories were not found.')
}

$wdkTargets = Get-ChildItem "$kitsRoot\build" -Filter 'WindowsDriver.Common.targets' -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
Write-Host ("WDK MSBuild targets: " + $(if ($wdkTargets) { $wdkTargets } else { 'MISSING' }))
if (-not $wdkTargets) { $problems.Add('WDK MSBuild integration was not found.') }

foreach ($tool in 'git.exe', 'pnputil.exe') {
    $command = Get-Command $tool
    Write-Host ("${tool}: " + $(if ($command) { $command.Source } else { 'MISSING' }))
    if (-not $command) { $problems.Add("$tool was not found.") }
}

if ($problems.Count -gt 0) {
    Write-Host ''
    Write-Host 'BLOCKED:' -ForegroundColor Red
    $problems | ForEach-Object { Write-Host "- $_" }
    exit 1
}

Write-Host ''
Write-Host 'Environment prerequisites detected.' -ForegroundColor Green
exit 0
