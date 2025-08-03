import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';

class DirectChatService {
  static final DirectChatService _instance = DirectChatService._internal();
  factory DirectChatService() => _instance;
  DirectChatService._internal();

  final supabase = Supabase.instance.client;
  String? _currentUserId;
  
  // Stream controllers for real-time updates
  final _chatsController = StreamController<List<DirectChat>>.broadcast();
  final _messagesController = StreamController<List<DirectMessage>>.broadcast();
  
  RealtimeChannel? _chatsSubscription;
  RealtimeChannel? _messagesSubscription;

  Stream<List<DirectChat>> get chatsStream => _chatsController.stream;
  Stream<List<DirectMessage>> get messagesStream => _messagesController.stream;

  Future<void> initialize() async {
    _currentUserId = supabase.auth.currentUser?.id;
    if (_currentUserId == null) throw Exception('User not authenticated');
    
    // Subscribe to real-time updates
    _subscribeToChats();
    _subscribeToMessages();
  }

  void _subscribeToChats() {
    _chatsSubscription = supabase
        .channel('direct_chats_${_currentUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_chats',
          callback: (payload) {
            print('Direct chats changed: $payload');
            getUserChats(); // Refresh chats
          },
        )
        .subscribe();
  }

  void _subscribeToMessages() {
    _messagesSubscription = supabase
        .channel('direct_messages_${_currentUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          callback: (payload) {
            print('Direct messages changed: $payload');
            // Refresh current chat messages if needed
          },
        )
        .subscribe();
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    
    final response = await supabase
        .from('profiles')
        .select('id, email, full_name, avatar_url')
        .ilike('email', '%$query%')
        .neq('id', _currentUserId!)
        .limit(10);

    return response.map((json) => UserProfile.fromJson(json)).toList();
  }

  Future<DirectChat> getOrCreateChat(String otherUserId) async {
    // Use the database function to get or create chat
    final response = await supabase.rpc(
      'get_or_create_direct_chat',
      params: {
        'user1_id': _currentUserId!,
        'user2_id': otherUserId,
      },
    );

    final chatId = response as String;
    
    // Get the full chat details
    final chatDetails = await supabase
        .from('direct_chats')
        .select('''
          *,
          profiles!participant_1(full_name, email),
          profiles!participant_2(full_name, email)
        ''')
        .eq('id', chatId)
        .single();

    // Determine the other user
    final isParticipant1 = chatDetails['participant_1'] == _currentUserId;
    final otherProfile = isParticipant1 
        ? chatDetails['profiles'][1] 
        : chatDetails['profiles'][0];

    final json = Map<String, dynamic>.from(chatDetails);
    json['other_user_name'] = otherProfile['full_name'];
    json['other_user_email'] = otherProfile['email'];

    return DirectChat.fromJson(json);
  }

  Future<List<DirectChat>> getUserChats() async {
    final response = await supabase
        .from('direct_chats')
        .select('*')
        .or('participant_1.eq.$_currentUserId,participant_2.eq.$_currentUserId')
        .order('updated_at', ascending: false);

    List<DirectChat> chats = [];
    
    for (final chatData in response) {
      // Get other user info
      final isParticipant1 = chatData['participant_1'] == _currentUserId;
      final otherUserId = isParticipant1 
          ? chatData['participant_2'] 
          : chatData['participant_1'];

      final otherUserResponse = await supabase
          .from('profiles')
          .select('full_name, email')
          .eq('id', otherUserId)
          .single();

      // Get unread count
      final unreadCount = await supabase
          .from('direct_messages')
          .select('id')
          .eq('chat_id', chatData['id'])
          .neq('sender_id', _currentUserId!)
          .eq('is_read', false)
          .count();

      // Get last message content if last_message_id exists
      String? lastMessageContent;
      if (chatData['last_message_id'] != null) {
        try {
          final lastMessage = await supabase
              .from('direct_messages')
              .select('content')
              .eq('id', chatData['last_message_id'])
              .single();
          lastMessageContent = lastMessage['content'];
        } catch (e) {
          // If message not found, continue without content
        }
      }

      final json = Map<String, dynamic>.from(chatData);
      json['other_user_name'] = otherUserResponse['full_name'];
      json['other_user_email'] = otherUserResponse['email'];
      json['last_message_content'] = lastMessageContent;
      json['unread_count'] = unreadCount.count;

      chats.add(DirectChat.fromJson(json));
    }

    _chatsController.add(chats);
    return chats;
  }

  Future<List<DirectMessage>> getChatMessages(String chatId) async {
    final response = await supabase
        .from('direct_messages')
        .select('''
          *,
          profiles!sender_id(full_name, email)
        ''')
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    final messages = response.map((json) {
      final messageJson = Map<String, dynamic>.from(json);
      final profile = json['profiles'];
      messageJson['sender_name'] = profile['full_name'];
      messageJson['sender_email'] = profile['email'];
      return DirectMessage.fromJson(messageJson);
    }).toList();

    _messagesController.add(messages);
    return messages;
  }

  Future<DirectMessage> sendMessage(String chatId, String content) async {
    final response = await supabase
        .from('direct_messages')
        .insert({
          'chat_id': chatId,
          'sender_id': _currentUserId!,
          'content': content,
          'message_type': 'text',
        })
        .select()
        .single();

    return DirectMessage.fromJson(response);
  }

  Future<void> markMessagesAsRead(String chatId) async {
    await supabase
        .from('direct_messages')
        .update({'is_read': true})
        .eq('chat_id', chatId)
        .neq('sender_id', _currentUserId!);
  }

  Future<void> deleteChat(String chatId) async {
    await supabase
        .from('direct_chats')
        .delete()
        .eq('id', chatId);
  }

  void dispose() {
    _chatsSubscription?.unsubscribe();
    _messagesSubscription?.unsubscribe();
    _chatsController.close();
    _messagesController.close();
  }
}