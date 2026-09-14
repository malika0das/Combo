import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_scope.dart';
import 'screens/home_shell.dart';
import 'screens/policy_screen.dart';
import 'services/ads_service.dart';
import 'services/catalog_service.dart';
import 'services/prefs_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts are bundled in assets/google_fonts/, so never reach out to the
  // network for them. Keeps the app fully offline and the Data Safety form
  // free of a runtime-download caveat.
  GoogleFonts.config.allowRuntimeFetching = false;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Orientation is intentionally NOT locked: tablets and foldables on a repair
  // bench are commonly used in landscape, and the layouts are responsive.

  final prefs = PrefsService();
  await prefs.init();

  final catalog = CatalogService();
  final ads = AdsService();

  // Non-blocking: the UI shows bundled data immediately.
  unawaited(catalog.init());

  runApp(ComboUniversalApp(prefs: prefs, catalog: catalog, ads: ads));
}

class ComboUniversalApp extends StatelessWidget {
  const ComboUniversalApp({
    super.key,
    required this.prefs,
    required this.catalog,
    required this.ads,
  });

  final PrefsService prefs;
  final CatalogService catalog;
  final AdsService ads;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      catalog: catalog,
      prefs: prefs,
      ads: ads,
      child: AnimatedBuilder(
        animation: prefs,
        builder: (context, _) => MaterialApp(
          title: 'Combo Universal',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: prefs.dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              // Respect the user's own accessibility setting, then apply the
              // in-app text-size preference on top of it.
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  media.textScaler.scale(1.0) * prefs.fontScale,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: AdsBootstrap(
            prefs: prefs,
            ads: ads,
            child: const HomeShell(),
          ),
        ),
      ),
    );
  }
}

/// Presents a plain-language, in-app disclosure before the advertising SDK is
/// initialized. This is separate from Google's UMP form: Play's user-data
/// policy requires the app itself to explain unexpected third-party SDK data
/// collection before that SDK starts collecting.
class AdsBootstrap extends StatefulWidget {
  const AdsBootstrap({
    super.key,
    required this.prefs,
    required this.ads,
    required this.child,
  });

  final PrefsService prefs;
  final AdsService ads;
  final Widget child;

  @override
  State<AdsBootstrap> createState() => _AdsBootstrapState();
}

class _AdsBootstrapState extends State<AdsBootstrap> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareAds());
  }

  Future<void> _prepareAds() async {
    if (_started || !mounted) return;
    _started = true;

    var allowAdsThisSession = true;
    if (!widget.prefs.adDisclosureShown) {
      final choice = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Ads and privacy'),
          content: const SingleChildScrollView(
            child: Text(
              'Combo Universal uses Google AdMob to keep the app free. Before '
              'ads load, Google may collect and share your IP address, device '
              'or account identifiers such as the Android Advertising ID, '
              'ad/app interactions and diagnostic information for advertising, '
              'measurement and fraud prevention. This app does not send your '
              'searches, saved lists or shop notes to us.\n\n'
              'Continue to ads, or use the app without ads for this session. '
              'Google will show any required consent choices next, and you can '
              'change ad privacy options later in Settings.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const PolicyScreen(kind: PolicyKind.privacy),
                ),
              ),
              child: const Text('Privacy policy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue with ads'),
            ),
          ],
        ),
      );
      await widget.prefs.markAdDisclosureShown();
      allowAdsThisSession = choice == true;
    }

    if (!mounted || !allowAdsThisSession) return;
    unawaited(widget.ads.init(personalized: widget.prefs.personalizedAds));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
