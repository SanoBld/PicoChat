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

  /// Newest first.
  List<Conversation> get chats => List.unmodifiable(_chats);

  Future<void> init() async {
    if (kIsWeb) return; // no real filesystem on the web: in-memory only
    if (assistMode) return initAssist(); // overlay: no history loaded, only the inbox
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}${Platform.pathSeparator}chats.json');
      _inbox = File('${dir.path}${Platform.pathSeparator}$_inboxName');
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
    } catch (e) {
      debugPrint('ChatStore.initAssist failed: $e');
    }
  }

  /// Main app: adds the chats made in the assistant overlay to the history.
  Future<void> mergeInbox() async {
    final f = _inbox;
    if (assistMode || f == null) return;
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
  }

  void addMessage(Conversation c, ChatMessage m) {
    if (!_chats.contains(c)) _chats.insert(0, c);
    c.messages.add(m);
    c.updatedAt = DateTime.now();
    _sort();
    notifyListeners();
    _scheduleSave();
  }

  /// Call after editing a message in place (streaming).
  void messageChanged(Conversation c) {
    notifyListeners();
    _scheduleSave();
  }

  void removeMessage(Conversation c, ChatMessage m) {
    c.messages.remove(m);
    notifyListeners();
    _scheduleSave();
  }

  void rename(Conversation c, String title) {
    c.title = title.trim();
    c.autoTitle = false;
    notifyListeners();
    _scheduleSave();
  }

  void setAutoTitle(Conversation c, String title) {
    if (!c.autoTitle) return;
    c.title = title;
    notifyListeners();
    _scheduleSave();
  }

  void delete(Conversation c) {
    _chats.remove(c);
    notifyListeners();
    _scheduleSave();
  }

  Future<void> clearAll() async {
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
