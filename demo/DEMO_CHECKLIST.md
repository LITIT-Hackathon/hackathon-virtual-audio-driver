# 3 minučių demo checklist

## Prieš prezentaciją

- [ ] Naudojamas užfiksuotas veikiantis commit ir driverio paketas.
- [ ] Windows Sound rodo tik vieną `LIT Virtual Input`.
- [ ] Windows Sound rodo tik vieną `LIT Virtual Output`.
- [ ] Device Manager nerodo Code 10.
- [ ] Testinis failas yra 48 kHz stereo.
- [ ] OBS scena sukurta, virtualus įėjimas matomas pasirinkime.
- [ ] Atsarginis 30–60 s video atsidaro lokaliai.

## Gyva demonstracija

1. Parodyti Windows Sound playback sąrašą ir `LIT Virtual Input`.
2. Parodyti recording sąrašą ir `LIT Virtual Output`.
3. Testinio WAV arba naršyklės output pasirinkti `LIT Virtual Input`.
4. OBS Audio Input Capture pasirinkti `LIT Virtual Output`.
5. Paleisti garsą ir 10–15 s parodyti judantį OBS indikatorių.
6. Sustabdyti šaltinį ir parodyti, kad indikatorius nustoja judėti.

## Ką sakyti

> Programa siunčia PCM frames į mūsų virtualų playback endpointą. Mūsų Windows
> driverio ring bufferis perduoda juos į virtualų capture endpointą, kurį OBS
> mato kaip įrašymo įrenginį.

## Ko nesakyti

- Nesakyti, kad tai produkcinis ar pilnai pasirašytas driveris.
- Nesakyti, kad nukopijuotas ar perrašytas VB-Audio kodas.
- Jei veikia tik testinio tono fallback, nevadinti jo pilnu virtualiu kabeliu.
