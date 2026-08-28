# VAD schemos lentai

## 1. Pagrindinė VAD struktūra

```text
USER MODE

┌─────────────────────┐
│  YouTube / Test WAV │
│     Programa A      │
└──────────┬──────────┘
           │ WASAPI audio: 48 kHz stereo
           ▼
┌─────────────────────────────┐
│     LIT Virtual Input       │
│ Windows Playback / Output   │
│      Render endpoint        │
└──────────┬──────────────────┘
           │ PCM frames
═══════════╪════════════ USER / KERNEL RIBA ═══════════════════
           ▼
┌────────────────────────────────────────────────────┐
│               MŪSŲ WINDOWS VAD DRIVERIS            │
│                                                    │
│  ┌────────────────┐                                │
│  │ Render miniport│                                │
│  │ gauna frames   │                                │
│  └───────┬────────┘                                │
│          │ Write(frames)                           │
│          ▼                                         │
│  ┌──────────────────────────────────────────────┐  │
│  │              ROUTE ENGINE                    │  │
│  │                                              │  │
│  │     SPSC RING BUFFER – 48 kHz stereo         │  │
│  │                                              │  │
│  │  Write → [PCM][PCM][PCM][PCM][free] → Read  │  │
│  │                                              │  │
│  │  Buffer tuščias → tyla                       │  │
│  │  Buffer pilnas → išmesti seniausius frames  │  │
│  └──────────────────────┬───────────────────────┘  │
│                         │ Read(frames)              │
│                         ▼                           │
│                 ┌─────────────────┐                 │
│                 │ Capture miniport│                 │
│                 │ atiduoda frames │                 │
│                 └────────┬────────┘                 │
│                                                    │
│  Adapter + PnP + Power + endpointų registravimas   │
└──────────────────────────┼─────────────────────────┘
                           │ PCM frames
═══════════════════════════╪════════ KERNEL / USER RIBA ═══════
                           ▼
┌─────────────────────────────┐
│     LIT Virtual Output      │
│ Windows Recording / Input   │
│      Capture endpoint       │
└──────────┬──────────────────┘
           │ WASAPI audio
           ▼
┌─────────────────────┐
│     OBS / Discord   │
│     Programa B      │
└─────────────────────┘
```

## 2. Supaprastinta schema

Šią versiją naudoti, jeigu lentoje mažai vietos.

```text
USER MODE

YouTube / WAV                                      OBS
     │                                              ▲
     │ WASAPI                                       │ WASAPI
     ▼                                              │
LIT Virtual Input                           LIT Virtual Output
Windows Playback                            Windows Recording
     │                                              ▲
═════╪══════════════ KERNEL MODE ═══════════════════╪═════
     ▼                                              │
Render miniport                                     │
     │                                              │
     │ Write                                        │ Read
     ▼                                              │
┌───────────────────────────────────────────────────────┐
│                   ROUTE ENGINE                        │
│                                                       │
│       [ PCM RING BUFFER – 48 kHz stereo ]              │
│                                                       │
│  underrun → tyla          overflow → mesti seniausius │
└───────────────────────────┬───────────────────────────┘
                            │
                            ▼
                     Capture miniport
```

## 3. Driverio paleidimas

```text
LitVadAudio.inf
      │
      ▼
ROOT\LITVAD
      │
      ▼
Windows PnP
      │
      ▼
LitVadAudio.sys
      │
      ▼
VAD Adapter
      │
      ├── Render endpoint
      ├── Capture endpoint
      └── Route Engine / ring buffer
```

## 4. Vieno audio paketo eiga

```text
1. YouTube siunčia 480 stereo frames.
2. Render miniportas gauna frames.
3. RouteEngine.Write įrašo juos į ring bufferį.
4. OBS paprašo 480 frames.
5. RouteEngine.Read paima juos iš bufferio.
6. Capture miniportas perduoda frames OBS.
7. OBS garso indikatorius juda.
```

Prie 48 kHz dažnio 480 frames sudaro 10 ms garso:

```text
480 / 48 000 = 0,01 s = 10 ms
```

## 5. Windows pavadinimų reikšmė

```text
LIT Virtual Input
= Windows Playback / Output
= driverio Render endpoint
= programa čia SIUNČIA garsą

LIT Virtual Output
= Windows Recording / Input
= driverio Capture endpoint
= programa iš čia PAIMA garsą
```

## 6. Clean-room ir reverse engineering schema

```text
┌────────────────────────┐
│ VB-Audio analizė       │
│                        │
│ Stebime:               │
│ - Windows endpointus   │
│ - audio formatus       │
│ - PnP įrenginius       │
│ - signalo kelią        │
└────────────┬───────────┘
             │ elgsenos žinios
             ▼
┌────────────────────────┐
│ Microsoft SysVAD       │
│ WDM / WaveRT karkasas  │
└────────────┬───────────┘
             │
             ▼
┌────────────────────────┐
│ Mūsų implementacija    │
│                        │
│ - LIT identitetas      │
│ - 2 endpointai         │
│ - RouteEngine          │
│ - Ring buffer          │
└────────────────────────┘
```

```text
VB-Audio kodo nekopijuojame.
Stebime tik Windows matomą elgesį.
```

## Pagrindinis paaiškinimo sakinys

> Programa A siunčia PCM frames į mūsų virtualų playback endpointą, driverio
> ring bufferis perduoda juos capture endpointui, o Programa B pasiima juos kaip
> iš virtualaus mikrofono.
