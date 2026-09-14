import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';

/// ---------------------------------------------------------------------------
/// Ambient animated icons
/// ---------------------------------------------------------------------------
/// Continuous, slow, low-amplitude motion that makes surfaces feel alive
/// without ever demanding attention. The rules every widget here obeys:
///
///  * One animation controller, one loop, nothing per-frame allocated.
///  * [Motion.reduced] freezes the loop entirely (static frame is painted).
///  * An [AppLifecycleListener] stops the ticker while the app is hidden —
///    invisible frames still cost battery.
///  * Loops accept a [phase] so neighbouring cards never pulse in lockstep,
///    which is the difference between "alive" and "mechanical".

abstract class _AmbientLoopState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: loopDuration,
  );

  AppLifecycleListener? _lifecycle;

  Duration get loopDuration;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: controller.stop,
      onPause: controller.stop,
      onShow: _resume,
      onRestart: _resume,
    );
  }

  void _resume() {
    if (!mounted || controller.isAnimating) return;
    if (Motion.reduced(context)) return;
    controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Under reduced motion the loop value is never painted, so an animating
    // ticker would burn frames for nothing.
    if (Motion.reduced(context)) {
      controller.stop();
    } else if (!controller.isAnimating) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    controller.dispose();
    super.dispose();
  }
}

/// An icon in a tinted gradient tile that gently "breathes": the tile scale,
/// glow and border all swell and settle on one slow sine wave. Used on the
/// home grid so the part categories read as living destinations, not buttons
/// in a spreadsheet.
class BreathingIcon extends StatefulWidget {
  const BreathingIcon({
    super.key,
    required this.icon,
    required this.tint,
    this.iconSize = 20,
    this.containerSize = 38,
    this.borderRadius = 12,
    this.phase = 0,
    this.tileColor,
  });

  final IconData icon;
  final Color tint;

  /// When set, the tile is a solid fill (e.g. a white tile sitting on a
  /// tinted card) instead of the tint gradient.
  final Color? tileColor;
  final double iconSize;
  final double containerSize;
  final double borderRadius;

  /// 0..1 offset into the loop. Stagger it across a list (e.g. `i * 0.37 % 1`)
  /// so the icons breathe out of sync.
  final double phase;

  @override
  State<BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends _AmbientLoopState<BreathingIcon> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 3600);

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return _tile(0);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final breath =
            0.5 - 0.5 * math.cos((controller.value + widget.phase) * 2 * math.pi);
        return _tile(breath);
      },
    );
  }

  Widget _tile(double breath) {
    return Container(
      width: widget.containerSize,
      height: widget.containerSize,
      decoration: BoxDecoration(
        gradient: widget.tileColor == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.tint.withValues(alpha: 0.22),
                  widget.tint.withValues(alpha: 0.06),
                ],
              )
            : null,
        color: widget.tileColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: widget.tint.withValues(alpha:
              widget.tileColor == null ? 0.16 + 0.12 * breath : 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: widget.tint.withValues(alpha: 0.08 + 0.14 * breath),
            blurRadius: 9 + 8 * breath,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Transform.scale(
        // Amplitude is deliberately small: readable at rest, perceptible in
        // the corner of the eye.
        scale: 1.0 + 0.05 * breath,
        child: Icon(widget.icon, size: widget.iconSize, color: widget.tint),
      ),
    );
  }
}

/// A search-style icon with a soft radar "ping": an expanding ring fades out
/// every few seconds while the icon gives one small pop in sync. Draws the
/// eye to the app's primary action without a tutorial.
class PingIcon extends StatefulWidget {
  const PingIcon({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 20,
    this.phase = 0,
  });

  final IconData icon;
  final Color tint;
  final double size;
  final double phase;

  @override
  State<PingIcon> createState() => _PingIconState();
}

class _PingIconState extends _AmbientLoopState<PingIcon> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 3200);

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, size: widget.size, color: widget.tint);
    if (Motion.reduced(context)) return icon;

    final box = widget.size * 2.1;
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = (controller.value + widget.phase) % 1.0;
          // The ring lives on the first 65% of the cycle, then rests — a ping
          // that loops back-to-back reads as an error spinner.
          final ringT = Curves.easeOutCubic.transform((t / 0.65).clamp(0.0, 1.0));
          final resting = t >= 0.65;
          final pop = 1.0 +
              0.12 * (1 - Curves.easeOut.transform((t * 3).clamp(0.0, 1.0)));
          return Stack(
            alignment: Alignment.center,
            children: [
              if (!resting)
                Opacity(
                  opacity: (1 - ringT) * 0.45,
                  child: Transform.scale(
                    scale: 0.55 + 0.55 * ringT,
                    child: Container(
                      width: box * 0.92,
                      height: box * 0.92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.tint.withValues(alpha: 0.7),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.scale(scale: pop, child: icon),
            ],
          );
        },
      ),
    );
  }
}

/// The app bar brand tile with a slow specular sheen sweeping across its
/// gradient — the one place a little jewellery is earned. Same footprint as
/// the static tile it replaces, so the header layout does not move.
class AnimatedBrandMark extends StatefulWidget {
  const AnimatedBrandMark({super.key, this.size = 30, this.iconSize = 17});

  final double size;
  final double iconSize;

  @override
  State<AnimatedBrandMark> createState() => _AnimatedBrandMarkState();
}

class _AnimatedBrandMarkState extends _AmbientLoopState<AnimatedBrandMark> {
  static const _tileCoral = Color(0xFFF08A72);

  @override
  Duration get loopDuration => const Duration(milliseconds: 9000);

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.size * 0.3),
        boxShadow: [
          BoxShadow(
            color: brandSeed.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.3),
        child: Motion.reduced(context)
            ? _face(0)
            : AnimatedBuilder(
                animation: controller,
                builder: (context, _) => _face(controller.value),
              ),
      ),
    );
    return tile;
  }

  Widget _face(double t) {
    // A narrow bright band travels around a conic gradient: a sheen passing
    // over the tile roughly every nine seconds. Slow enough to read as light,
    // fast enough to be noticed once.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: SweepGradient(
          transform: GradientRotation(-math.pi / 2 + t * 2 * math.pi),
          colors: const [
            brandSeed,
            _tileCoral,
            brandSeed,
            Color(0xFFFFE3D6),
            brandSeed,
          ],
          stops: const [0.0, 0.30, 0.52, 0.60, 0.70],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.hub_rounded,
          size: widget.iconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// A desktop/web nicety: lifts its child a couple of pixels and deepens the
/// shadow while a pointer hovers. Touch devices never hover, so on phones this
/// is exactly the resting card — nothing changes.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.lift = 2.0,
    this.restingShadow = const [],
    this.hoverShadow = const [],
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double lift;
  final List<BoxShadow> restingShadow;
  final List<BoxShadow> hoverShadow;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => mounted ? setState(() => _hover = true) : null,
      onExit: (_) => mounted ? setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.quick),
        curve: Motion.enter,
        transform: Matrix4.translationValues(0, _hover ? -widget.lift : 0, 0),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _hover ? widget.hoverShadow : widget.restingShadow,
        ),
        child: widget.child,
      ),
    );
  }
}

/// A four-pointed sparkle — the editorial "magic" mark — that slowly turns a
/// few degrees and breathes on one long loop. Decorative only: never the
/// sole carrier of meaning, always safe to freeze under reduced motion.
class SparkStar extends StatefulWidget {
  const SparkStar({
    super.key,
    required this.color,
    this.size = 40,
    this.phase = 0,
  });

  final Color color;
  final double size;
  final double phase;

  @override
  State<SparkStar> createState() => _SparkStarState();
}

class _SparkStarState extends _AmbientLoopState<SparkStar> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 6000);

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _SparkPainter(color: widget.color, t: 0)),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final wave =
            0.5 - 0.5 * math.cos((controller.value + widget.phase) * 2 * math.pi);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _SparkPainter(color: widget.color, t: wave),
          ),
        );
      },
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.color, required this.t});

  final Color color;

  /// 0..1 breath wave: drives a gentle turn and swell.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 * (0.96 + 0.06 * t);
    final k = r * 0.16; // concavity of the four edges — small = sharp sparkle

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // A slow few-degree sway rather than a full spin: a spinning star reads
    // as a loading indicator.
    canvas.rotate(0.22 * math.sin((t + 0.25) * math.pi));

    final glow = Paint()
      ..color = color.withValues(alpha: 0.22 + 0.16 * t)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    _starPath(r * 0.98, k * 0.98);
    canvas.drawPath(_path, glow);
    _starPath(r, k);
    canvas.drawPath(_path, Paint()..color = color);
    canvas.restore();
  }

  Path _path = Path();

  void _starPath(double r, double k) {
    _path = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(k, -k, r, 0)
      ..quadraticBezierTo(k, k, 0, r)
      ..quadraticBezierTo(-k, k, -r, 0)
      ..quadraticBezierTo(-k, -k, 0, -r)
      ..close();
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t || old.color != color;
}
