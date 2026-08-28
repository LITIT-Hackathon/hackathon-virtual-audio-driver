# Virtual Audio Device (VAD): Matrix Analysis and Windows Delivery Plan

## Scope and terminology

In this document, **VAD** means a *Virtual Audio Device*, not voice-activity
detection. The proposed product is a Windows virtual cable/matrix that lets an
application send audio to a virtual playback endpoint and lets another
application receive that audio from a virtual recording endpoint.

This is a clean-room design. The supplied VB-Audio package is useful for
observing Windows-visible behaviour only; do not reuse its binaries, INF,
identifiers, endpoint names, or implementation.

## What the supplied Matrix/CABLE material tells us

### Evidence observed locally

| Category | Observation | Design implication |
| --- | --- | --- |
| Package | `VBAudioMatrix_Setup_v1026 1.zip` contains a single setup executable; no source is included. | Treat it as an installer-level behavioural reference only. |
| Driver | The installed CABLE reference uses a `ROOT\\MEDIA` device, a MEDIA-class driver and a signed catalog. | Our driver should use its own root-enumerated hardware ID and MEDIA-class INF. |
| Endpoints | The active configuration exposes a capture endpoint and two render endpoints, including a 16-channel render endpoint. | A matrix can expose more than one logical endpoint; the MVP must expose only one render/capture pair. |
| Health | One `ROOT\\MEDIA` instance is healthy while two older instances report Code 10; phantom MMDevice endpoints remain. | Upgrade/uninstall must be an explicit product requirement, with unique device identity and removal tests. |

### Behavioural model to emulate at a high level

```text
Application render stream
        -> VAD Virtual Input (playback endpoint)
        -> shared route buffer / routing matrix
        -> VAD Virtual Output (recording endpoint)
        -> consuming application
```

Windows deliberately gives the two ends opposite names from the application's
point of view: an application **renders to** the virtual input and another
application **captures from** the virtual output.

## Product categories

| Category | MVP | Later matrix capability |
| --- | --- | --- |
| Endpoints | One stereo render endpoint and one stereo capture endpoint | Multiple buses, per-bus channel layouts, physical-device outputs |
| Routing | Fixed `Input -> Output` route | N x M route matrix with gains, mute and solo |
| Format handling | PCM 16-bit/24-bit/32-bit float, 48 kHz stereo as the preferred internal format | Resampling, channel mapping and per-route format policies |
| Timing | Bounded ring buffer, silence on underrun, bounded latency | Drift correction, clock domains, metering and latency compensation |
| Control plane | A small local configuration app: device state, latency and diagnostics | Route editor, presets, hotkeys, public local API |
| Observability | ETW/logs, buffer overrun/underrun counters, version/health page | Per-route meters, performance history, crash telemetry with consent |
| Security | Least-privileged UI, local-only IPC with ACLs, no arbitrary driver IOCTL surface | Signed updates and policy-managed enterprise configuration |

## Recommended technical structure

### 1. Kernel-mode audio endpoint driver

Start from Microsoft's **SysVAD** sample architecture and retain only the
pieces needed for a root-enumerated WaveRT virtual device.

Responsibilities:

- enumerate `VAD Virtual Input` (render) and `VAD Virtual Output` (capture);
- advertise a deliberately small, tested set of formats;
- receive render packets and satisfy capture packets without blocking;
- expose endpoint properties and power/PnP lifecycle correctly;
- never perform UI, file, network, allocations, or heavyweight DSP on the
  real-time audio path.

The shared routing state belongs in a driver-owned `RouteEngine` object. It is
created with the adapter, destroyed with it, and is accessed by both pins under
short real-time-safe synchronization. Do not use the application's process
memory as the audio bridge.

### 2. Real-time route engine

Use a preallocated, interleaved PCM ring buffer with monotonic read/write
cursors. A safe first version has exactly one writer (render) and one reader
(capture). Each audio-period operation must be bounded and allocation-free.

```text
render callback -> validate/convert -> ring-buffer write -> advance write cursor
capture callback -> ring-buffer read or silence -> advance read cursor
```

Rules:

- Make buffer length configurable only within safe limits; begin with about
  40–100 ms and tune from actual glitch measurements.
- On overflow, discard the oldest complete frames and increment an overrun
  counter. On underrun, return silence and increment an underrun counter.
- Frame alignment, channel count and sample rate are part of every route
  contract; never reinterpret bytes as another format.
- Keep a single 48 kHz stereo float internal representation if conversion is
  needed. For the hackathon MVP, restricting both endpoints to matching PCM
  formats is simpler and lower risk.

### 3. User-mode control application

This is a normal signed desktop app, separate from the driver. It uses standard
Windows audio-device APIs to display endpoint status and a narrowly scoped,
versioned IOCTL or service interface for configuration.

Its responsibilities are configuration, diagnostics and user education—not
audio sample transport. It must tolerate the driver being absent, disabled or
being upgraded.

### 4. Installer and lifecycle layer

The driver package installs the root device and its driver. The product installer
then installs the control application, invokes the supported device-install
flow with elevation, and verifies that both endpoints appear. Uninstall must
stop/remove the root device, uninstall the matching package, and leave no
duplicate endpoints.

Use product-owned identifiers, for example:

```text
Root hardware ID: ROOT\\LITVAD
Driver service:    LitVadAudio
Render endpoint:   LIT Virtual Input
Capture endpoint:  LIT Virtual Output
```

The final identifiers should be registered and treated as compatibility
contracts; do not change them between ordinary upgrades.

## Milestones and acceptance checks

| Phase | Deliverable | Acceptance check |
| --- | --- | --- |
| P0: enumerate | Root device + two endpoints | Both appear once in Windows Sound settings after reboot. |
| P1: cable | Fixed render-to-capture buffer | A WAV player routed to Virtual Input moves the OBS meter on Virtual Output. |
| P2: resilience | Buffer policy, counters, PnP and uninstall | Repeated start/stop and install/upgrade/uninstall leave no Code 10 or duplicate endpoints. |
| P3: control | Status/diagnostics application | It reports endpoint state and under/overruns without needing administrator rights after install. |
| P4: matrix | Explicit N x M route configuration | Each enabled route has tested gain, channel-map and latency behaviour. |
| P5: release | Signed package, installer, regression suite | Fresh installation succeeds on each supported Windows build with Secure Boot enabled. |

## Two-person delivery plan

Split the work by boundary: one person owns the real-time driver path, while
the other owns the test, install and demonstration path. Neither person should
wait for a full matrix implementation.

| Person | Primary responsibility | Concrete tasks | Definition of done |
| --- | --- | --- | --- |
| **A — driver** | Virtual device and audio path | Build SysVAD; define product-owned INF/device IDs; expose one render and one capture endpoint; implement the fixed render-to-capture ring buffer; handle silence/overflow; fix PnP failures. | Windows shows exactly one `LIT Virtual Input` and one `LIT Virtual Output`, and a render stream is readable on capture. |
| **B — test, install and demo** | Reproducible user experience | Prepare the WDK test machine; create the install/uninstall flow; validate Sound settings and OBS; collect logs/counters; write demo instructions and presentation; test fresh install and cleanup. | A fresh test-machine install reaches OBS, the OBS meter moves, and the documented demo can be repeated. |

### Shared checkpoint

After roughly 3–4 hours, both people validate only one thing: both endpoints
must appear exactly once in Windows Sound settings. If they do not, pause
feature work and jointly resolve build, INF, signing or PnP installation
problems. A working endpoint pair is the prerequisite for every later task.

## Simplified hackathon scope

The fastest credible result is a **virtual cable**, not a complete audio
matrix. Implement this fixed path first:

```text
YouTube / test WAV -> LIT Virtual Input -> ring buffer -> LIT Virtual Output -> OBS
```

### Keep

- one stereo playback endpoint and one stereo recording endpoint;
- one fixed `Input -> Output` route;
- 48 kHz stereo PCM/float only for the first demo;
- one preallocated ring buffer;
- silence on underrun, discard-oldest frames on overflow, and two counters;
- Windows Sound settings and OBS as the demonstration UI.

### Defer

- multi-bus routing matrix and additional virtual cables;
- a mixer UI, presets, hotkeys and per-application automatic routing;
- DSP, APOs, effects, equalizer and noise suppression;
- format resampling, 16-channel support and advanced channel maps;
- network audio and physical-device mirroring;
- production-grade installer polish until the cable works.

### Simplified release sequence

1. **Hackathon demo:** test-signed driver on one prepared test machine.
2. **Pilot:** Microsoft attestation-signed driver for controlled test users.
3. **Public release:** HLK-tested, Microsoft-signed driver, with the control
   application supplied through a signed installer or MSIX and the driver
   published through Windows Update where applicable.

## Making it available on Windows

### Supported-product path

1. **Target Windows 10 (supported releases) and Windows 11, x64 first.** Keep
   the initial driver package small and Universal/Declarative where the chosen
   WDK model permits it. Arm64 support should be a separately tested build,
   not an unverified checkbox.
2. **Build and test with Visual Studio, the Windows SDK and WDK.** SysVAD is a
   virtual WaveRT audio reference, so it is the most appropriate starting
   point—not a VB installer or reverse-engineered driver.
3. **Development distribution:** use a test-signed build only on isolated test
   machines. Never ask normal users to disable Secure Boot or enable test
   signing.
4. **Pre-release distribution:** submit the complete driver package to the
   Windows Hardware Developer Center for Microsoft attestation signing. This
   permits Secure-Boot-enabled pilot systems, but it is not certification and
   must be limited to controlled testing.
5. **Production distribution:** run the applicable HLK tests, submit the
   resulting package for Microsoft hardware certification signing, and publish
   the signed driver through Windows Update. Offer the control app via a
   signed MSIX/installer and its own update channel.
6. **Installer experience:** distribute a single signed bootstrapper that
   installs the driver package with elevation, the user-mode app, an uninstall
   entry, release notes and a diagnostic log collector. Reboot only when the
   PnP stack requires it.
7. **Update and rollback:** version the INF, catalog and app together; test
   upgrade/downgrade; retain an uninstall/rollback route; block incompatible
   configurations rather than leaving multiple root-device instances.

### Release gates

- Secure Boot stays enabled on customer devices.
- WHQL/Microsoft signature validates the catalog and driver files.
- Audio routing is tested with shared and exclusive mode, device changes,
  sleep/resume, fast user switching and no-client idle conditions.
- Fresh install, in-place upgrade, rollback and uninstall are tested on every
  supported Windows release and architecture.
- The product has a privacy statement; local audio is never uploaded unless a
  user explicitly opts in to a separate feature.

## Deliberate non-goals for the first demo

Do not add multi-cable routing, DSP effects/APOs, network transport, per-app
auto-routing, a global audio hook, or a mixer UI until P1 is demonstrated.
APOs are user-mode DSP plugins and are only relevant later if effects such as
noise suppression or EQ are required; they are not necessary to make a virtual
cable.

## References

- [Microsoft SysVAD virtual audio device sample](https://learn.microsoft.com/en-us/samples/microsoft/windows-driver-samples/sysvad-virtual-audio-device-driver-sample/)
- [Universal Windows Drivers for Audio](https://learn.microsoft.com/en-us/windows-hardware/drivers/audio/audio-universal-drivers)
- [Driver signing options](https://learn.microsoft.com/en-us/windows-hardware/drivers/dashboard/driver-signing-offerings)
- [Audio Processing Object architecture](https://learn.microsoft.com/en-us/windows-hardware/drivers/audio/audio-processing-object-architecture)
