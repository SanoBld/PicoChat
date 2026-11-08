// lib/services/chat_store.dart
// Conversation storage: one JSON file in the app's private folder.
// Nothing is ever sent anywhere.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_models.dart';

class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  final List<Conversation> _chats = [];
  File? _file;
  Timer? _saveTimer;

  /// Newest first.
  List<Conversation> get chats => List.unmodifiable(_chats);

  Future<void> init() async {
    if (kIsWeb) return; // no real filesystem on the web: in-memory only
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}${Platform.pathSeparator}chats.json');
      if (await _file!.exists()) {
        final data = jsonDecode(await _file!.readAsString());
        if (data is List) {
          for (final c in data.whereType<Map>()) {
            _chats.add(Conversation.fromJson(Map<String, dynamic>.from(c)));
          }
        }
      }
    } catch (e) {
      debugPrint('ChatStore.init failed: $e'); // corrupted file: start clean
    }
    _sort();
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
