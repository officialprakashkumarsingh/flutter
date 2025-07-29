/* ----------------------------------------------------------
   MODELS
---------------------------------------------------------- */
enum Sender { user, bot }

class ThoughtContent {
  final String text;
  final String type; // 'thinking', 'thoughts', 'think', 'thought', 'reason', 'reasoning'
  
  ThoughtContent({required this.text, required this.type});
}

class CodeContent {
  final String code;
  final String language; // 'dart', 'python', 'javascript', etc.
  final String extension; // '.dart', '.py', '.js', etc.
  
  CodeContent({required this.code, required this.language, required this.extension});
}

class Message {
  final String id;
  final String text;
  final Sender sender;
  final bool isStreaming;
  final String? imagePath;
  final DateTime timestamp;
  final String displayText;
  final Map<String, dynamic> toolData;
  final List<ThoughtContent> thoughts;
  final List<CodeContent> codes;

  Message({
    String? id,
    required this.text,
    required this.sender,
    this.isStreaming = false,
    this.imagePath,
    DateTime? timestamp,
    String? displayText,
    this.toolData = const {},
    this.thoughts = const [],
    this.codes = const [],
  }) : id = id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
       timestamp = timestamp ?? DateTime.now(),
       displayText = displayText ?? text;

  factory Message.user(String text, {String? imagePath}) {
    return Message(
      text: text,
      sender: Sender.user,
      imagePath: imagePath,
    );
  }

  factory Message.bot(String text, {bool isStreaming = false, Map<String, dynamic>? toolData}) {
    return Message(
      text: text,
      sender: Sender.bot,
      isStreaming: isStreaming,
      toolData: toolData ?? {},
    );
  }

  bool get isUser => sender == Sender.user;
  bool get isBot => sender == Sender.bot;
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  Message copyWith({
    String? id,
    String? text,
    Sender? sender,
    bool? isStreaming,
    String? imagePath,
    DateTime? timestamp,
    String? displayText,
    Map<String, dynamic>? toolData,
    List<ThoughtContent>? thoughts,
    List<CodeContent>? codes,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      isStreaming: isStreaming ?? this.isStreaming,
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
      displayText: displayText ?? this.displayText,
      toolData: toolData ?? this.toolData,
      thoughts: thoughts ?? this.thoughts,
      codes: codes ?? this.codes,
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