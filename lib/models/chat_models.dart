class DirectChat {
  final String id;
  final String participant1;
  final String participant2;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessageId;
  
  // Additional fields for UI
  final String? otherUserName;
  final String? otherUserEmail;
  final String? lastMessageContent;
  final int unreadCount;

  DirectChat({
    required this.id,
    required this.participant1,
    required this.participant2,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageId,
    this.otherUserName,
    this.otherUserEmail,
    this.lastMessageContent,
    this.unreadCount = 0,
  });

  factory DirectChat.fromJson(Map<String, dynamic> json) {
    return DirectChat(
      id: json['id'],
      participant1: json['participant_1'],
      participant2: json['participant_2'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastMessageId: json['last_message_id'],
      otherUserName: json['other_user_name'],
      otherUserEmail: json['other_user_email'],
      lastMessageContent: json['last_message_content'],
      unreadCount: json['unread_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participant_1': participant1,
      'participant_2': participant2,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message_id': lastMessageId,
      'other_user_name': otherUserName,
      'other_user_email': otherUserEmail,
      'last_message_content': lastMessageContent,
      'unread_count': unreadCount,
    };
  }
}

class DirectMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String messageType;
  final DateTime createdAt;
  final bool isRead;
  
  // Additional fields for UI
  final String? senderName;
  final String? senderEmail;

  DirectMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    required this.createdAt,
    this.isRead = false,
    this.senderName,
    this.senderEmail,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'],
      chatId: json['chat_id'],
      senderId: json['sender_id'],
      content: json['content'],
      messageType: json['message_type'] ?? 'text',
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'] ?? false,
      senderName: json['sender_name'],
      senderEmail: json['sender_email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'sender_name': senderName,
      'sender_email': senderEmail,
    };
  }
}

class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
      lastSeen: json['last_seen'] != null 
          ? DateTime.parse(json['last_seen']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }

  String get displayName => fullName?.isNotEmpty == true 
      ? fullName! 
      : email.split('@')[0];
}