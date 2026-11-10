// lib/widgets/import_memory_sheet.dart
// Copy a prompt to another AI, paste its answer, and save each line as a memory fact.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../services/memory_store.dart';

Future<void> showImportMemorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _ImportMemorySheet(),
  );
}

class _ImportMemorySheet extends StatefulWidget {
  const _ImportMemorySheet();
  @override
  State<_ImportMemorySheet> createState() => _ImportMemorySheetState();
}

class _ImportMemorySheetState extends State<_ImportMemorySheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // One fact per line; remove bullets and numbers.
  Future<void> _save() async {
    var n = 0;
    for (final raw in _ctrl.text.split('\n')) {
      final f = raw.replaceFirst(RegExp(r'^\s*([-*•]|\d+[.)])\s*'), '').trim();
      if (f.length < 3) continue;
      if (await MemoryStore.instance.add(f)) n++;
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('im_done', {'n': '$n'}))));
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('im_title'), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text('1. ${tr('im_step1')}', style: t.titleSmall),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: s.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('im_prompt'), maxLines: 4, overflow: TextOverflow.ellipsis, style: t.bodySmall),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(tr('im_copy')),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: tr('im_prompt')));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('im_copied'))));
                  },
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('2. ${tr('im_step2')}', style: t.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: tr('im_hint'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
            const SizedBox(width: 8),
            FilledButton(onPressed: _save, child: Text(tr('im_add'))),
          ]),
        ]),
      ),
    );
  }
}
