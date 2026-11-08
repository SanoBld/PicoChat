// lib/screens/_models_page.dart
// Models: installed list, discover (suggestions + Hugging Face search),
// and the download queue.
part of 'home_screen.dart';

class _ModelsPage extends StatefulWidget {
  const _ModelsPage();

  @override
  State<_ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<_ModelsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    ModelManager.instance.addListener(_rebuild);
    localeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    ModelManager.instance.removeListener(_rebuild);
    localeNotifier.removeListener(_rebuild);
    _tabs.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _import() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = r?.files.single.path;
    if (path == null || !mounted) return;
    final m = await ModelManager.instance.importFile(path);
    if (!mounted) return;
    _toast(context, m == null ? tr('import_bad') : tr('import_ok'));
  }

  @override
  Widget build(BuildContext context) {
    final mgr = ModelManager.instance;
    final activeDownloads = mgr.tasks.where((t) => t.isActive).length;
    return Scaffold(
      appBar: M3AppBar(
        title: tr('nav_models'),
        subtitle: tr('models_sub'),
        actions: [
          if (!kIsWeb)
            IconButton.filledTonal(
              tooltip: tr('import_gguf'),
              icon: const Icon(Icons.folder_open_rounded),
              onPressed: _import,
            ),
        ],
      ),
      body: Column(children: [
        M3TabSwitch(
          controller: _tabs,
          labels: [
            tr('tab_installed'),
            tr('tab_discover'),
            activeDownloads > 0 ? '${tr('tab_downloads')} ($activeDownloads)' : tr('tab_downloads'),
          ],
        ),
        Expanded(
          child: kIsWeb
              ? M3EmptyState(icon: Icons.desktop_windows_rounded, message: tr('web_unsupported'))
              : TabBarView(controller: _tabs, children: [
                  _InstalledTab(onDiscover: () => _tabs.animateTo(1)),
                  const _DiscoverTab(),
                  const _DownloadsTab(),
                ]),
        ),
      ]),
    );
  }
}

// ── Installed ────────────────────────────────────────────────────────────────

class _InstalledTab extends StatelessWidget {
  final VoidCallback onDiscover;
  const _InstalledTab({required this.onDiscover});

  Future<void> _delete(BuildContext context, InstalledModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_model_q')),
        content: Text(tr('delete_model_body', {'name': m.displayName, 'size': formatBytes(m.sizeBytes)})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok == true) await ModelManager.instance.delete(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mgr = ModelManager.instance;
    final list = mgr.installed;
    if (list.isEmpty) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        M3EmptyState(icon: Icons.memory_rounded, message: tr('no_installed')),
        const SizedBox(height: 16),
        M3LabelButton(kind: M3ButtonKind.filled, icon: Icons.explore_rounded, label: tr('tab_discover'), onTap: onDiscover),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final m = list[i];
        final isActive = m.id == activeModelNotifier.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: M3PressCard(
            color: isActive ? scheme.primaryContainer : scheme.surfaceContainerLow,
            onTap: () {
              m3Haptic();
              mgr.setActive(m.id);
            },
            child: Row(children: [
              M3CookieBadge(
                size: 44,
                color: isActive ? scheme.primary : scheme.secondaryContainer,
                child: Icon(isActive ? Icons.check_rounded : Icons.memory_rounded,
                    color: isActive ? scheme.onPrimary : scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    [if (m.quant.isNotEmpty) m.quant, formatBytes(m.sizeBytes), if (isActive) tr('in_use')].join(' · '),
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ]),
              ),
              IconButton(
                tooltip: tr('delete'),
                icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
                onPressed: () => _delete(context, m),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Discover ─────────────────────────────────────────────────────────────────

class _DiscoverTab extends StatefulWidget {
  const _DiscoverTab();

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab> with AutomaticKeepAliveClientMixin {
  Timer? _debounce;
  String _query = '';
  List<HfModelSummary>? _results;
  String? _error;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String v) {
    _query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(v));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await HfService.search(q);
      if (!mounted || q != _query) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } on HfException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.kind;
        _loading = false;
      });
    }
  }

  Future<void> _downloadRecommended(RecommendedModel r) async {
    try {
      await ModelManager.instance.downloadRecommended(r.repo);
      if (mounted) _toast(context, tr('download_started'));
    } on HfException catch (e) {
      if (mounted) _toast(context, _errorText(e.kind));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mgr = ModelManager.instance;
    final showRecommended = _query.trim().isEmpty;

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      M3SearchField(hint: tr('hf_search_hint'), onChanged: _onQuery),
      if (showRecommended) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(tr('rec_title'),
              style: text.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
        ),
        for (final r in kRecommendedModels)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Builder(builder: (_) {
              final installed = mgr.installed.any((m) => m.repo == r.repo);
              final downloading = mgr.tasks.any((t) => t.repo == r.repo);
              return M3PressCard(
                color: scheme.surfaceContainerLow,
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r.title}  ·  ${r.params}',
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${tr(r.blurbKey)} · ~${formatBytes(r.approxMb * 1024 * 1024)}',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  if (installed)
                    Icon(Icons.check_circle_rounded, color: scheme.primary)
                  else if (downloading)
                    const SizedBox(width: 24, height: 24, child: M3Spinner())
                  else
                    IconButton.filledTonal(
                      tooltip: tr('download'),
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => _downloadRecommended(r),
                    ),
                ]),
              );
            }),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(tr('hf_popular'),
              style: text.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
        ),
      ],
      if (_loading && _results == null)
        const Padding(padding: EdgeInsets.all(32), child: Center(child: M3LoadingIndicator(size: 40)))
      else if (_error != null)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Text(_errorText(_error), textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: scheme.error)),
            const SizedBox(height: 12),
            M3LabelButton(kind: M3ButtonKind.tonal, icon: Icons.refresh_rounded, label: L.commonRetry, onTap: () => _search(_query)),
          ]),
        )
      else if ((_results ?? []).isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(tr('no_results'), style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
        )
      else
        for (final r in _results!)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: M3PressCard(
              color: scheme.surfaceContainerLow,
              onTap: () => _showFiles(context, r.id),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${r.author} · ↓ ${_compact(r.downloads)} · ♥ ${_compact(r.likes)}${r.gated ? ' · ${tr('gated')}' : ''}',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
    ]);
  }
}

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

/// Bottom sheet listing the .gguf files of a repo, one Download button each.
void _showFiles(BuildContext context, String repo) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scroll) => _FilesSheet(repo: repo, controller: scroll),
    ),
  );
}

class _FilesSheet extends StatefulWidget {
  final String repo;
  final ScrollController controller;
  const _FilesSheet({required this.repo, required this.controller});

  @override
  State<_FilesSheet> createState() => _FilesSheetState();
}

class _FilesSheetState extends State<_FilesSheet> {
  late final Future<List<HfFileInfo>> _files = HfService.listGgufFiles(widget.repo);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mgr = ModelManager.instance;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
        child: Row(children: [
          Expanded(child: Text(widget.repo, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          IconButton(
            tooltip: tr('open_hf'),
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => launchUrl(Uri.parse(HfService.pageUrl(widget.repo)), mode: LaunchMode.externalApplication),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(tr('files_hint'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ),
      Expanded(
        child: FutureBuilder<List<HfFileInfo>>(
          future: _files,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: M3LoadingIndicator(size: 40));
            }
            if (snap.hasError) {
              final e = snap.error;
              return Center(child: Text(_errorText(e is HfException ? e.kind : 'server'), style: TextStyle(color: scheme.error)));
            }
            final files = snap.data ?? [];
            if (files.isEmpty) return Center(child: Text(tr('no_gguf')));
            final best = HfService.pickDefault(files);
            return ListenableBuilder(
              listenable: mgr,
              builder: (_, _) => ListView.builder(
                controller: widget.controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: files.length,
                itemBuilder: (_, i) {
                  final f = files[i];
                  final id = '${widget.repo}/${f.path}';
                  final installed = mgr.isInstalled(id);
                  final busy = mgr.tasks.any((t) => t.id == id);
                  return ListTile(
                    title: Text(f.quant.isEmpty ? f.path : f.quant, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${formatBytes(f.size)}${identical(f, best) ? ' · ${tr('recommended')}' : ''}\n${f.path}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    trailing: installed
                        ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                        : busy
                            ? const SizedBox(width: 24, height: 24, child: M3Spinner())
                            : IconButton.filledTonal(
                                icon: const Icon(Icons.download_rounded),
                                onPressed: () {
                                  mgr.download(widget.repo, f.path, size: f.size);
                                  _toast(context, tr('download_started'));
                                },
                              ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Downloads ────────────────────────────────────────────────────────────────

class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mgr = ModelManager.instance;
    final tasks = mgr.tasks;
    if (tasks.isEmpty) return M3EmptyState(icon: Icons.download_done_rounded, message: tr('no_downloads'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final t = tasks[i];
        final failed = t.status == DownloadStatus.failed;
        final paused = t.status == DownloadStatus.paused;
        final info = <String>[
          if (t.quant.isNotEmpty) t.quant,
          '${formatBytes(t.received)}${t.total > 0 ? ' / ${formatBytes(t.total)}' : ''}',
          if (t.status == DownloadStatus.downloading && t.speedBps > 0) '${formatBytes(t.speedBps.round())}/s',
          if (paused) tr('paused'),
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: M3PressCard(
            color: scheme.surfaceContainerLow,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(t.repo.split('/').last.replaceAll(RegExp(r'[-_ ]?GGUF$', caseSensitive: false), ''),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (failed || paused)
                  IconButton(
                    tooltip: tr('resume'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () => mgr.resume(t.id),
                  )
                else
                  IconButton(
                    tooltip: tr('pause'),
                    icon: const Icon(Icons.pause_rounded),
                    onPressed: () => mgr.pause(t.id),
                  ),
                IconButton(
                  tooltip: tr('cancel'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => mgr.cancel(t.id),
                ),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: t.total > 0 ? t.fraction : null,
                  minHeight: 5,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                failed ? _errorText(t.errorKind) : info.join(' · '),
                style: text.bodySmall?.copyWith(color: failed ? scheme.error : scheme.onSurfaceVariant),
              ),
            ]),
          ),
        );
      },
    );
  }
}
