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

  Future<void> replaceAll(List<String> list) async {
    for (final f in list) {
      await add(f);
    }
  }

  // "remember that..." typed by the user: the app saves it itself (small models are unreliable).
  static final _intent = RegExp(
      r'^\s*(?:please\s+|stp\s+|s\x27il te pla[iî]t\s+)?(?:enregistre|retiens|rappelle[- ]toi|souviens[- ]toi|m[ée]morise|note|remember|save|memorize|merk dir|speichere|recuerda|guarda)\b[\s,:]*(?:que|that|dass|qu\x27|:)?\s*(.+)$',
      caseSensitive: false,
      dotAll: true);

  static String? intentFact(String userText) {
    final m = _intent.firstMatch(userText.trim());
    final f = m?.group(1)?.trim();
    return (f == null || f.length < 3) ? null : f;
  }

  Future<void> clear() async {
    items = [];
    await _save();
  }

  // "[[memory: fact]]" tags written by the AI.
  static final tag = RegExp(r'\[{1,2}memory:\s*(.*?)\]{1,2}', dotAll: true);

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

  Future<List<String>> harvest(String s) async {
    final added = <String>[];
    for (final m in tag.allMatches(s)) {
      final f = (m.group(1) ?? '').trim();
      if (f.isEmpty || f.toLowerCase().contains('short fact') || f == '...') continue;
      added.add(f);
      await add(f);
    }
    return added;
  }
}
