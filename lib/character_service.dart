import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'character_models.dart';
import 'models.dart';
import 'supabase_character_service.dart';
import 'supabase_auth_service.dart';

class CharacterService extends ChangeNotifier {
  static final CharacterService _instance = CharacterService._internal();
  factory CharacterService() => _instance;
  CharacterService._internal() {
    _loadCharacters();
    
    // Listen for auth state changes
    SupabaseAuthService.authStateChanges.listen((authState) {
      if (SupabaseAuthService.isSignedIn) {
        _loadCharacters();
      } else {
        _characters.clear();
        _selectedCharacter = null;
        _characterChats.clear();
        notifyListeners();
      }
    });
  }

  final List<Character> _characters = [];
  Character? _selectedCharacter;
  final Map<String, CharacterChat> _characterChats = {};

  List<Character> get characters => List.unmodifiable(_characters);
  Character? get selectedCharacter => _selectedCharacter;
  Map<String, CharacterChat> get characterChats => Map.unmodifiable(_characterChats);

  Future<void> _loadCharacters() async {
    if (!SupabaseAuthService.isSignedIn) {
      return;
    }
    
    try {
      final charactersFromDb = await SupabaseCharacterService.getUserCharacters();
      _characters.clear();
      _characters.addAll(charactersFromDb);
      notifyListeners();
    } catch (e) {
      print('Error loading characters from Supabase: $e');
    }
  }

  Future<bool> addCharacter(Character character) async {
    try {
      final characterId = await SupabaseCharacterService.createCharacter(
        name: character.name,
        description: character.description,
        systemPrompt: character.systemPrompt,
        avatarUrl: character.avatarUrl,
        customTag: character.customTag,
        backgroundColor: character.backgroundColor,
        isFavorite: character.isFavorite,
      );
      
      if (characterId != null) {
        final newCharacter = character.copyWith(id: characterId);
        _characters.add(newCharacter);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding character: $e');
      return false;
    }
  }

  Future<bool> updateCharacter(Character character) async {
    try {
      final success = await SupabaseCharacterService.updateCharacter(
        characterId: character.id,
        name: character.name,
        description: character.description,
        systemPrompt: character.systemPrompt,
        avatarUrl: character.avatarUrl,
        customTag: character.customTag,
        backgroundColor: character.backgroundColor,
        isFavorite: character.isFavorite,
      );
      
      if (success) {
        final index = _characters.indexWhere((c) => c.id == character.id);
        if (index != -1) {
          _characters[index] = character;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating character: $e');
      return false;
    }
  }

  Future<bool> deleteCharacter(String characterId) async {
    try {
      final success = await SupabaseCharacterService.deleteCharacter(characterId);
      
      if (success) {
        _characters.removeWhere((c) => c.id == characterId);
        _characterChats.remove(characterId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting character: $e');
      return false;
    }
  }

  Future<bool> toggleFavorite(String characterId) async {
    try {
      final character = _characters.firstWhere((c) => c.id == characterId);
      final newFavoriteStatus = !character.isFavorite;
      
      final success = await SupabaseCharacterService.toggleFavorite(characterId, newFavoriteStatus);
      
      if (success) {
        final index = _characters.indexWhere((c) => c.id == characterId);
        if (index != -1) {
          _characters[index] = character.copyWith(isFavorite: newFavoriteStatus);
          // Re-sort to put favorites first
          _characters.sort((a, b) {
            if (a.isFavorite && !b.isFavorite) return -1;
            if (!a.isFavorite && b.isFavorite) return 1;
            return b.createdAt.compareTo(a.createdAt);
          });
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error toggling favorite: $e');
      return false;
    }
  }

  void selectCharacter(Character character) {
    _selectedCharacter = character;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCharacter = null;
    notifyListeners();
  }

  CharacterChat getCharacterChat(String characterId) {
    return _characterChats[characterId] ??= CharacterChat(characterId: characterId);
  }

  void addMessageToCharacterChat(String characterId, Message message) {
    final chat = getCharacterChat(characterId);
    chat.messages.add(message);
    notifyListeners();
  }

  void clearCharacterChat(String characterId) {
    _characterChats[characterId] = CharacterChat(characterId: characterId);
    notifyListeners();
  }

  List<String> generateRandomAvatarUrls(int count) {
    final random = Random();
    const imageIds = [
      'photo-1507003211169-0a1dd7228f2d',
      'photo-1472099645785-5658abf4ff4e',
      'photo-1560250097-0b93528c311a',
      'photo-1531891437562-4301cf35b7e4',
      'photo-1557804506-669a67965ba0',
      'photo-1582750433449-648ed127bb54',
    ];
    
    return List.generate(count, (index) {
      final imageId = imageIds[random.nextInt(imageIds.length)];
      return 'https://images.unsplash.com/$imageId?w=150&h=150&fit=crop&crop=face';
    });
  }

  List<int> generateRandomColors(int count) {
    final colors = [
      0xFFE3F2FD, // Light Blue
      0xFFE8F5E8, // Light Green
      0xFFFFF3E0, // Light Orange
      0xFFF3E5F5, // Light Purple
      0xFFFCE4EC, // Light Pink
      0xFFE0F2F1, // Light Teal
    ];
    
    return List.generate(count, (index) => colors[index % colors.length]);
  }
}