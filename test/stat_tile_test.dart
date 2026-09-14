import 'package:combo_universal/format.dart';
import 'package:combo_universal/theme.dart';
import 'package:combo_universal/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  /// Pumps one tile at a realistic grid-cell width, inside the real theme and
  /// under the same text-scale plumbing the app itself uses.
  ///
  /// Animation is frozen because the tile rolls its number up on first paint;
  /// freezing makes the painted value the final one, so the assertions are
  /// about content rather than about timing.
  Future<void> pumpTile(
    WidgetTester tester,
    Widget tile, {
    double width = 158,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: SizedBox(
                width: width,
                // Sized the same way the home grid sizes its cells.
                height: statTileExtent(context),
                child: tile,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('StatTile', () {
    testWidgets('leads with a grouped number between eyebrow and caption',
        (tester) async {
      await pumpTile(
        tester,
        const StatTile(
          eyebrow: 'Battery List',
          value: 1137,
          caption: '324 lists',
          tint: Color(0xFF17A673),
          icon: Icons.battery_charging_full_rounded,
        ),
      );

      expect(find.text('BATTERY LIST'), findsOneWidget);
      expect(find.text('1,137'), findsOneWidget);
      expect(find.text('324 lists'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('holds its composition at 1.5x text on the narrowest tile',
        (tester) async {
      // 140dp is about what a 320dp phone leaves per column, and 1.5x is the
      // top of the app's own text-size slider: the worst case there is.
      await pumpTile(
        tester,
        const StatTile(
          eyebrow: 'Tempered / Screen Guard',
          value: 1797,
          caption: '226 lists',
          tint: Color(0xFF00A3C4),
          icon: Icons.shield_moon_outlined,
        ),
        width: 140,
        textScale: 1.5,
      );

      expect(find.text('1,797'), findsOneWidget);
      // Overflow and clipping surface as framework exceptions, never as a
      // visible error on a user's phone — so catch them here instead.
      expect(tester.takeException(), isNull);

      // The number is allowed to shrink to fit, but never to spill outside the
      // tile it belongs to.
      final number = tester.getSize(find.byType(FittedBox));
      expect(number.width, lessThanOrEqualTo(140));
    });

    testWidgets('reports a single semantics label, not three fragments',
        (tester) async {
      final handle = tester.ensureSemantics();

      await pumpTile(
        tester,
        const StatTile(
          eyebrow: 'Battery List',
          value: 1137,
          caption: '324 lists',
          semanticsLabel: 'Battery List: 1,137 models across 324 lists',
        ),
      );

      expect(
        tester.getSemantics(find.byType(StatTile)).label,
        'Battery List: 1,137 models across 324 lists',
      );

      // Disposed inside the body, not in a tearDown: the framework checks for
      // leaked handles as the test ends, before tearDowns run.
      handle.dispose();
    });

    testWidgets('fires its callback when tappable', (tester) async {
      var taps = 0;
      await pumpTile(
        tester,
        StatTile(
          eyebrow: 'Battery',
          value: 10,
          caption: '1 list',
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.byType(StatTile));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('groupDigits', () {
    test('separates thousands and keeps the sign', () {
      expect(groupDigits(0), '0');
      expect(groupDigits(7), '7');
      expect(groupDigits(999), '999');
      expect(groupDigits(1000), '1,000');
      expect(groupDigits(5675), '5,675');
      expect(groupDigits(1234567), '1,234,567');
      expect(groupDigits(-5675), '-5,675');
    });
  });
}
