import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../models/telemetry_data.dart';

class ApiService {
  static const _base = 'https://driver-dashboard-production-f393.up.railway.app';

  Future<List<Trip>> getTrips(String driverId) async {
    final uri = Uri.parse('$_base/api/drivers/$driverId/trips');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> tripsList = data['trips'] ?? [];
      return tripsList.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load trips: ${response.statusCode}');
  }

  Future<Trip> getTrip(String driverId, String tripId) async {
    final uri = Uri.parse('$_base/api/drivers/$driverId/trips/$tripId');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return Trip.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load trip: ${response.statusCode}');
  }

  Future<List<TripPoint>> getTripRoute(String driverId, String tripId) async {
    final uri = Uri.parse('$_base/api/drivers/$driverId/trips/$tripId/route');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> routeList = data['points'] ?? [];
      return routeList
          .map((e) => TripPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load trip route: ${response.statusCode}');
  }

  Future<void> uploadTelemetry({
    required String driverId,
    required String tripId,
    required TelemetryData data,
  }) async {
    final uri = Uri.parse('$_base/api/telemetry');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'driver_id': driverId,
        'trip_id': tripId,
        ...data.toJson(),
      }),
    ).timeout(const Duration(seconds: 10));
  }

  Future<Map<String, dynamic>> startTrip(String driverId) async {
    final uri = Uri.parse('$_base/api/trips/start');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'driver_id': driverId}),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to start trip: ${response.statusCode}');
  }

  Future<void> endTrip(String tripId) async {
    final uri = Uri.parse('$_base/api/trips/$tripId/end');
    await http.post(uri).timeout(const Duration(seconds: 10));
  }

  Future<void> syncOfflinePoints({
    required String driverId,
    required List<Map<String, dynamic>> points,
  }) async {
    final uri = Uri.parse('$_base/api/drivers/$driverId/sync');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'driver_id': driverId, 'points': points}),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Sync failed: ${response.statusCode}');
    }
  }
}
