// lib/widgets/info_cards.dart
// Visual cards drawn by the app from real data (weather, scores, calculator)
// and the collapsible timeline of what the AI did.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import 'm3_components.dart' show M3CookieBadge;
import 'map_card.dart';
import 'pc_motion.dart';
import 'skeleton.dart' show M3Spinner;

class InfoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const InfoCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final w = switch (data['type']) {
      'weather' => _WeatherCard(d: data),
      'score' => _ScoreCards(d: data),
      'calc' => _CalcCard(d: data),
      'map' => MapCard(d: data),
      _ => const SizedBox.shrink(),
    };
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: FadeSlideIn(child: w));
  }
}

ShapeDecoration _deco(Color c, {Color? border}) => ShapeDecoration(
      color: c,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: border == null ? BorderSide.none : BorderSide(color: border, width: 1.5),
      ),
    );

// ── Calculator ───────────────────────────────────────────────────────────────

class _CalcCard extends StatelessWidget {
  final Map<String, dynamic> d;
  const _CalcCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 20, 14),
      decoration: _deco(s.primaryContainer),
      child: Row(children: [
        M3CookieBadge(size: 48, color: s.primary, child: Icon(Icons.calculate_rounded, color: s.onPrimary)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d['expr']}', style: t.bodyMedium?.copyWith(color: s.onPrimaryContainer.withValues(alpha: 0.75))),
            const SizedBox(height: 2),
            Text('= ${d['result']}',
                style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: s.onPrimaryContainer)),
          ]),
        ),
      ]),
    );
  }
}

// ── Weather ──────────────────────────────────────────────────────────────────

IconData _wxIcon(int code, bool day) {
  if (code == 0) return day ? Icons.wb_sunny_rounded : Icons.nightlight_round;
  if (code <= 2) return day ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 57) return Icons.grain_rounded;
  if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return Icons.water_drop_rounded;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return Icons.ac_unit_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  return Icons.cloud_rounded;
}

String _wxLabel(int code) {
  final k = code == 0
      ? 'clear'
      : code <= 2
          ? 'partly'
          : code == 3
              ? 'cloudy'
              : (code == 45 || code == 48)
                  ? 'fog'
                  : (code >= 51 && code <= 57)
                      ? 'drizzle'
                      : ((code >= 61 && code <= 67))
                          ? 'rain'
                          : ((code >= 71 && code <= 77) || code == 85 || code == 86)
                              ? 'snow'
                              : (code >= 80 && code <= 82)
                                  ? 'showers'
                                  : 'storm';
  return tr('wx_$k');
}

const _days = {
  'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
  'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
  'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
};

class _WeatherCard extends StatelessWidget {
  final Map<String, dynamic> d;
  const _WeatherCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final code = (d['code'] as num).toInt();
    final day = d['day'] == true;
    final days = (d['days'] as List).cast<Map>();
    final names = _days[localeNotifier.value] ?? _days['en']!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.primaryContainer, s.tertiaryContainer],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.location_on_rounded, size: 16, color: s.onPrimaryContainer),
          const SizedBox(width: 4),
          Expanded(
            child: Text('${d['place']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: s.onPrimaryContainer)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Icon(_wxIcon(code, day), size: 64, color: s.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (d['temp'] as num).toDouble()),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text('${v.round()}°',
                    style: t.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: s.onPrimaryContainer, height: 1)),
              ),
              Text(_wxLabel(code), style: t.titleMedium?.copyWith(color: s.onPrimaryContainer)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip(s, Icons.thermostat_rounded, '${tr('wx_feels')} ${d['feels']}°'),
          _chip(s, Icons.air_rounded, '${d['wind']} km/h'),
          _chip(s, Icons.water_drop_outlined, '${d['hum']}%'),
        ]),
        const SizedBox(height: 14),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, e) in days.indexed)
            Expanded(
              child: FadeSlideIn(
                delay: Duration(milliseconds: 120 + i * 70),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: _deco(s.surface.withValues(alpha: 0.55)),
                  child: Column(children: [
                    Text(i == 0 ? tr('wx_today') : names[(DateTime.parse('${e['d']}').weekday - 1) % 7],
                        style: t.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: s.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Icon(_wxIcon((e['code'] as num).toInt(), true), size: 22, color: s.primary),
                    const SizedBox(height: 4),
                    Text('${e['max']}°', style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${e['min']}°', style: t.labelSmall?.copyWith(color: s.onSurfaceVariant)),
                    SizedBox(
                      height: 16,
                      child: (e['rain'] as num) >= 30
                          ? Text('${e['rain']}%', style: t.labelSmall?.copyWith(color: s.tertiary, fontWeight: FontWeight.w700))
                          : null,
                    ),
                  ]),
                ),
              ),
            ),
        ])),
      ]),
    );
  }

  Widget _chip(ColorScheme s, IconData i, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: _deco(s.surface.withValues(alpha: 0.55)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 16, color: s.primary),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.onSurface)),
        ]),
      );
}

// ── Scores ───────────────────────────────────────────────────────────────────

class _ScoreCards extends StatelessWidget {
  final Map<String, dynamic> d;
  const _ScoreCards({required this.d});

  @override
  Widget build(BuildContext context) {
    final ms = (d['matches'] as List).cast<Map>();
    return Column(children: [
      for (final (i, m) in ms.indexed)
        Padding(
          padding: EdgeInsets.only(bottom: i == ms.length - 1 ? 0 : 8),
          child: _ScoreCard(m: m),
        ),
    ]);
  }
}

class _ScoreCard extends StatelessWidget {
  final Map m;
  const _ScoreCard({required this.m});

  Widget _team(BuildContext c, Map t) {
    final s = Theme.of(c).colorScheme;
    final logo = t['logo'] as String?;
    return Expanded(
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(8),
          decoration: ShapeDecoration(color: s.surface, shape: const CircleBorder()),
          child: logo == null
              ? Icon(Icons.shield_rounded, color: s.primary)
              : Image.network(logo, fit: BoxFit.contain, errorBuilder: (_, _, _) => Icon(Icons.shield_rounded, color: s.primary)),
        ),
        const SizedBox(height: 6),
        Text('${t['name']}',
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(c).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final state = '${m['state']}';
    final live = state == 'in';
    final pre = state == 'pre';
    final home = (m['home']['score'] as num).toInt();
    final away = (m['away']['score'] as num).toInt();
    String status;
    if (live) {
      status = '${m['clock']}'.isNotEmpty && '${m['clock']}' != '0:00' ? '${m['clock']}' : '${m['detail']}';
    } else if (pre) {
      final dt = DateTime.tryParse('${m['date']}')?.toLocal();
      status = dt == null ? '${m['detail']}' : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      status = tr('score_final');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: _deco(live ? s.errorContainer : s.secondaryContainer),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text('${m['league']}', style: t.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: s.onSurfaceVariant))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: _deco(live ? s.error : s.surface),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (live) ...[
                PulseScale(active: true, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: s.onError, shape: BoxShape.circle))),
                const SizedBox(width: 6),
                Text('${tr('score_live')} · ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: s.onError)),
              ],
              Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: live ? s.onError : s.onSurface)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _team(context, m['home'] as Map),
          SizedBox(
            width: 112,
            child: pre
                ? Padding(padding: const EdgeInsets.only(top: 12), child: Text('VS', textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _num(context, home),
                    Text(' – ', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    _num(context, away),
                  ]),
          ),
          _team(context, m['away'] as Map),
        ]),
      ]),
    );
  }

  Widget _num(BuildContext c, int v) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: v.toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, x, _) => Text('${x.round()}',
            style: Theme.of(c).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, height: 1.1)),
      );
}

// ── Timeline: what the AI did ────────────────────────────────────────────────

class StepsTimeline extends StatefulWidget {
  final List<Map<String, String>> steps;
  final bool running;
  const StepsTimeline({super.key, required this.steps, required this.running});

  @override
  State<StepsTimeline> createState() => _StepsTimelineState();
}

class _StepsTimelineState extends State<StepsTimeline> {
  bool? _open; // null = automatic (open while running if the option is on)

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    // "Analyse", "write", "load model" are not worth showing: only real work
    // (reasoning, web search/reading, files, commands).
    const trivial = {'step_analyze', 'step_write', 'step_load'};
    final steps = [for (final st in widget.steps) if (!trivial.contains(st['title'])) st];
    if (steps.isEmpty) return const SizedBox.shrink();
    final open = _open ?? (widget.running && stepsOpenNotifier.value);
    final n = steps.length;
    return FadeSlideIn(
      child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        decoration: _deco(s.surfaceContainerHigh),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => setState(() => _open = !open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              child: Row(children: [
                widget.running
                    ? SizedBox(width: 18, height: 18, child: M3Spinner(color: s.primary))
                    : Icon(Icons.auto_awesome_rounded, size: 18, color: s.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.running ? tr('steps_running') : '${tr('steps_title')} · $n',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: s.onSurfaceVariant),
                ),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Column(children: [
                      for (final (i, st) in steps.indexed)
                        _StepRow(step: st, last: i == n - 1, running: widget.running && i == n - 1),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    ));
  }
}

class _StepRow extends StatefulWidget {
  final Map<String, String> step;
  final bool last;
  final bool running;
  const _StepRow({required this.step, required this.last, required this.running});

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> {
  bool _full = false;

  // Searches / sources: small chips side by side. Anything else: 2 lines, tap for more.
  Widget _detail(BuildContext context, String detail, bool long, TextTheme t, ColorScheme s) {
    final title = widget.step['title'] ?? '';
    if (title == 'step_search' || title == 'step_plan') {
      final qs = detail.split('\n').where((e) => e.trim().isNotEmpty).toList();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(spacing: 5, runSpacing: 4, children: [
          for (final q in qs)
            Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: s.secondaryContainer, borderRadius: BorderRadius.circular(8)),
              child: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: s.onSecondaryContainer)),
            ),
        ]),
      );
    }
    return MouseRegion(
      cursor: long ? SystemMouseCursors.click : MouseCursor.defer,
      child: PcGesture(
        onTap: long ? () => setState(() => _full = !_full) : null,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Text(detail,
              maxLines: _full ? null : 2,
              overflow: _full ? TextOverflow.visible : TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(color: s.onSurfaceVariant, height: 1.25)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final detail = widget.step['detail'] ?? '';
    final long = detail.length > 90;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 28,
          child: Column(children: [
            widget.running
                ? PulseScale(active: true, child: M3CookieBadge(size: 24, color: s.tertiary, child: Icon(Icons.more_horiz_rounded, size: 14, color: s.onTertiary)))
                : M3CookieBadge(size: 24, color: s.primary, child: Icon(Icons.check_rounded, size: 14, color: s.onPrimary)),
            if (!widget.last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: s.primary.withValues(alpha: 0.35))),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.last ? 0 : 8, top: 1),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(widget.step['title'] ?? ''), style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              if (detail.isNotEmpty) _detail(context, detail, long, t, s),
            ]),
          ),
        ),
      ]),
    );
  }
}
