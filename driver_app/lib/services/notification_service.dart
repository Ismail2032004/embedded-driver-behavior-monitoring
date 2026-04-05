import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  // ── Fields ─────────────────────────────────────────────────────────────────
  final _plugin = FlutterLocalNotificationsPlugin();
  DateTime? _lastAlertTime;
  static const _cooldown = Duration(seconds: 30);
  bool _ready = false;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);

    // Create the Android notification channel
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'driver_alerts',
          'Driving Alerts',
          importance: Importance.high,
        ));

    // Request POST_NOTIFICATIONS permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _ready = true;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> showAggressiveAlert() async {
    if (!_ready) return;

    final now = DateTime.now();
    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!) < _cooldown) {
      return; // still in cooldown — skip
    }
    _lastAlertTime = now;

    const androidDetails = AndroidNotificationDetails(
      'driver_alerts',
      'Driving Alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(android: androidDetails);

    final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    await _plugin.show(
      0, // fixed id — replaces previous alert rather than stacking
      '⚠️ Aggressive Driving Detected',
      'Aggressive driving behaviour detected at $timeStr',
      details,
    );
  }
}
