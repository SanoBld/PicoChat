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
                onOpen: () => _showFiles(context, featured[i].repo),
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
  final hue = (h % 360).toDouble();
  final dark = scheme.brightness == Brightness.dark;
  return (
    container: HSLColor.fromAHSL(1, hue, dark ? 0.28 : 0.55, dark ? 0.20 : 0.88).toColor(),
    accent: HSLColor.fromAHSL(1, hue, dark ? 0.50 : 0.55, dark ? 0.62 : 0.40).toColor(),
    onAccent: dark ? const Color(0xFF101010) : Colors.white,
  );
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
