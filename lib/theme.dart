import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ---------------------------------------------------------------------------
/// Brand palette
/// ---------------------------------------------------------------------------
/// A vivid coral — the single warm accent the whole UI hangs from (buttons,
/// highlights, the hero sparkle). Warm cream surfaces keep the tool friendly
/// at a repair counter without ever reading as a toy.
const Color brandSeed = Color(0xFFE8705F);
const Color brandAccent = Color(0xFFF0A500);
const Color brandInk = Color(0xFF1C150F);

/// Soft butter yellow — the secondary accent (sparkle, "focus score"-style
/// tinted cards) in the same family as the coral.
const Color brandYellow = Color(0xFFF2C16B);

/// Surface tints: a warm ivory canvas with near-white warm cards on top, so
/// flat borderless cards still separate cleanly.
const Color _lightBg = Color(0xFFF2EFE4);
const Color _lightSurface = Color(0xFFFDFCF8);
const Color _darkBg = Color(0xFF171310);
const Color _darkSurface = Color(0xFF241E18);

/// ---------------------------------------------------------------------------
/// Typography
/// ---------------------------------------------------------------------------
/// Sora for headings (geometric, premium), Inter for body/UI (dense-list
/// legibility), JetBrains Mono for part codes (unambiguous 0/O and 1/l).
///
/// `google_fonts` resolves these from `assets/google_fonts/` when the TTFs are
/// bundled (see tools/fetch_fonts.sh) and silently falls back to the platform
/// font otherwise, so the app never blocks on a network call.
class AppFonts {
  const AppFonts._();

  static TextStyle display(TextStyle? base) => GoogleFonts.sora(textStyle: base);
  static TextStyle body(TextStyle? base) => GoogleFonts.inter(
        textStyle: base,
      ).copyWith(
        // The bundled Inter files are variable fonts. Older Android text
        // engines can briefly expose a variant family before its glyph table
        // is ready, which turns bold labels into tofu boxes. Keep the brand
        // face first, but guarantee an immediately readable system fallback.
        fontFamilyFallback: const ['Roboto', 'Arial', 'sans-serif'],
      );
  static TextStyle mono(TextStyle? base) =>
      GoogleFonts.jetBrainsMono(textStyle: base);

  /// Monospaced style for part codes, battery numbers and SKUs.
  static TextStyle code(BuildContext context, {double size = 12.5, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        textStyle: TextStyle(
          fontSize: size,
          height: 1.2,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w500,
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

/// A hand-tuned type scale. Sizes step on a ~1.2 ratio; tracking tightens as
/// size grows, which is what makes large headings feel designed rather than
/// merely big.
TextTheme _buildTextTheme(ColorScheme scheme) {
  final onSurface = scheme.onSurface;
  final muted = scheme.onSurfaceVariant;

  TextStyle heading(double size, FontWeight weight, double tracking,
          {double height = 1.18, Color? color}) =>
      AppFonts.display(TextStyle(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking,
        height: height,
        color: color ?? onSurface,
      ));

  TextStyle text(double size, FontWeight weight, double tracking,
          {double height = 1.42, Color? color}) =>
      AppFonts.body(TextStyle(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking,
        height: height,
        color: color ?? onSurface,
      ));

  return TextTheme(
    displayLarge: heading(44, FontWeight.w700, -1.2),
    displayMedium: heading(36, FontWeight.w700, -1.0),
    displaySmall: heading(30, FontWeight.w700, -0.8),
    headlineLarge: heading(28, FontWeight.w700, -0.7),
    headlineMedium: heading(24, FontWeight.w700, -0.5),
    headlineSmall: heading(21, FontWeight.w700, -0.4),
    titleLarge: heading(19, FontWeight.w700, -0.3, height: 1.25),
    titleMedium: heading(16, FontWeight.w600, -0.15, height: 1.3),
    titleSmall: heading(14, FontWeight.w600, 0.0, height: 1.3),
    bodyLarge: text(15.5, FontWeight.w400, 0.0),
    bodyMedium: text(14, FontWeight.w400, 0.05),
    bodySmall: text(12.5, FontWeight.w400, 0.1, height: 1.38, color: muted),
    labelLarge: text(14, FontWeight.w600, 0.1, height: 1.2),
    labelMedium: text(12.5, FontWeight.w600, 0.3, height: 1.2),
    labelSmall: text(11, FontWeight.w600, 0.6, height: 1.2, color: muted),
  );
}

/// ---------------------------------------------------------------------------
/// Theme
/// ---------------------------------------------------------------------------
ThemeData buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  final base = ColorScheme.fromSeed(
    seedColor: brandSeed,
    brightness: brightness,
  );

  final scheme = base.copyWith(
    surface: isLight ? _lightSurface : _darkSurface,
    // The amber accent carries the search highlight and "hot" badges.
    tertiary: brandAccent,
    tertiaryContainer: isLight ? const Color(0xFFF7E7BE) : const Color(0xFF4A3D1E),
    onTertiaryContainer: isLight ? const Color(0xFF4A3D1E) : const Color(0xFFF3DFAE),
    outlineVariant: isLight ? const Color(0xFFE6E0D0) : const Color(0xFF383026),
  );

  final textTheme = _buildTextTheme(scheme);
  final radius = BorderRadius.circular(24);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: isLight ? _lightBg : _darkBg,
    canvasColor: isLight ? _lightBg : _darkBg,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,

    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: isLight ? _lightBg : _darkBg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleSpacing: 20,
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle:
          isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      // Flat fill — in light mode separation comes from the ivory canvas
      // showing between warm-white cards, as in editorial card UIs. In dark
      // mode that tone step is too faint to read, so a quiet hairline takes
      // over the job instead.
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: isLight
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.outline),
      labelStyle: textTheme.bodyMedium,
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),

    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius),
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: textTheme.bodySmall,
      iconColor: scheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: isLight ? const Color(0xFFEAE6D8) : const Color(0xFF2E2720),
      selectedColor: scheme.primaryContainer,
      labelStyle: textTheme.labelMedium,
      secondaryLabelStyle: textTheme.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      backgroundColor: scheme.inverseSurface,
      insetPadding: const EdgeInsets.all(16),
    ),

    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.outlineVariant,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      trackHeight: 4,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHighest,
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.outlineVariant,
    ),

    iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),

    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      // CupertinoPageTransitionsBuilder was removed from the framework; the
      // Material 3 forward-fade transition is its intended replacement.
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

/// ---------------------------------------------------------------------------
/// Spacing scale — use these instead of magic numbers so rhythm stays even.
/// ---------------------------------------------------------------------------
class Gap {
  const Gap._();
  static const xs = SizedBox(height: 4);
  static const sm = SizedBox(height: 8);
  static const md = SizedBox(height: 12);
  static const lg = SizedBox(height: 16);
  static const xl = SizedBox(height: 24);
  static const xxl = SizedBox(height: 32);

  static const wXs = SizedBox(width: 4);
  static const wSm = SizedBox(width: 8);
  static const wMd = SizedBox(width: 12);
  static const wLg = SizedBox(width: 16);
}

/// Per-category accent colour, so the eye can tell part types apart in a list.
Color accentFor(String key, ColorScheme scheme) {
  switch (key) {
    case 'battery':
      return const Color(0xFF17A673);
    case 'glass':
      return const Color(0xFF00A3C4);
    case 'board':
      return const Color(0xFF9B5DE5);
    case 'case':
      return const Color(0xFFE8618C);
    case 'frame':
      return const Color(0xFFF0A500);
    default:
      return scheme.primary;
  }
}

IconData iconFor(String key) {
  switch (key) {
    case 'battery':
      return Icons.battery_charging_full_rounded;
    case 'glass':
      return Icons.shield_moon_outlined;
    case 'board':
      return Icons.developer_board_rounded;
    case 'frame':
      return Icons.crop_square_rounded;
    case 'case':
      return Icons.phonelink_ring_rounded;
    default:
      return Icons.smartphone_rounded;
  }
}

/// ---------------------------------------------------------------------------
/// Pastel tile surfaces
/// ---------------------------------------------------------------------------
/// The stat-tile language: a flat, saturated pastel fill carrying a single dark
/// ink for every line of text on it — no border, no shadow, no alpha wash, and
/// no tinted captions. Tinted text on a tinted card is both muddy and a
/// contrast hazard; one ink on a solid pastel is neither.
///
/// [pastelSurface] keeps the accent's hue, clamps its saturation, and then
/// solves for the lightness that lands it on a fixed *perceived* luminance —
/// so the brand coral, the category accents and the brand colours all sit on
/// one tonal shelf. That is what lets a single ink stay legible on every one of
/// them, and what makes a grid of these tiles read as a family rather than as a
/// colour swatch set.
///
/// Matching on luminance rather than HSL lightness is the whole trick: at equal
/// lightness a blue tile is several times darker than a yellow one, which would
/// make both the ink contrast and the tiles' apparent weight drift with the part
/// type.
Color pastelSurface(Color tint, ColorScheme scheme) {
  final light = scheme.brightness == Brightness.light;
  final hsl = HSLColor.fromColor(tint);
  final saturation = light
      ? hsl.saturation.clamp(0.45, 0.78)
      : (hsl.saturation * 0.55).clamp(0.18, 0.40);

  // Light: ~1.36:1 against the ivory canvas while holding dark ink at ~11:1.
  // Dark: ~1.67:1 against the near-black canvas, light ink ~9.7:1.
  final target = light ? 0.62 : 0.045;

  // Luminance rises monotonically with HSL lightness at fixed hue/saturation,
  // so a plain bisection finds the tone. Sixteen steps is far more precision
  // than the eye can resolve, and the whole loop is a few dozen float ops.
  var low = 0.0;
  var high = 1.0;
  var best = hsl.withSaturation(saturation).withLightness(low).toColor();
  for (var i = 0; i < 16; i++) {
    final mid = (low + high) / 2;
    best = hsl.withSaturation(saturation).withLightness(mid).toColor();
    if (best.computeLuminance() < target) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return best;
}

/// The single ink used on every pastel surface, in either brightness. ~12:1
/// against the lightest pastel the palette can produce.
Color pastelInk(ColorScheme scheme) =>
    scheme.brightness == Brightness.light
        ? brandInk
        : const Color(0xFFF4EDE3);

/// Quieter ink for the caption line only. At 0.72 alpha it still clears 5:1 on
/// any pastel surface — the muted step is quieter than the tinted captions it
/// replaces, yet several times more legible.
Color pastelInkMuted(ColorScheme scheme) =>
    pastelInk(scheme).withValues(alpha: 0.72);
