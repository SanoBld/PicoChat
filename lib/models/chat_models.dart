// lib/models/chat_models.dart
// Plain JSON-serialisable data classes for conversations.

import 'dart:math';

enum ChatRole { system, user, assistant }

/// Short unique id (time + random), enough for local storage.
String newId() {
  final r = Random().nextInt(1 << 20).toRadixString(36);
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$r';
}

class ChatMessage {
  final String id;
  final ChatRole role;
  String text;
  final DateTime createdAt;
  bool stopped; // the person pressed stop while this answer was written
  bool failed; // the engine failed while writing this answer
  String context; // hidden text sent with this message (files, web results)
  List<String> files; // names of attached files (display only)
  List<Map<String, String>> sources; // web pages used for this answer
  List<String> memories; // facts saved to memory by this answer

  ChatMessage({
    String? id,
    required this.role,
    required this.text,
    DateTime? createdAt,
    this.stopped = false,
    this.failed = false,
    this.context = '',
    List<String>? files,
    List<Map<String, String>>? sources,
    List<String>? memories,
  })  : files = files ?? [],
        memories = memories ?? [],
        sources = sources ?? [],
        id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        if (stopped) 'stopped': true,
        if (failed) 'failed': true,
        if (context.isNotEmpty) 'context': context,
        if (files.isNotEmpty) 'files': files,
        if (sources.isNotEmpty) 'sources': sources,
        if (memories.isNotEmpty) 'memories': memories,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String?,
        role: ChatRole.values.firstWhere((r) => r.name == j['role'], orElse: () => ChatRole.user),
        text: (j['text'] as String?) ?? '',
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? ''),
        stopped: j['stopped'] == true,
        failed: j['failed'] == true,
        context: (j['context'] as String?) ?? '',
        files: ((j['files'] as List?) ?? []).whereType<String>().toList(),
        memories: ((j['memories'] as List?) ?? []).whereType<String>().toList(),
        sources: ((j['sources'] as List?) ?? [])
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry('$k', '$v')))
            .toList(),
      );
}

class Conversation {
  final String id;
  String title;
  bool autoTitle; // false once the person renamed the chat
  final DateTime createdAt;
  DateTime updatedAt;
  String modelId;
  final List<ChatMessage> messages;

  Conversation({
    String? id,
    this.title = '',
    this.autoTitle = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.modelId = '',
    List<ChatMessage>? messages,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'autoTitle': autoTitle,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'modelId': modelId,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? '',
        autoTitle: j['autoTitle'] != false,
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? ''),
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? ''),
        modelId: (j['modelId'] as String?) ?? '',
        messages: ((j['messages'] as List?) ?? [])
            .whereType<Map>()
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}
