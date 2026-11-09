// lib/widgets/pico_avatar.dart
// The assistant's bubble: a cookie badge with the animated smiley.
// While the AI works the bubble changes shape and the face reacts to what is
// happening (loading, searching, thinking, writing). Tap = the face jumps for
// joy. Press and hold = the bubble spins on itself.

import 'package:flutter/material.dart';

import '../theme/m3_motion.dart';
import 'm3_components.dart' show M3CookieBadge;
import 'pico_face.dart';
import 'skeleton.dart' show M3MorphBlob;

class PicoAvatar extends StatefulWidget {
  const PicoAvatar({super.key, this.size = 34, this.mood = PicoMood.idle});

  final double size;

  /// What the AI is doing; the face and the bubble follow it.
  final PicoMood mood;

  @override
  State<PicoAvatar> createState() => _PicoAvatarState();
}

class _PicoAvatarState extends State<PicoAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  bool _held = false;
  int _poke = 0;

  static bool _busy(PicoMood m) =>
      m == PicoMood.loading || m == PicoMood.searching || m == PicoMood.thinking || m == PicoMood.writing;

  @override
  void didUpdateWidget(PicoAvatar old) {
    super.didUpdateWidget(old);
    // Answer finished: a small happy jump.
    if (_busy(old.mood) && !_busy(widget.mood) && widget.mood == PicoMood.idle) _poke++;
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _start() {
    if (M3Motion.reduced(context)) return;
    setState(() => _held = true);
    m3Haptic(M3Haptic.medium);
    _spin.repeat();
  }

  // Let go: finish the current turn with a soft slow-down.
  void _end() {
    if (!_held) return;
    setState(() => _held = false);
    final left = 1 - _spin.value;
    _spin
        .animateTo(1,
            duration: Duration(milliseconds: 350 + (900 * left).round()), curve: Curves.easeOutCubic)
        .whenComplete(() {
      if (mounted && !_held) _spin.value = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mood = _held ? PicoMood.excited : widget.mood;
    Widget face() => PicoFace(size: widget.size * 0.54, color: scheme.onPrimary, mood: mood, poke: _poke);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        m3Haptic(M3Haptic.light);
        setState(() => _poke++);
      },
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _end(),
      onLongPressCancel: _end,
      child: RotationTransition(
        turns: _spin,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _busy(widget.mood)
              ? M3MorphBlob(key: const ValueKey('blob'), size: widget.size, color: scheme.primary, child: face())
              : M3CookieBadge(key: const ValueKey('cookie'), size: widget.size, color: scheme.primary, child: face()),
        ),
      ),
    );
  }
}
