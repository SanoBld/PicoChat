// lib/screens/settings/background_page.dart
// What keeps running when PicoChat is not in front. Every item is the person's choice.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../services/background_service.dart';
import '../../services/notif_service.dart';
import '../../services/prefs.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';
import 'settings_rows.dart';

class BackgroundPage extends StatefulWidget {
  const BackgroundPage({super.key});

  @override
  State<BackgroundPage> createState() => _BackgroundPageState();
}

class _BackgroundPageState extends State<BackgroundPage> {
  Widget _sw(IconData icon, String key, ValueNotifier<bool> n, String pref, {bool enabled = true, String? extra}) =>
      SettingSwitchRow(
        icon: icon,
        title: tr('bg_$key'),
        subtitle: extra ?? tr('bg_${key}_sub'),
        value: n.value,
        onChanged: enabled
            ? (v) async {
                if (v && NotifService.supported && key != 'close') await NotifService.requestPermission();
                n.value = v;
                await savePref(pref, v);
                if (mounted) setState(() {});
              }
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mobile = NotifService.supported;
    final desktop = BackgroundService.desktop;
    final any = bgSyncNotifier.value || bgAnswersNotifier.value || (mobile && notifBackgroundNotifier.value) || bgCloseNotifier.value;
    return Scaffold(
      appBar: M3AppBar(title: tr('bg_title')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SettingsStatusCard(
            on: any && !kIsWeb,
            title: any ? tr('bg_on') : tr('bg_off'),
            subtitle: tr('bg_status_sub'),
            iconOn: Icons.layers_rounded,
            iconOff: Icons.layers_clear_rounded,
          ),
          const SizedBox(height: 20),
          SettingsSection(label: tr('bg_what'), children: [
            _sw(Icons.sync_rounded, 'sync', bgSyncNotifier, 'pc_bg_sync', enabled: !kIsWeb),
            _sw(Icons.chat_rounded, 'answers', bgAnswersNotifier, 'pc_bg_answers', enabled: mobile, extra: mobile ? null : tr('bg_mobile_only')),
            _sw(Icons.downloading_rounded, 'downloads', notifBackgroundNotifier, 'pc_n_bg', enabled: mobile, extra: mobile ? null : tr('bg_mobile_only')),
            _sw(Icons.close_fullscreen_rounded, 'close', bgCloseNotifier, 'pc_bg_close', enabled: desktop, extra: desktop ? null : tr('bg_desktop_only')),
          ]),
          const SizedBox(height: 12),
          Text(tr('bg_note'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}
