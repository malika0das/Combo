import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad configuration.
///
/// Google test unit IDs are used by default so the app never serves live ads
/// during development (serving live ads on a dev build is an AdMob policy
/// violation). Replace the `real*` constants with your own unit IDs and build
/// with `--dart-define=USE_REAL_ADS=true` for release.
class AdIds {
  static const bool useReal = bool.fromEnvironment(
    'USE_REAL_ADS',
    defaultValue: false,
  );

  // TODO: replace with your real AdMob unit IDs before publishing.
  static const String realBannerAndroid =
      'ca-app-pub-0000000000000000/0000000000';
  static const String realInterstitialAndroid =
      'ca-app-pub-0000000000000000/1111111111';

  static const String testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';

  static String get banner => useReal ? realBannerAndroid : testBannerAndroid;
  static String get interstitial =>
      useReal ? realInterstitialAndroid : testInterstitialAndroid;
}

class AdsService extends ChangeNotifier {
  bool _initialized = false;
  bool _initializing = false;
  bool _personalized = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  InterstitialAd? _interstitial;

  /// Ad handed to the platform but still inside the post-frame + delay window
  /// before [InterstitialAd.show] actually runs. Tracked separately so a
  /// dispose during that window still tears the ad down instead of leaking it.
  InterstitialAd? _showing;

  /// True while an [InterstitialAd.load] is in flight. Serialises preloads:
  /// two overlapping loads would otherwise let the later one orphan the first
  /// loaded ad, which is never shown and never disposed.
  bool _preloading = false;

  /// Set once the service is torn down; in-flight load callbacks check this to
  /// dispose their ad instead of resurrecting it into a dead service.
  bool _disposed = false;
  int _navCount = 0;
  DateTime? _lastInterstitial;

  /// Show an interstitial at most every N qualifying navigations, and never
  /// on app open / back press. Keeps UX clean and Play-policy safe.
  static const int interstitialEvery = 6;

  /// Hard floor between two interstitials. Without this, six quick taps could
  /// stack ads back to back, which is both hostile and a policy risk.
  static const Duration interstitialCooldown = Duration(minutes: 2);

  // defaultTargetPlatform instead of dart:io's Platform, so this file also
  // compiles for web (where dart:io does not exist and ads never load).
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// True only once the SDK is up *and* consent allows an ad request. Every ad
  /// widget must gate on this, not merely on initialisation.
  bool get initialized => _initialized && _canRequestAds;

  /// Whether to show the "Privacy options" entry in Settings. Google requires
  /// a persistent way for EEA/UK users to change their consent choice.
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// Gathers GDPR/ePrivacy consent through Google's User Messaging Platform
  /// before any ad is requested. Serving ads in the EEA or UK without this is
  /// an AdMob policy violation and a common Play review rejection.
  Future<void> _gatherConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((error) {
            if (error != null) {
              debugPrint('Consent form error: ${error.message}');
            }
          });
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (error) {
        debugPrint('Consent info error: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    // Never let a slow or failed consent round-trip hang startup.
    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );

    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      _privacyOptionsRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      // If consent state cannot be read, stay silent rather than risk serving
      // a non-compliant ad.
      _canRequestAds = false;
    }
  }

  /// Re-opens the consent form so a user can change their choice later.
  Future<void> showPrivacyOptions() async {
    if (!supported) return;
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('Privacy options error: ${error.message}');
    });
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    notifyListeners();
  }

  /// Clears consent state. Debug helper for testing the flow repeatedly.
  Future<void> resetConsent() async {
    ConsentInformation.instance.reset();
    _canRequestAds = false;
    notifyListeners();
  }

  Future<void> init({required bool personalized}) async {
    _personalized = personalized;
    if (!supported || _initializing) return;

    _initializing = true;
    try {
      await _gatherConsent();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          ageRestrictedTreatment: AgeRestrictedTreatment.unspecified,
          maxAdContentRating: MaxAdContentRating.g,
        ),
      );
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (error) {
      debugPrint('Ad initialization error: $error');
      _initialized = false;
      _canRequestAds = false;
    } finally {
      _initializing = false;
      notifyListeners();
    }

    if (_initialized && _canRequestAds) _preloadInterstitial();
  }

  void setPersonalized(bool value) {
    _personalized = value;
    notifyListeners();
  }

  AdRequest get request => AdRequest(
    nonPersonalizedAds: !_personalized,
    keywords: const [
      'mobile repair',
      'smartphone spare parts',
      'lcd display',
      'mobile accessories',
    ],
  );

  BannerAd createBanner({required AdSize size, VoidCallback? onLoaded}) {
    return BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: request,
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded?.call(),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
  }

  void _preloadInterstitial() {
    if (!supported || !_initialized || !_canRequestAds) return;
    if (_interstitial != null || _preloading || _disposed) return;
    _preloading = true;

    final future = InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _preloading = false;
          // The service died while the load was in flight; never leave the ad
          // owned by nobody (the classic interstitial memory leak).
          if (_disposed) {
            ad.dispose();
            return;
          }
          _interstitial = ad;
          // Attach the full-screen callback at load time (Google's lifecycle
          // rules): a dismissal or a failed show must always end the ad's life
          // and immediately re-arm the next preload.
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
              _preloadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitial = null;
              _preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _preloading = false;
          _interstitial = null;
        },
      ),
    );
    // Belt-and-braces: if the load future itself fails without a callback,
    // clear the in-flight flag so future navigations can retry. Also prevents
    // the discarded future from surfacing as an unhandled async error.
    unawaited(future.catchError((_) {
      _preloading = false;
      _interstitial = null;
    }));
  }

  /// Call on meaningful navigation events (e.g. opening a group detail).
  void maybeShowInterstitial() {
    if (!supported || !_initialized || !_canRequestAds || _disposed) return;
    _navCount++;
    if (_navCount % interstitialEvery != 0) return;

    final now = DateTime.now();
    final last = _lastInterstitial;
    if (last != null && now.difference(last) < interstitialCooldown) return;

    final ad = _interstitial;
    if (ad == null) {
      _preloadInterstitial();
      return;
    }
    _lastInterstitial = now;
    _interstitial = null;
    // The full-screen callback was already attached at load time, so a
    // dismissal or failed show always disposes and reloads. This field only
    // tracks the hand-off window so [dispose] can tear the ad down mid-delay.
    _showing = ad;

    // Show *after* the current page transition finishes. Firing it inline made
    // the ad and the route animation run at once, which looked like a stutter.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_showing != ad || _disposed) return;
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (_showing != ad || _disposed) return;
        _showing = null;
        unawaited(ad.show());
      });
    });
  }

  @override
  void dispose() {
    _disposed = true;
    // Tear down any ad still inside the pre-show hand-off window.
    final pending = _showing;
    _showing = null;
    pending?.dispose();
    _interstitial?.dispose();
    _interstitial = null;
    super.dispose();
  }
}
