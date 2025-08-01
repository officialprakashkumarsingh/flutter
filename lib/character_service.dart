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
    loadCharacters();
    
    // Listen for auth state changes
    SupabaseAuthService.authStateChanges.listen((authState) {
      if (SupabaseAuthService.isSignedIn) {
        loadCharacters();
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

  Future<void> loadCharacters() async {
    if (!SupabaseAuthService.isSignedIn) {
      return;
    }
    
    try {
      final charactersFromDb = await SupabaseCharacterService.getUserCharacters();
      print('🔍 CharacterService.loadCharacters() - Loaded ${charactersFromDb.length} characters from Supabase');
      
      // If no characters exist, create built-in characters as fallback
      if (charactersFromDb.isEmpty) {
        print('📝 No characters found, creating built-in characters...');
        await _createBuiltInCharacters();
        // Try loading again after creating built-in characters
        final charactersAfterCreation = await SupabaseCharacterService.getUserCharacters();
        _characters.clear();
        _characters.addAll(charactersAfterCreation);
        print('✅ Created and loaded ${charactersAfterCreation.length} built-in characters');
      } else {
        _characters.clear();
        _characters.addAll(charactersFromDb);
      }
      
      notifyListeners();
    } catch (e) {
      print('❌ Error loading characters from Supabase: $e');
      // Create fallback characters locally if database fails
      await _createFallbackCharacters();
    }
  }

  Future<void> _createBuiltInCharacters() async {
    final builtInCharacters = [
      {
        'name': 'Narendra Modi',
        'description': 'Prime Minister of India, visionary leader',
        'systemPrompt': 'You are Narendra Modi, the Prime Minister of India. You speak with authority, vision, and deep love for your country. You often reference India\'s rich heritage, development goals, and your commitment to serving the people. You use phrases like "my dear friends" and often mention Digital India, Make in India, and other initiatives. You are optimistic, determined, and always focused on India\'s progress and the welfare of its citizens. You sometimes use Hindi phrases naturally in conversation.',
        'avatarUrl': 'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=150&h=150&fit=crop&crop=face',
        'customTag': 'Politician',
        'backgroundColor': 4294901760,
      },
      {
        'name': 'Elon Musk',
        'description': 'CEO of Tesla & SpaceX, Tech Visionary',
        'systemPrompt': 'You are Elon Musk, the innovative entrepreneur behind Tesla, SpaceX, and other groundbreaking companies. You think big, move fast, and aren\'t afraid to take risks. You\'re passionate about sustainable energy, space exploration, and advancing human civilization. You often make bold predictions about the future, love discussing technology and engineering challenges, and sometimes make playful or unexpected comments. You\'re direct, sometimes blunt, but always focused on solving humanity\'s biggest challenges. You occasionally reference memes and have a quirky sense of humor.',
        'avatarUrl': 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150&h=150&fit=crop&crop=face',
        'customTag': 'Tech CEO',
        'backgroundColor': 4293848563,
      },
      {
        'name': 'Virat Kohli',
        'description': 'Cricket Superstar, Former Indian Captain',
        'systemPrompt': 'You are Virat Kohli, one of the greatest cricket batsmen of all time and former captain of the Indian cricket team. You\'re passionate, competitive, and incredibly dedicated to fitness and excellence. You speak with energy and enthusiasm about cricket, training, and the importance of hard work. You often mention your love for the game, respect for teammates, and pride in representing India. You\'re motivational, disciplined, and always encourage others to give their best effort. You sometimes share insights about cricket techniques, mental toughness, and the importance of staying focused under pressure.',
        'avatarUrl': 'https://images.unsplash.com/photo-1531891437562-4301cf35b7e4?w=150&h=150&fit=crop&crop=face',
        'customTag': 'Cricketer',
        'backgroundColor': 4293982696,
      },
    ];

    print('📝 Creating ${builtInCharacters.length} built-in characters...');
    
    for (final characterData in builtInCharacters) {
      try {
        print('🔄 Creating character: ${characterData['name']}');
        final result = await SupabaseCharacterService.createCharacter(
          name: characterData['name'] as String,
          description: characterData['description'] as String,
          systemPrompt: characterData['systemPrompt'] as String,
          avatarUrl: characterData['avatarUrl'] as String,
          customTag: characterData['customTag'] as String,
          backgroundColor: characterData['backgroundColor'] as int,
          isFavorite: false,
          isBuiltIn: true,
        );
        print('✅ Created built-in character: ${characterData['name']} with ID: $result');
      } catch (e) {
        print('❌ Failed to create built-in character ${characterData['name']}: $e');
        print('❌ Stack trace: ${StackTrace.current}');
      }
    }
    
    print('📝 Finished creating built-in characters');
  }

  Future<void> _createFallbackCharacters() async {
    print('📝 Creating fallback characters locally...');
    _characters.clear();
    _characters.addAll([
      Character(
        id: 'fallback_1',
        name: 'Narendra Modi',
        description: 'Prime Minister of India, visionary leader',
        systemPrompt: 'You are Narendra Modi, the Prime Minister of India...',
        avatarUrl: 'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=150&h=150&fit=crop&crop=face',
        customTag: 'Politician',
        backgroundColor: 4294901760,
        isBuiltIn: true,
        createdAt: DateTime.now(),
      ),
      Character(
        id: 'fallback_2',
        name: 'Elon Musk',
        description: 'CEO of Tesla & SpaceX, Tech Visionary',
        systemPrompt: 'You are Elon Musk, the innovative entrepreneur...',
        avatarUrl: 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150&h=150&fit=crop&crop=face',
        customTag: 'Tech CEO',
        backgroundColor: 4293848563,
        isBuiltIn: true,
        createdAt: DateTime.now(),
      ),
    ]);
    notifyListeners();
    print('✅ Created ${_characters.length} fallback characters');
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

  String generateId() {
    return 'char_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  void saveCharacterChat(String characterId, String characterName, List<Message> messages) {
    _characterChats[characterId] = CharacterChat(
      characterId: characterId,
      characterName: characterName,
      messages: messages,
      lastUpdated: DateTime.now(),
    );
    notifyListeners();
  }

  void deleteCharacterChat(String characterId) {
    _characterChats.remove(characterId);
    notifyListeners();
  }
}