// lib/services/model_manager.dart
// Model files on disk: installed list (models/registry.json), resumable
// downloads from Hugging Face (.part file + HTTP Range), import of a local
// .gguf file. The HF token is only sent to the Hugging Face host itself,
// never to the CDN a download redirects to.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../models/model_models.dart';
import 'hf_service.dart';

enum DownloadStatus { queued, downloading, paused, failed }

class DownloadTask {
  final String id; // "<repo>/<fileName>"
  final String repo;
  final String fileName;
  final String url;
  int received = 0;
  int total; // 0 = unknown
  DownloadStatus status = DownloadStatus.queued;

  /// HfException kind, or 'incomplete' / 'invalid'.
  String? errorKind;
  double speedBps = 0;

  http.Client? _client;
  String? _stop; // null | 'pause' | 'cancel'

  DownloadTask({
    required this.id,
    required this.repo,
    required this.fileName,
    required this.url,
    this.total = 0,
  });

  double get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : 0;
  String get quant => quantOf(fileName);
  bool get isActive => status == DownloadStatus.downloading || status == DownloadStatus.queued;
}

class ModelManager extends ChangeNotifier {
  ModelManager._();
  static final ModelManager instance = ModelManager._();

  Directory? _dir;
  final List<InstalledModel> _installed = [];
  final Map<String, DownloadTask> _tasks = {};
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  List<InstalledModel> get installed => List.unmodifiable(_installed);
  List<DownloadTask> get tasks => _tasks.values.toList();
  Directory? get directory => _dir;

  /// Selected model, or null when none is installed.
  InstalledModel? get active => byId(activeModelNotifier.value);

  InstalledModel? byId(String id) {
    for (final m in _installed) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool isInstalled(String id) => byId(id) != null;

  // ── Start-up ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (kIsWeb) return; // models need a real filesystem
    final base = await getApplicationSupportDirectory();
    _dir = Directory('${base.path}${Platform.pathSeparator}models');
    await _dir!.create(recursive: true);
    await _loadRegistry();
    if (active == null) await _setActive(_installed.isEmpty ? '' : _installed.first.id);
  }

  File get _registryFile => File('${_dir!.path}${Platform.pathSeparator}registry.json');

  Future<void> _loadRegistry() async {
    try {
      if (!await _registryFile.exists()) return;
      final data = jsonDecode(await _registryFile.readAsString());
      if (data is! Map) return;
      for (final e in ((data['installed'] as List?) ?? []).whereType<Map>()) {
        final m = InstalledModel.fromJson(Map<String, dynamic>.from(e));
        if (await File(m.path).exists()) _installed.add(m); // drop dead entries
      }
      // Unfinished downloads come back paused: one tap resumes them.
      for (final e in ((data['partials'] as List?) ?? []).whereType<Map>()) {
        final repo = e['repo'] as String;
        final file = e['fileName'] as String;
        final id = '$repo/$file';
        final part = File(_partPath(id));
        if (!await part.exists()) continue;
        _tasks[id] = DownloadTask(
          id: id,
          repo: repo,
          fileName: file,
          url: HfService.downloadUrl(repo, file),
          total: (e['total'] as num?)?.toInt() ?? 0,
        )
          ..received = await part.length()
          ..status = DownloadStatus.paused;
      }
    } catch (e) {
      debugPrint('ModelManager registry load failed: $e');
    }
  }

  Future<void> _saveRegistry() async {
    if (_dir == null) return;
    try {
      final json = jsonEncode({
        'installed': _installed.map((m) => m.toJson()).toList(),
        'partials': _tasks.values
            .where((t) => t.status != DownloadStatus.failed)
            .map((t) => {'repo': t.repo, 'fileName': t.fileName, 'total': t.total})
            .toList(),
      });
      await _registryFile.writeAsString(json, flush: true);
    } catch (e) {
      debugPrint('ModelManager registry save failed: $e');
    }
  }

  // ── Paths ─────────────────────────────────────────────────────────────────

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  String _finalPath(String id) => '${_dir!.path}${Platform.pathSeparator}${_safe(id)}';
  String _partPath(String id) => '${_finalPath(id)}.part';

  // ── Active model ──────────────────────────────────────────────────────────

  Future<void> setActive(String id) => _setActive(id);

  Future<void> _setActive(String id) async {
    activeModelNotifier.value = id;
    final p = await SharedPreferences.getInstance();
    await p.setString('pc_active_model', id);
    notifyListeners();
  }

  // ── Downloads ─────────────────────────────────────────────────────────────

  /// Starts (or resumes) one file. [size] = expected bytes when known.
  Future<void> download(String repo, String fileName, {int size = 0}) async {
    if (_dir == null) return;
    final id = '$repo/$fileName';
    if (isInstalled(id)) return;
    var task = _tasks[id];
    if (task != null && task.status == DownloadStatus.downloading) return;
    task ??= DownloadTask(
      id: id,
      repo: repo,
      fileName: fileName,
      url: HfService.downloadUrl(repo, fileName),
      total: size,
    );
    if (size > 0) task.total = size;
    _tasks[id] = task;
    task.errorKind = null;
    task.status = DownloadStatus.queued;
    notifyListeners();
    unawaited(_run(task));
  }

  // ── Vision projector (mmproj) ─────────────────────────────────────────────
  // Saved as "<repo>/mmproj.gguf". It is not a chat model: it is never listed.

  static const _projName = 'mmproj.gguf';

  /// Path of the projector saved for [m]'s repo, or null.
  String? projectorFor(InstalledModel m) {
    if (_dir == null || m.isLocalImport) return null;
    final f = File(_finalPath('${m.repo}/$_projName'));
    return f.existsSync() ? f.path : null;
  }

  /// Downloads the vision projector of [repo]. Throws [HfException].
  Future<void> downloadProjector(String repo) async {
    if (_dir == null) return;
    final id = '$repo/$_projName';
    if (File(_finalPath(id)).existsSync() || _tasks[id]?.status == DownloadStatus.downloading) return;
    final pick = HfService.pickProjector(await HfService.listProjectors(repo));
    if (pick == null) throw const HfException('notFound');
    final task = DownloadTask(
      id: id,
      repo: repo,
      fileName: _projName,
      url: HfService.downloadUrl(repo, pick.path),
      total: pick.size,
    );
    _tasks[id] = task;
    notifyListeners();
    unawaited(_run(task));
  }

  /// Picks the best default .gguf file of [repo] and downloads it.
  /// Throws [HfException] when Hugging Face is unreachable or has no .gguf.
  Future<void> downloadRecommended(String repo) async {
    final files = await HfService.listGgufFiles(repo);
    final pick = HfService.pickDefault(files);
    if (pick == null) throw const HfException('notFound');
    await download(repo, pick.path, size: pick.size);
  }

  void pause(String id) {
    final t = _tasks[id];
    if (t == null || !t.isActive) return;
    t._stop = 'pause';
    t._client?.close(); // aborts the connection, _run notices and stops
    if (t.status == DownloadStatus.queued) {
      t.status = DownloadStatus.paused;
      _saveRegistry();
      notifyListeners();
    }
  }

  void resume(String id) {
    final t = _tasks[id];
    if (t == null) return;
    unawaited(download(t.repo, t.fileName, size: t.total));
  }

  Future<void> cancel(String id) async {
    final t = _tasks[id];
    if (t == null) return;
    if (t.status == DownloadStatus.downloading) {
      t._stop = 'cancel';
      t._client?.close();
      return; // _run removes the task and the .part file
    }
    _tasks.remove(id);
    await _deleteQuietly(File(_partPath(id)));
    await _saveRegistry();
    notifyListeners();
  }

  Future<void> _run(DownloadTask t) async {
    t._stop = null;
    t.status = DownloadStatus.downloading;
    t.speedBps = 0;
    notifyListeners();

    final part = File(_partPath(t.id));
    final client = http.Client();
    t._client = client;
    RandomAccessFile? raf;
    try {
      var offset = await part.exists() ? await part.length() : 0;
      final hfHost = Uri.parse(HfService.base).host;

      // Follow redirects by hand so the token never leaves the HF host.
      var uri = Uri.parse(t.url);
      http.StreamedResponse? resp;
      for (var hop = 0; hop < 6; hop++) {
        final req = http.Request('GET', uri)..followRedirects = false;
        req.headers['User-Agent'] = 'PicoChat';
        if (offset > 0) req.headers['Range'] = 'bytes=$offset-';
        final token = hfTokenNotifier.value.trim();
        if (token.isNotEmpty && uri.host == hfHost) {
          req.headers['Authorization'] = 'Bearer $token';
        }
        resp = await client.send(req);
        if (resp.isRedirect) {
          final loc = resp.headers['location'];
          await resp.stream.drain<void>();
          if (loc == null) throw const HfException('server');
          uri = uri.resolve(loc);
          resp = null;
          continue;
        }
        break;
      }
      if (resp == null) throw const HfException('server');

      final code = resp.statusCode;
      if (code == 416) {
        await resp.stream.drain<void>();
        // The partial file already has every byte: just finish it.
        if (t.total > 0 && offset == t.total) {
          await _finish(t, part);
          return;
        }
        // Otherwise it doesn't match the remote file: drop it.
        await _deleteQuietly(part);
        t.received = 0;
        throw const HfException('server', 416);
      }
      if (code == 401 || code == 403) throw HfException('auth', code);
      if (code == 404) throw HfException('notFound', code);
      if (code != 200 && code != 206) throw HfException('server', code);

      final resumed = code == 206 && offset > 0;
      if (!resumed) offset = 0; // server sent the whole file again
      final len = resp.contentLength ?? 0;
      if (len > 0) t.total = offset + len;
      t.received = offset;

      raf = await part.open(mode: resumed ? FileMode.append : FileMode.write);
      var lastBytes = t.received;
      var lastTime = DateTime.now();
      await for (final chunk in resp.stream) {
        if (t._stop != null) break;
        await raf.writeFrom(chunk);
        t.received += chunk.length;

        final now = DateTime.now();
        final dt = now.difference(lastTime).inMilliseconds;
        if (dt >= 800) {
          final inst = (t.received - lastBytes) * 1000 / dt;
          t.speedBps = t.speedBps == 0 ? inst : t.speedBps * 0.6 + inst * 0.4;
          lastBytes = t.received;
          lastTime = now;
        }
        _notifyThrottled();
      }
      await raf.close();
      raf = null;

      if (t._stop == 'cancel') {
        await _deleteQuietly(part);
        _tasks.remove(t.id);
      } else if (t._stop == 'pause') {
        t.status = DownloadStatus.paused;
      } else {
        await _finish(t, part);
      }
    } catch (e) {
      try {
        await raf?.close();
      } catch (_) {}
      if (t._stop == 'cancel') {
        await _deleteQuietly(part);
        _tasks.remove(t.id);
      } else if (t._stop == 'pause') {
        t.status = DownloadStatus.paused; // client.close() aborted the stream
      } else {
        t.status = DownloadStatus.failed;
        t.errorKind = e is HfException
            ? e.kind
            : (e is SocketException || e is http.ClientException ? 'offline' : 'server');
        debugPrint('Download failed (${t.id}): $e');
      }
    } finally {
      client.close();
      t._client = null;
      await _saveRegistry();
      notifyListeners();
    }
  }

  Future<void> _finish(DownloadTask t, File part) async {
    final size = await part.length();
    if (t.total > 0 && size != t.total) {
      t.status = DownloadStatus.failed;
      t.errorKind = 'incomplete';
      return;
    }
    // A real GGUF file starts with the 4 bytes "GGUF".
    final head = await _readHead(part, 4);
    if (utf8.decode(head, allowMalformed: true) != 'GGUF') {
      t.status = DownloadStatus.failed;
      t.errorKind = 'invalid';
      await _deleteQuietly(part);
      t.received = 0;
      return;
    }
    final dest = _finalPath(t.id);
    await part.rename(dest);
    if (t.fileName == _projName) {
      _tasks.remove(t.id); // projector: keep the file only
      return;
    }
    _installed.removeWhere((m) => m.id == t.id);
    _installed.add(InstalledModel(
      id: t.id,
      repo: t.repo,
      fileName: t.fileName,
      path: dest,
      sizeBytes: size,
      addedAt: DateTime.now(),
    ));
    _tasks.remove(t.id);
    if (active == null) await _setActive(t.id); // first model becomes active
  }

  // ── Import / delete ───────────────────────────────────────────────────────

  /// Copies a .gguf file the person already has into the models folder.
  /// Returns null when the file isn't a GGUF.
  Future<InstalledModel?> importFile(String sourcePath) async {
    if (_dir == null) return null;
    final name = sourcePath.split(RegExp(r'[\\/]')).last;
    if (!name.toLowerCase().endsWith('.gguf')) return null;
    final src = File(sourcePath);
    final head = await _readHead(src, 4);
    if (utf8.decode(head, allowMalformed: true) != 'GGUF') return null;

    final id = 'local/$name';
    final dest = _finalPath(id);
    await src.copy(dest);
    _installed.removeWhere((m) => m.id == id);
    final m = InstalledModel(
      id: id,
      repo: 'local',
      fileName: name,
      path: dest,
      sizeBytes: await File(dest).length(),
      addedAt: DateTime.now(),
    );
    _installed.add(m);
    if (active == null) await _setActive(id);
    await _saveRegistry();
    notifyListeners();
    return m;
  }

  Future<void> delete(String id) async {
    final m = byId(id);
    if (m == null) return;
    await _deleteQuietly(File(m.path));
    _installed.remove(m);
    // Remove the projector when no other model of this repo is left.
    if (!_installed.any((o) => o.repo == m.repo)) {
      await _deleteQuietly(File(_finalPath('${m.repo}/$_projName')));
    }
    if (activeModelNotifier.value == id) {
      await _setActive(_installed.isEmpty ? '' : _installed.first.id);
    }
    await _saveRegistry();
    notifyListeners();
  }

  /// Removes every unfinished download (.part files).
  Future<void> clearPartials() async {
    for (final t in _tasks.values.toList()) {
      if (t.isActive) {
        t._stop = 'cancel';
        t._client?.close();
      }
    }
    _tasks.removeWhere((_, t) => t.status != DownloadStatus.downloading);
    if (_dir != null) {
      await for (final e in _dir!.list()) {
        if (e is File && e.path.endsWith('.part')) await _deleteQuietly(e);
      }
    }
    await _saveRegistry();
    notifyListeners();
  }

  /// Bytes used by installed models and partial downloads.
  Future<int> sizeOnDisk() async {
    if (_dir == null) return 0;
    var total = 0;
    try {
      await for (final e in _dir!.list()) {
        if (e is File && !e.path.endsWith('registry.json')) total += await e.length();
      }
    } catch (_) {}
    return total;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<int>> _readHead(File f, int n) async {
    final raf = await f.open();
    try {
      return await raf.read(n);
    } finally {
      await raf.close();
    }
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  void _notifyThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds < 250) return;
    _lastNotify = now;
    notifyListeners();
  }
}
