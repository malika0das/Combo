import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';

/// ---------------------------------------------------------------------------
/// Motion system
/// ---------------------------------------------------------------------------
/// One place for every duration and curve in the app. Motion is expressive but
/// *fast*: this is a tool used at a counter with a customer waiting, so nothing
/// should ever make the technician wait for an animation to finish.
class Motion {
  const Motion._();

  /// Feedback on a tap — must feel instant.
  static const instant = Duration(milliseconds: 90);

  /// Micro-interactions: chips, icons, toggles.
  static const quick = Duration(milliseconds: 180);

  /// Standard element entrance / state change.
  static const base = Duration(milliseconds: 280);

  /// Emphasised: hero panels, counters counting up.
  static const slow = Duration(milliseconds: 460);

  /// Delay between successive items in a staggered list.
  static const stagger = Duration(milliseconds: 38);

  /// Deceleration for elements entering the screen.
  static const enter = Curves.easeOutCubic;

  /// For elements leaving — quicker off the screen than onto it.
  static const exit = Curves.easeInCubic;

  /// Springy, confident emphasis. Used sparingly on success moments.
  static const emphasis = Curves.easeOutBack;

  /// Smooth both ends, for continuous/looping motion.
  static const smooth = Curves.easeInOutCubic;

  /// Respects the OS "reduce motion" accessibility setting. Every animated
  /// widget below routes through this, so one system switch calms the whole app.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Light haptic vocabulary. Distinct physical "words" for distinct meanings, so
/// the user learns them without ever reading a label.
class Haptics {
  const Haptics._();

  /// Navigating, opening, expanding.
  static void tap() => HapticFeedback.selectionClick();

  /// Something was added or confirmed.
  static void confirm() => HapticFeedback.lightImpact();

  /// Something was removed, or a search found nothing.
  static void warn() => HapticFeedback.mediumImpact();
}

/// ---------------------------------------------------------------------------
/// Micro-interactions
/// ---------------------------------------------------------------------------

/// Wraps any tappable surface so it dips slightly under the finger. The single
/// highest-value micro-interaction: it makes the whole UI feel physical.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.haptic = true,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final BorderRadius? borderRadius;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) Haptics.tap();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down && enabled ? widget.scale : 1.0,
        duration: Motion.of(context, Motion.instant),
        curve: Motion.enter,
        child: widget.child,
      ),
    );
  }
}

/// Fades and lifts a widget into place, optionally offset by [index] so a list
/// arrives as a soft cascade rather than a hard snap.
class EntranceFade extends StatelessWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
    this.maxStaggered = 12,
  });

  final Widget child;
  final int index;
  final double offset;

  /// Beyond this index items appear immediately — a 1,000-row list must never
  /// make the user wait for a cascade.
  final int maxStaggered;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final steps = index.clamp(0, maxStaggered);
    final delay = Motion.stagger * steps;
    return _DelayedBuild(
      delay: delay,
      placeholder: Opacity(opacity: 0, child: child),
      builder: () => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.base,
        curve: Motion.enter,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, offset * (1 - t)), child: child),
        ),
        child: child,
      ),
    );
  }
}

class _DelayedBuild extends StatefulWidget {
  const _DelayedBuild({
    required this.delay,
    required this.builder,
    required this.placeholder,
  });

  final Duration delay;
  final Widget Function() builder;
  final Widget placeholder;

  @override
  State<_DelayedBuild> createState() => _DelayedBuildState();
}

class _DelayedBuildState extends State<_DelayedBuild> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ready = true;
    } else {
      // A cancellable Timer, not Future.delayed: scrolling a long list creates
      // and destroys these constantly, and an uncancellable future keeps the
      // whole element tree alive until it fires.
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _ready = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.builder() : widget.placeholder;
}

/// A number that rolls up to its value. Used for model/list counts, where the
/// motion quietly communicates "this catalog is big".
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.grouped = false,
  });

  final int value;
  final TextStyle? style;
  final String suffix;

  /// Insert thousands separators ("5,675").
  ///
  /// Grouped counters also get tabular figures, so a rolling number does not
  /// shuffle sideways as digits change width mid-count.
  final bool grouped;

  TextStyle? get _style {
    if (!grouped) return style;
    return (style ?? const TextStyle())
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  }

  String _render(int v) => '${grouped ? groupDigits(v) : '$v'}$suffix';

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      return Text(_render(value), style: _style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: Motion.slow,
      curve: Motion.enter,
      builder: (context, v, _) => Text(_render(v.round()), style: _style),
    );
  }
}

/// Cross-fades between two states of the same slot without any layout jump.
class SoftSwitcher extends StatelessWidget {
  const SoftSwitcher({super.key, required this.child, this.alignment = Alignment.center});

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.quick),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A slow, looping shimmer used only on skeleton placeholders.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Under reduced motion the shimmer is not painted, so running the ticker
    // would burn frames to produce a value nothing reads. TickerMode already
    // pauses it off-screen; this covers the accessibility case.
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
    if (Motion.reduced(context)) return widget.child;
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Color.alphaBlend(
      Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
      base,
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [base, highlight, base],
          stops: const [0.1, 0.5, 0.9],
          begin: Alignment(-1.6 + 3.2 * _controller.value, -0.3),
          end: Alignment(-0.6 + 3.2 * _controller.value, 0.3),
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}
