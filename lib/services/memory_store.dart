// lib/services/memory_store.dart
// Personal memory: short facts the AI keeps about the user.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryStore extends ChangeNotifier {
  MemoryStore._();
  static final MemoryStore instance = MemoryStore._();
  static const _key = 'pc_memories';

  List<String> items = [];

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    items = p.getStringList(_key) ?? [];
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, items);
    notifyListeners();
  }

  Future<void> add(String fact) async {
    final f = fact.trim();
    if (f.isEmpty || items.any((e) => e.toLowerCase() == f.toLowerCase())) return;
    items = [...items, f];
    await _save();
  }

  Future<void> removeAt(int i) async {
    items = [...items]..removeAt(i);
    await _save();
  }

  Future<void> clear() async {
    items = [];
    await _save();
  }

  // "[[memory: fact]]" tags written by the AI.
  static final tag = RegExp(r'\[\[memory:\s*(.*?)\]\]', dotAll: true);

  // Text without tags (also hides a tag that is still being written).
  static String visible(String s) {
    var out = s.replaceAll(tag, '');
    final open = out.lastIndexOf('[[');
    if (open != -1) {
      final tail = out.substring(open);
      if (!tail.contains(']]') && ('[[memory:'.startsWith(tail) || tail.startsWith('[[memory:'))) {
        out = out.substring(0, open);
      }
    }
    return out.trimRight();
  }

  Future<void> harvest(String s) async {
    for (final m in tag.allMatches(s)) {
      await add(m.group(1) ?? '');
    }
  }
}
