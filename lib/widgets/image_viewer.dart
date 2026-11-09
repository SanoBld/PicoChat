// lib/widgets/image_viewer.dart
// Pictures in answers: copy, download, show the source, and a full-screen
// viewer with pinch / wheel zoom, double-tap zoom, Hero flight and tap outside to close.

import 'dart:convert' show base64Decode;
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

  static ImageProvider provider(String url) {
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final raw = comma != -1 ? url.substring(comma + 1) : url;
      return MemoryImage(base64Decode(raw));
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url, headers: const {'User-Agent': 'PicoChat/0.1 (private chat app)'});
    }
    return FileImage(File(url));
  }

  static Widget imageWidget(
    String url, {
    BoxFit fit = BoxFit.contain,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (url.startsWith('data:')) {
      try {
        final comma = url.indexOf(',');
        final raw = comma != -1 ? url.substring(comma + 1) : url;
        return Image.memory(
          base64Decode(raw),
          fit: fit,
          errorBuilder: (_, _, _) => errorWidget ?? const Icon(Icons.broken_image_outlined),
        );
      } catch (_) {
        return errorWidget ?? const Icon(Icons.broken_image_outlined);
      }
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (_, child, p) => p == null
            ? child
            : (placeholder ?? const Center(child: SizedBox(width: 30, height: 30, child: M3Spinner(color: Colors.white)))),
        errorBuilder: (_, _, _) => errorWidget ?? const Icon(Icons.broken_image_outlined),
      );
    }
    return Image.file(
      File(url),
      fit: fit,
      errorBuilder: (_, _, _) => errorWidget ?? const Icon(Icons.broken_image_outlined),
    );
  }

  static Future<Uint8List?> _bytes(String url) async {
    try {
      if (url.startsWith('data:')) {
        final comma = url.indexOf(',');
        final raw = comma != -1 ? url.substring(comma + 1) : url;
        return base64Decode(raw);
      }
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final r = await http
            .get(Uri.parse(url), headers: {'User-Agent': 'PicoChat/0.1 (private chat app)'})
            .timeout(const Duration(seconds: 20));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) return r.bodyBytes;
        return null;
      }
      final f = File(url);
      if (await f.exists()) return await f.readAsBytes();
    } catch (_) {}
    return null;
  }

  /// Host of the picture, without "www." (shown as the source).
  static String host(String url) {
    if (url.startsWith('data:')) return 'Pico AI';
    if (!url.startsWith('http://') && !url.startsWith('https://')) return 'Pico AI';
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
    if (!asImage && (url.startsWith('http://') || url.startsWith('https://'))) {
      await Clipboard.setData(ClipboardData(text: url));
    }
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
    if (!url.startsWith('http://') && !url.startsWith('https://')) return;
    final u = Uri.tryParse(url);
    if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  static Route<void> route(String url, {String source = '', String alt = ''}) => PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        barrierDismissible: true,
        pageBuilder: (_, _, _) => PcImageViewer(url: url, source: source, alt: alt),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
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
  Size? _imageSize;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final a = _a;
      if (a != null) _tc.value = a.value;
    });
    _resolveSize();
  }

  void _resolveSize() {
    try {
      final prov = ImageTools.provider(widget.url);
      _stream = prov.resolve(const ImageConfiguration());
      _listener = ImageStreamListener((info, _) {
        if (!mounted) return;
        setState(() {
          _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble());
        });
      });
      _stream?.addListener(_listener!);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
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
          ..translateByDouble(-_tap.dx * (s - 1), -_tap.dy * (s - 1), 0.0, 1.0)
          ..scaleByDouble(s, s, 1.0, 1.0));
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
    final isWebUrl = widget.url.startsWith('http://') || widget.url.startsWith('https://');
    final src = widget.source.isNotEmpty ? widget.source : ImageTools.host(widget.url);

    return CallbackShortcuts(
      bindings: {SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(children: [
            // Background tap to close: anywhere outside the image or when tapping dark margins
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_tc.value.getMaxScaleOnAxis() > 1.05) {
                    _toggleZoom();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),

            // Image area with free pan & zoom + Hero animation
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screen = Size(constraints.maxWidth, constraints.maxHeight);
                  final imgSize = _imageSize ?? screen;
                  final fitted = applyBoxFit(BoxFit.contain, imgSize, screen);
                  final displayW = fitted.destination.width;
                  final displayH = fitted.destination.height;

                  return Center(
                    child: InteractiveViewer(
                      transformationController: _tc,
                      minScale: 1,
                      maxScale: 6,
                      child: GestureDetector(
                        behavior: HitTestBehavior.deferToChild,
                        onDoubleTapDown: (d) => _tap = d.localPosition,
                        onDoubleTap: _toggleZoom,
                        child: SizedBox(
                          width: displayW,
                          height: displayH,
                          child: Hero(
                            tag: 'img_${widget.url}',
                            flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                              return Material(
                                color: Colors.transparent,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22 * (1 - animation.value)),
                                  child: toHeroContext.widget,
                                ),
                              );
                            },
                            child: ImageTools.imageWidget(
                              widget.url,
                              fit: BoxFit.contain,
                              placeholder: const Center(
                                child: SizedBox(width: 32, height: 32, child: M3Spinner(color: Colors.white)),
                              ),
                              errorWidget: Center(
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
                  );
                },
              ),
            ),

            // Top bar with close, copy, save, open source — ALWAYS visible (not hidden on tap)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(children: [
                    _btn(Icons.close_rounded, tr('img_close'), () => Navigator.of(context).maybePop()),
                    const Spacer(),
                    _btn(Icons.copy_rounded, tr('img_copy'), () => ImageTools.copy(context, widget.url)),
                    const SizedBox(width: 8),
                    _btn(Icons.download_rounded, tr('img_save'), () => ImageTools.save(context, widget.url)),
                    if (isWebUrl) ...[
                      const SizedBox(width: 8),
                      _btn(Icons.open_in_new_rounded, tr('img_open_source'), () => ImageTools.openSource(widget.url)),
                    ],
                  ]),
                ),
              ),
            ),

            // Bottom caption (alt text and source) — ALWAYS visible
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
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
          ]),
        ),
      ),
    );
  }
}
