// lib/screens/settings/appearance_page.dart
// Theme mode, visual style, accent colour, font, text size and layout.

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../services/prefs.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';
import 'settings_rows.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  String _accentKey = 'teal';
  bool _custom = false;

  @override
  void initState() {
    super.initState();
    _loadAccent();
    localeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _loadAccent() {
    final c = accentNotifier.value;
    final match = kSettingsAccentOptions.where((o) => o.$1.toARGB32() == c.toARGB32());
    _custom = match.isEmpty;
    _accentKey = match.isEmpty ? '' : match.first.$2;
  }

  Future<void> _setAccent(String key, Color color) async {
    accentNotifier.value = color;
    setState(() {
      _accentKey = key;
      _custom = false;
    });
    await savePref('pc_accent', key);
  }

  Future<void> _pickCustom() async {
    final result = await showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: accentNotifier.value),
    );
    if (result == null || !mounted) return;
    accentNotifier.value = result;
    setState(() {
      _custom = true;
      _accentKey = '';
    });
    await savePref('pc_accent', colorToHex(result));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dyn = useDynamicColorNotifier.value;

    return Scaffold(
      appBar: M3AppBar(title: tr('set_appearance')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SettingsSection(label: tr('ap_theme'), children: [
            SettingChoiceRow(
              icon: Icons.contrast_rounded,
              title: tr('ap_theme'),
              options: [
                ('system', tr('ap_system'), Icons.brightness_auto_rounded),
                ('light', tr('ap_light'), Icons.light_mode_rounded),
                ('dark', tr('ap_dark'), Icons.dark_mode_rounded),
              ],
              value: const {ThemeMode.system: 'system', ThemeMode.light: 'light', ThemeMode.dark: 'dark'}[themeModeNotifier.value]!,
              onChanged: (v) {
                themeModeNotifier.value = themeFromString(v);
                savePref('pc_theme', v);
                setState(() {});
              },
            ),
            SettingSwitchRow(
              icon: Icons.phone_android_rounded,
              title: tr('ap_oled'),
              subtitle: tr('ap_oled_sub'),
              value: oledModeNotifier.value,
              onChanged: (v) {
                oledModeNotifier.value = v;
                savePref('pc_oled_mode', v);
                setState(() {});
              },
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('ap_accent'), children: [
                SettingSwitchRow(
                  icon: Icons.wallpaper_rounded,
                  title: tr('ap_dynamic'),
                  subtitle: tr('ap_dynamic_sub'),
                  value: dyn,
                  onChanged: (v) {
                    useDynamicColorNotifier.value = v;
                    savePref('pc_use_dynamic_color', v);
                    setState(() {});
                  },
                ),
                Opacity(
                  opacity: dyn ? 0.35 : 1,
                  child: IgnorePointer(
                    ignoring: dyn,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final (color, key, label) in kSettingsAccentOptions)
                          GestureDetector(
                            onTap: () => _setAccent(key, color),
                            child: Tooltip(
                              message: tr(label),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _accentKey == key ? scheme.onSurface : Colors.transparent, width: 2.5),
                                ),
                                child: _accentKey == key
                                    ? Icon(Icons.check_rounded,
                                        size: 18,
                                        color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                                            ? Colors.white
                                            : Colors.black)
                                    : null,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: _pickCustom,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _custom ? accentNotifier.value : null,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _custom ? scheme.onSurface : scheme.outlineVariant, width: _custom ? 2.5 : 1.5),
                            ),
                            child: Icon(Icons.colorize_rounded, size: 18, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                SettingChoiceRow(
                  icon: Icons.tonality_rounded,
                  title: tr('ap_harmony'),
                  options: [
                    for (final k in const ['mono', 'tinted', 'classic', 'vivid', 'soft']) (k, tr('harmony_$k'), null),
                  ],
                  value: colorHarmonyNotifier.value,
                  onChanged: (v) {
                    colorHarmonyNotifier.value = v;
                    savePref('pc_color_harmony', v);
                    setState(() {});
                  },
                ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('ap_text'), children: [
            SettingChoiceRow(
              icon: Icons.font_download_rounded,
              title: tr('ap_font'),
              previewFonts: true,
              options: const [
                ('GoogleSansFlex', 'Google Sans Flex', null),
                ('Inter', 'Inter', null),
                ('Roboto', 'Roboto', null),
                ('OpenSans', 'Open Sans', null),
                ('SpaceGrotesk', 'Space Grotesk', null),
              ],
              value: appFontNotifier.value,
              onChanged: (v) {
                appFontNotifier.value = v;
                savePref('pc_app_font', v);
                setState(() {});
              },
            ),
            SettingSliderRow(
              icon: Icons.format_size_rounded,
              title: tr('ap_text_size'),
              valueLabel: '${(textScaleNotifier.value * 100).round()}%',
              value: textScaleNotifier.value,
              min: 0.8,
              max: 1.4,
              divisions: 6,
              onChanged: (v) {
                textScaleNotifier.value = v;
                setState(() {});
              },
              onChangeEnd: (v) => savePref('pc_text_scale', v),
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('ap_layout'), children: [
            SettingChoiceRow(
              icon: Icons.view_sidebar_rounded,
              title: tr('ap_layout'),
              description: tr('ap_layout_sub'),
              options: [
                ('auto', tr('ap_layout_auto'), Icons.devices_rounded),
                ('on', tr('ap_layout_sidebar'), Icons.view_sidebar_rounded),
                ('off', tr('ap_layout_drawer'), Icons.menu_rounded),
              ],
              value: pcModeNotifier.value,
              onChanged: (v) {
                pcModeNotifier.value = v;
                savePref('pc_layout', v);
                setState(() {});
              },
            ),
            SettingSwitchRow(
              icon: Icons.vibration_rounded,
              title: tr('ap_haptic'),
              value: hapticFeedbackNotifier.value,
              onChanged: (v) {
                hapticFeedbackNotifier.value = v;
                savePref('pc_haptic_feedback', v);
                setState(() {});
              },
            ),
            SettingTextRow(
              icon: Icons.badge_rounded,
              title: tr('ap_name'),
              keyboardType: TextInputType.text,
              hint: tr('ap_name_hint'),
              value: displayNameNotifier.value,
              onChanged: (v) {
                displayNameNotifier.value = v.trim();
                savePref('pc_display_name', v.trim());
                setState(() {});
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
