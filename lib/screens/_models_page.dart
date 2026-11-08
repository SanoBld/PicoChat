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
            tr('tab_discover'),
            tr('tab_installed'),
            activeDownloads > 0 ? '${tr('tab_downloads')} ($activeDownloads)' : tr('tab_downloads'),
          ],
        ),
        Expanded(
          child: kIsWeb
              ? M3EmptyState(icon: Icons.desktop_windows_rounded, message: tr('web_unsupported'))
              : TabBarView(controller: _tabs, children: [
                  const _DiscoverTab(),
                  _InstalledTab(onDiscover: () => _tabs.animateTo(0)),
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
        return FadeSlideIn(
          key: ValueKey(m.id),
          delay: staggerDelay(i),
          child: Padding(
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
          ),
        );
      },
    );
  }
}

// ── Discover (store look) ────────────────────────────────────────────────────

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
  int _cat = 0; // 0 all, 1 light, 2 balanced, 3 powerful

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

  List<RecommendedModel> get _featured => kRecommendedModels.where((r) {
        switch (_cat) {
          case 1:
            return r.approxMb <= 900;
          case 2:
            return r.approxMb > 900 && r.approxMb <= 1500;
          case 3:
            return r.approxMb > 1500;
          default:
            return true;
        }
      }).toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final store = _query.trim().isEmpty;
    final cats = [tr('cat_all'), tr('cat_light'), tr('cat_balanced'), tr('cat_power')];
    final featured = _featured;

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      M3SearchField(hint: tr('hf_search_hint'), onChanged: _onQuery),
      if (store) ...[
        _StoreSection(tr('store_featured')),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (i, label) in cats.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: M3Chip(
                    label: Text(label),
                    selected: _cat == i,
                    onSelected: (_) => setState(() => _cat = i),
                  ),
                ),
            ],
          ),
        ),
        _ForYouCard(onOpen: (r) => _showDetail(context, r)),
        const SizedBox(height: 12),
        SizedBox(
          height: 236,
          child: ListView.separated(
            // A new key per category replays the entrance of the cards.
            key: ValueKey('featured_$_cat'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: featured.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => FadeSlideIn(
              dx: 0.08,
              delay: staggerDelay(i, stepMs: 70),
              child: _FeaturedCard(
                model: featured[i],
                onGet: () => _downloadRecommended(featured[i]),
                onOpen: () => _showDetail(context, featured[i]),
              ),
            ),
          ),
        ),
        _StoreSection(tr('hf_popular')),
      ],
      if (_loading && _results == null)
        WavyLoader(label: tr('searching'))
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
      else ...[
        // Thin wavy bar under the list while a new search is running.
        if (_loading)
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 0, 32, 10),
            child: M3WavyProgress(indeterminate: true, height: 10),
          ),
        for (final (i, r) in _results!.indexed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FadeSlideIn(
              key: ValueKey('row_${r.id}'),
              delay: staggerDelay(i),
              child: _StoreRow(rank: store ? i + 1 : null, model: r, onOpen: () => _showFiles(context, r.id)),
            ),
          ),
      ],
    ]);
  }
}

// Stable colour per repo, so each model keeps its own "icon".
({Color container, Color accent, Color onAccent}) _tintFor(String seed, ColorScheme scheme) {
  var h = 7;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0xFFFFF;
  }
  // Only colours of the chosen app theme.
  switch (h % 3) {
    case 0:
      return (container: scheme.primaryContainer, accent: scheme.primary, onAccent: scheme.onPrimary);
    case 1:
      return (container: scheme.secondaryContainer, accent: scheme.secondary, onAccent: scheme.onSecondary);
    default:
      return (container: scheme.tertiaryContainer, accent: scheme.tertiary, onAccent: scheme.onTertiary);
  }
}

String _initial(String s) => s.isEmpty ? '?' : String.fromCharCode(s.runes.first).toUpperCase();

class _StoreSection extends StatelessWidget {
  final String title;
  const _StoreSection(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );
}

/// GET / progress / installed, like the button of an app store.
class _StoreAction extends StatelessWidget {
  final String repo;
  final VoidCallback onGet;
  const _StoreAction({required this.repo, required this.onGet});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: ModelManager.instance,
      builder: (_, _) {
        final mgr = ModelManager.instance;
        if (mgr.installed.any((m) => m.repo == repo)) {
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary),
            const SizedBox(width: 6),
            Text(tr('store_installed'), style: text.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
          ]);
        }
        final running = mgr.tasks.where((t) => t.repo == repo && t.status != DownloadStatus.failed).toList();
        if (running.isNotEmpty) {
          final t = running.first;
          return SizedBox(
            width: 92,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              t.total > 0
                  ? M3WavyProgress(value: t.fraction, height: 12)
                  : const M3WavyProgress(indeterminate: true, height: 12),
              const SizedBox(height: 4),
              Text(t.total > 0 ? '${(t.fraction * 100).round()} %' : '…',
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          );
        }
        return M3LabelButton(
          kind: M3ButtonKind.tonal,
          height: 38,
          icon: Icons.download_rounded,
          label: tr('store_get'),
          onTap: onGet,
        );
      },
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final RecommendedModel model;
  final VoidCallback onGet;
  final VoidCallback onOpen;
  const _FeaturedCard({required this.model, required this.onGet, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tint = _tintFor(model.repo, scheme);
    return SizedBox(
      width: 264,
      child: M3PressCard(
        color: tint.container,
        onTap: onOpen,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            M3CookieBadge(
              size: 52,
              color: tint.accent,
              child: Text(_initial(model.title),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tint.onAccent)),
            ),
            const Spacer(),
            if (model.vision) ...[
              Icon(Icons.visibility_rounded, size: 18, color: tint.accent),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tint.accent.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(model.params, style: text.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 14),
          Text(model.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: Text(tr(model.blurbKey), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text('~${formatBytes(model.approxMb * 1024 * 1024)}',
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            _StoreAction(repo: model.repo, onGet: onGet),
          ]),
        ]),
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  final int? rank;
  final HfModelSummary model;
  final VoidCallback onOpen;
  const _StoreRow({required this.rank, required this.model, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tint = _tintFor(model.id, scheme);
    final small = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return M3PressCard(
      color: scheme.surfaceContainerLow,
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(children: [
        if (rank != null)
          SizedBox(
            width: 24,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
          ),
        if (rank != null) const SizedBox(width: 8),
        M3CookieBadge(
          size: 44,
          color: tint.accent,
          child: Text(_initial(model.name),
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: tint.onAccent)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text('${model.author}${model.gated ? ' · ${tr('gated')}' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.download_rounded, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 3),
              Text(_compact(model.downloads), style: small),
              const SizedBox(width: 10),
              Icon(Icons.favorite_rounded, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 3),
              Text(_compact(model.likes), style: small),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        _StoreAction(repo: model.id, onGet: onOpen),
      ]),
    );
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
  late final Future<List<HfFileInfo>> _proj =
      HfService.listProjectors(widget.repo).catchError((_) => <HfFileInfo>[]);
  bool _vision = false; // also download the vision projector

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
      FutureBuilder<List<HfFileInfo>>(
        future: _proj,
        builder: (_, snap) {
          final pick = HfService.pickProjector(snap.data ?? []);
          if (pick == null) return const SizedBox.shrink();
          return SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(tr('detail_vision_opt')),
            subtitle: Text('+${formatBytes(pick.size)}'),
            value: _vision,
            onChanged: (v) => setState(() => _vision = v),
          );
        },
      ),
      Expanded(
        child: FutureBuilder<List<HfFileInfo>>(
          future: _files,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const WavyLoader();
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
                  return FadeSlideIn(
                    key: ValueKey(f.path),
                    delay: staggerDelay(i),
                    child: ListTile(
                    title: Text(f.quant.isEmpty ? f.path : f.quant, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${formatBytes(f.size)}${identical(f, best) ? ' · ${tr('recommended')}' : ''}\n${f.path}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    trailing: installed
                        ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                        : busy
                            ? const SizedBox(width: 56, child: M3WavyProgress(indeterminate: true, height: 10))
                            : IconButton.filledTonal(
                                icon: const Icon(Icons.download_rounded),
                                onPressed: () {
                                  mgr.download(widget.repo, f.path, size: f.size);
                                  if (_vision) mgr.downloadProjector(widget.repo).catchError((_) {});
                                  _toast(context, tr('download_started'));
                                },
                              ),
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
              t.total > 0
                  ? M3WavyProgress(value: t.fraction, height: 14)
                  : const M3WavyProgress(indeterminate: true, height: 14),
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

// ── Store: model details + suggestion for this device ───────────────────────

Future<void> _installRecommended(BuildContext context, RecommendedModel r, bool vision) async {
  try {
    await ModelManager.instance.downloadRecommended(r.repo);
    if (vision) await ModelManager.instance.downloadProjector(r.repo);
    if (context.mounted) _toast(context, tr('download_started'));
  } on HfException catch (e) {
    if (context.mounted) _toast(context, _errorText(e.kind));
  }
}

void _showDetail(BuildContext context, RecommendedModel r) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DetailSheet(model: r, parent: context),
  );
}

class _DetailSheet extends StatefulWidget {
  final RecommendedModel model;
  final BuildContext parent; // used to open the files sheet after closing this one
  const _DetailSheet({required this.model, required this.parent});

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  bool _vision = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = widget.model;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(tr(r.blurbKey), style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(label: Text(r.params)),
            for (final t in r.tags) Chip(label: Text(tr(t))),
          ]),
          const SizedBox(height: 12),
          Text(tr('detail_needs', {'gb': '${r.minRamGb}', 'size': formatBytes(r.approxMb * 1024 * 1024)}),
              style: text.bodyMedium),
          FutureBuilder<double?>(
            future: DeviceSpecs.ramGb(),
            builder: (_, snap) {
              final ram = snap.data;
              if (ram == null) return const SizedBox.shrink();
              final fits = ram >= r.minRamGb;
              final tight = !fits && ram >= r.minRamGb * 0.7;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr(fits ? 'store_fits' : (tight ? 'store_tight' : 'store_toobig')),
                  style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: fits ? scheme.primary : (tight ? scheme.tertiary : scheme.error)),
                ),
              );
            },
          ),
          if (r.vision)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('detail_vision_opt')),
              value: _vision,
              onChanged: (v) => setState(() => _vision = v),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: M3LabelButton(
                kind: M3ButtonKind.tonal,
                icon: Icons.tune_rounded,
                label: tr('detail_choose_quant'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.parent.mounted) _showFiles(widget.parent, r.repo);
                },
              ),
            ),
            const SizedBox(width: 12),
            _StoreAction(repo: r.repo, onGet: () => _installRecommended(context, r, _vision)),
          ]),
        ]),
      ),
    );
  }
}

/// "Recommended for your device": the biggest suggested model that fits the RAM.
class _ForYouCard extends StatelessWidget {
  final void Function(RecommendedModel) onOpen;
  const _ForYouCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return FutureBuilder<double?>(
      future: DeviceSpecs.ramGb(),
      builder: (_, snap) {
        final ram = snap.data;
        final r = ram == null ? null : DeviceSpecs.bestFor(ram);
        if (ram == null || r == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: M3PressCard(
            color: scheme.primaryContainer,
            onTap: () => onOpen(r),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded, color: scheme.onPrimaryContainer),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('store_for_you'), style: text.labelMedium?.copyWith(color: scheme.onPrimaryContainer)),
                  Text(r.title,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
                  Text(tr('store_ram', {'gb': ram.toStringAsFixed(0)}),
                      style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onPrimaryContainer),
            ]),
          ),
        );
      },
    );
  }
}
