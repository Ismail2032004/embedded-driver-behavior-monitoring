import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/telemetry_data.dart';
import 'notification_service.dart';

class BleService {
  static const _targetNames = ['DriverMonitor'];

  final _telemetryController = StreamController<TelemetryData>.broadcast();
  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;

  /// Tracks the label from the previous telemetry point to detect transitions.
  int? _lastLabel;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  bool get isConnected => _connectedDevice != null;

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connect(BluetoothDevice device) async {
    _lastLabel = null;
    await device.connect(autoConnect: false);
    _connectedDevice = device;
    await _discoverAndSubscribe(device);
  }

  Future<void> disconnect() async {
    _notifySub?.cancel();
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _lastLabel = null;
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final service in services) {
      for (final char in service.characteristics) {
        if (char.properties.notify) {
          await char.setNotifyValue(true);
          _notifySub = char.lastValueStream.listen((value) {
            if (value.isEmpty) return;
            try {
              final jsonStr = utf8.decode(value);
              final map = jsonDecode(jsonStr) as Map<String, dynamic>;
              final data = TelemetryData.fromJson(map);
              _handleTelemetry(data);
            } catch (_) {}
          });
          return;
        }
      }
    }
  }

  void _handleTelemetry(TelemetryData data) {
    _telemetryController.add(data);

    if (data.label == 1 && _lastLabel != 1) {
      // 0 → 1 transition: aggressive event starts — haptic + notification once
      HapticFeedback.heavyImpact();
      NotificationService.instance.showAggressiveAlert();
    } else if (data.label == 0 && _lastLabel == 1) {
      // 1 → 0 transition: aggressive event ends — gentle haptic
      HapticFeedback.lightImpact();
    }

    _lastLabel = data.label;
  }

  bool isTargetDevice(ScanResult result) {
    final name = result.device.platformName;
    return _targetNames.any((t) => name.contains(t));
  }

  void dispose() {
    _scanSub?.cancel();
    _notifySub?.cancel();
    _telemetryController.close();
  }
}
