# Combo Universal — Flutter Android App

Offline-first universal compatibility list (combo/display, battery, frame, power/volume flex, charging sub-board, display connector, back cover, tempered glass and Touch/OCA glass) for mobile repair technicians. 100% self-contained: no hardcoded external URLs, no third-party server, nothing to infringe.

## Features
- **Smart highlight search** across every category at once, with debounce and exact-match ranking.
- **Hybrid data**: ships with a bundled JSON catalog (works offline, instantly), silently upgrades from a remote JSON when a higher `version` is published, and caches it locally.
- Category → brand → list browsing, per-brand filter.
- Save/bookmark lists, recent searches, copy & WhatsApp share of a full list.
- Material 3 UI, dark mode, portrait-locked, no login.
- AdMob adaptive banner + throttled interstitial (1 in 6 navigations), with an in-app personalised-ads toggle.
- In-app privacy policy and disclaimer screens.


**Search that understands how technicians type**
- Ignores spacing and punctuation — `redmi9a`, `Redmi 9-A` and `REDMI  9a` are the same query.
- Brand shorthand and common misspellings are expanded (`rn9pro`, `samsang a10`, `1+`, `moto`).
- Typo tolerance: an exact/substring pass runs first, and only if nothing matches does it fall back to edit-distance matching, so correct spellings never get noisy results.
- Part keywords auto-scope the query — `redmi 9a battery`, `A53 power volume flex`, `V21 display connector` and `Galaxy S25 OCA glass` search their specific categories. Filter chips override it.
- Also matches group codes and battery part numbers (`BN4A`, `EB-BA546ABY`).
- "Did you mean" suggestions when nothing matches, and model autocomplete chips above the results.

**Model profile** — tap any model to see every sourced part mapping that fits it (combo, battery, frame, flex, connector, OCA, tempered glass, charging board or back cover) plus every phone that shares those parts. Directory-only models remain visible but keep an honest pending/no-fitment state. Share or copy the whole parts sheet.

**Compare models** — add two or more phones and instantly see which categories have a single part covering all of them. Decide what to stock before you buy.

**Order list** — add any part list to a cart, attach a note (price, shelf, supplier), then send the whole order to a supplier over WhatsApp in one tap.

**Browse A–Z** — a filterable index of every distinct model in the catalog, for when you are unsure of the exact spelling.

**Shop notes** — a private, on-device note against any part list.

**Proactive UX** — the home screen reads on-device signals (time of day, repeated searches, a waiting order list) and offers the single most useful next step: resume a job you keep searching, send an order that has been sitting, or compare the two phones you just looked up. At most one suggestion at a time, always dismissible, never nagging. All signals stay on the device.

**Emotionally intelligent copy** — a time-aware greeting, and failure states that name what you typed and offer a route forward instead of a dead end. Haptics form a small vocabulary: selection for navigation, light impact for "added", medium for "removed".

**Motion & 3D** — real perspective transforms (`Matrix4` with a perspective term), not shadows faking depth: cards tilt toward your finger, a lit orb rotates in empty states, and two phone silhouettes swing together with a burst when a shared part is found. Lists cascade in, counters roll up, skeletons shimmer while a search debounces.

**Accessibility** — in-app text size slider (85–150%) layered on top of the system setting, plus dark mode. Everything works fully offline. Every animation honours the OS "reduce motion" setting through a single `Motion.reduced` gate.

**Responsive** — content-driven breakpoints at 600 and 905 logical pixels: one column on phones, two on tablets, with page padding that grows and a max content width so model names never stretch into unreadable lines. Orientation is deliberately unlocked for bench use.

## Design system

**Motion** — one scale in `lib/motion.dart` (90 / 180 / 280 / 460 ms) with
`easeOutCubic` in and `easeInCubic` out, so things leave faster than they
arrive. Nothing exceeds 500 ms: this is a tool used with a customer waiting.
Staggered list entrances cap at 12 items so a 1,000-row list never makes the
user wait for a cascade.

**Depth** — `TiltCard` and `DepthOrb` use genuine perspective matrices with a
moving light source and rim lighting, so surfaces read as lit objects rather
than gradient rectangles. Tilt is capped at ~0.16 rad; a bigger angle reads as
a gimmick and hurts legibility.

**Typography** — three Google Fonts, each doing one job:

| Family | Role | Why |
|---|---|---|
| **Sora** | headings, titles, stats | geometric and confident; gives the app its premium, technical feel |
| **Inter** | body, lists, labels | engineered for small sizes and dense UI — this app is mostly lists |
| **JetBrains Mono** | part codes, battery numbers, SKUs | unambiguous `0/O` and `1/l`, which matters when reading `BN4A` off a screen |

The scale in `lib/theme.dart` steps on a ~1.2 ratio with tracking that tightens
as size grows (`-1.2` at display, `+0.6` at label), which is what separates a
designed type system from merely resized text. Line heights are set per role:
1.18 for headings, 1.42 for body.

Fonts are **bundled**, not fetched. `GoogleFonts.config.allowRuntimeFetching`
is off, so the app never makes a network call for type and works fully offline.
Run `bash tools/fetch_fonts.sh` once to populate `assets/google_fonts/`.

**Colour** — a deep indigo-blue brand seed with an amber accent for search
highlights. Each part category carries its own accent (`accentFor`) so the home
grid reads as distinct destinations: battery green, glass cyan, board violet, cover pink,
frame amber, power-flex coral, connector blue and OCA indigo.

**Shared primitives** (`lib/widgets/ui.dart`) keep every screen consistent:
`CodeChip` (tap-to-copy monospaced part code), `SoftBadge`, `SectionHeader`,
`EmptyState` and `VerifyNotice`. Spacing uses the `Gap` scale instead of magic
numbers.

The Android splash background is themed light/dark to match the app, so there
is no colour flash on launch.


## Project layout
```
lib/
  main.dart              app bootstrap (non-blocking init)
  app_scope.dart         InheritedWidget dependency holder
  theme.dart             Material 3 theme
  models/catalog.dart    Catalog/Category/Brand/ComboGroup + simple search
  theme.dart             brand palette, type scale, component themes
  motion.dart            durations, curves, haptics, entrance/press primitives
  responsive.dart        breakpoints, PageBody, AdaptiveCardList
  widgets/ui.dart        CodeChip / SoftBadge / SectionHeader / EmptyState
  widgets/dimensional.dart  TiltCard / DepthOrb / CompatibilityGlyph / burst
  widgets/insight_card.dart proactive suggestion card
  services/insight_service.dart  on-device signals -> next best action
  services/search_engine.dart  typo-tolerant index, autocomplete, model profiles
  screens/model_screen.dart    every part that fits one phone
  screens/compare_screen.dart  shared-part finder for 2+ phones
  screens/models_az_screen.dart A-Z model browser
  screens/stock_screen.dart    order / purchase list
  services/
    catalog_service.dart bundled + cached + remote catalog loading
    prefs_service.dart   recents, bookmarks, theme, ad consent (local only)
    ads_service.dart     AdMob init, banner factory, interstitial throttle
  screens/               home, category/brand, group detail, search, saved, settings, policy
  widgets/               highlight_text.dart, banner_ad_slot.dart
assets/data/catalog.json bundled offline catalog (generated)
tools/raw/*.txt          plain-text source lists (groups plus the recent model directory)
tools/raw/models_current.txt  recent 2024–2026 model names without fitment claims
tools/build_catalog.py   regenerates assets/data/catalog.json from tools/raw/
store/                   Play listing, data safety, privacy policy, terms, icon source
```

## Run it

Fetch the bundled fonts once before the first build:

```bash
bash tools/fetch_fonts.sh
```

```bash
flutter pub get
flutter run
```

Optionally point the app at your own remote catalog (there is no default — without one the app makes zero data requests):
```bash
flutter run --dart-define=CATALOG_URL=https://your-host.example/catalog.json
```

## Before you publish
1. **AdMob IDs** — provide the live app ID through `android/local.properties` (`admob.appId=...`) or `-PadmobAppId=...`, and pass both live unit IDs at release build time with `--dart-define=USE_REAL_ADS=true`, `--dart-define=ADMOB_BANNER_ANDROID_ID=...` and `--dart-define=ADMOB_INTERSTITIAL_ANDROID_ID=...`. Debug builds use Google's test IDs; release builds fail closed rather than shipping sample or placeholder IDs.
2. **Application ID** — currently `com.makund.combouniversal` (`android/app/build.gradle`). The existing Play listing uses `com.makund.combosupport`; use that ID instead if you are updating the same app rather than publishing a new one.
3. **Signing** — create `android/key.properties` (git-ignored) with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
4. **Icon** — `store/icon_source.png` is a 1024px source; generate launcher densities (e.g. with `flutter_launcher_icons`) into `android/app/src/main/res/mipmap-*`.
5. **Privacy policy URL** — publish `store/PRIVACY_POLICY.md` at a public, non-geofenced URL you control, verify it in an incognito browser, and enter the final URL manually in Play Console. The repository file is not itself a hosted policy URL.
6. **Data safety form** — use `store/DATA_SAFETY.md`, then verify every answer against the exact AAB and current SDK disclosures.

Build the release bundle:
```bash
flutter build appbundle --release \
  --dart-define=USE_REAL_ADS=true \
  --dart-define=ADMOB_BANNER_ANDROID_ID=ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB \
  --dart-define=ADMOB_INTERSTITIAL_ANDROID_ID=ca-app-pub-XXXXXXXXXXXXXXXX/IIIIIIIIII
```

## Publishing catalog updates without an app update
Host a JSON file with the same schema as `assets/data/catalog.json` at `CATALOG_URL`, and bump the top-level `version` integer each time you add models. Users get it on next launch or pull-to-refresh — no Play review needed.

## Policy notes baked in
- Minimal permissions: `INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID`. No location/storage/contacts, no `QUERY_ALL_PACKAGES`.
- Cleartext traffic disabled; HTTPS-only network security config.
- `compileSdk 36` and `targetSdk 36` (Android 16; required for new apps and updates submitted from 31 August 2026).
- Interstitials never appear on app open or back press, and banners render only after load — no accidental clicks.
- Trademark disclaimer for brand names included in the listing and in-app terms.

## Tests
```bash
flutter test
```


## Updating the bundled data

The offline catalog currently ships with **1,420 universal lists covering 5,977
compatibility references** across 9 categories: Combo/Display, Battery, Frame /
Middle Frame, Power / Volume Flex, Display Connector, Touch / OCA Glass,
Tempered / Screen Guard, Charging Sub Board and Back Cover. It also includes a
de-duplicated directory of **226 recent 2024–2026 phone names** whose part
compatibility has not yet been verified. Directory-only models are searchable
and clearly shown as awaiting a tested part mapping; they are never presented
as compatible.

Edit the plain-text sources in `tools/raw/` and regenerate:

```bash
python3 tools/build_catalog.py
```

Formats:

- `combo_*.txt`, `glass_*.txt`, `cc_*.txt`, `case_all.txt`, `frame_all.txt`,
  `powerflex_all.txt`, `displayconnector_all.txt` and `oca_all.txt` — one group
  per line, models comma separated. Trailing descriptors such as `Punch Hole
  LCD` are detected automatically and stored as the group note. The new raw
  lists retain supplier URLs and keep display connectors/flexes model-specific;
  OCA glass is intentionally separate from Tempered / Screen Guard glass.
- `battery_*.txt` — `Battery code|Model, Model, Model` per line.
- `models_current.txt` — one recent model per line; comments beginning with `#`
  record manufacturer sources. The builder normalizes and de-duplicates these
  names, then removes names already covered by a compatibility group.
- Lines starting with `Coming Soon` are skipped.

To push an update without a Play release, host the generated JSON at
`CATALOG_URL` and bump its `version`.
