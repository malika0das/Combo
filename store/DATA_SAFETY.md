# Play Console → Data Safety answers

This file is a release checklist, not a substitute for the Play Console form. The
form must describe the exact binary uploaded to Play, including every SDK. The
current app includes Google Mobile Ads, so do not answer “no data collected”.

## SDK source of truth

Google's current Google Mobile Ads disclosure says the SDK automatically collects
and shares IP address, user product interactions, diagnostic information and
device/account identifiers for advertising, analytics and fraud prevention. It
also says the traffic is encrypted in transit. Review the SDK disclosure again
when upgrading `google_mobile_ads`:

- https://developers.google.com/admob/android/privacy/play-data-disclosure
- https://developers.google.com/admob/flutter/privacy

## Data types to review in the Play Console form

For a build with ads enabled, the following SDK data types must be declared and
shared with Google. Map the SDK wording to the Play Console wording as shown:

| Play data type | What Google Mobile Ads may receive | Collected/shared | Purposes |
|---|---|---|---|
| Location → Approximate location | IP address may be used to estimate general location | Yes / shared with Google | Advertising, analytics, fraud prevention |
| App activity → App interactions | App launch, taps and ad/video views | Yes / shared with Google | Advertising, analytics, fraud prevention |
| App info and performance → Diagnostics | App launch time, hang rate and energy usage | Yes / shared with Google | Advertising, analytics, fraud prevention |
| Device or other IDs | Android Advertising ID, App Set ID and applicable account identifiers | Yes / shared with Google | Advertising, analytics, fraud prevention |

Do not declare the app's local searches, saved lists, order notes, theme or
catalog cache as collected by the developer: these remain on the device and are
not transmitted by the app. The ad SDK's app-interaction telemetry is a
separate disclosure and must still be declared.

For the current build:

- **Encrypted in transit:** Yes. HTTPS is required for catalog updates and
  Google's ad SDK uses TLS.
- **User deletion request:** No account exists and there is no server-side user
  profile. Users can clear local app data or uninstall. Google handles ad/SDK
  retention under Google's own policies.
- **Account creation:** No.
- **Target audience:** adults / professional technicians; do not enrol in
  Designed for Families. Answer the target-audience and content-rating forms
  truthfully in Play Console.
- **Permissions:** `INTERNET`, `ACCESS_NETWORK_STATE` and `AD_ID` only. There is
  no location, camera, microphone, contacts, SMS, storage, package-visibility,
  notification or foreground-service permission.

The Android Advertising ID can be reset or deleted in Android settings, and
Google's limited-ad/consent modes can reduce identifier collection. Verify the
“optional” answer in the Play form against the exact ad serving configuration;
do not mark every row optional merely because the user can disable ad
personalisation.

## Consent and prominent disclosure

Before Mobile Ads initializes, the app shows an in-app disclosure naming the
SDK data categories and purposes. The user can continue without ads for that
session. After that disclosure, the Google UMP flow is used when required, and
`canRequestAds()` gates every ad request. A required Privacy options entry point
is kept in Settings so users can revisit consent choices.

## Permissions declared and why

| Permission | Why |
|---|---|
| `INTERNET` | Optional catalog updates and Google Mobile Ads |
| `ACCESS_NETWORK_STATE` | Detect offline state and avoid failed update requests |
| `com.google.android.gms.permission.AD_ID` | Google Mobile Ads advertising identifier when available |

## Release configuration

Release builds must not use Google's sample ad units. Supply live values without
committing them:

```text
flutter build appbundle --release \
  --dart-define=USE_REAL_ADS=true \
  --dart-define=ADMOB_BANNER_ANDROID_ID=ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB \
  --dart-define=ADMOB_INTERSTITIAL_ANDROID_ID=ca-app-pub-XXXXXXXXXXXXXXXX/IIIIIIIIII
```

Also provide the live AdMob **application ID** through
`android/local.properties` (`admob.appId=...`) or CI's
`-PadmobAppId=...`. A release missing a valid live application ID or production signing
configuration fails the Gradle build. A release with missing or malformed unit
IDs disables ad requests at runtime, rather than sending test or placeholder
traffic. Replace the placeholders above locally; do not commit real account
identifiers if your release process keeps them in CI secrets/configuration.
