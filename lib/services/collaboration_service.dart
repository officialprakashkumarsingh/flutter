import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/collaboration_models.dart';

class CollaborationService {
  static final CollaborationService _instance = CollaborationService._internal();
  factory CollaborationService() => _instance;
  CollaborationService._internal();

  final _supabase = Supabase.instance.client;
  
  // Stream controllers for real-time updates
  final _roomsController = StreamController<List<CollaborationRoom>>.broadcast();
  final _messagesController = StreamController<List<RoomMessage>>.broadcast();
  final _membersController = StreamController<List<RoomMember>>.broadcast();
  final _typingController = StreamController<List<TypingIndicator>>.broadcast();
  
  // Subscriptions for realtime
  RealtimeChannel? _roomsSubscription;
  RealtimeChannel? _messagesSubscription;
  RealtimeChannel? _membersSubscription;
  
  // Current state
  String? _currentRoomId;
  String? _currentUserId;
  String? _currentUserName;
  
  // Getters for streams
  Stream<List<CollaborationRoom>> get roomsStream => _roomsController.stream;
  Stream<List<RoomMessage>> get messagesStream => _messagesController.stream;
  Stream<List<RoomMember>> get membersStream => _membersController.stream;
  Stream<List<TypingIndicator>> get typingStream => _typingController.stream;

  /// Initialize the service with current user info
  Future<void> initialize() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _currentUserId = user.id;
      
      // Get user profile for name
      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();
      
      _currentUserName = profile['full_name'] ?? user.email?.split('@')[0] ?? 'Unknown';
    }
  }

  /// Generate a unique invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      6, (_) => chars.codeUnitAt(random.nextInt(chars.length))
    ));
  }

  /// Create a new collaboration room
  Future<CollaborationRoom> createRoom(CreateRoomRequest request) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Generate unique invite code
    String inviteCode;
    bool isUnique = false;
    do {
      inviteCode = _generateInviteCode();
      final existing = await _supabase
          .from('collaboration_rooms')
          .select('id')
          .eq('invite_code', inviteCode)
          .maybeSingle();
      isUnique = existing == null;
    } while (!isUnique);

    // Create room
    final roomData = {
      ...request.toJson(),
      'invite_code': inviteCode,
      'created_by': _currentUserId,
    };

    final response = await _supabase
        .from('collaboration_rooms')
        .insert(roomData)
        .select()
        .single();

    final room = CollaborationRoom.fromJson(response);

    // Add creator as admin member
    await _supabase.from('room_members').insert({
      'room_id': room.id,
      'user_id': _currentUserId,
      'role': 'admin',
    });

    // Send system message
    await _sendSystemMessage(room.id, '${_currentUserName} created the room');

    return room;
  }

  /// Join a room using invite code
  Future<CollaborationRoom> joinRoom(String inviteCode) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Find room by invite code
    final roomResponse = await _supabase
        .from('collaboration_rooms')
        .select()
        .eq('invite_code', inviteCode.toUpperCase())
        .eq('is_active', true)
        .single();

    final room = CollaborationRoom.fromJson(roomResponse);

    // Check if already a member
    final existingMember = await _supabase
        .from('room_members')
        .select('id')
        .eq('room_id', room.id)
        .eq('user_id', _currentUserId!)
        .maybeSingle();

    if (existingMember == null) {
      // Check room capacity
      final memberCount = await _supabase
          .from('room_members')
          .select('id')
          .eq('room_id', room.id)
          .eq('is_active', true)
          .count();

      if (memberCount.count >= room.maxMembers) {
        throw Exception('Room is full');
      }

      // Add as member
      await _supabase.from('room_members').insert({
        'room_id': room.id,
        'user_id': _currentUserId,
        'role': 'member',
      });

      // Send system message
      await _sendSystemMessage(room.id, '${_currentUserName} joined the room');
    }

    return room;
  }

  /// Get user's rooms
  Future<List<CollaborationRoom>> getUserRooms() async {
    if (_currentUserId == null) return [];

    // Get all rooms where user is a member
    final memberResponse = await _supabase
        .from('room_members')
        .select('room_id')
        .eq('user_id', _currentUserId!)
        .eq('is_active', true);

    final roomIds = memberResponse.map((m) => m['room_id'] as String).toList();
    
    if (roomIds.isEmpty) return [];

    // Get room details for user's rooms
    final response = await _supabase
        .from('collaboration_rooms')
        .select('*')
        .inFilter('id', roomIds)
        .eq('is_active', true)
        .order('last_activity', ascending: false);

    List<CollaborationRoom> rooms = [];
    
    for (var json in response) {
      final room = CollaborationRoom.fromJson(json);
      
      // Get member count for this room
      final memberCountResponse = await _supabase
          .from('room_members')
          .select('id')
          .eq('room_id', room.id)
          .eq('is_active', true);
      
      final roomWithCount = room.copyWith(memberCount: memberCountResponse.length);
      rooms.add(roomWithCount);
    }

    return rooms;
  }

  /// Subscribe to room updates
  void subscribeToRooms() {
    if (_currentUserId == null) return;

    _roomsSubscription?.unsubscribe();
    _roomsSubscription = _supabase
        .channel('rooms_$_currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'collaboration_rooms',
          callback: (payload) => _refreshRooms(),
        )
        .subscribe();
  }

  /// Subscribe to messages in a room
  void subscribeToMessages(String roomId) {
    _currentRoomId = roomId;
    
    _messagesSubscription?.unsubscribe();
    _messagesSubscription = _supabase
        .channel('messages_$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'room_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) => _refreshMessages(roomId),
        )
        .subscribe();

    // Initial load
    _refreshMessages(roomId);
  }

  /// Subscribe to room members
  void subscribeToMembers(String roomId) {
    _membersSubscription?.unsubscribe();
    _membersSubscription = _supabase
        .channel('members_$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'room_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) => _refreshMembers(roomId),
        )
        .subscribe();

    // Initial load
    _refreshMembers(roomId);
  }

  /// Send a message to a room
  Future<void> sendMessage(String roomId, String content) async {
    if (_currentUserId == null || _currentUserName == null) {
      throw Exception('User not authenticated');
    }

    // Security check: Verify user is member of this room
    final memberCheck = await _supabase
        .from('room_members')
        .select('id')
        .eq('room_id', roomId)
        .eq('user_id', _currentUserId!)
        .eq('is_active', true)
        .maybeSingle();
    
    if (memberCheck == null) {
      throw Exception('Access denied: You are not a member of this room');
    }

    await _supabase.from('room_messages').insert({
      'room_id': roomId,
      'user_id': _currentUserId,
      'user_name': _currentUserName,
      'content': content,
      'message_type': 'user',
    });
  }

  /// Send AI response to room
  Future<void> sendAIResponse(String roomId, String content) async {
    await _supabase.from('room_messages').insert({
      'room_id': roomId,
      'user_id': _currentUserId, // Use current user ID instead of null
      'user_name': 'AhamAI',
      'content': content,
      'message_type': 'ai',
    });
  }

  /// Send system message
  Future<void> _sendSystemMessage(String roomId, String content) async {
    await _supabase.from('room_messages').insert({
      'room_id': roomId,
      'user_id': _currentUserId, // Use current user ID instead of null
      'user_name': 'System',
      'content': content,
      'message_type': 'system',
    });
  }

  /// Get room messages
  Future<List<RoomMessage>> getRoomMessages(String roomId, {int limit = 50}) async {
    // Security check: Verify user is member of this room
    if (_currentUserId != null) {
      final memberCheck = await _supabase
          .from('room_members')
          .select('id')
          .eq('room_id', roomId)
          .eq('user_id', _currentUserId!)
          .eq('is_active', true)
          .maybeSingle();
      
      if (memberCheck == null) {
        throw Exception('Access denied: You are not a member of this room');
      }
    }

    final response = await _supabase
        .from('room_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);

    return response
        .map((json) => RoomMessage.fromJson(json).copyWith(
              isOwnMessage: json['user_id'] == _currentUserId,
            ))
        .toList()
        .reversed
        .toList();
  }

  /// Get room members
  Future<List<RoomMember>> getRoomMembers(String roomId) async {
    try {
      final response = await _supabase
          .from('room_members')
          .select('''
            *,
            profiles!inner(full_name, email)
          ''')
          .eq('room_id', roomId)
          .eq('is_active', true)
          .order('joined_at');

      print('Members response: ${response.length} members found for room $roomId');
      
      return response.map((json) {
        final profile = json['profiles'];
        final userName = profile['full_name'] ?? profile['email']?.split('@')[0] ?? 'Unknown User';
        final userEmail = profile['email'];
        
        // Add user info to the json before parsing
        json['user_name'] = userName;
        json['user_email'] = userEmail;
        
        return RoomMember.fromJson(json);
      }).toList();
    } catch (e) {
      print('Error getting room members: $e');
      return [];
    }
  }

  /// Leave a room
  Future<void> leaveRoom(String roomId) async {
    if (_currentUserId == null) return;

    await _supabase
        .from('room_members')
        .update({'is_active': false})
        .eq('room_id', roomId)
        .eq('user_id', _currentUserId!);

    await _sendSystemMessage(roomId, '${_currentUserName} left the room');
  }

  /// Delete a room (admin only)
  Future<void> deleteRoom(String roomId) async {
    if (_currentUserId == null) return;

    await _supabase
        .from('collaboration_rooms')
        .update({'is_active': false})
        .eq('id', roomId)
        .eq('created_by', _currentUserId!);
  }

  /// Send typing indicator
  void sendTypingIndicator(String roomId) {
    if (_currentUserId == null || _currentUserName == null) return;

    final typingData = TypingIndicator(
      userId: _currentUserId!,
      userName: _currentUserName!,
      roomId: roomId,
      timestamp: DateTime.now(),
    );

    // Send through realtime channel for instant delivery
    _messagesSubscription?.sendBroadcastMessage(
      event: 'typing',
      payload: typingData.toJson(),
    );
  }

  /// Private methods for refreshing data

  Future<void> _refreshRooms() async {
    try {
      final rooms = await getUserRooms();
      _roomsController.add(rooms);
    } catch (e) {
      print('Error refreshing rooms: $e');
    }
  }

  Future<void> _refreshMessages(String roomId) async {
    try {
      final messages = await getRoomMessages(roomId);
      _messagesController.add(messages);
    } catch (e) {
      print('Error refreshing messages: $e');
    }
  }

  Future<void> _refreshMembers(String roomId) async {
    try {
      final members = await getRoomMembers(roomId);
      _membersController.add(members);
    } catch (e) {
      print('Error refreshing members: $e');
    }
  }

  /// Clean up subscriptions
  void dispose() {
    _roomsSubscription?.unsubscribe();
    _messagesSubscription?.unsubscribe();
    _membersSubscription?.unsubscribe();
    
    _roomsController.close();
    _messagesController.close();
    _membersController.close();
    _typingController.close();
  }

  /// Get current user info
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  String? get currentRoomId => _currentRoomId;
}