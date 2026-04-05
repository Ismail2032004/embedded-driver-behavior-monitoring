import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../providers/app_provider.dart';
import 'connect_screen.dart';
import 'trip_detail_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  final bool embedded;
  const TripHistoryScreen({super.key, this.embedded = false});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<Trip> _trips = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    final driverId = provider.driverId;
    if (driverId.isEmpty) {
      setState(() => _error = 'Not logged in. Please log in to view trips.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await provider.apiService.getTrips(driverId);
      setState(() => _trips = trips);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _goBack(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ConnectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDarkTheme;
    final bg = isDark ? const Color(0xFF0f1117) : Colors.white;
    final card = isDark ? const Color(0xFF1a1d2e) : Colors.grey.shade100;
    final text = isDark ? Colors.white : Colors.black87;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: text)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    } else if (_trips.isEmpty) {
      body = Center(
        child: Text('No trips found', style: TextStyle(color: text)),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _trips.length,
          itemBuilder: (_, i) => _TripCard(
            trip: _trips[i],
            card: card,
            text: text,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TripDetailScreen(trip: _trips[i]),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.embedded) return body;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _goBack(context),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: text),
            onPressed: () => _goBack(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trip History',
                  style: TextStyle(color: text, fontSize: 16)),
              if (provider.driverName.isNotEmpty)
                Text(
                  provider.driverName,
                  style: TextStyle(
                    color: text.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: text),
              onPressed: _load,
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final Color card;
  final Color text;
  final VoidCallback onTap;

  const _TripCard({
    required this.trip,
    required this.card,
    required this.text,
    required this.onTap,
  });

  int _score(double aggressionRate) =>
      (((1 - aggressionRate) * 100).round()).clamp(0, 100);

  Color _scoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final score = _score(trip.aggressionRate);
    final scoreColor = _scoreColor(score);
    final fmt = DateFormat('MMM d, y  HH:mm');

    String durStr(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final s = d.inSeconds % 60;
      if (h > 0) return '${h}h ${m}m';
      return '${m}m ${s}s';
    }

    return Card(
      color: card,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.route, color: Colors.blue.shade400, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fmt.format(trip.startTime.toLocal()),
                        style: TextStyle(
                            color: text, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 13,
                            color: text.withValues(alpha: 0.5)),
                        const SizedBox(width: 3),
                        Text(
                          durStr(trip.duration),
                          style: TextStyle(
                              color: text.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.straighten,
                            size: 13,
                            color: text.withValues(alpha: 0.5)),
                        const SizedBox(width: 3),
                        Text(
                          '-- km',
                          style: TextStyle(
                              color: text.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scoreColor, width: 1.5),
                    ),
                    child: Text(
                      '$score',
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'score',
                    style: TextStyle(
                        color: text.withValues(alpha: 0.45), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
