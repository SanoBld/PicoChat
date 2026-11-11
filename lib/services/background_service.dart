// lib/services/background_service.dart
// Keeps PicoChat working when it is not in front, only for what the person chose
// (Settings → Background):
//  • Android: the same foreground service as the model downloads keeps the app alive for
//    the sync, and for an answer that is being written. A notification shows while it runs.
//  • Windows / Linux / Mac: the window's close button reduces the window instead of quitting.
//  • iPhone: iOS suspends apps, so there is nothing to keep alive.
import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import 'chat_service.dart';
import 'notif_service.dart';
import 'sherpa_stt.dart';
import 'sherpa_tts.dart';
import 'sync/sync_service.dart';

class BackgroundService with WindowListener, TrayListener {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();
  static const _ch = MethodChannel('picochat/download'); // the foreground service of the downloads

  bool _on = false;
  bool _answering = false;

  static bool get desktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// True while something chosen by the person needs the app to stay alive.
  bool get wantsKeepAlive => _wantSync || _wantAnswer;
  bool get _wantSync => bgSyncNotifier.value && SyncService.instance.configured;
  bool get _wantAnswer => bgAnswersNotifier.value && ChatService.instance.isGenerating;

  Future<void> attach() async {
    if (kIsWeb) return;
    if (NotifService.supported) {
      SyncService.instance.addListener(_refresh);
      ChatService.instance.addListener(_refresh);
      bgSyncNotifier.addListener(_refresh);
      bgAnswersNotifier.addListener(_refresh);
      _refresh();
    }
    if (desktop) {
      try {
        await windowManager.ensureInitialized();
        await windowManager.setPreventClose(true);
        windowManager.addListener(this);
        trayManager.addListener(this);
        await trayManager.setIcon(_icon(false));
        await trayManager.setToolTip('PicoChat');
        await trayManager.setContextMenu(Menu(items: [
          MenuItem(key: 'open', label: tr('tray_open')),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: tr('tray_quit')),
        ]));
      } catch (_) {}
    }
  }

  String _icon(bool bg) =>
      'assets/tray/${bg ? 'tray_bg' : 'tray'}.${Platform.isWindows ? 'ico' : 'png'}';

  Future<void> _showWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
    try {
      await trayManager.setIcon(_icon(false)); // back to the normal icon
    } catch (_) {}
  }

  /// Quit at once: the window disappears first, the rest is cleaned up in the background.
  Future<void> quit() async {
    try {
      await windowManager.hide();
    } catch (_) {}
    try {
      SherpaStt.instance.close();
      SherpaTts.instance.close();
      await trayManager.destroy();
    } catch (_) {}
    exit(0);
  }

  @override
  Future<void> onWindowClose() async {
    if (bgCloseNotifier.value) {
      // The person chose to keep PicoChat running: hide it, an icon stays near the clock.
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
      try {
        await trayManager.setIcon(_icon(true)); // the icon changes while it runs in the background
      } catch (_) {}
    } else {
      await quit();
    }
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem item) {
    if (item.key == 'open') {
      _showWindow();
    } else if (item.key == 'quit') {
      quit();
    }
  }

  Future<void> _call(String m, [Map<String, Object?>? a]) async {
    try {
      await _ch.invokeMethod(m, a);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    final want = wantsKeepAlive;
    _answering = _wantAnswer;
    if (!want) {
      if (_on) {
        _on = false;
        if (!NotifService.instance.downloading) await _call('stop'); // downloads keep it if they need it
      }
      return;
    }
    final n = SyncService.instance.connectedCount;
    final args = {
      'title': 'PicoChat',
      'text': _answering ? tr('bg_answering') : tr('bg_sync_text', {'n': '$n'}),
      'percent': -2, // no progress bar
      'silent': true,
    };
    await _call(_on ? 'update' : 'start', args);
    _on = true;
  }
}
