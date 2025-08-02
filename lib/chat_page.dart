import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart'; // Dark theme for AMOLED
import 'models.dart';
import 'character_service.dart';
import 'file_attachment_service.dart';
import 'file_attachment_widget.dart';

import 'image_generation_service.dart';
import 'message_bubble.dart';
import 'input_bar.dart';
import 'chat_utils.dart';
import 'supabase_chat_service.dart';
import 'supabase_auth_service.dart';





/* ----------------------------------------------------------
   CHAT PAGE
---------------------------------------------------------- */
class ChatPage extends StatefulWidget {
  final void Function(Message botMessage) onBookmark;
  final String selectedModel;
  final VoidCallback? onChatHistoryChanged; // Callback when chat history changes
  final bool isTemporaryChatMode; // Whether temporary chat mode is enabled
  
  const ChatPage({
    super.key, 
    required this.onBookmark, 
    required this.selectedModel,
    this.onChatHistoryChanged,
    this.isTemporaryChatMode = false, // Default to false
  });

  @override
  State<ChatPage> createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <Message>[
    // Start completely empty - no auto-greeting
    // Bot greeting will be added when user sends first message
  ];
  bool _awaitingReply = false;
  DateTime? _lastStreamUpdate;
  String? _editingMessageId;
  
  // Scroll to bottom button
  bool _showScrollToBottom = false;




  // Unified attachment functionality (replaces separate image + file upload)
  List<FileAttachment> _attachedFiles = [];
  
  // Image generation mode
  bool _isImageGenerationMode = false;
  String _selectedImageModel = 'flux';
  List<String> _availableImageModels = ['flux', 'turbo'];
  bool _isGeneratingImage = false;
  
  // Image generation memory and follow-up (default OFF)
  List<String> _imagePromptMemory = [];
  bool _followUpMode = false; // Default OFF - user can enable if needed
  
  // Diagram generation tracking


  // Add memory system for general chat
  List<String> _conversationMemory = [];
  
  // Current conversation tracking
  String? _currentConversationId;
  static const int _maxMemorySize = 10;
  bool _isSavingChat = false; // Prevent concurrent saves

  http.Client? _httpClient;
  final CharacterService _characterService = CharacterService();
  // REMOVED: External tools service

  final _prompts = ['Explain quantum computing', 'Write a Python snippet', 'Draft an email to my boss', 'Ideas for weekend trip'];
  
  // MODIFICATION: Robust function to fix server-side encoding errors (mojibake).
  // This is the core fix for rendering emojis and special characters correctly.
  String _fixServerEncoding(String text) {
    try {
      // This function corrects text that was encoded in UTF-8 but mistakenly interpreted as Latin-1.
      // 1. We take the garbled string and encode it back into bytes using Latin-1.
      //    This recovers the original, correct UTF-8 byte sequence.
      final originalBytes = latin1.encode(text);
      // 2. We then decode these bytes using the correct UTF-8 format.
      //    `allowMalformed: true` makes this more robust against potential errors.
      return utf8.decode(originalBytes, allowMalformed: true);
    } catch (e) {
      // If anything goes wrong, return the original text to prevent the app from crashing.
      return text;
    }
  }



  @override
  void initState() {
    debugPrint('🎬 CHATPAGE: initState() called - setting up ChatPage...');
    super.initState();
    _characterService.addListener(_onCharacterChanged);
    // REMOVED: External tools service listener
    
    _updateGreetingForCharacter();
    debugPrint('🎬 CHATPAGE: Calling _loadConversationMemory...');
    _loadConversationMemory();
    _loadImageModels();
    _controller.addListener(() {
      setState(() {}); // Refresh UI when text changes
    });
    debugPrint('✅ CHATPAGE: initState() completed');
  }
  
      Future<void> _loadConversationMemory() async {
    try {
      debugPrint('💭 CONVERSATION: _loadConversationMemory() called');
      // Skip loading from Supabase if in temporary chat mode
      if (widget.isTemporaryChatMode) {
        debugPrint('💭 CONVERSATION: Temporary chat mode - starting empty');
        setState(() {
          _currentConversationId = null;
          _conversationMemory = [];
          _messages.clear();
          // DON'T add bot greeting - wait for user interaction
        });
        return;
      }
      
      // Check if user is signed in before attempting to load from Supabase
      if (!SupabaseAuthService.isSignedIn) {
        debugPrint('💭 CONVERSATION: User not signed in - starting empty');
        setState(() {
          _currentConversationId = null;
          _conversationMemory = [];
          _messages.clear();
          // DON'T add bot greeting - wait for user interaction
        });
        return;
      }
      
      // CHANGED: Start completely empty - no auto-greeting
      // Bot greeting will be added when user sends first message
      debugPrint('💭 CONVERSATION: Starting empty - no auto-greeting');
      setState(() {
        _currentConversationId = null;
        _conversationMemory = [];
        _messages.clear();
        // DON'T add bot greeting - completely empty start
      });
      debugPrint('✅ CONVERSATION: Empty chat initialized with ${_messages.length} messages');
      
    } catch (e) {
      debugPrint('❌ CONVERSATION: Error in conversation memory setup: $e');
      // On error, start empty
      setState(() {
        _currentConversationId = null;
        _conversationMemory = [];
        _messages.clear();
        // DON'T add bot greeting even on error
      });
    }
  }
  
    Future<void> _saveChatHistory() async {
    // Prevent concurrent saves
    if (_isSavingChat) {
      debugPrint('💾 SAVE: Already saving, skipping concurrent save request');
      return;
    }
    
    try {
      _isSavingChat = true;
      debugPrint('💾 SAVE: Starting save operation...');
      
      if (_messages.isEmpty) {
        debugPrint('💾 SAVE: No messages to save');
        return;
      }
      
      // Skip saving if in temporary chat mode
      if (widget.isTemporaryChatMode) {
        debugPrint('Temporary chat mode: Not saving chat history to Supabase');
        return;
      }
      
      // Skip saving if only contains initial bot greeting (prevent empty conversations)
      if (_messages.length == 1 && 
          _messages.first.sender == Sender.bot && 
          (_messages.first.text.contains('Hi, I\'m AhamAI') || 
           _messages.first.text.contains('Fresh chat started'))) {
        debugPrint('Skipping save: Only contains initial bot greeting');
        return;
      }
      
      // Generate title ONLY for new conversations
      String title = 'New Chat';
      if (_currentConversationId == null && _messages.length > 1) {
        title = SupabaseChatService.generateConversationTitle(_messages);
        debugPrint('💬 SAVE: Generated new title for new conversation: "$title"');
      } else if (_currentConversationId != null) {
        // For existing conversations, DON'T regenerate title to prevent overwriting
        // Keep the existing title by not setting a new one
        debugPrint('💬 SAVE: Preserving existing title for conversation ID: $_currentConversationId');
      } else {
        debugPrint('💬 SAVE: Using default title: "$title"');
      }
      
      final isNewConversation = _currentConversationId == null;
      
      debugPrint('💾 SAVE: Saving chat with ${_messages.length} messages');
      debugPrint('💾 SAVE: isNewConversation: $isNewConversation');
      debugPrint('💾 SAVE: conversationId: $_currentConversationId');
      debugPrint('💾 SAVE: title: "$title"');
      
      // Save to Supabase
      final conversationId = await SupabaseChatService.saveConversation(
        messages: _messages,
        conversationMemory: _conversationMemory,
        conversationId: _currentConversationId,
        title: _currentConversationId == null ? title : null, // Only set title for new conversations
      );
      
      if (conversationId != null && _currentConversationId == null) {
        setState(() {
          _currentConversationId = conversationId;
        });
        debugPrint('💾 SAVE: Assigned new conversation ID: $conversationId');
      } else if (conversationId != null && _currentConversationId != null) {
        debugPrint('💾 SAVE: Updated existing conversation ID: $conversationId (was: $_currentConversationId)');
      } else {
        debugPrint('💾 SAVE: No conversation ID returned from save operation');
      }
      
      debugPrint('💾 SAVE: Final conversation ID state: $_currentConversationId');
      
      // Only notify parent of new conversations, not every message update
      if (isNewConversation && conversationId != null) {
        debugPrint('New conversation created, refreshing chat history list');
        widget.onChatHistoryChanged?.call();
      }
      
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    } finally {
      _isSavingChat = false;
      debugPrint('💾 SAVE: Save operation completed');
    }
  }
  

  


  @override
  void dispose() {
    debugPrint('🎬 CHATPAGE: dispose() called - cleaning up ChatPage...');
    _characterService.removeListener(_onCharacterChanged);
    // REMOVED: External tools service listener removal
    _controller.dispose();
    _scroll.dispose();
    _httpClient?.close();
    super.dispose();
    debugPrint('✅ CHATPAGE: dispose() completed');
  }

  List<Message> getMessages() => _messages;

  void loadChatSession(List<Message> messages, {String? conversationId}) {
    debugPrint('📂 LOAD: loadChatSession called with ${messages.length} messages');
    debugPrint('📂 LOAD: Current conversation ID: $_currentConversationId');
    debugPrint('📂 LOAD: New conversation ID: $conversationId');
    setState(() {
      _awaitingReply = false;
      _httpClient?.close();
      _messages.clear();
      _messages.addAll(messages);
      _currentConversationId = conversationId; // Set the conversation ID so messages save to correct conversation
    });
    debugPrint('✅ LOAD: Loaded chat session with ${messages.length} messages, conversation ID: $_currentConversationId');
  }

  void _onCharacterChanged() {
    if (mounted) {
      _updateGreetingForCharacter();
    }
  }

  // REMOVED: External tools service change handler

  void _updateGreetingForCharacter() {
    final selectedCharacter = _characterService.selectedCharacter;
    setState(() {
      if (_messages.isNotEmpty && _messages.first.sender == Sender.bot && _messages.length == 1) {
        if (selectedCharacter != null) {
          _messages.first = Message.bot('Hello! I\'m ${selectedCharacter.name}. ${selectedCharacter.description}. How can I help you today?');
        } else {
          _messages.first = Message.bot('Hi, I\'m AhamAI. Ask me anything!');
        }
      }
    });
  }

  void _startEditing(Message message) {
    setState(() {
      _editingMessageId = message.id;
      _controller.text = message.text;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    });
  }
  
  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _controller.clear();
    });
  }

  void _showUserMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
                  backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.copy_all_rounded, color: Color(0xFF8E8E93)),
              title: const Text('Copy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Copied to clipboard')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFF8E8E93)),
              title: const Text('Edit & Resend', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _startEditing(message);
              },
            ),
          ],
        );
      },
    );
  }

  void _updateConversationMemory(String userMessage, String aiResponse) async {
    // Simple memory storage without any cleaning that could affect display
    // Just store basic conversation for context, truncate if too long
    String simpleResponse = aiResponse.length > 300 ? aiResponse.substring(0, 300) + '...' : aiResponse;
    
    final memoryEntry = 'User: $userMessage\nAI: $simpleResponse';
    _conversationMemory.add(memoryEntry);
    
    // Keep only last 3 conversations to prevent token overflow
    if (_conversationMemory.length > 3) {
      _conversationMemory.removeAt(0);
    }
  }

  String _getMemoryContext() {
    if (_conversationMemory.isEmpty) return '';
    return 'Previous conversation context:\n${_conversationMemory.join('\n\n')}\n\nCurrent conversation:';
  }

  Future<void> _generateResponse(String prompt, {bool hasVision = false}) async {
    if (widget.selectedModel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No model selected'), backgroundColor: Color(0xFFEAE9E5)),
      );
      return;
    }

    // Clear executed tools and results for new message to prevent cross-message interference
    _executedTools.clear();
    _completedToolResults.clear();

    
    setState(() => _awaitingReply = true);

    // Regular AI chat with file attachment support

    _httpClient = http.Client();
    final memoryContext = _getMemoryContext();
    final fullPrompt = memoryContext.isNotEmpty ? '$memoryContext\n\nUser: $prompt' : prompt;

    try {
      final request = http.Request('POST', Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ahamaibyprakash25',
      });
      Map<String, dynamic> messageContent;
      
      // Build message content with optional vision
      if (hasVision) {
        final imageAttachments = _attachedFiles.where((f) => f.isImage).toList();
        if (imageAttachments.isNotEmpty) {
          final contentParts = <Map<String, dynamic>>[
            {"type": "text", "text": fullPrompt}
          ];
          for (final img in imageAttachments) {
            final base64Image = "data:${img.mimeType};base64,${base64Encode(img.bytes!)}";
            contentParts.add({
              "type": "image_url",
              "image_url": {"url": base64Image}
            });
          }
          messageContent = {"role": "user", "content": contentParts};
        } else {
          messageContent = {"role": "user", "content": fullPrompt};
        }
      } else {
        messageContent = {"role": "user", "content": fullPrompt};
      }

      // Build system prompt with file attachment context
      final systemMessage = {
        'role': 'system',
        'content': '''You are AhamAI, an intelligent assistant focused on helpful conversations and image generation capabilities.

🎨 **RESPONSE FORMATTING GUIDELINES:**
- Use **bold** for important points and headings
- Use *italics* for emphasis and subtle highlighting
- Use emojis 🤗 to make responses friendly and engaging
- Use `code formatting` for technical terms, commands, and file names
- Use > blockquotes for important notes, tips, and warnings
- Use numbered lists (1. 2. 3.) for step-by-step instructions
- Use bullet points (- • *) for feature lists and options
- Use ## Headers and ### Sub-headers to structure long responses
- Use ~~strikethrough~~ for corrections or outdated information
- Use --- horizontal rules to separate major sections
- Use tables when presenting structured data or comparisons
- Use - [ ] checkboxes for task lists and action items
- Include relevant emojis throughout your responses 📝✨🚀
- Make your responses **well-structured and readable** using rich markdown formatting

🖼️ **IMAGE & MEDIA SUPPORT:**
- You can reference images, GIFs, and media files when relevant
- Support markdown image syntax: ![alt text](image_url)
- Encourage visual learning and multimedia responses when appropriate

🎨 **IMAGE GENERATION CAPABILITY:**
This app has a built-in image generator with model selection (Flux, Turbo) and follow-up options for consistent style. Users can access it through the attachment button or you can mention this feature when relevant.

🎨 **FOR IMAGE GENERATION:**
When users want to create images, photos, artwork, or illustrations, guide them to use the attachment button (📎) to access the built-in image generator. Say something like: "I can help you create images! Please click the attachment button (📎) and select 'Generate Image' to access our image generator with different models like Flux and Turbo."

**Always use proper JSON format and explain what you're doing to help the user understand the process.**

**Be conversational, helpful, and make your responses visually appealing with proper formatting!** 🚀'''
      };

      request.body = json.encode({
        'model': widget.selectedModel,
        'messages': [systemMessage, messageContent],
        'stream': true,
      });

      final response = await _httpClient!.send(request);

      if (response.statusCode == 200) {
        final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
        var botMessage = Message.bot('', isStreaming: true);
        final botMessageIndex = _messages.length;
        
        setState(() {
          _messages.add(botMessage);
        });

        String accumulatedText = '';
        
        await for (String line in stream) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') {
              break;
            }
            
            try {
              final json = jsonDecode(data);
              final content = json['choices']?[0]?['delta']?['content'];
              if (content != null) {
                accumulatedText += _fixServerEncoding(content);
                
                // Throttle updates for smoother performance (every 50ms)
                if (_lastStreamUpdate == null || 
                    DateTime.now().difference(_lastStreamUpdate!).inMilliseconds > 50) {
                  
                  // Parse thinking content in real-time during streaming
                  final streamingParseResult = _parseContentStreaming(accumulatedText);
                  
                  // Use original display text from parsing without any processing
                  String displayText = streamingParseResult['displayText'];

                  if (mounted) {
                    setState(() {
                      _messages[botMessageIndex] = Message(
                        id: botMessage.id,
                        sender: Sender.bot,
                        text: accumulatedText,
                        isStreaming: true,
                        timestamp: botMessage.timestamp,
                        thoughts: streamingParseResult['thoughts'],
                        codes: streamingParseResult['codes'],
                        displayText: displayText,
                        toolData: botMessage.toolData,
                      );
                    });
                    
                    _scrollToBottom();
                    _lastStreamUpdate = DateTime.now();
                  }
                }
              }
            } catch (e) {
              // Continue on JSON parsing errors
            }
          }
        }

        // FIXED: Always use original accumulated text, no processed text
        final textToUse = accumulatedText;
        
        // Parse final content to preserve codes and thoughts
        final finalParseResult = _parseContentStreaming(textToUse);
        
        setState(() {
          _messages[botMessageIndex] = Message(
            id: _messages[botMessageIndex].id,
            sender: Sender.bot,
            text: textToUse,
            isStreaming: false,
            timestamp: _messages[botMessageIndex].timestamp,
            thoughts: finalParseResult['thoughts'],
            codes: finalParseResult['codes'],
            displayText: finalParseResult['displayText'],
            toolData: _messages[botMessageIndex].toolData,
          );
        });



        // FIXED: Use original text for memory, no cleaning of code blocks
        _updateConversationMemory(prompt, accumulatedText);
        
        // Save complete chat history to SharedPreferences
        await _saveChatHistory();

        // Ensure UI scrolls to bottom after processing
        _scrollToBottom();

      } else {
        // Handle different status codes more gracefully
        String errorMessage;
        if (response.statusCode == 400) {
          errorMessage = 'Bad request. Please check your message format and try again.';
        } else if (response.statusCode == 401) {
          errorMessage = 'Authentication failed. Please check API credentials.';
        } else if (response.statusCode == 429) {
          errorMessage = 'Rate limit exceeded. Please wait a moment and try again.';
        } else if (response.statusCode >= 500) {
          errorMessage = 'Server error. Please try again in a moment.';
        } else {
          errorMessage = 'Sorry, there was an error processing your request. Status: ${response.statusCode}';
        }
        
        setState(() {
          _messages.add(Message.bot(errorMessage));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Better error handling without showing Stack Overflow details
          String errorMessage = 'Sorry, I encountered an issue. Please try again.';
          if (e.toString().toLowerCase().contains('stack overflow')) {
            errorMessage = 'Request was too complex. Please try a simpler request.';
          } else if (e.toString().toLowerCase().contains('timeout')) {
            errorMessage = 'Request timed out. Please try again.';
          } else if (e.toString().toLowerCase().contains('connection')) {
            errorMessage = 'Connection issue. Please check your internet and try again.';
          }
          _messages.add(Message.bot(errorMessage));
        });
      }
    } finally {
      // Clean up resources
      _httpClient?.close();
      _httpClient = null;
      if (mounted) {
        setState(() {
          _awaitingReply = false;
        });
        // Clear uploaded image only after successful processing
      }
    }
  }

  // Track already executed tools to prevent duplicates
  final Set<String> _executedTools = {};
  // Store completed tool results to prevent them from being overwritten
  final Map<String, String> _completedToolResults = {};
  
  /// REMOVED: This function was interfering with code panels
  /// Process Python-based tool calls during streaming - execute tools ONE BY ONE
  Future<String> _processToolCallsDuringStreaming_DISABLED(String responseText, int messageIndex) async {
    // Look for Python code blocks with execute_tool calls
    final pythonPattern = RegExp(r'```python\s*(.*?)\s*```', dotAll: true);
    final matches = pythonPattern.allMatches(responseText);
    
    String processedText = responseText;
    Set<String> processedMatches = {}; // Prevent duplicate processing
    
    // Execute tools and replace Python blocks with results directly
    for (final match in matches) {
      final fullMatch = match.group(0)!;
      if (processedMatches.contains(fullMatch)) continue;
      processedMatches.add(fullMatch);
      
      final pythonCode = match.group(1) ?? '';
      debugPrint('Found Python code: $pythonCode');
      
      // Extract execute_tool calls from Python code - simplified pattern
      final toolCallPattern = RegExp(r'execute_tool\s*\([^)]+\)', dotAll: true);
      final toolMatches = toolCallPattern.allMatches(pythonCode);
      
      String executionResults = '';
      
      // EXECUTE TOOLS ONE BY ONE - NO PARALLEL EXECUTION
      for (final toolMatch in toolMatches) {
         try {
           final fullCall = toolMatch.group(0)!;
           debugPrint('Found tool call: $fullCall');
           
                                   // Extract tool name and parameters manually using string parsing
            final startQuote = fullCall.indexOf("'") != -1 ? "'" : '"';
            final firstQuoteIndex = fullCall.indexOf(startQuote);
            final secondQuoteIndex = fullCall.indexOf(startQuote, firstQuoteIndex + 1);
            
            if (firstQuoteIndex == -1 || secondQuoteIndex == -1) continue;
            
                        final toolName = fullCall.substring(firstQuoteIndex + 1, secondQuoteIndex);
            final afterTool = fullCall.substring(secondQuoteIndex + 1);
            final paramString = afterTool.replaceAll(RegExp(r'^\s*,?\s*'), '').replaceAll(RegExp(r'\)\s*$'), '');
            
            // Create unique tool signature to prevent duplicates
            final toolSignature = '$toolName:$paramString';
            
            // Skip if this exact tool call was already executed
            if (_executedTools.contains(toolSignature)) {
              debugPrint('Tool already executed, skipping: $toolSignature');
              continue;
            }
            
            debugPrint('Extracted tool: $toolName, params: $paramString');
            
            // Parse parameters from Python function call format
            final parameters = _parsePythonParameters(paramString);
            
            debugPrint('Executing tool: $toolName with params: $parameters');
            
            // Mark this tool as executed
            _executedTools.add(toolSignature);
          
          // Tool execution starting
          
            // File attachments are now processed and included in AI messages
          
          // Add execution result directly
          executionResults += '"File processing completed"\n\n';
          
          // Store the completed tool result to prevent it from being overwritten
          _completedToolResults[fullMatch] = "File processing completed";
          

          
          // MODIFIED: Only replace code blocks that contain execute_tool calls
          // Keep regular code blocks for coding panels
          if (pythonCode.contains('execute_tool')) {
            // This is a tool execution block - replace with results
            setState(() {
              final updatedText = processedText.replaceAll(
                fullMatch,
                "File processing completed"
              );
              
              _messages[messageIndex] = _messages[messageIndex].copyWith(
                text: updatedText,
                isStreaming: true,
              );
            });
          }
          // If no execute_tool, keep the code block as-is for coding panels
          _scrollToBottom();
          
          // Wait a bit before next tool to prevent overwhelming
          await Future.delayed(Duration(milliseconds: 100));
          
        } catch (e) {
          debugPrint('Error executing Python tool call: $e');
          executionResults += '\n# Error executing tool: $e\n';
        }
      }
      
      // Replace Python block with results (if any tools were executed)
      if (executionResults.isNotEmpty) {
        processedText = processedText.replaceAll(
          fullMatch,
          executionResults.trim()
        );
      } else {
        // Remove empty Python blocks
        processedText = processedText.replaceAll(fullMatch, '');
      }
    }
    
    // Restore any completed tool results that might have been overwritten during streaming
    for (final entry in _completedToolResults.entries) {
      final pythonBlock = entry.key;
      final toolResult = entry.value;
      if (processedText.contains(pythonBlock)) {
        processedText = processedText.replaceAll(pythonBlock, toolResult);
      }
    }
    
               // Also ensure any Python blocks that have tool results are replaced
      final restorePythonPattern = RegExp(r'```python\s*(.*?)\s*```', dotAll: true);
      for (final match in restorePythonPattern.allMatches(processedText)) {
        final fullMatch = match.group(0)!;
        if (_completedToolResults.containsKey(fullMatch)) {
          processedText = processedText.replaceAll(fullMatch, _completedToolResults[fullMatch]!);
        }
      }
     
     return processedText;
  }
  
  /// Parse Python function parameters into a Map
  Map<String, dynamic> _parsePythonParameters(String paramString) {
    final parameters = <String, dynamic>{};
    
    if (paramString.trim().isEmpty) return parameters;
    
                                            // Handle keyword arguments using simple string parsing
     final parts = paramString.split(',');
     
     for (final part in parts) {
       final trimmed = part.trim();
       if (trimmed.contains('=')) {
         final equalIndex = trimmed.indexOf('=');
         final key = trimmed.substring(0, equalIndex).trim();
         final valueWithQuotes = trimmed.substring(equalIndex + 1).trim();
         
         // Remove quotes from value
         String value = valueWithQuotes;
         if ((value.startsWith("'") && value.endsWith("'")) || 
             (value.startsWith('"') && value.endsWith('"'))) {
           value = value.substring(1, value.length - 1);
         }
         
         parameters[key] = value;
         debugPrint('Parsed parameter: $key = $value');
       }
     }
    
    return parameters;
  }

  /// Process tool calls in AI response and execute them
  Future<Map<String, dynamic>> _processToolCalls(String responseText) async {
    try {
      Map<String, dynamic> toolData = {};
      String processedText = responseText;
    
    // Enhanced patterns for more robust JSON tool detection
    final singleJsonPattern = RegExp(r'```json\s*(\{[^`]*?["\x27]tool_use["\x27]\s*:\s*true[^`]*?\})\s*```', dotAll: true, multiLine: true);
    
    // Look for parallel tool calls (array of tool calls)
    final parallelJsonPattern = RegExp(r'```json\s*(\[[^`]*?["\x27]tool_use["\x27]\s*:\s*true[^`]*?\])\s*```', dotAll: true, multiLine: true);
    
    // Also look for tool calls without explicit tool_use flag
    final implicitToolPattern = RegExp(r'```json\s*(\{[^`]*?["\x27]tool_name["\x27]\s*:\s*["\x27][^"\x27]+["\x27][^`]*?\})\s*```', dotAll: true, multiLine: true);
    final implicitParallelPattern = RegExp(r'```json\s*(\[[^`]*?["\x27]tool_name["\x27]\s*:\s*["\x27][^"\x27]+["\x27][^`]*?\])\s*```', dotAll: true, multiLine: true);
    
    final singleMatches = singleJsonPattern.allMatches(responseText);
    final parallelMatches = parallelJsonPattern.allMatches(responseText);
    final implicitSingleMatches = implicitToolPattern.allMatches(responseText);
    final implicitParallelMatches = implicitParallelPattern.allMatches(responseText);
    
    // Handle parallel tool calls first
    for (final match in [...parallelMatches, ...implicitParallelMatches]) {
      try {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          // Clean and fix common JSON issues for parallel calls
          String cleanedJson = jsonStr.trim();
          cleanedJson = cleanedJson.replaceAll("'", '"');
          cleanedJson = cleanedJson.replaceAll('True', 'true');
          cleanedJson = cleanedJson.replaceAll('False', 'false'); 
          cleanedJson = cleanedJson.replaceAll('None', 'null');
          
          final toolCalls = json.decode(cleanedJson) as List;
          final validToolCalls = toolCalls.where((call) => 
            call is Map<String, dynamic> && 
            (call['tool_use'] == true || call['tool_name'] != null) &&
            call['tool_name'] != null
          ).cast<Map<String, dynamic>>().toList();
          
          // Add tool_use flag for implicit calls
          for (final call in validToolCalls) {
            call['tool_use'] = true;
          }
          
          if (validToolCalls.isNotEmpty) {
            // Execute tools in parallel
            // REMOVED: External tools execution - parallel
            final results = <String, Map<String, dynamic>>{};
            // No tool execution - empty results
            
            // Build combined result text without execution headers
            String combinedResultText = '';
            for (final call in validToolCalls) {
              final toolName = call['tool_name'] as String;
              final result = {"success": false, "message": "External tools have been removed"};
              combinedResultText += _formatToolResult(toolName, result) + '\n\n';
            }
            
            processedText = processedText.replaceAll(match.group(0)!, combinedResultText.trim());
          } else {
            // No valid tool calls, remove the JSON block
            processedText = processedText.replaceAll(match.group(0)!, '');
          }
        }
      } catch (e) {
        debugPrint('Parallel tool call JSON parsing error: $e - removing malformed JSON');
        processedText = processedText.replaceAll(match.group(0)!, '');
      }
    }
    
    // Handle single tool calls
    for (final match in [...singleMatches, ...implicitSingleMatches]) {
      try {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          // Try to clean and fix common JSON issues
          String cleanedJson = jsonStr.trim();
          
          // Fix common JSON formatting issues
          cleanedJson = cleanedJson.replaceAll("'", '"'); // Single quotes to double quotes
          cleanedJson = cleanedJson.replaceAll('True', 'true'); // Python-style booleans
          cleanedJson = cleanedJson.replaceAll('False', 'false'); 
          cleanedJson = cleanedJson.replaceAll('None', 'null');
          
          final toolCall = json.decode(cleanedJson);
          
          if ((toolCall['tool_use'] == true || toolCall['tool_name'] != null) && toolCall['tool_name'] != null) {
            final toolName = toolCall['tool_name'] as String;
            final parameters = toolCall['parameters'] as Map<String, dynamic>? ?? {};
            
            // Ensure tool_use flag is set
            toolCall['tool_use'] = true;
            
            // Execute the tool
            // REMOVED: External tools execution - single
            final result = {"success": false, "message": "External tools removed"};
            toolData[toolName] = result;
            
            // Replace the JSON block with the tool execution result
            String resultText = "File processing completed";
            processedText = processedText.replaceAll(match.group(0)!, "File processing completed");
          } else {
            // If not a valid tool call, remove the JSON block entirely
            processedText = processedText.replaceAll(match.group(0)!, '');
          }
        }
      } catch (e) {
        // If JSON parsing fails completely, remove the problematic JSON block
        debugPrint('Tool call JSON parsing error: $e - removing malformed JSON');
        processedText = processedText.replaceAll(match.group(0)!, '');
      }
    }
    
      return {
        'text': processedText,
        'toolData': toolData,
      };
    } catch (e) {
      // Handle stack overflow and other errors gracefully
      debugPrint('Error processing tool calls: $e');
      // Clean the response text completely without any replacement
      String cleanedText = responseText
          .replaceAll(RegExp(r'```json[^`]*```', multiLine: true), '')
          .replaceAll(RegExp(r'\{[^}]*"tool_use"[^}]*\}', multiLine: true), '')
          .replaceAll(RegExp(r'\[[^]]*"tool_use"[^]]*\]', multiLine: true), '')
          .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
          .trim();
      
      return {
        'text': cleanedText.isEmpty ? 'Task completed successfully.' : cleanedText,
        'toolData': <String, dynamic>{},
      };
    }
  }

  /// Format tool execution result for display
  String _formatToolResult(String toolName, Map<String, dynamic> result) {
    if (result['success'] == true) {
      switch (toolName) {


        case 'fetch_ai_models':
          final models = result['models'] as List;
          final modelsList = models.take(10).join(', ');
          return '''**🤖 AI Models Fetched Successfully**

**Available Models:** ${result['total_count']} models found
**Sample Models:** $modelsList${models.length > 10 ? '...' : ''}
**API Status:** ${result['api_status']}

✅ Models list retrieved successfully!''';

        case 'switch_ai_model':
          return '''**🔄 AI Model Switch Executed**

**New Model:** ${result['new_model']}
**Reason:** ${result['reason']}
**Validation:** ${result['validation']}
**Status:** ${result['action_completed']}

✅ Model switch completed successfully!''';





                  // REMOVED: PlantUML diagram generation



        default:
          // For other tools, show minimal clean output (hide raw JSON data)
          if (result['description'] != null) {
            String description = result['description'].toString();
            // Hide raw JSON data from tool outputs
            description = _cleanJsonFromText(description);
            return '''✅ $description''';
          } else {
            return '''✅ Task completed successfully''';
          }
      }
    } else {
      return '''❌ Error: ${result['error']}''';
    }
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
    _httpClient?.close();
    _httpClient = null;
    if(mounted) {
      setState(() {
        if (_awaitingReply && _messages.isNotEmpty && _messages.last.isStreaming) {
                        final lastIndex = _messages.length - 1;
             _messages[lastIndex] = _messages.last.copyWith(isStreaming: false);
        }
        _awaitingReply = false;
      });
    }
  }

  void startNewChat() {
    debugPrint('🆕 NEWCHAT: startNewChat() called');
    debugPrint('🆕 NEWCHAT: Current conversation ID before reset: $_currentConversationId');
    setState(() {
      _awaitingReply = false;
      _editingMessageId = null;
      _currentConversationId = null;
      _conversationMemory.clear(); // Clear memory for fresh start
      _httpClient?.close();
      _httpClient = null;
      _messages.clear();
      // DON'T add any bot greeting - let it be completely empty
      // Bot greeting will be added when user sends first message
    });
    debugPrint('✅ NEWCHAT: Empty chat created with ${_messages.length} messages');
    debugPrint('✅ NEWCHAT: Conversation ID reset to: $_currentConversationId');
  }
  
  // Public method to reload conversation memory (for auth state changes)
  void reloadConversationMemory() {
    _loadConversationMemory();
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _send({String? text}) async {
    final messageText = text ?? _controller.text.trim();
    if (messageText.isEmpty || _awaitingReply) return;



    final isEditing = _editingMessageId != null;
    if (isEditing) {
      final messageIndex = _messages.indexWhere((m) => m.id == _editingMessageId);
      if (messageIndex != -1) {
        setState(() {
          _messages.removeRange(messageIndex, _messages.length);
        });
      }
    }
    
    // Build complete message for AI including attachments
    final aiMessage = ChatUtils.buildAIMessage(messageText, _attachedFiles);
    final hasImages = ChatUtils.hasImages(_attachedFiles);
    
    _controller.clear();
    setState(() {
      _messages.add(Message.user(messageText, attachments: List.from(_attachedFiles)));
      _editingMessageId = null;
      _attachedFiles.clear(); // Clear attachments after sending
    });

    _scrollToBottom();
    HapticFeedback.lightImpact();
    
    // Use enhanced message with attachments for AI
    await _generateResponse(aiMessage, hasVision: hasImages);
  }



  Future<void> _handleImageUpload() async {
    try {
      await _showImageSourceDialog();
    } catch (e) {
      // Handle error
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showImageSourceDialog() async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFC4C4C4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Text(
              'Select Image Source',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF000000),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF000000)),
              ),
              title: Text(
                'Take Photo',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF000000),
                ),
              ),
              subtitle: Text(
                'Capture with camera',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA3A3A3),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            
            // Gallery option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF000000)),
              ),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF000000),
                ),
              ),
              subtitle: Text(
                'Select from photos',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA3A3A3),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        setState(() {
        });
        final imageMessage = Message.user("📷 Image uploaded: ${pickedFile.name}");
        setState(() {
          _messages.add(imageMessage);
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Attachment Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
            
            // Options
            Column(
              children: [
                // Upload Image
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF2D3748).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.image,
                      color: Color(0xFF2D3748),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Upload Image',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  subtitle: Text(
                    'Select an image from your device',
                    style: TextStyle(color: Color(0xFF718096)),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleImageUpload();
                  },
                ),
                
                // Generate Image
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF2D3748).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.paintBrush,
                      color: Color(0xFF2D3748),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Generate Image',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  subtitle: Text(
                    'Create an image with AI from text prompt',
                    style: TextStyle(color: Color(0xFF718096)),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _enableImageGenerationMode();
                  },
                ),
              ],
            ),
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _loadImageModels() async {
    final result = await ImageGenerationService.getImageModels();
    if (mounted) {
      setState(() {
        _availableImageModels = List<String>.from(result['models'] ?? ['flux', 'turbo']);
        if (!_availableImageModels.contains(_selectedImageModel)) {
          _selectedImageModel = _availableImageModels.first;
        }
      });
    }
  }

  void _enableImageGenerationMode() {
    setState(() {
      _isImageGenerationMode = true;
      _controller.clear();
    });
  }

  void _disableImageGenerationMode() {
    setState(() {
      _isImageGenerationMode = false;
      _controller.clear();
    });
  }



  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF2D3748),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveImageToDevice(String imageUrl) async {
    try {
      // For Android 10+ (API 29+), we don't need storage permission for app-specific directories
      // For older versions, try to get permission but continue if denied

      // TODO: Re-implement file export with proper path_provider
      _showSnackBar('❌ Export functionality temporarily disabled');
      return;
    } catch (e) {
      print('Error saving image: $e');
      _showSnackBar('❌ Error saving image: ${e.toString()}');
    }
  }

  Future<void> _generateImageInline() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    // Build enhanced prompt with memory if follow-up mode is enabled
    String enhancedPrompt = prompt;
    if (_followUpMode && _imagePromptMemory.isNotEmpty) {
      final previousPrompts = _imagePromptMemory.take(3).join(', ');
      enhancedPrompt = '$prompt, following style of: $previousPrompts';
    }

    setState(() {
      _isGeneratingImage = true;
    });

    final result = await ImageGenerationService.generateImage(
      prompt: enhancedPrompt,
      model: _selectedImageModel,
    );

    if (mounted) {
      setState(() {
        _isGeneratingImage = false;
        // Keep image generation mode active after generation
        // _isImageGenerationMode = false; // Removed this line
      });

      if (result['success']) {
        // Store prompt in memory
        _imagePromptMemory.insert(0, prompt);
        if (_imagePromptMemory.length > 5) {
          _imagePromptMemory.removeLast();
        }

        // Add user prompt message
        final promptMessage = Message.user("🎨 Generate image: $prompt");
        setState(() {
          _messages.add(promptMessage);
        });

        // Add generated image message using same format as external tools
        final imageMessage = Message.bot('''![Generated Image](${result['image_url']})''');
        
        setState(() {
          _messages.add(imageMessage);
        });

        _controller.clear();
        _scrollToBottom();
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageGenerationDialog() {
    // TODO: Re-implement image generation dialog
    _showSnackBar('❌ Image generation temporarily disabled');
  }

  void _clearAllAttachments() {
    setState(() {
      _attachedFiles.clear();
    });
  }

  Future<void> _handleUnifiedAttachment() async {
    final files = await ChatUtils.handleUnifiedAttachment();
    if (files != null && files.isNotEmpty) {
      setState(() {
        _attachedFiles.addAll(files);
      });
    }
  }

  void _clearFile(String fileId) {
    setState(() {
      _attachedFiles.removeWhere((file) => file.id == fileId);
    });
  }

  void _clearAllFiles() {
    setState(() {
      _attachedFiles.clear();
    });
  }

  void _editMessage(Message message) {
    // Set the text in the input field and focus on it
    _controller.text = message.text;
    
    // Remove the message and any subsequent messages
    final messageIndex = _messages.indexOf(message);
    if (messageIndex != -1) {
      setState(() {
        _messages.removeRange(messageIndex, _messages.length);
      });
    }
    
    // Focus on the text field
    FocusScope.of(context).requestFocus();
  }

  String _cleanJsonFromText(String text) {
    // Remove raw JSON blocks and objects from tool outputs for cleaner UI
    text = text.replaceAll(RegExp(r'\{[^}]*\}', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\[[^\]]*\]', multiLine: true), '');
    text = text.replaceAll(RegExp(r'"[^"]*"\s*:\s*"[^"]*"'), '');
    text = text.replaceAll(RegExp(r'"[^"]*"\s*:\s*\d+'), '');
    text = text.replaceAll(RegExp(r'"[^"]*"\s*:\s*(true|false|null)'), '');
    // Clean up extra whitespace and newlines
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// REMOVED: This function was removing code blocks
  String _cleanStreamingText_DISABLED(String text) {
    // This function is disabled to preserve code blocks
    return text; // Return text unchanged
  }

  // Parse thoughts and content in real-time during streaming
  Map<String, dynamic> _parseContentStreaming(String text) {
    final List<ThoughtContent> thoughts = [];
    final List<CodeContent> codes = [];
    String displayText = text;
    
    // Debug: Check if text contains code blocks
    if (text.contains('```')) {
      print('🔍 PARSING: Found code blocks in text (${text.length} chars)');
    }
    
    // Regex patterns for different thought types - including partial matches
    final thoughtPatterns = {
      'thinking': RegExp(r'<thinking>(.*?)</thinking>', dotAll: true),
      'thoughts': RegExp(r'<thoughts>(.*?)</thoughts>', dotAll: true),
      'think': RegExp(r'<think>(.*?)</think>', dotAll: true),
      'thought': RegExp(r'<thought>(.*?)</thought>', dotAll: true),
      'reason': RegExp(r'<reason>(.*?)</reason>', dotAll: true),
      'reasoning': RegExp(r'<reasoning>(.*?)</reasoning>', dotAll: true),
    };
    
    // Also check for unclosed tags (streaming in progress)
    final partialThoughtPatterns = {
      'thinking': RegExp(r'<thinking>(.*?)$', dotAll: true),
      'thoughts': RegExp(r'<thoughts>(.*?)$', dotAll: true),
      'think': RegExp(r'<think>(.*?)$', dotAll: true),
      'thought': RegExp(r'<thought>(.*?)$', dotAll: true),
      'reason': RegExp(r'<reason>(.*?)$', dotAll: true),
      'reasoning': RegExp(r'<reasoning>(.*?)$', dotAll: true),
    };
    
    // Code block patterns for real-time parsing (complete blocks)
    // IMPORTANT: Use word boundaries (\b) to prevent partial matches!
    final codePatterns = {
      // C++ variants BEFORE 'c' to prevent conflicts
      'cpp': RegExp(r'```(?:cpp|c\+\+|cxx)\b\s*(.*?)```', dotAll: true),
      'csharp': RegExp(r'```(?:csharp|cs|c#)\b\s*(.*?)```', dotAll: true),
      'c': RegExp(r'```c\b\s*(.*?)```', dotAll: true), // \b prevents matching 'css'
      
      // JavaScript variants BEFORE 'java'
      'javascript': RegExp(r'```(?:javascript|js)\b\s*(.*?)```', dotAll: true),
      'typescript': RegExp(r'```(?:typescript|ts)\b\s*(.*?)```', dotAll: true),
      'java': RegExp(r'```java\b\s*(.*?)```', dotAll: true), // \b prevents matching 'javascript'
      
      // Specific web frameworks
      'react': RegExp(r'```(?:react|jsx|tsx)\b\s*(.*?)```', dotAll: true),
      'vue': RegExp(r'```vue\b\s*(.*?)```', dotAll: true),
      'angular': RegExp(r'```angular\b\s*(.*?)```', dotAll: true),
      'svelte': RegExp(r'```svelte\b\s*(.*?)```', dotAll: true),
      
      // CSS variants
      'scss': RegExp(r'```(?:scss|sass)\b\s*(.*?)```', dotAll: true),
      'less': RegExp(r'```less\b\s*(.*?)```', dotAll: true),
      'css': RegExp(r'```css\b\s*(.*?)```', dotAll: true),
      
      // Web Technologies
      'html': RegExp(r'```html\b\s*(.*?)```', dotAll: true),
      
      // Programming Languages (alphabetical after conflicts resolved)
      'dart': RegExp(r'```dart\b\s*(.*?)```', dotAll: true),
      'kotlin': RegExp(r'```(?:kotlin|kt)\b\s*(.*?)```', dotAll: true),
      'php': RegExp(r'```php\b\s*(.*?)```', dotAll: true),
      'python': RegExp(r'```(?:python|py)\b\s*(.*?)```', dotAll: true),
      'ruby': RegExp(r'```(?:ruby|rb)\b\s*(.*?)```', dotAll: true),
      'swift': RegExp(r'```swift\b\s*(.*?)```', dotAll: true),
      'go': RegExp(r'```(?:go|golang)\b\s*(.*?)```', dotAll: true),
      'rust': RegExp(r'```(?:rust|rs)\b\s*(.*?)```', dotAll: true),
      'scala': RegExp(r'```scala\b\s*(.*?)```', dotAll: true),
      'perl': RegExp(r'```(?:perl|pl)\b\s*(.*?)```', dotAll: true),
      'lua': RegExp(r'```lua\b\s*(.*?)```', dotAll: true),
      'r': RegExp(r'```r\b\s*(.*?)```', dotAll: true),
      'matlab': RegExp(r'```(?:matlab|m)\b\s*(.*?)```', dotAll: true),
      
      // Data & Config
      'sql': RegExp(r'```sql\b\s*(.*?)```', dotAll: true),
      'json': RegExp(r'```json\b\s*(.*?)```', dotAll: true),
      'xml': RegExp(r'```xml\b\s*(.*?)```', dotAll: true),
      'yaml': RegExp(r'```(?:yaml|yml)\b\s*(.*?)```', dotAll: true),
      'toml': RegExp(r'```toml\b\s*(.*?)```', dotAll: true),
      'ini': RegExp(r'```ini\b\s*(.*?)```', dotAll: true),
      'csv': RegExp(r'```csv\b\s*(.*?)```', dotAll: true),
      
      // Shell & Scripts
      'bash': RegExp(r'```(?:bash|shell|sh)\b\s*(.*?)```', dotAll: true),
      'powershell': RegExp(r'```(?:powershell|ps1)\b\s*(.*?)```', dotAll: true),
      'zsh': RegExp(r'```zsh\b\s*(.*?)```', dotAll: true),
      'fish': RegExp(r'```fish\b\s*(.*?)```', dotAll: true),
      'batch': RegExp(r'```(?:batch|bat|cmd)\b\s*(.*?)```', dotAll: true),
      
      // Documentation
      'markdown': RegExp(r'```(?:markdown|md)\b\s*(.*?)```', dotAll: true),
      'latex': RegExp(r'```(?:latex|tex)\b\s*(.*?)```', dotAll: true),
      'text': RegExp(r'```(?:text|txt|plain)\b\s*(.*?)```', dotAll: true),
      
      // DevOps & Infrastructure
      'dockerfile': RegExp(r'```(?:dockerfile|docker)\b\s*(.*?)```', dotAll: true),
      'terraform': RegExp(r'```(?:terraform|tf)\b\s*(.*?)```', dotAll: true),
      'ansible': RegExp(r'```ansible\b\s*(.*?)```', dotAll: true),
      'kubernetes': RegExp(r'```(?:kubernetes|k8s)\b\s*(.*?)```', dotAll: true),
      'nginx': RegExp(r'```nginx\b\s*(.*?)```', dotAll: true),
      'apache': RegExp(r'```apache\b\s*(.*?)```', dotAll: true),
      
      // Hardware Description
      'verilog': RegExp(r'```(?:verilog|v)\b\s*(.*?)```', dotAll: true),
      'vhdl': RegExp(r'```vhdl\b\s*(.*?)```', dotAll: true),
      'systemverilog': RegExp(r'```(?:systemverilog|sv)\b\s*(.*?)```', dotAll: true),
    };
    
    // Partial code patterns for streaming (unclosed blocks) 
    // Manually create partial patterns for the most common languages to avoid conflicts
    final partialCodePatterns = {
      // C++ variants BEFORE 'c' to prevent conflicts
      'cpp': RegExp(r'```(?:cpp|c\+\+|cxx)\b\s*(.*?)$', dotAll: true),
      'csharp': RegExp(r'```(?:csharp|cs|c#)\b\s*(.*?)$', dotAll: true),
      'c': RegExp(r'```c\b\s*(.*?)$', dotAll: true),
      
      // JavaScript variants BEFORE 'java'
      'javascript': RegExp(r'```(?:javascript|js)\b\s*(.*?)$', dotAll: true),
      'typescript': RegExp(r'```(?:typescript|ts)\b\s*(.*?)$', dotAll: true),
      'java': RegExp(r'```java\b\s*(.*?)$', dotAll: true),
      
      // CSS variants  
      'scss': RegExp(r'```(?:scss|sass)\b\s*(.*?)$', dotAll: true),
      'less': RegExp(r'```less\b\s*(.*?)$', dotAll: true),
      'css': RegExp(r'```css\b\s*(.*?)$', dotAll: true),
      
      // Web Technologies
      'html': RegExp(r'```html\b\s*(.*?)$', dotAll: true),
      'react': RegExp(r'```(?:react|jsx|tsx)\b\s*(.*?)$', dotAll: true),
      'vue': RegExp(r'```vue\b\s*(.*?)$', dotAll: true),
      
      // Common Programming Languages
      'python': RegExp(r'```(?:python|py)\b\s*(.*?)$', dotAll: true),
      'dart': RegExp(r'```dart\b\s*(.*?)$', dotAll: true),
      'php': RegExp(r'```php\b\s*(.*?)$', dotAll: true),
      'ruby': RegExp(r'```(?:ruby|rb)\b\s*(.*?)$', dotAll: true),
      'swift': RegExp(r'```swift\b\s*(.*?)$', dotAll: true),
      'kotlin': RegExp(r'```(?:kotlin|kt)\b\s*(.*?)$', dotAll: true),
      'go': RegExp(r'```(?:go|golang)\b\s*(.*?)$', dotAll: true),
      'rust': RegExp(r'```(?:rust|rs)\b\s*(.*?)$', dotAll: true),
      
      // Data & Config
      'json': RegExp(r'```json\b\s*(.*?)$', dotAll: true),
      'yaml': RegExp(r'```(?:yaml|yml)\b\s*(.*?)$', dotAll: true),
      'xml': RegExp(r'```xml\b\s*(.*?)$', dotAll: true),
      'sql': RegExp(r'```sql\b\s*(.*?)$', dotAll: true),
      
      // Shell & Scripts
      'bash': RegExp(r'```(?:bash|shell|sh)\b\s*(.*?)$', dotAll: true),
      'powershell': RegExp(r'```(?:powershell|ps1)\b\s*(.*?)$', dotAll: true),
      
      // Documentation
      'markdown': RegExp(r'```(?:markdown|md)\b\s*(.*?)$', dotAll: true),
      'text': RegExp(r'```(?:text|txt|plain)\b\s*(.*?)$', dotAll: true),
    };
    
    // Extract complete thoughts and remove them from display text
    for (String type in thoughtPatterns.keys) {
      final matches = thoughtPatterns[type]!.allMatches(text);
      for (final match in matches) {
        final thoughtText = match.group(1)?.trim() ?? '';
        if (thoughtText.isNotEmpty) {
          thoughts.add(ThoughtContent(text: thoughtText, type: type));
        }
        // Remove the entire complete thought block from display text
        displayText = displayText.replaceAll(match.group(0)!, '');
      }
    }
    
    // Handle partial/streaming thoughts (unclosed tags)
    for (String type in partialThoughtPatterns.keys) {
      final match = partialThoughtPatterns[type]!.firstMatch(text);
      if (match != null) {
        final thoughtText = match.group(1)?.trim() ?? '';
        if (thoughtText.isNotEmpty) {
          // Only add if we don't already have a complete thought of this type
          final hasCompleteThought = thoughts.any((t) => t.type == type);
          if (!hasCompleteThought) {
            thoughts.add(ThoughtContent(text: thoughtText, type: type));
          }
        }
        // Remove the partial thought block from display text
        displayText = displayText.replaceAll(match.group(0)!, '');
      }
    }
    
    // Extract complete code blocks and remove them from display text
    for (String language in codePatterns.keys) {
      final matches = codePatterns[language]!.allMatches(text);
      for (final match in matches) {
        final code = match.group(1)?.trim() ?? '';
        if (code.isNotEmpty) {
          print('🔍 Found complete code block: $language (${code.length} chars)');
          print('    Pattern matched: ${match.group(0)?.substring(0, 20)}...');
          print('    Code preview: ${code.length > 50 ? code.substring(0, 50) : code}...');
          codes.add(CodeContent(
            code: code,
            language: language,
            extension: _getFileExtension(language),
          ));
        }
        // Remove the entire complete code block from display text
        displayText = displayText.replaceAll(match.group(0)!, '');
      }
    }
    
    // Handle partial/streaming code blocks (unclosed blocks)
    for (String language in partialCodePatterns.keys) {
      final match = partialCodePatterns[language]!.firstMatch(text);
      if (match != null) {
        final code = match.group(1)?.trim() ?? '';
        if (code.isNotEmpty) {
          // Only add if we don't already have a complete code block of this language
          final hasCompleteCode = codes.any((c) => c.language == language);
          if (!hasCompleteCode) {
            print('🔍 Found partial code block: $language (${code.length} chars)');
            print('    Partial code preview: ${code.length > 50 ? code.substring(0, 50) : code}...');
            codes.add(CodeContent(
              code: code,
              language: language,
              extension: _getFileExtension(language),
            ));
          }
        }
        // Remove the partial code block from display text
        displayText = displayText.replaceAll(match.group(0)!, '');
      }
    }
    
    if (codes.isNotEmpty || thoughts.isNotEmpty) {
      print('✅ PARSE RESULT: ${thoughts.length} thoughts, ${codes.length} codes');
    }
    
    return {
      'thoughts': thoughts,
      'codes': codes,
      'displayText': displayText.trim(),
    };
  }
  
  String _getFileExtension(String language) {
    const extensions = {
      // Web Technologies
      'html': '.html',
      'css': '.css',
      'javascript': '.js',
      'typescript': '.ts',
      'react': '.jsx',
      'vue': '.vue',
      'angular': '.ts',
      'svelte': '.svelte',
      'scss': '.scss',
      'less': '.less',
      
      // Programming Languages
      'python': '.py',
      'dart': '.dart',
      'java': '.java',
      'kotlin': '.kt',
      'swift': '.swift',
      'cpp': '.cpp',
      'c': '.c',
      'csharp': '.cs',
      'php': '.php',
      'ruby': '.rb',
      'go': '.go',
      'rust': '.rs',
      'scala': '.scala',
      'perl': '.pl',
      'lua': '.lua',
      'r': '.r',
      'matlab': '.m',
      
      // Data & Config
      'sql': '.sql',
      'json': '.json',
      'xml': '.xml',
      'yaml': '.yaml',
      'toml': '.toml',
      'ini': '.ini',
      'csv': '.csv',
      
      // Shell & Scripts
      'bash': '.sh',
      'powershell': '.ps1',
      'batch': '.bat',
      'fish': '.fish',
      'zsh': '.zsh',
      
      // Markup & Documentation
      'markdown': '.md',
      'text': '.txt',
      'latex': '.tex',
      'rst': '.rst',
      'asciidoc': '.adoc',
      
      // Functional Languages
      'haskell': '.hs',
      'elixir': '.ex',
      'erlang': '.erl',
      'clojure': '.clj',
      'ocaml': '.ml',
      'fsharp': '.fs',
      'lisp': '.lisp',
      'scheme': '.scm',
      
      // Modern Languages
      'julia': '.jl',
      'nim': '.nim',
      'zig': '.zig',
      'crystal': '.cr',
      'vlang': '.v',
      
      // Mobile Development
      'flutter': '.dart',
      'reactnative': '.jsx',
      'xamarin': '.cs',
      
      // Game Development
      'gdscript': '.gd',
      'hlsl': '.hlsl',
      'glsl': '.glsl',
      'unity': '.cs',
      
      // Blockchain
      'solidity': '.sol',
      'vyper': '.vy',
      'move': '.move',
      
      // Assembly & Low Level
      'assembly': '.asm',
      'x86': '.asm',
      'arm': '.s',
      
      // Hardware Description
      'verilog': '.v',
      'vhdl': '.vhd',
      'systemverilog': '.sv',
    };
    return extensions[language] ?? '.txt';
  }

  @override
  Widget build(BuildContext context) {
    final emptyChat = _messages.length <= 1;
    return Container(
              color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: emptyChat && _editingMessageId == null
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Welcome message - centered in screen
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildWelcomeMessage(),
                          ),
                          
                          const SizedBox(height: 60),
                          
                          // Suggestions
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _prompts.map((p) => Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _controller.text = p;
                                        _send();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FA),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          p,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF000000),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, index) {
                      final message = _messages[index];
                      return MessageBubble(
                        message: message,
                        onRegenerate: () => _regenerateResponse(index),
                        onUserMessageTap: () => _showUserMessageOptions(context, message),
                        onSaveImage: _saveImageToDevice,
                        onEditMessage: _editMessage,
                      );
                    },
                  ),
          ),

          // External tools now execute silently - no status panel
                        SafeArea(
            top: false,
            left: false,
            right: false,
            child: InputBar(
              controller: _controller,
              onSend: () => _isImageGenerationMode ? _generateImageInline() : _send(),
              onStop: _stopGeneration,
              awaitingReply: _awaitingReply,
              isEditing: _editingMessageId != null,
              onCancelEdit: _cancelEditing,
              onUnifiedAttachment: _handleUnifiedAttachment,  // Unified attachment
              attachedFiles: _attachedFiles,
              onClearFile: _clearFile,
              isImageGenerationMode: _isImageGenerationMode,
              selectedImageModel: _selectedImageModel,
              availableImageModels: _availableImageModels,
              onImageModelChanged: (model) => setState(() => _selectedImageModel = model),
              onCancelImageGeneration: _disableImageGenerationMode,
              isGeneratingImage: _isGeneratingImage,
              followUpMode: _followUpMode,
              onToggleFollowUp: () => setState(() => _followUpMode = !_followUpMode),
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _sendMessage(String text) async {
    // Implement the logic to send a message to the AI
    // This is a placeholder implementation
    print('Sending message: $text');
    await _generateResponse(text);
  }

  // Build welcome message with styled user name
  Widget _buildWelcomeMessage() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)); // IST
    final hour = now.hour;
    final user = SupabaseAuthService.currentUser;
    
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = "Good morning";
    } else if (hour >= 12 && hour < 17) {
      greeting = "Good afternoon";
    } else if (hour >= 17 && hour < 21) {
      greeting = "Good evening";
    } else {
      greeting = "Good night";
    }
    
    String userName = SupabaseAuthService.userFullName ?? 
                     user?.email?.split('@')[0] ?? 
                     "there";
    
    return Column(
      children: [
        // Greeting with larger user name
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF09090B),
              height: 1.3,
            ),
            children: [
              TextSpan(text: "$greeting, "),
              TextSpan(
                text: userName,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF09090B),
                ),
              ),
              const TextSpan(text: "!"),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "How can I help you today?",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF09090B),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "I'm here to help you with questions, tasks, and conversations.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF71717A),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
