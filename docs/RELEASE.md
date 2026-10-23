# Spurtly – vydanie do App Store a Google Play

Plán, ako dostať Spurtly do obchodov: účty, podpisovanie, buildy, nahrávanie,
formuláre a podklady. Stav projektu a požiadavky obchodov sú k októbru 2026.

**Model:** appka je **zadarmo** a obsahuje **jednorazový nákup „Spurtly Pro“**
(odomknutie navždy, bez predplatného), pozri kapitolu 6.

## 0. Prehľad

| | iOS | Android |
|---|---|---|
| Bundle ID / application ID | `sk.codemit.spurtly` | `sk.codemit.spurtly` |
| Rozšírenie | `sk.codemit.spurtly.LiveActivity` (Live Activity, iOS 17+) | – |
| Verzia | `1.0.0+1` v `pubspec.yaml` (`názov+build`) | to isté (`versionName` + `versionCode`) |
| Minimálna verzia OS | iOS 15 (Live Activity od iOS 17), len iPhone | Android 7.0 (API 24) |
| Cieľové SDK | iOS 26 SDK (Xcode 26.4) | API 36 (Android 16) |
| Podpis | Xcode, tím `TR23TL5S42` | upload kľúč cez `android/key.properties` (kľúč treba vytvoriť, 4.1) |
| Výstup na upload | `.ipa` | `.aab` (App Bundle) |
| Poplatok | 99 USD / rok | 25 USD jednorazovo |
| Nákup v appke | Non-Consumable `spurtly_pro` | One-time product `spurtly_pro` |
| Provízia obchodu | 15 % (Small Business Program) | 15 % z prvého 1 mil. USD ročne |

**Požiadavky obchodov, ktoré už spĺňame:**
- **App Store** od 28. 4. 2026 prijíma iba buildy z Xcode 26 a iOS 26 SDK. Máme Xcode 26.4.1.
- **Google Play** od 31. 8. 2026 vyžaduje pri nových appkách aj aktualizáciách target API 36 (Android 16). Flutter 3.47 ho nastavuje predvolene.

## 1. Čo treba spraviť pred prvým vydaním

Rozhodnutia a práca, ktoré by mali byť hotové skôr, než pôjdeme do obchodov.

**Rozhodnutia**
- [ ] **Kto bude vydavateľ.** Odporúčam **CodeMIT, s.r.o.** ako organizáciu v oboch obchodoch.
  - Bundle ID `sk.codemit…` s tým sedí.
  - V obchode sa ukáže meno firmy, nie tvoje.
  - Organizačný účet v Google Play **nemusí** pred prvým vydaním absolvovať test s 12 testermi počas 14 dní (pozri 4.7).
- [x] **Model:** zadarmo + jednorazové odomknutie Pro, bez reklám a bez predplatného.
- [ ] **Rozsah Pro a cena:** návrh je v 6.1 a 6.2, treba ho potvrdiť.
- [x] **iPad:** v1 je **len pre iPhone** (`TARGETED_DEVICE_FAMILY = 1` v celom Xcode projekte), takže App Store nebude chcieť iPad screenshoty. UI je robené na telefón na výšku. Na iPade sa appka dá spustiť v iPhone režime.
- [ ] **Jazyky obchodu:** appka je po anglicky, takže listing v angličtine. Slovenčinu môžeme pridať neskôr.

**Práca v kóde (zoznam pre Claude)**
- [x] **Spurtly Pro:** nákup v appke, obrazovka s ponukou, obnovenie nákupu a uplatnenie kódu. Pozri 6.4.
- [x] **Android: foreground služba počas tréningu.** Android 16+ stlmí zvuk appiek na pozadí bez foreground služby (overené na emulátore: `AudioHardening … would be muted`). Služba má trvalú notifikáciu s odpočítavaním a s Pro aj tlačidlá Pause a Skip, teda androidovú obdobu Live Activity. Pozri 4.3.
- [x] **Android: release podpisovanie** z `android/key.properties`. Kým súbor neexistuje, release build sa podpíše debug kľúčom. Pozri 4.1.
- [x] **iOS: `ITSAppUsesNonExemptEncryption = NO`** v `ios/Runner/Info.plist`. Appka nepoužíva vlastné šifrovanie, takže sa App Store pri každom uploade nebude pýtať na exportné povolenie.
- [x] **iOS: privacy manifest** `ios/Runner/PrivacyInfo.xcprivacy`: žiadne sledovanie, žiadne zbierané dáta a dôvod pre `UserDefaults` (`CA92.1`), ktorý používa `shared_preferences`.
- [ ] **Testovanie na reálnych zariadeniach:** tvoj iPhone („Hans“) a aspoň jeden Android telefón. Treba overiť zvuky pri zamknutej obrazovke, vibrácie, Live Activity a jej tlačidlá a notifikáciu na Androide. Simulátor zvuky ani vibrácie neoverí.
- [ ] **Zmazanie predvolených dát pri prvom spustení:** netreba, nová inštalácia začína s tromi predvoľbami.

**Mimo kódu**
- [ ] **Zásady ochrany súkromia (privacy policy)** na verejnej URL, napr. na webe CodeMIT alebo cez GitHub Pages. Oba obchody ju vyžadujú. Text je krátky: appka nezbiera žiadne osobné údaje, všetko ostáva v telefóne, bez analytiky a reklám.
- [ ] **Support URL** (App Store ju vyžaduje) a kontaktný e-mail.
- [ ] **Zmluvy, banka a dane pre predaj** v oboch obchodoch, pozri 6.3. Bez nich nefunguje nákup ani v testovaní.
- [ ] **Screenshoty a texty** do obchodov, pozri kapitolu 5.

## 2. Účty a právne náležitosti

### D-U-N-S číslo (pre organizáciu)
Apple aj Google ho pri organizačnom účte vyžadujú.
1. Over, či ho CodeMIT, s.r.o. už nemá. Apple má vyhľadávač na developer.apple.com → Enroll → D-U-N-S lookup.
2. Ak nie, požiadaj o bezplatné pridelenie cez Apple (Dun & Bradstreet). Trvá to **zvyčajne 1–2 týždne**, preto začni čo najskôr.

### Apple Developer Program
1. developer.apple.com/programs/enroll → **Organization**. Treba D-U-N-S, právny názov firmy, webstránku firmy a oprávnenie konať za firmu.
2. Poplatok je 99 USD ročne. Overenie trvá od pár dní po ~2 týždne.
3. Potom zisti, či tím `TR23TL5S42` nastavený v projekte je firemný. Ak je to tvoj osobný tím, v Xcode prepni oba targety na tím CodeMIT (pozri 3.1).

### Google Play Console
1. play.google.com/console → nový účet → typ **Organization**. Treba D-U-N-S, overenie identity a firmy a 25 USD.
2. Overenie trvá niekoľko dní.

### EÚ: obchodník podľa DSA (trader status)
Oba obchody pri distribúcii v EÚ chcú vyhlásenie, či si „trader“. Firma je trader, takže v obchode sa verejne zobrazí adresa, e-mail a telefón firmy. Treba to vyplniť v App Store Connect (Business → Digital Services Act) aj v Play Console (Account details).

## 3. iOS / App Store

### 3.1 Podpisovanie
Najjednoduchšie je **automatické podpisovanie v Xcode**:
1. Otvor `ios/Runner.xcworkspace` v Xcode.
2. Pre targety **Runner** aj **SpurtlyLiveActivity** nastav v *Signing & Capabilities* → *Team* tím CodeMIT a zapni **Automatically manage signing**.
3. Xcode sám:
   - zaregistruje App ID `sk.codemit.spurtly` a `sk.codemit.spurtly.LiveActivity`,
   - vytvorí distribučný certifikát a provisioning profily.

Žiadne ďalšie capabilities v portáli netreba:
- Background audio je len kľúč v `Info.plist` (`UIBackgroundModes: audio`).
- Live Activities sú `NSSupportsLiveActivities`.
- Notifikácie sú len lokálne, push nepoužívame.

### 3.2 Záznam v App Store Connect
appstoreconnect.apple.com → *Apps* → **+** → *New App*:
- **Platform:** iOS
- **Name:** Spurtly. Musí byť v App Store unikátny; pri kontrole v októbri 2026 bol voľný.
- **Primary language:** English
- **Bundle ID:** `sk.codemit.spurtly`
- **SKU:** napr. `spurtly-ios`
- **User access:** Full access

Potom vyplň:
- **Category:** Health & Fitness, prípadne vedľajšia Sports.
- **Age rating** dotazník: nič rizikové, vyjde najnižšia kategória.
- **App Privacy:** „**Data Not Collected**“. Appka nič neposiela, nastavenia a tréningy sú len v telefóne.
- **Pricing and Availability:** cena appky **Free** a krajiny. Spurtly Pro sa zakladá zvlášť ako In-App Purchase (6.5).
- **Privacy Policy URL** a **Support URL**.

### 3.3 Verzia a build
- Verzia je v `pubspec.yaml`: `version: 1.0.0+1`. Prvá časť je verzia v obchode (`CFBundleShortVersionString`), číslo za `+` je build (`CFBundleVersion`).
- **Každý upload musí mať vyššie číslo buildu**, aj keď verzia ostáva rovnaká.
- Live Activity rozšírenie berie verziu z tých istých Flutter premenných, takže sa zhoduje automaticky.

### 3.4 Build a upload
```bash
flutter build ipa --release
```
- Vytvorí `build/ios/archive/Runner.xcarchive` a `build/ios/ipa/Spurtly.ipa`.
- Upload: najjednoduchšie cez appku **Transporter** z Mac App Store (pretiahneš `.ipa`), alebo v Xcode *Window → Organizer → Archives → Distribute App → App Store Connect*.
- Pri problémoch s podpisom ide build ručne v Xcode: *Product → Archive* so schémou Runner a release konfiguráciou.

### 3.5 TestFlight
- **Interní testeri** (až 100 ľudí s prístupom do App Store Connect) dostanú build hneď po spracovaní, zvyčajne do 15–30 minút.
- **Externí testeri** (až 10 000, cez e-mail alebo verejný link) potrebujú krátku Beta App Review.
- Na TestFlighte over na reálnom iPhone hlavne: zvuky pri zamknutej obrazovke, Live Activity a jej tlačidlá, notifikácie a vibrácie.

### 3.6 Odoslanie na review
1. V App Store Connect vytvor verziu 1.0. Vyber build a vyplň popis, kľúčové slová, screenshoty a „What's New“ (pri v1 netreba).
2. **App Review Information → Notes**. Treba vopred vysvetliť background audio a Live Activity. Návrh textu:
   > Spurtly is an interval timer. During a workout it plays audible cues (work, rest, finish and a 3-2-1 countdown), including while the screen is locked, which is why it uses the audio background mode. The audio session is only active while a workout is running. The Live Activity shows the current phase and lets the user pause, resume or skip a phase from the lock screen. To test: tap the play button on "Tabata", lock the phone and listen for the cues; use the Pause and Skip buttons on the lock screen. No account or login is needed.
   >
   > Spurtly Pro (spurtly_pro) is a one-time, non-consumable In-App Purchase that unlocks unlimited custom workouts and the Live Activity lock-screen controls. Its screen opens from Settings › Spurtly Pro, or when creating a fourth workout; it shows the price, a Buy button, Restore Purchases and Redeem Code.
3. Riziko: Apple niekedy zamietne appku podľa pravidla 2.5.4, ak pozadie využíva len kvôli tichému zvuku. Naše zvuky sú však počuteľné a sú hlavnou funkciou appky, a presne to treba v poznámkach zdôrazniť. Ak by aj tak zamietli, odpoveď je v Resolution Center s rovnakým vysvetlením, prípadne s videom.
4. Review trvá obvykle 1–2 dni. Vydanie môže byť automatické, manuálne alebo postupné (phased release na 7 dní).

## 4. Android / Google Play

### 4.1 Upload kľúč a podpisovanie
1. Vygeneruj upload kľúč. **Raz, a bezpečne ho zálohuj** (heslo do password managera, súbor mimo repa):
   ```bash
   keytool -genkey -v -keystore ~/keys/spurtly-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Vytvor `android/key.properties`. Súbor je v `.gitignore`, do gitu sa nedostane:
   ```properties
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/Users/martin/keys/spurtly-upload.jks
   ```
3. `android/app/build.gradle.kts` už údaje z `key.properties` číta (hotové). Kým súbor neexistuje, release build sa podpíše debug kľúčom, aby `flutter run --release` fungoval aj bez neho. **Pred uploadom do Play over**, že `key.properties` existuje, inak by išiel do obchodu debug podpis (Play ho odmietne).
4. **Play App Signing:** pri prvom nahratí App Bundle ho Play Console zapne automaticky.
   - Google drží finálny podpisový kľúč, ty len **upload kľúč**.
   - Keď upload kľúč stratíš, dá sa cez podporu vymeniť. Bez Play App Signing by to nešlo.

### 4.2 Verzia
Rovnako ako pri iOS: `version: 1.0.0+1` v `pubspec.yaml`.
- `1.0.0` je `versionName`.
- `1` je `versionCode`, ktorý musí pri každom uploade rásť.

### 4.3 Foreground služba (treba pred vydaním)
- **Prečo:** Android 16+ stlmí zvuk appky na pozadí bez foreground služby, takže zvuky pri zamknutej obrazovke by nemuseli hrať. Zároveň systém appku nezabije pri dlhom tréningu.
- **V kóde (hotové):** `android/app/src/main/kotlin/.../WorkoutService.kt`.
  - Služba typu `mediaPlayback` beží počas tréningu. Spúšťa ju rovnaký kanál `spurtly/live_activity` ako Live Activity na iPhone.
  - Povolenia `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` a `POST_NOTIFICATIONS` v manifeste.
  - Trvalá notifikácia s fázou, odpočítavaním, ďalšou fázou a zostávajúcim časom počas pauzy.
  - S Pro má tlačidlá **Pause/Resume** a **Skip** a na Androide 16+ je to „Live Update“: čip s odpočítavaním v stavovom riadku (povolenie `POST_PROMOTED_NOTIFICATIONS`).
  - Overené na emulátore s Androidom 17: služba beží ako `mediaPlayback`, tlačidlá ovládajú časovač, po skončení tréningu notifikácia zmizne.
- **Play Console:** v *App content* → **Foreground service permissions** treba deklarovať typ `mediaPlayback`. Popis: „audible workout cues during a running interval timer“. Môže sa vyžadovať aj krátke video.

### 4.4 Build
```bash
flutter build appbundle --release
```
- Vytvorí `build/app/outputs/bundle/release/app-release.aab`.
- Pred nahratím ho otestuj na telefóne. Release build Flutter skracuje a obfuskuje (R8), čo môže odhaliť chyby, ktoré v debug builde nie sú:
  ```bash
  flutter build apk --release
  ```
  ```bash
  flutter install --release
  ```

### 4.5 Založenie appky v Play Console
*Create app*: Name **Spurtly**, Default language English, App (nie hra), **Free**, súhlas s pravidlami. Nákup Pro sa zakladá zvlášť ako produkt (6.5). Appka v obchode automaticky dostane označenie „Contains in-app purchases“.

V **App content** treba vyplniť všetky formuláre:
- **Privacy policy:** URL.
- **App access:** „All functionality is available without special access“, appka nemá prihlásenie.
- **Ads:** „No, my app does not contain ads“.
- **Content rating:** dotazník IARC, vyjde PEGI 3 / Everyone.
- **Target audience:** 18+ alebo 13+. Nie deti, inak platia prísnejšie pravidlá pre rodiny.
- **Data safety:** „No data collected“, „No data shared“. Platbu spracúva Google Play, appka údaje o nákupe nikam neposiela.
- **Health apps:** appka v kategórii Health & Fitness musí vyplniť deklaráciu. Zaškrtni fitness/cvičenie, appka nemá medicínske funkcie.
- **Foreground service permissions:** pozri 4.3.
- **Government apps / Financial features / News:** nie.

V **Store settings** vyber kategóriu **Health & Fitness** a vyplň kontaktný e-mail (a web).

### 4.6 Store listing (Main store listing)
Názov, krátky a plný popis, ikona 512 × 512, feature graphic 1024 × 500 a screenshoty z telefónu. Pozri kapitolu 5.

### 4.7 Testovacie trate a vydanie
1. **Internal testing:** až 100 testerov cez e-mail, build je dostupný do pár minút. Na prvé overenie release buildu.
2. **Closed testing:**
   - Pri **osobnom** účte (založenom po 13. 11. 2023) je povinné: aspoň **12 testerov musí byť prihlásených 14 dní za sebou**, až potom sa odomkne produkcia. Keď počet klesne pod 12, 14 dní sa počíta odznova.
   - **Organizačný účet (D-U-N-S) túto povinnosť nemá.** To je ďalší dôvod ísť cez CodeMIT.
3. **Production:** odoslanie na review. Prvá kontrola novej appky trvá od pár dní po ~týždeň, ďalšie bývajú rýchlejšie. Odporúčam **postupné vydanie** (staged rollout, napr. 20 % → 100 %).

## 5. Podklady do obchodov

### Texty (návrh, angličtina)
- **Name:** Spurtly
- **Subtitle (App Store, 30 znakov):** `HIIT & Tabata interval timer`
- **Short description (Google Play, 80 znakov):** `Interval timer for HIIT and Tabata with sounds, rounds and lock-screen controls.`
- **Keywords (App Store, 100 znakov):** `hiit,tabata,interval,timer,workout,emom,circuit,rest,rounds,boxing,fitness,training,stopwatch`
- **Description (spoločný základ):**
  > Spurtly is a clean, focused interval timer for HIIT, Tabata and circuit training.
  >
  > • Start in one tap with HIIT 1:1, HIIT 2:1 or Tabata — or build your own: warm-up, work, rest, intervals per round, rounds and an optional longer rest between rounds.
  > • Distinct sounds for work, rest and the finish, plus a 3-2-1 countdown. Cues play over your music and keep going with the screen locked.
  > • Big, colour-coded countdown you can read from across the room.
  > • Control the timer from the lock screen and Dynamic Island with Live Activities (iPhone).
  > • Duplicate, rename and fine-tune your workouts; everything is saved on your phone.
  > • No account, no ads, no tracking.
  >
  > Spurtly Pro — a one-time purchase, no subscription:
  > • Unlimited custom workouts, duplicate and tweak any of them.
  > • Lock-screen and Dynamic Island controls: pause, resume or skip without unlocking (iPhone), notification controls (Android).
  > • Every future Pro feature included.

### Grafika
| | App Store | Google Play |
|---|---|---|
| Ikona | 1024 × 1024 (už je v projekte, Xcode ju pridá do buildu) | 512 × 512 PNG, nahrať zvlášť |
| Screenshoty | 6,9" iPhone **1320 × 2868** (alebo 1290 × 2796), 3 až 10 kusov | telefón, min. 2 kusy (napr. 1080 × 2400 až 1440 × 3200) |
| iPad | len ak ostane podpora iPadu: 13" **2064 × 2752** | – |
| Feature graphic | – | **1024 × 500** |

**Ako ich spraviť:**
- iOS: simulátor **iPhone 17 Pro Max** (6,9"), screenshot cez `xcrun simctl io booted screenshot`.
- Android: emulátor Pixel cez `adb exec-out screencap -p`.
- **Odporúčané zábery:**
  1. zoznam tréningov,
  2. editor tréningu,
  3. časovač vo fáze Work,
  4. časovač vo fáze Rest,
  5. Live Activity na zamknutej obrazovke,
  6. obrazovka „Done“,
  7. obrazovka Spurtly Pro. App Store ju vyžaduje aj ako „review screenshot“ pri nákupe v appke.
- Do screenshotov sa oplatí pridať krátky nadpis, napríklad „Start in one tap“, „Lock-screen controls“. Môže ich pripraviť Claude.
- Feature graphic: logo a názov na tmavomodrom pozadí s koralovo-tyrkysovým pruhom (dashes a dots z loga). Vie ho vygenerovať skript podobný `tool/make_logo.py`.

## 6. Spurtly Pro – jednorazové odomknutie

### 6.1 Čo je zadarmo a čo v Pro (návrh, treba potvrdiť)
| Zadarmo | Spurtly Pro (jednorazovo) |
|---|---|
| 3 tréningy (HIIT 1:1, HIIT 2:1, Tabata), dajú sa ľubovoľne upravovať | **Neobmedzený počet vlastných tréningov**, duplikovanie |
| Celý časovač: warm-up, intervaly, kolá, rest medzi kolami | **Live Activity a Dynamic Island** s Pause/Resume a Skip (iPhone) |
| Zvuky, 3-2-1, vibrácie, zvuky aj pri zamknutej obrazovke | **Notifikácia s tlačidlami** Pause a Skip (Android) |
| Základná notifikácia s aktuálnou fázou | **Všetky budúce Pro funkcie**: história, štatistiky, Apple Health / Health Connect |

**Princíp:** bezplatná verzia je plnohodnotný časovač, takže ľudia ju nebudú hodnotiť ako „orezanú“. Pro pridáva pohodlie a prispôsobenie.

Zvuky na pozadí a foreground služba na Androide musia ostať zadarmo. Bez nich by časovač pri zamknutej obrazovke nefungoval.

### 6.2 Cena
- Návrh: **4,99 €** (4,99 USD) jednorazovo. Bežné odomknutia časovačov stoja 2,99–6,99 €.
- Ceny pre ostatné krajiny obchody prepočítajú podľa svojich cenových hladín. Neskôr sa dá spraviť úvodná zľava.
- Orientačne na Slovensku: zo 4,99 € odpočítaj DPH 23 % (zostane 4,06 €) a 15 % províziu, takže firme ostane **~3,45 €** za nákup. DPH sa líši podľa krajiny zákazníka.

### 6.3 Zmluvy, banka a dane
**Apple (App Store Connect → Business):**
1. **Paid Applications Agreement** podpisuje Account Holder.
2. **Banka:** IBAN CodeMIT, s.r.o.
3. **Daňové formuláre:** pre slovenskú s.r.o. dotazník spravidla vedie k **W-8BEN-E**. Po odoslaní sa už nedá meniť, preto výber formulára a zmluvné výhody (zmluva SR–USA) konzultuj s účtovníčkou.
4. **Small Business Program:** treba sa prihlásiť na developer.apple.com/app-store/small-business-program. Provízia je potom **15 %** namiesto 30 %. Noví vývojári sa kvalifikujú, pri prihláške treba uviesť aj prepojené vývojárske účty.

Bez aktívnej Paid Applications Agreement sa produkty nenačítajú ani v sandboxe a TestFlighte.

**Google (Play Console → Setup → Payments profile):**
1. Založ platobný profil firmy (merchant) a prepoj ho s vývojárskym účtom.
2. Vyplň banku a daňové údaje.
3. Provízia 15 % z prvého 1 mil. USD ročne sa uplatní automaticky.

**Oba obchody** sú voči zákazníkovi predajcom a v EÚ samy odvádzajú DPH. Výplaty chodia mesačne. Ako ich zaúčtovať (podklady od Apple a Google, prenesenie daňovej povinnosti) treba vyjasniť s účtovníčkou.

### 6.4 Technické riešenie (hotové)
- **Plugin:** oficiálny Flutter `in_app_purchase` (StoreKit 2 na iOS, Play Billing na Androide). Pre jeden jednorazový produkt netreba vlastný server ani RevenueCat. Ten by dával zmysel až pri predplatnom.
- **ID produktu** je na oboch platformách `spurtly_pro`.
- **Služba na nároky (entitlements):**
  - Pri štarte načíta produkt s lokalizovanou cenou, počúva nákupy a dokončí ich.
  - Stav „Pro odomknuté“ si uloží aj lokálne, aby appka fungovala offline.
  - Pri štarte overí nárok v obchode, aby sa prejavilo aj vrátenie peňazí (refund).
- **Obrazovka Spurtly Pro:**
  - čo Pro obsahuje a cena z obchodu,
  - tlačidlo **Buy**,
  - **Restore Purchases**, ktoré Apple pri jednorazových nákupoch vyžaduje,
  - **Redeem Code** na uplatnenie kódu z 6.6.
- **Kde sa ponuka ukáže:**
  - pri „New workout“ alebo „Duplicate“, keď už má používateľ 3 tréningy,
  - Live Activity na iPhone sa bez Pro nespustí, appka namiesto nej použije bežnú notifikáciu,
  - tlačidlá v androidovej notifikácii len s Pro,
  - v nastaveniach riadok „Spurtly Pro“ so stavom, kúpou, obnovením a kódom.
- **Nesmie sa:** vlastné odomykacie kódy, skryté prepínače alebo odomknutie mimo obchodu. Porušuje to Apple pravidlo 3.1.1 aj platobné pravidlá Google Play. Zadarmo sa dá Pro dať len cez mechanizmy obchodov (6.6).
- **Známe riziko:** na fóre Apple sa v roku 2026 objavili hlásenia, že `in_app_purchase` 3.2.x s Xcode 26.4 niekedy po nákupe nevráti nárok. Preto otestovať na reálnom iPhone cez TestFlight a mať funkčné tlačidlo Restore Purchases.
- **Kde to je v kóde:**
  - `lib/services/pro.dart` (`StorePro`): produkt, nákup, obnovenie, kód, lokálna cache `pro_v1` a kontrola v obchode pri štarte. Na iPhone kontrola pri štarte číta `Transaction.currentEntitlements`, takže sa nepýta na Apple ID. Až tlačidlo Restore purchase robí `AppStore.sync()`.
  - `lib/screens/pro_sheet.dart`: obrazovka Spurtly Pro.
  - Obmedzenia: `home_screen.dart` (nový a duplikovaný tréning), `timer_screen.dart` (Live Activity, tlačidlá v notifikácii), `settings_sheet.dart` (riadok Spurtly Pro).
  - Testy: `test/pro_test.dart` (logika nákupu s falošným obchodom), `test/widget_test.dart` (obmedzenia a obrazovka Pro).

### 6.5 Založenie produktu v obchodoch
**App Store Connect:** v appke Monetization → In-App Purchases → **+**:
1. Type: **Non-Consumable**.
2. Reference name „Spurtly Pro“, Product ID `spurtly_pro`.
3. Cena (4,99 €) a dostupnosť.
4. Lokalizácia: display name „Spurtly Pro“, popis „Unlimited workouts and lock-screen controls“.
5. Review screenshot obrazovky Pro a krátka poznámka pre recenzenta.
6. **Family Sharing:** odporúčam zapnúť, ľudia to oceňujú. Pri jednorazovom nákupe sa však raz zapnuté už nedá vypnúť.
7. **Prvý nákup v appke sa musí odoslať na review spolu s verziou appky.** Na stránke verzie ho vyber v sekcii In-App Purchases.

**Google Play Console:**
1. Najprv nahraj do ľubovoľného kanála (stačí Internal testing) build, ktorý už obsahuje Play Billing. Skôr Play nedovolí produkt založiť.
2. Monetize with Play → Products → **One-time products** → Create:
   - product ID `spurtly_pro`, názov a popis,
   - purchase option typu **Buy** s cenou,
   - **Activate**.

### 6.6 Pro zadarmo pre konkrétnych ľudí
Odomknutie je naviazané na Apple ID alebo Google účet a po uplatnení kódu platí natrvalo, rovnako ako kúpa.

**iPhone:**
- **Offer codes:** pri produkte `spurtly_pro` založíš kampaň s bezplatnou ponukou.
  - Buď **jednorazové kódy** (vygeneruje ich Apple, každý pre jedného človeka), alebo **vlastný kód** (napr. `SPURTLYFRIENDS`) s limitom použití.
  - Kódy treba uplatniť do ich platnosti (max. ~6 mesiacov od vytvorenia).
  - Uplatnenie: v App Store (profil → Redeem Gift Card or Code), cez Redeem Code v appke alebo cez odkaz.
- **Family Sharing:** tvoja rodina (až 5 ľudí) dostane Pro automaticky.
- **TestFlight:** nákupy sú zadarmo (sandbox), ale len v testovacích buildoch. Nie je to trvalý prístup.

**Android:**
- **Promo kódy:** Play Console → promo kódy pre one-time produkt `spurtly_pro`.
  - Doteraz platil limit 500 kódov za štvrťrok na appku.
  - Uplatnenie: Play Store → Payments & subscriptions → Redeem code, alebo odkaz `https://play.google.com/redeem?code=KÓD`.
- **License testers** (Setup → License testing): Google účty, ktoré nakupujú testovacou kartou, teda zadarmo, vo všetkých tvojich appkách. Sú určené na testovanie, hodia sa pre teba a tím.
- **Family Library:** ak ju zapneš, Pro dostane aj tvoja rodina.

**Odporúčanie:** pre seba a rodinu Family Sharing / Family Library, prípadne license tester. Pre kamarátov a testerov offer kódy a promo kódy.

### 6.7 Testovanie nákupu
- **Pro bez obchodu (len debug build):** `flutter run --dart-define=SPURTLY_PRO=true` zapne Pro na skúšanie funkcií. V release builde prepínač nefunguje (`kDebugMode`).
- **iOS lokálne:** `ios/Runner/Spurtly.storekit` je StoreKit Configuration s produktom `spurtly_pro` za 4,99 € a schéma `Runner` ho používa pri Run.
  - Funguje len pri spustení **z Xcode** (`open ios/Runner.xcworkspace` → Run). `flutter run` ho nepoužije a obrazovka Pro ukáže, že App Store nie je dostupný.
  - Ak by ho Xcode nenašiel: Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration → `Spurtly.storekit`.
  - Nákupy v ňom sa dajú mazať a refundovať v Xcode: Debug → StoreKit → Manage Transactions.
- **iOS sandbox:**
  - App Store Connect → Users and Access → **Sandbox testers**,
  - na iPhone Nastavenia → Vývojár → Sandbox účet,
  - nákupy v TestFlighte idú cez sandbox a sú zadarmo.
- **Android:** license testers a kanál Internal testing. Pri nákupe sa ukáže testovacia karta („always approves“ / „always declines“).
- **Scenáre:**
  - kúpa,
  - zrušená kúpa,
  - obnovenie po preinštalovaní,
  - druhé zariadenie s rovnakým účtom,
  - štart bez internetu,
  - vrátenie peňazí (Pro po ďalšom štarte zmizne),
  - uplatnenie kódu.

### 6.8 Review a podmienky
- **Apple** pri review nákup reálne vyskúša v sandboxe. Obrazovka Pro musí jasne ukázať, čo nákup obsahuje, a cenu, a musí mať Restore. Popis v obchode má Pro spomenúť (je v návrhu v kapitole 5).
- **Ochrana súkromia:** App Privacy ostáva „Data Not Collected“. Nákup spracúva Apple a Google, appka údaje o nákupe nikam neposiela. Ak by sme neskôr pridali RevenueCat alebo analytiku, treba to zmeniť.
- Pre jednorazový nákup platia štandardné podmienky Apple (Standard EULA). Vlastné podmienky použitia netreba, tie sú povinné až pri predplatnom.

## 7. Ďalšie vydania (postup)
1. Zvýš verziu v `pubspec.yaml`, napr. `1.0.1+2`. Build číslo musí rásť vždy.
2. `flutter analyze`, `flutter test`, rýchly test na telefóne.
3. iOS: `flutter build ipa --release` → Transporter → TestFlight → nová verzia v App Store Connect s textom „What's New“.
4. Android: `flutter build appbundle --release` → Internal testing → Production (postupné vydanie).
5. Commit a push do `main`, prípadne tag `v1.0.1`.

## 8. Automatizácia (neskôr, voliteľné)
Keď bude vydaní viac, oplatí sa automatizovať build a upload:
- **fastlane** (lokálne alebo v CI): `match` na iOS certifikáty, `pilot` na TestFlight, `supply` na Google Play.
- **Codemagic** (CI zamerané na Flutter, macOS stroje v cene) alebo **GitHub Actions** s macOS runnerom.
- **Tajné údaje do CI secrets, nikdy do repa:**
  - App Store Connect API kľúč (`.p8`),
  - Google Play service account JSON,
  - upload keystore a jeho heslá.

## 9. Orientačný harmonogram
| Krok | Trvanie |
|---|---|
| D-U-N-S (ak ho firma nemá) | 1–2 týždne, **začať hneď** |
| Overenie Apple Developer a Google Play organizácie | pár dní až 2 týždne (paralelne) |
| Foreground služba na Androide, release podpis, privacy manifest | hotové |
| Spurtly Pro: nákup v appke, obrazovka Pro, obmedzenia, testy | hotové, chýba test s obchodmi (6.7) |
| Zmluvy, banka a dane pre predaj (Apple aj Google) | 1–3 dni (paralelne) |
| Privacy policy, screenshoty, texty | 1 deň |
| TestFlight a interné testovanie | ~1 týždeň reálneho používania |
| App Review (iOS) | 1–2 dni |
| Google Play review prvej verzie | pár dní až ~1 týždeň |

Realisticky **3–4 týždne** od začiatku, väčšinou čakania na overenie účtov.

## Zdroje
- Google Play, požiadavka na target API: https://developer.android.com/google/play/requirements/target-sdk
- Google Play, foreground služby: https://support.google.com/googleplay/android-developer/answer/13392821
- Apple, minimálne SDK od apríla 2026 (zhrnutie): https://expo.dev/blog/app-store-connect-minimum-sdk-26
- Flutter, vydanie pre iOS: https://docs.flutter.dev/deployment/ios
- Flutter, vydanie pre Android: https://docs.flutter.dev/deployment/android
- Apple, Small Business Program: https://developer.apple.com/app-store/small-business-program/
- Apple, daňové formuláre v App Store Connect: https://developer.apple.com/help/app-store-connect/provide-tax-information/tax-forms-overview
- Apple ruší promo kódy na nákupy v appke, nahrádzajú ich offer codes: https://www.bgr.com/2011787/apple-retire-in-app-purchase-promo-codes/
- Google Play, one-time produkty: https://support.google.com/googleplay/android-developer/answer/16430488
- Google Play, promo kódy: https://support.google.com/googleplay/android-developer/answer/6321495
- Google Play, testovanie nákupov (license testers): https://www.revenuecat.com/guides/google-play-billing/testing-your-integration
- Flutter `in_app_purchase`: https://pub.dev/packages/in_app_purchase
