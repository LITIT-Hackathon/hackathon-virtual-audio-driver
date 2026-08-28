# Minimalus VAD techninis kontraktas

```text
USER MODE

Test WAV / browser                       OBS
        |                                 ^
        | WASAPI render                   | WASAPI capture
        v                                 |
Windows Audio Engine              Windows Audio Engine
        |                                 ^
--------|----------- KERNEL --------------|----------------
        v                                 |
LIT Virtual Input                 LIT Virtual Output
render endpoint                   capture endpoint
        |                                 ^
        v                                 |
Render miniport -> [SPSC RING BUFFER] -> Capture miniport
                         |
                 RouteEngine owned
                 by adapter object
```

## Vieno audio periodo eiga

1. Windows render pusėje pateikia `N` pilnų stereo frames.
2. Render data path iškviečia `RouteEngine.Write`.
3. Frames nukopijuojami į iš anksto rezervuotą žiedinį bufferį.
4. Windows capture pusėje paprašo `M` frames.
5. Capture data path iškviečia `RouteEngine.Read`.
6. Jei yra `M` frames, jie grąžinami OBS.
7. Jei jų mažiau, likusi dalis užpildoma nuliais.
8. Jei rašant trūksta vietos, seniausi pilni frames išmetami.

## Fiksuoti sprendimai

```text
platform:       Windows 11 x64 demo PC
base:           Microsoft SysVAD
route count:    1
render count:   1
capture count:  1
sample rate:    48,000 Hz
channels:       2 interleaved
latency target: veikianti demonstracija, ne produkcinė garantija
```

Pirmiausia naudoti formatą, kurį pasirinkta SysVAD render/capture pora jau
bendrai palaiko. Neįvedinėti konversijos vien tam, kad viduje būtų float.

## SysVAD ir mūsų darbo riba

SysVAD paliekama:

- WDM, PortCls ir WaveRT infrastruktūra;
- PnP, power ir stream būsenos;
- endpointų descriptor ir INF karkasas;
- render/capture miniportų esamas laiko bei pozicijų valdymas.

Mūsų pakeitimai:

- produkto identitetas ir dviejų endpointų vardai;
- nereikalingų endpointų išjungimas;
- adapteriui priklausantis fiksuoto dydžio `RouteEngine`;
- render frames įrašymas ir capture frames skaitymas;
- silence-on-underrun ir discard-oldest-on-overflow.

GUI, IOCTL, diagnostikos API, resampling, drift correction, keli klientai,
multi-format, matrix, APO, installerio UX, production signing ir platus PnP
testavimas nėra šio prototipo dalis.
