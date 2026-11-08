// lib/screens/settings/storage_page.dart
// What PicoChat stores on the device: total, models, chats, memory,
// the biggest items, and buttons to free space.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/chat_models.dart';
import '../../models/model_models.dart';
import '../../services/chat_store.dart';
import '../../services/memory_store.dart';
import '../../services/model_manager.dart';
import '../../widgets/m3_components.dart';
import '../../widgets/pc_motion.dart';
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
  int _memory = 0;
  Map<String, int> _chatSizes = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final c = await ChatStore.instance.sizeOnDisk();
    final m = await ModelManager.instance.sizeOnDisk();
    final sizes = {for (final x in ChatStore.instance.chats) x.id: utf8.encode(jsonEncode(x.toJson())).length};
    final mem = utf8.encode(MemoryStore.instance.items.join('\n')).length;
    if (mounted) {
      setState(() {
        _chats = c;
        _models = m;
        _memory = mem;
        _chatSizes = sizes;
      });
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
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

  Widget _legend(ColorScheme s, TextTheme t, Color c, String label, int bytes) => Padding(
        padding: const EdgeInsets.only(right: 16, top: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label · ${formatBytes(bytes)}', style: t.labelMedium?.copyWith(color: s.onPrimaryContainer)),
        ]),
      );

  Widget _bar(ColorScheme s, double fraction, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction.clamp(0.02, 1.0)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: color, backgroundColor: s.surfaceContainerHighest),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final mgr = ModelManager.instance;
    final models = [...mgr.installed]..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    final maxModel = models.isEmpty ? 1 : models.first.sizeBytes;
    final chats = [...ChatStore.instance.chats]..sort((a, b) => (_chatSizes[b.id] ?? 0).compareTo(_chatSizes[a.id] ?? 0));
    final topChats = chats.take(8).toList();
    final maxChat = topChats.isEmpty ? 1 : (_chatSizes[topChats.first.id] ?? 1).clamp(1, 1 << 40);
    final total = _models + _chats + _memory;
    final cModels = s.primary, cChats = s.tertiary, cMem = s.secondary;

    return Scaffold(
      appBar: M3AppBar(title: tr('set_storage')),
      body: M3MaxWidth(
        maxWidth: 760,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          // ── Total ──────────────────────────────────────────────────────
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: ShapeDecoration(color: s.primaryContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  M3CookieBadge(size: 44, color: s.primary, child: Icon(Icons.storage_rounded, color: s.onPrimary)),
                  const SizedBox(width: 12),
                  Text(tr('st_total'), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: s.onPrimaryContainer)),
                ]),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: total.toDouble()),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(formatBytes(v.round()),
                      style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: s.onPrimaryContainer)),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 16,
                    child: total == 0
                        ? ColoredBox(color: s.surface.withValues(alpha: 0.5))
                        : Row(children: [
                            if (_models > 0) Expanded(flex: _models, child: ColoredBox(color: cModels)),
                            if (_chats > 0) Expanded(flex: _chats, child: ColoredBox(color: cChats)),
                            if (_memory > 0) Expanded(flex: _memory, child: ColoredBox(color: cMem)),
                          ]),
                  ),
                ),
                Wrap(children: [
                  _legend(s, t, cModels, tr('nav_models'), _models),
                  _legend(s, t, cChats, tr('st_chats'), _chats),
                  _legend(s, t, cMem, tr('st_memory'), _memory),
                ]),
              ]),
            ),
          ),
          // ── Models ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 24, 8, 10),
            child: Text('${tr('st_models_list')} · ${models.length}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: s.primary)),
          ),
          for (final (i, m) in models.indexed)
            FadeSlideIn(
              delay: Duration(milliseconds: 60 * i.clamp(0, 8)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  decoration: ShapeDecoration(color: s.surfaceContainerHigh, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                  child: Row(children: [
                    M3CookieBadge(size: 40, color: s.primaryContainer, child: Icon(Icons.memory_rounded, size: 20, color: s.onPrimaryContainer)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(m.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                          Text(formatBytes(m.sizeBytes), style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: s.primary)),
                        ]),
                        const SizedBox(height: 2),
                        Text(m.quant.isEmpty ? m.fileName : '${m.quant} · ${m.fileName}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        _bar(s, m.sizeBytes / maxModel, cModels),
                      ]),
                    ),
                    IconButton(
                      tooltip: tr('delete'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        if (await _confirm(m.displayName, tr('st_delete_model_q'))) {
                          await mgr.delete(m.id);
                          await _refresh();
                        }
                      },
                    ),
                  ]),
                ),
              ),
            ),
          // ── Chats ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 10),
            child: Text('${tr('st_top_chats')} · ${chats.length}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: s.primary)),
          ),
          for (final (i, Conversation c) in topChats.indexed)
            FadeSlideIn(
              delay: Duration(milliseconds: 60 * i.clamp(0, 8)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  decoration: ShapeDecoration(color: s.surfaceContainerHigh, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                  child: Row(children: [
                    M3CookieBadge(size: 40, color: s.tertiaryContainer, child: Icon(Icons.chat_bubble_rounded, size: 18, color: s.onTertiaryContainer)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(c.title.isEmpty ? 'PicoChat' : c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                          Text(formatBytes(_chatSizes[c.id] ?? 0), style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: s.tertiary)),
                        ]),
                        const SizedBox(height: 2),
                        Text('${c.messages.length}', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        _bar(s, (_chatSizes[c.id] ?? 0) / maxChat, cChats),
                      ]),
                    ),
                    IconButton(
                      tooltip: tr('delete'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        if (await _confirm(c.title.isEmpty ? 'PicoChat' : c.title, tr('delete_chat_body'))) {
                          ChatStore.instance.delete(c);
                          await _refresh();
                        }
                      },
                    ),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 12),
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
