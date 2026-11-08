// lib/services/device_data.dart
// Optional access to the phone (Android): contacts, text messages,
// notifications, calendar. Each source is off by default, needs the Android
// permission, and is only read when the question is about it.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_state.dart';

class DeviceResult {
  final String text, step, detail;
  const DeviceResult(this.text, this.step, this.detail);
}

class DeviceData {
  static const _ch = MethodChannel('picochat/device');
  static bool get supported => !kIsWeb && Platform.isAndroid;

  static final _contactRe = RegExp(
      r"contacts?|num[ée]ro de|t[ée]l[ée]phone de|phone number|telefonnummer|n[úu]mero de tel",
      caseSensitive: false);
  static final _smsRe = RegExp(
      r"\bsms\b|\btexto|mes messages|derniers? messages?|messages? re[çc]us?|text messages?|my messages|nachrichten|mensajes",
      caseSensitive: false);
  static final _notifRe = RegExp(r"notifications?|benachrichtigung|notificaci", caseSensitive: false);
  static final _calRe = RegExp(
      r"agenda|calendrier|rendez-vous|[ée]v[ée]nements?|calendar|appointments?|meetings?|r[ée]union|planning|termine|calendario|reuni[óo]n",
      caseSensitive: false);

  // ── Permissions (used by settings and intro too) ────────────────────────────
  static const _pContacts = 'android.permission.READ_CONTACTS';
  static const _pSms = 'android.permission.READ_SMS';
  static const _pCal = 'android.permission.READ_CALENDAR';

  /// Real Android permission state, read natively (permission_handler's calendar status is unreliable).
  static Future<bool> granted(String perm) async {
    try {
      return (await _ch.invokeMethod<bool>('granted', {'p': perm})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> enable(String what) async {
    if (!supported) return false;
    switch (what) {
      case 'contacts':
        await Permission.contacts.request();
        return granted(_pContacts);
      case 'sms':
        await Permission.sms.request();
        return granted(_pSms);
      case 'calendar':
        await Permission.calendarFullAccess.request();
        if (!await granted(_pCal)) {
          // ignore: deprecated_member_use
          await Permission.calendar.request();
        }
        return granted(_pCal);
      case 'notif':
        if (await notifAccess()) return true;
        try {
          await _ch.invokeMethod('openNotifAccess');
        } catch (_) {}
        return false; // the person grants it in Android settings, then comes back
    }
    return false;
  }

  static Future<bool> notifAccess() async {
    try {
      return (await _ch.invokeMethod<bool>('notifAccess')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static const _denied = 'The user asked about this but did not give PicoChat the Android permission. '
      'Tell them to grant it in PicoChat Settings → Phone access.';

  static Future<DeviceResult?> build(String q) async {
    if (!supported) return null;
    try {
      if (accNotifNotifier.value && _notifRe.hasMatch(q)) {
        if (!await notifAccess()) return const DeviceResult(_denied, 'step_device', 'notifications');
        final l = await _list('notifications');
        return DeviceResult(
            l.isEmpty ? 'No recent notification.' : 'Recent notifications (newest first):\n${l.join('\n')}',
            'step_device', 'notifications');
      }
      if (accSmsNotifier.value && _smsRe.hasMatch(q)) {
        if (!await granted(_pSms)) return const DeviceResult(_denied, 'step_device', 'SMS');
        final l = await _list('sms', {'limit': 10});
        return DeviceResult(l.isEmpty ? 'No text message found.' : 'Latest text messages received:\n${l.join('\n')}',
            'step_device', 'SMS');
      }
      if (accCalendarNotifier.value && _calRe.hasMatch(q)) {
        if (!await granted(_pCal)) return const DeviceResult(_denied, 'step_device', 'calendar');
        final l = await _list('calendar', {'days': 14});
        return DeviceResult(l.isEmpty ? 'No event in the next 14 days.' : 'Calendar, next 14 days:\n${l.join('\n')}',
            'step_device', 'calendar');
      }
      if (accContactsNotifier.value && _contactRe.hasMatch(q)) {
        if (!await granted(_pContacts)) return const DeviceResult(_denied, 'step_device', 'contacts');
        // Names are the capitalised words of the question; nothing capitalised = list a few.
        final tokens = RegExp(r"\b[A-ZÀ-Ý][\wÀ-ÿ'-]{2,}")
            .allMatches(q)
            .map((m) => m.group(0)!)
            .where((w) => !_contactRe.hasMatch(w))
            .toSet()
            .toList();
        final l = await _list('contacts', {'tokens': tokens});
        return DeviceResult(l.isEmpty ? 'No matching contact.' : 'Contacts:\n${l.join('\n')}', 'step_device', 'contacts');
      }
    } catch (e) {
      return DeviceResult('Reading the phone data failed: $e. Tell the user.', 'step_device', 'error');
    }
    return null;
  }

  static Future<List<String>> _list(String method, [Map<String, dynamic>? args]) async {
    final r = await _ch.invokeListMethod<String>(method, args);
    return r ?? [];
  }
}
