import 'package:flutter/material.dart';
import 'package:x_notes/screen/splash_screen.dart';
import 'package:x_notes/services/app_config.dart';
import 'package:x_notes/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLinks.fetchConfig();
  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes App',
      debugShowCheckedModeBanner: false,
      // Light Theme Settings
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor:
              Colors.transparent, // Gradient dikhane ke liye transparent
          elevation: 0,
        ),
      ),
      // Dark Theme Settings
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // Dark background
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      home: SplashScreen(),
    );
  }
}
