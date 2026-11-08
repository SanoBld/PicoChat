// lib/screens/_settings_page.dart
// Settings hub: links to every settings sub-page.
part of 'home_screen.dart';

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  @override
  void initState() {
    super.initState();
    localeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chevron = Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant);
    final lang = supportedLocaleFor(localeNotifier.value);

    return Scaffold(
      appBar: M3AppBar(title: tr('nav_settings')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SettingsSection(label: tr('set_general'), children: [
            SettingActionRow(
              icon: Icons.palette_rounded,
              title: tr('set_appearance'),
              subtitle: tr('set_appearance_sub'),
              trailing: chevron,
              onTap: () => _open(const AppearancePage()),
            ),
            SettingActionRow(
              icon: Icons.language_rounded,
              title: tr('set_language'),
              subtitle: '${lang.flag} ${lang.nativeName}',
              trailing: chevron,
              onTap: () => _open(const LanguagePage()),
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('set_ai'), children: [
            SettingActionRow(
              icon: Icons.tune_rounded,
              title: tr('set_chat'),
              subtitle: tr('set_chat_sub'),
              trailing: chevron,
              onTap: () => _open(const ChatSettingsPage()),
            ),
            SettingActionRow(
              icon: Icons.memory_rounded,
              title: tr('nav_models'),
              subtitle: tr('models_sub'),
              trailing: chevron,
              onTap: () => _open(const _ModelsPage()),
            ),
            SettingActionRow(
              icon: Icons.phonelink_lock_rounded,
              title: tr('acc_title'),
              subtitle: tr('acc_sub'),
              trailing: chevron,
              onTap: () => _open(const AccessSettingsPage()),
            ),
            SettingActionRow(
              icon: Icons.notifications_rounded,
              title: tr('n_title'),
              subtitle: tr('n_sub'),
              trailing: chevron,
              onTap: () => _open(const NotificationsSettingsPage()),
            ),
            SettingActionRow(
              icon: Icons.psychology_rounded,
              title: tr('memory_title'),
              subtitle: tr('memory_sub'),
              trailing: chevron,
              onTap: () => _open(const MemoryPage()),
            ),
            SettingActionRow(
              icon: Icons.travel_explore_rounded,
              title: tr('set_context'),
              subtitle: tr('set_context_sub'),
              trailing: chevron,
              onTap: () => _open(const ContextPage()),
            ),
            SettingActionRow(
              icon: Icons.hub_rounded,
              title: tr('set_hf'),
              subtitle: tr('set_hf_sub'),
              trailing: chevron,
              onTap: () => _open(const HfPage()),
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('set_data'), children: [
            SettingActionRow(
              icon: Icons.storage_rounded,
              title: tr('set_storage'),
              subtitle: tr('set_storage_sub'),
              trailing: chevron,
              onTap: () => _open(const StoragePage()),
            ),
            SettingActionRow(
              icon: Icons.lock_rounded,
              title: tr('set_privacy'),
              subtitle: tr('set_privacy_sub'),
              trailing: chevron,
              onTap: () => _open(const PrivacyPage()),
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('set_danger'), children: [
            SettingActionRow(
              icon: Icons.delete_forever_rounded,
              title: tr('reset_all'),
              subtitle: tr('reset_all_sub'),
              danger: true,
              onTap: () async {
                if (await ResetService.fullFlow(context) && context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const IntroScreen()),
                    (_) => false,
                  );
                }
              },
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('set_about'), children: [
            SettingActionRow(
              icon: Icons.info_outline_rounded,
              title: tr('set_about'),
              trailing: chevron,
              onTap: () => _open(const _AboutPage()),
            ),
          ]),
        ]),
      ),
    );
  }
}
