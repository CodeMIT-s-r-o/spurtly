# Spurtly – úpravy pre Android tablety

Plán, ako pripraviť Spurtly na tablety a rozložené skladacie telefóny
s Androidom. iPad ostáva v iPhone režime (appka je len pre iPhone), tento plán
sa ho netýka. Stav k októbru 2026.

## 1. Prečo to treba

- **Android 16 ignoruje zámok na výšku na veľkých displejoch.** Appky, ktoré cielia na API 36 (to je Spurtly), na displejoch so šírkou aspoň 600 dp nemôžu obmedziť orientáciu, veľkosť okna ani pomer strán.
  - Spurtly sa na tablete otočí na šírku, aj keď ho v kóde (`main.dart`) zamykáme na výšku.
  - Appka vyplní celé okno a dá sa dať aj do rozdelenej obrazovky (split screen).
- **Android 16 ešte dovoľuje dočasnú výnimku (opt-out), Android 17 (API 37) ju ruší.** Google Play bude target API 37 podľa plánu vyžadovať od augusta 2027. Výnimka by teda problém len odsunula, preto ju nepoužijeme.
- **Google Play** v rebríčkoch zvýhodňuje appky, ktoré sa dobre prispôsobia veľkej obrazovke a podporujú výšku aj šírku.
- **Telefóny sa nemenia.** Na displejoch užších ako 600 dp zámok na výšku platí ďalej.

## 2. Ako to vyzerá dnes (bez testu na tablete, podľa kódu)

| Obrazovka | Na tablete / na šírku |
|---|---|
| Zoznam tréningov | Karty sa roztiahnu na celú šírku displeja. Funguje, ale vyzerá prázdno a nepekne. |
| Editor tréningu | Riadky −/+ sú roztiahnuté, číslo a tlačidlá ďaleko od seba. Tlačidlo Start má celú šírku. |
| Časovač | Stavaný ako stĺpec: horná lišta, kruh, „Next“, tlačidlá. Na šírku zaberie kruh len časť výšky a po stranách ostane veľa prázdna. V nízkom okne (split screen, telefón na šírku) kruh výrazne zmenší. |
| Hotovo (Done) | Tlačidlo Back cez celú šírku. |
| Nastavenia, Spurtly Pro | Spodné panely má Material 3 obmedzené na šírku 640 dp, takže sú v poriadku. Pri nízkom okne sa dajú rolovať. |
| Notifikácia, foreground služba | Bez zmeny, fungujú rovnako. |

**Stav sa pri otočení nestratí.** Manifest má `configChanges` (orientácia, veľkosť obrazovky, rozloženie), takže Android aktivitu nereštartuje a bežiaci tréning pokračuje. Treba to však overiť.

## 3. Čo spravíme (hotové v branchi `android-tablets`)

Cieľ je úroveň „Large screen ready“ z kvality pre veľké obrazovky Google: appka vyplní obrazovku, funguje na výšku aj na šírku, v rozdelenej obrazovke aj pri skladaní a rozkladaní a pritom nestratí stav. Samostatné tabletové rozloženie (napr. zoznam a editor vedľa seba) teraz nerobíme.

### 3.1 Orientácia podľa veľkosti displeja (`lib/app.dart`)
- Telefóny ostanú zamknuté na výšku.
- Tablety a rozložené skladačky (najkratšia strana ≥ 600 dp) sa môžu otáčať.
  - Rovnako sa budú správať aj na Androide 12–15, kde by inak zámok platil.
- Rozhodnutie podľa aktuálnej veľkosti okna, nie raz pri štarte. Skladačka tak pri zložení prejde na telefónny režim a pri rozložení na tabletový.
- Na iPhone a iPade sa nič nemení: iPhone appka na iPade má telefónnu veľkosť.

### 3.2 Obsah obmedzený na rozumnú šírku (`lib/widgets/readable_width.dart`)
- `ReadableWidth` a `readableInset`: obsah vycentruje a obmedzí na 640 dp. Zoznamy majú len odsadenie, takže sa dajú rolovať aj za okraje.
- Použije sa na zoznam tréningov, editor (vrátane spodného súčtu a tlačidla Start) a obrazovku Done.
- Pozadie a farba fázy ostanú cez celú obrazovku, obmedzí sa len obsah.

### 3.3 Časovač na šírku (`lib/screens/timer_screen.dart`)
- Keď je okno výrazne širšie než vyššie, časovač sa rozloží vedľa seba:
  ```
  ┌──────────────────────────────────────────────────┐
  │ ✕       Round 1 / 4 · Interval 2 / 8       17:40 │
  │                                                  │
  │      ╭────────╮                                  │
  │     │  WORK   │        Next: Rest · 0:10         │
  │     │  0:17   │                                  │
  │      ╰────────╯          ( ⏸ )   ( ⏭ )            │
  │                                                  │
  └──────────────────────────────────────────────────┘
  ```
- Kruh vľavo, čo najväčší podľa výšky okna. Vpravo „Next“ a tlačidlá Pause a Skip.
- Rozhoduje sa podľa rozmerov okna (`LayoutBuilder`), nie podľa toho, či je zariadenie tablet. Rovnaký kód pokryje tablet na šírku, rozdelenú obrazovku aj prípadné nízke okná.
- Na výšku ostane časovač ako dnes.
- Prah: okno je viac ako 1,3× širšie než vysoké.

### 3.4 Drobnosti
- Rozdelená obrazovka a malé okná: obrazovka Done sa v nízkom okne roluje, editor a panely sa rolovali už predtým.
- Hint „Swipe a workout right…“ a odznak PRO: bez zmeny, len v rámci obmedzenej šírky.
- Ikona a splash: bez zmeny.

## 4. Testovanie

- **Widget testy** (hotové, `test/widget_test.dart`, skupina „on a tablet“) s veľkosťami okna:
  - tablet na výšku a na šírku (napr. 800 × 1280 a 1280 × 800 dp),
  - polovica tabletu v rozdelenej obrazovke,
  - Kontrola: nič nepretečie, na šírku sa časovač rozloží vedľa seba a obsah je obmedzený na šírku.
- **Emulátor** (systémový obraz Android 17 je nainštalovaný, profily sú k dispozícii):
  - `pixel_tablet`: zoznam, editor, časovač na výšku aj na šírku, otočenie počas bežiaceho tréningu (čas ani stav sa nesmú stratiť), rozdelená obrazovka.
  - `pixel_fold`: zložený je telefón a ostane na výšku, rozložený je tablet. Rozloženie a zloženie počas tréningu.
  - Notifikácia s tlačidlami a čip v stavovom riadku aj na tablete.
  - Emulátor tabletu je náročnejší na pamäť. Pred testom vypnúť Gradle démonov (pri poslednom teste emulátor padal pre nedostatok pamäte).
- **Telefón:** overiť, že sa nič nezmenilo a ostáva na výšku.

**Výsledok (október 2026):**
- Testované na emulátore s Androidom 17. Telefónny emulátor mal nastavený displej tabletu (`adb shell wm size 1600x2560` a `wm density 320`, teda 800 × 1280 dp). Samostatný tabletový emulátor `pixel_tablet` na tomto Macu pre nedostatok pamäte nenabehol.
- **Overené:**
  - zoznam vycentrovaný na 640 dp,
  - časovač na šírku vedľa seba a na výšku pod sebou,
  - otočenie počas bežiaceho tréningu: čas pokračuje a nič sa nereštartuje,
  - notifikácia s tlačidlami,
  - telefón ostáva na výšku aj pri otočení.
- **Neoverené:** skladací telefón (`pixel_fold`) a rozdelená obrazovka na skutočnom zariadení. Rozdelenú obrazovku pokrýva widget test nízkeho okna.

## 5. Google Play

- Tabletové screenshoty sú **voliteľné**, ale odporúčané. Bez nich sa appka na tabletoch nainštalovať dá, len sa v obchode horšie prezentuje.
  - Návrh: 2–4 screenshoty pre 7" a 10" tablet, aspoň jeden na šírku s časovačom.
  - Presné požiadavky overiť v Play Console pri zakladaní listingu (kapitola 4.6 a 5 v [RELEASE.md](RELEASE.md)).
- V Play Console netreba nič vypínať ani obmedzovať. Tablety v katalógu zariadení ostanú povolené.

## 6. Odhad

| Krok | Trvanie |
|---|---|
| Orientácia podľa veľkosti, obmedzená šírka obsahu | ~2 hodiny |
| Časovač na šírku | ~2–3 hodiny |
| Widget testy pre veľkosti okna | ~1 hodina |
| Test na emulátore tabletu a skladačky, opravy | ~2–3 hodiny |

Spolu zhruba **1 deň práce**. Tabletové screenshoty sa dajú spraviť potom z emulátora `pixel_tablet`.

## Zdroje
- Android 16, zmeny orientácie a veľkosti okna: https://android-developers.googleblog.com/2025/01/orientation-and-resizability-changes-in-android-16.html
- Android 17, zrušenie výnimky: https://developer.android.com/about/versions/17/changes/ff-restrictions-ignored
- Príprava na zmeny v Androide 17: https://developer.android.com/blog/posts/prepare-your-app-for-the-resizability-and-orientation-changes-in-android-17
- Google Play a kvalita appiek pre veľké obrazovky (ranking): https://techcrunch.com/?p=2574862
