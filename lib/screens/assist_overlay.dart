// lib/screens/assist_overlay.dart
// Small Gemini-like assistant card for Android. It opens over any app,
// starts the microphone right away (Whisper, offline), then answers.
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/chat_store.dart';
import '../services/inference_engine.dart';
import '../services/voice_input.dart';
import '../supported_locales.dart';

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

class _AssistScreenState extends State<_AssistScreen> {
  final _ctrl = TextEditingController();
  final _chat = ChatStore.instance.create();
  final _voice = VoiceInput.instance;
  _Phase _phase = _Phase.listening;
  bool _micFailed = false;
  DateTime _lastChange = DateTime.now();
  Timer? _silence;

  @override
  void initState() {
    super.initState();
    _voice.transcript.addListener(() => _lastChange = DateTime.now());
    // Send by itself after a short silence, once something was said.
    _silence = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_phase == _Phase.listening &&
          _voice.listening.value &&
          !_voice.loading.value &&
          _voice.transcript.value.trim().isNotEmpty &&
          DateTime.now().difference(_lastChange) > const Duration(milliseconds: 2000)) {
        _send();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _silence?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    _ctrl.clear();
    setState(() => _phase = _Phase.listening);
    final ok = await _voice.start(_ctrl);
    if (!ok && mounted) setState(() => _micFailed = true);
  }

  Future<void> _send() async {
    if (_phase != _Phase.listening) return;
    setState(() => _phase = _Phase.thinking);
    await _voice.stop();
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      if (mounted) _listen();
      return;
    }
    await ChatService.instance.send(_chat, text);
    if (mounted) setState(() => _phase = _Phase.answered);
  }

  Future<void> _close() async {
    await _voice.cancel();
    ChatService.instance.requestStop();
    try {
      await InferenceService.engine.unload(); // free the RAM
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => _close(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(children: [
          // Tap outside the card to close.
          Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close)),
          Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: ListenableBuilder(
                  listenable: Listenable.merge([ChatService.instance, ChatStore.instance]),
                  builder: (_, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!ChatService.instance.canChat)
                      Text(tr('no_installed'), style: text.bodyLarge)
                    else if (_micFailed && _phase == _Phase.listening)
                      TextField(
                        controller: _ctrl,
                        autofocus: true,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(hintText: tr('assist_listening'), border: InputBorder.none),
                      )
                    else if (_phase == _Phase.listening)
                      _listeningView(scheme, text)
                    else ...[
                      Text(_ctrl.text, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 10),
                      if (_answer.isEmpty)
                        Row(children: [
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                          const SizedBox(width: 12),
                          Text(tr('assist_thinking'), style: text.bodyLarge),
                        ])
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                          child: SingleChildScrollView(child: SelectableText(_answer, style: text.bodyLarge)),
                        ),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      TextButton.icon(onPressed: _openApp, icon: const Icon(Icons.open_in_new_rounded, size: 18), label: Text(tr('assist_open'))),
                      const Spacer(),
                      if (_phase == _Phase.answered)
                        IconButton.filledTonal(onPressed: _listen, icon: const Icon(Icons.mic_rounded)),
                      if (_phase == _Phase.listening)
                        FilledButton.icon(onPressed: _send, icon: const Icon(Icons.arrow_upward_rounded, size: 18), label: Text(tr('assist_send'))),
                      const SizedBox(width: 8),
                      IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
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
              Container(
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
