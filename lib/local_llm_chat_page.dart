import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'local_llm_service.dart';
import 'models.dart';

class LocalLLMChatPage extends StatefulWidget {
  final String modelId;
  final String modelName;

  const LocalLLMChatPage({
    super.key,
    required this.modelId,
    required this.modelName,
  });

  @override
  State<LocalLLMChatPage> createState() => _LocalLLMChatPageState();
}

class _LocalLLMChatPageState extends State<LocalLLMChatPage> {
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
        'Hello! I\'m ${widget.modelName}, Google\'s on-device AI model. I run locally on your device for complete privacy and offline capabilities. How can I help you today?',
      ));
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(Message.user(text));
    });

    _controller.clear();

    // Prepare messages for the service
    final chatMessages = _messages.where((m) => m.isUser || m.isBot).map((m) {
      return {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      };
    }).toList();

    // Add bot placeholder
    setState(() {
      _messages.add(Message.bot(''));
      _isLoading = true;
    });

    try {
      final stream = await _llmService.chatWithGemmaModel(
        widget.modelId,
        chatMessages,
      );

      String accumulatedText = '';
      _chatSubscription = stream.listen(
        (token) {
          accumulatedText += token;
          setState(() {
            _messages[_messages.length - 1] = Message.bot(accumulatedText);
          });
          _scrollToBottom();
        },
        onDone: () {
          setState(() {
            _isLoading = false;
          });
        },
        onError: (error) {
          setState(() {
            _messages[_messages.length - 1] = Message.bot('Error: $error');
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = Message.bot('Error: $e');
        _isLoading = false;
      });
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
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.modelName,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            Text(
              'Google Gemma • On-Device AI',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF4285F4),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              _addWelcomeMessage();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessage(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessage(Message message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: message.isUser ? const Color(0xFF4285F4) : const Color(0xFF34A853),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              message.isUser ? Icons.person : Icons.smart_toy,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.isUser ? 'You' : widget.modelName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isUser ? const Color(0xFFE3F2FD) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: message.isUser ? const Color(0xFF4285F4) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: message.isUser
                      ? Text(
                          message.text,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF1F2937),
                          ),
                        )
                      : MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF1F2937),
                            ),
                            code: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              backgroundColor: const Color(0xFFF3F4F6),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _controller,
                enabled: !_isLoading,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF9CA3AF),
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _isLoading ? const Color(0xFFE5E7EB) : const Color(0xFF4285F4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}