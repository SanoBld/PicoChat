// lib/widgets/pico_face.dart
// The app's smiley, drawn with a painter so it can move: it blinks, winks,
// looks around, and reacts to what the AI is doing (loading a model,
// searching, thinking, writing). All values glide to their target, so every
// change of mood is smooth. Poke it (change [poke]) and it jumps for joy.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/m3_motion.dart';

enum PicoMood { idle, loading, searching, thinking, writing, happy, excited, sad }

class _Pose {
  double smile, mouthW, lookX, lookY, open, arch, tilt;
  _Pose(this.smile, this.mouthW, this.lookX, this.lookY, this.open, this.arch, this.tilt);

  void glide(_Pose t, double a) {
    smile += (t.smile - smile) * a;
    mouthW += (t.mouthW - mouthW) * a;
    lookX += (t.lookX - lookX) * a;
    lookY += (t.lookY - lookY) * a;
    open += (t.open - open) * a;
    arch += (t.arch - arch) * a;
    tilt += (t.tilt - tilt) * a;
  }
}

_Pose _target(PicoMood m, double t) {
  switch (m) {
    case PicoMood.idle:
      return _Pose(0.9, 1, math.sin(t * 0.5) * 0.2, math.sin(t * 0.37) * 0.05, 1, 0, math.sin(t * 0.4) * 0.02);
    case PicoMood.loading: // eyes circle slowly, small smile
      return _Pose(0.35, 0.85, math.cos(t * 2.2) * 0.7, math.sin(t * 2.2) * 0.5 - 0.1, 0.8, 0, math.sin(t * 1.1) * 0.05);
    case PicoMood.searching: // eyes dart left and right
      final s = math.sin(t * 3.4);
      return _Pose(0.5, 0.9, s.sign * math.sqrt(s.abs()) * 0.9, -0.05, 1.08, 0, 0);
    case PicoMood.thinking: // looks up and aside, head tilted
      return _Pose(0.15, 0.7, 0.55 + math.sin(t) * 0.1, -0.7, 0.95, 0, -0.06 + math.sin(t * 0.8) * 0.015);
    case PicoMood.writing: // reads along, mouth moves like talking
      final talk = ((math.sin(t * 10) + math.sin(t * 6.3 + 1)) / 4 + 0.5).clamp(0.0, 1.0);
      return _Pose(0.5 + 0.5 * talk, 1 - 0.25 * talk, math.sin(t * 1.5) * 0.55, 0.3, 0.9, 0, math.sin(t * 2) * 0.02);
    case PicoMood.happy:
      return _Pose(1.25, 1.05, 0, 0, 0.3, 1, 0);
    case PicoMood.excited:
      return _Pose(1.3, 1.08, 0, 0, 0.3, 1, math.sin(t * 10) * 0.08);
    case PicoMood.sad:
      return _Pose(-0.7, 0.8, 0, 0.5, 0.85, 0, 0.04);
  }
}

class _FaceModel extends ChangeNotifier {
  final pose = _Pose(0.9, 1, 0, 0, 1, 0, 0);
  double blinkL = 1, blinkR = 1, bounce = 0;
  void changed() => notifyListeners();
}

class PicoFace extends StatefulWidget {
  const PicoFace({
    super.key,
    required this.size,
    required this.color,
    this.mood = PicoMood.idle,
    this.animated = true,
    this.poke = 0,
  });

  /// Width and height of the box the face is drawn in.
  final double size;
  final Color color;
  final PicoMood mood;

  /// False = still picture (sidebar, about page).
  final bool animated;

  /// Change this number to make the face react (happy jump).
  final int poke;

  @override
  State<PicoFace> createState() => _PicoFaceState();
}

class _PicoFaceState extends State<PicoFace> with SingleTickerProviderStateMixin {
  final _m = _FaceModel();
  final _rnd = math.Random();
  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _t = 0;
  double _nextBlink = 2.2;
  double _blinkP = -1; // -1 = not blinking, else 0..1
  int _winkSide = 0; // 0 = both eyes, 1 = left, 2 = right
  double _pokeAt = -10;

  bool get _still => !widget.animated || M3Motion.reduced(context);

  @override
  void initState() {
    super.initState();
    final p = _target(widget.mood, 0);
    _m.pose.glide(p, 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _ticker?.stop();
      _m.pose.glide(_target(widget.mood, 0), 1);
      _m.blinkL = _m.blinkR = 1;
      _m.bounce = 0;
      _m.changed();
    } else {
      _ticker ??= createTicker(_tick);
      if (!_ticker!.isActive) {
        _last = Duration.zero;
        _ticker!.start();
      }
    }
  }

  @override
  void didUpdateWidget(PicoFace old) {
    super.didUpdateWidget(old);
    if (widget.poke != old.poke) _pokeAt = _t;
    if (_still) {
      _m.pose.glide(_target(widget.mood, 0), 1);
      _m.changed();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _m.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _t += dt;

    // A poke (or a finished answer) plays a short happy reaction.
    final since = _t - _pokeAt;
    final reacting = since >= 0 && since < 1.1;
    final mood = reacting ? PicoMood.excited : widget.mood;
    final fast = mood == PicoMood.writing || mood == PicoMood.searching || reacting;
    final a = 1 - math.exp(-dt * (fast ? 16 : 8));
    _m.pose.glide(_target(mood, _t), a);

    // Squash and stretch after a poke.
    _m.bounce = reacting ? math.exp(-4 * since) * math.sin(15 * since) * 0.13 : 0;

    // Blink every few seconds; sometimes a wink when idle.
    if (_blinkP < 0 && _t >= _nextBlink && !reacting && _m.pose.arch < 0.5) {
      _blinkP = 0;
      _winkSide = (mood == PicoMood.idle && _rnd.nextDouble() < 0.18) ? 1 + _rnd.nextInt(2) : 0;
    }
    var f = 1.0;
    if (_blinkP >= 0) {
      _blinkP += dt / (_winkSide == 0 ? 0.18 : 0.3);
      if (_blinkP >= 1) {
        _blinkP = -1;
        _nextBlink = _t + 2 + _rnd.nextDouble() * 3;
      } else {
        f = 1 - math.sin(math.pi * _blinkP);
      }
    }
    _m.blinkL = (_winkSide == 2) ? 1 : f;
    _m.blinkR = (_winkSide == 1) ? 1 : f;
    _m.changed();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _FacePainter(_m, widget.color),
        ),
      );
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.m, this.color) : super(repaint: m);
  final _FaceModel m;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = m.pose;
    // The glyph lives in a 1024 box; its visible centre is (512, 505).
    final k = size.width / 1024 * 1.5;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(p.tilt);
    canvas.scale(k * (1 - m.bounce * 0.6), k * (1 + m.bounce));
    canvas.translate(-512, -505);

    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Eyes: pills that squash to a line when they blink, or arches when happy.
    for (var i = 0; i < 2; i++) {
      final cx = (i == 0 ? 348.0 : 676.0) + p.lookX * 34;
      final cy = 357.0 + p.lookY * 44 + p.arch * 10;
      final open = p.open * (i == 0 ? m.blinkL : m.blinkR);
      final h = (250 * open).clamp(18.0, 300.0);
      if (p.arch < 0.98) {
        fill.color = color.withValues(alpha: color.a * (1 - p.arch));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(cx, cy), width: 96, height: h), Radius.circular(math.min(48, h / 2))),
          fill,
        );
      }
      if (p.arch > 0.02) {
        stroke
          ..strokeWidth = 80
          ..color = color.withValues(alpha: color.a * p.arch);
        final path = Path()
          ..moveTo(cx - 62, cy + 30)
          ..quadraticBezierTo(cx, cy - 90, cx + 62, cy + 30);
        canvas.drawPath(path, stroke);
      }
    }

    // Mouth: one curve; below the line = smile, above = frown.
    final halfW = 276 * p.mouthW;
    final down = p.smile < 0 ? -p.smile * 90 : 0.0;
    final y0 = 600 + down;
    final ctrl = 600 + 260 * p.smile + down;
    stroke
      ..strokeWidth = 96
      ..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(512 - halfW, y0)
        ..quadraticBezierTo(512, ctrl, 512 + halfW, y0),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.color != color || old.m != m;
}
