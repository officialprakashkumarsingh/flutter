import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // Get current user
  static User? get currentUser => _supabase.auth.currentUser;
  
  // Check if user is signed in
  static bool get isSignedIn => currentUser != null;
  
  // Get auth stream for listening to changes
  static Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  
  // Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
      );
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // Sign out
  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }
  
  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }
  
  // Update user profile
  static Future<UserResponse> updateProfile({
    String? fullName,
    String? email,
  }) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(
          email: email,
          data: fullName != null ? {'full_name': fullName} : null,
        ),
      );
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // Get user profile data
  static Map<String, dynamic>? get userMetadata => currentUser?.userMetadata;
  
  static String? get userEmail => currentUser?.email;
  
  static String? get userFullName => userMetadata?['full_name'];
  
  static String get userId => currentUser?.id ?? '';
  
  // Check if email is confirmed
  static bool get isEmailConfirmed => currentUser?.emailConfirmedAt != null;
  
  // Resend confirmation email
  static Future<void> resendConfirmation(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  // Handle auth errors
  static String getErrorMessage(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'Invalid email or password. Please try again.';
        case 'Email not confirmed':
          return 'Please confirm your email address before signing in.';
        case 'User already registered':
          return 'An account with this email already exists.';
        case 'Password should be at least 6 characters':
          return 'Password must be at least 6 characters long.';
        case 'Unable to validate email address: invalid format':
          return 'Please enter a valid email address.';
        case 'Signup requires a valid password':
          return 'Please enter a valid password.';
        default:
          return error.message;
      }
    }
    return error.toString();
  }
  
  // Create user profile in profiles table
  static Future<void> createUserProfile({
    required String userId,
    required String email,
    String? fullName,
  }) async {
    try {
      await _supabase.from('profiles').insert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Profile might already exist, which is fine
      print('Profile creation error (might already exist): $e');
    }
  }
  
  // Get user profile from profiles table
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
  
  // Update user profile in profiles table
  static Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? email,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (fullName != null) updateData['full_name'] = fullName;
      if (email != null) updateData['email'] = email;
      
      await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }
}