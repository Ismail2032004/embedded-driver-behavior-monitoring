import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/telemetry_data.dart';
import 'login_screen.dart';
import 'trip_history_screen.dart';

// ── Theme constants ───────────────────────────────────────────────────────────

const _kDarkBg   = Color(0xFF0A0E1A);
const _kDarkCard = Color(0xFF1A1F2E);

// Sensor accent colours
const _cSpeed  = Color(0xFF38BDF8);
const _cRpm    = Color(0xFFA78BFA);
const _cThrottle = Color(0xFF818CF8);
const _cLongAcc  = Color(0xFFF87171);
const _cLatAcc   = Color(0xFFFB923C);
const _cYaw      = Color(0xFFF59E0B);
const _cConf     = Color(0xFF34D399);
const _cGps      = Color(0xFF2DD4BF);

// ── Screen ───────────────────────────────────────────────────────────────────

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  int _tabIndex = 0;
  final _driverIdController = TextEditingController();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _driverIdController.text = context.read<AppProvider>().driverId;
  }

  @override
  void dispose() {
    _driverIdController.dispose();
    super.dispose();
  }

  void _openSettings() {
    final provider = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: provider.isDarkTheme ? _kDarkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettingsSheet(provider: provider, onLogout: _logout),
    );
  }

  Future<void> _logout() async {
    final provider = context.read<AppProvider>();
    await provider.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDarkTheme;
    final bg = isDark ? _kDarkBg : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green.shade400,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'DriverMonitor',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: isDark ? Colors.white70 : Colors.black54),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          _SessionAlertsBar(
              alerts: context.watch<AppProvider>().sessionAlerts),
          Expanded(
            child: _tabIndex == 0
                ? _LiveTab(
                    mapController: _mapController,
                    driverIdController: _driverIdController,
                  )
                : const TripHistoryScreen(embedded: true),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: isDark ? _kDarkCard : Colors.white,
        selectedItemColor: Colors.blue.shade400,
        unselectedItemColor: Colors.grey.shade600,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Trips'),
        ],
      ),
    );
  }
}

// ── Live tab ─────────────────────────────────────────────────────────────────

class _LiveTab extends StatelessWidget {
  final MapController mapController;
  final TextEditingController driverIdController;

  const _LiveTab({
    required this.mapController,
    required this.driverIdController,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDarkTheme;
    final data = provider.latest;
    final card = isDark ? _kDarkCard : Colors.grey.shade100;
    final text = isDark ? Colors.white : Colors.black87;

    final isAgg = data?.isAggressive ?? false;
    final statusColor = isAgg ? Colors.red.shade400 : Colors.green.shade400;
    final statusLabel = isAgg ? 'AGGRESSIVE' : 'NORMAL';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Latency badges row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _LatencyBadge(
                  prefix: 'BLE',
                  value: provider.avgBleLatencyMs,
                  color: _cGps),
              const SizedBox(width: 8),
              _LatencyBadge(
                  prefix: 'INF',
                  value: provider.avgInfLatencyMs,
                  color: _cConf),
            ],
          ),
          const SizedBox(height: 12),

          // ── Driver ID ──
          TextField(
            controller: driverIdController,
            style: TextStyle(color: text, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Driver ID',
              labelStyle:
                  TextStyle(color: text.withValues(alpha: 0.5), fontSize: 13),
              prefixIcon: Icon(Icons.person_outline,
                  color: text.withValues(alpha: 0.5), size: 18),
              filled: true,
              fillColor: card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (v) => provider.setDriverId(v.trim()),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),

          // ── Status badge with glow ──
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: statusColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: statusColor.withValues(alpha: 0.6),
                            blurRadius: 8)
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Session driving score (circular) ──
          _DrivingScoreCard(provider: provider, card: card, text: text),
          const SizedBox(height: 16),

          // ── Telemetry grid ──
          _TelemetryGrid(data: data, card: card),
          const SizedBox(height: 16),

          // ── Map ──
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                child: data != null
                    ? FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: LatLng(data.lat, data.lon),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.driver_monitor',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(data.lat, data.lon),
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.directions_car,
                                  color: isAgg
                                      ? Colors.red.shade400
                                      : Colors.green.shade400,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Container(
                        color: card,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_outlined,
                                  color: text.withValues(alpha: 0.3),
                                  size: 40),
                              const SizedBox(height: 8),
                              Text('No GPS data yet',
                                  style: TextStyle(
                                      color: text.withValues(alpha: 0.5))),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Trip stats ──
          _TripStatsCard(provider: provider, card: card, text: text),
        ],
      ),
    );
  }
}

// ── Latency badge ─────────────────────────────────────────────────────────────

class _LatencyBadge extends StatelessWidget {
  final String prefix;
  final int value;
  final Color color;

  const _LatencyBadge(
      {required this.prefix, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = value >= 0 ? '$prefix ${value}ms' : '$prefix --';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Telemetry grid ────────────────────────────────────────────────────────────

class _SensorItem {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool smallFont;

  const _SensorItem(
      this.label, this.value, this.unit, this.icon, this.color,
      {this.smallFont = false});
}

class _TelemetryGrid extends StatelessWidget {
  final TelemetryData? data;
  final Color card;

  const _TelemetryGrid({required this.data, required this.card});

  @override
  Widget build(BuildContext context) {
    final d = data;
    final items = [
      _SensorItem('Speed',
          d != null ? d.speed.toStringAsFixed(1) : '--', 'km/h',
          Icons.speed, _cSpeed),
      _SensorItem('RPM',
          d != null ? d.rpm.toStringAsFixed(0) : '--', 'rpm',
          Icons.settings, _cRpm),
      _SensorItem('Throttle',
          d != null ? (d.throttle * 100).toStringAsFixed(0) : '--', '%',
          Icons.keyboard_arrow_up, _cThrottle),
      _SensorItem('Long Acc',
          d != null ? d.longAcc.toStringAsFixed(2) : '--', 'm/s²',
          Icons.arrow_forward, _cLongAcc),
      _SensorItem('Lat Acc',
          d != null ? d.latAcc.toStringAsFixed(2) : '--', 'm/s²',
          Icons.swap_horiz, _cLatAcc),
      _SensorItem('Yaw Rate',
          d != null ? d.yawRate.toStringAsFixed(2) : '--', '°/s',
          Icons.rotate_right, _cYaw),
      _SensorItem('Confidence',
          d != null ? (d.confidence * 100).toStringAsFixed(0) : '--', '%',
          Icons.psychology, _cConf),
      _SensorItem('LAT',
          d != null ? d.lat.toStringAsFixed(6) : '--', '°',
          Icons.location_on, _cGps, smallFont: true),
      _SensorItem('LON',
          d != null ? d.lon.toStringAsFixed(6) : '--', '°',
          Icons.location_on, _cGps, smallFont: true),
    ];

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.90,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((item) => _SensorCard(item: item, card: card)).toList(),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final _SensorItem item;
  final Color card;

  const _SensorCard({required this.item, required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.color, size: 15),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: TextStyle(
              color: Colors.white,
              fontSize: item.smallFont ? 11 : 15,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item.unit,
            style: TextStyle(
              color: item.color.withValues(alpha: 0.7),
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            item.label,
            style: const TextStyle(color: Color(0xFF555A72), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ── Driving score card ────────────────────────────────────────────────────────

class _DrivingScoreCard extends StatelessWidget {
  final AppProvider provider;
  final Color card;
  final Color text;

  const _DrivingScoreCard(
      {required this.provider, required this.card, required this.text});

  Color _scoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final hasData = provider.sessionTotalWindows > 0;
    final score = provider.sessionDrivingScore;
    final scoreInt = score.round();
    final color = hasData ? _scoreColor(score) : Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasData ? color.withValues(alpha: 0.25) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Score',
                  style: TextStyle(
                    color: text.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasData
                      ? '${provider.sessionTotalWindows} windows  •  '
                          '${provider.sessionAggressiveWindows} aggressive'
                      : 'Waiting for data…',
                  style: TextStyle(
                    color: text.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: hasData ? score / 100 : 0,
                  strokeWidth: 7,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasData ? '$scoreInt' : '--',
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        color: text.withValues(alpha: 0.4),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trip stats card ───────────────────────────────────────────────────────────

class _TripStatsCard extends StatelessWidget {
  final AppProvider provider;
  final Color card;
  final Color text;

  const _TripStatsCard(
      {required this.provider, required this.card, required this.text});

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final rate = (provider.aggressionRate * 100).toStringAsFixed(1);
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
              const Icon(Icons.assessment_outlined,
                  color: _cSpeed, size: 15),
              const SizedBox(width: 7),
              Text('Trip Stats',
                  style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatWithIcon(
                  icon: Icons.access_time,
                  color: _cSpeed,
                  label: 'Duration',
                  value: _formatDuration(provider.tripDuration),
                  text: text),
              _StatWithIcon(
                  icon: Icons.grid_view_rounded,
                  color: _cRpm,
                  label: 'Windows',
                  value: '${provider.windowCount}',
                  text: text),
              _StatWithIcon(
                  icon: Icons.warning_amber_rounded,
                  color: _cLongAcc,
                  label: 'Aggressive',
                  value: '${provider.aggressiveCount}',
                  text: text),
              _StatWithIcon(
                  icon: Icons.percent,
                  color: _cYaw,
                  label: 'Rate',
                  value: '$rate%',
                  text: text),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatWithIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color text;

  const _StatWithIcon({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(height: 5),
        Text(value,
            style: TextStyle(
                color: text, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: TextStyle(
                color: text.withValues(alpha: 0.5), fontSize: 10)),
      ],
    );
  }
}

// ── Session alerts bar ────────────────────────────────────────────────────────

class _SessionAlertsBar extends StatelessWidget {
  final List<DateTime> alerts;
  const _SessionAlertsBar({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    final isDark = context.watch<AppProvider>().isDarkTheme;
    final bg = isDark ? _kDarkCard : Colors.grey.shade100;
    final text = isDark ? Colors.white : Colors.black87;
    final border = isDark ? const Color(0xFF2A2D3E) : Colors.grey.shade300;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 13, color: Colors.red.shade400),
              const SizedBox(width: 5),
              Text(
                'Session Alerts',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: text.withValues(alpha: 0.55),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ...alerts.reversed.map((dt) => _AlertRow(time: dt, text: text)),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final DateTime time;
  final Color text;
  const _AlertRow({required this.time, required this.text});

  @override
  Widget build(BuildContext context) {
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.red.shade300,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Aggressive driving detected',
            style:
                TextStyle(fontSize: 11, color: text.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}

// ── Settings sheet ────────────────────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  final AppProvider provider;
  final VoidCallback onLogout;

  const _SettingsSheet({required this.provider, required this.onLogout});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late TextEditingController _driverCtrl;
  late TextEditingController _newPinCtrl;
  late TextEditingController _confirmPinCtrl;

  @override
  void initState() {
    super.initState();
    _driverCtrl = TextEditingController(text: widget.provider.driverId);
    _newPinCtrl = TextEditingController();
    _confirmPinCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _driverCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (_newPinCtrl.text.length != 4) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
      return;
    }
    if (_newPinCtrl.text != _confirmPinCtrl.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PINs do not match')));
      return;
    }
    await widget.provider.storageService.setPin(_newPinCtrl.text);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PIN updated')));
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.provider.isDarkTheme;
    final text = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Settings',
                  style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              const Spacer(),
              Text('v1.0.0',
                  style: TextStyle(
                      color: text.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: text),
              const SizedBox(width: 12),
              Text('Dark Theme', style: TextStyle(color: text)),
              const Spacer(),
              Switch(
                value: isDark,
                onChanged: (_) => widget.provider.toggleTheme(),
                activeThumbColor: Colors.blue.shade400,
              ),
            ],
          ),
          const Divider(),
          TextField(
            controller: _driverCtrl,
            style: TextStyle(color: text),
            decoration: InputDecoration(
              labelText: 'Driver ID',
              labelStyle: TextStyle(color: text.withValues(alpha: 0.6)),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) => widget.provider.setDriverId(v.trim()),
          ),
          const SizedBox(height: 12),
          Text('Change PIN',
              style: TextStyle(color: text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _newPinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: TextStyle(color: text),
            decoration: InputDecoration(
              labelText: 'New PIN',
              labelStyle: TextStyle(color: text.withValues(alpha: 0.6)),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: TextStyle(color: text),
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              labelStyle: TextStyle(color: text.withValues(alpha: 0.6)),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _changePin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade400,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Update PIN'),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onLogout();
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
