// lib/screens/settings/privacy_page.dart
// Plain-language explanation of what stays on the device and what doesn't.

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../widgets/m3_components.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = <(IconData, String, String)>[
      (Icons.phone_android_rounded, tr('pv_1_t'), tr('pv_1_s')),
      if (cloudEnabledNotifier.value)
        (Icons.cloud_upload_rounded, tr('pv_cloud_t'), tr('pv_cloud_s'))
      else
        (Icons.cloud_off_rounded, tr('pv_2_t'), tr('pv_2_s')),
      (Icons.download_rounded, tr('pv_3_t'), tr('pv_3_s')),
      (Icons.person_off_rounded, tr('pv_4_t'), tr('pv_4_s')),
    ];
    return Scaffold(
      appBar: M3AppBar(title: tr('set_privacy')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          for (final (icon, title, sub) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: M3PressCard(
                color: scheme.surfaceContainerLow,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  M3CookieBadge(size: 44, color: scheme.secondaryContainer, child: Icon(icon, color: scheme.onSecondaryContainer)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(sub, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
