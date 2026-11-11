// lib/screens/voice_mode_screen.dart
// Voice mode: talk with the AI like a phone call. Loop: listen → the AI answers → it speaks
// each sentence as soon as it is written → listen again. Tap the circle to interrupt.
// Everything uses the same engines as the rest of the app (Whisper or the system recognizer,
// the chosen local or cloud model, the system voice).
import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/voice.dart';
import '../services/voice_input.dart';
import '../widgets/pico_face.dart';

enum _VState { starting, listening, thinking, speaking, paused }

class VoiceModeScreen extends StatefulWidget {
  final Conversation chat;
  const VoiceModeScreen({super.key, required this.chat});

  @override
  State<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends State<VoiceModeScreen> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  Timer? _poll;
  _VState _state = _VState.starting;
  bool _active = true;
  bool _interrupted = false;
  String _heard = '';
  String _reply = '';
  String _prev = '';
  DateTime _lastChange = DateTime.now();
  int _turn = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _shutdown();
    _pulse.dispose();
    // _ctrl is not disposed here: the recognizer may still write its last words into it while it closes.
    super.dispose();
  }

  void _shutdown() {
    _active = false;
    _poll?.cancel();
    VoiceInput.instance.cancel();
    VoiceService.instance.stop();
    ChatService.instance.requestStop();
  }

  void _set(_VState s) {
    if (mounted) setState(() => _state = s);
  }

  // ── Listening ──────────────────────────────────────────────────────────────

  Future<void> _listen() async {
    if (!_active || !mounted) return;
    _ctrl.clear();
    _prev = '';
    _lastChange = DateTime.now();
    _set(_VState.listening);
    final ok = await VoiceInput.instance.start(_ctrl);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('voice_unavailable'))));
        Navigator.of(context).maybePop();
      }
      return;
    }
    _poll?.cancel();
    // The turn ends when the words stop changing for a moment.
    _poll = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_active || _state != _VState.listening) return;
      final t = _ctrl.text.trim();
      if (t != _prev) {
        _prev = t;
        _lastChange = DateTime.now();
        if (mounted) setState(() => _heard = t);
      } else if (t.isNotEmpty && DateTime.now().difference(_lastChange).inMilliseconds > 1500) {
        _endTurn();
      }
    });
  }

  Future<void> _endTurn() async {
    _poll?.cancel();
    _set(_VState.thinking);
    await VoiceInput.instance.stop();
    final text = _ctrl.text.trim();
    if (!_active) return;
    if (text.isEmpty) return _listen();
    if (mounted) setState(() {
      _heard = text;
      _reply = '';
    });
    await _converse(text);
    if (_active && _state != _VState.paused) await _listen();
  }

  // ── Answering out loud ─────────────────────────────────────────────────────

  /// What can be said: without the model's reasoning, the [[tags]] and half-written ones.
  String _speakable(String raw) {
    var s = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
    final open = s.indexOf('<think>');
    if (open >= 0) s = s.substring(0, open);
    s = s.replaceAll(RegExp(r'\[\[[\s\S]*?\]\]'), '');
    final tag = s.lastIndexOf('[[');
    if (tag >= 0) s = s.substring(0, tag);
    return s;
  }

  Future<void> _converse(String text) async {
    _interrupted = false;
    final chat = widget.chat;
    final before = chat.messages.length;
    var finished = false;
    final done = ChatService.instance.send(chat, text).whenComplete(() => finished = true);
    var spoken = 0; // characters of the speakable text already said
    while (_active && !_interrupted) {
      final fresh = chat.messages.length > before && chat.messages.last.role == ChatRole.assistant;
      final clean = fresh ? _speakable(chat.messages.last.text) : '';
      if (spoken > clean.length) spoken = clean.length;
      if (mounted && clean != _reply) setState(() => _reply = clean);
      final rest = clean.substring(spoken);
      // A sentence is complete when something follows its end mark (so "3.5" is not cut).
      final m = RegExp(r'^[\s\S]*?[.!?…:\n](?=\s)').firstMatch(rest);
      String? say;
      if (m != null) {
        say = m.group(0);
      } else if (finished && rest.trim().isNotEmpty) {
        say = rest;
      }
      if (say != null && say.trim().isNotEmpty) {
        spoken += say.length;
        _set(_VState.speaking);
        await VoiceService.instance.speak('vm${_turn++}', say);
        continue;
      }
      if (finished && rest.trim().isEmpty) break;
      if (finished && chat.messages.length == before) break; // nothing was sent (no model ready)
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (chat.messages.length == before && mounted && _active && !_interrupted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('no_model_title'))));
    }
    await done; // the generation is over (or stopped) before listening again
  }

  // ── Buttons ────────────────────────────────────────────────────────────────

  Future<void> _tapOrb() async {
    if (_state == _VState.speaking || _state == _VState.thinking) {
      _interrupted = true;
      ChatService.instance.requestStop();
      await VoiceService.instance.stop();
    } else if (_state == _VState.listening && _prev.isNotEmpty) {
      _endTurn(); // send now, without waiting for the pause
    }
  }

  Future<void> _togglePause() async {
    if (_state == _VState.paused) {
      _listen();
      return;
    }
    _poll?.cancel();
    _interrupted = true;
    ChatService.instance.requestStop();
    await VoiceService.instance.stop();
    await VoiceInput.instance.cancel();
    _set(_VState.paused);
  }

  void _end() => Navigator.of(context).maybePop();

  // ── Screen ─────────────────────────────────────────────────────────────────

  PicoMood get _mood => switch (_state) {
        _VState.listening => PicoMood.curious,
        _VState.thinking => PicoMood.thinking,
        _VState.speaking => PicoMood.writing,
        _VState.paused => PicoMood.sleepy,
        _ => PicoMood.idle,
      };

  String get _label => switch (_state) {
        _VState.listening => tr('vm_listening'),
        _VState.thinking => tr('vm_thinking'),
        _VState.speaking => tr('vm_speaking'),
        _VState.paused => tr('vm_paused'),
        _ => tr('voice_loading'),
      };

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final shown = _reply.length > 260 ? '…${_reply.substring(_reply.length - 260)}' : _reply;
    return Scaffold(
      backgroundColor: s.surface,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.close_rounded), tooltip: tr('vm_end'), onPressed: _end),
              Expanded(child: Text(tr('vm_title'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            ]),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _tapOrb,
            child: ValueListenableBuilder<List<double>>(
              valueListenable: VoiceInput.instance.levels,
              builder: (context, lv, _) => AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final level = _state == _VState.listening ? lv.skip(lv.length - 6).fold<double>(0, (a, b) => a + b) / 6 : 0.0;
                  final breathe = (_state == _VState.speaking || _state == _VState.thinking) ? _pulse.value * 0.08 : 0.0;
                  final scale = 1 + level * 0.3 + breathe;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _state == _VState.paused ? s.surfaceContainerHighest : s.primaryContainer,
                        boxShadow: [
                          BoxShadow(
                              color: s.primary.withValues(alpha: _state == _VState.paused ? 0 : 0.18 + level * 0.3),
                              blurRadius: 40 + level * 40,
                              spreadRadius: 6 + level * 16),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: PicoFace(mood: _mood, size: 110, color: s.onPrimaryContainer),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(_label, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(children: [
                if (_heard.isNotEmpty)
                  Text('“$_heard”',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge?.copyWith(color: s.onSurfaceVariant, fontStyle: FontStyle.italic)),
                if (shown.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(shown, textAlign: TextAlign.center, maxLines: 6, overflow: TextOverflow.ellipsis, style: t.bodyLarge),
                ],
              ]),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(tr('vm_hint'), textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(
                iconSize: 30,
                style: IconButton.styleFrom(fixedSize: const Size(64, 64)),
                tooltip: tr('vm_mic'),
                icon: Icon(_state == _VState.paused ? Icons.mic_off_rounded : Icons.mic_rounded),
                onPressed: _togglePause,
              ),
              const SizedBox(width: 24),
              IconButton.filled(
                iconSize: 30,
                style: IconButton.styleFrom(
                    fixedSize: const Size(64, 64), backgroundColor: s.error, foregroundColor: s.onError),
                tooltip: tr('vm_end'),
                icon: const Icon(Icons.call_end_rounded),
                onPressed: _end,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
