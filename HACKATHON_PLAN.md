# Aktyvus 4 valandų hackathono planas

> Tai vienintelis vykdymo planas. `research/` failai yra ankstesnis tyrimas, o
> ne dabartinis backlogas. `README.md` yra originali užduoties sąlyga ir jo nekeisti.

## Tikslas

```text
Test WAV / naršyklė
  -> LIT Virtual Input (Windows playback įrenginys)
  -> mūsų SysVAD pagrindo driveris ir vienas ring bufferis
  -> LIT Virtual Output (Windows recording įrenginys)
  -> OBS garso indikatorius
```

## Griežtas MVP

Privaloma:

- vienas render ir vienas capture endpointas;
- vienas fiksuotas `render -> capture` kelias;
- tik 48 kHz stereo, vienodas formatas abiejose pusėse;
- iš anksto rezervuotas ring bufferis;
- kai trūksta duomenų – tyla;
- kai bufferis pilnas – išmetami seniausi pilni frames;
- Debug x64 testinis buildas ir gyva OBS demonstracija.

Nedaryti:

- assembly, driverio nuo nulio, GUI, mixerio ar routing matrix;
- resampling, DSP, APO, kelių kabelių ar fizinių įrenginių routing;
- production installerio, Microsoft signing, ARM64 ar plataus testavimo;
- papildomų funkcijų, kol OBS negauna garso.

## Dviejų žmonių ribos

| Žmogus | Šaka | Vienintelė atsakomybė | Failų savininkas |
| --- | --- | --- | --- |
| A + AI | `driver/mvp-cable` | SysVAD buildas, du endpointai, ring bufferis | `src/driver/**` |
| B + AI | `integration/demo-path` | aplinka, paketo diegimas, diagnostika, OBS demo | `scripts/**`, `demo/**`, `docs/**` |

Iki pirmo veikiančio audio perdavimo B nekeičia `src/driver/**`. A nekeičia B
skriptų. Problema perduodama kaip: tikslūs atkūrimo žingsniai, klaidos tekstas,
paketo commit ir SetupAPI logas.

```powershell
# A
git switch -c driver/mvp-cable

# B savo checkout'e
git switch -c integration/demo-path
```

Kas 20–30 min. daromas mažas commit. Jokio force-push ir jokio darbo tiesiai
`main`. Integracija vyksta tik ties žemiau nurodytais vartais.

## 0:00–0:20 – G0: aplinka

**A:** paleidžia `scripts/check-dev-env.ps1`, patvirtina Visual Studio 2022 C++,
SDK ir WDK, pasiima oficialų Microsoft `audio/sysvad` į `src/driver/`, o
`src/driver/UPSTREAM.md` įrašo repo URL ir konkretų commit hash.

**B:** patvirtina administratoriaus teises, paruošia OBS ir žinomą 48 kHz stereo
WAV bei atsidaro `demo/DEMO_CHECKLIST.md`.

**G0 PASS:** skriptas randa MSBuild, SDK ir WDK, o `sysvad.sln` atsidaro.

**G0 FAIL po 20 min.:** persikelti į paruoštą Windows kompiuterį/VM. Nešvaistyti
likusio laiko aplinkos diegimui. Dabartinė patikra šiame kompiuteryje yra `FAIL`,
nes VS/WDK nerasti.

## 0:20–0:50 – G1: nepakeistas SysVAD buildas

**A:** sukompiliuoja nepakeistą SysVAD `Debug|x64`. Dar nekeičia endpointų ir
nerašo ring bufferio.

**B:** paruošia paketo diegimo ir diagnostikos veiksmus, Device Manager bei
Windows Sound patikrą ir pasižymi `%windir%\inf\setupapi.dev.log`.

**G1 PASS:** yra buildo paketas su `.sys`, `.inf` ir `.cat`.

**G1 FAIL:** abu sprendžia tik toolchain/build problemą. Jokio feature kodo, kol
stock sample nesusibuildina.

## 0:50–1:40 – G2: du Windows endpointai

**A:** pasirenka vieną jau egzistuojančią paprastą SysVAD render/capture porą,
išjungia nereikalingas poras ir pakeičia tik produkto identitetą:

```text
hardware ID: ROOT\LITVAD
service:     LitVadAudio
render:      LIT Virtual Input
capture:     LIT Virtual Output
format:      bendras 48 kHz stereo formatas
```

Naudojami nuosavi GUID, kur jų reikia. Neperrašinėjamas visas SysVAD.

**B:** diegia kiekvieną A paketą, tikrina Device Manager, Windows Sound ir Code
10 bei grąžina tikslią diagnostiką.

**G2 PASS:** abu endpointai rodomi po vieną, adapteris neturi Code 10.

**G2 FAIL 1:40 momentu:** abu taiso tik INF/PnP/signing. Ring bufferio darbas be
veikiančių endpointų neturi vertės.

## 1:40–3:00 – G3: garsas pereina

**A** daro kuo mažesnį pakeitimą veikiančiame SysVAD data path:

```text
render stream -> RouteEngine.Write(frames)
              -> fiksuotas SPSC ring bufferis
capture stream <- RouteEngine.Read(frames)
```

Taisyklės:

- bufferis sukuriamas adapterio start metu, ne audio callbacke;
- kopijuojami tik pilni stereo frames;
- capture underrun užpildomas nuliais;
- overflow pastumia read poziciją ir palieka naujausius frames;
- audio kelyje nėra allocation, failų, logų ar laukimo;
- šiam demo nereikia UI ir IOCTL statistikos.

**B:** leidžia 48 kHz WAV į `LIT Virtual Input`, OBS pasirenka `LIT Virtual
Output`, kiekvieną buildą testuoja iki 2 minučių ir užrašo pirmo veikiančio
commit hash.

**G3 PASS:** OBS indikatorius be nutrūkimo juda 30 sekundžių.

**G3 FAIL 3:00 momentu:** capture endpointas generuoja kontroliuojamą driverio
testinį toną. Pristatyme aiškiai sakyti, kad endpointai ir capture data path
veikia, bet render-to-capture tiltas nebaigtas. Nevadinti to pilnu kabeliu.

## 3:00–3:30 – stabilizavimas

Tik jei G3 praėjo:

- 2 kartus paleisti ir sustabdyti šaltinį bei OBS;
- vienas 2 minučių nenutrūkstantis testas;
- patikrinti BSOD, Code 10 ir endpointų dublikatus;
- išsaugoti veikiančio commit hash;
- taisyti tik crash, silence ir aiškų trūkinėjimą.

Jokio refactoring, UI, naujų formatų ar installerio gražinimo.

## 3:30–4:00 – freeze ir demo

1. Nebekeičiama veikianti driverio versija.
2. A ir B du kartus praeina `demo/DEMO_CHECKLIST.md`.
3. Padaromas 30–60 s atsarginis demonstracijos video.
4. Užrašomas veikiantis paketas ir commit hash.

Pristatymo sakinys:

> Išanalizavome VB-Audio Windows matomą elgesį, tačiau nekopijavome jo kodo ar
> identifikatorių. Savo virtualų audio įrenginį sukūrėme naudodami Microsoft
> SysVAD infrastruktūrą ir savo minimalų render-to-capture buferio kelią.

## Clean-room riba

VB-Audio naudojamas tik stebėti endpointų tipą, formatą, signalą ir PnP elgesį.
Nekopijuoti jo binary, INF, GUID, hardware ID, vardų ar dekompiliuotos
implementacijos. Kodo bazė – oficialus Microsoft SysVAD ir jūsų pačių mažas
`RouteEngine` pakeitimas.

## Baigtumo kriterijai

- [ ] Windows rodo abu LIT endpointus be Code 10.
- [ ] Test WAV nukreiptas į `LIT Virtual Input`.
- [ ] OBS skaito iš `LIT Virtual Output`.
- [ ] OBS indikatorius juda bent 30 sekundžių.
- [ ] Yra veikiančio paketo kelias ir commit hash.
- [ ] Yra atsarginis demonstracijos įrašas.
