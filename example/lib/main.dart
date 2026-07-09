import 'package:flutter/material.dart';
import 'package:flutter_dev_monitor/flutter_dev_monitor.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

// ── App root ─────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevMonitor Lab',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [DevMonitor.observer],
      builder: DevMonitor.builder(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.light,
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF4F46E5),
          surface: const Color(0xFFF8FAFC),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
