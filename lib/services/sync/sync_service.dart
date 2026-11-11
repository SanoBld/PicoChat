// lib/services/sync/sync_service.dart
// Sync between a person's own devices (phone, PC, tablet…), directly on the local network.
//
//  • No server, no account: the devices find each other with a small encrypted UDP
//    beacon and talk over a WebSocket.
//  • Everything that travels is encrypted (AES-256-GCM) with a key made from the group
//    code. A device that does not know the code cannot read a beacon, say hello or send data.
//  • Sync only happens while the devices are connected. Each device sends and accepts only
//    the categories that are ticked on it.
//  • Newest wins: chats by last update, memory as a whole list, settings one by one.
//  • The web version cannot open sockets, so it does not sync.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_models.dart';
import '../chat_store.dart';
import '../memory_store.dart';
import 'sync_prefs.dart';

class SyncDevice {
  final String id;
  String name;
  String address;
  int port;
  bool connected;
  DateTime lastSeen;
  SyncDevice(this.id, this.name, this.address, this.port, this.connected, this.lastSeen);
}

class _Peer {
  final WebSocket ws;
  final bool outgoing;
  final String address;
  String? id;
  String name = '';
  bool ready = false;
  bool closed = false;
  StreamSubscription<dynamic>? sub;
  Future<void> chain = Future<void>.value();
  _Peer(this.ws, this.outgoing, this.address);

  void close() {
    if (closed) return;
    closed = true;
    sub?.cancel();
    try {
      ws.close();
    } catch (_) {}
  }
}

class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const int kPort = 47832; // WebSocket (a free port is used if this one is taken)
  static const int _beaconPort = 47831; // UDP discovery
  static const String _path = '/picochat-sync';
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // ── Settings of this device ────────────────────────────────────────────────
  bool enabled = false;
  String deviceId = '';
  String deviceName = '';
  String secret = ''; // 16 letters/digits, empty = no group yet
  Set<String> cats = {...kAllCats};
  bool live = true; // show answers being written on the other devices
  String? lastError;

  bool get supported => !kIsWeb && !ChatStore.instance.assistMode;
  bool get configured => supported && enabled && secret.isNotEmpty;
  bool get running => _running;
  int? get port => _server?.port;
  int get connectedCount => _peers.values.where((p) => p.ready).length;

  String get formattedSecret {
    if (secret.length != 16) return secret;
    return [for (var i = 0; i < 16; i += 4) secret.substring(i, i + 4)].join('-');
  }

  /// Devices connected now, then devices seen on the network but not connected.
  List<SyncDevice> get devices {
    final out = <SyncDevice>[];
    for (final p in _peers.values) {
      if (!p.ready || p.id == null) continue;
      out.add(SyncDevice(p.id!, p.name, p.address, 0, true, DateTime.now()));
    }
    for (final d in _seen.values) {
      if (out.any((x) => x.id == d.id)) continue;
      out.add(d);
    }
    return out;
  }

  // ── Internals ──────────────────────────────────────────────────────────────
  bool _running = false;
  bool _applying = false; // a setting is being set from another device: do not send it back
  SecretKey? _key;
  HttpServer? _server;
  RawDatagramSocket? _beacon;
  Timer? _beaconTimer;
  Timer? _chatTimer;
  Timer? _liveTimer;
  Conversation? _liveC;
  ChatMessage? _liveM;
  AppLifecycleListener? _life;
  final _aes = AesGcm.with256bits();
  final Map<String, _Peer> _peers = {};
  final Map<String, SyncDevice> _seen = {};
  final Set<String> _dialing = {};
  final Map<String, DateTime> _retryAt = {};
  final Set<String> _dirtyChats = {};
  final Map<String, Timer> _prefTimers = {};
  Map<String, int> _tomb = {}; // deleted chats: id → when (ms)
  Map<String, int> _pts = {}; // settings: key → when changed (ms)
  bool _hooked = false;

  // ── Start / stop ───────────────────────────────────────────────────────────

  Future<void> init() async {
    if (!supported) return;
    final p = await SharedPreferences.getInstance();
    enabled = p.getBool('pc_sync_on') ?? false;
    secret = p.getString('pc_sync_secret') ?? '';
    deviceId = p.getString('pc_sync_id') ?? '';
    if (deviceId.isEmpty) {
      deviceId = newId();
      await p.setString('pc_sync_id', deviceId);
    }
    deviceName = p.getString('pc_sync_name') ?? _defaultName();
    final saved = p.getStringList('pc_sync_cats');
    if (saved != null) cats = saved.where(kAllCats.contains).toSet();
    live = p.getBool('pc_sync_live') ?? true;
    _tomb = _decodeMap(p.getString('pc_sync_tomb'));
    _pts = _decodeMap(p.getString('pc_sync_pts'));
    final month = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    _tomb.removeWhere((_, t) => t < month);
    _hook();
    try {
      _life ??= AppLifecycleListener(onResume: _onResume);
    } catch (_) {}
    if (configured) await start();
  }

  void _hook() {
    if (_hooked) return;
    _hooked = true;
    ChatStore.instance.onLocal = _onLocalChat;
    ChatStore.instance.onDeleted = _onLocalDelete;
    MemoryStore.instance.onLocalChange = _onLocalMemory;
    for (final p in kSyncPrefs) {
      p.notifier.addListener(() => _onLocalPref(p));
    }
  }

  String _defaultName() {
    final os = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iPhone'
            : Platform.isWindows
                ? 'Windows'
                : Platform.isMacOS
                    ? 'Mac'
                    : Platform.isLinux
                        ? 'Linux'
                        : 'PicoChat';
    final tail = deviceId.length >= 3 ? deviceId.substring(deviceId.length - 3).toUpperCase() : '';
    return '$os $tail'.trim();
  }

  static Map<String, int> _decodeMap(String? s) {
    if (s == null || s.isEmpty) return {};
    try {
      return (jsonDecode(s) as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveState() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pc_sync_tomb', jsonEncode(_tomb));
    await p.setString('pc_sync_pts', jsonEncode(_pts));
  }

  Future<SecretKey> _derive(String code) => Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(utf8.encode(code)),
        nonce: utf8.encode('picochat-sync-v1'),
        info: utf8.encode('aes-256-gcm'),
      );

  Future<void> start() async {
    if (!configured || _running) return;
    _running = true;
    lastError = null;
    _key = await _derive(secret);
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, kPort);
    } catch (_) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      } catch (e) {
        lastError = '$e';
      }
    }
    _server?.listen(_onRequest, onError: (_) {});
    try {
      final b = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _beaconPort, reuseAddress: true);
      b.broadcastEnabled = true;
      b.listen(_onBeaconEvent, onError: (_) {});
      _beacon = b;
    } catch (e) {
      lastError ??= '$e'; // manual connection by address still works
    }
    _beaconTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _sendBeacon();
      _dropStale();
    });
    _sendBeacon();
    notifyListeners();
  }

  Future<void> stop() async {
    _running = false;
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _chatTimer?.cancel();
    _liveTimer?.cancel();
    _liveTimer = null;
    for (final p in List.of(_peers.values)) {
      p.close();
    }
    _peers.clear();
    _seen.clear();
    _dialing.clear();
    try {
      _beacon?.close();
    } catch (_) {}
    _beacon = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    notifyListeners();
  }

  void _onResume() {
    if (!configured) return;
    if (!_running) {
      start();
    } else {
      _sendBeacon();
    }
  }

  // ── Choices made by the person ─────────────────────────────────────────────

  /// New group: this device's settings and memory become the starting point of the group.
  Future<String> createGroup() async {
    final r = Random.secure();
    final code = List.generate(16, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
    await stop();
    secret = code;
    enabled = true;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in kSyncPrefs) {
      _pts[p.key] = now;
    }
    if (MemoryStore.instance.modifiedAt == 0) await MemoryStore.instance.applyRemote(MemoryStore.instance.items, now);
    await _savePrefs();
    await _saveState();
    await start();
    return formattedSecret;
  }

  /// Join a group made on another device. False when the code has the wrong shape.
  Future<bool> joinGroup(String input) async {
    final code = input.toUpperCase().replaceAll(RegExp('[^A-Z2-9]'), '');
    if (code.length != 16) return false;
    await stop();
    secret = code;
    enabled = true;
    _pts = {}; // the group's settings win; memory and chats are merged
    await MemoryStore.instance.applyRemote(MemoryStore.instance.items, 0);
    await _savePrefs();
    await _saveState();
    await start();
    return true;
  }

  Future<void> leaveGroup() async {
    await stop();
    secret = '';
    enabled = false;
    await _savePrefs();
    notifyListeners();
  }

  /// Wipes everything about sync (full app reset).
  Future<void> reset() async {
    await stop();
    secret = '';
    enabled = false;
    _tomb = {};
    _pts = {};
    cats = {...kAllCats};
    live = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    if (v && secret.isEmpty) return;
    enabled = v;
    await _savePrefs();
    if (v) {
      await start();
    } else {
      await stop();
    }
  }

  Future<void> setName(String n) async {
    final t = n.trim();
    if (t.isEmpty) return;
    deviceName = t;
    await _savePrefs();
    _sendBeacon();
    notifyListeners();
  }

  Future<void> setCategory(String cat, bool on) async {
    if (on) {
      cats.add(cat);
    } else {
      cats.remove(cat);
    }
    await _savePrefs();
    notifyListeners();
    if (on) resync(); // pull what this device was missing
  }

  Future<void> setLive(bool v) async {
    live = v;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('pc_sync_on', enabled);
    await p.setString('pc_sync_secret', secret);
    await p.setString('pc_sync_name', deviceName);
    await p.setStringList('pc_sync_cats', cats.toList());
    await p.setBool('pc_sync_live', live);
  }

  /// Connects by address when the network does not allow discovery.
  Future<bool> connectTo(String host) async {
    final h = host.trim();
    if (!configured || h.isEmpty) return false;
    if (!_running) await start();
    final parts = h.split(':');
    final port = parts.length == 2 ? int.tryParse(parts[1]) ?? kPort : kPort;
    return _dial('manual:${parts[0]}', parts[0], port);
  }

  /// Sends a fresh summary to every connected device (after a restore or a new category).
  void resync() {
    for (final p in _peers.values) {
      if (p.ready) _sendIndex(p);
    }
  }

  // ── Crypto and frames ──────────────────────────────────────────────────────

  Future<Uint8List> _enc(Object json) async {
    final box = await _aes.encrypt(utf8.encode(jsonEncode(json)), secretKey: _key!);
    return Uint8List.fromList(box.concatenation());
  }

  Future<Map<String, dynamic>?> _dec(List<int> bytes) async {
    final k = _key;
    if (k == null) return null;
    try {
      final box = SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
      final clear = await _aes.decrypt(box, secretKey: k);
      final j = jsonDecode(utf8.decode(clear));
      return j is Map ? Map<String, dynamic>.from(j) : null;
    } catch (_) {
      return null; // wrong key or damaged: ignored
    }
  }

  Future<void> _send(_Peer p, Map<String, dynamic> m) async {
    try {
      if (!p.closed) p.ws.add(await _enc(m));
    } catch (_) {}
  }

  Future<void> _broadcast(Map<String, dynamic> m) async {
    final ready = _peers.values.where((p) => p.ready).toList();
    if (ready.isEmpty || _key == null) return;
    try {
      final bytes = await _enc(m);
      for (final p in ready) {
        if (!p.closed) p.ws.add(bytes);
      }
    } catch (_) {}
  }

  // ── Discovery ──────────────────────────────────────────────────────────────

  Future<void> _sendBeacon() async {
    final b = _beacon;
    final port = _server?.port;
    if (b == null || port == null || _key == null) return;
    try {
      final bytes = await _enc({'id': deviceId, 'name': deviceName, 'port': port});
      final targets = <String>{'255.255.255.255'};
      try {
        for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
          for (final a in ni.addresses) {
            if (a.isLoopback || a.isLinkLocal) continue;
            final o = a.rawAddress;
            if (o.length == 4) targets.add('${o[0]}.${o[1]}.${o[2]}.255');
          }
        }
      } catch (_) {}
      for (final t in targets) {
        try {
          b.send(bytes, InternetAddress(t), _beaconPort);
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _onBeaconEvent(RawSocketEvent e) {
    if (e != RawSocketEvent.read) return;
    Datagram? d;
    while ((d = _beacon?.receive()) != null) {
      _handleBeacon(d!.data, d.address);
    }
  }

  Future<void> _handleBeacon(Uint8List data, InternetAddress from) async {
    final j = await _dec(data);
    if (j == null) return;
    final id = '${j['id']}';
    if (id.isEmpty || id == deviceId) return;
    final port = (j['port'] as num?)?.toInt() ?? kPort;
    final name = '${j['name']}';
    final known = _seen[id];
    final changed = known == null || known.name != name || known.address != from.address;
    _seen[id] = SyncDevice(id, name, from.address, port, _peers[id]?.ready == true, DateTime.now());
    if (changed) notifyListeners();
    if (_peers.containsKey(id) || _dialing.contains(id)) return;
    final retry = _retryAt[id];
    if (retry != null && DateTime.now().isBefore(retry)) return;
    _dial(id, from.address, port);
  }

  void _dropStale() {
    final limit = DateTime.now().subtract(const Duration(seconds: 15));
    final before = _seen.length;
    _seen.removeWhere((id, d) => d.lastSeen.isBefore(limit));
    if (_seen.length != before) notifyListeners();
  }

  // ── Connections ────────────────────────────────────────────────────────────

  Future<bool> _dial(String key, String host, int port) async {
    if (!_dialing.add(key)) return false;
    try {
      final ws = await WebSocket.connect('ws://$host:$port$_path').timeout(const Duration(seconds: 5));
      _attach(ws, outgoing: true, address: host);
      return true;
    } catch (_) {
      _retryAt[key] = DateTime.now().add(const Duration(seconds: 6));
      return false;
    } finally {
      _dialing.remove(key);
    }
  }

  Future<void> _onRequest(HttpRequest req) async {
    try {
      if (req.uri.path == _path && WebSocketTransformer.isUpgradeRequest(req)) {
        final addr = req.connectionInfo?.remoteAddress.address ?? '';
        final ws = await WebSocketTransformer.upgrade(req);
        _attach(ws, outgoing: false, address: addr);
      } else {
        req.response
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    } catch (_) {}
  }

  void _attach(WebSocket ws, {required bool outgoing, required String address}) {
    ws.pingInterval = const Duration(seconds: 10); // a lost connection is noticed and closed
    final peer = _Peer(ws, outgoing, address);
    peer.sub = ws.listen(
      (data) {
        // One frame at a time per device, in order.
        peer.chain = peer.chain.then((_) => _onData(peer, data)).catchError((_) {});
      },
      onDone: () => _closed(peer),
      onError: (_) => _closed(peer),
      cancelOnError: true,
    );
    _send(peer, {'t': 'hello', 'id': deviceId, 'name': deviceName});
  }

  void _closed(_Peer p) {
    final id = p.id;
    p.close();
    if (id != null && _peers[id] == p) {
      _peers.remove(id);
      _seen[id]?.connected = false;
      _retryAt[id] = DateTime.now().add(const Duration(seconds: 3));
      notifyListeners();
    }
  }

  Future<void> _onData(_Peer p, dynamic data) async {
    if (data is! List<int>) return;
    final m = await _dec(data);
    if (m == null) {
      p.close(); // not the same code: this is not one of our devices
      return;
    }
    final t = m['t'];
    if (t == 'hello') return _onHello(p, m);
    if (!p.ready) return;
    switch (t) {
      case 'index':
        return _onIndex(p, m);
      case 'want':
        return _onWant(p, m);
      case 'chat':
        return _onChat(m);
      case 'live':
        return _onLive(m);
      case 'del':
        return _onDel(m);
      case 'mem':
        return _onMem(m);
      case 'pref':
        return _onPref(m);
    }
  }

  void _onHello(_Peer p, Map<String, dynamic> m) {
    final id = '${m['id']}';
    if (id.isEmpty || id == deviceId) {
      p.close();
      return;
    }
    p.id = id;
    p.name = '${m['name']}';
    // Two connections between the same pair: keep the one started by the device with the smaller id.
    final preferred = deviceId.compareTo(id) < 0 ? deviceId : id;
    final initiator = p.outgoing ? deviceId : id;
    final old = _peers[id];
    if (old != null && old != p) {
      if (initiator == preferred) {
        _peers.remove(id);
        old.close();
      } else {
        p.close();
        return;
      }
    }
    _peers[id] = p;
    p.ready = true;
    _seen[id] = SyncDevice(id, p.name, p.address, 0, true, DateTime.now());
    notifyListeners();
    _sendIndex(p);
  }

  // ── Catch-up when two devices meet ─────────────────────────────────────────

  void _sendIndex(_Peer p) {
    final idx = <String, dynamic>{'t': 'index', 'cats': cats.toList()};
    if (cats.contains(kCatChats)) {
      idx['chats'] = {
        for (final c in ChatStore.instance.chats)
          if (c.messages.isNotEmpty) c.id: c.updatedAt.millisecondsSinceEpoch
      };
      idx['tomb'] = _tomb;
    }
    if (cats.contains(kCatMemory)) {
      idx['mem'] = {'facts': MemoryStore.instance.items, 'ts': MemoryStore.instance.modifiedAt};
    }
    final prefs = <String, dynamic>{};
    for (final sp in kSyncPrefs) {
      final ts = _pts[sp.key];
      if (cats.contains(sp.cat) && ts != null && ts > 0) prefs[sp.key] = {'v': sp.read(), 'ts': ts};
    }
    idx['prefs'] = prefs;
    _send(p, idx);
  }

  Future<void> _onIndex(_Peer p, Map<String, dynamic> m) async {
    final store = ChatStore.instance;
    // Chats
    if (cats.contains(kCatChats) && m['chats'] is Map) {
      final tombs = m['tomb'];
      if (tombs is Map) {
        for (final e in tombs.entries) {
          final ts = (e.value as num).toInt();
          if (ts > (_tomb['${e.key}'] ?? 0)) _tomb['${e.key}'] = ts;
          store.removeRemote('${e.key}', DateTime.fromMillisecondsSinceEpoch(ts));
        }
      }
      final local = {for (final c in store.chats) c.id: c.updatedAt.millisecondsSinceEpoch};
      final want = <String>[];
      for (final e in (m['chats'] as Map).entries) {
        final id = '${e.key}';
        final rts = (e.value as num).toInt();
        if ((_tomb[id] ?? 0) >= rts) continue; // deleted here after that version
        if (rts > (local[id] ?? 0)) want.add(id);
      }
      if (want.isNotEmpty) await _send(p, {'t': 'want', 'ids': want});
    }
    // Memory
    final mem = m['mem'];
    if (cats.contains(kCatMemory) && mem is Map) {
      await _takeMemory(mem, p);
    }
    // Settings
    final prefs = m['prefs'];
    if (prefs is Map) {
      for (final e in prefs.entries) {
        final sp = syncPrefByKey('${e.key}');
        final v = e.value;
        if (sp == null || !cats.contains(sp.cat) || v is! Map || v['v'] == null) continue;
        await _takePref(sp, v['v'] as Object, (v['ts'] as num).toInt());
      }
    }
    await _saveState();
  }

  Future<void> _takeMemory(Map mem, _Peer from) async {
    final rts = (mem['ts'] as num?)?.toInt() ?? 0;
    final facts = ((mem['facts'] as List?) ?? []).whereType<String>().toList();
    final store = MemoryStore.instance;
    if (rts > store.modifiedAt) {
      if (store.modifiedAt == 0 && store.items.isNotEmpty) {
        // First meeting: keep what this device already knew, then share the union.
        final merged = [...store.items];
        for (final f in facts) {
          if (!merged.any((e) => e.toLowerCase() == f.toLowerCase())) merged.add(f);
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        await store.applyRemote(merged, now > rts ? now : rts + 1);
        await _send(from, {'t': 'mem', 'facts': store.items, 'ts': store.modifiedAt});
      } else {
        await store.applyRemote(facts, rts);
      }
    }
  }

  Future<void> _takePref(SyncPref sp, Object value, int ts) async {
    if (ts <= (_pts[sp.key] ?? 0)) return;
    _pts[sp.key] = ts;
    _applying = true;
    try {
      sp.write(value);
    } catch (_) {
      _applying = false;
      return;
    }
    _applying = false;
    final p = await SharedPreferences.getInstance();
    final v = sp.read();
    if (v is bool) {
      await p.setBool(sp.key, v);
    } else if (v is int) {
      await p.setInt(sp.key, v);
    } else if (v is double) {
      await p.setDouble(sp.key, v);
    } else if (v is String) {
      await p.setString(sp.key, v);
    }
  }

  Future<void> _onWant(_Peer p, Map<String, dynamic> m) async {
    if (!cats.contains(kCatChats)) return;
    for (final id in ((m['ids'] as List?) ?? []).whereType<String>()) {
      for (final c in ChatStore.instance.chats) {
        if (c.id == id && c.messages.isNotEmpty) {
          await _send(p, {'t': 'chat', 'c': c.toJson()});
          break;
        }
      }
    }
  }

  // ── Frames received during the session ─────────────────────────────────────

  Future<void> _onChat(Map<String, dynamic> m) async {
    if (!cats.contains(kCatChats) || m['c'] is! Map) return;
    final c = Conversation.fromJson(Map<String, dynamic>.from(m['c'] as Map));
    if ((_tomb[c.id] ?? 0) >= c.updatedAt.millisecondsSinceEpoch) return;
    ChatStore.instance.applyRemoteChat(c);
  }

  Future<void> _onLive(Map<String, dynamic> m) async {
    if (!cats.contains(kCatChats) || !live || m['c'] is! Map || m['m'] is! Map) return;
    final meta = Map<String, dynamic>.from(m['c'] as Map);
    if (_tomb.containsKey('${meta['id']}')) return;
    ChatStore.instance.applyRemoteMessage(meta, ChatMessage.fromJson(Map<String, dynamic>.from(m['m'] as Map)));
  }

  Future<void> _onDel(Map<String, dynamic> m) async {
    if (!cats.contains(kCatChats)) return;
    final id = '${m['id']}';
    final ts = (m['ts'] as num?)?.toInt() ?? 0;
    if (ts > (_tomb[id] ?? 0)) _tomb[id] = ts;
    ChatStore.instance.removeRemote(id, DateTime.fromMillisecondsSinceEpoch(ts));
    await _saveState();
  }

  Future<void> _onMem(Map<String, dynamic> m) async {
    if (!cats.contains(kCatMemory)) return;
    final rts = (m['ts'] as num?)?.toInt() ?? 0;
    if (rts <= MemoryStore.instance.modifiedAt) return;
    await MemoryStore.instance
        .applyRemote(((m['facts'] as List?) ?? []).whereType<String>().toList(), rts);
  }

  Future<void> _onPref(Map<String, dynamic> m) async {
    final sp = syncPrefByKey('${m['k']}');
    if (sp == null || !cats.contains(sp.cat) || m['v'] == null) return;
    await _takePref(sp, m['v'] as Object, (m['ts'] as num?)?.toInt() ?? 0);
    await _saveState();
  }

  // ── Changes made on this device ────────────────────────────────────────────

  Map<String, dynamic> _meta(Conversation c) => {
        'id': c.id,
        'title': c.title,
        'autoTitle': c.autoTitle,
        'createdAt': c.createdAt.toIso8601String(),
        'updatedAt': c.updatedAt.toIso8601String(),
        'modelId': c.modelId,
      };

  void _onLocalChat(Conversation c, ChatMessage? m) {
    if (!configured || !cats.contains(kCatChats) || c.messages.isEmpty) return;
    if (connectedCount == 0) return; // the summary sent at the next meeting covers it
    _dirtyChats.add(c.id);
    _chatTimer?.cancel();
    _chatTimer = Timer(const Duration(milliseconds: 1200), _flushChats);
    if (live && m != null) {
      _liveC = c;
      _liveM = m;
      _liveTimer ??= Timer(const Duration(milliseconds: 140), () {
        _liveTimer = null;
        final lc = _liveC, lm = _liveM;
        _liveC = null;
        _liveM = null;
        if (lc != null && lm != null) _broadcast({'t': 'live', 'c': _meta(lc), 'm': lm.toJson()});
      });
    }
  }

  Future<void> _flushChats() async {
    final ids = List.of(_dirtyChats);
    _dirtyChats.clear();
    for (final id in ids) {
      for (final c in ChatStore.instance.chats) {
        if (c.id == id && c.messages.isNotEmpty) {
          await _broadcast({'t': 'chat', 'c': c.toJson()});
          break;
        }
      }
    }
  }

  void _onLocalDelete(String id, DateTime at) {
    if (!configured || !cats.contains(kCatChats)) return;
    final ts = at.millisecondsSinceEpoch;
    _tomb[id] = ts;
    _saveState();
    _broadcast({'t': 'del', 'id': id, 'ts': ts});
  }

  void _onLocalMemory() {
    if (!configured || !cats.contains(kCatMemory)) return;
    _broadcast({'t': 'mem', 'facts': MemoryStore.instance.items, 'ts': MemoryStore.instance.modifiedAt});
  }

  void _onLocalPref(SyncPref sp) {
    if (_applying || !configured || !cats.contains(sp.cat)) return;
    _prefTimers[sp.key]?.cancel();
    // Sliders fire many times: send the last value once.
    _prefTimers[sp.key] = Timer(const Duration(milliseconds: 400), () {
      _prefTimers.remove(sp.key);
      final ts = DateTime.now().millisecondsSinceEpoch;
      _pts[sp.key] = ts;
      _saveState();
      _broadcast({'t': 'pref', 'k': sp.key, 'v': sp.read(), 'ts': ts});
    });
  }
}
