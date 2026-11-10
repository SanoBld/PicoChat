// lib/screens/assist_overlay.dart
// Small Gemini-like assistant card for Android. It opens over any app,
// starts the microphone right away (Whisper, offline) or lets the person
// write, shows which AI answers (tap to change) and animates every change.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/attachments.dart';
import '../services/chat_store.dart';
import '../services/cloud/cloud_store.dart';
import '../services/device_data.dart';
import '../services/inference_engine.dart';
import '../services/model_manager.dart';
import '../services/prefs.dart';
import '../services/voice_input.dart';
import '../supported_locales.dart';
import '../theme/m3_motion.dart';
import '../widgets/assist_fx.dart';
import '../widgets/pc_motion.dart';
import 'settings/cloud_page.dart' show cloudProviderLogo;
import '../widgets/skeleton.dart' show M3Spinner;

const _channel = MethodChannel('picochat/assist_overlay');

class AssistApp extends StatelessWidget {
  const AssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = themeModeNotifier.value;
    final dark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && PlatformDispatcher.instance.platformBrightness == Brightness.dark);
    final scheme = buildAppScheme(accentNotifier.value, dark ? Brightness.dark : Brightness.light, colorHarmonyNotifier.value);
    return MaterialApp(
      navigatorKey: rootNavKey,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      locale: Locale(localeNotifier.value),
      supportedLocales: [for (final l in kSupportedLocales) Locale(l.code)],
      theme: ThemeData(colorScheme: scheme, useMaterial3: true, scaffoldBackgroundColor: Colors.transparent),
      home: const _AssistScreen(),
    );
  }
}

class _AssistScreen extends StatefulWidget {
  const _AssistScreen();

  @override
  State<_AssistScreen> createState() => _AssistScreenState();
}

enum _Phase { listening, thinking, answered }

class _AssistScreenState extends State<_AssistScreen> with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _chat = ChatStore.instance.create();
  final _voice = VoiceInput.instance;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  // Opening / closing animation of the card (instant in energy saving).
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: ecoModeNotifier.value ? 1 : 480),
    reverseDuration: Duration(milliseconds: ecoModeNotifier.value ? 1 : 300),
  );
  // Material You easing: decelerate when it opens, accelerate when it leaves.
  late final CurvedAnimation _enterC =
      CurvedAnimation(parent: _enter, curve: M3Motion.emphasizedDecelerate, reverseCurve: M3Motion.emphasizedAccelerate);
  // The coloured edge glow shows briefly (open and close), it never stays.
  late final AnimationController _glowC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
  bool _closing = false;
  bool _locked = false; // lock screen: no screenshot, no phone data
  Uint8List? _shot; // picture of the screen given by Android
  bool _selecting = false; // the person circles something on the screenshot
  Uint8List? _cropBytes;
  String? _cropPath;
  bool _cropSent = false;
  _Phase _phase = _Phase.listening;
  bool _micFailed = false;
  bool _typing = false; // the person writes: no automatic send
  DateTime _lastChange = DateTime.now();
  Timer? _silence;

  @override
  void initState() {
    super.initState();
    // Model chosen for the assistant (setting); falls back to the model of the app.
    _applyChoice(assistModelNotifier.value);
    _focus.addListener(() {
      if (_focus.hasFocus) _startTyping(); // keyboard opened: stop listening
    });
    if (!ecoModeNotifier.value) _glowC.forward();
    _channel.setMethodCallHandler((c) async {
      if (c.method == 'screenshot') _gotShot(c.arguments as String?);
    });
    _initDevice();
    _voice.transcript.addListener(() => _lastChange = DateTime.now());
    // Send by itself after a short silence, once something was said.
    _silence = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_phase == _Phase.listening &&
          !_typing &&
          _voice.listening.value &&
          !_voice.loading.value &&
          _voice.transcript.value.trim().isNotEmpty &&
          DateTime.now().difference(_lastChange) > const Duration(milliseconds: 2000)) {
        _send();
      }
    });
    // The card opens first; the microphone starts right after, so the animation stays smooth.
    _enter.forward().then((_) {
      if (mounted && !_typing && !_closing) _listen();
    });
  }

  @override
  void dispose() {
    _silence?.cancel();
    _pulse.dispose();
    _enterC.dispose();
    _glowC.dispose();
    _enter.dispose();
    _channel.setMethodCallHandler(null);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    _ctrl.clear();
    setState(() {
      _phase = _Phase.listening;
      _typing = false;
    });
    final ok = await _voice.start(_ctrl);
    // The person started writing while the engine was still starting (the model can
    // take a while to load): the microphone must not stay on.
    if (mounted && (_typing || _closing)) {
      final typed = _ctrl.text;
      await _voice.cancel();
      _ctrl.value = TextEditingValue(text: typed, selection: TextSelection.collapsed(offset: typed.length));
      return;
    }
    if (!ok && mounted) setState(() => _micFailed = true);
  }

  // The person taps the text field: stop the microphone and let them write.
  // What was typed (or already heard) is kept: the voice engine would overwrite the field.
  Future<void> _startTyping() async {
    if (_typing || _phase == _Phase.thinking) return;
    if (_phase == _Phase.answered) _ctrl.clear();
    var keep = _ctrl.text;
    if (keep.trim().isEmpty) keep = _voice.transcript.value;
    setState(() {
      _typing = true;
      if (_phase == _Phase.answered) _phase = _Phase.listening;
    });
    await _voice.cancel();
    _ctrl.value = TextEditingValue(text: keep, selection: TextSelection.collapsed(offset: keep.length));
  }

  // Local model or external AI (cloud): the choice is saved for the next time.
  void _applyChoice(String id) {
    final chat = ChatService.instance;
    if (id.startsWith(kCloudPrefix)) {
      chat.cloudOverride = cloudEnabledNotifier.value ? CloudStore.instance.byId(id) : null;
      chat.modelOverride = chat.cloudOverride == null ? ModelManager.instance.active : null;
    } else {
      chat.cloudOverride = null;
      chat.modelOverride = ModelManager.instance.byId(id);
    }
  }

  Future<void> _pickModel() async {
    final models = ModelManager.instance.installed;
    final cloud = cloudEnabledNotifier.value ? CloudStore.instance.chatModels : <CloudModel>[];
    final curId = ChatService.instance.currentCloud?.id ?? ChatService.instance.currentModel?.id;
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        Widget head(String t) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
              child: Text(t, style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Theme.of(ctx).colorScheme.primary)),
            );
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
            child: ListView(shrinkWrap: true, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text(tr('assist_choose_model'), style: Theme.of(ctx).textTheme.titleMedium),
              ),
              if (models.isNotEmpty) head(tr('assist_on_device')),
              for (final m in models)
                ListTile(
                  leading: Icon(m.id == curId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                  title: Text(m.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(ctx, m.id),
                ),
              if (cloud.isNotEmpty) head(tr('assist_cloud')),
              for (final m in cloud)
                ListTile(
                  leading: m.id == curId ? const Icon(Icons.radio_button_checked_rounded) : cloudProviderLogo(m.account.provider),
                  title: Text(m.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: m.info.vision ? const Icon(Icons.visibility_rounded, size: 18) : null,
                  onTap: () => Navigator.pop(ctx, m.id),
                ),
            ]),
          ),
        );
      },
    );
    if (id == null || id == curId) return;
    _applyChoice(id);
    assistModelNotifier.value = id;
    await savePref('pc_assist_model', id);
    if (mounted) setState(() {});
  }

  // ── Screen picture (circle to search) ────────────────────────────────────
  Future<void> _initDevice() async {
    try {
      _locked = (await _channel.invokeMethod<bool>('locked')) ?? false;
    } catch (_) {}
    DeviceData.locked = _locked; // lock screen: phone data stays private
    if (_locked) return;
    try {
      _gotShot(await _channel.invokeMethod<String>('screenshot'));
    } catch (_) {}
  }

  Future<void> _gotShot(String? path) async {
    if (path == null || _locked || _shot != null || _phase != _Phase.listening) return;
    try {
      final b = await File(path).readAsBytes();
      if (mounted) setState(() {
        _shot = b;
        _selecting = true;
      });
    } catch (_) {}
  }

  void _retake() => setState(() {
        _selecting = true;
        _cropBytes = null;
        _cropPath = null;
        _cropSent = false;
      });

  // Cuts the circled area out of the screenshot (max 1280 px) and keeps it as a PNG.
  Future<void> _onCircled(Rect r) async {
    final shot = _shot;
    if (shot == null) return;
    setState(() => _selecting = false);
    try {
      final img = (await (await ui.instantiateImageCodec(shot)).getNextFrame()).image;
      final src = Rect.fromLTRB(r.left * img.width, r.top * img.height, r.right * img.width, r.bottom * img.height);
      final k = math.min(1.0, 1280 / math.max(src.width, src.height));
      final w = math.max(1, (src.width * k).round());
      final h = math.max(1, (src.height * k).round());
      final rec = ui.PictureRecorder();
      Canvas(rec).drawImageRect(img, src, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..filterQuality = FilterQuality.high);
      final out = await rec.endRecording().toImage(w, h);
      final bd = await out.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) return;
      final bytes = bd.buffer.asUint8List();
      final f = File('${Directory.systemTemp.path}/pico_lens_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() {
        _cropBytes = bytes;
        _cropPath = f.path;
        _cropSent = false;
      });
    } catch (_) {}
  }

  // Images need an AI that can see: switch to an external one with vision if needed.
  Future<bool> _ensureVision() async {
    final cur = ChatService.instance.currentCloud;
    if (cur != null) {
      if (cur.info.vision) return true;
    } else if (ChatService.instance.currentModel != null && InferenceService.engine.supportsVision) {
      return true;
    }
    if (cloudEnabledNotifier.value) {
      for (final m in CloudStore.instance.chatModels) {
        if (m.info.vision) {
          ChatService.instance.cloudOverride = m;
          ChatService.instance.modelOverride = null;
          if (mounted) setState(() {});
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _send() async {
    if (_phase == _Phase.thinking) return;
    final typed = _typing ? _ctrl.text.trim() : '';
    setState(() => _phase = _Phase.thinking);
    if (!_typing) await _voice.stop(); // dictation: the final words are written in the field
    var text = _typing ? typed : _ctrl.text.trim();
    final hasImg = _cropPath != null && !_cropSent;
    if (text.isEmpty && hasImg) text = tr('assist_lens_q');
    if (text.isEmpty) {
      if (mounted) _typing ? setState(() => _phase = _Phase.listening) : _listen();
      return;
    }
    _typing = false;
    if (hasImg && !await _ensureVision()) {
      if (mounted) {
        setState(() {
          _phase = _Phase.listening;
          _typing = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('assist_need_vision'))));
      }
      return;
    }
    await ChatService.instance.send(_chat, text,
        files: hasImg ? [Attachment('screen.png', '', imagePath: _cropPath)] : const []);
    if (hasImg) _cropSent = true;
    _ctrl.text = text;
    if (mounted) setState(() => _phase = _Phase.answered);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    // The animation starts at once; the microphone and the model are freed while it plays.
    _glowC.duration = const Duration(milliseconds: 520); // short glow on the way out
    final anim = Future.wait([_enter.reverse(), if (!ecoModeNotifier.value) _glowC.forward(from: 0)]);
    try {
      await _voice.cancel();
      ChatService.instance.requestStop();
      await InferenceService.engine.unload(); // free the RAM
    } catch (_) {}
    try {
      await anim;
    } catch (_) {}
    try {
      await _channel.invokeMethod('close');
    } catch (_) {}
  }

  Future<void> _openApp() async {
    await _voice.cancel();
    try {
      await InferenceService.engine.unload();
    } catch (_) {}
    try {
      await _channel.invokeMethod('openApp');
    } catch (_) {}
  }

  String get _answer {
    for (final m in _chat.messages.reversed) {
      if (m.role == ChatRole.assistant) return m.text;
    }
    return '';
  }

  // ── Animated pieces ─────────────────────────────────────────────────────
  Widget _fade(Widget child, String key) => AnimatedSize(
        // The card changes height smoothly instead of jumping.
        duration: Duration(milliseconds: M3Motion.reduced(context) ? 1 : 320),
        curve: M3Motion.emphasized,
        alignment: Alignment.topCenter,
        child: _fadeSwitch(child, key),
      );

  Widget _fadeSwitch(Widget child, String key) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: M3Motion.emphasizedDecelerate,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, ?cur]),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(a), child: c),
        ),
        child: KeyedSubtree(key: ValueKey(key), child: child),
      );

  // Round button: springs when pressed, pulses while the microphone listens.
  Widget _btn(String key, IconData icon, VoidCallback? onTap, {bool filled = false, bool pulse = false}) {
    final scheme = Theme.of(context).colorScheme;
    return _Bouncy(
      key: ValueKey(key),
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null ? scheme.surfaceContainerHighest : (filled ? scheme.primary : scheme.secondaryContainer),
            boxShadow: pulse
                ? [
                    BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35 * (1 - _pulse.value)),
                        blurRadius: 4 + 16 * _pulse.value,
                        spreadRadius: 10 * _pulse.value)
                  ]
                : null,
          ),
          child: child,
        ),
        child: Icon(icon, color: filled ? scheme.onPrimary : scheme.onSecondaryContainer),
      ),
    );
  }

  // Buttons next to the text field: the field widens / narrows smoothly.
  Widget _swap(Widget child) => AnimatedSize(
        duration: Duration(milliseconds: M3Motion.reduced(context) ? 1 : 260),
        curve: M3Motion.emphasized,
        alignment: Alignment.centerRight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: M3Motion.emphasizedDecelerate,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerRight, children: [...prev, ?cur]),
          transitionBuilder: (c, a) => ScaleTransition(
              scale: Tween(begin: 0.7, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
          child: child,
        ),
      );

  Widget _body(ColorScheme scheme, TextTheme text, bool canChat, bool micOn) {
    if (!canChat) return Text(tr('no_installed'), style: text.bodyLarge);
    if (micOn) return _listeningView(scheme, text);
    if (_phase == _Phase.listening) return const SizedBox(width: double.infinity);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_ctrl.text, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 10),
      if (_answer.isEmpty)
        Row(children: [
          const SizedBox(width: 18, height: 18, child: M3Spinner()),
          const SizedBox(width: 12),
          Text(tr('assist_thinking'), style: text.bodyLarge),
        ])
      else
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
          child: SingleChildScrollView(child: SelectableText(_answer, style: text.bodyLarge)),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => _close(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          // Screenshot where the person circles what to search.
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: ecoModeNotifier.value ? 1 : 320),
              child: (_shot != null && _selecting)
                  ? LensSelect(
                      key: const ValueKey('lens'),
                      shot: _shot!,
                      onDone: _onCircled,
                      onCancel: () => setState(() => _selecting = false),
                      hint: tr('assist_lens_hint'),
                    )
                  : const SizedBox.shrink(key: ValueKey('nolens')),
            ),
          ),
          // Brief coloured glow (open and close) + soft shade under the card.
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_enterC, _glowC]),
                builder: (_, _) => AssistGlow(
                  intensity: ecoModeNotifier.value ? 0 : math.sin(math.pi * _glowC.value),
                  t: _glowC.value * 1.5,
                  scrim: _selecting ? 0 : _enterC.value,
                  colors: [scheme.primary, scheme.tertiary, scheme.secondary],
                ),
              ),
            )),
          ),
          Column(children: [
          // Tap outside the card to close (not while circling).
          Expanded(child: _selecting ? const IgnorePointer(child: SizedBox.expand()) : PcGesture(behavior: HitTestBehavior.opaque, onTap: _close)),
          // The card springs up and fades in; on close it slides away.
          FadeTransition(
            opacity: _enterC,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.22), end: Offset.zero).animate(_enterC),
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(_enterC),
                alignment: Alignment.bottomCenter,
            child: Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([ChatService.instance, ChatStore.instance]),
                    builder: (_, _) {
                      final canChat = ChatService.instance.canChat;
                      final micOn = _phase == _Phase.listening && !_typing && !_micFailed;
                      return AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            _Bouncy(
                              onTap: _phase == _Phase.thinking ? null : _pickModel,
                              child: Chip(
                                avatar: ChatService.instance.currentCloud != null
                                    ? cloudProviderLogo(ChatService.instance.currentCloud!.provider, size: 18)
                                    : const Icon(Icons.memory_rounded, size: 18),
                                label: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
                                  child: Text(ChatService.instance.currentCloud?.displayName ?? ChatService.instance.currentModel?.fileName ?? tr('no_installed'),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (_shot != null && !_selecting && _cropBytes == null)
                              IconButton(tooltip: tr('assist_retake'), onPressed: _retake, icon: const Icon(Icons.gesture_rounded)),
                            IconButton(tooltip: tr('assist_open'), onPressed: _openApp, icon: const Icon(Icons.open_in_new_rounded)),
                            IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded)),
                          ]),
                          const SizedBox(height: 6),
                          if (_cropBytes != null)
                            FadeSlideIn(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _Bouncy(
                                    onTap: _retake,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 96, maxWidth: 170),
                                        child: Image.memory(_cropBytes!, fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          _fade(_body(scheme, text, canChat, micOn), '${canChat}_${micOn}_${_phase.name}_${_answer.isEmpty}'),
                          const SizedBox(height: 12),
                          if (canChat)
                            Row(children: [
                              Expanded(
                                child: TextField(
                                  controller: _ctrl,
                                  focusNode: _focus,
                                  minLines: 1,
                                  maxLines: 3,
                                  onTap: _startTyping,
                                  onChanged: (_) => _typing ? null : _startTyping(),
                                  onSubmitted: (_) => _send(),
                                  textInputAction: TextInputAction.send,
                                  decoration: InputDecoration(
                                    hintText: tr('assist_type_hint'),
                                    filled: true,
                                    fillColor: scheme.surfaceContainerHighest,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _swap(micOn
                                  ? _btn('send', Icons.arrow_upward_rounded, _send, filled: true, pulse: true)
                                  : _phase == _Phase.thinking
                                      ? _btn('wait', Icons.hourglass_top_rounded, null)
                                      : Row(key: const ValueKey('mic+send'), mainAxisSize: MainAxisSize.min, children: [
                                          _btn('mic', Icons.mic_rounded, _listen),
                                          const SizedBox(width: 8),
                                          _btn('send2', Icons.arrow_upward_rounded, _send, filled: true),
                                        ])),
                            ]),
                        ]),
                      );
                    },
                  ),
                ),
              ),
            ),
          ))),
        ]),
        ]),
      ),
    );
  }

  // Wave bars (microphone level) + the words heard so far.
  Widget _listeningView(ColorScheme scheme, TextTheme text) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 44,
        child: ValueListenableBuilder<List<double>>(
          valueListenable: _voice.levels,
          builder: (_, lv, _) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final v in lv)
              AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: 5,
                height: 6 + v * 38,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(3)),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      ValueListenableBuilder<String>(
        valueListenable: _voice.transcript,
        builder: (_, t, _) => ValueListenableBuilder<bool>(
          valueListenable: _voice.loading,
          builder: (_, loading, _) => Text(
            t.isEmpty ? (loading ? '…' : tr('assist_listening')) : t,
            style: text.titleMedium?.copyWith(color: t.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface),
          ),
        ),
      ),
    ]);
  }
}

/// Springs down a little when pressed.
class _Bouncy extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Bouncy({super.key, required this.child, this.onTap});

  @override
  State<_Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<_Bouncy> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => PcGesture(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.88 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      );
}
