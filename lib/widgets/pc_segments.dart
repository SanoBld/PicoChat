// lib/widgets/pc_segments.dart
// Expressive selector: animated rounded pills (replaces SegmentedButton).
import 'package:flutter/material.dart';

class PcSegments<T> extends StatelessWidget {
  final List<(T, String, IconData?)> items;
  final T? value;
  final ValueChanged<T> onChanged;
  final double height;
  const PcSegments({super.key, required this.items, required this.value, required this.onChanged, this.height = 52});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Row(children: [
      for (final (i, it) in items.indexed)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(it.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  height: height,
                  decoration: ShapeDecoration(
                    color: it.$1 == value ? s.primary : s.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(it.$1 == value ? height / 2 : 18)),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (it.$3 != null)
                      AnimatedScale(
                        scale: it.$1 == value ? 1.15 : 1,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        child: Icon(it.$3, size: 20, color: it.$1 == value ? s.onPrimary : s.onSurfaceVariant),
                      ),
                    Text(it.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800, color: it.$1 == value ? s.onPrimary : s.onSurface)),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
