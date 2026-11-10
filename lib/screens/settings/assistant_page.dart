// lib/screens/settings/assistant_page.dart
// Android assistant: which AI answers, how to turn it on, lock screen and circle to search.
import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../services/cloud/cloud_store.dart';
import '../../services/model_manager.dart';
import '../../services/prefs.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';
import 'settings_rows.dart';

class AssistantSettingsPage extends StatefulWidget {
  const AssistantSettingsPage({super.key});

  @override
  State<AssistantSettingsPage> createState() => _AssistantSettingsPageState();
}

class _AssistantSettingsPageState extends State<AssistantSettingsPage> {
  Widget _step(BuildContext context, int n, String text) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: s.primaryContainer, shape: BoxShape.circle),
          child: Text('$n', style: t.labelLarge?.copyWith(color: s.onPrimaryContainer, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: t.bodyMedium)),
      ]),
    );
  }

  Widget _note(BuildContext context, IconData icon, String title, String body) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: s.surfaceContainerHigh, borderRadius: BorderRadius.circular(24)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: s.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(body, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloud = cloudEnabledNotifier.value ? CloudStore.instance.chatModels : <CloudModel>[];
    final current = assistModelNotifier.value;
    final valid = current.isEmpty ||
        ModelManager.instance.byId(current) != null ||
        cloud.any((m) => m.id == current);
    return Scaffold(
      appBar: M3AppBar(title: tr('set_assistant')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SettingsSection(label: tr('cs_assistant'), children: [
            SettingChoiceRow(
              icon: Icons.assistant_rounded,
              title: tr('cs_assist_model'),
              description: tr('cs_assist_model_sub'),
              options: [
                ('', tr('cs_assist_same'), null),
                for (final m in ModelManager.instance.installed) (m.id, m.fileName, Icons.smartphone_rounded),
                for (final m in cloud) (m.id, m.displayName, Icons.cloud_rounded),
              ],
              value: valid ? current : '',
              onChanged: (v) {
                assistModelNotifier.value = v;
                savePref('pc_assist_model', v);
                setState(() {});
              },
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('as_howto'), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(children: [
                _step(context, 1, tr('as_s1')),
                _step(context, 2, tr('as_s2')),
                _step(context, 3, tr('as_s3')),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          _note(context, Icons.gesture_rounded, tr('as_lens_t'), tr('as_lens_s')),
          const SizedBox(height: 12),
          _note(context, Icons.lock_rounded, tr('as_lock_t'), tr('as_lock_s')),
          const SizedBox(height: 12),
          _note(context, Icons.history_rounded, tr('as_hist_t'), tr('as_hist_s')),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
