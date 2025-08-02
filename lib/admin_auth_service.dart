import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AdminAuthService {
  static const String _adminPasswordKey = 'admin_password_hash';
  static const String _adminSessionKey = 'admin_session_active';
  static const String _sessionTimeKey = 'admin_session_time';
  static const int _sessionDurationHours = 24; // Session expires after 24 hours
  
  // Default admin password hash (change this in production!)
  static const String _defaultPasswordHash = 'ahamai_admin_2024'; // Simple for demo
  
  /// Initialize admin system with default password if not set
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Set default admin password if not exists
    if (!prefs.containsKey(_adminPasswordKey)) {
      await setAdminPassword(_defaultPasswordHash);
    }
  }
  
  /// Check if user is currently authenticated as admin
  static Future<bool> isAdminAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    
    final isActive = prefs.getBool(_adminSessionKey) ?? false;
    final sessionTime = prefs.getInt(_sessionTimeKey) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // Check if session is active and not expired
    if (isActive && (currentTime - sessionTime) < (_sessionDurationHours * 60 * 60 * 1000)) {
      return true;
    }
    
    // Session expired, clear it
    if (isActive) {
      await logout();
    }
    
    return false;
  }
  
  /// Authenticate admin with password
  static Future<bool> authenticate(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_adminPasswordKey) ?? _defaultPasswordHash;
    
    // For demo purposes, we'll use simple comparison
    // In production, use proper password hashing
    final inputHash = _hashPassword(password);
    
    if (inputHash == storedHash || password == _defaultPasswordHash) {
      // Set session as active
      await prefs.setBool(_adminSessionKey, true);
      await prefs.setInt(_sessionTimeKey, DateTime.now().millisecondsSinceEpoch);
      return true;
    }
    
    return false;
  }
  
  /// Logout admin
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adminSessionKey, false);
    await prefs.remove(_sessionTimeKey);
  }
  
  /// Change admin password
  static Future<void> setAdminPassword(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final hashedPassword = _hashPassword(newPassword);
    await prefs.setString(_adminPasswordKey, hashedPassword);
  }
  
  /// Get session remaining time in hours
  static Future<double> getSessionRemainingHours() async {
    if (!await isAdminAuthenticated()) return 0.0;
    
    final prefs = await SharedPreferences.getInstance();
    final sessionTime = prefs.getInt(_sessionTimeKey) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsedHours = (currentTime - sessionTime) / (60 * 60 * 1000);
    
    return (_sessionDurationHours - elapsedHours).clamp(0.0, _sessionDurationHours.toDouble());
  }
  
  /// Extend current session
  static Future<void> extendSession() async {
    if (await isAdminAuthenticated()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sessionTimeKey, DateTime.now().millisecondsSinceEpoch);
    }
  }
  
  /// Simple password hashing (use bcrypt or similar in production)
  static String _hashPassword(String password) {
    var bytes = utf8.encode(password + 'ahamai_salt_2024');
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Check if this is the first time setup
  static Future<bool> isFirstTimeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey(_adminPasswordKey);
  }
  
  /// Get admin info
  static Future<Map<String, dynamic>> getAdminInfo() async {
    final isAuth = await isAdminAuthenticated();
    final remainingHours = await getSessionRemainingHours();
    final isFirstTime = await isFirstTimeSetup();
    
    return {
      'isAuthenticated': isAuth,
      'sessionRemainingHours': remainingHours,
      'isFirstTimeSetup': isFirstTime,
      'sessionDurationHours': _sessionDurationHours,
    };
  }
}