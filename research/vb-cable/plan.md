# 🎯 Hackathon Project: Virtual Audio Cable

> **Istorinis 12 valandų tyrimo planas. Nevykdyti kaip dabartinio backlog'o.**
> Aktyvus planas yra [`../../HACKATHON_PLAN.md`](../../HACKATHON_PLAN.md).

Since we only have **12 hours**, we should not try to build a full competitor to VB-CABLE.

The best approach is to build a **minimal working Virtual Audio Cable prototype**.

## What exactly should we build?

The goal is:

```text
        Spotify / YouTube / Test App
                    │
                    │ Audio
                    ▼
        ┌───────────────────────┐
        │  LIT Virtual Input    │
        │  (Playback Device)    │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │   OUR AUDIO DRIVER    │
        │                       │
        │     Audio Buffer      │
        │     █████████ →       │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  LIT Virtual Output   │
        │  (Recording Device)   │
        └───────────┬───────────┘
                    │
                    ▼
               OBS / App
```

Think of it as a **virtual audio cable inside Windows**.

An application such as Spotify sends audio into our Virtual Input. Our driver receives the audio and transfers it to the Virtual Output. Another application, such as OBS or Discord, can then receive that audio.

In simple terms:

**Application A → Our Driver → Application B**

---

## 🖥️ What should the demo look like?

The demo should be extremely simple.

**1.** Open Windows Sound Settings.

We should see our two virtual devices:

```text
Playback:
LIT Virtual Input

Recording:
LIT Virtual Output
```

**2.** Play music or a YouTube video.

**3.** Set the application's audio output to:

```text
LIT Virtual Input
```

**4.** Open OBS and select:

```text
LIT Virtual Output
```

as the audio input.

**5.** Start playing audio.

The OBS audio meter should start moving.

That proves that audio successfully travels through our driver:

```text
YouTube
   ↓
LIT Virtual Input
   ↓
OUR DRIVER
   ↓
LIT Virtual Output
   ↓
OBS
```

That should be our main **“wow moment”** during the presentation.

---

# 🔧 What should the driver actually do?

At its core, we only need three main components:

```text
Virtual Render Endpoint
          │
          ▼
     Audio Buffer
          │
          ▼
Virtual Capture Endpoint
```

The **Virtual Render Endpoint** receives audio from an application.

The **Audio Buffer** temporarily stores and transfers the audio samples.

The **Virtual Capture Endpoint** exposes that same audio to another application as if it were coming from a microphone or recording device.

We do NOT need to build a mixer, audio editor, effects system, or complicated UI.

The main goal is simply:

> **Receive audio → transfer audio → expose audio to another application.**

---

# 🛠️ Technical Approach

We should **not build a Windows audio driver completely from scratch**.

A better starting point is Microsoft's **SysVAD (System Virtual Audio Device)** sample from the Windows Driver Samples repository.

SysVAD already provides much of the Windows virtual audio device infrastructure.

We can adapt it into something much simpler:

```text
Virtual Render Endpoint
        │
        ▼
    Audio Buffer
        │
        ▼
Virtual Capture Endpoint
```

Then rename the devices to something like:

```text
LIT Virtual Cable Input
LIT Virtual Cable Output
```

The main implementation challenge is connecting the render side to the capture side so that the same audio samples can travel through our virtual cable.

---

# ❌ What we should NOT build

Because we only have 12 hours, we should avoid unnecessary features.

We do NOT need:

* A fancy GUI
* An audio mixer
* Equalizer
* Audio effects
* Multiple virtual cables
* Network audio
* Complex configuration
* A perfect installer
* A full VB-CABLE replacement

Every additional feature increases the chance that the core functionality will not be finished.

**One stable working audio route is much more valuable than ten unfinished features.**

---

# ⏱️ 12-Hour Plan

| Time        | Goal                                                                      |
| ----------- | ------------------------------------------------------------------------- |
| **0–2 h**   | Set up Visual Studio + WDK and successfully build the driver sample       |
| **2–4 h**   | Install the driver and make sure Windows detects the virtual audio device |
| **4–7 h**   | Implement Render → Buffer → Capture audio routing                         |
| **7–9 h**   | Test with real applications such as YouTube/Spotify → OBS                 |
| **9–10 h**  | Fix device names, crashes and stability issues                            |
| **10–11 h** | Prepare the live demo                                                     |
| **11–12 h** | Final testing and presentation preparation                                |

## ⚠️ Important checkpoint

By approximately **hour 4**, Windows should already detect our virtual audio device.

If we are still fighting with basic driver compilation or installation after 6–7 hours, we should reduce the scope rather than adding more features.

The priority is always:

**Get the smallest possible version working first.**

---

# 🏆 Final Result

The finished prototype should demonstrate:

```text
YouTube / Spotify
       │
       ▼
LIT Virtual Input
       │
       ▼
┌──────────────────┐
│ OUR AUDIO DRIVER │
│                  │
│  Audio Buffer    │
└────────┬─────────┘
         │
         ▼
LIT Virtual Output
         │
         ▼
        OBS
```

If we can demonstrate this working reliably, we have successfully created a basic **Windows Virtual Audio Cable**.

## 🎤 Simple pitch for the judges

> **“We built a virtual audio cable for Windows. It allows audio from one application to be routed directly into another application without requiring any physical audio hardware.”**

Then we immediately demonstrate:

**YouTube → LIT Virtual Cable → OBS**

The live working demo should be the main focus of the project.
