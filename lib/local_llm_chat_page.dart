import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'local_llm_service.dart';
import 'models.dart';

class LocalLLMChatPage extends StatefulWidget {
  final LocalLLM localLLM;
  final String? selectedModel;

  const LocalLLMChatPage({
    super.key,
    required this.localLLM,
    this.selectedModel,
  });

  @override
  State<LocalLLMChatPage> createState() => _LocalLLMChatPageState();
}

class _LocalLLMChatPageState extends State<LocalLLMChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LocalLLMService _llmService = LocalLLMService();
  
  final List<Message> _messages = [];
  List<String> _availableModels = [];
  String? _selectedModel;
  bool _isLoading = false;
  bool _isLoadingModels = true;
  StreamSubscription<String>? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.selectedModel;
    _loadAvailableModels();
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
        'Hello! I\'m connected to ${widget.localLLM.name} running locally. How can I help you today?'
      ));
    });
  }

  Future<void> _loadAvailableModels() async {
    try {
      final models = await _llmService.getAvailableModels(widget.localLLM);
      setState(() {
        _availableModels = models;
        if (_selectedModel == null && models.isNotEmpty) {
          _selectedModel = models.first;
        }
        _isLoadingModels = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingModels = false;
      });
      _showError('Failed to load models: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showModelSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F3F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFC4C4C4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Select Model',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFFA3A3A3)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              LimitedBox(
                maxHeight: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _availableModels.length,
                  itemBuilder: (context, index) {
                    final model = _availableModels[index];
                    final isSelected = _selectedModel == model;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEAE9E5) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: const Color(0xFF000000)) : null,
                      ),
                      child: ListTile(
                        title: Text(
                          model,
                          style: GoogleFonts.robotoMono(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: const Color(0xFF000000),
                          ),
                        ),
                        trailing: isSelected 
                            ? const Icon(Icons.check_circle, color: Color(0xFF000000))
                            : null,
                        onTap: () {
                          setState(() => _selectedModel = model);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _selectedModel == null) return;

    _controller.clear();
    setState(() {
      _messages.add(Message.user(text));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Convert messages to the format expected by the local LLM
      final chatMessages = _messages.map((msg) {
        return {
          'role': msg.sender == Sender.user ? 'user' : 'assistant',
          'content': msg.text,
        };
      }).toList();

      // Add system message
      chatMessages.insert(0, {
        'role': 'system',
        'content': 'You are a helpful AI assistant running locally. Be concise and helpful.',
      });

      final stream = await _llmService.chatWithLocalLLM(
        widget.localLLM,
        _selectedModel!,
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
        },
        onError: (error) {
          setState(() {
            _messages[_messages.length - 1] = Message.bot(
              'Error: $error',
              isStreaming: false,
            );
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _messages.add(Message.bot('Error: $e'));
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _addWelcomeMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F3F0),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color(0xFF000000),
          ),
        ),
        title: GestureDetector(
          onTap: _showModelSelectionSheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.localLLM.name,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF000000),
                ),
              ),
              if (_selectedModel != null)
                Text(
                  _selectedModel!,
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: const Color(0xFFA3A3A3),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF000000),
            ),
          ),
          IconButton(
            onPressed: _showModelSelectionSheet,
            icon: const Icon(
              Icons.tune_rounded,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_isLoadingModels)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading available models...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFFA3A3A3),
                    ),
                  ),
                ],
              ),
            ),
          if (!_isLoadingModels && _availableModels.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFF87171),
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No models available. Make sure ${widget.localLLM.name} is running.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFFF87171),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generating response...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFFA3A3A3),
                    ),
                  ),
                ],
              ),
            ),
          _InputBar(
            controller: _controller,
            onSend: _sendMessage,
            enabled: !_isLoading && _selectedModel != null,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isBot = message.sender == Sender.bot;

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isBot ? Colors.transparent : const Color(0xFFEAE9E5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: isBot
            ? MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xFF000000),
                    fontWeight: FontWeight.w400,
                  ),
                  code: TextStyle(
                    backgroundColor: const Color(0xFFEAE9E5),
                    color: const Color(0xFF000000),
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0xFFEAE9E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            : Text(
                message.text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF000000),
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEAE9E5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
                style: const TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 16,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: enabled 
                      ? 'Message the local LLM...'
                      : 'Select a model first...',
                  hintStyle: const TextStyle(
                    color: Color(0xFFA3A3A3),
                    fontSize: 16,
                    height: 1.4,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 6),
              child: GestureDetector(
                onTap: enabled ? onSend : null,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: enabled 
                        ? const Color(0xFF000000)
                        : const Color(0xFFA3A3A3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}