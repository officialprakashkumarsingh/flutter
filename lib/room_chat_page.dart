import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'models/collaboration_models.dart';
import 'services/collaboration_service.dart';
import 'widgets/collaboration_input_bar.dart';
import 'widgets/collaboration_message_bubble.dart';
import 'package:http/http.dart' as http;

class RoomChatPage extends StatefulWidget {
  final CollaborationRoom room;
  final String selectedModel;

  const RoomChatPage({super.key, required this.room, required this.selectedModel});

  @override
  State<RoomChatPage> createState() => _RoomChatPageState();
}

class _RoomChatPageState extends State<RoomChatPage> {
  final _collaborationService = CollaborationService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<RoomMessage> _messages = [];
  List<RoomMember> _members = [];
  bool _isLoading = true;
  bool _isSendingMessage = false;
  bool _showMembers = false;
  RoomMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _initializeRoom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeRoom() async {
    try {
      // Subscribe to real-time updates
      _collaborationService.subscribeToMessages(widget.room.id);
      _collaborationService.subscribeToMembers(widget.room.id);

      // Listen to messages stream
      _collaborationService.messagesStream.listen((messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
          });
          _scrollToBottom();
        }
      });

      // Listen to members stream
      _collaborationService.membersStream.listen((members) {
        if (mounted) {
          setState(() {
            _members = members;
          });
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to initialize room: ${e.toString()}', isError: true);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS systemGroupedBackground
      appBar: _buildIOSAppBar(),
      body: Stack(
        children: [
          _isLoading ? _buildLoadingState() : _buildChatInterface(),
          if (_showMembers) _buildMembersDrawer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildIOSAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(
          color: const Color(0xFFE5E5EA).withOpacity(0.3),
          height: 0.5,
        ),
      ),
      leading: IconButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        icon: const Icon(
          CupertinoIcons.chevron_left,
          size: 24,
          color: Color(0xFF007AFF),
        ),
      ),
      title: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _showMembers = !_showMembers);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.room.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF000000),
              ),
            ),
            Text(
              '${_members.length} member${_members.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Copy invite code
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _copyInviteCode();
          },
          icon: const Icon(
            CupertinoIcons.doc_on_clipboard,
            size: 20,
            color: Color(0xFF007AFF),
          ),
        ),
        // Room menu
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _showIOSActionSheet(context);
          },
          icon: const Icon(
            CupertinoIcons.ellipsis,
            size: 20,
            color: Color(0xFF007AFF),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF09090B)),
      ),
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        // Room info banner
        if (widget.room.description != null) _buildRoomInfoBanner(),
        
        // Messages
        Expanded(child: _buildMessagesList()),
        
        // Reply preview bar
        if (_replyingTo != null) _buildReplyPreview(),
        
        // Input area
        CollaborationInputBar(
          controller: _messageController,
          onSend: _sendMessage,
          isSending: _isSendingMessage,
        ),
      ],
    );
  }

  Widget _buildRoomInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF09090B)),
              const SizedBox(width: 8),
              Text(
                'Room Description',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF09090B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.room.description!,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF71717A),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return _buildEmptyMessagesState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
                                return CollaborationMessageBubble(
                          message: message,
                          isOwnMessage: message.isOwnMessage,
                          onReply: _handleReply,
                        );
      },
    );
  }

  Widget _buildEmptyMessagesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: const FaIcon(
              FontAwesomeIcons.comments,
              size: 28,
              color: Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start the conversation',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF09090B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to send a message in this room',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF71717A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(RoomMessage message, bool isFirstInGroup) {
    final isOwn = message.isOwnMessage;
    final isAI = message.messageType == MessageType.ai;
    final isSystem = message.messageType == MessageType.system;

    if (isSystem) {
      return _buildSystemMessage(message);
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: 4,
        top: isFirstInGroup ? 16 : 2,
      ),
      child: Column(
        crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isFirstInGroup) ...[
            Row(
              mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isOwn && !isAI) ...[
                  _buildUserAvatar(message.userName),
                  const SizedBox(width: 8),
                ],
                Text(
                  isAI ? 'AhamAI' : message.userName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isAI ? const Color(0xFF7C3AED) : const Color(0xFF09090B),
                  ),
                ),
                if (isOwn) ...[
                  const SizedBox(width: 8),
                  _buildUserAvatar(message.userName),
                ],
              ],
            ),
            const SizedBox(height: 4),
          ],
          
          Row(
            mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOwn && !isFirstInGroup) const SizedBox(width: 40),
              
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isOwn 
                        ? const Color(0xFF09090B)
                        : isAI
                            ? const Color(0xFFF3F0FF)
                            : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: !isOwn && !isAI 
                        ? Border.all(color: const Color(0xFFE4E4E7))
                        : null,
                  ),
                  child: Text(
                    message.content,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isOwn 
                          ? Colors.white
                          : isAI
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF09090B),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (isFirstInGroup) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isOwn) const SizedBox(width: 40),
                Text(
                  _formatTime(message.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemMessage(RoomMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E4E7)),
          ),
          child: Text(
            message.content,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF71717A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String userName) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: _getAvatarColor(userName),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE4E4E7), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE4E4E7)),
                color: const Color(0xFFF8F9FA),
              ),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF09090B),
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF71717A),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Send button
          GestureDetector(
            onTap: _isSendingMessage ? null : _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isSendingMessage 
                    ? const Color(0xFF71717A)
                    : const Color(0xFF09090B),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isSendingMessage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Members (${_members.length})',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF09090B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showMembers = false),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF09090B)),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE4E4E7)),
            
            Expanded(
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  return ListTile(
                    leading: _buildUserAvatar(member.userName ?? 'Unknown'),
                    title: Text(
                      member.userName ?? 'Unknown User',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF09090B),
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: member.isActive 
                                ? const Color(0xFF10B981) 
                                : const Color(0xFF6B7280),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          member.isAdmin 
                              ? 'Admin ${member.isActive ? '• Online' : '• Offline'}'
                              : member.isActive ? 'Online' : 'Offline',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: member.isAdmin 
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF71717A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: member.isAdmin
                        ? const Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 16,
                            color: Color(0xFF7C3AED),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSendingMessage) return;

    setState(() => _isSendingMessage = true);
    _messageController.clear();

    try {
      // Send user message
      await _collaborationService.sendMessage(widget.room.id, content);

      // Check if message mentions AI or asks a question
      final shouldTrigger = _shouldTriggerAI(content);
      print('Message: "$content" | Should trigger AI: $shouldTrigger');
      
      if (shouldTrigger) {
        try {
          // Get recent chat history and members for context
          final recentMessages = await _collaborationService.getRoomMessages(widget.room.id, limit: 10);
          final roomMembers = await _collaborationService.getRoomMembers(widget.room.id);
          print('Got ${recentMessages.length} recent messages and ${roomMembers.length} members for context');
          
          // Get AI response with full context
          final aiResponse = await _generateAIResponse(content, recentMessages, roomMembers);
          print('AI Response length: ${aiResponse.length}');
          
          if (aiResponse.isNotEmpty) {
            // Send AI response to room
            await _collaborationService.sendAIResponse(widget.room.id, aiResponse);
            print('AI response sent successfully');
          } else {
            print('AI response was empty');
          }
        } catch (aiError) {
          print('AI Error: $aiError');
          _showSnackBar('AI response failed: ${aiError.toString()}', isError: true);
        }
      }
      
      // Clear reply context after sending
      setState(() {
        _replyingTo = null;
      });
      
    } catch (e) {
      _showSnackBar('Failed to send message: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isSendingMessage = false);
    }
  }

  bool _shouldTriggerAI(String message) {
    final lowercaseMessage = message.toLowerCase();
    
    // Explicit AI mentions
    if (lowercaseMessage.contains('ahamai') || 
        lowercaseMessage.contains('@ai') ||
        lowercaseMessage.contains('hey ai') ||
        lowercaseMessage.contains('ask ai')) {
      return true;
    }
    
    // Question patterns
    if (lowercaseMessage.contains('?') ||
        lowercaseMessage.startsWith('what') ||
        lowercaseMessage.startsWith('how') ||
        lowercaseMessage.startsWith('why') ||
        lowercaseMessage.startsWith('when') ||
        lowercaseMessage.startsWith('where') ||
        lowercaseMessage.startsWith('who') ||
        lowercaseMessage.startsWith('can you') ||
        lowercaseMessage.startsWith('could you') ||
        lowercaseMessage.startsWith('would you')) {
      return true;
    }
    
    // Help requests
    if (lowercaseMessage.contains('help') ||
        lowercaseMessage.contains('explain') ||
        lowercaseMessage.contains('clarify') ||
        lowercaseMessage.contains('understand') ||
        lowercaseMessage.contains('confused')) {
      return true;
    }
    
    // Conversational triggers (only for longer messages to avoid spam)
    if (message.length > 20 && (
        lowercaseMessage.contains('think') ||
        lowercaseMessage.contains('opinion') ||
        lowercaseMessage.contains('suggest') ||
        lowercaseMessage.contains('recommend') ||
        lowercaseMessage.contains('advice'))) {
      return true;
    }
    
    return false;
  }

  Future<String> _generateAIResponse(String prompt, List<RoomMessage> recentMessages, List<RoomMember> roomMembers) async {
    try {
      final request = http.Request('POST', Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ahamaibyprakash25',
      });

      // Get current user info
      final currentUserId = _collaborationService.currentUserId;
      final currentUserName = _collaborationService.currentUserName;
      
      // Build conversation context from recent messages and room info
      List<Map<String, String>> messages = [
        {
          'role': 'system',
          'content': '''You are AhamAI, an intelligent assistant participating in a collaborative chat room.

Room Context:
- Room Name: "${widget.room.name}"
- Room ID: "${widget.room.id}"
- Room Description: "${widget.room.description ?? 'No description'}"
- Total Members: ${roomMembers.length}
- Active Members: ${roomMembers.map((m) => m.userName).join(', ')}

Current Message Context:
- Message Author: ${recentMessages.isNotEmpty ? recentMessages.last.userName : 'Unknown'}
- Author ID: ${recentMessages.isNotEmpty ? recentMessages.last.userId : 'Unknown'}
- Current User: $currentUserName (ID: $currentUserId)
- Is Author Current User: ${recentMessages.isNotEmpty ? (recentMessages.last.userId == currentUserId) : false}

Member Details:
${roomMembers.map((m) => '- ${m.userName} (ID: ${m.userId})${m.isActive ? ' [ACTIVE]' : ' [INACTIVE]'}').join('\n')}

Guidelines:
- Provide helpful, accurate, and concise responses
- Engage naturally in conversations with multiple users
- Reference previous messages and participants by name when relevant
- You can see who sent each message and their activity status
- Be aware of member relationships and interactions
- Keep responses conversational but informative
- Be friendly and approachable while maintaining professionalism
- You can mention specific users by name when appropriate
- Understand the room dynamics and member participation'''
        }
      ];

      // Add recent chat history for context (excluding AI's own messages to avoid loops)
      final contextMessages = recentMessages
          .where((msg) => msg.messageType != 'ai')
          .take(8) // Limit context to avoid token overflow
          .toList()
          .reversed
          .toList();

      if (contextMessages.isNotEmpty) {
        String conversationContext = "Recent conversation:\n";
        for (final msg in contextMessages) {
          final speaker = msg.messageType == 'system' ? 'System' : msg.userName;
          conversationContext += "$speaker: ${msg.content}\n";
        }
        conversationContext += "\nCurrent message: $prompt";

        messages.add({
          'role': 'user',
          'content': conversationContext
        });
      } else {
        messages.add({
          'role': 'user',
          'content': prompt
        });
      }

      final body = jsonEncode({
        'model': widget.selectedModel,
        'messages': messages,
        'max_tokens': 1200,
        'temperature': 0.7,
      });

      request.body = body;
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('AI API Response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final content = jsonResponse['choices']?[0]?['message']?['content'] ?? '';
        print('AI API Success: Content length ${content.length}');
        return content.toString().trim();
      } else {
        print('AI API Error: ${response.statusCode} - ${response.body}');
        return '';
      }
    } catch (e) {
      print('Error generating AI response: $e');
      return '';
    }
  }

  void _handleReply(RoomMessage message) {
    setState(() {
      _replyingTo = message;
    });
    _messageController.text = '@${message.userName} ';
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(
            color: Color(0xFF09090B),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyingTo!.userName}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF09090B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.content,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF71717A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _replyingTo = null;
              });
              _messageController.clear();
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF71717A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.xmark,
                size: 12,
                color: Color(0xFF71717A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: widget.room.inviteCode));
    _showSnackBar('Invite code copied: ${widget.room.inviteCode}');
  }

  void _showIOSActionSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showRoomInfo();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.info,
                  size: 20,
                  color: CupertinoColors.systemBlue.resolveFrom(context),
                ),
                const SizedBox(width: 8),
                const Text('Room Info'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _leaveRoom();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.arrow_right_square,
                  size: 20,
                  color: CupertinoColors.destructiveRed,
                ),
                const SizedBox(width: 8),
                const Text('Leave Room'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'info':
        _showRoomInfo();
        break;
      case 'leave':
        _leaveRoom();
        break;
    }
  }

  void _showRoomInfo() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text(
          'Room Information',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF000000),
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIOSInfoRow('Name', widget.room.name),
              if (widget.room.description != null)
                _buildIOSInfoRow('Description', widget.room.description!),
              _buildIOSInfoRow('Invite Code', widget.room.inviteCode),
              _buildIOSInfoRow('Members', '${_members.length}/${widget.room.maxMembers}'),
              _buildIOSInfoRow('Created', _formatDate(widget.room.createdAt)),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIOSInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              color: Color(0xFF000000),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveRoom() async {
    final shouldLeave = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text(
          'Leave Room',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF000000),
          ),
        ),
        content: Text(
          'Are you sure you want to leave "${widget.room.name}"?',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF000000),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontSize: 17,
              ),
            ),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Leave',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      try {
        await _collaborationService.leaveRoom(widget.room.id);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        _showSnackBar('Failed to leave room: ${e.toString()}', isError: true);
      }
    }
  }

  Color _getAvatarColor(String userName) {
    final colors = [
      const Color(0xFF7C3AED),
      const Color(0xFF059669),
      const Color(0xFFDC2626),
      const Color(0xFF2563EB),
      const Color(0xFFD97706),
      const Color(0xFF9333EA),
    ];
    
    final hash = userName.hashCode;
    return colors[hash.abs() % colors.length];
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}