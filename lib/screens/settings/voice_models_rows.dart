// lib/screens/settings/voice_models_rows.dart
// Download rows for the fast speech recognition and the natural voice.
import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../services/prefs.dart';
import '../../services/sherpa_models.dart';
import '../../services/voice.dart';

class VoiceModelsRows extends StatefulWidget {
  const VoiceModelsRows({super.key});

  @override
  State<VoiceModelsRows> createState() => _VoiceModelsRowsState();
}

class _VoiceModelsRowsState extends State<VoiceModelsRows> {
  bool? _asr;
  bool? _voice;
  String _busy = ''; // 'asr' or 'voice' while downloading
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final a = await SherpaModels.hasAsr();
    final v = await SherpaModels.hasVoice(localeNotifier.value);
    if (mounted) {
      setState(() {
        _asr = a;
        _voice = v;
      });
    }
  }

  Future<void> _get(String what) async {
    setState(() {
      _busy = what;
      _error = null;
    });
    try {
      if (what == 'asr') {
        await SherpaModels.ensureAsr();
      } else {
        await SherpaModels.ensureVoice(localeNotifier.value);
      }
    } catch (e) {
      _error = '${tr('vm_dl_fail')}: $e';
    }
    _busy = '';
    await _check();
  }

  Widget _row(IconData icon, String title, String sub, bool? ready, String what) {
    final s = Theme.of(context).colorScheme;
    final busy = _busy == what;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: busy
          ? ValueListenableBuilder<double?>(
              valueListenable: SherpaModels.progress,
              builder: (_, p, _) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(value: p),
              ),
            )
          : Text(sub),
      trailing: ready == null
          ? null
          : ready
              ? Icon(Icons.check_circle_rounded, color: s.primary)
              : FilledButton.tonal(onPressed: _busy.isEmpty ? () => _get(what) : null, child: Text(tr('vm_dl_btn'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _row(Icons.mic_rounded, tr('vm_dl_asr'), tr('vm_dl_asr_sub'), _asr, 'asr'),
      ValueListenableBuilder<bool>(
        valueListenable: VoiceService.neural,
        builder: (_, on, _) => SwitchListTile(
          secondary: const Icon(Icons.record_voice_over_rounded),
          title: Text(tr('vm_dl_voice')),
          subtitle: Text(tr('vm_dl_voice_sub')),
          value: on,
          onChanged: (v) {
            VoiceService.neural.value = v;
            savePref('pc_voice_neural', v);
          },
        ),
      ),
      if (VoiceService.neural.value) _row(Icons.download_rounded, tr('vm_dl_voice'), tr('vm_dl_voice_sub'), _voice, 'voice'),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
    ]);
  }
}
