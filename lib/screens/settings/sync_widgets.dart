// lib/screens/settings/sync_widgets.dart
// Pieces shared by the sync page, the backup page and the first-launch intro.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../services/sync/sync_prefs.dart';
import '../../services/sync/sync_service.dart';
import '../../widgets/m3_components.dart';

/// Icon, title and one-line description of a category.
(IconData, String, String) catInfo(String cat) {
  switch (cat) {
    case kCatChats:
      return (Icons.forum_rounded, tr('cat_chats'), tr('cat_chats_sub'));
    case kCatMemory:
      return (Icons.psychology_rounded, tr('cat_memory'), tr('cat_memory_sub'));
    case kCatAppearance:
      return (Icons.palette_rounded, tr('cat_appearance'), tr('cat_appearance_sub'));
    default:
      return (Icons.tune_rounded, tr('cat_behavior'), tr('cat_behavior_sub'));
  }
}

/// Tick the categories to use. [counts] (optional) shows how many items each one holds;
/// only the categories of [cats] are listed.
class CategoryPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final List<String> cats;
  final Map<String, int>? counts;
  const CategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.cats = kAllCats,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final c in cats)
        CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          controlAffinity: ListTileControlAffinity.trailing,
          secondary: Icon(catInfo(c).$1),
          title: Text(catInfo(c).$2),
          subtitle: Text(counts == null ? catInfo(c).$3 : '${catInfo(c).$3} · ${counts![c] ?? 0}'),
          value: selected.contains(c),
          onChanged: (v) {
            final next = {...selected};
            v == true ? next.add(c) : next.remove(c);
            onChanged(next);
          },
        ),
    ]);
  }
}

/// The group code, big, with a copy button.
class SyncCodeCard extends StatelessWidget {
  const SyncCodeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final code = SyncService.instance.formattedSecret;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('sync_code_t'), style: t.labelLarge?.copyWith(color: s.onPrimaryContainer, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            SelectableText(code,
                style: t.titleLarge?.copyWith(
                    color: s.onPrimaryContainer, fontWeight: FontWeight.w800, fontFamily: 'monospace', letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Text(tr('sync_code_s'), style: t.bodySmall?.copyWith(color: s.onPrimaryContainer.withValues(alpha: 0.8))),
          ]),
        ),
        IconButton(
          tooltip: tr('sync_copy'),
          icon: Icon(Icons.copy_rounded, color: s.onPrimaryContainer),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('sync_copied'))));
            }
          },
        ),
      ]),
    );
  }
}

/// First step of sync: create a group, or join the one made on another device.
/// Once a group exists it shows the code instead.
class SyncPairPanel extends StatefulWidget {
  const SyncPairPanel({super.key});

  @override
  State<SyncPairPanel> createState() => _SyncPairPanelState();
}

class _SyncPairPanelState extends State<SyncPairPanel> {
  final _code = TextEditingController();
  bool _join = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    await SyncService.instance.createGroup();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _doJoin() async {
    setState(() => _busy = true);
    final ok = await SyncService.instance.joinGroup(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : tr('sync_bad_code');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncService.instance,
      builder: (context, _) {
        if (SyncService.instance.secret.isNotEmpty) return const SyncCodeCard();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          M3LabelButton(
              kind: M3ButtonKind.filled, icon: Icons.add_link_rounded, label: tr('sync_create'), loading: _busy, onTap: _busy ? null : _create),
          const SizedBox(height: 10),
          M3LabelButton(
              kind: M3ButtonKind.tonal,
              icon: Icons.login_rounded,
              label: tr('sync_join'),
              onTap: () => setState(() => _join = !_join)),
          if (_join) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.5),
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX-XXXX',
                errorText: _error,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onSubmitted: (_) => _doJoin(),
            ),
            const SizedBox(height: 10),
            M3LabelButton(
                kind: M3ButtonKind.filled, icon: Icons.check_rounded, label: tr('sync_join_go'), loading: _busy, onTap: _busy ? null : _doJoin),
          ],
        ]);
      },
    );
  }
}
