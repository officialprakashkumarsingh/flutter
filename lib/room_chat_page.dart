import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'models/collaboration_models.dart';
import 'services/collaboration_service.dart';
import 'package:http/http.dart' as http;

class RoomChatPage extends StatefulWidget {
  final CollaborationRoom room;

  const RoomChatPage({super.key, required this.room});

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
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingState() : _buildChatInterface(),
      endDrawer: _showMembers ? _buildMembersDrawer() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF09090B), size: 20),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.room.name,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF09090B),
            ),
          ),
          Text(
            '${_members.length} member${_members.length == 1 ? '' : 's'}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF71717A),
            ),
          ),
        ],
      ),
      actions: [
        // Copy invite code
        IconButton(
          onPressed: _copyInviteCode,
          icon: const Icon(Icons.content_copy_rounded, color: Color(0xFF09090B), size: 20),
          tooltip: 'Copy invite code',
        ),
        // Show members
        IconButton(
          onPressed: () => setState(() => _showMembers = !_showMembers),
          icon: const Icon(Icons.people_outlined, color: Color(0xFF09090B), size: 20),
          tooltip: 'Members',
        ),
        // Room menu
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF09090B), size: 20),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF09090B)),
                  SizedBox(width: 12),
                  Text('Room Info'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'leave',
              child: Row(
                children: [
                  Icon(Icons.exit_to_app, size: 18, color: Color(0xFFEF4444)),
                  SizedBox(width: 12),
                  Text('Leave Room', style: TextStyle(color: Color(0xFFEF4444))),
                ],
              ),
            ),
          ],
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
        
        // Input area
        _buildInputArea(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isFirstInGroup = index == 0 || 
            _messages[index - 1].userId != message.userId ||
            _messages[index].createdAt.difference(_messages[index - 1].createdAt).inMinutes > 5;
        
        return _buildMessageBubble(message, isFirstInGroup);
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
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 32,
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
                    subtitle: Text(
                      member.isAdmin ? 'Admin' : 'Member',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: member.isAdmin 
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF71717A),
                      ),
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
      if (_shouldTriggerAI(content)) {
        // Get AI response
        final aiResponse = await _generateAIResponse(content);
        if (aiResponse.isNotEmpty) {
          // Send AI response to room
          await _collaborationService.sendAIResponse(widget.room.id, aiResponse);
        }
      }
    } catch (e) {
      _showSnackBar('Failed to send message: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isSendingMessage = false);
    }
  }

  bool _shouldTriggerAI(String message) {
    final lowercaseMessage = message.toLowerCase();
    return lowercaseMessage.contains('ahamai') ||
           lowercaseMessage.contains('ai') ||
           lowercaseMessage.contains('?') ||
           lowercaseMessage.contains('explain') ||
           lowercaseMessage.contains('help') ||
           lowercaseMessage.contains('what') ||
           lowercaseMessage.contains('how') ||
           lowercaseMessage.contains('why');
  }

  Future<String> _generateAIResponse(String prompt) async {
    try {
      final request = http.Request('POST', Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ahamaibyprakash25',
      });

      final body = jsonEncode({
        'model': 'claude-3-5-sonnet-20241022',
        'messages': [
          {
            'role': 'system',
            'content': 'You are AhamAI participating in a collaborative chat room. Provide helpful, concise responses to questions and engage naturally in the conversation. Keep responses focused and conversational.'
          },
          {
            'role': 'user',
            'content': prompt
          }
        ],
        'max_tokens': 1000,
        'temperature': 0.7,
      });

      request.body = body;
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final content = jsonResponse['choices']?[0]?['message']?['content'] ?? '';
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

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: widget.room.inviteCode));
    _showSnackBar('Invite code copied: ${widget.room.inviteCode}');
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Room Information',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', widget.room.name),
            if (widget.room.description != null)
              _buildInfoRow('Description', widget.room.description!),
            _buildInfoRow('Invite Code', widget.room.inviteCode),
            _buildInfoRow('Members', '${_members.length}/${widget.room.maxMembers}'),
            _buildInfoRow('Created', _formatDate(widget.room.createdAt)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(color: const Color(0xFF09090B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF71717A),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF09090B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveRoom() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Leave Room',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to leave "${widget.room.name}"?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF71717A)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Leave',
              style: GoogleFonts.inter(color: const Color(0xFFEF4444)),
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