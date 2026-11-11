// lib/screens/settings/sync_page.dart
// Sync between the person's own devices: group code, devices, what to sync.
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/reset.dart';
import '../../services/sync/sync_prefs.dart';
import '../../services/sync/sync_service.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';
import 'settings_rows.dart';
import 'sync_widgets.dart';

class SyncSettingsPage extends StatelessWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SyncService.instance;
    return Scaffold(
      appBar: M3AppBar(title: tr('sync_title')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            final n = s.connectedCount;
            final on = s.supported && s.configured && n > 0;
            final subtitle = !s.supported
                ? tr('sync_unsupported')
                : n > 0
                    ? tr('sync_status_sub_on')
                    : s.configured
                        ? tr('sync_status_sub_wait')
                        : tr('sync_status_sub_off');
            final title = !s.supported
                ? tr('sync_title')
                : n > 0
                    ? tr('sync_status_on', {'n': '$n'})
                    : s.configured
                        ? tr('sync_status_wait')
                        : tr('sync_status_off');
            return ListView(padding: const EdgeInsets.all(20), children: [
              SettingsStatusCard(
                on: on,
                title: title,
                subtitle: subtitle,
                iconOn: Icons.sync_rounded,
                iconOff: Icons.sync_disabled_rounded,
                pill: on ? '$n' : null,
              ),
              const SizedBox(height: 20),
              if (s.supported) ..._body(context, s),
            ]);
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, SyncService s) {
    final scheme = Theme.of(context).colorScheme;
    if (s.secret.isEmpty) {
      return [
        SettingsSection(label: tr('sync_setup'), children: const [
          Padding(padding: EdgeInsets.all(16), child: SyncPairPanel()),
        ]),
        const SizedBox(height: 12),
        Text(tr('sync_note', {'p': '${SyncService.kPort}'}),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ];
    }
    final devices = s.devices;
    return [
      SettingsSection(label: tr('sync_this'), children: [
        SettingSwitchRow(
          icon: Icons.sync_rounded,
          title: tr('sync_enable'),
          subtitle: tr('sync_enable_sub'),
          value: s.enabled,
          onChanged: (v) => s.setEnabled(v),
        ),
        SettingTextRow(
          icon: Icons.devices_rounded,
          title: tr('sync_name'),
          hint: '',
          value: s.deviceName,
          keyboardType: TextInputType.text,
          onChanged: (v) => s.setName(v),
        ),
      ]),
      const SizedBox(height: 20),
      SettingsSection(label: tr('sync_devices'), children: [
        if (devices.isEmpty)
          SettingTile(
            leading: const Icon(Icons.radar_rounded),
            title: Text(tr('sync_waiting')),
            subtitle: s.lastError == null ? null : Text(tr('sync_error', {'e': s.lastError!})),
          )
        else
          for (final d in devices)
            SettingTile(
              leading: Icon(d.connected ? Icons.check_circle_rounded : Icons.radar_rounded,
                  color: d.connected ? scheme.primary : scheme.onSurfaceVariant),
              title: Text(d.name),
              subtitle: Text(d.connected ? tr('sync_connected') : tr('sync_nearby')),
            ),
      ]),
      const SizedBox(height: 20),
      SettingsSection(label: tr('sync_what'), children: [
        for (final c in kAllCats)
          SettingSwitchRow(
            icon: catInfo(c).$1,
            title: catInfo(c).$2,
            subtitle: catInfo(c).$3,
            value: s.cats.contains(c),
            onChanged: (v) => s.setCategory(c, v),
          ),
        SettingSwitchRow(
          icon: Icons.bolt_rounded,
          title: tr('sync_live'),
          subtitle: tr('sync_live_sub'),
          value: s.live,
          onChanged: (v) => s.setLive(v),
        ),
      ]),
      const SizedBox(height: 20),
      SettingsSection(label: tr('sync_group'), children: [
        const Padding(padding: EdgeInsets.all(12), child: SyncCodeCard()),
        SettingTextRow(
          icon: Icons.lan_rounded,
          title: tr('sync_ip'),
          hint: tr('sync_ip_hint'),
          value: '',
          onChanged: (v) async {
            final ok = await s.connectTo(v);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('sync_ip_fail'))));
            }
          },
        ),
        SettingActionRow(
          icon: Icons.logout_rounded,
          title: tr('sync_leave'),
          subtitle: tr('sync_leave_sub'),
          danger: true,
          onTap: () async {
            if (await ResetService.confirm(context, tr('sync_leave_q'), title: tr('sync_leave'))) {
              await s.leaveGroup();
            }
          },
        ),
      ]),
      const SizedBox(height: 12),
      Text(tr('sync_note', {'p': '${s.port ?? SyncService.kPort}'}),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 16),
    ];
  }
}
