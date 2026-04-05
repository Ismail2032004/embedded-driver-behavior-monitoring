class Trip {
  final String id;
  final String driverId;
  final DateTime startTime;
  final DateTime? endTime;
  final int totalWindows;
  final int aggressiveWindows;
  final List<TripPoint> route;

  Trip({
    required this.id,
    required this.driverId,
    required this.startTime,
    this.endTime,
    required this.totalWindows,
    required this.aggressiveWindows,
    this.route = const [],
  });

  double get aggressionRate =>
      totalWindows > 0 ? aggressiveWindows / totalWindows : 0.0;

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      totalWindows: (json['total_windows'] as num?)?.toInt() ?? 0,
      aggressiveWindows: (json['aggressive_windows'] as num?)?.toInt() ?? 0,
      route: (json['route'] as List<dynamic>?)
              ?.map((e) => TripPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TripPoint {
  final double lat;
  final double lon;
  final int label;
  final DateTime timestamp;

  TripPoint({
    required this.lat,
    required this.lon,
    required this.label,
    required this.timestamp,
  });

  bool get isAggressive => label == 1;

  factory TripPoint.fromJson(Map<String, dynamic> json) {
    return TripPoint(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      label: (json['label'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
