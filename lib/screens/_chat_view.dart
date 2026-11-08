// lib/screens/_chat_view.dart
// The conversation: message list, empty state with suggestions, composer.
part of 'home_screen.dart';

class _ChatView extends StatefulWidget {
  final Conversation chat;
  final VoidCallback? onMenu; // null on wide layouts (sidebar is always visible)
  final VoidCallback onNewChat;
  final VoidCallback onOpenModels;

  const _ChatView({
    super.key,
    required this.chat,
    required this.onMenu,
    required this.onNewChat,
    required this.onOpenModels,
  });

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    ChatStore.instance.addListener(_onChange);
    ChatService.instance.addListener(_onChange);
    ModelManager.instance.addListener(_onChange);
    localeNotifier.addListener(_onChange);
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    ChatStore.instance.removeListener(_onChange);
    ChatService.instance.removeListener(_onChange);
    ModelManager.instance.removeListener(_onChange);
    localeNotifier.removeListener(_onChange);
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (ChatService.instance.isGeneratingIn(widget.chat)) _scrollToEnd();
  }

  void _scrollToEnd({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final p = _scroll.position;
      if (force || p.maxScrollExtent - p.pixels < 200) {
        _scroll.jumpTo(p.maxScrollExtent);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    if (!ChatService.instance.canChat) {
      widget.onOpenModels();
      return;
    }
    if (ChatService.instance.isGenerating) return;
    m3Haptic();
    _ctrl.clear();
    final f = ChatService.instance.send(widget.chat, text);
    _scrollToEnd(force: true);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final service = ChatService.instance;
    final active = ModelManager.instance.active;
    final busy = service.isGeneratingIn(widget.chat);
    final messages = widget.chat.messages;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onMenu == null
            ? null
            : IconButton(icon: const Icon(Icons.menu_rounded), onPressed: widget.onMenu),
        automaticallyImplyLeading: false,
        titleSpacing: widget.onMenu == null ? 20 : 0,
        title: Text(
          widget.chat.title.isEmpty ? 'PicoChat' : widget.chat.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton.icon(
            onPressed: widget.onOpenModels,
            icon: const Icon(Icons.memory_rounded, size: 18),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(active?.displayName ?? tr('select_model'), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          if (widget.onMenu != null)
            IconButton(icon: const Icon(Icons.edit_square), tooltip: tr('new_chat'), onPressed: widget.onNewChat),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        if (service.canChat && InferenceService.engine.isPlaceholder)
          Container(
            width: double.infinity,
            color: scheme.tertiaryContainer.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: scheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('demo_banner'), style: text.bodySmall?.copyWith(color: scheme.onTertiaryContainer))),
            ]),
          ),
        Expanded(
          child: messages.isEmpty
              ? _EmptyChat(onSuggest: _send, onOpenModels: widget.onOpenModels)
              : SelectionArea(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      final isLast = i == messages.length - 1;
                      return M3MaxWidth(
                        maxWidth: 820,
                        child: _MessageView(
                          message: m,
                          showActions: isLast && !busy && m.role == ChatRole.assistant && m.text.isNotEmpty,
                          waiting: busy && isLast && m.role == ChatRole.assistant && m.text.isEmpty,
                          loadingModel: service.isLoadingModel,
                          onRegenerate: () => service.regenerate(widget.chat),
                        ),
                      );
                    },
                  ),
                ),
        ),
        _composer(scheme, text, busy),
      ]),
    );
  }

  Widget _composer(ColorScheme scheme, TextTheme text, bool busy) {
    final canChat = ChatService.instance.canChat;
    final canSend = _hasText && canChat && !ChatService.instance.isGenerating;
    return SafeArea(
      top: false,
      child: M3MaxWidth(
        maxWidth: 820,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Focus(
                  onKeyEvent: (node, e) {
                    final isEnter = e.logicalKey == LogicalKeyboardKey.enter;
                    if (isEnter &&
                        _isDesktopPlatform &&
                        sendOnEnterNotifier.value &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      if (e is KeyDownEvent) _send();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    enabled: canChat,
                    minLines: 1,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: canChat ? tr('chat_hint') : tr('no_model_hint'),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (busy)
                IconButton.filled(
                  tooltip: tr('stop'),
                  icon: const Icon(Icons.stop_rounded),
                  onPressed: ChatService.instance.requestStop,
                )
              else
                IconButton.filled(
                  tooltip: tr('send'),
                  icon: const Icon(Icons.arrow_upward_rounded),
                  onPressed: canSend ? _send : null,
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final ValueChanged<String> onSuggest;
  final VoidCallback onOpenModels;
  const _EmptyChat({required this.onSuggest, required this.onOpenModels});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canChat = ChatService.instance.canChat;
    final name = displayNameNotifier.value.trim();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            M3CookieBadge(
              size: 88,
              color: scheme.primary,
              child: BrandIcon('assets/icons/app_logo.svg', Icons.chat_bubble_rounded, size: 44, color: scheme.onPrimary),
            ),
            const SizedBox(height: 20),
            Text(
              canChat
                  ? (name.isEmpty ? tr('empty_title') : tr('empty_title_name', {'name': name}))
                  : tr('no_model_title'),
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              canChat ? tr('empty_sub') : tr('no_model_sub'),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (!canChat)
              M3LabelButton(
                kind: M3ButtonKind.filled,
                icon: Icons.download_rounded,
                label: tr('get_model'),
                onTap: onOpenModels,
              )
            else
              Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                for (final k in const ['suggest_1', 'suggest_2', 'suggest_3', 'suggest_4'])
                  ActionChip(label: Text(tr(k)), onPressed: () => onSuggest(tr(k))),
              ]),
          ]),
        ),
      ),
    );
  }
}

// ── One message ──────────────────────────────────────────────────────────────

class _MessageView extends StatelessWidget {
  final ChatMessage message;
  final bool showActions;
  final bool waiting;
  final bool loadingModel;
  final VoidCallback onRegenerate;

  const _MessageView({
    required this.message,
    required this.showActions,
    required this.waiting,
    required this.loadingModel,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (message.role == ChatRole.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 56, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(message.text, style: text.bodyLarge?.copyWith(color: scheme.onPrimaryContainer)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        M3CookieBadge(
          size: 34,
          color: scheme.primary,
          child: BrandIcon('assets/icons/app_logo.svg', Icons.chat_bubble_rounded, size: 18, color: scheme.onPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (waiting)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const M3LoadingIndicator(size: 24),
                  const SizedBox(width: 10),
                  Text(loadingModel ? tr('loading_model') : tr('thinking'),
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ]),
              )
            else if (message.text.isNotEmpty)
              MarkdownLite(text: message.text, style: text.bodyLarge, linkColor: scheme.primary),
            if (message.stopped)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(tr('stopped'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            if (message.failed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(tr('gen_failed'), style: text.bodySmall?.copyWith(color: scheme.error)),
              ),
            if (showActions)
              Row(children: [
                IconButton(
                  tooltip: tr('copy'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    _toast(context, tr('copied'));
                  },
                ),
                IconButton(
                  tooltip: tr('regenerate'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: onRegenerate,
                ),
              ]),
          ]),
        ),
      ]),
    );
  }
}
