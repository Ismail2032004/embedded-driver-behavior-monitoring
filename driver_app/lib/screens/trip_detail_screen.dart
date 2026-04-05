import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../providers/app_provider.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  List<TripPoint> _routePoints = [];
  bool _loadingRoute = true;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final provider = context.read<AppProvider>();
    final driverId = widget.trip.driverId.isNotEmpty
        ? widget.trip.driverId
        : provider.driverId;

    try {
      final points =
          await provider.apiService.getTripRoute(driverId, widget.trip.id);
      if (mounted) setState(() => _routePoints = points);
    } catch (e) {
      if (mounted) setState(() => _routeError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  String _durStr(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  double _calcDistance(List<TripPoint> points) {
    if (points.length < 2) return 0;
    const R = 6371.0;
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final lat1 = points[i].lat * pi / 180;
      final lat2 = points[i + 1].lat * pi / 180;
      final dLat = (points[i + 1].lat - points[i].lat) * pi / 180;
      final dLon = (points[i + 1].lon - points[i].lon) * pi / 180;
      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
      total += R * 2 * atan2(sqrt(a), sqrt(1 - a));
    }
    return total;
  }

  int _score(double aggressionRate) =>
      (((1 - aggressionRate) * 100).round()).clamp(0, 100);

  Color _scoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.amber;
    return Colors.red;
  }

  void _share(AppProvider provider) {
    final fmt = DateFormat('MMM d, y HH:mm');
    final distance = _calcDistance(_routePoints);
    final distStr = _routePoints.length >= 2
        ? '${distance.toStringAsFixed(2)} km'
        : '-- km';
    final score = _score(widget.trip.aggressionRate);
    final driverName = provider.driverName.isNotEmpty
        ? provider.driverName
        : provider.driverId;

    final summary = '''DriverMonitor Trip Summary
Driver: $driverName
Date: ${fmt.format(widget.trip.startTime.toLocal())}
Duration: ${_durStr(widget.trip.duration)}
Distance: $distStr
Driving Score: $score / 100
''';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Trip Summary'),
        content: SelectableText(summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDarkTheme;
    final bg = isDark ? const Color(0xFF0A0E1A) : Colors.white;
    final card = isDark ? const Color(0xFF1A1F2E) : Colors.grey.shade100;
    final text = isDark ? Colors.white : Colors.black87;

    final fmt = DateFormat('MMM d, y  HH:mm');

    final latLngPoints =
        _routePoints.map((p) => LatLng(p.lat, p.lon)).toList();

    final polylines = <Polyline>[];
    if (_routePoints.length > 1) {
      for (int i = 0; i < _routePoints.length - 1; i++) {
        polylines.add(Polyline(
          points: [
            LatLng(_routePoints[i].lat, _routePoints[i].lon),
            LatLng(_routePoints[i + 1].lat, _routePoints[i + 1].lon),
          ],
          color: _routePoints[i].isAggressive ? Colors.red : Colors.green,
          strokeWidth: 4,
        ));
      }
    }

    final center = latLngPoints.isNotEmpty
        ? latLngPoints[latLngPoints.length ~/ 2]
        : null;

    final distance = _calcDistance(_routePoints);
    final distStr = _routePoints.length >= 2
        ? '${distance.toStringAsFixed(2)} km'
        : '-- km';
    final score = _score(widget.trip.aggressionRate);
    final scoreColor = _scoreColor(score);
    final driverName = provider.driverName.isNotEmpty
        ? provider.driverName
        : provider.driverId;

    // Derive aggressive events from route points
    final aggressiveEvents =
        _routePoints.where((p) => p.isAggressive).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Trip Detail', style: TextStyle(color: text)),
        iconTheme: IconThemeData(color: text),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _share(provider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stats grid ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _StatRow(Icons.person_outline, 'Driver', driverName, text),
                  _StatRow(Icons.play_circle_outline, 'Start',
                      fmt.format(widget.trip.startTime.toLocal()), text),
                  if (widget.trip.endTime != null)
                    _StatRow(Icons.stop_circle_outlined, 'End',
                        fmt.format(widget.trip.endTime!.toLocal()), text),
                  _StatRow(Icons.timer_outlined, 'Duration',
                      _durStr(widget.trip.duration), text),
                  _StatRow(Icons.straighten, 'Distance', distStr, text),
                  _StatRow(Icons.data_usage, 'Data Points',
                      '${widget.trip.totalWindows}', text),
                  _StatRow(Icons.warning_amber_outlined, 'Aggressive Moments',
                      '${widget.trip.aggressiveWindows}', text),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.stars_outlined,
                                size: 16,
                                color: text.withValues(alpha: 0.5)),
                            const SizedBox(width: 8),
                            Text('Driving Score',
                                style: TextStyle(
                                    color: text.withValues(alpha: 0.6))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: scoreColor, width: 1.5),
                          ),
                          child: Text(
                            '$score / 100',
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Legend ──
            Row(
              children: [
                _Legend('Normal', Colors.green),
                const SizedBox(width: 16),
                _Legend('Aggressive', Colors.red),
              ],
            ),
            const SizedBox(height: 8),

            // ── Map ──
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 320,
                  child: _buildMap(
                      card, text, latLngPoints, polylines, center),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Aggressive events list ──
            _AggressiveEventsList(
                events: aggressiveEvents,
                loading: _loadingRoute,
                card: card,
                text: text),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(
    Color card,
    Color text,
    List<LatLng> latLngPoints,
    List<Polyline> polylines,
    LatLng? center,
  ) {
    if (_loadingRoute) {
      return Container(
        color: card,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_routeError != null) {
      return Container(
        color: card,
        child: Center(
          child:
              Text('Failed to load route', style: TextStyle(color: text)),
        ),
      );
    }

    if (latLngPoints.isEmpty) {
      return Container(
        color: card,
        child: Center(
          child: Text('No route data available',
              style: TextStyle(color: text)),
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(initialCenter: center!, initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.driver_monitor',
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(
          markers: [
            Marker(
              point: latLngPoints.first,
              width: 36,
              height: 36,
              child: const Icon(Icons.trip_origin,
                  color: Colors.green, size: 28),
            ),
            Marker(
              point: latLngPoints.last,
              width: 36,
              height: 36,
              child:
                  const Icon(Icons.flag, color: Colors.red, size: 28),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Aggressive events list ────────────────────────────────────────────────────

class _AggressiveEventsList extends StatelessWidget {
  final List<TripPoint> events;
  final bool loading;
  final Color card;
  final Color text;

  const _AggressiveEventsList({
    required this.events,
    required this.loading,
    required this.card,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Text(
                'Aggressive Events',
                style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              if (events.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    '${events.length}',
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.green.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'No aggressive events recorded',
                    style: TextStyle(
                        color: text.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) =>
                  _EventRow(point: events[i], index: i + 1, text: text),
            ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final TripPoint point;
  final int index;
  final Color text;

  const _EventRow(
      {required this.point, required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${point.timestamp.toLocal().hour.toString().padLeft(2, '0')}:'
        '${point.timestamp.toLocal().minute.toString().padLeft(2, '0')}:'
        '${point.timestamp.toLocal().second.toString().padLeft(2, '0')}';
    final hasGps = point.lat != 0 || point.lon != 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.red, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
                if (hasGps)
                  Text(
                    '${point.lat.toStringAsFixed(5)}, ${point.lon.toStringAsFixed(5)}',
                    style: TextStyle(
                      color: text.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '#$index',
            style: TextStyle(
              color: Colors.red.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color text;
  const _StatRow(this.icon, this.label, this.value, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: text.withValues(alpha: 0.45)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(color: text.withValues(alpha: 0.6))),
          ),
          Text(value,
              style:
                  TextStyle(color: text, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
