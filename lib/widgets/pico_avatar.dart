// lib/widgets/pico_avatar.dart
// The assistant's bubble: a cookie badge with the app's smiley.
// While the AI works the bubble itself changes shape (same morph as the
// loader). Press and hold it and it spins on itself.

import 'package:flutter/material.dart';

import '../theme/m3_motion.dart';
import 'brand_icon.dart';
import 'm3_components.dart' show M3CookieBadge;
import 'skeleton.dart' show M3MorphBlob;

class PicoAvatar extends StatefulWidget {
  const PicoAvatar({super.key, this.size = 34, this.active = false});

  final double size;

  /// True while the AI is loading, searching or writing: the bubble morphs.
  final bool active;

  @override
  State<PicoAvatar> createState() => _PicoAvatarState();
}

class _PicoAvatarState extends State<PicoAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  bool _held = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _start() {
    if (M3Motion.reduced(context)) return;
    _held = true;
    m3Haptic(M3Haptic.medium);
    _spin.repeat();
  }

  // Let go: finish the current turn with a soft slow-down.
  void _end() {
    if (!_held) return;
    _held = false;
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
    Widget face() => BrandIcon('assets/icons/app_logo.svg', Icons.sentiment_satisfied_rounded,
        size: widget.size * 0.54, color: scheme.onPrimary);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _end(),
      onLongPressCancel: _end,
      child: RotationTransition(
        turns: _spin,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: widget.active
              ? M3MorphBlob(key: const ValueKey('blob'), size: widget.size, color: scheme.primary, child: face())
              : M3CookieBadge(key: const ValueKey('cookie'), size: widget.size, color: scheme.primary, child: face()),
        ),
      ),
    );
  }
}
