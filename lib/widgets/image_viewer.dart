// lib/widgets/image_viewer.dart
// Pictures in answers: copy, download, show the source, and a full-screen
// viewer with pinch / wheel zoom, double-tap zoom and pan (nothing is cropped).

import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, LogicalKeyboardKey;
import 'package:http/http.dart' as http;
import 'package:pasteboard/pasteboard.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../theme/m3_motion.dart';
import 'skeleton.dart' show M3Spinner;

class ImageTools {
  ImageTools._();

  static Future<Uint8List?> _bytes(String url) async {
    try {
      final r = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'PicoChat/0.1 (private chat app)'})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  /// Host of the picture, without "www." (shown as the source).
  static String host(String url) {
    final h = Uri.tryParse(url)?.host ?? '';
    return h.startsWith('www.') ? h.substring(4) : h;
  }

  static String _ext(Uint8List b, String url) {
    if (b.length > 4) {
      if (b[0] == 0x89 && b[1] == 0x50) return 'png';
      if (b[0] == 0xFF && b[1] == 0xD8) return 'jpg';
      if (b[0] == 0x47 && b[1] == 0x49) return 'gif';
      if (b[0] == 0x52 && b[1] == 0x49) return 'webp';
    }
    final m = RegExp(r'\.(png|jpe?g|gif|webp)(\?|$)', caseSensitive: false).firstMatch(url);
    return (m?.group(1) ?? 'jpg').toLowerCase();
  }

  /// Copies the picture itself when the platform allows it, else its link.
  static Future<void> copy(BuildContext context, String url) async {
    final b = await _bytes(url);
    var asImage = false;
    if (b != null && !kIsWeb) {
      try {
        await Pasteboard.writeImage(b);
        asImage = true;
      } catch (_) {}
    }
    if (!asImage) await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) _toast(context, tr(asImage ? 'img_copied' : 'img_copied_link'));
  }

  static Future<void> save(BuildContext context, String url) async {
    final b = await _bytes(url);
    if (b == null) {
      if (context.mounted) _toast(context, tr('img_failed'));
      return;
    }
    final path = await FilePicker.platform.saveFile(fileName: 'pico-image.${_ext(b, url)}', bytes: b);
    if (path == null) return;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await File(path).writeAsBytes(b);
    }
    if (context.mounted) _toast(context, tr('img_saved'));
  }

  static void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));

  static Future<void> openSource(String url) async {
    final u = Uri.tryParse(url);
    if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  static Route<void> route(String url, {String source = '', String alt = ''}) => PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => PcImageViewer(url: url, source: source, alt: alt),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(CurvedAnimation(parent: anim, curve: M3Motion.emphasizedDecelerate)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      );
}

class PcImageViewer extends StatefulWidget {
  const PcImageViewer({super.key, required this.url, this.source = '', this.alt = ''});
  final String url;
  final String source;
  final String alt;

  @override
  State<PcImageViewer> createState() => _PcImageViewerState();
}

class _PcImageViewerState extends State<PcImageViewer> with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  Animation<Matrix4>? _a;
  Offset _tap = Offset.zero;
  bool _bars = true;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final a = _a;
      if (a != null) _tc.value = a.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  // Double tap / double click: zoom in where you tapped, or back to fit.
  void _toggleZoom() {
    final zoomed = _tc.value.getMaxScaleOnAxis() > 1.05;
    const s = 2.5;
    final end = zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..translate(-_tap.dx * (s - 1), -_tap.dy * (s - 1))
          ..scale(s));
    _a = Matrix4Tween(begin: _tc.value, end: end)
        .animate(CurvedAnimation(parent: _anim, curve: M3Motion.emphasizedDecelerate));
    _anim.forward(from: 0);
  }

  Widget _btn(IconData icon, String tip, VoidCallback onTap) => IconButton.filled(
        tooltip: tip,
        icon: Icon(icon, size: 22),
        style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
        onPressed: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final src = widget.source.isNotEmpty ? widget.source : ImageTools.host(widget.url);
    return CallbackShortcuts(
      bindings: {SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.94),
          body: Stack(children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _bars = !_bars),
                onDoubleTapDown: (d) => _tap = d.localPosition,
                onDoubleTap: _toggleZoom,
                // Whole picture visible (contain), then free zoom and pan.
                child: InteractiveViewer(
                  transformationController: _tc,
                  minScale: 1,
                  maxScale: 6,
                  child: SizedBox.expand(
                    child: Image.network(
                      widget.url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, p) => p == null
                          ? child
                          : const Center(child: SizedBox(width: 30, height: 30, child: M3Spinner(color: Colors.white))),
                      errorBuilder: (_, _, _) => Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 40),
                          const SizedBox(height: 8),
                          Text(tr('img_failed'), style: const TextStyle(color: Colors.white70)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: AnimatedSlide(
                offset: _bars ? Offset.zero : const Offset(0, -0.6),
                duration: const Duration(milliseconds: 220),
                curve: M3Motion.emphasizedDecelerate,
                child: AnimatedOpacity(
                  opacity: _bars ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_bars,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Row(children: [
                          _btn(Icons.close_rounded, tr('img_close'), () => Navigator.of(context).maybePop()),
                          const Spacer(),
                          _btn(Icons.copy_rounded, tr('img_copy'), () => ImageTools.copy(context, widget.url)),
                          const SizedBox(width: 8),
                          _btn(Icons.download_rounded, tr('img_save'), () => ImageTools.save(context, widget.url)),
                          const SizedBox(width: 8),
                          _btn(Icons.open_in_new_rounded, tr('img_open_source'), () => ImageTools.openSource(widget.url)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _bars ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Text(
                        [if (widget.alt.isNotEmpty) widget.alt, if (src.isNotEmpty) '${tr('img_source')} : $src'].join(' · '),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
