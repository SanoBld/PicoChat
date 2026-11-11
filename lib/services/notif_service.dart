// lib/services/notif_service.dart
// Android: keeps model downloads alive in the background (foreground service)
// and shows a progress notification, then a "finished / failed" one.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import 'background_service.dart';
import 'model_manager.dart';

class NotifService {
  NotifService._();
  static final NotifService instance = NotifService._();
  static const _ch = MethodChannel('picochat/download');
  static bool get supported => !kIsWeb && Platform.isAndroid;

  bool _running = false;
  bool get downloading => _running;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, String> _prev = {}; // task id → file name, while downloading
  int _installedCount = 0;

  void attach() {
    if (!supported) return;
    _installedCount = ModelManager.instance.installed.length;
    ModelManager.instance.addListener(_onChange);
  }

  /// Asks the Android 13+ notification permission.
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    return (await Permission.notification.request()).isGranted;
  }

  Future<void> _call(String m, [Map<String, Object?>? a]) async {
    try {
      await _ch.invokeMethod(m, a);
    } catch (_) {}
  }

  Future<void> _onChange() async {
    final mgr = ModelManager.instance;
    final active = mgr.tasks.where((t) => t.status == DownloadStatus.downloading).toList();
    final now = DateTime.now();

    // Finished or failed since the last call.
    final ids = active.map((t) => t.id).toSet();
    for (final e in _prev.entries.where((e) => !ids.contains(e.key)).toList()) {
      _prev.remove(e.key);
      final task = mgr.tasks.where((t) => t.id == e.key).firstOrNull;
      if (!notifDoneNotifier.value) continue;
      if (mgr.installed.length > _installedCount) {
        await _call('done', {'title': tr('n_done_title'), 'text': e.value});
      } else if (task != null && task.status == DownloadStatus.failed) {
        await _call('done', {'title': tr('n_failed_title'), 'text': e.value});
      }
    }
    _installedCount = mgr.installed.length;
    for (final t in active) {
      _prev[t.id] = t.fileName;
    }

    if (active.isEmpty || !notifBackgroundNotifier.value) {
      if (_running) {
        _running = false;
        if (!BackgroundService.instance.wantsKeepAlive) await _call('stop'); // sync / answer may still need it
      }
      return;
    }
    if (now.difference(_last).inMilliseconds < 1000 && _running) return;
    _last = now;

    final t = active.first;
    final pct = t.total > 0 ? (t.fraction * 100).round() : -1;
    final speed = t.speedBps > 0 ? ' · ${(t.speedBps / 1048576).toStringAsFixed(1)} MB/s' : '';
    final more = active.length > 1 ? ' (+${active.length - 1})' : '';
    final args = {
      'title': '${tr('n_downloading')} ${t.fileName}$more',
      'text': pct >= 0 ? '$pct %$speed' : tr('n_waiting'),
      'percent': notifProgressNotifier.value ? pct : -2, // -2 = no notification text update
      'silent': !notifProgressNotifier.value,
    };
    if (!_running) {
      _running = true;
      if (notifProgressNotifier.value || notifBackgroundNotifier.value) await _call('start', args);
    } else {
      await _call('update', args);
    }
  }
}
