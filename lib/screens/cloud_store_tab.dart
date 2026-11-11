// lib/screens/cloud_store_tab.dart
// "Cloud" tab of the models store: everything the connected providers offer for the
// person's API keys. Add a model to its account, or use it for the chats.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../services/cloud/cloud_engine.dart';
import '../services/cloud/cloud_protocol.dart';
import '../services/cloud/cloud_store.dart';
import '../theme/m3_motion.dart';
import '../widgets/m3_components.dart';
import '../widgets/skeleton.dart' show M3Spinner;
import 'settings/cloud_page.dart';

class _Listing {
  List<CloudModelInfo> models = const [];
  String? error;
  bool loading = true;
}

class CloudStoreTab extends StatefulWidget {
  const CloudStoreTab({super.key});

  @override
  State<CloudStoreTab> createState() => _CloudStoreTabState();
}

class _CloudStoreTabState extends State<CloudStoreTab> {
  final Map<String, _Listing> _lists = {};
  int _filter = 0; // 0 all, 1 chat, 2 images, 3 vision, 4 added only
  String? _acc; // account shown (null = all)

  @override
  void initState() {
    super.initState();
    CloudStore.instance.addListener(_changed);
    activeCloudNotifier.addListener(_changed);
    cloudEnabledNotifier.addListener(_changed);
    _loadAll();
  }

  @override
  void dispose() {
    CloudStore.instance.removeListener(_changed);
    activeCloudNotifier.removeListener(_changed);
    cloudEnabledNotifier.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<CloudAccount> get _accounts => [for (final a in CloudStore.instance.accounts) if (a.ready) a];

  void _loadAll() {
    for (final a in _accounts) {
      _load(a);
    }
  }

  Future<void> _load(CloudAccount a) async {
    final l = _lists.putIfAbsent(a.id, _Listing.new);
    setState(() {
      l.loading = true;
      l.error = null;
    });
    try {
      final list = await CloudApi.listModels(a);
      l.models = list;
    } catch (e) {
      l.error = cloudErrorText(e);
    }
    if (mounted) setState(() => l.loading = false);
  }

  bool _keep(CloudAccount a, CloudModelInfo m) => switch (_filter) {
        4 => a.models.any((x) => x.id == m.id),
        1 => !m.imageOnly,
        2 => m.image,
        3 => m.vision,
        _ => true,
      };

  Widget _tag(BuildContext context, String text) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: s.secondaryContainer, borderRadius: BorderRadius.circular(10)),
      child: Text(text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: s.onSecondaryContainer, fontWeight: FontWeight.w700)),
    );
  }

  Widget _tile(BuildContext context, CloudAccount a, CloudModelInfo m) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final added = a.models.any((x) => x.id == m.id);
    final active = activeCloudNotifier.value == CloudModel(a, m).id;
    final ctx = m.contextTokens >= 1000 ? '${(m.contextTokens / 1000).round()}k' : '${m.contextTokens}';
    Widget action;
    if (active) {
      action = Icon(Icons.check_circle_rounded, color: s.primary);
    } else if (added && !m.imageOnly) {
      action = FilledButton.tonal(
        onPressed: () async {
          m3Haptic();
          await CloudStore.instance.select(CloudModel(a, m).id);
        },
        child: Text(tr('cst_use')),
      );
    } else if (added) {
      action = Icon(Icons.done_rounded, color: s.onSurfaceVariant);
    } else {
      action = IconButton.filledTonal(
        tooltip: tr('cst_add'),
        icon: const Icon(Icons.add_rounded),
        onPressed: () async {
          m3Haptic();
          a.models.add(m);
          await CloudStore.instance.update(a);
          if (mounted) setState(() {});
        },
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(color: s.surfaceContainerLow, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (m.name != m.id)
              Text(m.id, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (!m.imageOnly) _tag(context, '$ctx ${tr('cst_tokens')}'),
              if (m.vision) _tag(context, tr('cst_vision')),
              if (m.image) _tag(context, tr('cst_image')),
              if (added) _tag(context, tr('cst_added')),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        action,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final accounts = _accounts;
    if (accounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: s.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(tr('cst_none'), textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
            const SizedBox(height: 16),
            M3LabelButton(
              kind: M3ButtonKind.filled,
              icon: Icons.add_rounded,
              label: tr('cst_add_account'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CloudPage())),
            ),
          ]),
        ),
      );
    }
    final labels = [tr('cst_all'), tr('cst_chat'), tr('cst_images'), tr('cst_vision'), tr('cst_added_only')];
    final shownAccounts = [for (final a in accounts) if (_acc == null || _acc == a.id) a];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      if (!cloudEnabledNotifier.value)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: s.tertiaryContainer, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, color: s.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(child: Text(tr('cst_off_banner'), style: t.bodyMedium?.copyWith(color: s.onTertiaryContainer))),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CloudPage())),
              child: Text(tr('cst_open')),
            ),
          ]),
        ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < labels.length; i++)
          M3Chip(label: Text(labels[i]), selected: _filter == i, onSelected: (_) => setState(() => _filter = i)),
      ]),
      if (accounts.length > 1) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          M3Chip(label: Text(tr('cst_all_accounts')), selected: _acc == null, onSelected: (_) => setState(() => _acc = null)),
          for (final a in accounts)
            M3Chip(label: Text(a.name), selected: _acc == a.id, onSelected: (_) => setState(() => _acc = a.id)),
        ]),
      ],
      const SizedBox(height: 12),
      for (final a in shownAccounts) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
          child: Row(children: [
            cloudProviderLogo(a.provider, size: 20, color: s.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(a.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            IconButton(tooltip: tr('cst_refresh'), icon: const Icon(Icons.refresh_rounded), onPressed: () => _load(a)),
          ]),
        ),
        if (_lists[a.id]?.loading ?? true)
          Padding(padding: const EdgeInsets.all(20), child: Center(child: SizedBox(width: 24, height: 24, child: M3Spinner(color: s.primary))))
        else if (_lists[a.id]?.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_lists[a.id]!.error!, style: t.bodyMedium?.copyWith(color: s.error)),
          )
        else
          for (final m in _lists[a.id]!.models.where((m) => _keep(a, m))) _tile(context, a, m),
      ],
    ]);
  }
}
