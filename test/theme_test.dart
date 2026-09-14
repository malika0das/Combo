import 'dart:math' as math;

import 'package:combo_universal/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  // buildTheme resolves fonts through google_fonts, which needs the binding
  // for the asset bundle. Fonts are bundled in assets/google_fonts/, so with
  // runtime fetching off they load from assets and never touch the network.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('theme', () {
    for (final brightness in Brightness.values) {
      test('builds for $brightness with a complete type scale', () {
        final theme = buildTheme(brightness);
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, brightness);

        final t = theme.textTheme;
        final styles = <String, TextStyle?>{
          'displayLarge': t.displayLarge,
          'headlineMedium': t.headlineMedium,
          'titleLarge': t.titleLarge,
          'titleMedium': t.titleMedium,
          'titleSmall': t.titleSmall,
          'bodyLarge': t.bodyLarge,
          'bodyMedium': t.bodyMedium,
          'bodySmall': t.bodySmall,
          'labelLarge': t.labelLarge,
          'labelSmall': t.labelSmall,
        };
        styles.forEach((name, style) {
          expect(style, isNotNull, reason: '$name missing');
          expect(style!.fontSize, isNotNull, reason: '$name has no size');
          expect(style.height, isNotNull, reason: '$name has no line height');
        });
      });

      test('type scale descends in size for $brightness', () {
        final t = buildTheme(brightness).textTheme;
        final ladder = <double>[
          t.displayLarge!.fontSize!,
          t.headlineLarge!.fontSize!,
          t.titleLarge!.fontSize!,
          t.titleMedium!.fontSize!,
          t.bodyLarge!.fontSize!,
          t.bodyMedium!.fontSize!,
          t.bodySmall!.fontSize!,
        ];
        for (var i = 1; i < ladder.length; i++) {
          expect(ladder[i], lessThan(ladder[i - 1]),
              reason: 'step $i is not smaller than the one before');
        }
      });

      test('body text meets a readable minimum size for $brightness', () {
        final t = buildTheme(brightness).textTheme;
        expect(t.bodyMedium!.fontSize, greaterThanOrEqualTo(13));
        expect(t.bodySmall!.fontSize, greaterThanOrEqualTo(12));
        expect(t.labelSmall!.fontSize, greaterThanOrEqualTo(10));
      });
    }

    test('light and dark use different backgrounds', () {
      expect(
        buildTheme(Brightness.light).scaffoldBackgroundColor,
        isNot(buildTheme(Brightness.dark).scaffoldBackgroundColor),
      );
    });

    test('component themes are configured', () {
      final theme = buildTheme(Brightness.light);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.appBarTheme.titleTextStyle, isNotNull);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.listTileTheme.titleTextStyle, isNotNull);
    });
  });

  group('category accents', () {
    test('each part type gets a distinct accent', () {
      final scheme = buildTheme(Brightness.light).colorScheme;
      final keys = ['display', 'battery', 'glass', 'board', 'case'];
      final colors = keys.map((k) => accentFor(k, scheme)).toList();
      expect(colors.toSet().length, keys.length);
    });

    test('unknown keys fall back to the brand colour', () {
      final scheme = buildTheme(Brightness.light).colorScheme;
      expect(accentFor('something-new', scheme), scheme.primary);
    });

    test('every category icon resolves', () {
      for (final key in ['display', 'battery', 'glass', 'board', 'frame', 'case', '']) {
        expect(iconFor(key), isA<IconData>());
      }
    });
  });

  group('pastel tiles', () {
    const accents = ['display', 'battery', 'glass', 'board', 'case'];

    /// WCAG contrast ratio between two opaque colours.
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    for (final brightness in Brightness.values) {
      // The tiles put every line of text on the pastel itself, so the ink has
      // to hold up against *all* of them, not just the brand colour. This is the
      // regression guard for "someone adds an accent and the caption vanishes".
      test('$brightness keeps one ink legible on every pastel', () {
        final scheme = buildTheme(brightness).colorScheme;
        final tints = <Color>[
          scheme.primary,
          ...accents.map((k) => accentFor(k, scheme)),
        ];

        for (final tint in tints) {
          final pastel = pastelSurface(tint, scheme);
          expect(contrast(pastel, pastelInk(scheme)), greaterThanOrEqualTo(7.0),
              reason: '$brightness number ink fails AAA on $tint');

          // The caption is the muted step, so it is the one that can fail.
          final muted = Color.alphaBlend(pastelInkMuted(scheme), pastel);
          expect(contrast(pastel, muted), greaterThanOrEqualTo(4.5),
              reason: '$brightness caption ink fails AA on $tint');
        }
      });

      test('$brightness pastels are opaque, distinct and visible on the canvas',
          () {
        final theme = buildTheme(brightness);
        final scheme = theme.colorScheme;
        final fills = accents
            .map((k) => pastelSurface(accentFor(k, scheme), scheme))
            .toList();

        for (final fill in fills) {
          // A solid fill, not an alpha wash: the tint used to be 12% alpha, and
          // text on that picked up whatever sat behind the card.
          expect(fill.a, greaterThan(0.99));
          // The tile has to read as a tile against the page it sits on.
          expect(contrast(fill, theme.scaffoldBackgroundColor),
              greaterThanOrEqualTo(1.20));
        }
        expect(fills.toSet().length, fills.length,
            reason: 'two part types would be indistinguishable');
      });
    }
  });
}
