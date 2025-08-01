import 'package:supabase_flutter/supabase_flutter.dart';
import 'character_models.dart';

class SupabaseCharacterService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // Get all characters for current user
  static Future<List<Character>> getUserCharacters() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 SupabaseCharacterService.getUserCharacters() - Fetching for user: $userId');
      
      final response = await _supabase
          .from('characters')
          .select()
          .eq('user_id', userId)
          .order('is_favorite', ascending: false)  // Favorites first
          .order('created_at', ascending: false);  // Then by creation date

      print('🔍 SupabaseCharacterService.getUserCharacters() - Raw response: ${response.length} characters');
      
      final characters = response.map<Character>((characterData) {
        return Character(
          id: characterData['id'],
          name: characterData['name'],
          description: characterData['description'],
          systemPrompt: characterData['system_prompt'],
          avatarUrl: characterData['avatar_url'],
          customTag: characterData['custom_tag'],
          backgroundColor: characterData['background_color'] ?? 4294967295,
          isBuiltIn: characterData['is_built_in'] ?? false,
          isFavorite: characterData['is_favorite'] ?? false,
          createdAt: DateTime.parse(characterData['created_at']),
        );
      }).toList();
      
      print('🔍 SupabaseCharacterService.getUserCharacters() - Processed result: ${characters.length} characters');
      
      return characters;
    } catch (e) {
      print('❌ Error getting user characters: $e');
      return [];
    }
  }
  
  // Create a new character
  static Future<String?> createCharacter({
    required String name,
    required String description,
    required String systemPrompt,
    String? avatarUrl,
    String? customTag,
    int backgroundColor = 4294967295,
    bool isFavorite = false,
    bool isBuiltIn = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('characters')
          .insert({
            'user_id': userId,
            'name': name,
            'description': description,
            'system_prompt': systemPrompt,
            'avatar_url': avatarUrl,
            'custom_tag': customTag,
            'background_color': backgroundColor,
            'is_built_in': isBuiltIn,
            'is_favorite': isFavorite,
          })
          .select('id')
          .single();
      
      return response['id'] as String;
    } catch (e) {
      print('Error creating character: $e');
      return null;
    }
  }
  
  // Update an existing character
  static Future<bool> updateCharacter({
    required String characterId,
    String? name,
    String? description,
    String? systemPrompt,
    String? avatarUrl,
    String? customTag,
    int? backgroundColor,
    bool? isFavorite,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (systemPrompt != null) updateData['system_prompt'] = systemPrompt;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      if (customTag != null) updateData['custom_tag'] = customTag;
      if (backgroundColor != null) updateData['background_color'] = backgroundColor;
      if (isFavorite != null) updateData['is_favorite'] = isFavorite;
      
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('characters')
          .update(updateData)
          .eq('id', characterId)
          .eq('user_id', userId);
      
      return true;
    } catch (e) {
      print('Error updating character: $e');
      return false;
    }
  }
  
  // Delete a character
  static Future<bool> deleteCharacter(String characterId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('characters')
          .delete()
          .eq('id', characterId)
          .eq('user_id', userId)
          .neq('is_built_in', true); // Prevent deletion of built-in characters
      
      return true;
    } catch (e) {
      print('Error deleting character: $e');
      return false;
    }
  }
  
  // Toggle favorite status of a character
  static Future<bool> toggleFavorite(String characterId, bool isFavorite) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('characters')
          .update({
            'is_favorite': isFavorite,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', characterId)
          .eq('user_id', userId);
      
      return true;
    } catch (e) {
      print('Error toggling favorite: $e');
      return false;
    }
  }
}