// lib/widgets/pc_motion.dart
// Small animation widgets shared by the chat and the model store:
// entrance fade/slide, "thinking" dots, shimmering label, breathing avatar
// and the wavy loading bar (indeterminate).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/m3_motion.dart';
import 'm3_components.dart';

/// Capped stagger delay for lists: item 40 does not wait 1.4 s to appear.
Duration staggerDelay(int index, {int stepMs = 35}) =>
    Duration(milliseconds: index.clamp(0, 10) * stepMs);

// ── Entrance: fade + gentle upward slide ────────────────────────────────────
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.skip = false,
    this.dx = 0,
  });

  final Widget child;
  final Duration delay;
  final bool skip; // appear already in place
  final double dx; // horizontal start offset (fraction of the width)

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: M3Motion.emphasizedDecelerate);
  late final Animation<Offset> _slide = Tween<Offset>(begin: Offset(widget.dx, 0.06), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: M3Motion.emphasizedDecelerate));

  @override
  void initState() {
    super.initState();
    if (widget.skip) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ── Wavy loading bar with an optional label ─────────────────────────────────
class WavyLoader extends StatelessWidget {
  const WavyLoader({super.key, this.width = 200, this.label});
  final double width;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: width, child: const M3WavyProgress(indeterminate: true, height: 14)),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(label!, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}

// ── Three dots that bounce one after the other ──────────────────────────────
class ThinkingDots extends StatefulWidget {
  const ThinkingDots({super.key, this.size = 8, this.color});
  final double size;
  final Color? color;

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (M3Motion.reduced(context)) {
      _c.stop();
      _started = false;
    } else if (!_started) {
      _c.repeat();
      _started = true;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final d = widget.size;
    return SizedBox(
      height: d * 2.6,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 3; i++)
            Builder(builder: (_) {
              final wave = math.max(0.0, math.sin((_c.value - i * 0.14) * 2 * math.pi));
              return Container(
                margin: EdgeInsets.symmetric(horizontal: d * 0.28),
                transform: Matrix4.translationValues(0, -wave * d * 1.1, 0),
                width: d,
                height: d,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.4 + 0.6 * wave),
                  shape: BoxShape.circle,
                ),
              );
            }),
        ]),
      ),
    );
  }
}

// ── Label with a light sweep ────────────────────────────────────────────────
class ShimmerText extends StatefulWidget {
  const ShimmerText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);
  final double t;
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (2 * t - 1), 0, 0);
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (M3Motion.reduced(context)) {
      _c.stop();
      _started = false;
    } else if (!_started) {
      _c.repeat();
      _started = true;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.onSurfaceVariant;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          colors: [base, scheme.primary, base],
          stops: const [0.25, 0.5, 0.75],
          transform: _SlideGradient(_c.value),
        ).createShader(rect),
        child: child,
      ),
      child: Text(widget.text, style: widget.style),
    );
  }
}

// ── Breathing scale (avatar while the model is working) ─────────────────────
class PulseScale extends StatefulWidget {
  const PulseScale({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<PulseScale> createState() => _PulseScaleState();
}

class _PulseScaleState extends State<PulseScale> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _scale =
      Tween<double>(begin: 1, end: 1.14).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  void _sync() {
    if (widget.active && !M3Motion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.animateTo(0, duration: const Duration(milliseconds: 250));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseScale old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}


// ── Text being written: the end fades in softly (reverse fade) ───────────────
class StreamFade extends StatelessWidget {
  const StreamFade({super.key, required this.active, required this.child, this.fadeHeight = 44});
  final bool active;
  final Widget child;
  final double fadeHeight;

  @override
  Widget build(BuildContext context) {
    if (M3Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: active ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      child: child,
      builder: (_, v, ch) {
        if (v == 0) return ch!;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) {
            final h = r.height <= 0 ? 1.0 : r.height;
            final f = (fadeHeight / h).clamp(0.0, 1.0);
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.white.withValues(alpha: 1 - 0.85 * v)],
              stops: [0, 1 - f, 1],
            ).createShader(r);
          },
          child: ch,
        );
      },
    );
  }
}
