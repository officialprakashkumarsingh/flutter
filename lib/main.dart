import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash_screen.dart';
import 'auth_gate.dart';
import 'smooth_scroll_behavior.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://pxmhiaxrivtlkrjrqmkb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4bWhpYXhyaXZ0bGtyanJxbWtiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM2NDk1MzQsImV4cCI6MjA2OTIyNTUzNH0.0x9HweD2DCZcGSso0Xx5v1AAgpWvC_ZZO9THBzRovTs',
  );
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF4F3F0),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  
  runApp(const AhamAIApp());
}

class AhamAIApp extends StatelessWidget {
  const AhamAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AhamAI',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SmoothScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF000000),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F3F0),
          foregroundColor: Colors.black,
          elevation: 0,
          // Remove Material 3 scroll overlay & shadow tint
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
        ),
        cardTheme: const CardTheme(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AppWrapper(),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onComplete: () {
          setState(() {
            _showSplash = false;
          });
        },
      );
    }
    
    return const AuthGate();
  }
}