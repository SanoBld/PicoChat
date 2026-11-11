// lib/services/sync/sync_data.dart
// Reads and writes the data of each category. Shared by the backup file and by the
// device sync, so both move exactly the same things.

import '../../models/chat_models.dart';
import '../chat_store.dart';
import '../memory_store.dart';
import 'sync_prefs.dart';

class SyncData {
  /// Everything of the chosen categories as plain JSON.
  static Map<String, dynamic> collect(Set<String> cats) {
    final out = <String, dynamic>{};
    if (cats.contains(kCatChats)) {
      out[kCatChats] = [
        for (final c in ChatStore.instance.chats)
          if (c.messages.isNotEmpty) c.toJson()
      ];
    }
    if (cats.contains(kCatMemory)) {
      out[kCatMemory] = {'facts': MemoryStore.instance.items, 'ts': MemoryStore.instance.modifiedAt};
    }
    final prefs = <String, dynamic>{};
    for (final p in kSyncPrefs) {
      if (cats.contains(p.cat)) prefs[p.key] = p.read();
    }
    if (prefs.isNotEmpty) out['prefs'] = prefs;
    return out;
  }

  /// What a backup file holds: category → number of items (settings count as 1 per setting).
  static Map<String, int> peek(Map<String, dynamic> data) {
    final out = <String, int>{};
    final chats = data[kCatChats];
    if (chats is List) out[kCatChats] = chats.length;
    final mem = data[kCatMemory];
    if (mem is Map && mem['facts'] is List) out[kCatMemory] = (mem['facts'] as List).length;
    final prefs = data['prefs'];
    if (prefs is Map) {
      for (final k in prefs.keys) {
        final p = syncPrefByKey('$k');
        if (p == null) continue;
        out[p.cat] = (out[p.cat] ?? 0) + 1;
      }
    }
    return out;
  }

  /// Restores the chosen categories from [data] (a backup). Chats and memory are merged:
  /// nothing already on this device is deleted. Settings are overwritten.
  static Future<void> restore(Map<String, dynamic> data, Set<String> cats) async {
    if (cats.contains(kCatChats) && data[kCatChats] is List) {
      for (final m in (data[kCatChats] as List).whereType<Map>()) {
        try {
          ChatStore.instance.applyRemoteChat(Conversation.fromJson(Map<String, dynamic>.from(m)));
        } catch (_) {}
      }
    }
    final mem = data[kCatMemory];
    if (cats.contains(kCatMemory) && mem is Map && mem['facts'] is List) {
      final merged = [...MemoryStore.instance.items];
      for (final f in (mem['facts'] as List).whereType<String>()) {
        if (!merged.any((e) => e.toLowerCase() == f.toLowerCase())) merged.add(f);
      }
      await MemoryStore.instance.applyRemote(merged, DateTime.now().millisecondsSinceEpoch);
    }
    final prefs = data['prefs'];
    if (prefs is Map) {
      for (final e in prefs.entries) {
        final p = syncPrefByKey('${e.key}');
        if (p == null || !cats.contains(p.cat) || e.value == null) continue;
        try {
          await applySyncPref(p, e.value as Object);
        } catch (_) {}
      }
    }
  }
}
