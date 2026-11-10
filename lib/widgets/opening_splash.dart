// lib/widgets/opening_splash.dart
// Launch animation in the colours of the app: the smiley pops in with a turning
// light ring and soft waves, "PicoChat" appears letter by letter, then a round
// wave with a glowing edge opens the app.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_state.dart';
import 'pico_avatar.dart';
import 'pico_face.dart' show PicoMood;

class OpeningGate extends StatefulWidget {
  final Widget child;
  const OpeningGate({super.key, required this.child});

  static bool _played = false; // once per app start

  @override
  State<OpeningGate> createState() => _OpeningGateState();
}

class _OpeningGateState extends State<OpeningGate> {
  late bool _show;

  @override
  void initState() {
    super.initState();
    // Off when the option is off or energy saving is on.
    _show = !OpeningGate._played && openingAnimNotifier.value && !ecoModeNotifier.value;
    OpeningGate._played = true;
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        if (_show) Positioned.fill(child: _Splash(onDone: () => setState(() => _show = false))),
      ]);
}

double _seg(double t, double a, double b, [Curve k = Curves.linear]) => k.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

class _Splash extends StatefulWidget {
  final VoidCallback onDone;
  const _Splash({required this.onDone});
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _word = 'PicoChat';

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    final c = Offset(size.width / 2, size.height / 2 - 24);
    final maxR = math.sqrt(size.width * size.width + size.height * size.height);
    final colors = [s.primary, s.tertiary, s.secondary];
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final v = _c.value;
        final pop = _seg(v, 0.0, 0.3, Curves.elasticOut);
        final out = _seg(v, 0.6, 0.82, Curves.easeIn);
        final reveal = _seg(v, 0.64, 1.0, Curves.easeInOutCubic);
        return IgnorePointer(
          child: Stack(fit: StackFit.expand, children: [
            ClipPath(
              clipper: _HoleClipper(c, reveal * maxR),
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: s.surface),
                CustomPaint(painter: _AuraPainter(v, c, colors)),
                Opacity(
                  opacity: 1 - out,
                  child: Transform.scale(
                    scale: 1 + 0.18 * out,
                    child: Stack(children: [
                      Positioned(
                        left: c.dx - 48,
                        top: c.dy - 48,
                        width: 96,
                        height: 96,
                        child: Transform.scale(
                          scale: pop,
                          child: Transform.rotate(
                            angle: (1 - pop.clamp(0.0, 1.0)) * -0.7,
                            child: PicoAvatar(size: 96, mood: v > 0.3 ? PicoMood.happy : PicoMood.idle),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: c.dy + 84,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (var i = 0; i < _word.length; i++)
                            Builder(builder: (_) {
                              final k = _seg(v, 0.34 + i * 0.028, 0.5 + i * 0.028, Curves.easeOutCubic);
                              return Opacity(
                                opacity: k,
                                child: Transform.translate(
                                  offset: Offset(0, 16 * (1 - k)),
                                  child: Text(_word[i],
                                      style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1, color: s.onSurface)),
                                ),
                              );
                            }),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
            // Glowing edge of the round wave.
            CustomPaint(painter: _RimPainter(reveal, v, c, maxR, colors)),
          ]),
        );
      },
    );
  }
}

class _HoleClipper extends CustomClipper<Path> {
  final Offset c;
  final double r;
  _HoleClipper(this.c, this.r);

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addOval(Rect.fromCircle(center: c, radius: r));

  @override
  bool shouldReclip(_HoleClipper o) => o.r != r || o.c != c;
}

class _AuraPainter extends CustomPainter {
  final double v;
  final Offset c;
  final List<Color> colors;
  _AuraPainter(this.v, this.c, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final glow = _seg(v, 0, 0.25) * (1 - _seg(v, 0.6, 0.8));
    // Soft light behind the smiley.
    final rg = 130 + 150 * _seg(v, 0, 0.35, Curves.easeOut);
    canvas.drawCircle(
      c,
      rg,
      Paint()
        ..shader = RadialGradient(colors: [colors[0].withValues(alpha: 0.32 * glow), colors[0].withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: rg)),
    );
    // Three waves leaving the smiley.
    for (var i = 0; i < 3; i++) {
      final p = ((v - 0.14 - 0.09 * i) / 0.42).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
        c,
        58 + 240 * Curves.easeOutCubic.transform(p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = colors[i].withValues(alpha: (1 - p) * 0.5),
      );
    }
    // Turning ring of light.
    final a = _seg(v, 0.02, 0.2) * (1 - _seg(v, 0.62, 0.78));
    if (a > 0) {
      final rect = Rect.fromCircle(center: c, radius: 66);
      final shader = SweepGradient(colors: [...colors, colors.first], transform: GradientRotation(v * math.pi * 5)).createShader(rect);
      canvas.saveLayer(rect.inflate(30), Paint()..color = Colors.white.withValues(alpha: a));
      canvas.drawCircle(c, 66, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawCircle(c, 66, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 4);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AuraPainter o) => o.v != v;
}

class _RimPainter extends CustomPainter {
  final double reveal, v, maxR;
  final Offset c;
  final List<Color> colors;
  _RimPainter(this.reveal, this.v, this.c, this.maxR, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0 || reveal >= 1) return;
    final r = reveal * maxR;
    final rect = Rect.fromCircle(center: c, radius: r);
    final shader = SweepGradient(colors: [...colors, colors.first], transform: GradientRotation(v * math.pi * 6)).createShader(rect);
    canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 1 - reveal));
    canvas.drawCircle(c, r, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 22 * (1 - reveal) + 6..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    canvas.drawCircle(c, r, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RimPainter o) => o.reveal != reveal || o.v != v;
}
