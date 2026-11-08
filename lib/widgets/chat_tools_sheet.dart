// lib/widgets/chat_tools_sheet.dart
// Bottom sheet: power presets, sliders and voice reading.
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/l10n.dart';
import '../services/prefs.dart';

Future<void> showChatToolsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ToolsSheet(),
  );
}

class _ToolsSheet extends StatefulWidget {
  const _ToolsSheet();
  @override
  State<_ToolsSheet> createState() => _ToolsSheetState();
}

class _ToolsSheetState extends State<_ToolsSheet> {
  static const _ctxs = [2048, 4096, 8192, 16384];
  static const _presets = {
    'eco': (0.5, 512, 2048),
    'balanced': (0.7, 1024, 4096),
    'max': (0.8, 3072, 8192),
    'ultra': (0.6, 4096, 16384),
  };

  void _apply(double t, int m, int c, {bool ultra = false}) {
    setState(() {
      ultraModeNotifier.value = ultra;
      temperatureNotifier.value = t;
      maxTokensNotifier.value = m;
      contextSizeNotifier.value = c;
    });
    savePref('pc_ultra', ultra);
    savePref('pc_temperature', t);
    savePref('pc_max_tokens', m);
    savePref('pc_context_size', c);
  }

  String? get _current {
    if (ultraModeNotifier.value) return 'ultra';
    for (final e in _presets.entries) {
      final v = e.value;
      if (temperatureNotifier.value == v.$1 && maxTokensNotifier.value == v.$2 && contextSizeNotifier.value == v.$3) {
        return e.key;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ctxIndex = _ctxs.indexOf(contextSizeNotifier.value).clamp(0, _ctxs.length - 1);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('tools_power'), style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'eco', label: Text(tr('power_eco'))),
                ButtonSegment(value: 'balanced', label: Text(tr('power_balanced'))),
                ButtonSegment(value: 'max', label: Text(tr('power_max'))),
                ButtonSegment(value: 'ultra', icon: const Icon(Icons.auto_awesome_rounded, size: 16), label: Text(tr('power_ultra'))),
              ],
              selected: {?_current},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                final v = _presets[s.first]!;
                _apply(v.$1, v.$2, v.$3, ultra: s.first == 'ultra');
              },
            ),
          ),
          if (ultraModeNotifier.value)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr('ultra_hint'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 8),
          _row(text, scheme, tr('cs_temperature'), temperatureNotifier.value.toStringAsFixed(1)),
          Slider(
            min: 0,
            max: 1.5,
            divisions: 15,
            value: temperatureNotifier.value.clamp(0, 1.5),
            onChanged: (v) => setState(() => temperatureNotifier.value = double.parse(v.toStringAsFixed(1))),
            onChangeEnd: (v) => savePref('pc_temperature', double.parse(v.toStringAsFixed(1))),
          ),
          _row(text, scheme, tr('cs_max_tokens'), '${maxTokensNotifier.value}'),
          Slider(
            min: 256,
            max: 4096,
            divisions: 15,
            value: maxTokensNotifier.value.clamp(256, 4096).toDouble(),
            onChanged: (v) => setState(() => maxTokensNotifier.value = v.round()),
            onChangeEnd: (v) => savePref('pc_max_tokens', v.round()),
          ),
          _row(text, scheme, tr('tools_context'), '${_ctxs[ctxIndex]}'),
          Slider(
            min: 0,
            max: 3,
            divisions: 3,
            value: ctxIndex.toDouble(),
            onChanged: (v) => setState(() => contextSizeNotifier.value = _ctxs[v.round()]),
            onChangeEnd: (v) => savePref('pc_context_size', _ctxs[v.round()]),
          ),
          const SizedBox(height: 8),
          Text(tr('tools_web_max'), style: text.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 5, label: Text('5')),
                ButtonSegment(value: 10, label: Text('10')),
                ButtonSegment(value: 20, label: Text('20')),
                ButtonSegment(value: 0, label: Text('∞')),
              ],
              selected: {webMaxSourcesNotifier.value},
              onSelectionChanged: (s) {
                setState(() => webMaxSourcesNotifier.value = s.first);
                savePref('pc_web_max', s.first);
              },
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('tools_auto_speak')),
            value: autoSpeakNotifier.value,
            onChanged: (v) {
              setState(() => autoSpeakNotifier.value = v);
              savePref('pc_auto_speak', v);
            },
          ),
        ]),
      ),
    );
  }

  Widget _row(TextTheme text, ColorScheme scheme, String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(child: Text(label, style: text.titleSmall)),
          Text(value, style: text.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
        ]),
      );
}
