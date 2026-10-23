# Spurtly – bezplatná verzia s jednou obrazovkou

Plán, ako zmeniť rozdelenie Free a Pro: zadarmo bude **jedna obrazovka**, kde
si nastavíš časy a spustíš časovač. Ukladanie tréningov, ich úpravy a
história budú len v Pro. Stav k októbru 2026.

## 1. Nové rozdelenie

| Zadarmo | Spurtly Pro (jednorazovo) |
|---|---|
| Jedna obrazovka: warm-up, work, rest, intervaly, kolá, rest medzi kolami, celkový čas, Start | **Uložené tréningy:** predvoľby (HIIT 1:1, HIIT 2:1, Tabata) a neobmedzene vlastných, premenovanie, duplikovanie, swipe akcie |
| Celý časovač: farby fáz, kruh, pauza, skip, obrazovka Done | **Live Activity a Dynamic Island** s Pause a Skip (iPhone) |
| Zvuky, 3-2-1, vibrácie (zapnuté, bez nastavení) | **Tlačidlá v notifikácii** a čip v stavovom riadku (Android) |
| Zvuky pri zamknutej obrazovke, bežná notifikácia, foreground služba na Androide | **Nastavenia signálov:** zvuky, 3-2-1, vibrácie |
| | **História a štatistiky**, keď ich spravíme |

**Princíp ostáva:** bezplatná verzia je plnohodnotný intervalový časovač. Pro pridáva pohodlie: tréningy pripravené na jedno ťuknutie, ovládanie z uzamknutej obrazovky a prispôsobenie.

## 2. Rozhodnutia (potvrdené podľa odporúčaní)

1. **Pamätať si posledné hodnoty aj zadarmo?** Odporúčam **áno**.
   - Nie je to uložený tréning, len posledné nastavenie obrazovky.
   - Bez toho by si človek musel pri každom spustení appky časy nastavovať odznova. Pôsobilo by to otravne a hodnotenia v obchode by tým trpeli.
2. **Zvuky vypnúť aj zadarmo?** Odporúčam nechať zadarmo aspoň **jeden prepínač „Sounds“** (malá ikona reproduktora na obrazovke). Celé nastavenia signálov ostanú v Pro.
   - Dôvod: na iPhone appka zámerne hrá aj pri prepínači ticha. Inak by pri zamknutej obrazovke cue nefungovali.
   - Bez prepínača by sa zvuk dal stíšiť len hlasitosťou.
   - Ak chceš úplne bez nastavení, ide to: všetky signály budú zapnuté.
3. **Predvoľby (HIIT 1:1, HIIT 2:1, Tabata) zadarmo?** Odporúčam **len v Pro** ako súčasť knižnice tréningov, aby bolo rozdelenie jasné.
   - Alternatíva: na bezplatnej obrazovke tri tlačidlá, ktoré len predvyplnia časy. Nič by sa neukladalo. Pekne by ukázali, čo appka vie, ale rozmazali by hranicu medzi Free a Pro.
4. **Čo sa stane s nastavením po kúpe Pro?** Odporúčam: ak sa líši od predvolených hodnôt, pridá sa do knižnice ako „My workout“. Človek o nič nepríde.

## 3. Ako to bude vyzerať

**Zadarmo:**
```
┌──────────────────────────────────┐
│ [logo] Spurtly          (★ Pro)  │
│        Interval timer            │
│                                  │
│ BEFORE YOU START                 │
│ Warm-up               −  1:00  + │
│ EACH INTERVAL                    │
│ Work                  −  0:30  + │
│ Rest                  −  0:15  + │
│ ROUNDS                           │
│ Intervals per round   −   4    + │
│ Rounds                −   3    + │
│ Rest between rounds   −  1:00  + │
│                                  │
│ 🔊  Total 14:00   Save · PRO     │
│ [            ▶ Start           ] │
└──────────────────────────────────┘
```
- Vpravo hore tlačidlo **Pro** (namiesto nastavení) otvorí obrazovku Spurtly Pro s Buy, Restore a Redeem code.
- **„Save · PRO“** je prirodzené miesto pre ponuku: kto chce tréning uložiť, dostane ponuku Pro.
- Prepínač zvuku 🔊 len ak potvrdíš rozhodnutie 2.

**S Pro:** zostane dnešná domovská obrazovka so zoznamom tréningov, editorom a nastaveniami.

## 4. Technické riešenie (hotové)

1. **Spoločný formulár:** riadky −/+ a súčet presunúť z `workout_screen.dart` do `lib/widgets/workout_config_form.dart`. Použije ho editor (Pro) aj bezplatná obrazovka.
2. **Bezplatná obrazovka** `lib/screens/quick_timer_screen.dart`:
   - hlavička s tlačidlom Pro,
   - formulár,
   - Start, Save · PRO (a prípadne prepínač zvuku),
   - na tablete vycentrovaná na čitateľnú šírku, ako ostatné obrazovky.
3. **Posledné hodnoty:**
   - nový kľúč `quick_config_v1` v `LibraryStore`,
   - v `WorkoutLibrary` vlastnosť `quickConfig`, uloží sa pri každej zmene.
4. **Výber domovskej obrazovky** v `app.dart` podľa `pro.unlocked`:
   - Pro → `HomeScreen` (knižnica),
   - inak → `QuickTimerScreen`.
   - Po kúpe sa obrazovka prepne sama. Po vrátení peňazí sa appka vráti na bezplatnú obrazovku. Uložené tréningy ostanú v telefóne skryté a pri ďalšej kúpe alebo obnovení sa znova ukážu.
5. **Časovač** (`timer_screen.dart`):
   - prijme konfiguráciu a nepovinný názov (bezplatná verzia názov nemá),
   - zadarmo použije predvolené signály, prípadne len prepínač zvuku,
   - obmedzenie Live Activity a tlačidiel v notifikácii ostáva.
6. **Odstrániť limit 3 tréningov:**
   - `SpurtlyPro.freeWorkouts`, odznak PRO pri „New workout“, ponuka pri duplikovaní.
   - Knižnica je celá v Pro, takže limit už netreba.
7. **Obrazovka Spurtly Pro:** nový zoznam výhod:
   - uložené tréningy a predvoľby,
   - ovládanie z uzamknutej obrazovky,
   - nastavenia signálov,
   - bez predplatného a reklám.
   - Históriu tam pridáme, až keď bude hotová. Apple nemá rád sľuby funkcií, ktoré v appke ešte nie sú.
8. **Prenos pri kúpe:** rozhodnutie 4, hneď po odomknutí.

## 5. Testy
- **Widget testy:**
  - zadarmo sa ukáže len formulár so Start, bez zoznamu a nastavení,
  - zmena hodnoty prežije reštart, teda sa uloží do `quick_config_v1`,
  - Save · PRO a tlačidlo Pro otvoria ponuku,
  - po kúpe sa ukáže knižnica a nastavenie sa prenesie ako „My workout“,
  - po strate Pro (refund) sa appka vráti na bezplatnú obrazovku a tréningy ostanú uložené.
- **Existujúce testy:** knižnicu, editor a swipe testovať s Pro, limit 3 tréningov vyhodiť.
- **Simulátor a emulátor:** bezplatná obrazovka na telefóne a na tablete, štart tréningu, kúpa s `--dart-define=SPURTLY_PRO=true`.

## 6. Dokumentácia a obchody
- `docs/RELEASE.md`:
  - 6.1 nová tabuľka Free/Pro,
  - 6.4 obmedzenia,
  - kapitola 5 popis v obchode (dnes spomína uložené tréningy ako bezplatnú funkciu a „Every future Pro feature included“),
  - poznámka pre recenzenta: bezplatná verzia je plnohodnotný časovač, Pro pridáva knižnicu a ovládanie z uzamknutej obrazovky.
- `README.md`: funkcie a rozdelenie Free/Pro.
- **Review:** jednoduchá bezplatná verzia s platenou knižnicou je bežný a povolený model (Apple 3.1.1, Google Play platby cez Play Billing). Bezplatná časť musí fungovať sama osebe, a to spĺňa.

## 7. Odhad
| Krok | Trvanie |
|---|---|
| Spoločný formulár, bezplatná obrazovka, posledné hodnoty | ~3 hodiny |
| Výber domovskej obrazovky, časovač bez názvu, prenos pri kúpe | ~2 hodiny |
| Úprava obrazovky Pro, odstránenie limitu | ~1 hodina |
| Testy, simulátor a emulátor, dokumentácia | ~3 hodiny |

Spolu zhruba **1 deň práce**.
