import 'dart:async';
import 'package:flutter/material.dart';
import '../models/telemetry_data.dart';
import '../services/ble_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final BleService bleService;
  final StorageService storageService;
  final ApiService apiService;

  AppProvider({
    required this.bleService,
    required this.storageService,
    required this.apiService,
  });

  // Theme
  bool _isDarkTheme = true;
  bool get isDarkTheme => _isDarkTheme;

  // Driver
  String _driverId = '';
  String _driverName = '';
  String get driverId => _driverId;
  String get driverName => _driverName;

  // Live telemetry
  TelemetryData? _latest;
  TelemetryData? get latest => _latest;

  // Trip stats
  DateTime? _tripStart;
  int _windowCount = 0;
  int _aggressiveCount = 0;

  // In-session aggressive moments (last 5, cleared on disconnect)
  final List<DateTime> _sessionAlerts = [];
  List<DateTime> get sessionAlerts => List.unmodifiable(_sessionAlerts);

  // Session driving score counters
  int _sessionTotalWindows = 0;
  int _sessionAggressiveWindows = 0;
  int get sessionTotalWindows => _sessionTotalWindows;
  int get sessionAggressiveWindows => _sessionAggressiveWindows;

  double get sessionDrivingScore {
    if (_sessionTotalWindows == 0) return 100.0;
    final aggrRate = _sessionAggressiveWindows / _sessionTotalWindows;
    return ((1.0 - aggrRate) * 100).clamp(0.0, 100.0);
  }

  // Latency rolling averages (last 10 readings)
  final List<int> _bleLatencies = [];
  final List<int> _infLatencies = [];

  /// Average BLE latency in ms, or -1 if no data yet.
  int get avgBleLatencyMs {
    if (_bleLatencies.isEmpty) return -1;
    return (_bleLatencies.reduce((a, b) => a + b) / _bleLatencies.length)
        .round();
  }

  /// Average inference latency in ms, or -1 if no data yet.
  int get avgInfLatencyMs {
    if (_infLatencies.isEmpty) return -1;
    return (_infLatencies.reduce((a, b) => a + b) / _infLatencies.length)
        .round();
  }

  DateTime? get tripStart => _tripStart;
  int get windowCount => _windowCount;
  int get aggressiveCount => _aggressiveCount;

  Duration get tripDuration =>
      _tripStart != null ? DateTime.now().difference(_tripStart!) : Duration.zero;

  double get aggressionRate =>
      _windowCount > 0 ? _aggressiveCount / _windowCount : 0.0;

  StreamSubscription<TelemetryData>? _telemetrySub;

  Future<void> init() async {
    _isDarkTheme = await storageService.getIsDarkTheme();
    _driverId = await storageService.getDriverId();
    _driverName = await storageService.getDriverName();
    notifyListeners();
  }

  void startListening() {
    _tripStart = DateTime.now();
    _windowCount = 0;
    _aggressiveCount = 0;
    _sessionTotalWindows = 0;
    _sessionAggressiveWindows = 0;
    _bleLatencies.clear();
    _infLatencies.clear();

    _telemetrySub = bleService.telemetryStream.listen((data) {
      _latest = data;
      _windowCount++;
      _sessionTotalWindows++;
      if (data.isAggressive) {
        _aggressiveCount++;
        _sessionAggressiveWindows++;
        _sessionAlerts.add(data.timestamp);
        if (_sessionAlerts.length > 5) _sessionAlerts.removeAt(0);
      }

      // BLE latency: current time minus ESP32 packet timestamp
      final bleLatency = DateTime.now().millisecondsSinceEpoch -
          data.espTimestamp.millisecondsSinceEpoch;
      if (bleLatency > 0 && bleLatency < 30000) {
        _bleLatencies.add(bleLatency);
        if (_bleLatencies.length > 10) _bleLatencies.removeAt(0);
      }

      // Inference latency from packet
      if (data.inferenceLatencyMs > 0) {
        _infLatencies.add(data.inferenceLatencyMs);
        if (_infLatencies.length > 10) _infLatencies.removeAt(0);
      }

      notifyListeners();
    });
    notifyListeners();
  }

  void stopListening() {
    _telemetrySub?.cancel();
    _tripStart = null;
    _sessionAlerts.clear();
    _sessionTotalWindows = 0;
    _sessionAggressiveWindows = 0;
    _bleLatencies.clear();
    _infLatencies.clear();
    notifyListeners();
  }

  Future<void> setDriverId(String id) async {
    _driverId = id;
    await storageService.setDriverId(id);
    notifyListeners();
  }

  Future<void> setDriverCredentials(String driverId, String name) async {
    _driverId = driverId;
    _driverName = name;
    await storageService.setDriverId(driverId);
    await storageService.setDriverName(name);
    notifyListeners();
  }

  Future<void> logout() async {
    _driverId = '';
    _driverName = '';
    await storageService.clearUserData();
    stopListening();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkTheme = !_isDarkTheme;
    await storageService.setIsDarkTheme(_isDarkTheme);
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    _isDarkTheme = isDark;
    await storageService.setIsDarkTheme(isDark);
    notifyListeners();
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    super.dispose();
  }
}
