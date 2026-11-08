// lib/services/location_service.dart
// Approximate location (city) from the IP address. No GPS, no permission.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';

class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  String? label; // "Mulhouse, France"
  String? city;
  bool busy = false;

  Future<void> refresh() async {
    if (busy) return;
    final manual = cityManualNotifier.value.trim();
    if (manual.isNotEmpty) {
      city = manual;
      label = manual;
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      final r = await http.get(Uri.parse('https://ipwho.is/')).timeout(const Duration(seconds: 8));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['success'] == true) {
        city = (j['city'] as String?)?.trim();
        final country = (j['country'] as String?)?.trim();
        final parts = [if (city != null && city!.isNotEmpty) city!, if (country != null && country.isNotEmpty) country];
        label = parts.isEmpty ? null : parts.join(', ');
      }
    } catch (e) {
      debugPrint('Location failed: $e');
    }
    busy = false;
    notifyListeners();
  }

  void clear() {
    label = null;
    city = null;
    notifyListeners();
  }
}
