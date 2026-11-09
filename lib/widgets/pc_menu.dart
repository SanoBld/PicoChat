// lib/widgets/pc_menu.dart
// Menu rows in the app style: rounded pill, selected row tinted, icon at the
// start, check at the end. Use inside PopupMenuButton / showMenu.

import 'package:flutter/material.dart';

class PcMenuItem<T> extends PopupMenuEntry<T> {
  const PcMenuItem({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.selected = false,
    this.danger = false,
    this.maxWidth = 240,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool selected;
  final bool danger;
  final double maxWidth;

  @override
  double get height => 48;

  @override
  bool represents(T? v) => v == value;

  @override
  State<PcMenuItem<T>> createState() => _PcMenuItemState<T>();
}

class _PcMenuItemState<T> extends State<PcMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = widget.danger
        ? scheme.error
        : widget.selected
            ? scheme.onSecondaryContainer
            : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: widget.selected ? scheme.secondaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pop<T>(context, widget.value),
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 20, color: widget.danger ? scheme.error : (widget.selected ? fg : scheme.onSurfaceVariant)),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: fg, fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600)),
                  ),
                  if (widget.selected) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.check_rounded, size: 20, color: fg),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PcMenuDivider extends PopupMenuEntry<Never> {
  const PcMenuDivider({super.key});

  @override
  double get height => 13;

  @override
  bool represents(void value) => false;

  @override
  State<PcMenuDivider> createState() => _PcMenuDividerState();
}

class _PcMenuDividerState extends State<PcMenuDivider> {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: SizedBox(
          height: 1,
          child: ColoredBox(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      );
}
