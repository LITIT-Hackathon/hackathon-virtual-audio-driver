# SysVAD G1 baseline build

## Environment

- Visual Studio Community 2026 18.9
- MSBuild 18.9
- Windows SDK 10.0.28000.0
- Windows Driver Kit 10.0.28000.2526
- Configuration: `Debug|x64`

## Build

Run from the repository root in an elevated shell:

```powershell
& "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe" `
  src\driver\Package\package.vcxproj `
  /t:Build `
  /p:Configuration=Debug `
  /p:Platform=x64 `
  /p:ApiValidator_Enable=false `
  /p:SkipPackageVerification=true `
  /p:Inf2CatUseLocalTime=true `
  /verbosity:minimal
```

`Inf2CatUseLocalTime` prevents a false future-date failure around the local
midnight/UTC boundary. The two verification properties work around missing x86
validation payloads in this WDK installation; they do not disable compilation,
INF stamping, catalog generation, or test signing. They are acceptable only for
the hackathon baseline and must not be used to claim production validation.

## G1 output

The package is generated at:

```text
src\driver\Package\x64\Debug\package\
```

It contains the required baseline artifacts:

- `TabletAudioSample.sys`
- `ComponentizedAudioSample.inf` plus extension/APO INF files
- `sysvad.cat`
- the upstream APO and keyword detector DLLs

This is the unchanged Microsoft SysVAD baseline. It does not yet use LIT
identifiers and does not yet route render samples to capture samples.
