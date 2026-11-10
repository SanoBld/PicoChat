// lib/widgets/opening_splash.dart
// Discreet start animation: a thin light of the theme colours travels once around
// the outline of the "Write a message" block, then fades away. It is only drawn
// on the border (nothing covers the screen, touches go through).
// Plays once per app start. Skipped when the option is off or energy saving is on.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/m3_motion.dart';

class ComposerIntro extends StatefulWidget {
  final Widget child; // the message block
  final double radius;
  const ComposerIntro({super.key, required this.child, this.radius = 28});

  static bool _played = false; // once per app start

  @override
  State<ComposerIntro> createState() => _ComposerIntroState();
}

class _ComposerIntroState extends State<ComposerIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _play = false;

  @override
  void initState() {
    super.initState();
    // Decide BEFORE marking it as played (otherwise it would never play).
    _play = !ComposerIntro._played && openingAnimNotifier.value && !ecoModeNotifier.value;
    ComposerIntro._played = true;
    if (_play) {
      // Let the home screen settle first, so the light is noticed.
      Future<void>.delayed(const Duration(milliseconds: 450), () {
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
  Widget build(BuildContext context) {
    if (!_play) return widget.child;
    final s = Theme.of(context).colorScheme;
    return Stack(clipBehavior: Clip.none, children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => (_c.value <= 0 || _c.value >= 1)
                ? const SizedBox.shrink()
                : CustomPaint(painter: _BorderLightPainter(_c.value, widget.radius, [s.primary, s.tertiary, s.secondary])),
          ),
        ),
      ),
    ]);
  }
}

class _BorderLightPainter extends CustomPainter {
  final double v, r;
  final List<Color> colors;
  _BorderLightPainter(this.v, this.r, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect.deflate(0.75), Radius.circular(r));
    final turn = M3Motion.emphasized.transform(v) * 2 * math.pi; // one full lap
    final env = math.sin(math.pi * v); // fades in, then out
    final shader = SweepGradient(
      colors: [Colors.transparent, colors[0], colors[1], colors[2], Colors.transparent],
      stops: const [0.0, 0.18, 0.4, 0.55, 0.62],
      transform: GradientRotation(turn),
    ).createShader(rect);
    canvas.saveLayer(rect.inflate(20), Paint()..color = Colors.white.withValues(alpha: env));
    canvas.drawRRect(rr, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 6..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawRRect(rr, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BorderLightPainter o) => o.v != v;
}
