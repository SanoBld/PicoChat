// lib/screens/settings/hf_page.dart
// Hugging Face access: optional token (gated / private models) and endpoint.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../services/prefs.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';
import 'settings_rows.dart';

class HfPage extends StatefulWidget {
  const HfPage({super.key});

  @override
  State<HfPage> createState() => _HfPageState();
}

class _HfPageState extends State<HfPage> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final token = hfTokenNotifier.value;

    return Scaffold(
      appBar: M3AppBar(title: tr('set_hf')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(24)),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('hf_info'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
            ]),
          ),
          const SizedBox(height: 20),
          SettingsSection(label: tr('hf_access'), children: [
            SettingTextRow(
              icon: Icons.key_rounded,
              title: tr('hf_token'),
              hint: 'hf_…',
              value: token.isEmpty ? '' : '••••••••${token.length > 4 ? token.substring(token.length - 4) : ''}',
              onChanged: (v) {
                final clean = v.trim();
                if (clean.contains('•')) return; // untouched masked value
                hfTokenNotifier.value = clean;
                savePref('pc_hf_token', clean);
                setState(() {});
              },
            ),
            SettingActionRow(
              icon: Icons.open_in_new_rounded,
              title: tr('hf_get_token'),
              onTap: () => launchUrl(Uri.parse('https://huggingface.co/settings/tokens'), mode: LaunchMode.externalApplication),
            ),
            if (token.isNotEmpty)
              SettingActionRow(
                icon: Icons.delete_outline_rounded,
                title: tr('hf_remove_token'),
                danger: true,
                onTap: () {
                  hfTokenNotifier.value = '';
                  savePref('pc_hf_token', '');
                  setState(() {});
                },
              ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('hf_advanced'), children: [
            SettingTextRow(
              icon: Icons.dns_rounded,
              title: tr('hf_endpoint'),
              hint: kDefaultHfEndpoint,
              keyboardType: TextInputType.url,
              value: hfEndpointNotifier.value,
              onChanged: (v) {
                final clean = v.trim().isEmpty ? kDefaultHfEndpoint : v.trim();
                hfEndpointNotifier.value = clean;
                savePref('pc_hf_endpoint', clean);
                setState(() {});
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
