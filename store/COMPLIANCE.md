# Play Console & Copyright Compliance Checklist

Work through this before every release. Items marked **BLOCKER** will get the
app rejected or suspended.

---

## 1. Ads (AdMob / Play Families & Monetisation policy)

| Item | Status |
|---|---|
| App disclosure shown before the ad SDK initializes | Done — `AdsBootstrap` |
| UMP consent status checked before the first ad request | Done — `AdsService._gatherConsent()` and `canRequestAds()` |
| Consent refusal handled safely | Done — no request when `canRequestAds()` is false; UMP/limited ads may still be allowed when Google returns that status |
| Persistent "Privacy options" control for EEA/UK/Switzerland | Done — Settings, shown when `privacyOptionsRequired` |
| Non-personalised ad toggle | Done — Settings |
| `maxAdContentRating: G` | Done |
| No disruptive interstitials on app open or back press | Done — interstitials only on qualifying navigation |
| Interstitial frequency capped | Done — every 6 navigations **and** a 2 minute cooldown |
| Interstitial never interrupts a task mid-flow | Done — deferred until after the route transition |
| Banner never overlaps or sits flush against tappable controls | Done — zero height until loaded, inside `SafeArea` |
| Release build does not use test/placeholder AdMob IDs | **Guarded in code; live IDs still required before publishing** |

### Setting the real ad IDs

1. In `android/local.properties` (never commit this file), or in CI, provide:
   ```
   admob.appId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
   ```
2. Pass both live unit IDs as build inputs; they are no longer hardcoded in
   `lib/services/ads_service.dart`:
   ```bash
   flutter build appbundle --release \
     --dart-define=USE_REAL_ADS=true \
     --dart-define=ADMOB_BANNER_ANDROID_ID=ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB \
     --dart-define=ADMOB_INTERSTITIAL_ANDROID_ID=ca-app-pub-XXXXXXXXXXXXXXXX/IIIIIIIIII
   ```
3. Verify the generated release bundle with Ad Inspector/test devices before
   uploading it. Never use a real unit ID in a debug build or commit account
   values to Git.

The release guard disables ad requests when live unit values are missing,
rather than shipping Google's sample units or placeholder IDs. The Gradle
configuration also fails a release build when the live application ID is
missing or malformed, or when production signing properties/keystore are
missing. If the Play listing says that the app contains ads, configure the live
IDs before submitting the build.

---

## 2. Data safety form

`store/DATA_SAFETY.md` contains the current answer map. For an ads-enabled
release, review and declare the Google Mobile Ads SDK's automatic collection and
sharing of:

- Approximate location inferred from IP address.
- App activity / app interactions such as launches, taps and ad/video views.
- App info and performance / diagnostics such as launch time, hang rate and
  energy usage.
- Device or other IDs such as Android Advertising ID and App Set ID.

The purposes are advertising, analytics and fraud prevention; the SDK uses TLS.
Do not call the app's local searches, saved lists, order notes, theme or catalog
cache developer-collected data. These remain on-device and are not sent by the
app, but that does not remove the separate SDK disclosures above.

This must match `store/DATA_SAFETY.md`, the actual uploaded binary and the in-app
privacy policy. Re-check every answer after changing an SDK, ad format,
consent mode or network client. The developer must submit the final form in
Play Console; a repository document cannot submit it.

---

## 3. Copyright, trademark and data provenance

**Data provenance.** The catalog is built from the manually maintained files in
`tools/raw/`. Those files record a mixture of workshop/parts records and public
manufacturer or supplier references used for research. Before each release,
verify that the `source` field in `catalog.json` describes that honestly; it
must not claim that third-party material is owned or licensed when it is not.

Before publishing a catalog entry researched from a supplier or manufacturer
page, confirm that the intended use is permitted or replace it with independently
verified compatibility work. Keep only model-specific facts and original
wording; do not copy a competitor's database, descriptions, images or product
feed. A public URL is evidence of where a claim was checked, not permission to
republish its content. Remove source links that you cannot substantiate or
license, and retain a review record for each new compatibility group.

**Trademarks.** Brand names (Samsung, Xiaomi, Apple, etc.) are used purely
nominatively — to describe which part fits which phone. This is permitted, but
only while all of the following hold:

- No manufacturer logo, wordmark or custom typeface is used anywhere, including
  the icon, feature graphic and screenshots. **Verify before each release.**
- The app name and icon cannot be mistaken for a manufacturer's own app.
- The non-affiliation and fitment disclaimers in Terms §§2 and 4 stay visible
  in-app and in the listing.

**Fonts.** Sora, Inter and JetBrains Mono are SIL OFL 1.1.
`assets/google_fonts/OFL.txt` ships with the build (run `tools/fetch_fonts.sh`
if the folder is empty) — the licence requires the notice to be distributed.

**Screenshots.** Use only the app's own UI. No manufacturer press renders, no
stock photos you have not licensed.

---

## 4. App links

The manifest declares **no** App Links / deep links. An `autoVerify` intent
filter for a domain you do not control (or that does not host a valid
`assetlinks.json`) fails verification and is a misrepresentation risk in review.
Only re-add one after you host `.well-known/assetlinks.json` (with the Play App
Signing SHA-256 fingerprint) on a domain you fully control.

---

## 5. Content and store listing

- Content rating questionnaire: answer "no" to all sensitive categories →
  expected rating Everyone / PEGI 3.
- Target audience: adults / professional tool. **Do not** opt into Designed for
  Families — the app contains ads and is not aimed at children.
- Privacy policy URL must be publicly reachable, non-geofenced, non-editable,
  and hosted on a domain you control. `store/PRIVACY_POLICY.md` is the source
  document, not a hosted URL. Candidate after merge (not yet verified):
  `https://github.com/malika0das/Combo/blob/main/store/PRIVACY_POLICY.md`. A
  GitHub Pages URL for this public repository can also be used only after the
  file is merged, published, and verified in an incognito browser; enter the
  final URL manually in Play Console.
- In Play Console, declare that the app contains ads, complete the Data Safety,
  target-audience/content-rating and privacy-policy forms, and keep every
  answer synchronized with the uploaded AAB.
- Keep the listing free of unsubstantiated superlatives ("best", "#1",
  "guaranteed compatibility") and of competitor app/site claims.
- The accuracy disclaimer must be in the full description, not just in-app.

---

## 6. External submission actions — not completed by this repository

These are required from the developer/operator and cannot be guaranteed by a
code change:

- **Host the policy:** publish the final `store/PRIVACY_POLICY.md` at a stable,
  publicly accessible, non-geofenced URL. Verify the URL in an incognito browser
  on mobile and desktop, including its HTTPS certificate and no-login access.
  Enter that exact URL in Play Console; a GitHub file URL is not automatically a
  hosted policy and GitHub Pages must be enabled/configured separately.
- **Configure AdMob:** create/select the production Android app and live banner
  and interstitial units in AdMob Console. Publish the applicable UMP privacy
  messages for the EEA, UK and Switzerland, test consent and limited-ad paths,
  and supply the app/unit IDs through the documented release build inputs.
- **Complete Play Console:** declare “contains ads”, the target audience and
  content rating, Data Safety answers, the privacy-policy URL and app-access
  details. Recheck the answers against the final AAB and SDK versions.
- **Sign the release:** use a valid production keystore and Play App Signing
  setup. Do not use the debug signing key, and keep `android/key.properties`
  and the keystore out of Git and CI logs.
- **Test the production path:** use test devices and Ad Inspector, verify UMP
  forms, privacy options, banners and interstitial timing, and never click live
  ads during testing.

## 7. Technical requirements

- `compileSdk 36` and `targetSdk 36` — meets the Android 16 / API 36
  requirement for new apps and updates submitted from 31 August 2026. Recheck
  Google's target API deadline before each submission.
- 64-bit: automatic via App Bundle.
- `AD_ID` permission declared, and its use disclosed in the data safety form.
- No `REQUEST_INSTALL_PACKAGES`, no `QUERY_ALL_PACKAGES`, no background location.
- Cleartext traffic disabled.
