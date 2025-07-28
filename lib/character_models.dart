// Character models for the Characters page
import 'models.dart';

class Character {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String avatarUrl;
  final bool isBuiltIn;
  final DateTime createdAt;
  final String? customTag; // New property for custom tags
  final int? backgroundColor; // New property for background color (ARGB int value)

  Character({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.avatarUrl,
    required this.isBuiltIn,
    required this.createdAt,
    this.customTag,
    this.backgroundColor,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'systemPrompt': systemPrompt,
      'avatarUrl': avatarUrl,
      'isBuiltIn': isBuiltIn,
      'createdAt': createdAt.toIso8601String(),
      'customTag': customTag,
      'backgroundColor': backgroundColor,
    };
  }

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      systemPrompt: json['systemPrompt'],
      avatarUrl: json['avatarUrl'],
      isBuiltIn: json['isBuiltIn'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      customTag: json['customTag'],
      backgroundColor: json['backgroundColor'],
    );
  }

  Character copyWith({
    String? id,
    String? name,
    String? description,
    String? systemPrompt,
    String? avatarUrl,
    bool? isBuiltIn,
    DateTime? createdAt,
    String? customTag,
    int? backgroundColor,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      customTag: customTag ?? this.customTag,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}

class CharacterChat {
  final String characterId;
  final String characterName;
  final List<Message> messages;
  final DateTime lastUpdated;

  CharacterChat({
    required this.characterId,
    required this.characterName,
    required this.messages,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'characterId': characterId,
      'characterName': characterName,
      'messages': messages.map((m) => {
        'id': m.id,
        'sender': m.sender.toString(),
        'text': m.text,
        'timestamp': m.timestamp.toIso8601String(),
      }).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  static CharacterChat fromJson(Map<String, dynamic> json) {
    final messagesList = json['messages'] as List<dynamic>? ?? [];
    final messages = messagesList.map((messageJson) {
      return Message(
        id: messageJson['id'],
        sender: messageJson['sender'] == 'Sender.user' ? Sender.user : Sender.bot,
        text: messageJson['text'],
        timestamp: DateTime.parse(messageJson['timestamp']),
      );
    }).toList();
    
    return CharacterChat(
      characterId: json['characterId'],
      characterName: json['characterName'],
      messages: messages,
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}