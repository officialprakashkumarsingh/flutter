import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

class CacheManager {
  static CacheManager? _instance;
  static CacheManager get instance => _instance ??= CacheManager._();
  CacheManager._();

  SharedPreferences? _prefs;

  // Initialize cache manager
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Conversation memory management
  Future<void> saveConversationMemory(List<String> memory) async {
    await initialize();
    await _prefs!.setStringList('conversation_memory', memory);
  }

  Future<List<String>> getConversationMemory() async {
    await initialize();
    return _prefs!.getStringList('conversation_memory') ?? [];
  }

  // Image generation prompts memory
  Future<void> saveImagePrompts(List<String> prompts) async {
    await initialize();
    await _prefs!.setStringList('image_prompts', prompts);
  }

  Future<List<String>> getImagePrompts() async {
    await initialize();
    return _prefs!.getStringList('image_prompts') ?? [];
  }

  // Tool execution cache
  Future<void> cacheToolResult(String toolName, Map<String, dynamic> params, Map<String, dynamic> result) async {
    await initialize();
    final cacheKey = 'tool_${toolName}_${params.hashCode}';
    final cacheData = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'result': result,
    };
    await _prefs!.setString(cacheKey, jsonEncode(cacheData));
  }

  Future<Map<String, dynamic>?> getCachedToolResult(String toolName, Map<String, dynamic> params) async {
    await initialize();
    final cacheKey = 'tool_${toolName}_${params.hashCode}';
    final cacheStr = _prefs!.getString(cacheKey);
    
    if (cacheStr != null) {
      try {
        final cacheData = jsonDecode(cacheStr);
        final timestamp = cacheData['timestamp'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Cache valid for 1 hour for most tools, 5 minutes for search
        final maxAge = 60 * 60 * 1000; // 1 hour default cache
        
        if (now - timestamp < maxAge) {
          return cacheData['result'] as Map<String, dynamic>;
        }
      } catch (e) {
        // Invalid cache data, remove it
        await _prefs!.remove(cacheKey);
      }
    }
    
    return null;
  }

  // App settings
  Future<void> saveSetting(String key, dynamic value) async {
    await initialize();
    if (value is String) {
      await _prefs!.setString(key, value);
    } else if (value is int) {
      await _prefs!.setInt(key, value);
    } else if (value is bool) {
      await _prefs!.setBool(key, value);
    } else if (value is double) {
      await _prefs!.setDouble(key, value);
    }
  }

  Future<T?> getSetting<T>(String key) async {
    await initialize();
    return _prefs!.get(key) as T?;
  }

  // Clear cache
  Future<void> clearCache() async {
    await initialize();
    final keys = _prefs!.getKeys().where((key) => key.startsWith('tool_')).toList();
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }

  Future<void> clearAll() async {
    await initialize();
    await _prefs!.clear();
  }

  // Additional utility methods
  Future<void> setStringList(String key, List<String> value) async {
    await initialize();
    await _prefs!.setStringList(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    await initialize();
    return _prefs!.getStringList(key);
  }

  Future<void> setString(String key, String value) async {
    await initialize();
    await _prefs!.setString(key, value);
  }

  Future<String?> getString(String key) async {
    await initialize();
    return _prefs!.getString(key);
  }
}