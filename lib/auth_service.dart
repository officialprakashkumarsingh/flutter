import 'package:flutter/material.dart';
import 'models.dart';

class AuthService {
  // Singleton pattern to ensure only one instance of AuthService exists
  static final AuthService _instance = AuthService._internal();
  factory AuthService() {
    return _instance;
  }
  AuthService._internal();

  // ValueNotifier will notify listeners when the user logs in or out
  final ValueNotifier<User?> currentUser = ValueNotifier(null);

  final List<String> availableAvatars = [
    'https://i.ibb.co/S49qqjty/IMG-20250716-131014-009.jpg',
    'https://i.ibb.co/1fRxkbDt/10-0029981-64d519f7cbe03.png',
    'https://i.ibb.co/PZCDzzyz/source.png',
  ];

  // Demo user data
  final Map<String, User> _users = {
    'test@aham.ai': User(
      name: 'Demo User',
      email: 'test@aham.ai',
      avatarUrl: 'https://i.ibb.co/S49qqjty/IMG-20250716-131014-009.jpg',
    )
  };

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required String avatarUrl,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    if (_users.containsKey(email)) {
      return 'An account already exists for that email.';
    }
    final newUser = User(name: name, email: email, avatarUrl: avatarUrl);
    _users[email] = newUser;
    currentUser.value = newUser;
    return null; // Success
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    if (_users.containsKey(email)) {
      currentUser.value = _users[email];
      return null; // Success
    }
    return 'Invalid email or password.';
  }

  Future<void> updateAvatar(String newAvatarUrl) async {
    if (currentUser.value != null) {
      final updatedUser = User(
        name: currentUser.value!.name,
        email: currentUser.value!.email,
        avatarUrl: newAvatarUrl,
      );
      _users[currentUser.value!.email] = updatedUser;
      currentUser.value = updatedUser;
    }
  }

  Future<void> signOut() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    currentUser.value = null;
  }
}