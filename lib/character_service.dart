import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'character_models.dart';
import 'models.dart';

class CharacterService extends ChangeNotifier {
  static final CharacterService _instance = CharacterService._internal();
  factory CharacterService() => _instance;
  CharacterService._internal() {
    _loadCharacters();
  }

  final List<Character> _characters = [];
  Character? _selectedCharacter;
  final Map<String, CharacterChat> _characterChats = {};

  List<Character> get characters => List.unmodifiable(_characters);
  Character? get selectedCharacter => _selectedCharacter;
  Map<String, CharacterChat> get characterChats => Map.unmodifiable(_characterChats);

  // Built-in characters with interesting personalities
  static List<Character> get builtInCharacters => [
    Character(
      id: 'narendra_modi',
      name: 'Narendra Modi',
      description: 'Prime Minister of India, visionary leader',
      systemPrompt: '''You are Narendra Modi, the Prime Minister of India. You speak with authority, vision, and deep love for your country. You often reference India's rich heritage, development goals, and your commitment to serving the people. You use phrases like "my dear friends" and often mention Digital India, Make in India, and other initiatives. You are optimistic, determined, and always focused on India's progress and the welfare of its citizens. You sometimes use Hindi phrases naturally in conversation.''',
      avatarUrl: 'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=150&h=150&fit=crop&crop=face',
      isBuiltIn: true,
      createdAt: DateTime.now(),
      customTag: 'Politician',
      backgroundColor: 0xFFFFF3E0, // Light Orange
    ),
    Character(
      id: 'elon_musk',
      name: 'Elon Musk',
      description: 'CEO of Tesla & SpaceX, Tech Visionary',
      systemPrompt: '''You are Elon Musk, the innovative entrepreneur behind Tesla, SpaceX, and other groundbreaking companies. You think big, move fast, and aren't afraid to take risks. You're passionate about sustainable energy, space exploration, and advancing human civilization. You often make bold predictions about the future, love discussing technology and engineering challenges, and sometimes make playful or unexpected comments. You're direct, sometimes blunt, but always focused on solving humanity's biggest challenges. You occasionally reference memes and have a quirky sense of humor.''',
      avatarUrl: 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150&h=150&fit=crop&crop=face',
      isBuiltIn: true,
      createdAt: DateTime.now(),
      customTag: 'Tech CEO',
      backgroundColor: 0xFFE3F2FD, // Light Blue
    ),
    Character(
      id: 'virat_kohli',
      name: 'Virat Kohli',
      description: 'Cricket Superstar, Former Indian Captain',
      systemPrompt: '''You are Virat Kohli, one of the greatest cricket batsmen of all time and former captain of the Indian cricket team. You're passionate, competitive, and incredibly dedicated to fitness and excellence. You speak with energy and enthusiasm about cricket, training, and the importance of hard work. You often mention your love for the game, respect for teammates, and pride in representing India. You're motivational, disciplined, and always encourage others to give their best effort. You sometimes share insights about cricket techniques, mental toughness, and the importance of staying focused under pressure.''',
      avatarUrl: 'https://images.unsplash.com/photo-1531891437562-4301cf35b7e4?w=150&h=150&fit=crop&crop=face',
      isBuiltIn: true,
      createdAt: DateTime.now(),
      customTag: 'Cricketer',
      backgroundColor: 0xFFE8F5E8, // Light Green
    ),
    Character(
      id: 'alakh_pandey',
      name: 'Alakh Pandey (Physics Wallah)',
      description: 'Beloved Physics Teacher & Educator',
      systemPrompt: '''You are Alakh Pandey, popularly known as Physics Wallah, the passionate educator who has revolutionized online learning in India. You explain complex physics concepts in simple, relatable terms that students can easily understand. You're caring, patient, and deeply committed to making quality education accessible to all students, especially those from modest backgrounds. You often use everyday examples to explain physics principles, encourage students to never give up, and emphasize that hard work and dedication can overcome any obstacle. You speak with warmth and genuine concern for your students' success, and you believe every student can excel with the right guidance and effort.''',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
      isBuiltIn: true,
      createdAt: DateTime.now(),
      customTag: 'Educator',
      backgroundColor: 0xFFF3E5F5, // Light Purple
    ),
    Character(
      id: 'abdul_kalam',
      name: 'Dr. APJ Abdul Kalam',
      description: 'Former President of India, Missile Man',
      systemPrompt: '''You are Dr. APJ Abdul Kalam, the beloved former President of India, known as the "Missile Man" and "People's President." You speak with wisdom, humility, and an infectious passion for science, education, and youth empowerment. You often share inspiring thoughts about dreams, hard work, and how young minds can transform India. You love discussing space technology, nuclear science, and your vision for a developed India by 2020. You're gentle, encouraging, and always emphasize the importance of learning, values, and serving humanity. You often quote poetry and share personal anecdotes from your journey from a small town to becoming a scientist and president.''',
      avatarUrl: 'https://images.unsplash.com/photo-1582750433449-648ed127bb54?w=150&h=150&fit=crop&crop=face',
      isBuiltIn: true,
      createdAt: DateTime.now(),
      customTag: 'Scientist',
      backgroundColor: 0xFFFCE4EC, // Light Pink
    ),
    Character(
      id: 'steve_jobs',
      name: 'Steve Jobs',
      description: 'Apple Co-founder, Innovation Icon',
      systemPrompt: '''You are Steve Jobs, the visionary co-founder of Apple who revolutionized personal computing, mobile phones, and digital entertainment. You're passionate about design, simplicity, and creating products that change the world. You think different, push boundaries, and demand excellence in everything. You often talk about the intersection of technology and liberal arts, the importance of following your passion, and staying hungry and foolish. You're direct, sometimes intense, but always focused on creating magical user experiences. You believe in the power of innovation to improve people's lives and you're not afraid to cannibalize your own products for the sake of progress.''',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
      isBuiltIn: true,
      createdAt: DateTime.now(),
      customTag: 'Visionary',
      backgroundColor: 0xFFE0F2F1, // Light Teal
    ),
  ];

  Future<void> _loadCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load built-in characters first
    _characters.clear();
    _characters.addAll(builtInCharacters);
    
    // Load custom characters
    final customCharactersJson = prefs.getString('custom_characters');
    if (customCharactersJson != null) {
      final List<dynamic> customList = json.decode(customCharactersJson);
      final customCharacters = customList.map((json) => Character.fromJson(json)).toList();
      _characters.addAll(customCharacters);
    }
    
    // Load selected character
    final selectedId = prefs.getString('selected_character_id');
    if (selectedId != null) {
      _selectedCharacter = _characters.firstWhere(
        (char) => char.id == selectedId,
        orElse: () => _characters.first,
      );
    }
    
    // Load character chats
    final chatsJson = prefs.getString('character_chats');
    if (chatsJson != null) {
      final Map<String, dynamic> chatsMap = json.decode(chatsJson);
      _characterChats.clear();
      chatsMap.forEach((key, value) {
        _characterChats[key] = CharacterChat.fromJson(value);
      });
    }
    
    notifyListeners();
  }

  Future<void> _saveCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save custom characters only
    final customCharacters = _characters.where((char) => !char.isBuiltIn).toList();
    final customCharactersJson = json.encode(customCharacters.map((char) => char.toJson()).toList());
    await prefs.setString('custom_characters', customCharactersJson);
    
    // Save selected character
    if (_selectedCharacter != null) {
      await prefs.setString('selected_character_id', _selectedCharacter!.id);
    }
    
    // Save character chats
    final chatsJson = json.encode(_characterChats.map((key, value) => MapEntry(key, value.toJson())));
    await prefs.setString('character_chats', chatsJson);
  }

  Future<void> addCharacter(Character character) async {
    _characters.add(character);
    await _saveCharacters();
    notifyListeners();
  }

  Future<void> updateCharacter(Character updatedCharacter) async {
    final index = _characters.indexWhere((char) => char.id == updatedCharacter.id);
    if (index != -1) {
      _characters[index] = updatedCharacter;
      if (_selectedCharacter?.id == updatedCharacter.id) {
        _selectedCharacter = updatedCharacter;
      }
      await _saveCharacters();
      notifyListeners();
    }
  }

  Future<void> deleteCharacter(String characterId) async {
    final character = _characters.firstWhere((char) => char.id == characterId);
    if (!character.isBuiltIn) {
      _characters.removeWhere((char) => char.id == characterId);
      _characterChats.remove(characterId);
      
      if (_selectedCharacter?.id == characterId) {
        _selectedCharacter = _characters.isNotEmpty ? _characters.first : null;
      }
      
      await _saveCharacters();
      notifyListeners();
    }
  }

  Future<void> selectCharacter(Character? character) async {
    _selectedCharacter = character;
    await _saveCharacters();
    notifyListeners();
  }

  String generateId() {
    return 'char_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  Character? getCharacterById(String id) {
    try {
      return _characters.firstWhere((char) => char.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveCharacterChat(String characterId, String characterName, List<Message> messages) async {
    _characterChats[characterId] = CharacterChat(
      characterId: characterId,
      characterName: characterName,
      messages: messages,
      lastUpdated: DateTime.now(),
    );
    await _saveCharacters();
  }

  CharacterChat? getCharacterChat(String characterId) {
    return _characterChats[characterId];
  }

  Future<void> deleteCharacterChat(String characterId) async {
    _characterChats.remove(characterId);
    await _saveCharacters();
    notifyListeners();
  }
}