// lib/widgets/map_card.dart
// OpenStreetMap card: a position pin, or a route drawn as a clean line.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/l10n.dart';

class MapCard extends StatelessWidget {
  final Map<String, dynamic> d;
  const MapCard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final pts = [
      for (final p in (d['pts'] as List)) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ];
    if (pts.isEmpty) return const SizedBox.shrink();
    final here = d['mode'] == 'here';
    final mode = '${d['mode']}';
    final icon = mode == 'foot'
        ? Icons.directions_walk_rounded
        : mode == 'bike'
            ? Icons.directions_bike_rounded
            : Icons.directions_car_rounded;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget marker(Color c, IconData i) => Container(
          decoration: BoxDecoration(
              color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)]),
          child: Icon(i, color: Colors.white, size: 18),
        );

    final map = FlutterMap(
      options: MapOptions(
        initialCenter: pts.first,
        initialZoom: 16,
        initialCameraFit: here
            ? null
            : CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(36)),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
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
        if (!here && pts.length > 1)
          PolylineLayer(polylines: [
            Polyline(points: pts, strokeWidth: 9, color: Colors.white, strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round),
            Polyline(points: pts, strokeWidth: 5, color: s.primary, strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round),
          ]),
        MarkerLayer(markers: [
          if (here)
            Marker(point: pts.first, width: 40, height: 40, child: marker(s.primary, Icons.my_location_rounded))
          else ...[
            Marker(point: pts.first, width: 30, height: 30, child: marker(s.tertiary, Icons.trip_origin_rounded)),
            Marker(point: pts.last, width: 34, height: 34, child: marker(s.error, Icons.flag_rounded)),
          ],
        ]),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution('© OpenStreetMap')],
        ),
      ],
    );

    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        color: s.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 230, child: map),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: here
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d['title']}', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  if ('${d['sub']}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${d['sub']}', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                    ),
                ])
              : Row(children: [
                  Icon(icon, color: s.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${(d['min'] as num) >= 60 ? '${(d['min'] as num) ~/ 60} h ${(d['min'] as num) % 60} min' : '${d['min']} min'}'
                          '  ·  ${(d['km'] as num).toStringAsFixed(1)} km',
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${d['from']} → ${d['to']}',
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                    ]),
                  ),
                ]),
        ),
      ]),
    );
  }
}
