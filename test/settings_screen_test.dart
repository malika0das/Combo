import 'package:combo_universal/app_scope.dart';
import 'package:combo_universal/screens/settings_screen.dart';
import 'package:combo_universal/services/ads_service.dart';
import 'package:combo_universal/services/catalog_service.dart';
import 'package:combo_universal/services/prefs_service.dart';
import 'package:combo_universal/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings screen: renders every group, reports honestly on an offline
/// build's update check, and keeps the switches wired to the services.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late PrefsService prefs;
  late CatalogService catalog;
  late AdsService ads;

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});
    prefs = PrefsService();
    await prefs.init();
    // Catalog deliberately left un-init'd, like the first frame of a real
    // launch - and without init it never touches the bundled asset.
    catalog = CatalogService();
    ads = AdsService();
    // A phone-width, tall viewport so the lazy ListView builds every section.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        title: 'Settings test',
        theme: buildTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        ),
        home: AppScope(
          prefs: prefs,
          catalog: catalog,
          ads: ads,
          child: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders every section and the essential controls', (
    tester,
  ) async {
    await pump(tester);

    for (final label in [
      'Appearance',
      'Data',
      'Legal',
      'Dark theme',
      'Text size',
      'Personalised ads',
      'Check for list update',
      'Share this app',
      'Privacy policy',
      'Terms & disclaimer',
      'Open source licences',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // The accessibility slider gets its own full-width row.
    expect(find.byType(Slider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains that updates are off on an offline build', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Check for list update'));
    await tester.pump();
    expect(find.text('Updates are turned off for this build.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme switch flips the preference and the icon', (
    tester,
  ) async {
    await pump(tester);
    expect(prefs.dark, isFalse);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Dark theme'));
    await tester.pump();

    expect(prefs.dark, isTrue);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('personalised ads switch stays in sync with the service', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Personalised ads'));
    await tester.pump();
    expect(prefs.personalizedAds, isTrue);
    expect(tester.takeException(), isNull);
  });
}
