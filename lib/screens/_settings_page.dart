// lib/screens/_settings_page.dart
// Settings hub: search, quick toggles, and every sub-page grouped by purpose.
part of 'home_screen.dart';

class _SettingsEntry {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String keywords; // extra words the search also matches
  final Widget Function() page;
  const _SettingsEntry(this.icon, this.title, this.subtitle, this.keywords, this.page);
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  String _query = '';

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

  void _rebuild() {
    if (mounted) setState(() {});
  }

  // Sub-pages change values shown here (counts, on/off): refresh when coming back.
  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(M3SharedAxisRoute<void>(builder: (_) => page));
    _rebuild();
  }

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String _onOff(bool v) => v ? tr('set_on') : tr('set_off');

  String _assistSub() {
    final id = assistModelNotifier.value;
    if (id.isEmpty) return tr('cs_assist_same');
    final local = ModelManager.instance.byId(id);
    if (local != null) return local.fileName;
    for (final m in CloudStore.instance.chatModels) {
      if (m.id == id) return m.displayName;
    }
    return tr('cs_assist_same');
  }

  // Every page, in the order shown, grouped. Subtitles are live.
  List<(String, List<_SettingsEntry>)> _groups() {
    final lang = supportedLocaleFor(localeNotifier.value);
    final installed = ModelManager.instance.installed.length;
    final accounts = CloudStore.instance.accounts.length;
    return [
      (tr('set_my_ai'), [
        _SettingsEntry(Icons.memory_rounded, tr('nav_models'),
            tr('set_installed_n', {'n': '$installed'}), 'gguf modèle model download télécharger',
            () => const _ModelsPage()),
        _SettingsEntry(
            Icons.cloud_rounded,
            tr('cloud_title'),
            cloudEnabledNotifier.value ? tr('set_cloud_on', {'n': '$accounts'}) : tr('set_off'),
            'claude gemini chatgpt openai api key clé provider fournisseur',
            () => const CloudPage()),
        _SettingsEntry(Icons.tune_rounded, tr('set_chat'), tr('set_chat_sub'),
            'prompt temperature créativité longueur stream titre développeur', () => const ChatSettingsPage()),
        _SettingsEntry(Icons.psychology_rounded, tr('memory_title'), _onOff(memoryEnabledNotifier.value),
            'mémoire memory souvenirs', () => const MemoryPage()),
        _SettingsEntry(Icons.travel_explore_rounded, tr('set_context'), tr('set_context_sub'),
            'web recherche search localisation location voix voice whisper date', () => const ContextPage()),
        _SettingsEntry(Icons.hub_rounded, tr('set_hf'), tr('set_hf_sub'), 'hugging face token jeton', () => const HfPage()),
      ]),
      if (_android)
        (tr('set_phone'), [
          _SettingsEntry(Icons.assistant_rounded, tr('set_assistant'), _assistSub(),
              'assistant cercle circle écran verrouillé lock screen', () => const AssistantSettingsPage()),
          _SettingsEntry(Icons.phonelink_lock_rounded, tr('acc_title'), tr('acc_sub'),
              'contacts sms messages agenda calendar', () => const AccessSettingsPage()),
          _SettingsEntry(Icons.notifications_rounded, tr('n_title'), tr('n_sub'),
              'notification progression download arrière-plan', () => const NotificationsSettingsPage()),
        ])
      else
        (tr('set_phone'), [
          _SettingsEntry(Icons.notifications_rounded, tr('n_title'), tr('n_sub'),
              'notification progression download', () => const NotificationsSettingsPage()),
        ]),
      (tr('set_personal'), [
        _SettingsEntry(Icons.palette_rounded, tr('set_appearance'), tr('set_appearance_sub'),
            'thème theme couleur color police font oled animation éco vibration haptic', () => const AppearancePage()),
        _SettingsEntry(Icons.language_rounded, tr('set_language'), '${lang.flag} ${lang.nativeName}',
            'langue language idioma sprache', () => const LanguagePage()),
      ]),
      (tr('set_data'), [
        _SettingsEntry(Icons.storage_rounded, tr('set_storage'), tr('set_storage_sub'),
            'stockage storage espace cache export', () => const StoragePage()),
        _SettingsEntry(Icons.lock_rounded, tr('set_privacy'), tr('set_privacy_sub'),
            'confidentialité privacy données data cloud', () => const PrivacyPage()),
      ]),
    ];
  }

  Widget _quick(BuildContext context) {
    void flip(ValueNotifier<bool> n, String key) {
      n.value = !n.value;
      savePref(key, n.value);
      m3Haptic();
      setState(() {});
    }

    return SettingsSection(label: tr('set_quick'), children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          _QuickTile(Icons.psychology_rounded, tr('memory_title'), memoryEnabledNotifier.value,
              () => flip(memoryEnabledNotifier, 'pc_memory')),
          _QuickTile(Icons.stream_rounded, tr('cs_stream'), streamResponsesNotifier.value,
              () => flip(streamResponsesNotifier, 'pc_stream')),
          _QuickTile(Icons.battery_saver_rounded, tr('eco_mode'), ecoModeNotifier.value,
              () => flip(ecoModeNotifier, 'pc_eco_mode')),
          _QuickTile(Icons.vibration_rounded, tr('ap_haptic'), hapticFeedbackNotifier.value,
              () => flip(hapticFeedbackNotifier, 'pc_haptic_feedback')),
        ]),
      ),
    ]);
  }

  Widget _row(_SettingsEntry e) => SettingActionRow(
        icon: e.icon,
        title: e.title,
        subtitle: e.subtitle,
        onTap: () => _open(e.page()),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = _groups();
    final q = _query.trim().toLowerCase();

    final List<Widget> body;
    if (q.isNotEmpty) {
      final hits = [
        for (final g in groups)
          for (final e in g.$2)
            if ('${e.title} ${e.subtitle ?? ''} ${e.keywords}'.toLowerCase().contains(q)) e
      ];
      body = hits.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(children: [
                  Icon(Icons.search_off_rounded, size: 48, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(tr('set_no_result'), style: TextStyle(color: scheme.onSurfaceVariant)),
                ]),
              )
            ]
          : [SettingsSection(label: '${hits.length}', children: [for (final e in hits) _row(e)])];
    } else {
      body = [
        _quick(context),
        for (final g in groups) ...[
          const SizedBox(height: 20),
          SettingsSection(label: g.$1, children: [for (final e in g.$2) _row(e)]),
        ],
        const SizedBox(height: 20),
        SettingsSection(label: tr('set_about'), children: [
          SettingActionRow(
            icon: Icons.info_outline_rounded,
            title: tr('set_about'),
            onTap: () => _open(const _AboutPage()),
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
        const SizedBox(height: 16),
      ];
    }

    return Scaffold(
      appBar: M3AppBar(title: tr('nav_settings')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: Column(children: [
          M3SearchField(hint: tr('set_search_hint'), onChanged: (v) => setState(() => _query = v)),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: body,
            ),
          ),
        ]),
      ),
    );
  }
}

/// Compact on/off tile for the quick settings.
class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _QuickTile(this.icon, this.label, this.on, this.onTap);

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fg = on ? s.onPrimaryContainer : s.onSurfaceVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: on ? s.primaryContainer : s.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(on ? 22 : 16),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(label, style: t.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}
