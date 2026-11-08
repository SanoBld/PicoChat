// lib/services/whisper_bundle.dart
// Copies the Whisper model shipped in assets/whisper/ to where whisper_ggml
// looks for it, so nothing has to be downloaded.
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:whisper_ggml/whisper_ggml.dart';

class WhisperBundle {
  WhisperBundle._();

  /// Does nothing when the model is already there or not in the assets.
  static Future<void> ensure(WhisperModel model) async {
    try {
      final dest = File(await WhisperController().getPath(model));
      if (dest.existsSync()) return;
      final data = await rootBundle.load('assets/whisper/ggml-${model.modelName}.bin');
      await dest.parent.create(recursive: true);
      // Write to a temp file first: a half-copied model would crash Whisper.
      final tmp = File('${dest.path}.tmp');
      await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      await tmp.rename(dest.path);
    } catch (_) {
      // Not bundled: whisper_ggml downloads it as before.
    }
  }
}
