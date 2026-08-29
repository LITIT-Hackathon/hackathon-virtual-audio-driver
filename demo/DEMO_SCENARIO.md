# LIT Virtual Audio Cable — Live Hackathon Demo Scenario

## Demo objective

In three minutes, prove that our Windows kernel-mode virtual audio driver:

1. installs as a LIT-owned device;
2. exposes one playback endpoint and one recording endpoint;
3. transfers PCM audio from a source application to a receiving application;
4. stops transferring audio when the source stops.

The signal path demonstrated on screen is:

```text
48 kHz stereo audio source
  -> Speakers (LIT Virtual Audio Cable)
  -> LIT WaveRT driver and ring buffer
  -> LIT Virtual Cable Output (LIT Virtual Audio Cable)
  -> OBS audio meter
```

## Roles

- **Presenter:** explains the problem, architecture, and result.
- **Operator:** changes Windows and OBS settings, starts and stops the audio.

One person can perform both roles, but two people make the demo smoother.

## Required environment

- Windows 11 x64 or Windows Server 2025 x64.
- Secure Boot disabled.
- Windows test-signing mode enabled.
- G4 package installed with the repository installer.
- A known 48 kHz stereo WAV file ready to play.
- OBS installed with an `Audio Input Capture` source ready to configure.
- A local backup video of a successful 30–60 second run.

When presenting through Remote Desktop, configure the connection before logging
in:

```text
Remote Desktop Connection
  -> Show Options
  -> Local Resources
  -> Remote audio / Settings
  -> Play on remote computer
```

The equivalent RDP property is:

```text
audiomode:i:1
```

Without this setting, the RDP session can expose only `Remote Audio` and hide
the local LIT endpoints even though the kernel driver is running.

## Preparation — 15 minutes before presenting

Do not rebuild or modify the driver during this period.

1. Connect using the correct RDP audio setting, if applicable.
2. Open an elevated PowerShell in the repository.
3. Run a clean install only if the known-good driver is not already installed:

   ```powershell
   powershell -ExecutionPolicy Bypass `
     -File .\scripts\install-test-driver.ps1 `
     -CleanInstall
   ```

4. Confirm the adapter and endpoints:

   ```powershell
   pnputil /enum-devices /instanceid "ROOT\MEDIA\0000"
   pnputil /enum-devices /class AudioEndpoint
   ```

5. Confirm that both of these report `Status: Started`:

   ```text
   Speakers (LIT Virtual Audio Cable)
   LIT Virtual Cable Output (LIT Virtual Audio Cable)
   ```

6. Open `mmsys.cpl` and leave it on the Playback tab.
7. Open OBS and prepare an `Audio Input Capture` source.
8. Open the 48 kHz stereo test WAV, but do not start playback.
9. Close notification windows and unrelated applications.
10. Perform one full rehearsal and confirm that the OBS meter moves for at
    least 30 seconds.

If step 10 fails, use the troubleshooting section before the presentation. Do
not improvise driver installation while judges are watching.

## Three-minute live script

### 0:00–0:25 — Problem and result

**Presenter says:**

> Applications normally cannot directly expose their output as another
> application's microphone. We built a Windows virtual audio cable that adds
> two system audio endpoints: an application plays into one endpoint, and a
> second application records the same PCM stream from the other.

Show the project title or the architecture diagram. Do not begin with source
code or installation logs.

### 0:25–0:55 — Prove that Windows recognizes our driver

In `mmsys.cpl`, show the Playback tab and point to:

```text
Speakers (LIT Virtual Audio Cable)
```

Switch to the Recording tab and point to:

```text
LIT Virtual Cable Output (LIT Virtual Audio Cable)
```

**Presenter says:**

> These are not application-level simulated devices. Windows created them from
> our test-signed kernel driver. The playback side accepts audio, and the
> recording side exposes the routed stream to standard WASAPI applications.

Optionally show Device Manager for no more than five seconds to confirm that
`LIT Virtual Audio Cable` has no warning icon.

### 0:55–1:20 — Configure the source

Set the test player or browser output to:

```text
Speakers (LIT Virtual Audio Cable)
```

Keep playback paused.

**Presenter says:**

> The source will send 48 kHz stereo PCM frames to our virtual render endpoint.
> There is no physical speaker in this path.

### 1:20–1:45 — Configure the receiver

In OBS, add or open `Audio Input Capture` and select:

```text
LIT Virtual Cable Output (LIT Virtual Audio Cable)
```

Make sure the OBS meter is visible and currently still.

**Presenter says:**

> OBS is an independent application. It sees the other side of our driver as a
> normal Windows recording device.

### 1:45–2:20 — Demonstrate live transfer

Start the test WAV. Let it play for 15–20 seconds while the audience watches
the OBS meter.

**Presenter says:**

> The moving meter is the end-to-end proof. The source writes frames into our
> WaveRT render stream, our fixed-size ring buffer transfers them in kernel
> space, and the capture stream delivers them to OBS.

Do not talk over the key visual moment. Leave the meter clearly visible.

### 2:20–2:35 — Prove causality

Stop or pause the test WAV. Wait for the OBS meter to return to silence.

**Presenter says:**

> When the source stops, the buffer drains and the capture side returns silence.
> That confirms the meter was driven by the source through our cable, not by an
> unrelated microphone.

### 2:35–3:00 — Technical summary and honest scope

Show the compact architecture diagram.

**Presenter says:**

> We used Microsoft's SysVAD infrastructure for the standard PortCls and
> WaveRT foundation, then added our own LIT identity, endpoint configuration,
> and minimal render-to-capture data path. This hackathon build supports one
> route at 48 kHz stereo. It is test-signed and intentionally not presented as
> a production driver.

Finish on the working OBS meter or the two endpoint names, not on a terminal.

## Questions the judges are likely to ask

### Is this your own implementation?

> Yes. We used Microsoft SysVAD as the documented driver foundation and wrote
> our product identity and minimal routing path. VB-CABLE was used only as a
> behavioral reference; we did not copy its binaries, INF identifiers, GUIDs,
> or implementation.

### Why use a kernel driver?

> A kernel audio driver makes both sides appear as standard Windows system
> endpoints. Existing applications can use them through WASAPI without a
> custom plugin or integration.

### What happens on underrun or overflow?

> Capture underrun produces silence. On overflow, the oldest complete frames
> are discarded so the path keeps the newest audio and never blocks inside an
> audio callback.

### What formats are supported?

> The prototype is deliberately fixed to 48 kHz, 16-bit, stereo PCM. Format
> conversion, resampling, multiple cables, and a routing UI are future work.

### Is it production ready?

> No. It is a test-signed x64 prototype. Production work would require proper
> Microsoft driver signing, broader compatibility testing, latency and drift
> measurement, power-state testing, and a production installer.

### Why did the endpoints initially disappear on Windows Server?

> The driver and Kernel Streaming interfaces were running, but the RDP session
> redirected audio to `Remote Audio`. Reconnecting with `Play on remote
> computer` allowed Windows to activate both local LIT MMDevice endpoints. We
> also improved the installer so it restarts the audio endpoint services and
> reports phantom MMDevice state explicitly.

## Troubleshooting before the demo

### Only `Remote Audio` is visible

Disconnect and reconnect with `Remote audio -> Play on remote computer`, or
set `audiomode:i:1` in the RDP file. This requires a new RDP session; changing
it after login is not enough.

### Adapter is started but the endpoints are missing

Run the installer from elevated PowerShell with `-CleanInstall`, then inspect:

```text
install-test-driver.log
```

The installer now distinguishes a missing kernel adapter from MMDevice records
whose `SWD\MMDEVAPI` PnP nodes are not present.

### Endpoints exist but OBS is silent

Check, in this order:

1. The source output is `Speakers (LIT Virtual Audio Cable)`.
2. OBS input is `LIT Virtual Cable Output (LIT Virtual Audio Cable)`.
3. The source file is 48 kHz, 16-bit, stereo PCM.
4. The source is not muted in Windows Volume Mixer.
5. The OBS source is not muted and its meter is visible.
6. Restart the source and OBS once; do not reinstall the driver immediately.

## Fallback presentation

Keep a local 30–60 second recording of the complete successful flow. If the
live environment fails:

1. Spend no more than 20 seconds confirming the failure.
2. State that the backup was recorded from the same build and machine.
3. Play the backup video.
4. Show the installed LIT adapter and the source files afterward.

Do not substitute another vendor's cable while implying that it is the LIT
runtime. Do not claim production signing, broad format support, or completion
of features outside the demonstrated one-cable path.

## Final go/no-go checklist

- [ ] Correct RDP audio mode or a local console session is in use.
- [ ] LIT adapter status is `Started` with no Device Manager warning.
- [ ] Both LIT AudioEndpoint devices report `Started`.
- [ ] Playback endpoint is selected by the source application.
- [ ] Capture endpoint is selected by OBS.
- [ ] Known 48 kHz stereo WAV is ready.
- [ ] OBS meter moves continuously for at least 30 seconds in rehearsal.
- [ ] Stopping the source makes the meter return to silence.
- [ ] Known-good package and commit are recorded.
- [ ] Backup video plays locally without network access.
