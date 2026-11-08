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
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HardwareKeyboard, KeyDownEvent, LogicalKeyboardKey;
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
import '../services/file_output.dart';
import '../services/prefs.dart';
import '../services/reset.dart';
import 'intro_screen.dart';
import '../services/voice.dart';
import '../services/voice_input.dart';
import 'settings/memory_page.dart';
import 'settings/context_page.dart';
import '../widgets/info_cards.dart';
import '../services/location_service.dart';
import '../services/web_intent.dart';
import '../widgets/chat_tools_sheet.dart';
import '../services/chat_store.dart';
import '../services/hf_service.dart';
import '../services/inference_engine.dart';
import '../services/model_manager.dart';
import '../theme/m3_interaction.dart';
import '../theme/m3_motion.dart';
import '../widgets/brand_icon.dart';
import '../widgets/m3_components.dart';
import '../widgets/markdown_lite.dart';
import '../widgets/pc_motion.dart';
import 'settings/appearance_page.dart';
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
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
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

  @override
  void initState() {
    super.initState();
    localeNotifier.addListener(_rebuild);
    pcModeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_rebuild);
    pcModeNotifier.removeListener(_rebuild);
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
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

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
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: wide ? null : Drawer(child: SafeArea(child: sidebar(inDrawer: true))),
      body: wide
          ? Row(children: [
              SizedBox(width: 300, child: ColoredBox(color: scheme.surfaceContainerLow, child: SafeArea(child: sidebar(inDrawer: false)))),
              VerticalDivider(width: 1, color: scheme.outlineVariant),
              Expanded(child: chatView),
            ])
          : chatView,
    );
  }
}
