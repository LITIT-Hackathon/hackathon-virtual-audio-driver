# Virtual Audio Driver

Create a working system-level virtual audio driver for Windows.

The solution should expose virtual audio endpoints allowing audio produced by
one application to be consumed by another application.

A working VB-CABLE driver package is provided as a technical reference for
analysis and reverse engineering.

## Provided

- VB-CABLE reference package
- Windows development environment with Visual Studio, Windows SDK and WDK
- GCP sandbox with token credit

## Deliverable

A working prototype demonstrated live.

The implementation must be your own.

## Windows Server 2025 test install

The ready-to-install test package is built for x64 Windows 11 build 22621+
and Windows Server 2025. Secure Boot must be disabled and `TESTSIGNING` must
already be enabled. Install the Windows SDK and WDK once so `devcon.exe` is
available, then run the following from an elevated PowerShell:

```powershell
git switch driver/mvp-cable
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\install-test-driver.ps1
```

The installer selects the newest `dist\LIT-Virtual-Audio-Cable-G*-x64-Debug.zip`,
imports its public test certificate, stages the complete componentized INF
graph, updates or creates `Root\LIT_VirtualAudioCable`, and enables the Windows
Audio services that are commonly disabled on Server images. A successful run
prints both endpoints:

- `LIT Virtual Cable Input` (playback/render)
- `LIT Virtual Cable Output` (recording/capture)

This is a test-signed hackathon package, not a production-signed driver.
