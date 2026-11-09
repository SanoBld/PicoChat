// lib/widgets/error_card.dart
// A failed answer, drawn in the app's style: round badge, short title,
// one clear sentence, a Retry button and the technical detail on demand.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../l10n/l10n.dart';
import 'm3_components.dart' show M3CookieBadge;

class ErrorCard extends StatefulWidget {
  const ErrorCard({super.key, required this.kind, required this.detail, this.onRetry});

  /// CloudErrorKind name, "local" (on-device model), or '' (old saved message).
  final String kind;

  /// Raw message of the engine or the provider (shown under "Details").
  final String detail;

  /// Null = no retry button (the failed answer is not the last one).
  final VoidCallback? onRetry;

  @override
  State<ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<ErrorCard> {
  bool _open = false;

  static const _known = {
    'auth', 'rateLimit', 'notFound', 'badRequest', 'server', 'network', 'blocked', 'empty', 'local', 'other',
  };

  static IconData _icon(String k) => switch (k) {
        'auth' => Icons.lock_rounded,
        'rateLimit' => Icons.hourglass_top_rounded,
        'notFound' => Icons.search_off_rounded,
        'badRequest' => Icons.report_problem_rounded,
        'server' => Icons.cloud_off_rounded,
        'network' => Icons.wifi_off_rounded,
        'blocked' => Icons.block_rounded,
        'empty' => Icons.speaker_notes_off_rounded,
        _ => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final legacy = !_known.contains(widget.kind); // saved before error kinds existed
    final kind = legacy ? 'other' : widget.kind;
    final title = tr('err_t_$kind');
    final body = legacy ? (widget.detail.isNotEmpty ? widget.detail : tr('gen_failed')) : tr('err_b_$kind');
    final detail = legacy ? '' : widget.detail.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 12),
      decoration: ShapeDecoration(
        color: s.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          M3CookieBadge(size: 44, color: s.error, child: Icon(_icon(kind), color: s.onError, size: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 2),
              Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: s.onErrorContainer)),
              const SizedBox(height: 3),
              Text(body, style: t.bodyMedium?.copyWith(color: s.onErrorContainer.withValues(alpha: 0.85))),
            ]),
          ),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: _open && detail.isNotEmpty
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(
                    color: s.onErrorContainer.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: SelectableText(detail,
                      style: t.bodySmall?.copyWith(fontFamily: 'monospace', color: s.onErrorContainer)),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (widget.onRetry != null || detail.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (widget.onRetry != null)
              FilledButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(tr('retry')),
                style: FilledButton.styleFrom(
                  backgroundColor: s.error,
                  foregroundColor: s.onError,
                  shape: const StadiumBorder(),
                ),
              ),
            if (detail.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _open = !_open),
                onLongPress: () => Clipboard.setData(ClipboardData(text: detail)),
                icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                label: Text(tr(_open ? 'err_hide' : 'err_details')),
                style: TextButton.styleFrom(foregroundColor: s.onErrorContainer, shape: const StadiumBorder()),
              ),
          ]),
        ],
      ]),
    );
  }
}
