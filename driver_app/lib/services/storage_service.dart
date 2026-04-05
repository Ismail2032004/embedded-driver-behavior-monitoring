import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/telemetry_data.dart';

class StorageService {
  static const _pinKey = 'app_pin';
  static const _driverIdKey = 'driver_id';
  static const _driverNameKey = 'driver_name';
  static const _themeKey = 'is_dark_theme';
  static const _bufferKey = 'telemetry_buffer';

  Future<String> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) ?? '1234';
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  Future<String> getDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_driverIdKey) ?? '';
  }

  Future<void> setDriverId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_driverIdKey, id);
  }

  Future<String> getDriverName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_driverNameKey) ?? '';
  }

  Future<void> setDriverName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_driverNameKey, name);
  }

  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_driverIdKey);
    await prefs.remove(_driverNameKey);
  }

  Future<bool> getIsDarkTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? true;
  }

  Future<void> setIsDarkTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  Future<void> saveBufferedPoint(Map<String, dynamic> point) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bufferKey);
    final List<dynamic> list = raw != null ? jsonDecode(raw) : [];
    list.add(point);
    // Keep last 50000 entries, dropping oldest
    if (list.length > 50000) list.removeRange(0, list.length - 50000);
    await prefs.setString(_bufferKey, jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>> getBufferedPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bufferKey);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> clearBufferedPoints() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bufferKey);
  }

  // Legacy wrappers kept for compatibility
  Future<void> bufferTelemetry(TelemetryData data) => saveBufferedPoint(data.toJson());

  Future<List<TelemetryData>> getBufferedTelemetry() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bufferKey);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => TelemetryData.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> clearBuffer() => clearBufferedPoints();
}
