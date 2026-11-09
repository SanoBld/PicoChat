// lib/services/cloud/cloud_store.dart
// Cloud AI accounts (Claude, Gemini, ChatGPT, OpenAI-compatible) and the
// models added to each one. Saved in SharedPreferences ('pc_cloud_accounts'),
// like the Hugging Face token. API keys are never exported by Backup and are
// only sent to the account's own server.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_state.dart';
import '../../models/chat_models.dart' show newId;
import 'cloud_protocol.dart';

const String kCloudPrefix = 'cloud:';

class CloudAccount {
  final String id;
  CloudProvider provider;
  String name;
  String apiKey;
  String baseUrl; // '' = the provider's official address
  List<CloudModelInfo> models;

  CloudAccount({
    String? id,
    required this.provider,
    String? name,
    this.apiKey = '',
    this.baseUrl = '',
    List<CloudModelInfo>? models,
  })  : id = id ?? newId(),
        name = name ?? provider.shortName,
        models = models ?? [];

  String get effectiveBaseUrl => baseUrl.trim().isEmpty ? provider.defaultBaseUrl : baseUrl.trim();

  /// A key (when the service needs one) and an address are set.
  bool get ready => (apiKey.trim().isNotEmpty || !provider.keyRequired) && effectiveBaseUrl.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.name,
        'name': name,
        'key': apiKey,
        'url': baseUrl,
        'models': models.map((m) => m.toJson()).toList(),
      };

  factory CloudAccount.fromJson(Map<String, dynamic> j) => CloudAccount(
        id: j['id'] as String?,
        provider: cloudProviderFromId(j['provider'] as String?),
        name: j['name'] as String?,
        apiKey: (j['key'] as String?) ?? '',
        baseUrl: (j['url'] as String?) ?? '',
        models: ((j['models'] as List?) ?? [])
            .whereType<Map>()
            .map((m) => CloudModelInfo.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// One selectable cloud model = an account + one of its models.
class CloudModel {
  final CloudAccount account;
  final CloudModelInfo info;
  const CloudModel(this.account, this.info);

  /// Stored in 'pc_active_cloud' and in Conversation.modelId.
  String get id => '$kCloudPrefix${account.id}/${info.id}';
  String get displayName => info.name;
  CloudProvider get provider => account.provider;
  String get subtitle => account.name == account.provider.shortName
      ? account.provider.shortName
      : '${account.provider.shortName} · ${account.name}';
}

class CloudStore extends ChangeNotifier {
  CloudStore._();
  static final CloudStore instance = CloudStore._();

  final List<CloudAccount> _accounts = [];
  List<CloudAccount> get accounts => List.unmodifiable(_accounts);

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _accounts.clear();
    try {
      final raw = p.getString('pc_cloud_accounts');
      if (raw != null && raw.isNotEmpty) {
        for (final j in (jsonDecode(raw) as List).whereType<Map>()) {
          _accounts.add(CloudAccount.fromJson(Map<String, dynamic>.from(j)));
        }
      }
    } catch (e) {
      debugPrint('Cloud accounts unreadable: $e');
    }
  }

  CloudAccount? accountById(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Every model of every usable account.
  List<CloudModel> get models => [
        for (final a in _accounts)
          if (a.ready)
            for (final m in a.models) CloudModel(a, m),
      ];

  CloudModel? byId(String id) {
    if (!id.startsWith(kCloudPrefix)) return null;
    final rest = id.substring(kCloudPrefix.length);
    final slash = rest.indexOf('/');
    if (slash <= 0) return null;
    final acc = accountById(rest.substring(0, slash));
    if (acc == null || !acc.ready) return null;
    final modelId = rest.substring(slash + 1);
    for (final m in acc.models) {
      if (m.id == modelId) return CloudModel(acc, m);
    }
    return null;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pc_cloud_accounts', jsonEncode(_accounts.map((a) => a.toJson()).toList()));
    notifyListeners();
  }

  Future<void> add(CloudAccount a) async {
    _accounts.add(a);
    await _save();
  }

  /// Call after changing fields of an account.
  Future<void> update(CloudAccount a) async {
    // A model that disappeared from the account can no longer be active.
    if (activeCloudNotifier.value.startsWith('$kCloudPrefix${a.id}/') && byId(activeCloudNotifier.value) == null) {
      await clearActive();
    }
    await _save();
  }

  Future<void> remove(CloudAccount a) async {
    _accounts.removeWhere((x) => x.id == a.id);
    if (activeCloudNotifier.value.startsWith('$kCloudPrefix${a.id}/')) await clearActive();
    await _save();
  }

  /// Uses this cloud model for the chats (the local model choice is kept).
  Future<void> select(String id) async {
    activeCloudNotifier.value = id;
    final p = await SharedPreferences.getInstance();
    await p.setString('pc_active_cloud', id);
    notifyListeners();
  }

  /// Back to the local models.
  Future<void> clearActive() async {
    if (activeCloudNotifier.value.isEmpty) return;
    activeCloudNotifier.value = '';
    final p = await SharedPreferences.getInstance();
    await p.setString('pc_active_cloud', '');
    notifyListeners();
  }

  /// Used by "reset everything" (preferences are already wiped).
  void resetMemory() {
    _accounts.clear();
    cloudEnabledNotifier.value = false;
    activeCloudNotifier.value = '';
    notifyListeners();
  }
}
