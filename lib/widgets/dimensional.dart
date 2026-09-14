import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion.dart';

/// ---------------------------------------------------------------------------
/// 3D / dimensional widgets
/// ---------------------------------------------------------------------------
/// All real perspective transforms (Matrix4 with an entry(3,2) perspective
/// term), not drop shadows pretending to be depth. Every one of them degrades
/// to a flat, still widget when the OS asks for reduced motion.

/// A card that tilts in 3D toward the user's finger. Used on the hero surfaces
/// only — tilt everywhere would be noise.
class TiltCard extends StatefulWidget {
  const TiltCard({
    super.key,
    required this.child,
    this.onTap,
    this.maxTilt = 0.12,
    this.borderRadius = 20,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Maximum rotation in radians. Deliberately small — a big tilt reads as a
  /// gimmick and hurts legibility of the text on the card.
  final double maxTilt;
  final double borderRadius;

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  double _dx = 0;
  double _dy = 0;
  bool _active = false;

  void _update(Offset local, Size size) {
    if (size.isEmpty) return;
    setState(() {
      _active = true;
      // Map the touch point to -1..1 on each axis.
      _dx = ((local.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
      _dy = ((local.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);
    });
  }

  void _reset() {
    if (mounted) setState(() => _active = false);
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      return GestureDetector(onTap: widget.onTap, child: widget.child);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _update(d.localPosition, size),
          onPanUpdate: (d) => _update(d.localPosition, size),
          onTapUp: (_) {
            _reset();
            if (widget.onTap != null) {
              Haptics.tap();
              widget.onTap!();
            }
          },
          onTapCancel: _reset,
          onPanEnd: (_) => _reset(),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _active ? 1 : 0),
            duration: Motion.quick,
            curve: Motion.enter,
            builder: (context, t, child) {
              final s = 1 - 0.02 * t;
              final matrix = Matrix4.identity()
                // The perspective term is what makes this genuine 3D: nearer
                // edges enlarge, far edges foreshorten.
                ..setEntry(3, 2, 0.0012)
                ..rotateX(-_dy * widget.maxTilt * t)
                ..rotateY(_dx * widget.maxTilt * t)
                // Uniform scale, w untouched — what scale(x) used to do.
                ..scaleByDouble(s, s, s, 1.0);
              return Transform(
                transform: matrix,
                alignment: Alignment.center,
                child: child,
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// A slowly rotating, softly lit 3D-looking orb. Cheap to draw (a few gradients
/// on a CustomPainter) but reads as a lit sphere, which gives empty and hero
/// states a sense of physical space.
class DepthOrb extends StatefulWidget {
  const DepthOrb({
    super.key,
    required this.color,
    this.size = 120,
    this.icon,
  });

  final Color color;
  final double size;
  final IconData? icon;

  @override
  State<DepthOrb> createState() => _DepthOrbState();
}

class _DepthOrbState extends State<DepthOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The orbiting highlight is frozen under reduced motion, so keep the
    // ticker idle rather than animating a value that is never painted.
    if (Motion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = Motion.reduced(context);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = still ? 0.25 : _controller.value;
          return CustomPaint(
            painter: _OrbPainter(color: widget.color, t: t),
            child: widget.icon == null
                ? null
                : Center(
                    child: Icon(
                      widget.icon,
                      size: widget.size * 0.32,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final angle = t * 2 * math.pi;

    // The light source orbits, so the specular highlight drifts across the
    // surface — that motion is what sells the sphere.
    final light = Offset(
      center.dx + math.cos(angle) * radius * 0.36,
      center.dy - radius * 0.32 + math.sin(angle) * radius * 0.16,
    );

    // Ambient occlusion pooled under the orb.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.92),
        width: radius * 1.5,
        height: radius * 0.34,
      ),
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Body: a radial gradient offset toward the light gives the volume.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (light.dx - center.dx) / radius,
            (light.dy - center.dy) / radius,
          ),
          radius: 0.95,
          colors: [
            Color.lerp(color, Colors.white, 0.55)!,
            color,
            Color.lerp(color, Colors.black, 0.42)!,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Rim light on the shadowed edge — the detail that stops it looking like a
    // flat gradient circle.
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = SweepGradient(
          startAngle: angle,
          endAngle: angle + 2 * math.pi,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.35, 0.55, 0.75],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Specular hotspot.
    canvas.drawCircle(
      light,
      radius * 0.20,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.24),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t || old.color != color;
}

/// Two phone silhouettes in perspective that lean together and "click" when
/// a shared part is found. The compare screen's payoff moment.
class CompatibilityGlyph extends StatelessWidget {
  const CompatibilityGlyph({
    super.key,
    required this.matched,
    this.color,
    this.size = 88,
  });

  /// When true the phones align; when false they stay apart and tilted away.
  final bool matched;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: matched ? 1 : 0),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.emphasis,
      builder: (context, t, _) {
        return SizedBox(
          width: size * 1.5,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _phone(tint, -1, t),
              _phone(tint, 1, t),
              if (t > 0.55)
                Opacity(
                  opacity: ((t - 0.55) / 0.45).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: tint,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: tint.withValues(alpha: 0.45),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Icon(Icons.link_rounded,
                        size: size * 0.22, color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _phone(Color tint, double dir, double t) {
    // Apart and splayed at t=0; together and upright at t=1.
    final spread = (size * 0.42) * (1 - t * 0.45);
    final yaw = dir * (0.55 - 0.42 * t);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0016)
        ..translateByDouble(dir * spread, 0, 0, 1.0)
        ..rotateY(yaw)
        ..rotateZ(dir * 0.06 * (1 - t)),
      child: Container(
        width: size * 0.42,
        height: size * 0.78,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(size * 0.09),
          border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.6),
        ),
        child: Center(
          child: Container(
            width: size * 0.14,
            height: 3,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Celebratory burst for genuine wins (a shared part found). Deliberately
/// short and small — this is a professional tool, not a game.
class SuccessBurst extends StatefulWidget {
  const SuccessBurst({super.key, required this.trigger, required this.color});

  /// Change this value to fire the burst.
  final Object? trigger;
  final Color color;

  @override
  State<SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<SuccessBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(SuccessBurst old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && widget.trigger != null) {
      if (!Motion.reduced(context)) _controller.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _controller.isAnimating
            ? CustomPaint(
                painter: _BurstPainter(t: _controller.value, color: widget.color),
                size: const Size(160, 160),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);

    // Expanding ring.
    canvas.drawCircle(
      center,
      size.shortestSide * 0.22 + eased * size.shortestSide * 0.30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * fade
        ..color = color.withValues(alpha: 0.55 * fade),
    );

    // Particles.
    for (var i = 0; i < 10; i++) {
      final angle = (i / 10) * 2 * math.pi;
      final distance = eased * size.shortestSide * 0.42;
      final offset = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      canvas.drawCircle(
        offset,
        3.2 * fade,
        Paint()..color = color.withValues(alpha: 0.85 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
