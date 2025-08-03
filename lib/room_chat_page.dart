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
  // Removed _showMembers - no longer needed since count is shown in room list
  RoomMessage? _replyingTo;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _initializeRoom();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    final bool showButton = _scrollController.hasClients && 
        _scrollController.offset < _scrollController.position.maxScrollExtent - 100;
    if (showButton != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = showButton;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeRoom() async {
    try {
      // Initialize collaboration service first
      await _collaborationService.initialize();
      
      // Load initial members to ensure we have current data
      final initialMembers = await _collaborationService.getRoomMembers(widget.room.id);
      if (mounted) {
        setState(() {
          _members = initialMembers;
        });
      }
      
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
    // Set status bar to be visible with dark content
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F4), // Cream background
      extendBody: true,
      appBar: _buildHomeStyleAppBar(),
      body: CustomPaint(
        painter: RoomPatternPainter(),
        child: Stack(
          children: [
            _isLoading ? _buildLoadingState() : _buildChatInterface(),
            // Removed member drawer - count already shown in room list
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHomeStyleAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF9F7F4), // Cream background like home
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFF9F7F4), // Match background
        statusBarIconBrightness: Brightness.dark,
      ),
      leading: IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const FaIcon(
          FontAwesomeIcons.arrowLeft, // Better back icon
          size: 18,
          color: Color(0xFF09090B),
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.room.name,
            style: GoogleFonts.spaceMono( // Same font as AhamAI
              fontSize: 18, // Bigger like homescreen
              fontWeight: FontWeight.w600,
              color: const Color(0xFF09090B),
            ),
          ),
          if (widget.room.description != null && widget.room.description!.isNotEmpty)
            Text(
              widget.room.description!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        // Copy invite code
        IconButton(
          onPressed: _copyInviteCode,
          icon: const FaIcon(
            FontAwesomeIcons.copy,
            size: 18,
            color: Color(0xFF09090B),
          ),
        ),
        // Room menu
        IconButton(
          onPressed: () => _showShadcnActionSheet(context),
          icon: const FaIcon(
            FontAwesomeIcons.ellipsisVertical,
            size: 18,
            color: Color(0xFF09090B),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return _buildChatShimmerLoading();
  }

  Widget _buildChatShimmerLoading() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(8, (index) => _buildChatShimmerItem(index)),
      ),
    );
  }

  Widget _buildChatShimmerItem(int index) {
    final isLeft = index % 2 == 0; // Alternate left/right like chat
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isLeft) ...[
            // Left side shimmer (AI message style)
            Flexible(
              child: Container(
                padding: const EdgeInsets.only(right: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerBox(double.infinity, 16),
                    const SizedBox(height: 4),
                    _buildShimmerBox(200, 16),
                    const SizedBox(height: 4),
                    _buildShimmerBox(150, 16),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Right side shimmer (User message style)
            Flexible(
              child: Container(
                padding: const EdgeInsets.only(left: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE5E7EB),
                            Color(0xFFF3F4F6),
                            Color(0xFFE5E7EB),
                          ],
                        ),
                      ),
                      child: _buildShimmerBox(120, 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmerBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment(-1.0, 0.0),
          end: Alignment(1.0, 0.0),
          colors: [
            Color(0xFFF3F4F6),
            Color(0xFFE5E7EB),
            Color(0xFFF3F4F6),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    return CustomPaint(
      painter: RoomPatternPainter(),
      child: Stack(
        children: [
          Column(
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
          ),
          
          // Scroll to bottom button
          _buildScrollToBottomButton(),
        ],
      ),
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
        
        // Alternate messages: 1st user left, 2nd AI right, 3rd user left, 4th AI right
        // Count only user and AI messages for alternation
        int userAiMessageIndex = 0;
        for (int i = 0; i <= index; i++) {
          if (_messages[i].messageType == 'user' || _messages[i].messageType == 'ai') {
            if (i == index) break;
            userAiMessageIndex++;
          }
        }
        
        bool isOwnMessage;
        if (message.messageType == 'system') {
          isOwnMessage = false; // System messages always center
        } else {
          // Alternate: odd index (1st, 3rd, 5th...) = left, even index (2nd, 4th, 6th...) = right
          isOwnMessage = userAiMessageIndex % 2 == 1; // 0-based: 0=left, 1=right, 2=left, 3=right
        }
        
        return CollaborationMessageBubble(
          message: message,
          isOwnMessage: isOwnMessage,
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

  Widget _buildScrollToBottomButton() {
    if (!_showScrollToBottom) return const SizedBox.shrink();
    
    return Positioned(
      right: 16,
      bottom: 100, // Above input area
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF09090B), // Black background
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _scrollToBottom,
            child: const Center(
              child: FaIcon(
                FontAwesomeIcons.chevronDown,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
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

  // Removed _buildMembersDrawer - no longer needed since member count is shown in room list

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSendingMessage) return;

    setState(() => _isSendingMessage = true);
    _messageController.clear();

    try {
      // Send user message
      await _collaborationService.sendMessage(widget.room.id, content);

      // AI is always awake - analyze ALL messages for relevance
      final shouldTrigger = await _shouldTriggerAI(content);
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

  Future<bool> _shouldTriggerAI(String message) async {
    final lowercaseMessage = message.toLowerCase();
    
    // Always trigger for explicit AI mentions
    if (lowercaseMessage.contains('ahamai') || 
        lowercaseMessage.contains('@ai') ||
        lowercaseMessage.contains('hey ai') ||
        lowercaseMessage.contains('ask ai')) {
      return true;
    }
    
    // Always trigger for direct questions
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
    
    // Always trigger for help requests
    if (lowercaseMessage.contains('help') ||
        lowercaseMessage.contains('explain') ||
        lowercaseMessage.contains('clarify') ||
        lowercaseMessage.contains('understand') ||
        lowercaseMessage.contains('confused')) {
      return true;
    }
    
    // For other messages, use AI to intelligently determine relevance
    try {
      final relevanceCheck = await _checkMessageRelevance(message);
      return relevanceCheck;
    } catch (e) {
      print('Relevance check failed: $e');
      // Fallback to conservative triggers for conversational content
      if (message.length > 15 && (
          lowercaseMessage.contains('think') ||
          lowercaseMessage.contains('opinion') ||
          lowercaseMessage.contains('suggest') ||
          lowercaseMessage.contains('recommend') ||
          lowercaseMessage.contains('advice') ||
          lowercaseMessage.contains('should') ||
          lowercaseMessage.contains('better') ||
          lowercaseMessage.contains('good') ||
          lowercaseMessage.contains('bad'))) {
        return true;
      }
      return false;
    }
  }

  Future<bool> _checkMessageRelevance(String message) async {
    try {
      final request = http.Request('POST', Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ahamaibyprakash25',
      });

      // Use AI to determine if the message needs a response
      final relevancePrompt = '''Analyze this message and determine if an AI assistant should respond.

Message: "$message"

Context: This is from a collaborative chat room where people discuss various topics.

Respond with ONLY "true" or "false" based on these criteria:
- true: If the message asks for information, seeks advice, mentions a problem, discusses ideas, asks opinions, or would benefit from AI insight
- true: If the message is educational, technical, or informational in nature
- true: If the message seems to be seeking help or clarification
- false: If it's just casual chit-chat, greetings, or simple statements
- false: If it's personal conversation between specific users
- false: If it's very short (under 10 characters) unless it's a clear question

Be intelligent and helpful - err on the side of being responsive rather than silent.''';

      request.body = jsonEncode({
        'model': widget.selectedModel,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a relevance classifier. Respond with only "true" or "false".'
          },
          {
            'role': 'user',
            'content': relevancePrompt
          }
        ],
        'max_tokens': 10,
        'temperature': 0.1,
      });

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final relevanceResult = data['choices'][0]['message']['content'].toLowerCase().trim();
        return relevanceResult.contains('true');
      } else {
        print('Relevance check API error: ${response.statusCode}');
        return false; // Conservative fallback
      }
    } catch (e) {
      print('Relevance check error: $e');
      return false; // Conservative fallback
    }
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF25D366).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Reply icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const FaIcon(
              FontAwesomeIcons.reply,
              size: 12,
              color: Color(0xFF25D366),
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Replying to ',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                    Text(
                      _replyingTo!.messageType == 'ai' ? 'AhamAI' : _replyingTo!.userName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _replyingTo!.messageType == 'ai' 
                            ? const Color(0xFF7C3AED) 
                            : const Color(0xFF25D366),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.content,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF09090B),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          GestureDetector(
            onTap: () {
              setState(() {
                _replyingTo = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF71717A).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.xmark,
                size: 10,
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

  void _showShadcnActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E4E7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Room Info Action
            _buildActionSheetItem(
              icon: Icons.info_outline_rounded,
              label: 'Room Info',
              onTap: () {
                Navigator.pop(context);
                _showRoomInfo();
              },
            ),
            
            // Leave Room Action
            _buildActionSheetItem(
              icon: Icons.logout_rounded,
              label: 'Leave Room',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _leaveRoom();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Cancel button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFF8F9FA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: Color(0xFFE4E4E7),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF09090B),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSheetItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE4E4E7),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isDestructive 
                      ? const Color(0xFFDC2626) 
                      : const Color(0xFF09090B),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDestructive 
                        ? const Color(0xFFDC2626) 
                        : const Color(0xFF09090B),
                  ),
                ),
              ],
            ),
          ),
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

class RoomPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Create subtle dot pattern like homescreen
    final dotPaint = Paint()
      ..color = const Color(0xFFF5F5DC).withOpacity(0.2) // Subtle pattern like home
      ..style = PaintingStyle.fill;
    
    const dotSize = 1.0;
    const spacing = 25.0; // Wider spacing for cleaner look
    
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}