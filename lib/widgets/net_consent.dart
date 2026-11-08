// lib/widgets/net_consent.dart
// "PicoChat wants to use the internet: allow?" Shown before any web search,
// weather, scores or map lookup (can be turned off in Settings -> Chat).
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';

Future<bool> askNetConsent(String what) async {
  final ctx = rootNavKey.currentContext;
  if (ctx == null) return false; // nobody to ask: stay offline
  final ok = await showDialog<bool>(
    context: ctx,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.public_rounded),
      title: Text(tr('net_title')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('net_body')),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Theme.of(c).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
          child: Text(what, style: Theme.of(c).textTheme.bodyMedium),
        ),
        const SizedBox(height: 12),
        Text(tr('net_note'), style: Theme.of(c).textTheme.bodySmall),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('net_deny'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('net_allow'))),
      ],
    ),
  );
  return ok ?? false;
}
