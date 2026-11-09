// lib/screens/_chat_view.dart
// The conversation: message list, empty state with suggestions, composer.
part of 'home_screen.dart';

class _ChatView extends StatefulWidget {
  final Conversation chat;
  final VoidCallback? onMenu; // null on wide layouts (sidebar is always visible)
  final VoidCallback onNewChat;
  final VoidCallback onOpenModels;
  final VoidCallback? onToggleSidebar; // wide layouts only

  const _ChatView({
    super.key,
    required this.chat,
    required this.onMenu,
    required this.onNewChat,
    required this.onOpenModels,
    this.onToggleSidebar,
  });

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _hasText = false;
  List<Attachment> _files = [];
  bool _stick = true; // the list follows the end (user did not scroll up)
  final ValueNotifier<bool> _showJump = ValueNotifier(false); // arrow "back to the live answer"
  bool _jumping = false; // jump animation running: the follow timer waits
  Timer? _follow; // while writing: keeps the end in view as the text grows smoothly

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(() {
      if (_focus.hasFocus) _followEnd();
    });
    ChatStore.instance.addListener(_onChange);
    ChatService.instance.addListener(_onChange);
    ModelManager.instance.addListener(_onChange);
    localeNotifier.addListener(_onChange);
    webSearchNotifier.addListener(_onChange);
    locationEnabledNotifier.addListener(_onChange);
    LocationService.instance.addListener(_onChange);
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _follow?.cancel();
    _showJump.dispose();
    ChatStore.instance.removeListener(_onChange);
    ChatService.instance.removeListener(_onChange);
    ModelManager.instance.removeListener(_onChange);
    localeNotifier.removeListener(_onChange);
    webSearchNotifier.removeListener(_onChange);
    locationEnabledNotifier.removeListener(_onChange);
    LocationService.instance.removeListener(_onChange);
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    final gen = ChatService.instance.isGeneratingIn(widget.chat);
    if (gen) {
      _scrollToEnd();
      _follow ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!mounted || !_scroll.hasClients || !_stick || _jumping) return;
        final p = _scroll.position;
        if (p.maxScrollExtent - p.pixels > 0.5) _scroll.jumpTo(p.maxScrollExtent);
      });
    } else {
      _follow?.cancel();
      _follow = null;
    }
  }

  // Arrow in the middle: back to the end (the answer being written) with a smooth scroll.
  Future<void> _jumpToEnd() async {
    if (!_scroll.hasClients) return;
    _stick = true;
    _jumping = true;
    try {
      await _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } finally {
      _jumping = false;
    }
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  Widget _jumpButton(ColorScheme scheme) => Positioned(
        left: 0,
        right: 0,
        bottom: 10,
        child: ValueListenableBuilder<bool>(
          valueListenable: _showJump,
          builder: (_, show, _) => IgnorePointer(
            ignoring: !show,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: show ? Offset.zero : const Offset(0, 0.8),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: show ? 1 : 0,
                child: Center(
                  child: Material(
                    color: scheme.secondaryContainer,
                    elevation: 3,
                    shadowColor: Colors.black54,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: _jumpToEnd,
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Icon(Icons.arrow_downward_rounded, size: 22, color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  // Keyboard opens/closes: the viewport changes size, stay on the prompt.
  @override
  void didChangeMetrics() => _followEnd();

  void _followEnd() {
    if (!_stick) return;
    // Two passes: once now, once after the keyboard animation has moved the layout.
    for (final ms in const [0, 120, 320]) {
      Future<void>.delayed(Duration(milliseconds: ms), () {
        if (!mounted || !_scroll.hasClients) return;
        final p = _scroll.position;
        if ((p.maxScrollExtent - p.pixels).abs() > 1) {
          _scroll.animateTo(p.maxScrollExtent, duration: const Duration(milliseconds: 160), curve: Curves.easeOutCubic);
        }
      });
    }
  }

  void _scrollToEnd({bool force = false}) {
    if (force) _stick = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final p = _scroll.position;
      if (force || _stick) {
        _scroll.jumpTo(p.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMic() async {
    await VoiceInput.instance.stop();
    if (mounted) await _send();
  }

  Widget _dictationPanel(ColorScheme scheme, TextTheme text) {
    final v = VoiceInput.instance;
    return FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ValueListenableBuilder<bool>(
            valueListenable: v.loading,
            builder: (_, _, _) => ValueListenableBuilder<String>(
            valueListenable: v.transcript,
            builder: (_, t, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                t.isEmpty ? tr(v.loading.value ? 'voice_loading' : 'voice_listening') : t,
                key: ValueKey(t.isEmpty),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, fontStyle: t.isEmpty ? FontStyle.italic : FontStyle.normal),
              ),
            ),
          )),
          const SizedBox(height: 14),
          ValueListenableBuilder<List<double>>(
            valueListenable: v.levels,
            builder: (_, l, _) => SizedBox(
              height: 36,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                for (final x in l)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    width: 4,
                    height: 4 + x * 30,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: ShapeDecoration(color: scheme.primary.withValues(alpha: 0.4 + x * 0.6), shape: const StadiumBorder()),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            IconButton.filledTonal(tooltip: tr('cancel'), icon: const Icon(Icons.close_rounded), onPressed: v.cancel),
            const Spacer(),
            IconButton.filledTonal(tooltip: tr('voice_validate'), icon: const Icon(Icons.check_rounded), onPressed: v.stop),
            const SizedBox(width: 8),
            IconButton.filled(tooltip: tr('send'), icon: const Icon(Icons.arrow_upward_rounded), onPressed: _sendMic),
          ]),
        ]),
      ),
    );
  }

  Future<void> _toggleMic() async {
    final v = VoiceInput.instance;
    if (v.listening.value) return v.stop();
    final ok = await v.start(_ctrl);
    if (!ok && mounted) _toast(context, tr('voice_unavailable'));
  }

  Future<void> _attach() async {
    final picked = await Attachments.pick();
    if (picked.isNotEmpty && mounted) setState(() => _files = [..._files, ...picked]);
  }

  void _addFiles(Iterable<Attachment> list) {
    final l = list.toList();
    if (l.isNotEmpty && mounted) setState(() => _files = [..._files, ...l]);
  }

  Future<void> _onDrop(DropDoneDetails d) async {
    final out = <Attachment>[];
    for (final f in d.files) {
      final a = Attachments.fromBytes(f.name, await f.readAsBytes());
      if (a != null) out.add(a);
    }
    _addFiles(out);
    if (out.length < d.files.length && mounted) _toast(context, tr('file_unsupported'));
  }

  // Ctrl/Cmd+V with files in the clipboard: attach them instead of pasting text.
  Future<bool> _pasteFiles() async {
    if (kIsWeb) return false;
    try {
      final paths = await Pasteboard.files();
      if (paths.isEmpty) return false;
      final out = <Attachment>[];
      for (final p in paths) {
        final bytes = await File(p).readAsBytes();
        final a = Attachments.fromBytes(p.split(RegExp(r'[\\/]')).last, Uint8List.fromList(bytes));
        if (a != null) out.add(a);
      }
      _addFiles(out);
      return out.isNotEmpty;
    } catch (_) {
      return false;
    }
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
    final files = _files;
    setState(() => _files = []);
    final f = ChatService.instance.send(widget.chat, text, files: files, web: webSearchNotifier.value || (webAutoNotifier.value && WebIntent.needsWeb(text)));
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
        leading: widget.onMenu != null
            ? IconButton(icon: const Icon(Icons.menu_rounded), onPressed: widget.onMenu)
            : widget.onToggleSidebar != null
                ? IconButton(
                    tooltip: tr(sidebarCollapsedNotifier.value ? 'sidebar_show' : 'sidebar_hide'),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(sidebarCollapsedNotifier.value ? Icons.menu_rounded : Icons.menu_open_rounded,
                          key: ValueKey(sidebarCollapsedNotifier.value)),
                    ),
                    onPressed: widget.onToggleSidebar,
                  )
                : null,
        automaticallyImplyLeading: false,
        titleSpacing: (widget.onMenu == null && widget.onToggleSidebar == null) ? 20 : 0,
        title: Text(
          widget.chat.title.isEmpty ? 'PicoChat' : widget.chat.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          // Small menu: installed models + "See more" (opens the store).
          PopupMenuButton<String>(
            tooltip: tr('select_model'),
            onSelected: (id) {
              if (id == '__more') {
                widget.onOpenModels();
              } else {
                ModelManager.instance.setActive(id);
              }
            },
            itemBuilder: (_) => [
              for (final m in ModelManager.instance.installed.take(6))
                CheckedPopupMenuItem<String>(
                  value: m.id,
                  checked: m.id == active?.id,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(m.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              if (ModelManager.instance.installed.isNotEmpty) const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: '__more',
                child: Row(children: [
                  const Icon(Icons.storefront_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(tr('see_more')),
                ]),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.memory_rounded, size: 18),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(active?.displayName ?? tr('select_model'), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down_rounded, size: 20),
              ]),
            ),
          ),
          if (widget.onMenu != null)
            IconButton(icon: const Icon(Icons.edit_square), tooltip: tr('new_chat'), onPressed: widget.onNewChat),
          const SizedBox(width: 4),
        ],
      ),
      body: DropTarget(
        onDragDone: _onDrop,
        child: Column(children: [
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
              : Stack(children: [
                SelectionArea(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollUpdateNotification) {
                        final gap = n.metrics.maxScrollExtent - n.metrics.pixels;
                        // Scrolling up (by the user) releases the list; reaching the end follows again.
                        if ((n.scrollDelta ?? 0) < 0) {
                          _stick = false;
                        } else if (gap < 40) {
                          _stick = true;
                        }
                        _showJump.value = gap > 160;
                      }
                      return false;
                    },
                    child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      final isLast = i == messages.length - 1;
                      // Only messages written just now slide in; old ones
                      // scrolled back into view stay still.
                      final fresh = DateTime.now().difference(m.createdAt).inMilliseconds < 2500;
                      return M3MaxWidth(
                        maxWidth: _contentW(context),
                        child: FadeSlideIn(
                          key: ValueKey(m.id),
                          skip: !fresh,
                          child: _MessageView(
                            message: m,
                            showActions: isLast && !busy && m.role == ChatRole.assistant && m.text.isNotEmpty,
                            waiting: busy && isLast && m.role == ChatRole.assistant && m.text.isEmpty,
                            generating: busy && isLast && m.role == ChatRole.assistant,
                            loadingModel: service.isLoadingModel,
                            onRegenerate: () => service.regenerate(widget.chat),
                          ),
                        ),
                      );
                    },
                  )),
                ),
                _jumpButton(scheme),
              ]),
        ),
        _composer(scheme, text, busy),
      ])),
    );
  }

  Widget _composer(ColorScheme scheme, TextTheme text, bool busy) {
    final canChat = ChatService.instance.canChat;
    final canSend = _hasText && canChat && !ChatService.instance.isGenerating;
    return SafeArea(
      top: false,
      child: M3MaxWidth(
        maxWidth: _contentW(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: VoiceInput.instance.listening,
              builder: (_, dictating, _) => Column(mainAxisSize: MainAxisSize.min, children: [
                if (dictating) _dictationPanel(scheme, text),
                Offstage(
                  offstage: dictating,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: (locationEnabledNotifier.value && LocationService.instance.label != null)
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: FadeSlideIn(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 6),
                            child: Material(
                              color: scheme.secondaryContainer,
                              shape: const StadiumBorder(),
                              child: InkWell(
                                customBorder: const StadiumBorder(),
                                onTap: LocationService.instance.refresh,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(5, 4, 12, 4),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    M3CookieBadge(size: 22, color: scheme.secondary, child: Icon(Icons.location_on_rounded, size: 12, color: scheme.onSecondary)),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 240),
                                        child: Text(LocationService.instance.label!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer)),
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              if (_files.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 6, children: [
                    for (final f in _files)
                      InputChip(
                        avatar: Icon(f.isImage ? Icons.image_rounded : Icons.attach_file_rounded, size: 16),
                        label: Text(f.name),
                        onDeleted: () => setState(() => _files = [..._files]..remove(f)),
                      ),
                  ]),
                ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Focus(
                  onKeyEvent: (node, e) {
                    if (e is KeyDownEvent &&
                        e.logicalKey == LogicalKeyboardKey.keyV &&
                        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
                      _pasteFiles().then((ok) {
                        if (!ok) {
                          Clipboard.getData(Clipboard.kTextPlain).then((t) {
                            final v = t?.text;
                            if (v == null || v.isEmpty) return;
                            final s = _ctrl.selection;
                            final at = s.isValid ? s.start : _ctrl.text.length;
                            final to = s.isValid ? s.end : _ctrl.text.length;
                            _ctrl.value = TextEditingValue(
                              text: _ctrl.text.replaceRange(at, to, v),
                              selection: TextSelection.collapsed(offset: at + v.length),
                            );
                          });
                        }
                      });
                      return KeyEventResult.handled;
                    }
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
                      contentPadding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                    ),
                  ),
                ),
              ),
              ]),
              Row(children: [
                IconButton(
                  tooltip: tr('attach_file'),
                  icon: const Icon(Icons.attach_file_rounded),
                  onPressed: canChat ? _attach : null,
                ),
                IconButton(
                  tooltip: tr('web_search'),
                  isSelected: webSearchNotifier.value,
                  icon: const Icon(Icons.public_rounded),
                  selectedIcon: const Icon(Icons.public_rounded),
                  style: webSearchNotifier.value
                      ? IconButton.styleFrom(backgroundColor: scheme.primaryContainer, foregroundColor: scheme.onPrimaryContainer)
                      : null,
                  onPressed: () {
                    webSearchNotifier.value = !webSearchNotifier.value;
                    savePref('pc_web_search', webSearchNotifier.value);
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: VoiceInput.instance.listening,
                  builder: (_, on, _) => IconButton(
                    tooltip: tr('voice_input'),
                    isSelected: on,
                    icon: Icon(on ? Icons.mic_rounded : Icons.mic_none_rounded),
                    style: on
                        ? IconButton.styleFrom(backgroundColor: scheme.primaryContainer, foregroundColor: scheme.onPrimaryContainer)
                        : null,
                    onPressed: canChat ? _toggleMic : null,
                  ),
                ),
                IconButton(
                  tooltip: tr('tools_power'),
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => showChatToolsSheet(context),
                ),
                const Spacer(),
              AnimatedSwitcher(
                duration: M3Motion.effectsDefaultDuration,
                switchInCurve: M3Motion.spatialFast,
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                child: busy
                    ? IconButton.filled(
                        style: IconButton.styleFrom(fixedSize: const Size(44, 44), minimumSize: const Size(44, 44)),
                        key: const ValueKey('stop'),
                        tooltip: tr('stop'),
                        icon: const Icon(Icons.stop_rounded),
                        onPressed: ChatService.instance.requestStop,
                      )
                    : IconButton.filled(
                        style: IconButton.styleFrom(fixedSize: const Size(44, 44), minimumSize: const Size(44, 44)),
                        key: const ValueKey('send'),
                        tooltip: tr('send'),
                        icon: const Icon(Icons.arrow_upward_rounded),
                        onPressed: canSend ? _send : null,
                      ),
              ),
              ]),
            ])),
          ])),
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
            FadeSlideIn(
              child: M3CookieBadge(
                size: 88,
                color: scheme.primary,
                child: BrandIcon('assets/icons/app_logo.svg', Icons.chat_bubble_rounded, size: 44, color: scheme.onPrimary),
              ),
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
                for (final (i, k) in const ['suggest_1', 'suggest_2', 'suggest_3', 'suggest_4'].indexed)
                  FadeSlideIn(
                    delay: Duration(milliseconds: 150 + i * 70),
                    child: ActionChip(label: Text(tr(k)), onPressed: () => onSuggest(tr(k))),
                  ),
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
  final bool generating;
  final bool loadingModel;
  final VoidCallback onRegenerate;

  const _MessageView({
    required this.message,
    required this.showActions,
    required this.waiting,
    required this.generating,
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            for (final n in message.files)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.attach_file_rounded, size: 16, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 4),
                  Flexible(child: Text(n, style: text.labelMedium?.copyWith(color: scheme.onPrimaryContainer))),
                ]),
              ),
            Text(message.text, style: text.bodyLarge?.copyWith(color: scheme.onPrimaryContainer)),
          ]),
        ),
      );
    }

    return _HoverScope(builder: (context, hover) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PulseScale(
          active: generating,
          child: M3CookieBadge(
            size: 34,
            color: scheme.primary,
            child: BrandIcon('assets/icons/app_logo.svg', Icons.chat_bubble_rounded, size: 18, color: scheme.onPrimary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (message.steps.isNotEmpty && showStepsNotifier.value) StepsTimeline(steps: message.steps, running: generating),
            for (final cd in message.cards) InfoCard(data: cd),
            if (waiting)
              // Loading model / searching web / first words not here yet: full-width wavy line.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(width: double.infinity, child: M3WavyProgress(value: 1, height: 14)),
                  const SizedBox(height: 8),
                  Text(
                    loadingModel
                        ? tr('loading_model')
                        : ChatService.instance.isSearching
                            ? tr('searching_web')
                            : tr('thinking'),
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ]),
              )
            else if (message.text.isNotEmpty)
              // The text grows smoothly line by line, its tail fades in while it is written.
              AnimatedSize(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: double.infinity,
                  child: StreamFade(
                    active: generating,
                    child: MarkdownLite(text: generating ? message.text : FileOutput.hide(message.text), style: text.bodyLarge, linkColor: scheme.primary),
                  ),
                ),
              ),
            if (!generating)
              for (final f in FileOutput.extract(message.text))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: FadeSlideIn(
                    child: _FileCard(
                      file: f,
                      onTap: () => _showFilePreview(context, f),
                      onDownload: () async {
                        final ok = await FileOutput.save(f);
                        if (ok && context.mounted) _toast(context, tr('file_saved'));
                      },
                    ),
                  ),
                ),
            // While the answer is written, dots keep moving below the text.
            if (generating && !waiting && message.text.isNotEmpty)
              const Padding(padding: EdgeInsets.only(top: 6), child: ThinkingDots(size: 6)),
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
            if (message.memories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                // Hover (mouse) or long press (touch) shows what changed in memory.
                child: Tooltip(
                  message: message.memories.join('\n'),
                  waitDuration: const Duration(milliseconds: 250),
                  showDuration: const Duration(seconds: 6),
                  triggerMode: TooltipTriggerMode.longPress,
                  child: Chip(
                    avatar: const Icon(Icons.psychology_rounded, size: 18),
                    label: Text(tr('memory_saved')),
                  ),
                ),
              ),
            if (devModeNotifier.value && !generating && message.stats.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  _statChip(context, Icons.speed_rounded,
                      '${(message.stats['tps'] as num).toStringAsFixed(1)} ${tr('dev_tps')}'),
                  _statChip(context, Icons.data_array_rounded, '${message.stats['tokens']} ${tr('dev_tokens')}'),
                  _statChip(context, Icons.timer_outlined,
                      '${((message.stats['firstMs'] as num) / 1000).toStringAsFixed(2)} s ${tr('dev_first')}'),
                  _statChip(context, Icons.schedule_rounded,
                      '${((message.stats['totalMs'] as num) / 1000).toStringAsFixed(1)} s'),
                  _statChip(context, Icons.memory_rounded, '${message.stats['model']}'),
                  _statChip(context, Icons.view_headline_rounded,
                      '${tr('dev_prompt_tok')} ~${message.stats['promptTok']} / ctx ${message.stats['ctx']}'),
                  if (message.prompt.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.terminal_rounded, size: 18),
                      label: Text(tr('dev_view_prompt')),
                      onPressed: () => _showPrompt(context, message.prompt),
                    ),
                ]),
              ),
            if (message.sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.public_rounded, size: 18),
                  label: Text(_sourcesLabel(message.sources)),
                  onPressed: () => _showSources(context, message.sources),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a), child: c),
                ),
                child: !(showActions || (hover && !generating && message.text.isNotEmpty))
                    ? const SizedBox(key: ValueKey('noact'), width: double.infinity)
                    : Row(key: const ValueKey('act'), children: [
                IconButton(
                  tooltip: tr('copy'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    _toast(context, tr('copied'));
                  },
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: VoiceService.instance.speakingId,
                  builder: (_, id, _) => IconButton(
                    tooltip: tr(id == message.id ? 'voice_stop' : 'voice_read'),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(id == message.id ? Icons.stop_circle_outlined : Icons.volume_up_rounded, size: 18),
                    onPressed: () => VoiceService.instance.speak(message.id, message.text),
                  ),
                ),
                if (showActions)
                IconButton(
                  tooltip: tr('regenerate'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: onRegenerate,
                ),
              ]),
              ),
            ),
          ]),
        ),
      ]),
    ));
  }
}

// ── Developer mode ───────────────────────────────────────────────────────────

Widget _statChip(BuildContext context, IconData icon, String label) => Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: Theme.of(context).textTheme.labelMedium),
      visualDensity: VisualDensity.compact,
    );

void _showPrompt(BuildContext context, String prompt) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (_, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(children: [
            Expanded(child: Text(tr('dev_prompt_title'), style: Theme.of(ctx).textTheme.titleMedium)),
            IconButton(
              tooltip: tr('copy'),
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prompt));
                _toast(ctx, tr('copied'));
              },
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SelectableText(prompt, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.4)),
          ),
        ),
      ]),
    ),
  );
}

// ── Web sources bubble ───────────────────────────────────────────────────────

String _sourcesLabel(List<Map<String, String>> src) {
  final names = <String>[];
  for (final s in src) {
    final d = s['domain'] ?? '';
    if (d.isNotEmpty && !names.contains(d)) names.add(d);
  }
  final first = names.take(2).join(', ');
  return src.length > 2 ? '$first +${src.length - 2}' : first;
}

void _showSources(BuildContext context, List<Map<String, String>> src) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(children: [
                M3CookieBadge(size: 40, color: scheme.primary, child: Icon(Icons.public_rounded, color: scheme.onPrimary)),
                const SizedBox(width: 12),
                Text('${tr('sources_title')} · ${src.length}', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ]),
            ),
            for (final (i, s) in src.indexed)
              FadeSlideIn(
                delay: Duration(milliseconds: 40 * i.clamp(0, 10)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: scheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => launchUrl(Uri.parse(s['url'] ?? ''), mode: LaunchMode.externalApplication),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                        child: Row(children: [
                          _SourceThumb(url: s['url'] ?? '', domain: s['domain'] ?? ''),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(s['domain'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.north_east_rounded, size: 18, color: scheme.onSurfaceVariant),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
    },
  );
}


// ── File written by the AI ───────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final GeneratedFile file;
  final VoidCallback onTap; // preview
  final VoidCallback onDownload;
  const _FileCard({required this.file, required this.onTap, required this.onDownload});

  IconData _icon() {
    final e = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    if (const ['csv', 'tsv', 'xlsx'].contains(e)) return Icons.table_chart_rounded;
    if (const ['json', 'xml', 'html', 'py', 'js', 'ts', 'dart', 'css', 'sql', 'java', 'kt', 'c', 'cpp'].contains(e)) {
      return Icons.code_rounded;
    }
    return Icons.description_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (!materialShapesNotifier.value) {
      return ActionChip(avatar: const Icon(Icons.visibility_rounded, size: 18), label: Text(file.name), onPressed: onTap);
    }
    return Material(
      color: scheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            M3CookieBadge(size: 44, color: scheme.secondary, child: Icon(_icon(), size: 22, color: scheme.onSecondary)),
            const SizedBox(width: 12),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSecondaryContainer)),
                Text(formatBytes(file.content.length),
                    style: text.bodySmall?.copyWith(color: scheme.onSecondaryContainer.withValues(alpha: 0.7))),
              ]),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: tr('download'),
              icon: Icon(Icons.download_rounded, color: scheme.onSecondaryContainer),
              onPressed: onDownload,
            ),
          ]),
        ),
      ),
    );
  }
}


/// Message column width: grows on big screens.
double _contentW(BuildContext c) {
  final w = MediaQuery.of(c).size.width;
  return w > 1700 ? 1100 : (w > 1300 ? 960 : 820);
}

/// Tells its builder when the mouse is over it (desktop hover).
class _HoverScope extends StatefulWidget {
  final Widget Function(BuildContext, bool) builder;
  const _HoverScope({required this.builder});

  @override
  State<_HoverScope> createState() => _HoverScopeState();
}

class _HoverScopeState extends State<_HoverScope> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: widget.builder(context, _hover),
      );
}


// ── File preview ─────────────────────────────────────────────────────────────

void _showFilePreview(BuildContext context, GeneratedFile f) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
      Widget body;
      if (const ['csv', 'tsv', 'xlsx'].contains(ext)) {
        final rows = FileConvert.parseCsv(f.content);
        final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
        body = rows.isEmpty
            ? const SizedBox.shrink()
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 48,
                  columnSpacing: 20,
                  columns: [for (var i = 0; i < cols; i++) DataColumn(label: Text(i < rows.first.length ? rows.first[i] : '', style: const TextStyle(fontWeight: FontWeight.w800)))],
                  rows: [
                    for (final r in rows.skip(1).take(300))
                      DataRow(cells: [for (var i = 0; i < cols; i++) DataCell(Text(i < r.length ? r[i] : ''))]),
                  ],
                ),
              );
      } else if (const ['md', 'docx', 'pdf'].contains(ext)) {
        body = MarkdownLite(text: f.content, style: text.bodyLarge, linkColor: scheme.primary);
      } else {
        body = Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
          child: SelectableText(f.content, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.4)),
        );
      }
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scroll) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(children: [
              Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: tr('copy'),
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: f.content));
                  _toast(ctx, tr('copied'));
                },
              ),
              IconButton.filledTonal(
                tooltip: tr('download'),
                icon: const Icon(Icons.download_rounded),
                onPressed: () async {
                  final ok = await FileOutput.save(f);
                  if (ok && ctx.mounted) _toast(ctx, tr('file_saved'));
                },
              ),
            ]),
          ),
          Expanded(
            child: FadeSlideIn(
              child: SingleChildScrollView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: body),
            ),
          ),
        ]),
      );
    },
  );
}


// Result thumbnail (page picture), letter badge while loading or when there is none.
class _SourceThumb extends StatelessWidget {
  final String url;
  final String domain;
  const _SourceThumb({required this.url, required this.domain});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget badge() => M3CookieBadge(
          key: const ValueKey('badge'),
          size: 56,
          color: scheme.secondaryContainer,
          child: Text(domain.isEmpty ? '?' : domain.substring(0, 1).toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: scheme.onSecondaryContainer)),
        );
    return FutureBuilder<String?>(
      future: WebSearch.thumb(url),
      builder: (_, snap) {
        final u = snap.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: u == null
              ? badge()
              : ClipRRect(
                  key: ValueKey(u),
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(u, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, _, _) => badge()),
                ),
        );
      },
    );
  }
}
