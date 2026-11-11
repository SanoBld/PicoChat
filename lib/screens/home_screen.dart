// lib/screens/home_screen.dart
// ══════════════════════════════════════════════════════════════════════════
//  Main screen with adaptive layout (same idea as LastStats):
//    wide window (>= 900 dp, or pcMode 'on') → permanent sidebar + chat
//    narrow window                           → chat + slide-in drawer
//  The sidebar lists the chat history and links to Models and Settings.
// ══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io' show File;

import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HardwareKeyboard, KeyDownEvent, LogicalKeyboardKey, MethodChannel;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models/chat_models.dart';
import '../models/model_models.dart';
import '../supported_locales.dart';
import '../services/attachments.dart';
import '../services/backup.dart';
import '../services/chat_service.dart';
import '../services/file_convert.dart';
import '../services/file_output.dart';
import '../services/prefs.dart';
import '../services/reset.dart';
import 'intro_screen.dart';
import '../services/voice.dart';
import '../services/web_search.dart';
import '../services/voice_input.dart';
import 'settings/memory_page.dart';
import 'settings/context_page.dart';
import '../widgets/info_cards.dart';
import '../widgets/pico_avatar.dart';
import '../widgets/skeleton.dart' show M3LoadingIndicator;
import '../widgets/error_card.dart';
import '../services/location_service.dart';
import '../services/memory_store.dart';
import '../services/web_intent.dart';
import '../widgets/chat_tools_sheet.dart';
import '../services/chat_store.dart';
import '../services/device_info.dart';
import '../services/hf_service.dart';
import '../services/inference_engine.dart';
import '../services/model_manager.dart';
import '../theme/m3_interaction.dart';
import '../theme/m3_motion.dart';
import '../theme/m3_shapes.dart';
import '../widgets/pico_face.dart';
import '../widgets/opening_splash.dart';
import '../widgets/pc_menu.dart';
import '../widgets/m3_components.dart';
import '../widgets/markdown_lite.dart';
import '../widgets/pc_motion.dart';
import 'settings/appearance_page.dart';
import 'settings/cloud_page.dart';
import '../widgets/brand_icon.dart';
import '../services/cloud/cloud_store.dart';
import 'settings/access_settings_page.dart';
import 'settings/assistant_page.dart';
import 'settings/backup_page.dart';
import 'settings/sync_page.dart';
import '../services/sync/sync_service.dart';
import 'settings/chat_settings_page.dart';
import 'settings/hf_page.dart';
import 'settings/language_page.dart';
import 'settings/privacy_page.dart';
import 'settings/settings_helpers.dart';
import 'settings/settings_rows.dart';
import 'settings/storage_page.dart';

// Parts
part '_sidebar.dart';
part '_chat_view.dart';
part '_models_page.dart';
part '_settings_page.dart';
part '_about_page.dart';

const double _kWideBreakpoint = 900.0;

/// True when the sidebar layout is used.
bool _isWideLayout(BuildContext context) {
  final mode = pcModeNotifier.value;
  if (mode == 'on') return true;
  if (mode == 'off') return false;
  return MediaQuery.of(context).size.width >= _kWideBreakpoint;
}

bool get _isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

void _toast(BuildContext context, String message) {
  final scheme = Theme.of(context).colorScheme;
  final wide = MediaQuery.sizeOf(context).width > 600;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      duration: const Duration(milliseconds: 2600),
      backgroundColor: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // A floating bar is either full width with margin, or a fixed width on big screens.
      width: wide ? 420 : null,
      margin: wide ? null : const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: Row(children: [
        Icon(Icons.info_outline_rounded, size: 20, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: TextStyle(color: scheme.onSurface))),
      ]),
    ));
}

/// Translated message for a download / Hugging Face error kind.
String _errorText(String? kind) => tr('err_${kind ?? 'server'}');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Conversation _chat = ChatStore.instance.create();
  bool _dragging = false; // sidebar edge is being dragged
  bool _hover = false; // sidebar shown over the chat while hovering the left edge

  @override
  void initState() {
    super.initState();
    localeNotifier.addListener(_rebuild);
    pcModeNotifier.addListener(_rebuild);
    sidebarCollapsedNotifier.addListener(_rebuild);
    sidebarWidthNotifier.addListener(_rebuild);
    ChatStore.instance.openRequest.addListener(_openRequested);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequested()); // cold start from the assistant
    _initAssist();
  }

  // The assistant asked for its conversation to be opened here.
  void _openRequested() {
    final id = ChatStore.instance.openRequest.value;
    if (id == null || !mounted) return;
    ChatStore.instance.openRequest.value = null;
    for (final c in ChatStore.instance.chats) {
      if (c.id == id) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        _select(c);
        return;
      }
    }
  }

  // Android assistant: the small overlay runs its own engine, so this one frees
  // the model first (two copies of a model would not fit in the RAM).
  static const _assist = MethodChannel('picochat/assist');

  void _initAssist() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _assist.setMethodCallHandler((call) async {
      if (call.method == 'unload') await InferenceService.engine.unload();
      if (call.method == 'launchAction') _handleLaunch(call.arguments as String?);
    });
    // Action that started the app (shortcut, share, selection menu).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        _handleLaunch(await _assist.invokeMethod<String>('launchAction'));
      } catch (_) {}
    });
  }

  void _handleLaunch(String? a) {
    if (a == null || !mounted) return;
    if (a == 'new_chat') {
      _newChat();
    } else if (a == 'voice') {
      _newChat();
      voiceRequestNotifier.value = true;
    } else if (a == 'web') {
      webSearchNotifier.value = true;
      savePref('pc_web_search', true);
      _newChat();
    } else if (a.startsWith('send:')) {
      _newChat();
      draftNotifier.value = a.substring(5);
    }
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_rebuild);
    pcModeNotifier.removeListener(_rebuild);
    sidebarCollapsedNotifier.removeListener(_rebuild);
    sidebarWidthNotifier.removeListener(_rebuild);
    ChatStore.instance.openRequest.removeListener(_openRequested);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _select(Conversation c) => setState(() => _chat = c);

  void _newChat() {
    // Don't stack empty chats: reuse the current one when it has no message.
    if (_chat.messages.isEmpty) return;
    setState(() => _chat = ChatStore.instance.create());
  }

  void _onDeleted(Conversation c) {
    if (c.id == _chat.id) setState(() => _chat = ChatStore.instance.create());
  }

  void _push(Widget page) =>
      Navigator.of(context).push(M3SharedAxisRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final wide = _isWideLayout(context);
    final scheme = Theme.of(context).colorScheme;

    Widget sidebar({required bool inDrawer}) => _Sidebar(
          selectedId: _chat.id,
          onSelect: (c) {
            if (inDrawer) Navigator.of(context).pop();
            _select(c);
          },
          onNew: () {
            if (inDrawer) Navigator.of(context).pop();
            _newChat();
          },
          onDeleted: _onDeleted,
          onOpenModels: () {
            if (inDrawer) Navigator.of(context).pop();
            _push(const _ModelsPage());
          },
          onOpenSettings: () {
            if (inDrawer) Navigator.of(context).pop();
            _push(const _SettingsPage());
          },
        );

    final chatView = _ChatView(
      key: ValueKey(_chat.id),
      chat: _chat,
      onMenu: wide ? null : () => _scaffoldKey.currentState?.openDrawer(),
      onNewChat: _newChat,
      onOpenModels: () => _push(const _ModelsPage()),
      onOpenChat: _select,
      onToggleSidebar: wide
          ? () {
              _hover = false;
              sidebarCollapsedNotifier.value = !sidebarCollapsedNotifier.value;
              savePref('pc_sidebar_collapsed', sidebarCollapsedNotifier.value);
            }
          : null,
    );
    final collapsed = sidebarCollapsedNotifier.value;

    return CallbackShortcuts(
      bindings: {
        for (final ctrl in const [true, false])
          SingleActivator(LogicalKeyboardKey.keyN, control: ctrl, meta: !ctrl): _newChat,
        for (final ctrl in const [true, false])
          SingleActivator(LogicalKeyboardKey.comma, control: ctrl, meta: !ctrl): () => _push(const _SettingsPage()),
        for (final ctrl in const [true, false])
          SingleActivator(LogicalKeyboardKey.keyM, control: ctrl, meta: !ctrl): () => _push(const _ModelsPage()),
      },
      child: Scaffold(
      key: _scaffoldKey,
      drawer: wide ? null : Drawer(child: SafeArea(child: sidebar(inDrawer: true))),
      body: wide
          ? Stack(children: [
              Row(children: [
                AnimatedContainer(
                  duration: _dragging ? Duration.zero : const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  width: collapsed ? 0 : sidebarWidthNotifier.value,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: sidebarWidthNotifier.value,
                    maxWidth: sidebarWidthNotifier.value,
                    child: SizedBox(
                      width: sidebarWidthNotifier.value,
                      child: Row(children: [
                        Expanded(child: ColoredBox(color: scheme.surfaceContainerLow, child: SafeArea(child: sidebar(inDrawer: false)))),
                        // Drag this edge to make the sidebar wider or narrower.
                        MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (_) => setState(() => _dragging = true),
                            onHorizontalDragUpdate: (d) => sidebarWidthNotifier.value =
                                (sidebarWidthNotifier.value + d.delta.dx).clamp(220.0, 520.0),
                            onHorizontalDragEnd: (_) {
                              setState(() => _dragging = false);
                              savePref('pc_sidebar_width', sidebarWidthNotifier.value);
                            },
                            child: SizedBox(
                              width: 10,
                              child: Center(child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                Expanded(child: M3Switcher(child: chatView)),
              ]),
              if (collapsed) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 14,
                  child: MouseRegion(onEnter: (_) => setState(() => _hover = true), child: const SizedBox.expand()),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: _hover ? 8 : -320,
                  top: 8,
                  bottom: 8,
                  width: 300,
                  child: MouseRegion(
                    onExit: (_) => setState(() => _hover = false),
                    child: Material(
                      elevation: 12,
                      color: scheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      clipBehavior: Clip.antiAlias,
                      child: sidebar(inDrawer: false),
                    ),
                  ),
                ),
              ],
            ])
          : M3Switcher(child: chatView),
    ),
    );
  }
}
