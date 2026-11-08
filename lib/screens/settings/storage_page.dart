// lib/screens/settings/storage_page.dart
// What PicoChat stores on the device, and buttons to free the space.

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/model_models.dart';
import '../../services/chat_store.dart';
import '../../services/model_manager.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';
import 'settings_rows.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  int _chats = 0;
  int _models = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final c = await ChatStore.instance.sizeOnDisk();
    final m = await ModelManager.instance.sizeOnDisk();
    if (mounted) {
      setState(() {
        _chats = c;
        _models = m;
      });
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('delete'))),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final mgr = ModelManager.instance;
    return Scaffold(
      appBar: M3AppBar(title: tr('set_storage')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SettingsSection(label: tr('st_usage'), children: [
            SettingTile(
              leading: const Icon(Icons.memory_rounded),
              title: Text(tr('nav_models')),
              subtitle: Text('${mgr.installed.length} · ${formatBytes(_models)}'),
            ),
            SettingTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: Text(tr('st_chats')),
              subtitle: Text('${ChatStore.instance.chats.length} · ${formatBytes(_chats)}'),
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('st_clean'), children: [
            SettingActionRow(
              icon: Icons.cleaning_services_rounded,
              title: tr('st_clear_partials'),
              subtitle: tr('st_clear_partials_sub'),
              onTap: () async {
                await mgr.clearPartials();
                await _refresh();
              },
            ),
            SettingActionRow(
              icon: Icons.delete_sweep_rounded,
              title: tr('st_clear_chats'),
              subtitle: tr('st_clear_chats_sub'),
              danger: true,
              onTap: () async {
                if (await _confirm(tr('st_clear_chats'), tr('st_clear_chats_q'))) {
                  await ChatStore.instance.clearAll();
                  await _refresh();
                }
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
