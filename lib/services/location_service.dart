// lib/services/location_service.dart
// Real location: GPS / network position (asks the permission), turned into a
// city name with OpenStreetMap. Falls back to the IP address when refused.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';

class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  String? label; // "Mulhouse, France"
  String? city;
  String? address; // street address of the device position
  double? lat, lon;
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
    if (!await _fromDevice()) await _fromIp();
    busy = false;
    notifyListeners();
  }

  // Position of the device, then the city name of that position.
  Future<bool> _fromDevice() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 12)),
      );
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'zoom': '18',
        'lat': '${pos.latitude}',
        'lon': '${pos.longitude}',
        'accept-language': localeNotifier.value,
      });
      final r = await http.get(uri, headers: {'User-Agent': 'PicoChat'}).timeout(const Duration(seconds: 8));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final a = body['address'] as Map<String, dynamic>?;
      if (a == null) return false;
      final c = (a['city'] ?? a['town'] ?? a['village'] ?? a['municipality'] ?? a['county']) as String?;
      final country = a['country'] as String?;
      if (c == null || c.isEmpty) return false;
      lat = pos.latitude;
      lon = pos.longitude;
      address = body['display_name'] as String?;
      city = c;
      label = [c, if (country != null && country.isNotEmpty) country].join(', ');
      return true;
    } catch (e) {
      debugPrint('Device location failed: $e');
      return false;
    }
  }

  // Fallback: approximate city from the IP address.
  Future<void> _fromIp() async {
    try {
      final r = await http.get(Uri.parse('https://ipwho.is/')).timeout(const Duration(seconds: 8));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['success'] == true) {
        lat = (j['latitude'] as num?)?.toDouble();
        lon = (j['longitude'] as num?)?.toDouble();
        address = null;
        city = (j['city'] as String?)?.trim();
        final country = (j['country'] as String?)?.trim();
        final parts = [if (city != null && city!.isNotEmpty) city!, if (country != null && country.isNotEmpty) country];
        label = parts.isEmpty ? null : parts.join(', ');
      }
    } catch (e) {
      debugPrint('Location failed: $e');
    }
  }

  void clear() {
    label = null;
    city = null;
    notifyListeners();
  }
}
