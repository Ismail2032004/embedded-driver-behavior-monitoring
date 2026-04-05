class TelemetryData {
  final int label;
  final double confidence;
  final double speed;
  final double rpm;
  final double throttle;
  final double longAcc;
  final double latAcc;
  final double yawRate;
  final double lat;
  final double lon;
  final DateTime timestamp;        // local device receive time
  final DateTime espTimestamp;     // ESP32 Unix timestamp from BLE packet
  final int inferenceLatencyMs;    // inference_latency_ms from ESP32

  TelemetryData({
    required this.label,
    required this.confidence,
    required this.speed,
    required this.rpm,
    required this.throttle,
    required this.longAcc,
    required this.latAcc,
    required this.yawRate,
    required this.lat,
    required this.lon,
    DateTime? timestamp,
    DateTime? espTimestamp,
    this.inferenceLatencyMs = 0,
  })  : timestamp = timestamp ?? DateTime.now(),
        espTimestamp = espTimestamp ?? DateTime.now();

  bool get isAggressive => label == 1;

  factory TelemetryData.fromJson(Map<String, dynamic> json) {
    DateTime? espTs;
    final tsRaw = json['timestamp'];
    if (tsRaw is num) {
      espTs = DateTime.fromMillisecondsSinceEpoch(tsRaw.toInt() * 1000);
    }
    return TelemetryData(
      label: (json['label'] as num).toInt(),
      confidence: (json['confidence'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      rpm: (json['rpm'] as num).toDouble(),
      throttle: (json['throttle'] as num).toDouble(),
      longAcc: (json['long_acc'] as num).toDouble(),
      latAcc: (json['lat_acc'] as num).toDouble(),
      yawRate: (json['yaw_rate'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      espTimestamp: espTs,
      inferenceLatencyMs: (json['inference_latency_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'speed': speed,
        'rpm': rpm,
        'throttle': throttle,
        'long_acc': longAcc,
        'lat_acc': latAcc,
        'yaw_rate': yawRate,
        'lat': lat,
        'lon': lon,
        'timestamp': timestamp.toIso8601String(),
      };
}
