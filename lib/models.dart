import 'dart:typed_data';

/* ----------------------------------------------------------
   MODELS
---------------------------------------------------------- */
enum Sender { user, bot }

class ThoughtContent {
  final String content;
  final DateTime timestamp;

  ThoughtContent({
    required this.content,
    required this.timestamp,
  });
}

class CodeContent {
  final String language;
  final String code;
  final DateTime timestamp;

  CodeContent({
    required this.language,
    required this.code,
    required this.timestamp,
  });
}

class Message {
  String content;
  final bool isUser;
  final DateTime timestamp;
  final String? id;
  final String? displayText;
  final Map<String, dynamic>? toolData;
  final List<ThoughtContent>? thoughts;
  final List<CodeContent>? codes;
  final Uint8List? imageBytes;

  Message({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.id,
    this.displayText,
    this.toolData,
    this.thoughts,
    this.codes,
    this.imageBytes,
  });

  // Legacy constructors for compatibility
  factory Message.user(String text) {
    return Message(
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory Message.bot(String text) {
    return Message(
      content: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  factory Message.withImage({
    required String text,
    required Uint8List imageBytes,
    required bool isUser,
  }) {
    return Message(
      content: text,
      isUser: isUser,
      timestamp: DateTime.now(),
      imageBytes: imageBytes,
    );
  }

  factory Message.imageOnly({
    required Uint8List imageBytes,
    required bool isUser,
  }) {
    return Message(
      content: '',
      isUser: isUser,
      timestamp: DateTime.now(),
      imageBytes: imageBytes,
    );
  }

  factory Message.text({
    required String text,
    required bool isUser,
  }) {
    return Message(
      content: text,
      isUser: isUser,
      timestamp: DateTime.now(),
    );
  }

  factory Message.toolResponse({
    required String toolName,
    required Map<String, dynamic> response,
  }) {
    return Message(
      content: toolName,
      isUser: false,
      timestamp: DateTime.now(),
      toolData: response,
    );
  }

  factory Message.systemInfo({required String text}) {
    return Message(
      content: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  factory Message.thinking({required String text}) {
    return Message(
      content: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  // Legacy properties for compatibility
  String get text => content;
  String get sender => isUser ? 'user' : 'assistant';
  bool get isBot => !isUser;
  bool get hasImage => imageBytes != null;

  Message copyWith({
    String? content,
    bool? isUser,
    DateTime? timestamp,
    String? id,
    String? displayText,
    Map<String, dynamic>? toolData,
    List<ThoughtContent>? thoughts,
    List<CodeContent>? codes,
    Uint8List? imageBytes,
  }) {
    return Message(
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      id: id ?? this.id,
      displayText: displayText ?? this.displayText,
      toolData: toolData ?? this.toolData,
      thoughts: thoughts ?? this.thoughts,
      codes: codes ?? this.codes,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }
}

class ChatSession {
  final String title;
  final List<Message> messages;

  ChatSession({required this.title, required this.messages});
}

// NEW USER MODEL
class User {
  final String name;
  final String email;
  final String avatarUrl;

  User({required this.name, required this.email, required this.avatarUrl});
}