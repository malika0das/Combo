import 'package:flutter/material.dart';

import '../format.dart';
import '../motion.dart';
import '../theme.dart';
import 'animated_icons.dart';

/// ---------------------------------------------------------------------------
/// Stat tile
/// ---------------------------------------------------------------------------
/// One tile from the pastel stat grid: an uppercase eyebrow, one very large
/// number, and a short caption — the three-tier composition the reference
/// design hangs on.
///
/// The discipline that makes it work is that the *number* carries the tile.
/// Everything else is scaffolding: the eyebrow names it, the caption adds the
/// one detail worth knowing, and the icon sits in the corner as identity rather
/// than content. That is also why every line uses the same ink — a tinted
/// caption on a tinted card reads as decoration and fails contrast.

/// Base tile height at 1.0 text scale.
const double kStatTileExtent = 150;

/// Tile height for the current text scale.
///
/// Tiles are sized by an explicit extent rather than a grid aspect ratio: the
/// content is a fixed three-line stack, so an aspect ratio silently clips it the
/// moment the user raises their text size. Growing the extent preserves the
/// composition at every scale, and the [FittedBox] on the number absorbs the
/// last of the squeeze.
double statTileExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
  return kStatTileExtent * scale;
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.eyebrow,
    required this.value,
    required this.caption,
    this.tint,
    this.icon,
    this.onTap,
    this.phase = 0,
    this.animateValue = true,
    this.semanticsLabel,
  });

  /// The line naming the number. Rendered uppercase — the small-caps eyebrow is
  /// what lets the number stay enormous without the tile feeling shouty.
  final String eyebrow;

  /// The number itself, formatted with thousands separators.
  final int value;

  /// One short line under the number.
  final String caption;

  /// Source accent for the pastel fill. Defaults to the brand colour.
  final Color? tint;

  /// Quiet corner badge. Identity only — never the headline.
  final IconData? icon;

  final VoidCallback? onTap;

  /// 0..1 stagger for the badge's ambient loop, so neighbouring tiles breathe
  /// out of sync.
  final double phase;

  /// Roll the number up on first paint. Off for values that should be readable
  /// immediately.
  final bool animateValue;

  /// Screen-reader text. Defaults to the three visible parts joined, which
  /// reads as a list of fragments — pass something better when the caller knows
  /// what the number counts.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = tint ?? scheme.primary;
    final ink = pastelInk(scheme);

    // Sora ships Regular / SemiBold / Bold only, so w700 is the heaviest real
    // weight — w800 here would be synthetically emboldened and smear the
    // letterforms at this size.
    final numberStyle = AppFonts.display(TextStyle(
      fontSize: 34,
      height: 1.0,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      color: ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    ));

    // Semibold is deliberately used for the compact all-caps label. It keeps
    // the hierarchy strong while avoiding the bold variable-font variant,
    // which can briefly render as missing-glyph boxes on older Android text
    // engines while the font asset is loading.
    final eyebrowStyle = AppFonts.body(TextStyle(
      fontSize: 10.5,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.3,
      color: ink,
    ));

    final captionStyle = AppFonts.body(TextStyle(
      fontSize: 12.5,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: pastelInkMuted(scheme),
    ));

    final tile = Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: pastelSurface(accent, scheme),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Eyebrow pinned top, number and caption pinned bottom: neighbouring
        // tiles then align on the numbers themselves, which is the axis the eye
        // actually scans across.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  eyebrow.toUpperCase(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: eyebrowStyle,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                _Badge(
                  icon: icon!,
                  accent: accent,
                  scheme: scheme,
                  phase: phase,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: animateValue
                ? AnimatedCounter(
                    value: value,
                    style: numberStyle,
                    grouped: true,
                  )
                : Text(
                    groupDigits(value),
                    maxLines: 1,
                    style: numberStyle,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: captionStyle,
          ),
        ],
      ),
    );

    return Semantics(
      // The visible parts are three unrelated fragments to a screen reader.
      // Replacing them with one label is what makes the tile navigable rather
      // than noisy.
      container: true,
      button: onTap != null,
      excludeSemantics: true,
      label: semanticsLabel ?? '$eyebrow, ${groupDigits(value)}, $caption',
      child: onTap == null
          ? tile
          : PressableScale(onTap: onTap, child: tile),
    );
  }
}

/// A small chip in the tile's corner. Carries the accent at full strength, so
/// the part type is still identifiable at a glance without the icon competing
/// with the number.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.accent,
    required this.scheme,
    required this.phase,
  });

  final IconData icon;
  final Color accent;
  final ColorScheme scheme;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final light = scheme.brightness == Brightness.light;
    return BreathingIcon(
      icon: icon,
      // On a white chip the raw accent is legible; on dark mode's lifted chip it
      // would go muddy, so lift it toward white first.
      tint: light ? accent : Color.lerp(accent, Colors.white, 0.35)!,
      iconSize: 15,
      containerSize: 28,
      borderRadius: 9,
      phase: phase,
      // Near-white chip on the pastel in light mode (as in the reference); in
      // dark mode pure white would glare, so lift the pastel instead.
      tileColor: light
          ? scheme.surface
          : Color.alphaBlend(
              Colors.white.withValues(alpha: 0.08),
              pastelSurface(accent, scheme),
            ),
    );
  }
}
