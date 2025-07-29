import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'local_llm_service.dart';
import 'models.dart';

class HostedModelChatPage extends StatefulWidget {
  final String modelId;
  final String modelName;

  const HostedModelChatPage({
    super.key,
    required this.modelId,
    required this.modelName,
  });

  @override
  State<HostedModelChatPage> createState() => _HostedModelChatPageState();
}

class _HostedModelChatPageState extends State<HostedModelChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LocalLLMService _llmService = LocalLLMService();
  
  final List<Message> _messages = [];
  bool _isLoading = false;
  StreamSubscription<String>? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _chatSubscription?.cancel();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(Message.bot(
        'Hello! I\'m ${widget.modelName}, a hosted AI model. I\'m ready to chat with you right away - no setup required! How can I help you today?',
      ));
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = Message.user(text);
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      // Prepare chat messages for the API
      final chatMessages = _messages
          .map((m) => {
                'role': m.sender == Sender.user ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      final stream = await _llmService.chatWithHostedModel(
        widget.modelId,
        chatMessages,
      );

      String accumulatedResponse = '';
      final botMessage = Message.bot('', isStreaming: true);
      setState(() {
        _messages.add(botMessage);
      });

      _chatSubscription = stream.listen(
        (chunk) {
          accumulatedResponse += chunk;
          setState(() {
            _messages[_messages.length - 1] = Message.bot(
              accumulatedResponse,
              isStreaming: true,
            );
          });
          _scrollToBottom();
        },
        onDone: () {
          setState(() {
            _messages[_messages.length - 1] = Message.bot(
              accumulatedResponse,
              isStreaming: false,
            );
            _isLoading = false;
          });
          _scrollToBottom();
        },
        onError: (error) {
          setState(() {
            _messages[_messages.length - 1] = Message.bot(
              'Error: $error',
              isStreaming: false,
            );
            _isLoading = false;
          });
          _scrollToBottom();
        },
      );
    } catch (e) {
      setState(() {
        _messages.add(Message.bot('Error: $e'));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
    _addWelcomeMessage();
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F4),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF000000),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.modelName,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF000000),
              ),
            ),
            Text(
              'Hosted Model • Ready to Chat',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF10B981),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageTile(message);
                    },
                  ),
          ),
          _buildInputSection(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFEAE9E5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud,
              size: 40,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chat with ${widget.modelName}',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This hosted model is ready to chat!\nNo setup or downloads required.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFFA3A3A3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(Message message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
                     Container(
             width: 32,
             height: 32,
             decoration: BoxDecoration(
               color: message.sender == Sender.user ? const Color(0xFF000000) : const Color(0xFF10B981),
               borderRadius: BorderRadius.circular(16),
             ),
             child: Icon(
               message.sender == Sender.user ? Icons.person : Icons.smart_toy,
               color: Colors.white,
               size: 20,
             ),
           ),
          const SizedBox(width: 12),
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                                         Text(
                       message.sender == Sender.user ? 'You' : widget.modelName,
                       style: GoogleFonts.inter(
                         fontSize: 14,
                         fontWeight: FontWeight.w600,
                         color: const Color(0xFF000000),
                       ),
                     ),
                    if (message.isStreaming) ...[
                      const SizedBox(width: 8),
                                               SizedBox(
                           width: 12,
                           height: 12,
                           child: CircularProgressIndicator(
                             strokeWidth: 2,
                             valueColor: AlwaysStoppedAnimation<Color>(
                               message.sender == Sender.user ? const Color(0xFF000000) : const Color(0xFF10B981),
                             ),
                           ),
                         ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: message.sender == Sender.user ? const Color(0xFFEAE9E5) : Colors.white,
                       borderRadius: BorderRadius.circular(12),
                       border: message.sender == Sender.user ? null : Border.all(
                         color: const Color(0xFFE5E5E5),
                       ),
                     ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                                             message.sender == Sender.user
                           ? Text(
                               message.text,
                               style: GoogleFonts.inter(
                                 fontSize: 14,
                                 color: const Color(0xFF000000),
                               ),
                             )
                           : MarkdownBody(
                               data: message.text,
                              styleSheet: MarkdownStyleSheet(
                                p: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF000000),
                                ),
                                code: GoogleFonts.firaCode(
                                  fontSize: 13,
                                  backgroundColor: const Color(0xFFF3F4F6),
                                ),
                                codeblockDecoration: const BoxDecoration(
                                  color: Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                              ),
                            ),
                                             if (message.sender != Sender.user && !message.isStreaming) ...[
                         const SizedBox(height: 8),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.end,
                           children: [
                             IconButton(
                               onPressed: () => _copyMessage(message.text),
                               icon: const Icon(
                                 Icons.copy_rounded,
                                 size: 16,
                                 color: Color(0xFFA3A3A3),
                               ),
                             ),
                           ],
                         ),
                       ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E5E5)),
        ),
      ),
      child: Column(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Hosted Model Ready',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Input row
          MessageInput(
            controller: _controller,
            isLoading: _isLoading,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const MessageInput({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF000000),
              ),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFFA3A3A3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFF000000),
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: isLoading ? null : onSend,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
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
        ),
      ],
    );
  }
}