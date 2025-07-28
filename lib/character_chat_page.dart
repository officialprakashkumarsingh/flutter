import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'character_models.dart';
import 'character_service.dart';

class CharacterChatPage extends StatefulWidget {
  final Character character;
  final String selectedModel;

  const CharacterChatPage({
    super.key,
    required this.character,
    required this.selectedModel,
  });

  @override
  State<CharacterChatPage> createState() => _CharacterChatPageState();
}

class _CharacterChatPageState extends State<CharacterChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <Message>[];
  bool _awaitingReply = false;
  String? _editingMessageId;

  StreamSubscription? _streamSubscription;
  http.Client? _httpClient;
  final CharacterService _characterService = CharacterService();

  // Character-specific prompts for engagement
  final List<String> _characterPrompts = [];

  // Robust function to fix server-side encoding errors (mojibake)
  String _fixServerEncoding(String text) {
    try {
      final originalBytes = latin1.encode(text);
      return utf8.decode(originalBytes, allowMalformed: true);
    } catch (e) {
      return text;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _generateCharacterPrompts();
    _controller.addListener(() {
      setState(() {}); // Refresh UI when text changes
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _streamSubscription?.cancel();
    _httpClient?.close();
    _saveCurrentChat();
    super.dispose();
  }

  void _initializeChat() {
    // Try to load existing chat for this character
    final existingChat = _characterService.getCharacterChat(widget.character.id);
    if (existingChat != null && existingChat.messages.isNotEmpty) {
      // Reconstruct messages from saved data
      _messages.addAll(existingChat.messages);
    } else {
      // Start with character's greeting
      _messages.add(Message.bot(_getCharacterGreeting()));
    }
  }

  String _getCharacterGreeting() {
    switch (widget.character.id) {
      case 'narendra_modi':
        return 'Namaste my dear friends! I am Narendra Modi. How can I help you today? Let\'s discuss India\'s bright future together!';
      case 'elon_musk':
        return 'Hey! Elon here. What\'s on your mind? Whether it\'s rockets, electric cars, or the future of humanity, I\'m all ears!';
      case 'virat_kohli':
        return 'Hello there! Virat Kohli here. Ready to talk cricket, fitness, or whatever\'s on your mind? Let\'s make it count!';
      case 'alakh_pandey':
        return 'Hello students! This is your Physics Wallah. Ready to learn something amazing today? Remember, every question is a good question!';
      case 'abdul_kalam':
        return 'My dear young friend, this is Dr. Kalam. I\'m here to share, learn, and dream with you. What wonderful thoughts shall we explore today?';
      case 'steve_jobs':
        return 'Hello. I\'m Steve Jobs. Let\'s think different together. What would you like to create or explore today?';
      default:
        return 'Hello! I\'m ${widget.character.name}. ${widget.character.description}. How can I help you today?';
    }
  }

  void _generateCharacterPrompts() {
    switch (widget.character.id) {
      case 'narendra_modi':
        _characterPrompts.addAll([
          'Tell me about Digital India',
          'What is your vision for India?',
          'Explain Make in India initiative',
          'Share your thoughts on development',
        ]);
        break;
      case 'elon_musk':
        _characterPrompts.addAll([
          'What\'s next for SpaceX?',
          'Tell me about sustainable energy',
          'Thoughts on Mars colonization?',
          'Future of electric vehicles',
        ]);
        break;
      case 'virat_kohli':
        _characterPrompts.addAll([
          'Best cricket memories?',
          'Fitness and training tips',
          'Team India experiences',
          'Advice for young cricketers',
        ]);
        break;
      case 'alakh_pandey':
        _characterPrompts.addAll([
          'Explain quantum physics simply',
          'Study tips for students',
          'Make physics interesting',
          'Career advice for aspiring scientists',
        ]);
        break;
      case 'abdul_kalam':
        _characterPrompts.addAll([
          'Share your dreams for youth',
          'Science and spirituality',
          'Missile technology insights',
          'Inspire me with your wisdom',
        ]);
        break;
      case 'steve_jobs':
        _characterPrompts.addAll([
          'Design philosophy insights',
          'Innovation principles',
          'Building great products',
          'Think different mindset',
        ]);
        break;
      default:
        _characterPrompts.addAll([
          'Tell me about yourself',
          'What makes you unique?',
          'Share your expertise',
          'What inspires you?',
        ]);
    }
  }

  Future<void> _generateResponse(String prompt) async {
    if (widget.selectedModel.isEmpty) {
      setState(() => _messages.add(Message.bot('Error: No model has been selected.')));
      return;
    }

    final completer = Completer<void>();
    _streamSubscription?.cancel();
    _httpClient?.close();
    _httpClient = http.Client();

    setState(() {
      _awaitingReply = true;
      _messages.add(Message.bot('', isStreaming: true));
    });
    _scrollDown();

    try {
      const apiKey = 'ahamaibyprakash25';
      final url = Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions');

      // Build conversation context with character's system prompt
      final messages = [
        {'role': 'system', 'content': widget.character.systemPrompt},
        // Add recent conversation history for context
        ..._messages.take(_messages.length - 1).map((msg) => {
          'role': msg.sender == Sender.user ? 'user' : 'assistant',
          'content': msg.text,
        }),
        {'role': 'user', 'content': prompt},
      ];

      final body = json.encode({
        'model': widget.selectedModel,
        'messages': messages,
        'stream': true,
        'max_tokens': 2000,
        'temperature': 0.8, // Slightly higher for more character personality
      });

      final request = http.Request('POST', url)
        ..headers.addAll({
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
        })
        ..bodyBytes = utf8.encode(body);

      final streamedResponse = await _httpClient!.send(request);

      if (streamedResponse.statusCode == 200) {
        final buffer = StringBuffer();
        _streamSubscription = streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
          (line) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6);
              if (data.trim() == '[DONE]') return;

              try {
                final jsonResponse = json.decode(data);
                final content = jsonResponse['choices'][0]['delta']['content'];
                if (content != null) {
                  final correctedContent = _fixServerEncoding(content);
                  buffer.write(correctedContent);
                  if (mounted) {
                    setState(() => _messages.last = _messages.last.copyWith(text: buffer.toString(), isStreaming: true));
                    _scrollDown();
                  }
                }
              } catch (e) {
                // Ignore errors from incomplete JSON chunks
              }
            }
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _messages.last = _messages.last.copyWith(isStreaming: false);
                _awaitingReply = false;
              });
              _httpClient?.close();
              _saveCurrentChat();
              completer.complete();
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                _messages.last = Message.bot('An error occurred during streaming: $e');
                _awaitingReply = false;
              });
              _httpClient?.close();
              completer.complete();
            }
          },
          cancelOnError: true,
        );
      } else {
        final errorBody = await streamedResponse.stream.transform(utf8.decoder).join();
        final errorDetails = errorBody.isNotEmpty ? _fixServerEncoding(errorBody) : streamedResponse.reasonPhrase;
        if (mounted) {
          setState(() {
            _messages.last = Message.bot('API Error (${streamedResponse.statusCode}): $errorDetails');
            _awaitingReply = false;
          });
          _httpClient?.close();
          completer.complete();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last = Message.bot('Failed to send request: $e');
          _awaitingReply = false;
        });
        _httpClient?.close();
        completer.complete();
      }
    }
    return completer.future;
  }

  void _saveCurrentChat() {
    if (_messages.length > 1) {
      _characterService.saveCharacterChat(
        widget.character.id,
        widget.character.name,
        _messages,
      );
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send([String? text]) async {
    final message = text ?? _controller.text.trim();
    if (message.isEmpty || _awaitingReply) return;

    if (text == null) _controller.clear();
    
    setState(() {
      _messages.add(Message.user(message));
    });

    _scrollDown();
    HapticFeedback.lightImpact();
    await _generateResponse(message);
  }

  void _regenerateResponse(int botMessageIndex) {
    int userMessageIndex = botMessageIndex - 1;
    if (userMessageIndex >= 0 && _messages[userMessageIndex].sender == Sender.user) {
      String lastUserPrompt = _messages[userMessageIndex].text;
      setState(() => _messages.removeAt(botMessageIndex));
      _generateResponse(lastUserPrompt);
    }
  }

  void _stopGeneration() {
    _streamSubscription?.cancel();
    _httpClient?.close();
    if (mounted) {
      setState(() {
        if (_awaitingReply && _messages.isNotEmpty && _messages.last.isStreaming) {
                     _messages.last = _messages.last.copyWith(isStreaming: false);
        }
        _awaitingReply = false;
      });
    }
  }

  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF7F7F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard!')),
                );
              },
            ),
            if (message.sender == Sender.bot) ...[
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Regenerate'),
                onTap: () {
                  Navigator.pop(context);
                  final index = _messages.indexOf(message);
                  if (index != -1) {
                    _regenerateResponse(index);
                  }
                },
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final emptyChat = _messages.length <= 1;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Hero(
              tag: 'character_${widget.character.id}',
              child: CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(widget.character.avatarUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.character.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'AI Character • ${widget.selectedModel}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFFA3A3A3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF4F3F0),
        elevation: 0,
        actions: [
          if (_awaitingReply)
            IconButton(
              onPressed: _stopGeneration,
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: 'Stop generation',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  setState(() {
                    _messages.clear();
                    _messages.add(Message.bot(_getCharacterGreeting()));
                  });
                  _characterService.deleteCharacterChat(widget.character.id);
                  break;
                case 'info':
                  _showCharacterInfo();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 12),
                    Text('Clear Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Text('Character Info'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.sender == Sender.user;
                
                return GestureDetector(
                  onLongPress: () => _showMessageOptions(context, message),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser) ...[
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(widget.character.avatarUrl),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isUser ? const Color(0xFFEAE9E5) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: isUser ? null : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isUser)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child:                                         Text(
                                          widget.character.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF000000),
                                          ),
                                        ),
                                      ),
                                    if (isUser)
                                      Text(
                                        message.displayText,
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      )
                                    else
                                      MarkdownBody(
                                        data: message.displayText,
                                        styleSheet: MarkdownStyleSheet(
                                          p: GoogleFonts.poppins(fontSize: 14),
                                          code: GoogleFonts.jetBrainsMono(
                                            fontSize: 12,
                                            backgroundColor: const Color(0xFFEAE9E5),
                                          ),
                                        ),
                                      ),
                                    if (message.isStreaming)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  const Color(0xFF000000),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                                                                          Text(
                                                'Thinking...',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: const Color(0xFFA3A3A3),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Thoughts panel for bot messages
                              if (!isUser && message.thoughts.isNotEmpty)
                                _ThoughtsPanel(thoughts: message.thoughts),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Quick prompts (show when chat is empty or minimal)
          if (emptyChat && _characterPrompts.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _characterPrompts.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        _characterPrompts[index],
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      onPressed: () => _send(_characterPrompts[index]),
                      backgroundColor: const Color(0xFFEAE9E5),
                      side: BorderSide.none,
                    ),
                  );
                },
              ),
            ),
          
          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F3F0),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE0E0E0)),
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
                      controller: _controller,
                      enabled: !_awaitingReply,
                      decoration: InputDecoration(
                        hintText: _awaitingReply ? '${widget.character.name} is thinking...' : 'Message ${widget.character.name}...',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFFA3A3A3),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      style: GoogleFonts.inter(
                        color: const Color(0xFF000000),
                        fontSize: 16,
                      ),
                      maxLines: 6,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 8),
                    child: GestureDetector(
                      onTap: _awaitingReply ? null : () => _send(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _controller.text.trim().isEmpty 
                              ? const Color(0xFFE0E0E0)
                              : const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _controller.text.trim().isNotEmpty
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF000000).withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: _controller.text.trim().isEmpty 
                              ? const Color(0xFFA3A3A3)
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCharacterInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFFF4F3F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
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
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: widget.character.avatarUrl.isNotEmpty
                          ? Image.network(
                              widget.character.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  widget.character.name[0].toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                widget.character.name[0].toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.character.name,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.character.description,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFFA3A3A3),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Character Details',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAE9E5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC4C4C4)),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            widget.character.systemPrompt,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF000000),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------
   THOUGHTS PANEL - Collapsible panel for AI thinking content
---------------------------------------------------------- */
class _ThoughtsPanel extends StatefulWidget {
  final List<ThoughtContent> thoughts;
  
  const _ThoughtsPanel({required this.thoughts});
  
  @override
  State<_ThoughtsPanel> createState() => _ThoughtsPanelState();
}

class _ThoughtsPanelState extends State<_ThoughtsPanel> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }
  
  String _getThoughtsPreview() {
    if (widget.thoughts.isEmpty) return '';
    final firstThought = widget.thoughts.first;
    final preview = firstThought.text.length > 50 
        ? '${firstThought.text.substring(0, 50)}...'
        : firstThought.text;
    return preview;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC4C4C4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle button
          InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    size: 16,
                    color: const Color(0xFF000000),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isExpanded 
                          ? 'Thoughts (${widget.thoughts.length})'
                          : _getThoughtsPreview(),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFFA3A3A3),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: _isExpanded ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: const Color(0xFF000000),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.thoughts.map((thought) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F3F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC4C4C4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          thought.type.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFFFFF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        thought.text,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.4,
                          color: const Color(0xFF000000),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}