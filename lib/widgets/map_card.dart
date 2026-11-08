// lib/widgets/map_card.dart
// Interactive OpenStreetMap card. Long-press adds a point, tap a point to remove it,
// "Route" draws a line through the points in order (car / foot / bike).
// The AI can add points and routes too (see MapService tags).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/l10n.dart';
import '../services/map_service.dart';

class MapCard extends StatefulWidget {
  final Map<String, dynamic> d;
  const MapCard({super.key, required this.d});

  @override
  State<MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<MapCard> {
  final _ctrl = MapController();
  bool _busy = false;
  String? _err;

  Map<String, dynamic> get d => widget.d;

  List<Map<String, dynamic>> get _marks {
    final m = d['marks'];
    if (m is List) return m.cast<Map<String, dynamic>>();
    // Cards saved by an older version: derive the points from the line.
    final p = (d['pts'] as List?) ?? [];
    final out = <Map<String, dynamic>>[
      if (p.isNotEmpty) {'lat': p.first[0], 'lon': p.first[1], 'label': '${d['from'] ?? d['title'] ?? ''}'},
      if (p.length > 1) {'lat': p.last[0], 'lon': p.last[1], 'label': '${d['to'] ?? ''}'},
    ];
    d['marks'] = out;
    return out;
  }

  List<LatLng> get _line => [
        for (final p in ((d['pts'] as List?) ?? [])) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];

  LatLng _at(Map<String, dynamic> m) => LatLng((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble());

  void _add(LatLng p) {
    setState(() {
      _marks.add({'lat': p.latitude, 'lon': p.longitude, 'label': '${tr('map_point')} ${_marks.length + 1}'});
      d['mode'] = d['mode'] == 'here' ? 'marks' : d['mode'];
      _err = null;
    });
  }

  void _remove(int i) {
    setState(() {
      _marks.removeAt(i);
      d['pts'] = [];
      d.remove('km');
      d.remove('min');
      if (d['mode'] == 'here') d['mode'] = 'marks';
    });
  }

  void _clear() => setState(() {
        _marks.clear();
        d['pts'] = [];
        d.remove('km');
        d.remove('min');
        _err = null;
      });

  Future<void> _route(String mode) async {
    if (_marks.length < 2) {
      setState(() => _err = tr('map_need_two'));
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await MapService.routeVia([for (final m in _marks) [(m['lat'] as num).toDouble(), (m['lon'] as num).toDouble()]], mode);
      if (r == null) {
        _err = tr('map_no_route');
      } else {
        d['pts'] = r['pts'];
        d['km'] = r['km'];
        d['min'] = r['min'];
        d['mode'] = mode;
        d['from'] = '${_marks.first['label']}';
        d['to'] = '${_marks.last['label']}';
        final line = _line;
        if (line.length > 1) {
          _ctrl.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(line), padding: const EdgeInsets.all(36)));
        }
      }
    } catch (_) {
      _err = tr('map_no_route');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final marks = _marks;
    final line = _line;
    final all = [...line, for (final m in marks) _at(m)];
    if (all.isEmpty && marks.isEmpty) return const SizedBox.shrink();
    final mode = '${d['mode']}';
    final hasRoute = line.length > 1 && d['km'] != null;
    final icon = mode == 'foot'
        ? Icons.directions_walk_rounded
        : mode == 'bike'
            ? Icons.directions_bike_rounded
            : Icons.directions_car_rounded;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget pin(Color c, Widget child) => Container(
          decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)]),
          child: Center(child: child),
        );

    final map = FlutterMap(
      mapController: _ctrl,
      options: MapOptions(
        initialCenter: all.first,
        initialZoom: 16,
        initialCameraFit: all.length > 1
            ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(all), padding: const EdgeInsets.all(36))
            : null,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onLongPress: (_, p) => _add(p),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.picochat.app',
          tileBuilder: dark
              ? (ctx, tile, _) => ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      -0.8, 0, 0, 0, 255, 0, -0.8, 0, 0, 255, 0, 0, -0.8, 0, 255, 0, 0, 0, 1, 0,
                    ]),
                    child: tile,
                  )
              : null,
        ),
        if (line.length > 1)
          PolylineLayer(polylines: [
            Polyline(points: line, strokeWidth: 9, color: Colors.white, strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round),
            Polyline(points: line, strokeWidth: 5, color: s.primary, strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round),
          ]),
        MarkerLayer(markers: [
          for (var i = 0; i < marks.length; i++)
            Marker(
              point: _at(marks[i]),
              width: 34,
              height: 34,
              child: GestureDetector(
                onTap: () => _remove(i),
                child: marks.length == 1 && d['mode'] == 'here'
                    ? pin(s.primary, const Icon(Icons.my_location_rounded, color: Colors.white, size: 18))
                    : pin(
                        i == 0 ? s.tertiary : (i == marks.length - 1 ? s.error : s.primary),
                        Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
              ),
            ),
        ]),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution('© OpenStreetMap')],
        ),
      ],
    );

    String dur(num m) => m >= 60 ? '${m ~/ 60} h ${(m % 60).round()} min' : '${m.round()} min';

    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        color: s.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 240, child: map),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
          child: hasRoute
              ? Row(children: [
                  Icon(icon, color: s.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${dur(d['min'] as num)}  ·  ${(d['km'] as num).toStringAsFixed(1)} km',
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${d['from']} → ${d['to']}',
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                    ]),
                  ),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d['title'] ?? (marks.isEmpty ? '' : marks.map((m) => m['label']).join(' · '))}',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  if ('${d['sub'] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${d['sub']}', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                    ),
                ]),
        ),
        // Touch controls: route through the points, clear them.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Wrap(spacing: 6, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (_busy)
              const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)))
            else ...[
              IconButton(tooltip: tr('map_car'), icon: const Icon(Icons.directions_car_rounded), onPressed: () => _route('car')),
              IconButton(tooltip: tr('map_foot'), icon: const Icon(Icons.directions_walk_rounded), onPressed: () => _route('foot')),
              IconButton(tooltip: tr('map_bike'), icon: const Icon(Icons.directions_bike_rounded), onPressed: () => _route('bike')),
            ],
            IconButton(tooltip: tr('map_clear'), icon: const Icon(Icons.layers_clear_rounded), onPressed: _clear),
            if (all.length > 1)
              IconButton(
                tooltip: tr('map_fit'),
                icon: const Icon(Icons.center_focus_strong_rounded),
                onPressed: () => _ctrl.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(all), padding: const EdgeInsets.all(36))),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Text(_err ?? tr('map_hint'),
              style: t.bodySmall?.copyWith(color: _err == null ? s.onSurfaceVariant : s.error)),
        ),
      ]),
    );
  }
}
