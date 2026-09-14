# Play Console & Copyright Compliance Checklist

Work through this before every release. Items marked **BLOCKER** will get the
app rejected or suspended.

---

## 1. Ads (AdMob / Play Families & Monetisation policy)

| Item | Status |
|---|---|
| UMP consent gathered before the first ad request | Done — `AdsService._gatherConsent()` |
| Ads suppressed entirely when consent is refused | Done — `initialized` returns false unless `canRequestAds` |
| Persistent "Privacy options" control for EEA/UK | Done — Settings, shown when `privacyOptionsRequired` |
| Non-personalised ad toggle | Done — Settings |
| `maxAdContentRating: G` | Done |
| No ads on app open or back press | Done — interstitials only on qualifying navigation |
| Interstitial frequency capped | Done — every 6 navigations **and** a 2 minute cooldown |
| Interstitial never interrupts a task mid-flow | Done — deferred until after the route transition |
| Banner never overlaps or sits flush against tappable controls | Done — zero height until loaded, inside `SafeArea` |
| **BLOCKER** Real AdMob app ID + unit IDs in the release build | **TODO — see below** |

### Setting the real ad IDs

1. In `android/local.properties` (never commit this file) add:
   ```
   admob.appId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
   ```
2. In `lib/services/ads_service.dart` replace `realBannerAndroid` and
   `realInterstitialAndroid` with your real unit IDs.
3. Build with:
   ```
   flutter build appbundle --release --dart-define=USE_REAL_ADS=true
   ```

Shipping Google's sample IDs to production serves no revenue and reads as a
broken app to reviewers. Serving *real* ads from a debug build is an AdMob
policy violation, which is why the flag is opt-in.

---

## 2. Data safety form

Declare exactly this in Play Console:

- **Collected:** none by us.
- **Shared:** Device or other IDs — advertising ID, shared with Google AdMob
  for advertising. Optional, user can opt out in Settings.
- **Stored on device only:** recent searches, saved lists, stock notes, theme
  and text-size preference. Not transmitted.
- **Encrypted in transit:** yes (HTTPS enforced, cleartext disabled).
- **Deletion:** in-app clear controls, plus uninstall.

This must match `store/DATA_SAFETY.md` and the in-app privacy policy word for
word. Mismatches are the single most common rejection cause.

---

## 3. Copyright, trademark and data provenance

**Data provenance.** The catalog is built only from `tools/raw/` — Makund
Mobile's own parts listings plus workshop testing. The `source` field in
`catalog.json` states this. Never credit a domain or database you do not
actually license: a provenance string naming a third party is a written
admission of copying.

> Note: an earlier revision of `catalog.json` also credited a competitor's
> domain in its `source` string even though none of that site's data was ever
> used. That was corrected — never credit a third-party database you do not
> actually license, as it is a written admission of copying.

**Do not** ingest data from any competitor app or site. A compatibility list
is a compiled database and copying one invites a DMCA takedown, which on Play
means immediate suspension.

**Trademarks.** Brand names (Samsung, Xiaomi, Apple, etc.) are used purely
nominatively — to describe which part fits which phone. This is permitted, but
only while all of the following hold:

- No manufacturer logo, wordmark or custom typeface is used anywhere, including
  the icon, feature graphic and screenshots. **Verify before each release.**
- The app name and icon cannot be mistaken for a manufacturer's own app.
- The disclaimer in Terms §4 stays visible in-app and in the listing.

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
- Privacy policy URL must be publicly reachable, not behind a redirect chain,
  and hosted on a domain you control.
- Keep the listing free of unsubstantiated superlatives ("best", "#1",
  "guaranteed compatibility") and of competitor names.
- The accuracy disclaimer must be in the full description, not just in-app.

---

## 6. Technical requirements

- `targetSdk 35` — meets the current Play requirement.
- 64-bit: automatic via App Bundle.
- `AD_ID` permission declared, and its use disclosed in the data safety form.
- No `REQUEST_INSTALL_PACKAGES`, no `QUERY_ALL_PACKAGES`, no background location.
- Cleartext traffic disabled.
