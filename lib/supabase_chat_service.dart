import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'file_attachment_service.dart';
import 'dart:typed_data';

class SupabaseChatService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // Save current conversation to Supabase
  static Future<String?> saveConversation({
    required List<Message> messages,
    required List<String> conversationMemory,
    String? conversationId,
    String title = 'New Chat',
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Convert messages to JSON
      final messagesJson = messages.map((message) => {
        'id': message.id, // Include message ID
        'text': message.text,
        'sender': message.sender.toString(),
        'timestamp': message.timestamp.toIso8601String(),
        'isStreaming': message.isStreaming,
        'attachments': message.attachments.map((attachment) => {
          'name': attachment.name,
          'size': attachment.size,
          'filePath': attachment.filePath,
          'isApk': attachment.isApk,
        }).toList(),
      }).toList();

      if (conversationId != null) {
        // Update existing conversation
        await _supabase
            .from('chat_conversations')
            .update({
              'messages': messagesJson,
              'conversation_memory': conversationMemory,
              'title': title,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', conversationId)
            .eq('user_id', userId);
        
        return conversationId;
      } else {
        // Create new conversation
        final response = await _supabase
            .from('chat_conversations')
            .insert({
              'user_id': userId,
              'title': title,
              'messages': messagesJson,
              'conversation_memory': conversationMemory,
            })
            .select('id')
            .single();
        
        return response['id'] as String;
      }
    } catch (e) {
      print('Error saving conversation: $e');
      return null;
    }
  }
  
  // Load conversation by ID
  static Future<Map<String, dynamic>?> loadConversation(String conversationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 SupabaseChatService.loadConversation() - Loading conversation: $conversationId for user: $userId');

      final response = await _supabase
          .from('chat_conversations')
          .select()
          .eq('id', conversationId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        print('🔍 SupabaseChatService.loadConversation() - No conversation found for ID: $conversationId');
        return null;
      }

      print('🔍 SupabaseChatService.loadConversation() - Found conversation: ${response['title']} with ${(response['messages'] as List).length} messages');

      // Convert JSON back to Messages
      final messagesJson = response['messages'] as List<dynamic>;
      final messages = messagesJson.map((messageData) {
        // Reconstruct attachments
        final attachmentsData = messageData['attachments'] as List<dynamic>? ?? [];
        final attachments = attachmentsData.map<FileAttachment>((attachmentData) {
          return FileAttachment(
            id: attachmentData['name'] ?? '',
            name: attachmentData['name'] ?? '',
            filePath: attachmentData['filePath'] ?? '',
            mimeType: 'application/octet-stream',
            size: attachmentData['size'] ?? 0,
            uploadedAt: DateTime.now(),
            bytes: Uint8List(0), // Empty bytes since we don't store the actual file content
            isImage: false,
            isZip: false,
            isText: false,
            isCode: false,
            isPdf: false,
            isApk: attachmentData['isApk'] ?? false,
          );
        }).toList();
        
        return Message(
          id: messageData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(), // Preserve original ID if available
          text: messageData['text'] ?? '',
          sender: (messageData['sender'] as String) == 'Sender.user' ? Sender.user : Sender.bot,
          timestamp: DateTime.parse(messageData['timestamp'] ?? DateTime.now().toIso8601String()),
          isStreaming: messageData['isStreaming'] ?? false,
          attachments: attachments,
        );
      }).toList();

      final conversationMemory = List<String>.from(
        response['conversation_memory'] as List<dynamic>? ?? []
      );

      final result = {
        'id': response['id'],
        'title': response['title'],
        'messages': messages,
        'conversationMemory': conversationMemory,
        'createdAt': DateTime.parse(response['created_at']),
        'updatedAt': DateTime.parse(response['updated_at']),
      };
      
      print('🔍 SupabaseChatService.loadConversation() - Successfully loaded conversation with ${messages.length} messages');
      
      return result;
    } catch (e) {
      print('❌ Error loading conversation: $e');
      return null;
    }
  }
  
  // Load the most recent conversation for current user
  static Future<Map<String, dynamic>?> loadLatestConversation() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('chat_conversations')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return loadConversation(response['id']);
    } catch (e) {
      print('Error loading latest conversation: $e');
      return null;
    }
  }
  
  // Get all conversations for current user
  static Future<List<Map<String, dynamic>>> getUserConversations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 SupabaseChatService.getUserConversations() - Fetching for user: $userId');
      
      final response = await _supabase
          .from('chat_conversations')
          .select('id, title, created_at, updated_at')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      print('🔍 SupabaseChatService.getUserConversations() - Raw response: ${response.length} conversations');
      for (var i = 0; i < response.length; i++) {
        print('🔍   [$i] ID: ${response[i]['id']}, Title: ${response[i]['title']}');
      }

      final result = response.map<Map<String, dynamic>>((conversation) => {
        'id': conversation['id'],
        'title': conversation['title'],
        'createdAt': DateTime.parse(conversation['created_at']),
        'updatedAt': DateTime.parse(conversation['updated_at']),
      }).toList();
      
      print('🔍 SupabaseChatService.getUserConversations() - Processed result: ${result.length} conversations');
      
      return result;
    } catch (e) {
      print('❌ Error getting user conversations: $e');
      return [];
    }
  }
  
  // Delete a conversation
  static Future<bool> deleteConversation(String conversationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('chat_conversations')
          .delete()
          .eq('id', conversationId)
          .eq('user_id', userId);
      
      return true;
    } catch (e) {
      print('Error deleting conversation: $e');
      return false;
    }
  }
  
  // Clear all conversations for current user
  static Future<bool> clearAllConversations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('chat_conversations')
          .delete()
          .eq('user_id', userId);
      
      return true;
    } catch (e) {
      print('Error clearing conversations: $e');
      return false;
    }
  }
  
  // Generate smart title for conversation based on first few messages
  static String generateConversationTitle(List<Message> messages) {
    if (messages.isEmpty) return 'New Chat';
    
    // Find first user message
    final firstUserMessage = messages.firstWhere(
      (message) => message.sender == Sender.user,
      orElse: () => messages.first,
    );
    
    // Extract first few words from the message
    final words = firstUserMessage.text.split(' ').take(5).join(' ');
    if (words.length > 30) {
      return '${words.substring(0, 30)}...';
    }
    
    return words.isNotEmpty ? words : 'New Chat';
  }
}