// lib/widgets/pc_pointer.dart
// Last known pointer position (mouse or finger) in screen coordinates, so
// small widgets like Pico's face can look at it.

import 'package:flutter/material.dart';

final ValueNotifier<Offset?> pcPointer = ValueNotifier<Offset?>(null);

class PcPointerTracker extends StatelessWidget {
  const PcPointerTracker({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: (e) => pcPointer.value = e.position,
        onPointerMove: (e) => pcPointer.value = e.position,
        onPointerDown: (e) => pcPointer.value = e.position,
        child: child,
      );
}
