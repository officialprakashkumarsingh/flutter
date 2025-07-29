import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'auth_and_profile_pages.dart';
import 'auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the AuthService singleton so it's available everywhere
  AuthService(); 
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFFF4F3F0),
    statusBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.dark,
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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF000000), // Black for primary buttons
          secondary: Color(0xFF000000),
          surface: Color(0xFFF4F3F0), // Main background
          onSurface: Color(0xFF000000), // Text on surface
          background: Color(0xFFF4F3F0), // Main background
          onBackground: Color(0xFF000000), // Text on background
          surfaceVariant: Color(0xFFEAE9E5), // Chat bubbles background
          onSurfaceVariant: Color(0xFF000000), // Text on surfaceVariant
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F3F0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F3F0),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Color(0xFF000000)),
          titleTextStyle: TextStyle(
            color: Color(0xFF000000),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFFEAE9E5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF000000),
            foregroundColor: const Color(0xFFFFFFFF),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFF4F3F0),
          selectedItemColor: Color(0xFF000000),
          unselectedItemColor: Color(0xFFA3A3A3),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        fontFamily: 'SF Pro Display', // iOS font
        // Enhanced page transitions for iOS-like smoothness
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        // Enhanced animation duration for smoother feel
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      // AuthGate will decide which page to show
      home: const AuthGate(),
    );
  }
}