// lib/screens/_about_page.dart
// App name, version, engine in use and useful links.
part of 'home_screen.dart';

class _AboutPage extends StatefulWidget {
  const _AboutPage();

  @override
  State<_AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<_AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = '${i.version} (${i.buildNumber})');
    }).catchError((_) {});
  }

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final engine = InferenceService.engine;

    return Scaffold(
      appBar: M3AppBar(title: tr('set_about')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: M3CookieBadge(
              size: 96,
              color: scheme.primary,
              child: BrandIcon('assets/icons/app_logo.svg', Icons.sentiment_satisfied_rounded, size: 48, color: scheme.onPrimary),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text('PicoChat', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
          if (_version.isNotEmpty)
            Center(child: Text(_version, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
          const SizedBox(height: 8),
          Text(tr('app_tagline'), textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          SettingsSection(label: tr('about_info'), children: [
            SettingTile(
              leading: const Icon(Icons.bolt_rounded),
              title: Text(tr('about_engine')),
              subtitle: Text(engine.isPlaceholder ? tr('about_engine_demo') : engine.name),
            ),
            SettingTile(
              leading: const Icon(Icons.folder_rounded),
              title: Text(tr('about_models_dir')),
              subtitle: Text(ModelManager.instance.directory?.path ?? '—'),
            ),
          ]),
          const SizedBox(height: 20),
          SettingsSection(label: tr('about_links'), children: [
            SettingActionRow(
              icon: Icons.code_rounded,
              title: 'GitHub',
              subtitle: 'github.com/SanoBld/PicoChat',
              onTap: () => _open('https://github.com/SanoBld/PicoChat'),
            ),
            SettingActionRow(
              icon: Icons.hub_rounded,
              title: 'Hugging Face',
              subtitle: 'huggingface.co',
              onTap: () => _open(HfService.base),
            ),
            SettingActionRow(
              icon: Icons.description_outlined,
              title: tr('about_licenses'),
              onTap: () => showLicensePage(context: context, applicationName: 'PicoChat'),
            ),
          ]),
        ]),
      ),
    );
  }
}
