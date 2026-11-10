// lib/widgets/assist_fx.dart
// Assistant card effects: dim + coloured glow around the screen, and the
// "circle what you want" picker drawn over the screenshot.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

// ── Glow around the screen edge ─────────────────────────────────────────────
class AssistGlow extends StatelessWidget {
  final double enter; // 0..1 opening progress
  final double t; // 0..1 looping time
  final bool dim;
  final List<Color> colors;
  const AssistGlow({super.key, required this.enter, required this.t, required this.dim, required this.colors});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.infinite, painter: _GlowPainter(enter.clamp(0.0, 1.0), t, dim, colors));
}

class _GlowPainter extends CustomPainter {
  final double e, t;
  final bool dim;
  final List<Color> colors;
  _GlowPainter(this.e, this.t, this.dim, this.colors);

  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    if (dim) c.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.30 * e));
    if (e <= 0) return;
    final rr = RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(38));
    final shader = SweepGradient(
      colors: [...colors, colors.first],
      transform: GradientRotation(t * 2 * math.pi),
    ).createShader(rect);
    final a = e * (0.6 + 0.25 * math.sin(t * 4 * math.pi));
    c.saveLayer(rect, Paint()..color = Colors.white.withValues(alpha: a));
    c.drawRRect(rr, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 18..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24));
    c.drawRRect(rr, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 3);
    c.restore();
  }

  @override
  bool shouldRepaint(_GlowPainter o) => o.e != e || o.t != t || o.dim != dim;
}

// ── Circle-to-search picker ─────────────────────────────────────────────────
class LensSelect extends StatefulWidget {
  final Uint8List shot;
  final void Function(Rect normalized) onDone; // 0..1 rectangle of the screenshot
  final VoidCallback onCancel;
  final String hint;
  const LensSelect({super.key, required this.shot, required this.onDone, required this.onCancel, required this.hint});

  @override
  State<LensSelect> createState() => _LensSelectState();
}

class _LensSelectState extends State<LensSelect> with SingleTickerProviderStateMixin {
  late final MemoryImage _img = MemoryImage(widget.shot);
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  final List<Offset> _pts = [];
  Rect? _picked; // the chosen area (screen pixels)
  Size _box = Size.zero;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _finish() {
    if (_pts.length < 8) return _reset();
    var minX = _pts.first.dx, maxX = minX, minY = _pts.first.dy, maxY = minY;
    for (final p in _pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    var r = Rect.fromLTRB(minX, minY, maxX, maxY);
    if (r.width < 28 && r.height < 28) return _reset();
    r = r.inflate(math.max(r.shortestSide * 0.08, 10)).intersect(Offset.zero & _box);
    setState(() => _picked = r);
    widget.onDone(Rect.fromLTRB(r.left / _box.width, r.top / _box.height, r.right / _box.width, r.bottom / _box.height));
  }

  void _reset() => setState(() => _pts.clear());

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (ctx, cs) {
      _box = cs.biggest;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          if (_picked != null) return;
          setState(() => _pts..clear()..add(d.localPosition));
        },
        onPanUpdate: (d) {
          if (_picked != null) return;
          setState(() => _pts.add(d.localPosition));
        },
        onPanEnd: (_) {
          if (_picked == null) _finish();
        },
        child: Stack(fit: StackFit.expand, children: [
          Image(image: _img, fit: BoxFit.fill, gaplessPlayback: true),
          CustomPaint(painter: _LensPainter(_pts, _picked, [s.primary, s.tertiary, s.secondary], _t)),
          if (_picked == null && _pts.isEmpty)
            Positioned(
              top: MediaQuery.paddingOf(ctx).top + 14,
              left: 20,
              right: 72,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: s.surfaceContainerHigh.withValues(alpha: 0.92),
                  shape: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 9, 18, 9),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.gesture_rounded, size: 18, color: s.primary),
                      const SizedBox(width: 8),
                      Flexible(child: Text(widget.hint, style: Theme.of(ctx).textTheme.labelLarge)),
                    ]),
                  ),
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.paddingOf(ctx).top + 6,
            right: 10,
            child: IconButton.filledTonal(onPressed: widget.onCancel, icon: const Icon(Icons.close_rounded)),
          ),
        ]),
      );
    });
  }
}

class _LensPainter extends CustomPainter {
  final List<Offset> pts;
  final Rect? picked;
  final List<Color> colors;
  final Animation<double> t;
  _LensPainter(this.pts, this.picked, this.colors, this.t) : super(repaint: t);

  @override
  void paint(Canvas c, Size s) {
    final full = Offset.zero & s;
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.42);
    if (picked != null) {
      // Dark everywhere except the picked area.
      final hole = RRect.fromRectAndRadius(picked!, const Radius.circular(24));
      c.drawPath(Path.combine(PathOperation.difference, Path()..addRect(full), Path()..addRRect(hole)), dim);
      c.drawRRect(hole, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
    } else {
      c.drawRect(full, dim);
    }
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    if (picked == null) {
      final b = path.getBounds();
      final shader = SweepGradient(colors: [...colors, colors.first], transform: GradientRotation(t.value * 2 * math.pi))
          .createShader(b.inflate(8));
      final pen = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      c.drawPath(path, pen..shader = shader..strokeWidth = 16..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = Colors.white..strokeWidth = 4);
    }
  }

  @override
  bool shouldRepaint(_LensPainter o) => true;
}
