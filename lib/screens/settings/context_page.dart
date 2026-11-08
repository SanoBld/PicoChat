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
