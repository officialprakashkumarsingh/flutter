import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth_service.dart';
import 'auth_and_profile_pages.dart';
import 'main_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _checkAuthState();
    
    // Listen to auth state changes
    SupabaseAuthService.authStateChanges.listen((AuthState data) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }
  
  Future<void> _checkAuthState() async {
    // Small delay to let Supabase initialize
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F3F0),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.black,
          ),
        ),
      );
    }
    
    // Check if user is signed in
    if (SupabaseAuthService.isSignedIn) {
      return const MainShell();
    } else {
      return const AuthAndProfilePages();
    }
  }
}