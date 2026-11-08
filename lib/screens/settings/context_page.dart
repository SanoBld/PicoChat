// lib/screens/settings/context_page.dart
// Web search mode and what the AI may know about your device.
import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../services/location_service.dart';
import '../../services/prefs.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';
import 'settings_rows.dart';

class ContextPage extends StatefulWidget {
  const ContextPage({super.key});
  @override
  State<ContextPage> createState() => _ContextPageState();
}

class _ContextPageState extends State<ContextPage> {
  final _loc = LocationService.instance;

  @override
  void initState() {
    super.initState();
    _loc.addListener(_r);
  }

  @override
  void dispose() {
    _loc.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final on = locationEnabledNotifier.value;
    return Scaffold(
      appBar: M3AppBar(title: tr('set_context')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SettingsSection(label: tr('ctx_web'), children: [
            SettingChoiceRow(
              icon: Icons.search_rounded,
              title: tr('engine_title'),
              description: tr('engine_sub'),
              options: const [
                ('duckduckgo', 'DuckDuckGo', null),
                ('bing', 'Bing', null),
                ('google', 'Google', null),
                ('mojeek', 'Mojeek', null),
              ],
              value: searchEngineNotifier.value,
              onChanged: (v) {
                searchEngineNotifier.value = v;
                savePref('pc_search_engine', v);
                setState(() {});
              },
            ),
            SettingSwitchRow(
              icon: Icons.travel_explore_rounded,
              title: tr('ctx_web_auto'),
              subtitle: tr('ctx_web_auto_sub'),
              value: webAutoNotifier.value,
              onChanged: (v) {
                webAutoNotifier.value = v;
                savePref('pc_web_auto', v);
                setState(() {});
              },
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('voice_section'), children: [
            SettingSwitchRow(
              icon: Icons.graphic_eq_rounded,
              title: tr('voice_engine'),
              subtitle: tr('voice_engine_sub'),
              value: voiceEngineNotifier.value == 'whisper',
              onChanged: (v) {
                voiceEngineNotifier.value = v ? 'whisper' : 'system';
                savePref('pc_voice_engine', voiceEngineNotifier.value);
                setState(() {});
              },
            ),
            if (voiceEngineNotifier.value == 'whisper')
              SettingChoiceRow(
                icon: Icons.mic_rounded,
                title: tr('voice_model'),
                description: tr('voice_model_sub'),
                options: const [('tiny', 'Tiny', null), ('base', 'Base', null), ('small', 'Small', null)],
                value: voiceModelNotifier.value,
                onChanged: (v) {
                  voiceModelNotifier.value = v;
                  savePref('pc_voice_model', v);
                  setState(() {});
                },
              ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('ctx_auto'), children: [
            SettingSwitchRow(
              icon: Icons.bolt_rounded,
              title: tr('ctx_auto_cmd'),
              subtitle: tr('ctx_auto_cmd_sub'),
              value: autoCommandsNotifier.value,
              onChanged: (v) {
                autoCommandsNotifier.value = v;
                savePref('pc_auto_cmd', v);
                setState(() {});
              },
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('ctx_device'), children: [
            SettingSwitchRow(
              icon: Icons.location_on_rounded,
              title: tr('ctx_location'),
              subtitle: tr('ctx_location_sub'),
              value: on,
              onChanged: (v) {
                locationEnabledNotifier.value = v;
                savePref('pc_location', v);
                if (v) {
                  _loc.refresh();
                } else {
                  _loc.clear();
                }
                setState(() {});
              },
            ),
            if (on)
              SettingTextRow(
                icon: Icons.edit_location_alt_rounded,
                title: tr('ctx_city'),
                keyboardType: TextInputType.text,
                hint: tr('ctx_city_hint'),
                value: cityManualNotifier.value,
                onChanged: (v) {
                  cityManualNotifier.value = v.trim();
                  savePref('pc_city', v.trim());
                  _loc.refresh();
                  setState(() {});
                },
              ),
            if (on)
              SettingActionRow(
                icon: Icons.my_location_rounded,
                title: _loc.busy
                    ? '…'
                    : (_loc.label == null ? tr('ctx_location_none') : tr('ctx_location_now', {'place': _loc.label!})),
                subtitle: tr('ctx_refresh'),
                onTap: _loc.refresh,
              ),
            SettingSwitchRow(
              icon: Icons.schedule_rounded,
              title: tr('ctx_time'),
              subtitle: tr('ctx_time_sub'),
              value: contextTimeNotifier.value,
              onChanged: (v) {
                contextTimeNotifier.value = v;
                savePref('pc_ctx_time', v);
                setState(() {});
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
