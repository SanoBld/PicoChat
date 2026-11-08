// lib/screens/settings/access_settings_page.dart
// Optional phone access (contacts, messages, notifications, calendar)
// and notification options. Everything is off until the person turns it on.

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../services/device_data.dart';
import '../../services/notif_service.dart';
import '../../services/prefs.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';
import 'settings_rows.dart';

class AccessSettingsPage extends StatefulWidget {
  const AccessSettingsPage({super.key});

  @override
  State<AccessSettingsPage> createState() => _AccessSettingsPageState();
}

class _AccessSettingsPageState extends State<AccessSettingsPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the Android notification-access screen: check what was granted.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) async {
    if (s == AppLifecycleState.resumed && accNotifNotifier.value && !await DeviceData.notifAccess()) {
      accNotifNotifier.value = false;
      await savePref('pc_acc_notif', false);
    }
    if (mounted) setState(() {});
  }

  Widget _row(IconData icon, String key, ValueNotifier<bool> n, String pref, String what) => SettingSwitchRow(
        icon: icon,
        title: tr('acc_$key'),
        subtitle: tr('acc_${key}_sub'),
        value: n.value,
        onChanged: (v) async {
          if (v) {
            final ok = await DeviceData.enable(what);
            if (!ok) {
              if (what == 'notif') n.value = true; // pending until the person comes back from Android settings
              if (what != 'notif' && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('acc_denied'))));
              }
              if (what != 'notif') return;
            }
          }
          n.value = v;
          await savePref(pref, v);
          if (mounted) setState(() {});
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: M3AppBar(title: tr('acc_title')),
        body: M3MaxWidth(
          maxWidth: 720,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            if (!DeviceData.supported)
              Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(tr('acc_android_only'))),
            SettingsSection(label: tr('acc_section'), children: [
              _row(Icons.contacts_rounded, 'contacts', accContactsNotifier, 'pc_acc_contacts', 'contacts'),
              _row(Icons.sms_rounded, 'sms', accSmsNotifier, 'pc_acc_sms', 'sms'),
              _row(Icons.notifications_active_rounded, 'notif', accNotifNotifier, 'pc_acc_notif', 'notif'),
              _row(Icons.event_rounded, 'cal', accCalendarNotifier, 'pc_acc_cal', 'calendar'),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Text(tr('acc_note'), style: Theme.of(context).textTheme.bodySmall),
            ),
          ]),
        ),
      );
}

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  Widget _sw(IconData icon, String key, ValueNotifier<bool> n, String pref) => SettingSwitchRow(
        icon: icon,
        title: tr('n_$key'),
        subtitle: tr('n_${key}_sub'),
        value: n.value,
        onChanged: (v) async {
          if (v) await NotifService.requestPermission();
          n.value = v;
          await savePref(pref, v);
          if (mounted) setState(() {});
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: M3AppBar(title: tr('n_title')),
        body: M3MaxWidth(
          maxWidth: 720,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            if (!NotifService.supported)
              Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(tr('acc_android_only'))),
            SettingsSection(label: tr('n_downloads'), children: [
              _sw(Icons.downloading_rounded, 'background', notifBackgroundNotifier, 'pc_n_bg'),
              _sw(Icons.percent_rounded, 'progress', notifProgressNotifier, 'pc_n_progress'),
              _sw(Icons.check_circle_outline_rounded, 'done', notifDoneNotifier, 'pc_n_done'),
            ]),
          ]),
        ),
      );
}
