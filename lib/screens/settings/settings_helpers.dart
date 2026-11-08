// lib/screens/settings/settings_helpers.dart
// Shared by every settings page: section container, status card,
// colour picker and the accent palette.

import 'package:flutter/material.dart';
import '../../theme/m3_motion.dart';
import '../../widgets/m3_components.dart';
import '../../l10n/l10n.dart';
import 'settings_rows.dart';

// (colour, preference value, l10n key of its name)
const kSettingsAccentOptions = [
  (Color(0xFF7C3AED), 'purple',  'accent_purple'),
  (Color(0xFF1D4ED8), 'blue',    'accent_blue'),
  (Color(0xFF059669), 'green',   'accent_green'),
  (Color(0xFFDC2626), 'red',     'accent_red'),
  (Color(0xFFD97706), 'orange',  'accent_orange'),
  (Color(0xFFDB2777), 'pink',    'accent_pink'),
  (Color(0xFF0F766E), 'teal',    'accent_teal'),
  (Color(0xFF607D8B), 'neutral', 'accent_neutral'),
];

// ── SettingsSection ───────────────────────────────────────────────────────────

class SettingsSection extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const SettingsSection({super.key, required this.label, required this.children});

  // Old pages still build plain ListTile / SwitchListTile rows: they are
  // re-dressed here so every setting shares the same Expressive look
  // (cookie icon badge, spring press, same spacing).
  static Widget _restyle(Widget w) {
    if (w is SwitchListTile) {
      final v = w.value;
      final cb = w.onChanged;
      return SettingTile(
        leading: w.secondary,
        title: w.title ?? const SizedBox.shrink(),
        subtitle: w.subtitle,
        enabled: cb != null,
        trailing: Switch(
          value: v,
          onChanged: cb == null ? null : (x) { m3Haptic(); cb(x); },
        ),
        onTap: cb == null ? null : () => cb(!v),
      );
    }
    if (w is ListTile) {
      return SettingTile(
        leading: w.leading,
        title: w.title ?? const SizedBox.shrink(),
        subtitle: w.subtitle,
        trailing: w.trailing,
        enabled: w.enabled,
        onTap: w.onTap,
        onLongPress: w.onLongPress,
      );
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final scheme = theme.colorScheme;
    final text   = theme.textTheme;
    final rows = children.where((c) => c is! Divider).map(_restyle).toList();

    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(label, style: text.titleSmall?.copyWith(
            color: scheme.primary, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      ),
      // Every switch shows a check in its thumb when on (M3 Expressive).
      Theme(
        data: theme.copyWith(
          switchTheme: SwitchThemeData(
            thumbIcon: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? const Icon(Icons.check_rounded)
                    : null),
          ),
        ),
        // Each row is its own tile: big outer corners, small inner corners.
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < rows.length; i++)
            M3SegmentTile(index: i, count: rows.length, child: rows[i]),
        ]),
      ),
    ]);

    // One-shot spring: the section fades in and rises into place.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: M3Motion.spatialDefaultDuration,
      curve: M3Motion.spatialDefault,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
      ),
      child: content,
    );
  }
}

// ── Bannière "redémarrage requis" ─────────────────────────────────────────────

// ── Status card (top of a settings page) ───────────────────────────────────
// Big card that shows if a feature is on or off. The shape and color morph
// between the two states, the icon pops, and the phone gives a small
// vibration when the state flips.
class SettingsStatusCard extends StatefulWidget {
  final bool on;
  final String title;
  final String subtitle;
  final IconData iconOn;
  final IconData iconOff;
  final String? pill; // small tonal label on the right (optional)
  const SettingsStatusCard({
    super.key,
    required this.on,
    required this.title,
    required this.subtitle,
    required this.iconOn,
    required this.iconOff,
    this.pill,
  });

  @override
  State<SettingsStatusCard> createState() => _SettingsStatusCardState();
}

class _SettingsStatusCardState extends State<SettingsStatusCard> {
  @override
  void didUpdateWidget(SettingsStatusCard old) {
    super.didUpdateWidget(old);
    if (old.on != widget.on) m3Haptic(M3Haptic.medium);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text   = Theme.of(context).textTheme;
    final on = widget.on;
    final fg = on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return M3ShapeMorph(
      radius: BorderRadius.circular(on ? 36 : 24),
      color: on ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        M3CookieBadge(
          size: 60,
          color: on ? scheme.primary : scheme.surfaceContainerHighest,
          child: AnimatedSwitcher(
            duration: M3Motion.effectsDefaultDuration,
            switchInCurve: M3Motion.spatialFast,
            transitionBuilder: (c, a) =>
                ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
            child: Icon(
              on ? widget.iconOn : widget.iconOff,
              key: ValueKey(on),
              size: 30,
              color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: AnimatedSwitcher(
            duration: M3Motion.effectsDefaultDuration,
            child: Column(
              key: ValueKey('${widget.on}|${widget.title}|${widget.subtitle}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, color: fg)),
                const SizedBox(height: 4),
                Text(widget.subtitle,
                    style: text.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ),
        if (widget.pill != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: M3ShapeMorph(
              radius: BorderRadius.circular(14),
              color: scheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(widget.pill!,
                  style: text.labelLarge?.copyWith(
                      color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

class RestartBanner extends StatelessWidget {
  const RestartBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 16, color: scheme.onTertiaryContainer),
        const SizedBox(width: 10),
        Expanded(child: Text(
          L.restartHintFeatures,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onTertiaryContainer),
        )),
      ]),
    );
  }
}

// ── ColorPickerDialog (public) ────────────────────────────────────────────────

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const ColorPickerDialog({super.key, required this.initialColor});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSLColor _hsl;
  late TextEditingController _hexCtrl;
  bool _hexError = false;

  @override
  void initState() {
    super.initState();
    // Load the initial color as-is — no clamping.
    // Black, white, and any gray are all valid choices.
    _hsl = HSLColor.fromColor(widget.initialColor);
    _hexCtrl = TextEditingController(text: colorToHex(_hsl.toColor()));
  }

  @override
  void dispose() { _hexCtrl.dispose(); super.dispose(); }

  Color get _color => _hsl.toColor();

  void _syncHex() {
    _hexCtrl.text = colorToHex(_color);
    _hexCtrl.selection = TextSelection.collapsed(offset: _hexCtrl.text.length);
    _hexError = false;
  }

  void _onHexInput(String raw) {
    final hex = raw.trim().replaceAll('#', '');
    if (hex.length != 6) { setState(() => _hexError = true); return; }
    try {
      final c = Color(0xFF000000 | int.parse(hex, radix: 16));
      setState(() { _hsl = HSLColor.fromColor(c); _hexError = false; });
    } catch (_) { setState(() => _hexError = true); }
  }

  Widget _hueSlider() => LayoutBuilder(builder: (_, c) => GestureDetector(
    onTapDown:   (d) => setState(() { _hsl = _hsl.withHue((d.localPosition.dx / c.maxWidth).clamp(0, 1) * 360); _syncHex(); }),
    onPanUpdate: (d) => setState(() { _hsl = _hsl.withHue((d.localPosition.dx / c.maxWidth).clamp(0, 1) * 360); _syncHex(); }),
    child: SizedBox(height: 36, child: Stack(alignment: Alignment.centerLeft, children: [
      ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(height: 24,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [
            Color(0xFFFF0000), Color(0xFFFF8000), Color(0xFFFFFF00),
            Color(0xFF00FF00), Color(0xFF00FFFF), Color(0xFF0000FF),
            Color(0xFFFF00FF), Color(0xFFFF0000),
          ])))),
      Positioned(
        left: ((_hsl.hue / 360) * c.maxWidth - 12).clamp(0, c.maxWidth - 24),
        child: Container(width: 24, height: 36, decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black26, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        )),
      ),
    ])),
  ));

  Widget _sliderRow(String label, double value, double min, double max,
      List<Color> gradient, void Function(double) onChange) =>
    LayoutBuilder(builder: (_, c) => GestureDetector(
      onTapDown:   (d) => setState(() { onChange(((d.localPosition.dx / c.maxWidth) * (max - min) + min).clamp(min, max)); _syncHex(); }),
      onPanUpdate: (d) => setState(() { onChange(((d.localPosition.dx / c.maxWidth) * (max - min) + min).clamp(min, max)); _syncHex(); }),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        SizedBox(height: 28, child: Stack(alignment: Alignment.centerLeft, children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: Container(height: 20,
              decoration: BoxDecoration(gradient: LinearGradient(colors: gradient)))),
          Positioned(
            left: (((value - min) / (max - min)) * c.maxWidth - 10).clamp(0, c.maxWidth - 20),
            child: Container(width: 20, height: 28, decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.black26, width: 1.5),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
            )),
          ),
        ])),
      ]),
    ));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text   = Theme.of(context).textTheme;
    final pure   = _hsl.withSaturation(1.0).withLightness(0.5).toColor();

    // Quick presets — includes black and white for monochromatic themes
    const quickPresets = [
      Color(0xFF7C3AED), Color(0xFF1D4ED8), Color(0xFF059669), Color(0xFFDC2626),
      Color(0xFFD97706), Color(0xFFDB2777), Color(0xFF0F766E), Color(0xFFEA580C),
      Color(0xFF0284C7), Color(0xFF16A34A),
      Color(0xFF000000), // Black — produces a neutral dark theme
      Color(0xFFFFFFFF), // White — produces a neutral light theme
    ];

    return AlertDialog(
      title: Text(L.colorPickerTitle),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(width: 340, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Container(height: 52, decoration: BoxDecoration(
                color: _color, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant)))),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _hexCtrl, onChanged: _onHexInput,
              decoration: InputDecoration(
                labelText: 'HEX',
                errorText: _hexError ? L.colorPickerInvalid : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              style: text.bodyMedium?.copyWith(fontFamily: 'monospace'),
            )),
          ]),
          const SizedBox(height: 16),
          Text(L.colorPickerHue, style: text.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _hueSlider(),
          const SizedBox(height: 14),
          _sliderRow(L.colorPickerSaturation, _hsl.saturation, 0.0, 1.0,
            [Colors.grey.shade400, pure], (v) => _hsl = _hsl.withSaturation(v)),
          const SizedBox(height: 14),
          _sliderRow(L.colorPickerBrightness, _hsl.lightness, 0.0, 1.0,
            [Colors.black, _hsl.withSaturation(1.0).withLightness(0.5).toColor(), Colors.white],
            (v) => _hsl = _hsl.withLightness(v)),
          const SizedBox(height: 16),
          Text(L.colorPickerQuickColors, style: text.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: quickPresets.map((c) => GestureDetector(
            onTap: () => setState(() { _hsl = HSLColor.fromColor(c); _syncHex(); }),
            child: Container(width: 28, height: 28, decoration: BoxDecoration(
                color: c, shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant, width: 1))),
          )).toList()),
          const SizedBox(height: 16),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(L.commonCancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _color), child: Text(L.commonApply)),
      ],
    );
  }
}
