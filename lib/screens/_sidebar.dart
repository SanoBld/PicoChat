// lib/screens/_sidebar.dart
// Chat history list with search, plus links to Models and Settings.
part of 'home_screen.dart';

class _Sidebar extends StatefulWidget {
  final String selectedId;
  final ValueChanged<Conversation> onSelect;
  final VoidCallback onNew;
  final ValueChanged<Conversation> onDeleted;
  final VoidCallback onOpenModels;
  final VoidCallback onOpenSettings;

  const _Sidebar({
    required this.selectedId,
    required this.onSelect,
    required this.onNew,
    required this.onDeleted,
    required this.onOpenModels,
    required this.onOpenSettings,
  });

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    ChatStore.instance.addListener(_rebuild);
    localeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    ChatStore.instance.removeListener(_rebuild);
    localeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _rename(Conversation c) async {
    final ctrl = TextEditingController(text: c.title);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('rename')),
        content: TextField(controller: ctrl, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(L.commonSave)),
        ],
      ),
    );
    if (r != null && r.trim().isNotEmpty) ChatStore.instance.rename(c, r);
  }

  Future<void> _delete(Conversation c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_chat_q')),
        content: Text(tr('delete_chat_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok == true) {
      ChatStore.instance.delete(c);
      widget.onDeleted(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final chats = ChatStore.instance.search(_query);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
        child: Row(children: [
          M3CookieBadge(
            size: 40,
            color: scheme.primary,
            child: BrandIcon('assets/icons/app_logo.svg', Icons.sentiment_satisfied_rounded, size: 22, color: scheme.onPrimary),
          ),
          const SizedBox(width: 12),
          Text('PicoChat', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: M3LabelButton(
          kind: M3ButtonKind.filled,
          icon: Icons.add_rounded,
          label: tr('new_chat'),
          expand: true,
          height: 48,
          onTap: widget.onNew,
        ),
      ),
      M3SearchField(hint: tr('search_chats'), onChanged: (v) => setState(() => _query = v)),
      Expanded(
        child: chats.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _query.isEmpty ? tr('no_chats') : tr('no_results'),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: chats.length,
                itemBuilder: (_, i) {
                  final c = chats[i];
                  final selected = c.id == widget.selectedId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: selected ? scheme.secondaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: M3InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => widget.onSelect(c),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 4),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                c.title.isEmpty ? tr('new_chat') : c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_horiz_rounded, size: 20, color: scheme.onSurfaceVariant),
                              onSelected: (v) async {
                                if (v == 'rename') {
                                  _rename(c);
                                } else if (v == 'delete') {
                                  _delete(c);
                                } else if (v == 'export') {
                                  Backup.exportChat(c);
                                } else if (v == 'import') {
                                  final r = await Backup.import();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(r == null ? 'import_failed' : 'imported'))));
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'rename', child: Text(tr('rename'))),
                                PopupMenuItem(value: 'export', child: Text(tr('export'))),
                                PopupMenuItem(value: 'import', child: Text(tr('import'))),
                                PopupMenuItem(value: 'delete', child: Text(tr('delete'))),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        child: Column(children: [
          _SidebarLink(icon: Icons.memory_rounded, label: tr('nav_models'), onTap: widget.onOpenModels),
          _SidebarLink(icon: Icons.settings_rounded, label: tr('nav_settings'), onTap: widget.onOpenSettings),
        ]),
      ),
    ]);
  }
}

class _SidebarLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SidebarLink({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: M3InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 22, color: scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
