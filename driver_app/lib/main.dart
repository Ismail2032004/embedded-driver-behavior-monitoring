import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/ble_service.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = StorageService();
  final bleService = BleService();
  final apiService = ApiService();

  final provider = AppProvider(
    bleService: bleService,
    storageService: storageService,
    apiService: apiService,
  );
  await provider.init();

  await NotificationService.instance.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const DriverMonitorApp(),
    ),
  );
}

class DriverMonitorApp extends StatelessWidget {
  const DriverMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDarkTheme;
    return MaterialApp(
      title: 'DriverMonitor',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const LoginScreen(),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      cardColor: const Color(0xFF1A1F2E),
      colorScheme: ColorScheme.dark(
        primary: Colors.blue.shade400,
        secondary: Colors.blue.shade300,
        surface: const Color(0xFF1A1F2E),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0E1A),
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1F2E),
      ),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: Colors.blue.shade600,
        secondary: Colors.blue.shade400,
        surface: Colors.grey.shade100,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
