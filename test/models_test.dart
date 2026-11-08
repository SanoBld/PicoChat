// test/models_test.dart
// Pure-Dart checks for the model helpers (no widgets, no network).

import 'package:flutter_test/flutter_test.dart';
import 'package:picochat/models/model_models.dart';

void main() {
  test('quantOf reads the quantisation tag', () {
    expect(quantOf('qwen2.5-0.5b-instruct-q4_k_m.gguf'), 'Q4_K_M');
    expect(quantOf('model-Q8_0.gguf'), 'Q8_0');
    expect(quantOf('model-f16.gguf'), 'F16');
    expect(quantOf('model.gguf'), '');
  });

  test('formatBytes is human readable', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1536), '2 KB');
    expect(formatBytes(5 * 1024 * 1024 * 1024), '5.0 GB');
  });

  test('InstalledModel.displayName strips the GGUF suffix', () {
    final m = InstalledModel(
      id: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF/x.gguf',
      repo: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
      fileName: 'x.gguf',
      path: '/tmp/x.gguf',
      sizeBytes: 1,
      addedAt: DateTime(2026),
    );
    expect(m.displayName, 'Qwen2.5-0.5B-Instruct');
  });
}
