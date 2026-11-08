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
import '../services/model_manager.dart';
import '../services/prefs.dart';
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
  bool _typing = false; // the person writes: no automatic send
  DateTime _lastChange = DateTime.now();
  Timer? _silence;

  @override
  void initState() {
    super.initState();
    _voice.transcript.addListener(() => _lastChange = DateTime.now());
    // Model chosen for the assistant (setting), falls back to the app's model.
    ChatService.instance.modelOverride = ModelManager.instance.byId(assistModelNotifier.value);
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
    setState(() {
      _phase = _Phase.listening;
      _typing = false;
    });
    final ok = await _voice.start(_ctrl);
    if (!ok && mounted) setState(() => _micFailed = true);
  }

  // The person taps the text field: stop the microphone and let them write.
  Future<void> _startTyping() async {
    if (_typing || _phase == _Phase.thinking) return;
    if (_phase == _Phase.answered) _ctrl.clear();
    setState(() {
      _typing = true;
      if (_phase == _Phase.answered) _phase = _Phase.listening;
    });
    await _voice.stop();
  }

  Future<void> _pickModel() async {
    final models = ModelManager.instance.installed;
    final cur = ChatService.instance.currentModel;
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(tr('assist_choose_model'), style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final m in models)
            ListTile(
              leading: Icon(m.id == cur?.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
              title: Text(m.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(ctx, m.id),
            ),
        ]),
      ),
    );
    if (id == null || id == cur?.id) return;
    ChatService.instance.modelOverride = ModelManager.instance.byId(id);
    assistModelNotifier.value = id;
    await savePref('pc_assist_model', id);
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    if (_phase == _Phase.thinking) return;
    if (_phase == _Phase.answered) _phase = _Phase.listening;
    setState(() => _phase = _Phase.thinking);
    await _voice.stop();
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      if (mounted) _typing ? setState(() => _phase = _Phase.listening) : _listen();
      return;
    }
    final shown = text;
    await ChatService.instance.send(_chat, text);
    _ctrl.text = shown;
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
                    // Top line: which AI answers (tap to change), open app, close.
                    Row(children: [
                      ActionChip(
                        avatar: const Icon(Icons.memory_rounded, size: 18),
                        label: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
                          child: Text(ChatService.instance.currentModel?.fileName ?? tr('no_installed'),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        onPressed: _phase == _Phase.thinking ? null : _pickModel,
                      ),
                      const Spacer(),
                      IconButton(tooltip: tr('assist_open'), onPressed: _openApp, icon: const Icon(Icons.open_in_new_rounded)),
                      IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded)),
                    ]),
                    const SizedBox(height: 6),
                    if (!ChatService.instance.canChat)
                      Text(tr('no_installed'), style: text.bodyLarge)
                    else if (_phase == _Phase.listening && !_typing && !_micFailed)
                      _listeningView(scheme, text)
                    else if (_phase != _Phase.listening) ...[
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
                    const SizedBox(height: 12),
                    // Write instead of speaking.
                    if (ChatService.instance.canChat)
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
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
                        if (_typing || _phase == _Phase.answered)
                          IconButton.filledTonal(onPressed: _listen, icon: const Icon(Icons.mic_rounded)),
                        IconButton.filled(
                          onPressed: _phase == _Phase.thinking ? null : _send,
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
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
