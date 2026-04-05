import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'live_screen.dart';
import 'trip_history_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _connecting = false;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    context.read<AppProvider>().bleService.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();

    if (!mounted) return;
    final ble = context.read<AppProvider>().bleService;
    await ble.startScan();
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _connecting = true;
      _connectingId = device.remoteId.str;
    });
    try {
      final provider = context.read<AppProvider>();
      await provider.bleService.connect(device);
      provider.startListening();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LiveScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDarkTheme;
    final bg = isDark ? const Color(0xFF0f1117) : Colors.white;
    final card = isDark ? const Color(0xFF1a1d2e) : Colors.grey.shade100;
    final text = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Connect Device', style: TextStyle(color: text)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: text),
            onPressed: _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: provider.bleService.scanResults,
              builder: (context, snap) {
                final results = snap.data ?? [];
                if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Scanning for devices...',
                            style: TextStyle(color: text)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final r = results[i];
                    final isTarget =
                        provider.bleService.isTargetDevice(r);
                    final name = r.device.platformName.isEmpty
                        ? 'Unknown Device'
                        : r.device.platformName;
                    final isConnectingThis =
                        _connecting &&
                            _connectingId == r.device.remoteId.str;
                    return Card(
                      color: card,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isTarget
                            ? BorderSide(
                                color: Colors.blue.shade400, width: 1.5)
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.bluetooth,
                          color: isTarget
                              ? Colors.blue.shade400
                              : Colors.grey,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: text,
                            fontWeight: isTarget
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          r.device.remoteId.str,
                          style: TextStyle(
                              color: text.withOpacity(0.5), fontSize: 12),
                        ),
                        trailing: isConnectingThis
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : isTarget
                                ? Chip(
                                    label: const Text('DriverMonitor',
                                        style: TextStyle(fontSize: 11)),
                                    backgroundColor:
                                        Colors.blue.shade400.withOpacity(0.2),
                                    labelStyle: TextStyle(
                                        color: Colors.blue.shade400),
                                  )
                                : null,
                        onTap: _connecting ? null : () => _connect(r.device),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TripHistoryScreen()),
                    );
                  },
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Continue without Bluetooth'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(color: Colors.blue.shade400),
                    foregroundColor: Colors.blue.shade400,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
