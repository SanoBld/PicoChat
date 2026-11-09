// lib/screens/settings/cloud_page.dart
// Optional cloud AI: on/off switch, accounts (Claude, Gemini, ChatGPT,
// OpenAI-compatible), and which context is sent along with the messages.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../services/cloud/cloud_engine.dart';
import '../../services/cloud/cloud_protocol.dart';
import '../../services/cloud/cloud_store.dart';
import '../../services/prefs.dart';
import '../../theme/m3_motion.dart';
import '../../theme/m3_shapes.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';
import 'settings_rows.dart';

IconData cloudProviderIcon(CloudProvider p) => switch (p) {
      CloudProvider.anthropic => Icons.auto_awesome_rounded,
      CloudProvider.gemini => Icons.stars_rounded,
      CloudProvider.openai => Icons.bubble_chart_rounded,
      CloudProvider.custom => Icons.dns_rounded,
    };

void _toast(BuildContext context, String msg) => showAppSnackBar(context, SnackBar(content: Text(msg)));

String _tokens(int n) => n >= 1000000 ? '${(n / 1000000).toStringAsFixed(1)}M' : '${(n / 1000).round()}K';

// ── Main page ────────────────────────────────────────────────────────────────

class CloudPage extends StatefulWidget {
  const CloudPage({super.key});

  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  @override
  void initState() {
    super.initState();
    CloudStore.instance.addListener(_rebuild);
    localeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    CloudStore.instance.removeListener(_rebuild);
    localeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.cloud_upload_rounded),
          title: Text(tr('cloud_enable_q')),
          content: Text(tr('cloud_enable_body')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('cloud_enable_yes'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    cloudEnabledNotifier.value = on;
    await savePref('pc_cloud_enabled', on);
    if (mounted) setState(() {});
  }

  Future<void> _addAccount() async {
    final p = await showModalBottomSheet<CloudProvider>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(tr('cloud_add_pick'), style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final p in CloudProvider.values)
            ListTile(
              leading: Icon(cloudProviderIcon(p)),
              title: Text(p.label),
              subtitle: p == CloudProvider.custom ? Text(tr('cloud_custom_sub')) : null,
              onTap: () => Navigator.pop(ctx, p),
            ),
        ]),
      ),
    );
    if (p == null) return;
    final acc = CloudAccount(provider: p);
    await CloudStore.instance.add(acc);
    if (!mounted) return;
    Navigator.of(context).push(M3SharedAxisRoute<void>(builder: (_) => CloudAccountPage(account: acc)));
  }

  Widget _ctxSwitch(IconData icon, String key, ValueNotifier<bool> n, String pref) => SettingSwitchRow(
        icon: icon,
        title: tr('cloud_ctx_$key'),
        subtitle: tr('cloud_ctx_${key}_sub'),
        value: n.value,
        onChanged: (v) {
          n.value = v;
          savePref(pref, v);
          setState(() {});
        },
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final on = cloudEnabledNotifier.value;
    final accounts = CloudStore.instance.accounts;

    return Scaffold(
      appBar: M3AppBar(title: tr('cloud_title')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(24)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('cloud_info'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
            ]),
          ),
          const SizedBox(height: 20),
          SettingsSection(label: tr('cloud_title'), children: [
            SettingSwitchRow(
              icon: Icons.cloud_rounded,
              title: tr('cloud_enable'),
              subtitle: tr('cloud_enable_sub'),
              value: on,
              onChanged: _toggle,
            ),
          ]),
          if (on) ...[
            const SizedBox(height: 20),
            SettingsSection(label: tr('cloud_accounts'), children: [
              for (final a in accounts)
                SettingActionRow(
                  icon: cloudProviderIcon(a.provider),
                  title: a.name,
                  subtitle: [
                    a.provider.shortName,
                    tr('cloud_models_count', {'n': '${a.models.length}'}),
                    if (!a.ready) tr('cloud_key_missing_short'),
                  ].join(' · '),
                  onTap: () => Navigator.of(context).push(M3SharedAxisRoute<void>(builder: (_) => CloudAccountPage(account: a))),
                ),
              SettingActionRow(icon: Icons.add_rounded, title: tr('cloud_add'), onTap: _addAccount),
            ]),
            if (accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(tr('cloud_no_accounts'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(tr('cloud_ctx_info'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            SettingsSection(label: tr('cloud_ctx'), children: [
              _ctxSwitch(Icons.psychology_rounded, 'memory', cloudCtxMemoryNotifier, 'pc_cloud_ctx_memory'),
              _ctxSwitch(Icons.schedule_rounded, 'time', cloudCtxTimeNotifier, 'pc_cloud_ctx_time'),
              _ctxSwitch(Icons.place_rounded, 'location', cloudCtxLocationNotifier, 'pc_cloud_ctx_location'),
              _ctxSwitch(Icons.attach_file_rounded, 'files', cloudCtxFilesNotifier, 'pc_cloud_ctx_files'),
              _ctxSwitch(Icons.public_rounded, 'web', cloudCtxWebNotifier, 'pc_cloud_ctx_web'),
              _ctxSwitch(Icons.phone_android_rounded, 'device', cloudCtxDeviceNotifier, 'pc_cloud_ctx_device'),
              SettingChoiceRow(
                icon: Icons.history_rounded,
                title: tr('cloud_history'),
                description: tr('cloud_history_sub'),
                options: [
                  for (final n in const [10, 20, 40, 80]) ('$n', '$n', null),
                  ('0', tr('cloud_hist_all'), null),
                ],
                value: '${cloudHistoryNotifier.value}',
                onChanged: (v) {
                  cloudHistoryNotifier.value = int.parse(v);
                  savePref('pc_cloud_history', int.parse(v));
                  setState(() {});
                },
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ── One account ──────────────────────────────────────────────────────────────

class CloudAccountPage extends StatefulWidget {
  final CloudAccount account;
  const CloudAccountPage({super.key, required this.account});

  @override
  State<CloudAccountPage> createState() => _CloudAccountPageState();
}

class _CloudAccountPageState extends State<CloudAccountPage> {
  bool _busy = false;
  CloudAccount get _a => widget.account;

  @override
  void initState() {
    super.initState();
    CloudStore.instance.addListener(_rebuild);
    localeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    CloudStore.instance.removeListener(_rebuild);
    localeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _save() => CloudStore.instance.update(_a);

  Future<void> _fetch() async {
    if (_a.provider.keyRequired && _a.apiKey.trim().isEmpty) {
      _toast(context, tr('cloud_key_missing'));
      return;
    }
    if (_a.effectiveBaseUrl.isEmpty) {
      _toast(context, tr('cloud_url_missing'));
      return;
    }
    setState(() => _busy = true);
    List<CloudModelInfo> list = const [];
    String? error;
    try {
      list = await CloudApi.listModels(_a);
    } catch (e) {
      error = cloudErrorText(e);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _toast(context, error);
      return;
    }
    if (list.isEmpty) {
      _toast(context, tr('cloud_fetch_none'));
      return;
    }
    final picked = await showModalBottomSheet<List<CloudModelInfo>>(
      sheetAnimationStyle: kM3SheetAnimation,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModelPickSheet(models: list, added: {for (final m in _a.models) m.id}),
    );
    if (picked == null || picked.isEmpty) return;
    _a.models.addAll(picked.where((p) => !_a.models.any((m) => m.id == p.id)));
    await _save();
    if (mounted) _toast(context, tr('cloud_added', {'n': '${picked.length}'}));
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('cloud_remove_q')),
        content: Text(tr('cloud_remove_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    await CloudStore.instance.remove(_a);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _use(CloudModelInfo m) async {
    if (!_a.ready) {
      _toast(context, tr(_a.effectiveBaseUrl.isEmpty ? 'cloud_url_missing' : 'cloud_key_missing'));
      return;
    }
    m3Haptic();
    await CloudStore.instance.select(CloudModel(_a, m).id);
    if (mounted) _toast(context, tr('cloud_now_using', {'name': m.name}));
  }

  Widget _modelTile(CloudModelInfo m, bool active, ColorScheme scheme) => SettingTile(
        leading: Icon(active ? Icons.check_rounded : cloudProviderIcon(_a.provider)),
        title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([if (m.name != m.id) m.id, _tokens(m.contextTokens), if (active) tr('in_use')].join(' · '),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: tr('cloud_vision'),
            icon: Icon(m.vision ? Icons.image_rounded : Icons.hide_image_outlined,
                color: m.vision ? scheme.primary : scheme.onSurfaceVariant),
            onPressed: () async {
              _a.models[_a.models.indexWhere((x) => x.id == m.id)] = m.copyWith(vision: !m.vision);
              await _save();
            },
          ),
          IconButton(
            tooltip: tr('delete'),
            icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
            onPressed: () async {
              _a.models.removeWhere((x) => x.id == m.id);
              await _save();
            },
          ),
        ]),
        onTap: () => _use(m),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final key = _a.apiKey;
    final activeId = activeCloudNotifier.value;

    return Scaffold(
      appBar: M3AppBar(title: _a.name, subtitle: _a.provider.label),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SettingsSection(label: tr('cloud_accounts'), children: [
            SettingTextRow(
              icon: Icons.badge_rounded,
              title: tr('cloud_acc_name'),
              hint: _a.provider.shortName,
              keyboardType: TextInputType.text,
              value: _a.name,
              onChanged: (v) {
                _a.name = v.trim().isEmpty ? _a.provider.shortName : v.trim();
                _save();
              },
            ),
            SettingTextRow(
              icon: Icons.key_rounded,
              title: tr('cloud_acc_key'),
              hint: _a.provider.keyRequired ? 'sk-…' : '—',
              value: key.isEmpty ? '' : '••••••••${key.length > 4 ? key.substring(key.length - 4) : ''}',
              onChanged: (v) {
                if (v.contains('•')) return; // untouched masked value
                _a.apiKey = v.trim();
                _save();
              },
            ),
            if (_a.provider.keyUrl.isNotEmpty)
              SettingActionRow(
                icon: Icons.open_in_new_rounded,
                title: tr('cloud_acc_get_key'),
                onTap: () => launchUrl(Uri.parse(_a.provider.keyUrl), mode: LaunchMode.externalApplication),
              ),
            SettingTextRow(
              icon: Icons.dns_rounded,
              title: tr('cloud_acc_url'),
              hint: _a.provider.defaultBaseUrl.isEmpty ? 'http://localhost:11434/v1' : _a.provider.defaultBaseUrl,
              value: _a.baseUrl,
              onChanged: (v) {
                _a.baseUrl = v.trim();
                _save();
              },
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(tr('cloud_key_note'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 20),
          SettingsSection(label: tr('cloud_acc_models'), children: [
            for (final m in _a.models) _modelTile(m, activeId == CloudModel(_a, m).id, scheme),
            SettingActionRow(
              icon: Icons.cloud_sync_rounded,
              title: tr('cloud_fetch'),
              subtitle: _busy ? tr('cloud_fetching') : tr('cloud_fetch_sub'),
              trailing: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              onTap: _busy ? null : _fetch,
            ),
            SettingTextRow(
              icon: Icons.add_rounded,
              title: tr('cloud_add_manual'),
              hint: tr('cloud_model_id'),
              keyboardType: TextInputType.text,
              value: '',
              onChanged: (v) async {
                final id = v.trim();
                if (id.isEmpty || _a.models.any((m) => m.id == id)) return;
                _a.models.add(CloudModelInfo(id: id));
                await _save();
              },
            ),
          ]),
          if (_a.models.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(tr('cloud_no_models'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 20),
          SettingsSection(label: tr('set_danger'), children: [
            SettingActionRow(icon: Icons.delete_forever_rounded, title: tr('cloud_remove'), danger: true, onTap: _remove),
          ]),
        ]),
      ),
    );
  }
}

// ── Model picker ─────────────────────────────────────────────────────────────

class _ModelPickSheet extends StatefulWidget {
  final List<CloudModelInfo> models;
  final Set<String> added;
  const _ModelPickSheet({required this.models, required this.added});

  @override
  State<_ModelPickSheet> createState() => _ModelPickSheetState();
}

class _ModelPickSheetState extends State<_ModelPickSheet> {
  final Set<String> _sel = {};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = widget.models
        .where((m) => _q.isEmpty || m.id.toLowerCase().contains(_q) || m.name.toLowerCase().contains(_q))
        .toList();
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(children: [
            Expanded(child: Text(tr('cloud_pick_title'), style: Theme.of(context).textTheme.titleLarge)),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: TextField(
            autocorrect: false,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: tr('cloud_pick_filter'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
            ),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final m = shown[i];
              final already = widget.added.contains(m.id);
              return CheckboxListTile(
                value: already || _sel.contains(m.id),
                onChanged: already
                    ? null
                    : (v) => setState(() {
                          if (v == true) {
                            _sel.add(m.id);
                          } else {
                            _sel.remove(m.id);
                          }
                        }),
                title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text([if (m.name != m.id) m.id, _tokens(m.contextTokens), if (m.vision) '👁'].join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: M3LabelButton(
              kind: M3ButtonKind.filled,
              expand: true,
              icon: Icons.add_rounded,
              label: '${tr('cloud_pick_add')} (${_sel.length})',
              onTap: _sel.isEmpty ? null : () => Navigator.pop(context, widget.models.where((m) => _sel.contains(m.id)).toList()),
            ),
          ),
        ),
      ]),
    );
  }
}
