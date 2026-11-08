// lib/services/device_info.dart
// Reads the RAM of the device, to suggest a model that runs well on it.
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/model_models.dart';

class DeviceSpecs {
  DeviceSpecs._();
  static double? _ramGb;
  static bool _done = false;

  /// Total RAM in GB, or null when the system does not tell.
  static Future<double?> ramGb() async {
    if (_done) return _ramGb;
    _done = true;
    if (kIsWeb) return null;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        _ramGb = (await info.androidInfo).physicalRamSize / 1024;
      } else if (Platform.isWindows) {
        _ramGb = (await info.windowsInfo).systemMemoryInMegabytes / 1024;
      } else if (Platform.isMacOS) {
        _ramGb = (await info.macOsInfo).memorySize / (1024 * 1024 * 1024);
      } else if (Platform.isLinux) {
        final line = (await File('/proc/meminfo').readAsLines()).firstWhere((l) => l.startsWith('MemTotal'));
        _ramGb = int.parse(RegExp(r'\d+').firstMatch(line)!.group(0)!) / (1024 * 1024);
      }
    } catch (_) {
      _ramGb = null;
    }
    return _ramGb;
  }

  /// The biggest suggested model that fits [ram] GB (null when none fits).
  static RecommendedModel? bestFor(double ram) {
    RecommendedModel? best;
    for (final r in kRecommendedModels) {
      if (r.minRamGb <= ram && (best == null || r.approxMb > best.approxMb)) best = r;
    }
    return best;
  }
}
