import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_scope.dart';
import 'screens/home_shell.dart';
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

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(ads.init(personalized: prefs.personalizedAds));
  });
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
          home: const HomeShell(),
        ),
      ),
    );
  }
}
