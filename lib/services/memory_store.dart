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

  /// Returns true when the fact was really added (not empty, not a duplicate).
  Future<bool> add(String fact) async {
    final f = fact.trim();
    if (f.isEmpty || items.any((e) => e.toLowerCase() == f.toLowerCase())) return false;
    items = [...items, f];
    await _save();
    return true;
  }

  static List<String> _words(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-zàâäçéèêëîïôöùûüœ0-9]+'))
      .where((w) => w.length >= 4)
      .toList();

  /// Items that match [query] (same text, or most of its words).
  List<String> _match(String query) {
    final q = query.toLowerCase().trim();
    final qw = _words(q);
    return [
      for (final e in items)
        if (e.toLowerCase().contains(q) ||
            (qw.isNotEmpty && qw.where((w) => e.toLowerCase().contains(w)).length >= (qw.length * 0.6).ceil()))
          e
    ];
  }

  /// Deletes the facts that match [query]. Returns the removed facts.
  Future<List<String>> forget(String query) async {
    final hit = _match(query);
    if (hit.isEmpty) return [];
    items = [for (final e in items) if (!hit.contains(e)) e];
    await _save();
    return hit;
  }

  /// Replaces the fact that matches [oldFact] by [newFact]. False if none matches.
  Future<bool> update(String oldFact, String newFact) async {
    final hit = _match(oldFact);
    final n = newFact.trim();
    if (hit.isEmpty || n.isEmpty) return false;
    final i = items.indexOf(hit.first);
    items = [...items]..[i] = n;
    await _save();
    return true;
  }

  // The fact must come from what the user wrote: at least half of its words are in the message.
  // This blocks invented facts and things taken from files or web pages.
  static bool grounded(String fact, String userText) {
    final fw = _words(fact);
    if (fw.isEmpty) return userText.toLowerCase().contains(fact.toLowerCase());
    final u = userText.toLowerCase();
    return fw.where(u.contains).length >= (fw.length / 2).ceil();
  }

  static final _fileLike = RegExp(r'\.(pdf|docx?|xlsx?|pptx?|txt|csv|png|jpe?g|zip)\b|\b(pdf|fichier|file|document)\b',
      caseSensitive: false);

  // "forget that ..." / "delete ... from your memory", typed by the user (done by the app itself).
  static final _forgetA = RegExp(
      r'^\s*(?:oublie|oubliez|forget|vergiss|olvida)\b[\s,:]*(?:que|that|dass|qu\x27|:)?\s*(.+)$',
      caseSensitive: false, dotAll: true);
  static final _forgetB = RegExp(
      r'^\s*(?:supprime|efface|retire|enl[eè]ve|delete|remove|l[öo]sche)\s+(.+?)\s+(?:de|from|aus|din)\s+(?:ta|ma|la|your|the|deiner|der)\s+(?:m[ée]moire|memory|ged[äa]chtnis)\b',
      caseSensitive: false, dotAll: true);

  static String? forgetIntent(String userText) {
    final t = userText.trim();
    final m = _forgetB.firstMatch(t) ?? _forgetA.firstMatch(t);
    final f = m?.group(1)?.trim();
    return (f == null || f.length < 3) ? null : f;
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

  // "[[memory: fact]]", "[[forget: fact]]", "[[update: old => new]]" tags written by the AI.
  static final tag = RegExp(r'\[{1,2}(memory|forget|update):\s*(.*?)\]{1,2}', dotAll: true);
  static final mapTag = RegExp(r'\[\[map-(?:point|route|clear)[^\]]*\]\]');
  static final searchTag = RegExp(r'\[\[search:[\s\S]*?\]\]');
  static final imagineTag = RegExp(r'\[\[imagine:\s*([\s\S]*?)\]\]');
  static const _prefixes = ['[[memory:', '[[forget:', '[[update:', '[[map-', '[[image:', '[[search:', '[[imagine:'];

  // Text without tags (also hides a tag that is still being written).
  static String visible(String s) {
    var out = s.replaceAll(tag, '').replaceAll(mapTag, '').replaceAll(searchTag, '').replaceAll(imagineTag, '');
    final open = out.lastIndexOf('[[');
    if (open != -1) {
      final tail = out.substring(open);
      if (!tail.contains(']]') && _prefixes.any((p) => p.startsWith(tail) || tail.startsWith(p))) {
        out = out.substring(0, open);
      }
    }
    return out.trimRight();
  }

  /// Runs the tags of an answer. Returns short lines for the chip: "+ fact", "− fact", "✎ old → new".
  Future<List<String>> harvest(String s, {String userText = '', bool hadFiles = false}) async {
    final events = <String>[];
    for (final m in tag.allMatches(s)) {
      final kind = m.group(1);
      final f = (m.group(2) ?? '').trim();
      if (f.isEmpty || f.toLowerCase().contains('short fact') || f.contains('<') || f == '...') continue;
      if (kind == 'memory') {
        if (f.length > 160 || (hadFiles && _fileLike.hasMatch(f)) || !grounded(f, userText)) continue;
        if (await add(f)) events.add('+ $f');
      } else if (kind == 'forget') {
        // Only when the user really asked to forget something.
        if (forgetIntent(userText) == null && !RegExp(r'oubli|forget|supprim|efface|delete|remove', caseSensitive: false).hasMatch(userText)) continue;
        for (final r in await forget(f)) {
          events.add('− $r');
        }
      } else if (kind == 'update') {
        final parts = f.split('=>');
        if (parts.length != 2 || !grounded(parts[1], userText)) continue;
        if (await update(parts[0], parts[1])) events.add('✎ ${parts[0].trim()} → ${parts[1].trim()}');
      }
    }
    return events;
  }
}
