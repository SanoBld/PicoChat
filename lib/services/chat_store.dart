// lib/services/chat_store.dart
// Conversation storage: one JSON file in the app's private folder.
// Nothing is ever sent anywhere.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:path_provider/path_provider.dart';

import '../models/chat_models.dart';

class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  final List<Conversation> _chats = [];
  File? _file;
  Timer? _saveTimer;

  /// True in the assistant overlay. It runs in its own engine, so it never writes chats.json
  /// (it would overwrite the app's chats): its chats go to a small inbox file that the app
  /// merges into the history when it starts and when it comes back to the front.
  bool assistMode = false;
  File? _inbox;
  AppLifecycleListener? _life;
  static const _inboxName = 'assist_inbox.json';
  static const _openName = 'assist_open.txt';
  File? _openFile;

  /// Id of a chat the assistant asked the app to open (the home screen reacts to it).
  final ValueNotifier<String?> openRequest = ValueNotifier<String?>(null);

  /// Newest first.
  List<Conversation> get chats => List.unmodifiable(_chats);

  // ── Device sync hooks ───────────────────────────────────────────────────────
  // SyncService listens here. [onLocal] fires for changes made on this device only
  // (never for changes that come from another device, so nothing bounces back).
  void Function(Conversation c, ChatMessage? changed)? onLocal;
  void Function(String id, DateTime at)? onDeleted;

  void _local(Conversation c, [ChatMessage? m]) => onLocal?.call(c, m);

  /// Another device sent a whole chat: newer wins. The open chat object is updated in place.
  bool applyRemoteChat(Conversation r) {
    if (r.messages.isEmpty) return false;
    final i = _chats.indexWhere((x) => x.id == r.id);
    if (i < 0) {
      _chats.add(r);
    } else {
      final c = _chats[i];
      if (!r.updatedAt.isAfter(c.updatedAt)) return false;
      c.title = r.title;
      c.autoTitle = r.autoTitle;
      c.updatedAt = r.updatedAt;
      c.modelId = r.modelId;
      // Keep the pictures this device already has for its own messages.
      final keep = {for (final m in c.messages) m.id: m.images};
      c.messages
        ..clear()
        ..addAll(r.messages);
      for (final m in c.messages) {
        final img = keep[m.id];
        if (img != null && img.isNotEmpty) m.images = img;
      }
    }
    _sort();
    notifyListeners();
    _scheduleSave();
    return true;
  }

  /// Live update: one message of a chat that another device is writing.
  void applyRemoteMessage(Map<String, dynamic> meta, ChatMessage m) {
    final id = '${meta['id']}';
    var c = _chats.cast<Conversation?>().firstWhere((x) => x!.id == id, orElse: () => null);
    final at = DateTime.tryParse('${meta['updatedAt']}') ?? DateTime.now();
    if (c == null) {
      c = Conversation(
        id: id,
        title: '${meta['title'] ?? ''}',
        autoTitle: meta['autoTitle'] != false,
        createdAt: DateTime.tryParse('${meta['createdAt']}'),
        updatedAt: at,
        modelId: '${meta['modelId'] ?? ''}',
      );
      _chats.add(c);
    }
    final j = c.messages.indexWhere((x) => x.id == m.id);
    if (j >= 0) {
      c.messages[j].copyFrom(m);
    } else {
      c.messages.add(m);
    }
    if (at.isAfter(c.updatedAt)) c.updatedAt = at;
    c.title = '${meta['title'] ?? c.title}';
    _sort();
    notifyListeners();
    _scheduleSave();
  }

  /// Another device deleted this chat (only if it was not used since).
  bool removeRemote(String id, DateTime at) {
    final i = _chats.indexWhere((x) => x.id == id);
    if (i < 0 || _chats[i].updatedAt.isAfter(at)) return false;
    _chats.removeAt(i);
    notifyListeners();
    _scheduleSave();
    return true;
  }

  Future<void> init() async {
    if (kIsWeb) return; // no real filesystem on the web: in-memory only
    if (assistMode) return initAssist(); // overlay: no history loaded, only the inbox
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}${Platform.pathSeparator}chats.json');
      _inbox = File('${dir.path}${Platform.pathSeparator}$_inboxName');
      _openFile = File('${dir.path}${Platform.pathSeparator}$_openName');
      if (await _file!.exists()) {
        final data = jsonDecode(await _file!.readAsString());
        if (data is List) {
          for (final c in data.whereType<Map>()) {
            _chats.add(Conversation.fromJson(Map<String, dynamic>.from(c)));
            // A picture that was still being made when the app closed will never arrive.
            for (final m in _chats.last.messages) {
              for (final cd in m.cards) {
                if (cd['type'] == 'genimg' && cd['state'] == 'loading') cd['state'] = 'error';
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ChatStore.init failed: $e'); // corrupted file: start clean
    }
    _sort();
    await mergeInbox();
    try {
      _life ??= AppLifecycleListener(onResume: mergeInbox);
    } catch (_) {}
  }

  /// Assistant overlay: only prepares the inbox file (no chats are loaded).
  Future<void> initAssist() async {
    assistMode = true;
    if (kIsWeb) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _inbox = File('${dir.path}${Platform.pathSeparator}$_inboxName');
      _openFile = File('${dir.path}${Platform.pathSeparator}$_openName');
    } catch (e) {
      debugPrint('ChatStore.initAssist failed: $e');
    }
  }

  /// Assistant overlay: asks the app to open this chat the next time it comes to the front.
  Future<void> requestOpen(String id) async {
    try {
      await _openFile?.writeAsString(id, flush: true);
    } catch (_) {}
  }

  Future<void> _readOpenRequest() async {
    final o = _openFile;
    if (o == null) return;
    try {
      if (!await o.exists()) return;
      final id = (await o.readAsString()).trim();
      await o.delete();
      if (id.isNotEmpty && _chats.any((c) => c.id == id)) {
        openRequest.value = null; // same id twice in a row still notifies
        openRequest.value = id;
      }
    } catch (_) {}
  }

  /// Main app: adds the chats made in the assistant overlay to the history.
  Future<void> mergeInbox() async {
    final f = _inbox;
    if (assistMode || f == null) return;
    try {
      await _mergeFile(f);
    } finally {
      await _readOpenRequest();
    }
  }

  Future<void> _mergeFile(File f) async {
    try {
      if (!await f.exists()) return;
      final data = jsonDecode(await f.readAsString());
      await f.delete();
      if (data is! List) return;
      for (final m in data.whereType<Map>()) {
        final c = Conversation.fromJson(Map<String, dynamic>.from(m));
        if (c.messages.isEmpty) continue;
        final i = _chats.indexWhere((x) => x.id == c.id);
        if (i >= 0) {
          _chats[i] = c;
        } else {
          _chats.add(c);
        }
      }
      _sort();
      notifyListeners();
      _scheduleSave();
    } catch (e) {
      debugPrint('ChatStore.mergeInbox failed: $e');
    }
  }

  Future<void> _flushInbox() async {
    final f = _inbox;
    if (f == null) return;
    try {
      final byId = <String, Map<String, dynamic>>{};
      if (await f.exists()) {
        final d = jsonDecode(await f.readAsString());
        if (d is List) {
          for (final c in d.whereType<Map>()) {
            final m = Map<String, dynamic>.from(c);
            byId['${m['id']}'] = m;
          }
        }
      }
      for (final c in _chats) {
        if (c.messages.isNotEmpty) byId[c.id] = c.toJson();
      }
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(byId.values.toList()), flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('ChatStore inbox flush failed: $e');
    }
  }

  void _sort() => _chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// Creates an empty chat. It joins the history with its first message.
  Conversation create({String modelId = ''}) => Conversation(modelId: modelId);

  void importChat(Conversation c) {
    _chats.insert(0, c);
    _sort();
    notifyListeners();
    _scheduleSave();
    _local(c);
  }

  void addMessage(Conversation c, ChatMessage m) {
    if (!_chats.contains(c)) _chats.insert(0, c);
    c.messages.add(m);
    c.updatedAt = DateTime.now();
    _sort();
    notifyListeners();
    _scheduleSave();
    _local(c, m);
  }

  /// Call after editing a message in place (streaming).
  void messageChanged(Conversation c) {
    c.updatedAt = DateTime.now(); // "newest wins" between devices needs a fresh date
    notifyListeners();
    _scheduleSave();
    _local(c, c.messages.isEmpty ? null : c.messages.last);
  }

  void removeMessage(Conversation c, ChatMessage m) {
    c.messages.remove(m);
    c.updatedAt = DateTime.now();
    notifyListeners();
    _scheduleSave();
    _local(c);
  }

  void rename(Conversation c, String title) {
    c.title = title.trim();
    c.autoTitle = false;
    c.updatedAt = DateTime.now();
    notifyListeners();
    _scheduleSave();
    _local(c);
  }

  void setAutoTitle(Conversation c, String title) {
    if (!c.autoTitle) return;
    c.title = title;
    c.updatedAt = DateTime.now();
    notifyListeners();
    _scheduleSave();
    _local(c);
  }

  void delete(Conversation c) {
    _chats.remove(c);
    notifyListeners();
    _scheduleSave();
    onDeleted?.call(c.id, DateTime.now());
  }

  Future<void> clearAll() async {
    for (final c in _chats) {
      onDeleted?.call(c.id, DateTime.now());
    }
    _chats.clear();
    notifyListeners();
    await flush();
  }

  /// Case-insensitive search in titles and message text.
  List<Conversation> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return chats;
    return _chats
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            c.messages.any((m) => m.text.toLowerCase().contains(q)))
        .toList();
  }

  Future<int> sizeOnDisk() async {
    try {
      if (_file != null && await _file!.exists()) return await _file!.length();
    } catch (_) {}
    return 0;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    if (assistMode) return _flushInbox();
    final f = _file;
    if (f == null) return;
    try {
      final json = jsonEncode(_chats.map((c) => c.toJson()).toList());
      // Temp file first, so a crash never leaves a half-written file.
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('ChatStore.flush failed: $e');
    }
  }
}
