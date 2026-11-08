// lib/services/whisper_bundle.dart
// Copies the Whisper model shipped in assets/whisper/ to where whisper_ggml
// looks for it, so nothing has to be downloaded.
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:whisper_ggml/whisper_ggml.dart';

class WhisperBundle {
  WhisperBundle._();

  /// Copies the bundled model on first use. Never downloads: throws when the
  /// model is missing so the caller falls back to the system recognizer.
  static Future<void> ensure(WhisperModel model) async {
    final dest = File(await WhisperController().getPath(model));
    if (dest.existsSync() && dest.lengthSync() > 0) return;
    final data = await rootBundle.load('assets/whisper/ggml-${model.modelName}.bin');
    await dest.parent.create(recursive: true);
    // Write to a temp file first: a half-copied model would crash Whisper.
    final tmp = File('${dest.path}.tmp');
    await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    await tmp.rename(dest.path);
  }
}
