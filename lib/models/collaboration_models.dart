import 'package:flutter/material.dart';

/// Collaboration Room Model
class CollaborationRoom {
  final String id;
  final String name;
  final String? description;
  final String inviteCode;
  final String createdBy;
  final int maxMembers;
  final bool isActive;
  final Map<String, dynamic> settings;
  final DateTime lastActivity;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional properties for UI
  final int memberCount;
  final String? lastMessage;
  final bool hasUnreadMessages;

  CollaborationRoom({
    required this.id,
    required this.name,
    this.description,
    required this.inviteCode,
    required this.createdBy,
    this.maxMembers = 10,
    this.isActive = true,
    this.settings = const {"allowFileSharing": true, "allowVoiceNotes": false},
    required this.lastActivity,
    required this.createdAt,
    required this.updatedAt,
    this.memberCount = 0,
    this.lastMessage,
    this.hasUnreadMessages = false,
  });

  factory CollaborationRoom.fromJson(Map<String, dynamic> json) {
    return CollaborationRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      inviteCode: json['invite_code'] as String,
      createdBy: json['created_by'] as String,
      maxMembers: json['max_members'] as int? ?? 10,
      isActive: json['is_active'] as bool? ?? true,
      settings: json['settings'] as Map<String, dynamic>? ?? {"allowFileSharing": true, "allowVoiceNotes": false},
      lastActivity: DateTime.parse(json['last_activity'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      memberCount: json['member_count'] as int? ?? 0,
      lastMessage: json['last_message'] as String?,
      hasUnreadMessages: json['has_unread_messages'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'invite_code': inviteCode,
      'created_by': createdBy,
      'max_members': maxMembers,
      'is_active': isActive,
      'settings': settings,
      'last_activity': lastActivity.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CollaborationRoom copyWith({
    String? id,
    String? name,
    String? description,
    String? inviteCode,
    String? createdBy,
    int? maxMembers,
    bool? isActive,
    Map<String, dynamic>? settings,
    DateTime? lastActivity,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? memberCount,
    String? lastMessage,
    bool? hasUnreadMessages,
  }) {
    return CollaborationRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy ?? this.createdBy,
      maxMembers: maxMembers ?? this.maxMembers,
      isActive: isActive ?? this.isActive,
      settings: settings ?? this.settings,
      lastActivity: lastActivity ?? this.lastActivity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberCount: memberCount ?? this.memberCount,
      lastMessage: lastMessage ?? this.lastMessage,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
    );
  }
}

/// Room Member Model
class RoomMember {
  final String id;
  final String roomId;
  final String userId;
  final String role; // 'admin' or 'member'
  final DateTime joinedAt;
  final DateTime lastSeen;
  final bool isActive;

  // Additional properties for UI
  final String? userName;
  final String? userEmail;
  final String? avatarUrl;
  final bool isOnline;

  RoomMember({
    required this.id,
    required this.roomId,
    required this.userId,
    this.role = 'member',
    required this.joinedAt,
    required this.lastSeen,
    this.isActive = true,
    this.userName,
    this.userEmail,
    this.avatarUrl,
    this.isOnline = false,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      lastSeen: DateTime.parse(json['last_seen'] as String),
      isActive: json['is_active'] as bool? ?? true,
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      'last_seen': lastSeen.toIso8601String(),
      'is_active': isActive,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isMember => role == 'member';

  RoomMember copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? role,
    DateTime? joinedAt,
    DateTime? lastSeen,
    bool? isActive,
    String? userName,
    String? userEmail,
    String? avatarUrl,
    bool? isOnline,
  }) {
    return RoomMember(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isActive: isActive ?? this.isActive,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

/// Room Message Model
class RoomMessage {
  final String id;
  final String roomId;
  final String? userId;
  final String userName;
  final String content;
  final MessageType messageType;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  // Additional properties for UI
  final bool isOwnMessage;
  final Color? userColor;

  RoomMessage({
    required this.id,
    required this.roomId,
    this.userId,
    required this.userName,
    required this.content,
    this.messageType = MessageType.user,
    this.metadata = const {},
    required this.createdAt,
    this.isOwnMessage = false,
    this.userColor,
  });

  factory RoomMessage.fromJson(Map<String, dynamic> json) {
    return RoomMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String,
      content: json['content'] as String,
      messageType: MessageType.fromString(json['message_type'] as String? ?? 'user'),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      isOwnMessage: json['is_own_message'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'user_name': userName,
      'content': content,
      'message_type': messageType.value,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  RoomMessage copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? userName,
    String? content,
    MessageType? messageType,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    bool? isOwnMessage,
    Color? userColor,
  }) {
    return RoomMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      isOwnMessage: isOwnMessage ?? this.isOwnMessage,
      userColor: userColor ?? this.userColor,
    );
  }
}

/// Message Type Enum
enum MessageType {
  user('user'),
  ai('ai'),
  system('system');

  const MessageType(this.value);
  final String value;

  static MessageType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'ai':
        return MessageType.ai;
      case 'system':
        return MessageType.system;
      case 'user':
      default:
        return MessageType.user;
    }
  }
}

/// Room Creation Request Model
class CreateRoomRequest {
  final String name;
  final String? description;
  final int maxMembers;
  final Map<String, dynamic> settings;

  CreateRoomRequest({
    required this.name,
    this.description,
    this.maxMembers = 10,
    this.settings = const {"allowFileSharing": true, "allowVoiceNotes": false},
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'max_members': maxMembers,
      'settings': settings,
    };
  }
}

/// Join Room Request Model
class JoinRoomRequest {
  final String inviteCode;

  JoinRoomRequest({required this.inviteCode});

  Map<String, dynamic> toJson() {
    return {
      'invite_code': inviteCode,
    };
  }
}

/// Typing Indicator Model
class TypingIndicator {
  final String userId;
  final String userName;
  final String roomId;
  final DateTime timestamp;

  TypingIndicator({
    required this.userId,
    required this.userName,
    required this.roomId,
    required this.timestamp,
  });

  factory TypingIndicator.fromJson(Map<String, dynamic> json) {
    return TypingIndicator(
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      roomId: json['room_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'room_id': roomId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Check if typing indicator is still active (within last 3 seconds)
  bool get isActive {
    return DateTime.now().difference(timestamp).inSeconds < 3;
  }
}