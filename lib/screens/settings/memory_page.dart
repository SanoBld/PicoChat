// lib/screens/settings/memory_page.dart
// Personal memory (facts) and the instructions given to the AI.
import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../services/backup.dart';
import '../../services/memory_store.dart';
import '../../services/prefs.dart';
import '../../widgets/m3_components.dart' show M3CookieBadge;
import '../../widgets/pc_motion.dart';
import '../../widgets/import_memory_sheet.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});
  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final _store = MemoryStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_r);
  }

  @override
  void dispose() {
    _store.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  bool get _hasInstr => systemPromptNotifier.value.trim().isNotEmpty && systemPromptNotifier.value != kDefaultSystemPrompt;

  Future<void> _add() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.psychology_rounded),
        title: Text(tr('memory_add')),
        content: TextField(controller: c, autofocus: true, maxLines: 3, minLines: 1),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('save'))),
        ],
      ),
    );
    if (v != null) await _store.add(v);
  }

  Future<void> _editInstr() async {
    final c = TextEditingController(text: _hasInstr ? systemPromptNotifier.value : '');
    final suggestions = [tr('inst_s1'), tr('inst_s2'), tr('inst_s3'), tr('inst_s4'), tr('inst_s5')];
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(tr('ai_style'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr('inst_sub'), style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              TextField(
                controller: c,
                autofocus: true,
                minLines: 5,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: tr('cs_system_prompt_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in suggestions)
                  ActionChip(
                    shape: const StadiumBorder(),
                    label: Text(s),
                    onPressed: () => c.text = c.text.trim().isEmpty ? s : '${c.text.trim()}\n$s',
                  ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                TextButton(onPressed: () => Navigator.pop(ctx, ''), child: Text(tr('inst_reset'))),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(tr('save'))),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (saved == null) return;
    final clean = saved.isEmpty ? kDefaultSystemPrompt : saved;
    setState(() => systemPromptNotifier.value = clean);
    await savePref('pc_system_prompt', clean);
  }

  Future<void> _import() async {
    final r = await Backup.import();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(r == null ? 'import_failed' : 'imported'))));
  }

  Widget _card(ColorScheme s, {required Widget child, Color? color, VoidCallback? onTap}) => Material(
        color: color ?? s.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: child)),
      );

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('memory_title')),
        actions: [
          IconButton(tooltip: tr('im_btn'), icon: const Icon(Icons.auto_awesome_rounded), onPressed: () => showImportMemorySheet(context)),
          IconButton(tooltip: tr('import'), icon: const Icon(Icons.file_upload_outlined), onPressed: _import),
          IconButton(tooltip: tr('export'), icon: const Icon(Icons.file_download_outlined), onPressed: Backup.exportMemory),
          if (_store.items.isNotEmpty)
            IconButton(tooltip: tr('memory_clear'), icon: const Icon(Icons.delete_sweep_rounded), onPressed: _store.clear),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('memory_add')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
            FadeSlideIn(
              child: _card(
                s,
                color: s.primaryContainer,
                child: Row(children: [
                  M3CookieBadge(size: 44, color: s.primary, child: Icon(Icons.psychology_rounded, color: s.onPrimary)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('memory_enable'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: s.onPrimaryContainer)),
                      Text(tr('memory_enable_sub'), style: t.bodySmall?.copyWith(color: s.onPrimaryContainer.withValues(alpha: 0.8))),
                    ]),
                  ),
                  Switch(
                    value: memoryEnabledNotifier.value,
                    onChanged: (v) {
                      setState(() => memoryEnabledNotifier.value = v);
                      savePref('pc_memory', v);
                    },
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _card(
                s,
                onTap: _editInstr,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    M3CookieBadge(size: 40, color: s.secondary, child: Icon(Icons.tune_rounded, size: 20, color: s.onSecondary)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tr('ai_style'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                    Icon(Icons.edit_rounded, size: 20, color: s.onSurfaceVariant),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    _hasInstr ? systemPromptNotifier.value : tr('inst_none'),
                    style: t.bodyMedium?.copyWith(
                      color: _hasInstr ? s.onSurface : s.onSurfaceVariant,
                      fontStyle: _hasInstr ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 22, 8, 10),
              child: Text('${tr('mem_section')} · ${_store.items.length}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: s.primary)),
            ),
            if (_store.items.isEmpty)
              FadeSlideIn(
                delay: const Duration(milliseconds: 160),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(children: [
                    M3CookieBadge(size: 72, color: s.surfaceContainerHighest, child: Icon(Icons.auto_awesome_rounded, size: 32, color: s.primary)),
                    const SizedBox(height: 14),
                    Text(tr('memory_empty'), textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
                  ]),
                ),
              ),
            for (var i = 0; i < _store.items.length; i++)
              FadeSlideIn(
                key: ValueKey(_store.items[i]),
                delay: Duration(milliseconds: 120 + (i.clamp(0, 8)) * 40),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    decoration: ShapeDecoration(color: s.surfaceContainerHigh, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    child: Row(children: [
                      M3CookieBadge(size: 34, color: s.tertiaryContainer, child: Icon(Icons.bookmark_rounded, size: 16, color: s.onTertiaryContainer)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_store.items[i], style: t.bodyLarge)),
                      IconButton(tooltip: tr('delete'), icon: const Icon(Icons.close_rounded), onPressed: () => _store.removeAt(i)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
