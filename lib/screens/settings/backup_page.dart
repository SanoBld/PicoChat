// lib/screens/settings/backup_page.dart
// Custom backup: pick what goes in the file (chats, memory, appearance, behaviour),
// and pick what to restore from a file.
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/backup.dart';
import '../../services/sync/sync_data.dart';
import '../../services/sync/sync_prefs.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';
import 'sync_widgets.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  Set<String> _sel = {...kAllCats};
  bool _busy = false;

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _export() async {
    if (_sel.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await Backup.exportSelected(_sel);
    if (mounted) setState(() => _busy = false);
    if (ok) _snack(tr('bk_done'));
  }

  Future<void> _import() async {
    if (_busy) return;
    final data = await Backup.pickBackup();
    if (data == null) {
      _snack(tr('bk_invalid'));
      return;
    }
    final counts = SyncData.peek(data);
    if (counts.isEmpty) {
      _snack(tr('bk_invalid'));
      return;
    }
    if (!mounted) return;
    final present = [for (final c in kAllCats) if (counts.containsKey(c)) c];
    var pick = {...present};
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          icon: const Icon(Icons.settings_backup_restore_rounded),
          title: Text(tr('bk_pick')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: CategoryPicker(selected: pick, cats: present, counts: counts, onChanged: (v) => setD(() => pick = v)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L.commonCancel)),
            FilledButton(onPressed: pick.isEmpty ? null : () => Navigator.pop(ctx, true), child: Text(tr('bk_restore'))),
          ],
        ),
      ),
    );
    if (go != true) return;
    setState(() => _busy = true);
    await Backup.restoreSelected(data, pick);
    if (mounted) setState(() => _busy = false);
    _snack(tr('bk_restored'));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: M3AppBar(title: tr('bk_title')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SettingsSection(label: tr('bk_export'), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: CategoryPicker(selected: _sel, onChanged: (v) => setState(() => _sel = v)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: M3LabelButton(
                kind: M3ButtonKind.filled,
                expand: true,
                icon: Icons.file_download_rounded,
                label: tr('bk_make'),
                loading: _busy,
                onTap: _sel.isEmpty || _busy ? null : _export,
              ),
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('bk_import'), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(tr('bk_import_note'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                M3LabelButton(
                    kind: M3ButtonKind.tonal, expand: true, icon: Icons.file_upload_rounded, label: tr('bk_choose'), onTap: _busy ? null : _import),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text(tr('bk_note'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
