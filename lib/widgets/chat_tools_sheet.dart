// lib/widgets/chat_tools_sheet.dart
// Bottom sheet: quick options (power, reasoning, automatic actions, voice reading).
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/l10n.dart';
import '../services/location_service.dart';
import '../services/prefs.dart';
import 'pc_segments.dart';

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

  void _apply(String key) {
    final v = _presets[key]!;
    setState(() {
      ultraModeNotifier.value = key == 'ultra';
      temperatureNotifier.value = v.$1;
      maxTokensNotifier.value = v.$2;
      contextSizeNotifier.value = v.$3;
    });
    savePref('pc_ultra', key == 'ultra');
    savePref('pc_temperature', v.$1);
    savePref('pc_max_tokens', v.$2);
    savePref('pc_context_size', v.$3);
  }

  String? get _current {
    if (ultraModeNotifier.value) return 'ultra';
    for (final e in _presets.entries) {
      final v = e.value;
      if (e.key != 'ultra' &&
          temperatureNotifier.value == v.$1 &&
          maxTokensNotifier.value == v.$2 &&
          contextSizeNotifier.value == v.$3) {
        return e.key;
      }
    }
    return null;
  }

  Widget _title(TextTheme text, String s) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(s, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );

  Widget _sw(String title, String? sub, ValueNotifier<bool> n, String key, {void Function(bool)? also}) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: sub == null ? null : Text(sub),
        value: n.value,
        onChanged: (v) {
          setState(() => n.value = v);
          savePref(key, v);
          also?.call(v);
        },
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ctxIndex = _ctxs.indexOf(contextSizeNotifier.value).clamp(0, _ctxs.length - 1);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('tools_power'), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          PcSegments<String>(
            height: 68,
            value: _current,
            items: [
              ('eco', tr('power_eco'), Icons.eco_rounded),
              ('balanced', tr('power_balanced'), Icons.balance_rounded),
              ('max', tr('power_max'), Icons.bolt_rounded),
              ('ultra', tr('power_ultra'), Icons.auto_awesome_rounded),
            ],
            onChanged: _apply,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topLeft,
            child: ultraModeNotifier.value
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(tr('ultra_hint'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  )
                : const SizedBox(width: double.infinity),
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
          _title(text, tr('tools_web_max')),
          PcSegments<int>(
            height: 46,
            value: webMaxSourcesNotifier.value,
            items: const [(5, '5', null), (10, '10', null), (20, '20', null), (0, '∞', null)],
            onChanged: (v) {
              setState(() => webMaxSourcesNotifier.value = v);
              savePref('pc_web_max', v);
            },
          ),
          _title(text, tr('opt_reasoning')),
          PcSegments<String>(
            height: 46,
            value: reasoningModeNotifier.value,
            items: [
              ('auto', tr('opt_reason_auto'), null),
              ('on', tr('opt_reason_on'), null),
              ('off', tr('opt_reason_off'), null),
            ],
            onChanged: (v) {
              setState(() => reasoningModeNotifier.value = v);
              savePref('pc_reasoning', v);
            },
          ),
          const SizedBox(height: 4),
          Text(tr('opt_reason_sub'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          _sw(tr('opt_show_steps'), tr('opt_show_steps_sub'), showStepsNotifier, 'pc_show_steps'),
          if (showStepsNotifier.value) _sw(tr('opt_steps_open'), null, stepsOpenNotifier, 'pc_steps_open'),
          _title(text, tr('ctx_auto')),
          _sw(tr('ctx_web_auto'), tr('ctx_web_auto_sub'), webAutoNotifier, 'pc_web_auto'),
          _sw(tr('ctx_location'), null, locationEnabledNotifier, 'pc_location', also: (v) {
            if (v) {
              LocationService.instance.refresh();
            } else {
              LocationService.instance.clear();
            }
          }),
          _sw(tr('ctx_time'), null, contextTimeNotifier, 'pc_ctx_time'),
          _sw(tr('ctx_auto_cmd'), null, autoCommandsNotifier, 'pc_auto_cmd'),
          _sw(tr('tools_auto_speak'), null, autoSpeakNotifier, 'pc_auto_speak'),
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
