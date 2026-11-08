// lib/services/prefs.dart
// Tiny helpers around SharedPreferences used by every settings page.

import 'package:shared_preferences/shared_preferences.dart';

Future<void> savePref(String key, Object value) async {
  final p = await SharedPreferences.getInstance();
  if (value is bool) {
    await p.setBool(key, value);
  } else if (value is int) {
    await p.setInt(key, value);
  } else if (value is double) {
    await p.setDouble(key, value);
  } else if (value is String) {
    await p.setString(key, value);
  }
}
