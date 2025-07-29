import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models.dart';
import 'character_service.dart';
import 'image_generation_dialog.dart';
import 'image_generation_service.dart';
import 'external_tools_service.dart';
import 'crypto_chart_widget.dart';
import 'diagram_save_widget.dart';
import 'cache_manager.dart';
import 'cached_image_widget.dart';
// import 'langchain_agent_service.dart';


/* ----------------------------------------------------------
   CHAT PAGE
---------------------------------------------------------- */
class ChatPage extends StatefulWidget {
  final void Function(Message botMessage) onBookmark;
  final String selectedModel;
  const ChatPage({super.key, required this.onBookmark, required this.selectedModel});

  @override
  State<ChatPage> createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <Message>[
    Message.bot('Hi, I\'m AhamAI. Ask me anything!'),
  ];
  bool _awaitingReply = false;
  String? _editingMessageId;




  // Image upload functionality
  String? _uploadedImagePath;
  String? _uploadedImageBase64;
  
  // Image generation mode
  bool _isImageGenerationMode = false;
  String _selectedImageModel = 'flux';
  List<String> _availableImageModels = ['flux', 'turbo'];
  bool _isGeneratingImage = false;
  
  // Image generation memory and follow-up (default OFF)
  List<String> _imagePromptMemory = [];
  bool _followUpMode = false; // Default OFF - user can enable if needed

  // Add memory system for general chat
  List<String> _conversationMemory = [];
  static const int _maxMemorySize = 10;

  http.Client? _httpClient;
  final CharacterService _characterService = CharacterService();
  final ExternalToolsService _externalToolsService = ExternalToolsService();
  // late LangChainAgentService _langChainAgent;

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
    super.initState();
    _characterService.addListener(_onCharacterChanged);
    _externalToolsService.addListener(_onExternalToolsServiceChanged);
    
    // Initialize LangChain Agent (temporarily disabled for testing)
    // _langChainAgent = LangChainAgentService();
    // _initializeLangChainAgent();
    
    _updateGreetingForCharacter();
    _loadConversationMemory();
    _loadImageModels();
    _controller.addListener(() {
      setState(() {}); // Refresh UI when text changes
    });
  }

  // LangChain methods temporarily disabled
  
  Future<void> _loadConversationMemory() async {
    try {
      final savedMemory = await CacheManager.instance.getConversationMemory();
      setState(() {
        _conversationMemory = savedMemory;
      });
      
      // Also load chat history
      await _loadChatHistory();
    } catch (e) {
      debugPrint('Error loading conversation memory: $e');
    }
  }
  
  Future<void> _saveChatHistory() async {
    try {
      final chatData = _messages.map((message) => {
        'text': message.text,
        'sender': message.sender.toString(),
        'timestamp': message.timestamp.millisecondsSinceEpoch,
        'isStreaming': message.isStreaming,
      }).toList();
      
      await CacheManager.instance.saveSetting('chat_history', jsonEncode(chatData));
      debugPrint('Chat history saved: ${chatData.length} messages');
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    }
  }
  
  Future<void> _loadChatHistory() async {
    try {
      final chatHistoryStr = await CacheManager.instance.getSetting<String>('chat_history');
      if (chatHistoryStr != null && chatHistoryStr.isNotEmpty) {
        final List<dynamic> chatData = jsonDecode(chatHistoryStr);
        final loadedMessages = chatData.map((data) => Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: data['text'] as String,
          sender: (data['sender'] as String) == 'Sender.bot' ? Sender.bot : Sender.user,
          timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
          isStreaming: data['isStreaming'] as bool? ?? false,
        )).toList();
        
        if (loadedMessages.isNotEmpty) {
          setState(() {
            // Clear existing messages except greeting and add loaded messages
            _messages.clear();
            _messages.addAll(loadedMessages);
          });
          debugPrint('Chat history loaded: ${loadedMessages.length} messages');
        }
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  @override
  void dispose() {
    _characterService.removeListener(_onCharacterChanged);
    _externalToolsService.removeListener(_onExternalToolsServiceChanged);
    // _langChainAgent.dispose();
    _controller.dispose();
    _scroll.dispose();
    _httpClient?.close();
    super.dispose();
  }

  List<Message> getMessages() => _messages;

  void loadChatSession(List<Message> messages) {
    setState(() {
      _awaitingReply = false;
      _httpClient?.close();
      _messages.clear();
      _messages.addAll(messages);
    });
  }

  void _onCharacterChanged() {
    if (mounted) {
      _updateGreetingForCharacter();
    }
  }

  void _onExternalToolsServiceChanged() {
    if (mounted) {
      setState(() {}); // Refresh UI when external tools service state changes
    }
  }

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
      backgroundColor: const Color(0xFFF4F3F0),
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

  Future<void> _generateResponse(String prompt) async {
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

    // Regular AI chat - AI is now aware of external tools it can access
    // The AI will mention and use external tools based on user requests

    _httpClient = http.Client();
    final memoryContext = _getMemoryContext();
    final fullPrompt = memoryContext.isNotEmpty ? '$memoryContext\n\nUser: $prompt' : prompt;

    try {
      final request = http.Request('POST', Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ahamaibyprakash25',
      });
      // Build message content with optional image
      Map<String, dynamic> messageContent;
      if (_uploadedImageBase64 != null && _uploadedImageBase64!.isNotEmpty) {
        messageContent = {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': fullPrompt,
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': _uploadedImageBase64!,
              },
            },
          ],
        };
      } else {
        messageContent = {'role': 'user', 'content': fullPrompt};
      }

      // Build system prompt with external tools information
      final availableTools = _externalToolsService.getAvailableTools();
      final toolsInfo = availableTools.map((tool) => 
        '- ${tool.name}: ${tool.description}'
      ).join('\n');
      
      final systemMessage = {
        'role': 'system',
        'content': '''You are AhamAI, an intelligent assistant with access to external tools. You can execute tools to help users with various tasks.

Available External Tools:
$toolsInfo

🔧 PYTHON-BASED TOOL EXECUTION:
When you need to use tools, write Python code using the execute_tool() function:

Single tool execution:
```python
# Create a diagram
diagram = execute_tool('plantuml_chart', diagram='Alice -> Bob: Hello')
print(f"Diagram created: {diagram}")
```

Sequential tools execution:
```python
# Execute tools ONE BY ONE (no parallel execution)  
# Get crypto data  
crypto_data = execute_tool('crypto_market_data', symbols='bitcoin,ethereum')

# Finally create diagram
chart = execute_tool('plantuml_chart', diagram='User -> API: Request\\nAPI -> Database: Query')
```

🎯 WHEN TO USE TOOLS:
- **screenshot**: Capture single/multiple webpages visually (supports urls array for batch)


- **plantuml_chart**: Generate technical diagrams ONLY - use for flowcharts, UML diagrams, system architecture, process flows
- **fetch_image_models**: Show available image generation models
- **create_image_collage**: Combine multiple images into one collage for easier analysis
- **crypto_market_data**: Get real-time crypto prices, market cap, volume, and 24h changes (automatically converts symbols like BTC→bitcoin, ETH→ethereum, ADA→cardano)
- **crypto_price_history**: Get historical crypto data with charts over different time periods (use coin IDs like bitcoin, ethereum, cardano)
- **crypto_global_stats**: Get global market statistics and DeFi data
- **crypto_trending**: Get trending coins, top gainers/losers, and market sentiment
- **get_local_ip**: Get local IP address for network connections

⚠️ CRITICAL EXECUTION RULES:
1. **SEQUENTIAL ONLY**: Execute tools ONE BY ONE, never simultaneously
2. **NO DUPLICATES**: Execute each tool only ONCE per request
3. **Diagram Generation**: Execute plantuml_chart ONCE, wait for completion, THEN explain
4. **WAIT FOR COMPLETION**: NEVER provide responses before tools complete execution

CORRECT PYTHON TOOL EXAMPLES:
```python
# Diagram creation example
diagram_result = execute_tool('plantuml_chart', diagram='Alice -> Bob: Hello\\nBob -> Alice: Hi there')
print("Diagram created:", diagram_result)
```

⚠️ IMPORTANT: Use tools appropriately:
- **plantuml_chart**: For technical diagrams, flowcharts, UML diagrams, system designs

🔍 ENHANCED FEATURES:
- Image generation now uses unique seeds to prevent duplicate images
- Screenshot analysis supports multiple images via automatic collage creation
- PlantUML diagrams with multiple fallback services and auto-enhancement
- All tools optimized for parallel execution when appropriate
- **fetch_ai_models**: List available AI chat models
- **switch_ai_model**: Change to different AI model
- **Crypto data**: Real-time prices, historical charts, market statistics, and trending analysis using CoinGecko API (no API key required)

🔗 SEQUENTIAL TOOL EXECUTION ONLY:
Execute tools ONE BY ONE in sequence. NO parallel execution! For example:
```python
# First get crypto data
crypto_data = execute_tool('crypto_market_data', symbols='bitcoin,ethereum')
# Finally get trending data
trend_data = execute_tool('crypto_trending')
```

```python
# Create diagram
diagram = execute_tool('plantuml_chart', diagram='User -> Computer: Work\\nComputer -> User: Results')
```

📋 CRYPTO TOOL USAGE GUIDELINES:
- **Symbol Conversion**: Automatically convert symbols to coin IDs (BTC→bitcoin, ETH→ethereum, ADA→cardano, etc.)
- **Multiple Coins**: For crypto_market_data, use comma-separated coin IDs: "bitcoin,ethereum,cardano"
- **Time Periods**: For crypto_price_history, use days: "1", "7", "30", "90", "365", "max"
- **Data Display**: Always show prices clearly with currency symbols and percentage changes
- **Silent Tool Execution**: Tools run silently - only show the final results in natural language

🌐 NETWORK UTILITIES:
- **get_local_ip**: Get device IP address for network connections

🎨 PLANTUML DIAGRAM GUIDELINES:
- **Always include diagram parameter**: Never leave diagram parameter empty
- **Auto-enhancement**: Set auto_enhance to true for better styling
- **Diagram Types**: Use appropriate types: sequence, class, usecase, activity, component, deployment, state
- **Display Results**: Always show the generated diagram image in the chat response
- **Silent Generation**: Don't show tool execution details - only the final diagram

🔄 TOOL EXECUTION BEHAVIOR:
- ALL tools should execute silently without showing execution panels
- Only display final results in natural conversational format
- For diagrams: Show the generated image directly in chat
- For crypto data: Present data in clean, formatted tables or descriptions
- Never expose raw tool JSON responses to users

Always use proper JSON format and explain what you're doing to help the user understand the process.

Be conversational and helpful!'''
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
        String finalProcessedText = '';
        await for (final line in stream) {
          if (!mounted || _httpClient == null) break;
          
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            if (jsonStr.trim() == '[DONE]') break;
            
            try {
              final data = json.decode(jsonStr);
              final content = data['choices']?[0]?['delta']?['content'];
              if (content != null) {
                accumulatedText += _fixServerEncoding(content);
                
                        // Process tools and create panels
        final processedStreamingMessage = await _processToolCallsDuringStreaming(accumulatedText, botMessageIndex);
        finalProcessedText = processedStreamingMessage; // Store the latest processed text
        
        // Use processed text directly - NO CLEANING during streaming to preserve tool results
        String displayText = processedStreamingMessage;
        
        // DON'T clean Python blocks during streaming - let _processToolCallsDuringStreaming handle it
                
                setState(() {
                  _messages[botMessageIndex] = botMessage.copyWith(
                    text: displayText,
                    isStreaming: true,
                  );
                });
                _scrollToBottom();
              }
            } catch (e) {
              // Continue on JSON parsing errors
            }
          }
        }

        // Streaming completed

        // FIXED: Only process final message, tools already executed during streaming
        // Use the final processed text that includes all tool results
        final textToUse = finalProcessedText.isNotEmpty ? finalProcessedText : accumulatedText;
        

        
        // DEBUG: Don't clean the final text - just use it directly to preserve tool results
        setState(() {
          _messages[botMessageIndex] = Message.bot(
            textToUse, // NO CLEANING - preserve tool results
            isStreaming: false,
          );
        });

        // Update memory with the completed conversation (can clean for memory)
        final memoryText = finalProcessedText.isNotEmpty ? finalProcessedText : accumulatedText;
        _updateConversationMemory(prompt, _cleanStreamingText(memoryText));
        
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
        if (_uploadedImageBase64 != null) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) _clearUploadedImage();
          });
        }
      }
    }
  }

  // Track already executed tools to prevent duplicates
  final Set<String> _executedTools = {};
  // Store completed tool results to prevent them from being overwritten
  final Map<String, String> _completedToolResults = {};
  
  /// Process Python-based tool calls during streaming - execute tools ONE BY ONE
  Future<String> _processToolCallsDuringStreaming(String responseText, int messageIndex) async {
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
          
          // Execute the tool immediately
          final result = await _externalToolsService.executeTool(toolName, parameters);
          debugPrint('Tool $toolName result: $result');
          
          // Format the result
          String resultText = _formatToolResult(toolName, result);
          
          // Add execution result directly
          executionResults += '$resultText\n\n';
          
          // Store the completed tool result to prevent it from being overwritten
          _completedToolResults[fullMatch] = resultText;
          

          
          // Update the message with results directly
          setState(() {
            final updatedText = processedText.replaceAll(
              fullMatch,
              resultText
            );
            
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              text: updatedText, // FIXED: Don't clean streaming text to preserve tool results
              isStreaming: true,
            );
          });
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
            final results = await _externalToolsService.executeToolsParallel(validToolCalls);
            toolData.addAll(results);
            
            // Build combined result text without execution headers
            String combinedResultText = '';
            for (final call in validToolCalls) {
              final toolName = call['tool_name'] as String;
              final result = results[toolName];
              combinedResultText += _formatToolResult(toolName, result ?? {}) + '\n\n';
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
            final result = await _externalToolsService.executeTool(toolName, parameters);
            toolData[toolName] = result;
            
            // Replace the JSON block with the tool execution result
            String resultText = _formatToolResult(toolName, result);
            processedText = processedText.replaceAll(match.group(0)!, resultText);
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
        case 'screenshot':
          // Handle multiple screenshots if they exist
          if (result.containsKey('screenshots') && result['screenshots'] is List) {
            final screenshots = result['screenshots'] as List;
            String screenshotImages = '';
            for (int i = 0; i < screenshots.length; i++) {
              final shot = screenshots[i] as Map;
              screenshotImages += '![Screenshot ${i + 1}](${shot['preview_url']})\n\n';
            }
            return '''**🖼️ Multiple Screenshots Captured Successfully**

$screenshotImages**Service:** ${result['service']}

✅ All screenshots captured and available for viewing!''';
          } else {
            return '''**🖼️ Screenshot Tool Executed Successfully**

**URL:** ${result['url']}
**Dimensions:** ${result['width']}x${result['height']}
**Service:** ${result['service']}

![Screenshot](${result['preview_url']})

✅ Screenshot captured and available for viewing!''';
          }

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

        case 'fetch_image_models':
          final models = result['model_names'] as List;
          final modelsList = models.take(5).join(', ');
          return '''**🎨 Image Models Fetched Successfully**

**Available Models:** ${result['total_count']} models found
**Sample Models:** $modelsList${models.length > 5 ? '...' : ''}
**API Status:** ${result['api_status']}

✅ Image models list retrieved successfully!''';

        case 'screenshot_vision':
          return '''**👁️ Screenshot Vision Analysis Completed**

**Question:** ${result['question']}
**Model:** ${result['model']}
**Analysis:** ${result['answer']}

          ✅ Screenshot analyzed successfully using vision AI!''';

        case 'plantuml_chart':
          // For PlantUML charts, show clean diagram without technical details
          return '''![PlantUML Diagram](${result['image_url']})''';

        case 'crypto_market_data':
          // Format crypto market data with interactive chart
          return _formatCryptoMarketDataWithChart(result);

        case 'crypto_price_history':
          // Format crypto price history cleanly
          return _formatCryptoPriceHistory(result);

        case 'crypto_global_stats':
          // Format crypto global stats cleanly
          return _formatCryptoGlobalStats(result);

        case 'crypto_trending':
          // Format crypto trending data cleanly
          return _formatCryptoTrending(result);

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

  String _formatCryptoMarketDataWithChart(Map<String, dynamic> result) {
    if (result['success'] != true) {
      return '''❌ **Crypto Data Error**: ${result['error']}''';
    }

    final data = result['data'] as Map<String, dynamic>?;
    if (data == null || data.isEmpty) {
      return '''❌ **No crypto data available**''';
    }

    // Create interactive chart widget with embedded data - AI will analyze the widget directly
    return '''[INTERACTIVE_CRYPTO_CHART:${base64Encode(utf8.encode(jsonEncode(result)))}]''';
  }

  String _formatCryptoMarketData(Map<String, dynamic> result) {
    if (result['success'] != true) {
      return '''❌ **Crypto Data Error**: ${result['error']}''';
    }

    final data = result['data'] as Map<String, dynamic>?;
    if (data == null || data.isEmpty) {
      return '''❌ **No crypto data available**''';
    }

    String output = '🪙 **Cryptocurrency Market Data**\n\n';
    
    // Create a visual chart representation
    List<Map<String, dynamic>> cryptoData = [];
    
    for (final entry in data.entries) {
      final coinId = entry.key;
      final coinData = entry.value as Map<String, dynamic>;
      
      final price = coinData['usd']?.toString() ?? 'N/A';
      final marketCap = coinData['usd_market_cap']?.toString() ?? 'N/A';
      final volume = coinData['usd_24h_vol']?.toString() ?? 'N/A';
      final change = coinData['usd_24h_change']?.toString() ?? 'N/A';
      
      final changeDouble = double.tryParse(change) ?? 0;
      final changeIcon = changeDouble >= 0 ? '🟢' : '🔴';
      final changeFormatted = changeDouble >= 0 ? '+${change}%' : '${change}%';
      
      cryptoData.add({
        'name': coinId.toUpperCase(),
        'price': price,
        'marketCap': marketCap,
        'volume': volume,
        'change': changeDouble,
        'changeFormatted': changeFormatted,
        'changeIcon': changeIcon,
      });
      
      // Price bar visualization will be calculated after all data is collected
      
      // Create a price trend visualization bar
      final priceNum = double.tryParse(price) ?? 0;
      final changeNum = double.tryParse(change) ?? 0;
      
      // Visual price bar (scaled to market position)
      final priceBarLength = (priceNum > 1000 ? 20 : priceNum > 100 ? 15 : priceNum > 10 ? 10 : 5).clamp(1, 20);
      final priceBar = '█' * priceBarLength + '░' * (20 - priceBarLength);
      
      // Volume indicator
      final volumeNum = double.tryParse(volume) ?? 0;
      final volumeBarLength = (volumeNum > 1e9 ? 15 : volumeNum > 1e8 ? 10 : volumeNum > 1e7 ? 5 : 1).clamp(1, 15);
      final volumeBar = '🟦' * volumeBarLength + '⬜' * (15 - volumeBarLength);
      
      output += '''
╭─────────────────────────────────────╮
│ **${coinId.toUpperCase()}**${' ' * (35 - coinId.length)}│
├─────────────────────────────────────┤
│ 💰 Price: \$${_formatNumber(price)}${' ' * (25 - _formatNumber(price).length)}│
│ [$priceBar] │
│                                     │
│ 📊 Market Cap: \$${_formatLargeNumber(marketCap)}${' ' * (18 - _formatLargeNumber(marketCap).length)}│
│ 💧 24h Volume: \$${_formatLargeNumber(volume)}${' ' * (18 - _formatLargeNumber(volume).length)}│
│ [$volumeBar] │
│                                     │
│ $changeIcon 24h Change: $changeFormatted${' ' * (22 - changeFormatted.length)}│
╰─────────────────────────────────────╯

''';
    }

    // Add comparison chart if multiple coins
    if (cryptoData.length > 1) {
      output += _generateComparisonChart(cryptoData);
    }

    output += '📡 *Data from ${result['source']}*';
    return output;
  }

  String _formatCryptoPriceHistory(Map<String, dynamic> result) {
    if (result['success'] != true) {
      return '''❌ **Price History Error**: ${result['error']}''';
    }

    final coinId = result['coin_id'] ?? 'Unknown';
    final timePeriod = result['time_period'] ?? '7';
    final data = result['data'] as Map<String, dynamic>?;
    
    if (data == null) {
      return '''❌ **No price history data available for $coinId**''';
    }

    final prices = data['prices'] as List<dynamic>? ?? [];
    if (prices.isEmpty) {
      return '''❌ **No price data available for $coinId**''';
    }

    final firstPrice = prices.first[1]?.toString() ?? '0';
    final lastPrice = prices.last[1]?.toString() ?? '0';
    final firstPriceNum = double.tryParse(firstPrice) ?? 0;
    final lastPriceNum = double.tryParse(lastPrice) ?? 0;
    
    final change = lastPriceNum - firstPriceNum;
    final changePercent = firstPriceNum > 0 ? (change / firstPriceNum) * 100 : 0;
    final changeIcon = changePercent >= 0 ? '🟢' : '🔴';
    final changeFormatted = changePercent >= 0 ? '+${changePercent.toStringAsFixed(2)}%' : '${changePercent.toStringAsFixed(2)}%';

    // Generate ASCII price chart
    final priceChart = _generatePriceChart(prices, coinId);

    return '''📈 **${coinId.toUpperCase()} Price History (${timePeriod} days)**

💰 Current Price: \$${_formatNumber(lastPrice)}
📊 Starting Price: \$${_formatNumber(firstPrice)}
$changeIcon Period Change: $changeFormatted
📏 Data Points: ${prices.length}

📊 **Price Chart:**
```
$priceChart
```

📡 *Data from ${result['source']}*''';
  }

  String _formatCryptoGlobalStats(Map<String, dynamic> result) {
    if (result['success'] != true) {
      return '''❌ **Global Stats Error**: ${result['error']}''';
    }

    final globalData = result['global_data'] as Map<String, dynamic>?;
    if (globalData == null) {
      return '''❌ **No global stats data available**''';
    }

    final totalMarketCap = globalData['total_market_cap']?['usd']?.toString() ?? 'N/A';
    final totalVolume = globalData['total_volume']?['usd']?.toString() ?? 'N/A';
    final activeCryptos = globalData['active_cryptocurrencies']?.toString() ?? 'N/A';
    final markets = globalData['markets']?.toString() ?? 'N/A';
    
    String output = '''🌍 **Global Cryptocurrency Market Stats**

💰 Total Market Cap: \$${_formatLargeNumber(totalMarketCap)}
📊 24h Trading Volume: \$${_formatLargeNumber(totalVolume)}
🪙 Active Cryptocurrencies: $activeCryptos
🏪 Markets: $markets

''';

    // Add market dominance if available
    final marketCapPercentage = globalData['market_cap_percentage'] as Map<String, dynamic>?;
    if (marketCapPercentage != null) {
      output += '👑 **Market Dominance Chart:**\n';
      final btcDominance = double.tryParse(marketCapPercentage['btc']?.toString() ?? '0') ?? 0;
      final ethDominance = double.tryParse(marketCapPercentage['eth']?.toString() ?? '0') ?? 0;
      
      final btcBar = '█' * (btcDominance / 2).round();
      final ethBar = '█' * (ethDominance / 2).round();
      
      output += '₿ Bitcoin: ${btcDominance.toStringAsFixed(1)}%\n';
      output += '|$btcBar\n';
      output += '⟠ Ethereum: ${ethDominance.toStringAsFixed(1)}%\n';
      output += '|$ethBar\n\n';
    }

    // Add DeFi data if available
    if (result['defi_data'] != null) {
      final defiData = result['defi_data'] as Map<String, dynamic>;
      final defiMarketCap = defiData['defi_market_cap']?.toString() ?? 'N/A';
      output += '''🏦 **DeFi Statistics:**
💎 DeFi Market Cap: \$${_formatLargeNumber(defiMarketCap)}

''';
    }

    output += '📡 *Data from ${result['source']}*';
    return output;
  }

  String _formatCryptoTrending(Map<String, dynamic> result) {
    if (result['success'] != true) {
      return '''❌ **Trending Data Error**: ${result['error']}''';
    }

    final category = result['category'] ?? 'trending';
    String output = '';

    if (category == 'search_trending') {
      final trendingData = result['trending_data'] as Map<String, dynamic>?;
      final coins = trendingData?['coins'] as List<dynamic>? ?? [];
      
      output = '''🔥 **Trending Cryptocurrencies**

''';
      
      for (int i = 0; i < coins.length && i < 10; i++) {
        final coin = coins[i] as Map<String, dynamic>;
        final name = coin['name'] ?? 'Unknown';
        final symbol = coin['symbol']?.toString().toUpperCase() ?? '';
        final marketCapRank = coin['market_cap_rank']?.toString() ?? 'N/A';
        
        output += '''${i + 1}. **$name ($symbol)**
   📊 Rank: #$marketCapRank

''';
      }
    } else {
      final marketData = result['market_data'] as List<dynamic>? ?? [];
      final title = category == 'top_gainers' ? '🚀 **Top Gainers**' : '📉 **Top Losers**';
      
      output = '$title\n\n';
      
      for (int i = 0; i < marketData.length && i < 10; i++) {
        final coin = marketData[i] as Map<String, dynamic>;
        final name = coin['name'] ?? 'Unknown';
        final symbol = coin['symbol']?.toString().toUpperCase() ?? '';
        final price = coin['current_price']?.toString() ?? '0';
        final change = coin['price_change_percentage_24h']?.toString() ?? '0';
        final changeDouble = double.tryParse(change) ?? 0;
        final changeIcon = changeDouble >= 0 ? '🟢' : '🔴';
        final changeFormatted = changeDouble >= 0 ? '+${change}%' : '${change}%';
        
        output += '''${i + 1}. **$name ($symbol)**
   💰 \$${_formatNumber(price)}
   $changeIcon $changeFormatted

''';
      }
    }

    output += '📡 *Data from ${result['source']}*';
    return output;
  }

  String _formatNumber(String numberStr) {
    final number = double.tryParse(numberStr) ?? 0;
    if (number >= 1) {
      return number.toStringAsFixed(2);
    } else {
      return number.toStringAsFixed(6);
    }
  }

  String _formatLargeNumber(String numberStr) {
    final number = double.tryParse(numberStr) ?? 0;
    if (number >= 1e12) {
      return '${(number / 1e12).toStringAsFixed(2)}T';
    } else if (number >= 1e9) {
      return '${(number / 1e9).toStringAsFixed(2)}B';
    } else if (number >= 1e6) {
      return '${(number / 1e6).toStringAsFixed(2)}M';
    } else if (number >= 1e3) {
      return '${(number / 1e3).toStringAsFixed(2)}K';
    } else {
      return number.toStringAsFixed(2);
    }
  }

  int _calculateBarLength(double value, List<double> allValues) {
    if (allValues.isEmpty || allValues.every((v) => v == 0)) return 0;
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return 0;
    return ((value / maxValue) * 20).round().clamp(0, 20);
  }

  String _generateComparisonChart(List<Map<String, dynamic>> cryptoData) {
    String output = '\n📊 **Price Comparison & Performance Chart**\n\n';
    
    // Find max price for scaling
    double maxPrice = 0;
    double maxChange = 0;
    for (final crypto in cryptoData) {
      final price = double.tryParse(crypto['price']) ?? 0;
      final change = (crypto['change'] as double).abs();
      if (price > maxPrice) maxPrice = price;
      if (change > maxChange) maxChange = change;
    }
    
    // Price comparison section
    output += '💰 **Price Comparison:**\n';
    for (final crypto in cryptoData) {
      final name = crypto['name'];
      final price = double.tryParse(crypto['price']) ?? 0;
      final changeFormatted = crypto['changeFormatted'];
      final changeIcon = crypto['changeIcon'];
      
      final barLength = maxPrice > 0 ? ((price / maxPrice) * 25).round().clamp(1, 25) : 1;
      final priceBar = '█' * barLength + '░' * (25 - barLength);
      
      output += '$name \$${_formatNumber(crypto['price'])}\n';
      output += '[$priceBar] $changeIcon $changeFormatted\n\n';
    }
    
    // Performance comparison section  
    output += '📈 **24h Performance:**\n';
    for (final crypto in cryptoData) {
      final name = crypto['name'];
      final change = crypto['change'] as double;
      final changeFormatted = crypto['changeFormatted'];
      final changeIcon = crypto['changeIcon'];
      
      final absChange = change.abs();
      final perfBarLength = maxChange > 0 ? ((absChange / maxChange) * 20).round().clamp(1, 20) : 1;
      final perfBar = change >= 0 ? '🟩' * perfBarLength : '🟥' * perfBarLength;
      final perfPadding = '⬜' * (20 - perfBarLength);
      
      output += '$name $changeIcon $changeFormatted\n';
      output += '[$perfBar$perfPadding]\n\n';
    }
    
    return output;
  }

  String _generatePriceChart(List<dynamic> prices, String coinId) {
    if (prices.length < 2) return 'Insufficient data for chart';
    
    // Extract price values and normalize them
    List<double> priceValues = [];
    for (final price in prices) {
      if (price is List && price.length >= 2) {
        priceValues.add(double.tryParse(price[1].toString()) ?? 0);
      }
    }
    
    if (priceValues.isEmpty) return 'No valid price data';
    
    final minPrice = priceValues.reduce((a, b) => a < b ? a : b);
    final maxPrice = priceValues.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    
    if (priceRange == 0) return 'Price remained constant at \$${_formatNumber(minPrice.toString())}';
    
    // Create enhanced ASCII chart (50 characters wide, 12 lines tall)
    const chartWidth = 50;
    const chartHeight = 12;
    
    String chart = '';
    
    // Chart title
    chart += '┌${'─' * (chartWidth + 8)}┐\n';
    chart += '│ ${coinId.toUpperCase()} PRICE TREND${' ' * (chartWidth + 8 - coinId.length - 13)}│\n';
    chart += '├${'─' * (chartWidth + 8)}┤\n';
    
    // Chart header with max price
    chart += '│ High: \$${_formatNumber(maxPrice.toString())}${' ' * (chartWidth + 8 - 8 - _formatNumber(maxPrice.toString()).length)}┤\n';
    
    // Main chart area with trend line
    for (int row = chartHeight - 4; row >= 0; row--) {
      String line = '│ ';
      final currentPriceLevel = minPrice + (priceRange * row / (chartHeight - 5));
      
      for (int col = 0; col < chartWidth; col++) {
        final dataIndex = (col * (priceValues.length - 1) / (chartWidth - 1)).round();
        if (dataIndex < priceValues.length) {
          final dataValue = priceValues[dataIndex];
          final threshold = priceRange / (chartHeight - 5);
          
          if ((dataValue - currentPriceLevel).abs() < threshold) {
            // Trend direction indicators
            if (dataIndex > 0) {
              final prevValue = priceValues[dataIndex - 1];
              if (dataValue > prevValue) {
                line += '🟢';  // Rising
              } else if (dataValue < prevValue) {
                line += '🔴';  // Falling
              } else {
                line += '🟡';  // Stable
              }
            } else {
              line += '●';
            }
          } else if (dataValue > currentPriceLevel) {
            line += '░';
          } else {
            line += ' ';
          }
        } else {
          line += ' ';
        }
      }
      line += ' │';
      chart += '$line\n';
    }
    
    // Chart footer with min price
    chart += '│ Low:  \$${_formatNumber(minPrice.toString())}${' ' * (chartWidth + 8 - 8 - _formatNumber(minPrice.toString()).length)}│\n';
    chart += '└${'─' * (chartWidth + 8)}┘\n';
    
    // Time scale
    chart += '  Start${' ' * (chartWidth ~/ 2 - 7)}Middle${' ' * (chartWidth ~/ 2 - 5)}End\n';
    
    // Trend summary
    final firstPrice = priceValues.first;
    final lastPrice = priceValues.last;
    final trendChange = ((lastPrice - firstPrice) / firstPrice * 100);
    final trendIcon = trendChange >= 0 ? '📈' : '📉';
    final trendDirection = trendChange >= 0 ? 'UPWARD' : 'DOWNWARD';
    
    chart += '\n$trendIcon Overall Trend: $trendDirection (${trendChange >= 0 ? '+' : ''}${trendChange.toStringAsFixed(2)}%)';
    
    return chart;
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
    setState(() {
      _awaitingReply = false;
      _editingMessageId = null;
      _conversationMemory.clear(); // Clear memory for fresh start
      _httpClient?.close();
      _httpClient = null;
      _messages.clear();
      final selectedCharacter = _characterService.selectedCharacter;
      if (selectedCharacter != null) {
        _messages.add(Message.bot('Fresh chat started with ${selectedCharacter.name}. How can I help?'));
      } else {
        _messages.add(Message.bot('Hi, I\'m AhamAI. Ask me anything!'));
      }
    });
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
    
    _controller.clear();
    setState(() {
      _messages.add(Message.user(messageText));
      _editingMessageId = null;
    });

    _scrollToBottom();
    HapticFeedback.lightImpact();
            await _generateResponse(messageText);
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
          color: Color(0xFFF4F3F0),
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
          _uploadedImagePath = pickedFile.path;
          _uploadedImageBase64 = 'data:image/jpeg;base64,$base64Image';
        });
        
        // Add image message to chat
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

        // Add generated image message
        final imageMessage = Message.bot('''**🎨 Image Generated Successfully**

![Generated Image](${result['image_url']})

**Model:** ${result['model'].toString().toUpperCase()}
**Size:** ${result['size_kb']}KB
${_followUpMode ? '\n*Following previous style*' : ''}''');
        
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
    showDialog(
      context: context,
      builder: (context) => ImageGenerationDialog(),
    );
  }

  void _clearUploadedImage() {
    setState(() {
      _uploadedImagePath = null;
      _uploadedImageBase64 = null;
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

  String _cleanStreamingText(String text) {
    // SIMPLE APPROACH: Just remove Python code blocks and execution messages
    // Show everything naturally in message UI without panels
    
    // Remove Python code blocks completely
    text = text.replaceAll(RegExp(r'```python[\s\S]*?```', multiLine: true), '');
    
    // Remove partial Python blocks that might appear during streaming
    text = text.replaceAll(RegExp(r'```python[\s\S]*$', multiLine: true), '');
    
    // Remove tool executing messages
    text = text.replaceAll(RegExp(r'\[Tool executing\.\.\.?\]', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\[Tools executing\.\.\.?\]', multiLine: true), '');
    
    // Remove any tool panel placeholders if they exist
    text = text.replaceAll(RegExp(r'\[TOOL_PANEL_(?:EXECUTING|COMPLETED):[^\]]*\]', multiLine: true), '');
    
    // Clean up extra whitespace and newlines
    text = text.replaceAll(RegExp(r'\n\s*\n+'), '\n\n').trim();
    
    return text;
  }









  @override
  Widget build(BuildContext context) {
    final emptyChat = _messages.length <= 1;
    return Container(
      color: const Color(0xFFF4F3F0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (_, index) {
                final message = _messages[index];
                return _MessageBubble(
                  message: message,
                  onRegenerate: () => _regenerateResponse(index),
                  onUserMessageTap: () => _showUserMessageOptions(context, message),
                );
              },
            ),
          ),
          if (emptyChat && _editingMessageId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _prompts.map((p) => Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _controller.text = p;
                            _send();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAE9E5),
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
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          // External tools now execute silently - no status panel
                        SafeArea(
            top: false,
            left: false,
            right: false,
            child: _InputBar(
              controller: _controller,
              onSend: () => _isImageGenerationMode ? _generateImageInline() : _send(),
              onStop: _stopGeneration,
              awaitingReply: _awaitingReply,
              isEditing: _editingMessageId != null,
              onCancelEdit: _cancelEditing,
              externalToolsService: _externalToolsService,
              onImageUpload: _showAttachmentOptions,
              uploadedImagePath: _uploadedImagePath,
              onClearImage: _clearUploadedImage,
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
}

/* ----------------------------------------------------------
   MESSAGE BUBBLE & ACTION BUTTONS - iOS Style Interactions
---------------------------------------------------------- */
class _MessageBubble extends StatefulWidget {
  final Message message;
  final VoidCallback? onRegenerate;
  final VoidCallback? onUserMessageTap;
  const _MessageBubble({
    required this.message,
    this.onRegenerate,
    this.onUserMessageTap,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> with TickerProviderStateMixin {
  bool _showActions = false;
  late AnimationController _actionsAnimationController;
  late Animation<double> _actionsAnimation;
  bool _showUserActions = false;
  late AnimationController _userActionsAnimationController;
  late Animation<double> _userActionsAnimation;

  @override
  void initState() {
    super.initState();
    _actionsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _actionsAnimation = CurvedAnimation(
      parent: _actionsAnimationController,
      curve: Curves.easeOut,
    );
    
    _userActionsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _userActionsAnimation = CurvedAnimation(
      parent: _userActionsAnimationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _actionsAnimationController.dispose();
    _userActionsAnimationController.dispose();
    super.dispose();
  }

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
      if (_showActions) {
        _actionsAnimationController.forward();
      } else {
        _actionsAnimationController.reverse();
      }
    });
  }

  void _toggleUserActions() {
    setState(() {
      _showUserActions = !_showUserActions;
      if (_showUserActions) {
        _userActionsAnimationController.forward();
      } else {
        _userActionsAnimationController.reverse();
      }
    });
  }

  void _giveFeedback(BuildContext context, bool isPositive) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPositive ? '👍 Thank you for your feedback!' : '👎 Feedback noted. We\'ll improve!',
          style: const TextStyle(
            color: Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
    // Hide actions after interaction
    _toggleActions();
  }

  void _copyMessage(BuildContext context) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '📋 Message copied to clipboard!',
          style: TextStyle(
            color: Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
    // Hide actions after interaction
    _toggleActions();
  }

  void _shareMessage(BuildContext context) {
    HapticFeedback.lightImpact();
    // For now, copy to clipboard (can implement actual sharing later)
    Clipboard.setData(ClipboardData(text: widget.message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '🔗 Message ready to share!',
          style: TextStyle(
            color: Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
    // Hide actions after interaction
    _toggleActions();
  }


  Widget _buildImageWidget(String url) {
    try {
      Widget image;
      if (url.startsWith('data:image')) {
        final commaIndex = url.indexOf(',');
        final header = url.substring(5, commaIndex);
        final mime = header.split(';').first;
        if (mime == 'image/svg+xml') {
          final base64Data = url.substring(commaIndex + 1);
          final bytes = base64Decode(base64Data);
          image = SvgPicture.memory(bytes, fit: BoxFit.contain);
        } else {
          // Use CachedImageWidget for base64 images too
          image = CachedImageWidget(
            imageUrl: url,
            fit: BoxFit.contain,
          );
        }
      } else {
        if (url.toLowerCase().endsWith('.svg')) {
          image = SvgPicture.network(
            url,
            fit: BoxFit.contain,
            placeholderBuilder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
        } else {
          // Use CachedImageWidget for network images
          image = CachedImageWidget(
            imageUrl: url,
            fit: BoxFit.contain,
          );
        }
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300, maxWidth: double.infinity),
          child: image,
        ),
      );
    } catch (_) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
  }

  Widget _buildBotMessageContent(String text) {
    final widgets = <Widget>[];
    final lines = text.split('\n');
    String currentText = '';
    


    // Simple content rendering without shimmer effects
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Tool panels removed - everything shows directly in message UI
      
      // Check for base64 images (generated images or diagrams)
      if (line.contains('data:image/') && line.contains('base64,')) {
        // Add any accumulated text
        if (currentText.isNotEmpty) {
          widgets.add(_buildMarkdownText(currentText));
          currentText = '';
        }
        
        // Extract base64 image data
        final base64Regex = RegExp(r'data:image/[^;]+;base64,[A-Za-z0-9+/=]+');
        final base64Match = base64Regex.firstMatch(line);
        if (base64Match != null) {
          final base64ImageData = base64Match.group(0) ?? '';

          
          widgets.add(
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedImageWidget(
                  imageUrl: base64ImageData,
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }
        continue;
      }
      
      // Check for interactive crypto chart placeholder
      if (line.contains('[INTERACTIVE_CRYPTO_CHART')) {
        // Add any accumulated text
        if (currentText.isNotEmpty) {
          widgets.add(_buildMarkdownText(currentText));
          currentText = '';
        }
        
        // Extract embedded crypto data or fallback to context extraction
        Map<String, dynamic>? cryptoData;
        
        // Try to extract embedded data first
        final regex = RegExp(r'\[INTERACTIVE_CRYPTO_CHART:(.*?)\]');
        final match = regex.firstMatch(line);
        if (match != null) {
          try {
            final encodedData = match.group(1) ?? '';
            final decodedData = utf8.decode(base64Decode(encodedData));
            cryptoData = jsonDecode(decodedData) as Map<String, dynamic>;
            cryptoData = _transformCryptoDataForChart(cryptoData);
          } catch (e) {
            print('Error decoding crypto data: $e');
          }
        }
        
        // Fallback to context extraction if embedded data failed
        cryptoData ??= _extractCryptoDataFromContext(text);
        
        if (cryptoData != null) {
          widgets.add(
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: CryptoChartWidget(
                cryptoData: cryptoData,
                height: 450,
              ),
            ),
          );
        }
        continue;
      }
      

      
      // Accumulate regular text
      if (i == 0) {
        currentText = line;
      } else {
        currentText += '\n$line';
      }
    }
    
    // Add any remaining text
    if (currentText.isNotEmpty) {
      widgets.add(_buildMarkdownText(currentText));
    }
    
    // No shimmer effects - content displays directly
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildMarkdownText(String text) {
    return MarkdownBody(
      data: text,
      imageBuilder: (uri, title, alt) => _buildImageWidget(uri.toString()),
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
          fontFamily: 'SF Mono',
          fontSize: 14,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFEAE9E5),
          borderRadius: BorderRadius.circular(8),
        ),
        h1: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
        h2: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
        h3: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
        listBullet: const TextStyle(color: Color(0xFFA3A3A3)),
        blockquote: const TextStyle(color: Color(0xFFA3A3A3)),
        strong: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
        em: const TextStyle(color: Color(0xFF000000), fontStyle: FontStyle.italic),
      ),
    );
  }

  Map<String, dynamic> _transformCryptoDataForChart(Map<String, dynamic> apiResult) {
    final data = apiResult['data'] as Map<String, dynamic>?;
    if (data == null) return apiResult;

    // Transform API data format to chart widget format
    final transformedData = <String, dynamic>{};
    for (final entry in data.entries) {
      final coinId = entry.key;
      final coinData = entry.value as Map<String, dynamic>;
      
      transformedData[coinId] = {
        'name': coinId.replaceAll('-', ' ').toUpperCase(),
        'symbol': coinId.substring(0, 3).toUpperCase(),
        'current_price': double.tryParse(coinData['usd']?.toString() ?? '0') ?? 0,
        'price_change_percentage_24h': double.tryParse(coinData['usd_24h_change']?.toString() ?? '0') ?? 0,
        'market_cap': double.tryParse(coinData['usd_market_cap']?.toString() ?? '0') ?? 0,
        'total_volume': double.tryParse(coinData['usd_24h_vol']?.toString() ?? '0') ?? 0,
        'circulating_supply': _getCirculatingSupply(coinId),
      };
    }

    return {
      'success': true,
      'data': transformedData,
      'source': apiResult['source'] ?? 'CoinGecko API',
    };
  }

  double _getCirculatingSupply(String coinId) {
    // Return realistic circulating supply estimates
    switch (coinId.toLowerCase()) {
      case 'bitcoin':
        return 19700000;
      case 'ethereum':
        return 120200000;
      case 'cardano':
        return 35000000000;
      case 'solana':
        return 420000000;
      case 'polkadot':
        return 1300000000;
      default:
        return 1000000000; // Default estimate
    }
  }

  Map<String, dynamic>? _extractCryptoDataFromContext(String text) {
    // Extract data from market summary section
    final lines = text.split('\n');
    final cryptoData = <String, dynamic>{};
    
    for (final line in lines) {
      if (line.contains('**') && line.contains('\$') && line.contains('%')) {
        // Parse line like: • **BITCOIN**: $43,250.00 🟢 +2.34%
        final regex = RegExp(r'• \*\*(.*?)\*\*: \$([0-9,\.]+) [🟢🔴] ([\+\-0-9\.]+)%');
        final match = regex.firstMatch(line);
        if (match != null) {
          final coin = match.group(1)?.toLowerCase() ?? '';
          final priceStr = match.group(2)?.replaceAll(',', '') ?? '0';
          final changeStr = match.group(3) ?? '0';
          
          final price = double.tryParse(priceStr) ?? 0;
          final change = double.tryParse(changeStr) ?? 0;
          
          cryptoData[coin] = {
            'name': coin.substring(0, 1).toUpperCase() + coin.substring(1),
            'symbol': coin.substring(0, 3),
            'current_price': price,
            'price_change_percentage_24h': change,
            'market_cap': price * _getCirculatingSupply(coin),
            'total_volume': price * 1000000, // Estimate
            'circulating_supply': _getCirculatingSupply(coin),
          };
        }
      }
    }
    
    if (cryptoData.isNotEmpty) {
      return {
        'success': true,
        'data': cryptoData,
        'source': 'Extracted from API',
      };
    }
    
    // Fallback sample data
    return {
      'success': true,
      'data': {
        'bitcoin': {
          'name': 'Bitcoin',
          'symbol': 'btc',
          'current_price': 43250.00,
          'price_change_percentage_24h': 2.34,
          'market_cap': 850500000000,
          'total_volume': 25300000000,
          'circulating_supply': 19700000,
        },
      },
      'source': 'Demo Data',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isBot = widget.message.sender == Sender.bot;
    final isUser = widget.message.sender == Sender.user;
    final canShowActions = isBot && !widget.message.isStreaming && widget.message.text.isNotEmpty && widget.onRegenerate != null;

    Widget bubbleContent = Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: isBot ? Colors.transparent : const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: isBot
          ? _buildBotMessageContent(widget.message.displayText)
          : Text(
              widget.message.text, 
              style: const TextStyle(
                fontSize: 15, 
                height: 1.5, 
                color: Color(0xFF000000),
                fontWeight: FontWeight.w500,
              ),
            ),
    );

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Thoughts panel for bot messages - MOVED ABOVE THE MESSAGE
          if (isBot && widget.message.thoughts.isNotEmpty)
            _ThoughtsPanel(thoughts: widget.message.thoughts),
          if (isBot && widget.message.codes.isNotEmpty)
            _CodePanel(codes: widget.message.codes),
          // Tool results panel removed for cleaner interface
          // Agent processing panel removed – agent output will now stream directly in the chat bubble
          if (isUser)
            GestureDetector(
              onTap: _toggleUserActions,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _showUserActions ? const Color(0xFFEAE9E5).withOpacity(0.3) : Colors.transparent,
                ),
                child: bubbleContent,
              ),
            )
          else if (isBot && canShowActions)
            GestureDetector(
              onTap: _toggleActions,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _showActions ? const Color(0xFFEAE9E5).withOpacity(0.3) : Colors.transparent,
                ),
                child: bubbleContent,
              ),
            )
          else
            bubbleContent,
          // User message actions
          if (isUser && _showUserActions)
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.2, 0),
                end: Offset.zero,
              ).animate(_userActionsAnimation),
              child: FadeTransition(
                opacity: _userActionsAnimation,
                child: Container(
                  margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Copy
                      _ActionButton(
                        icon: Icons.content_copy_rounded,
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: widget.message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '📋 Message copied to clipboard!',
                                style: TextStyle(
                                  color: Color(0xFF000000),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: Colors.white,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                              elevation: 4,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          _toggleUserActions();
                        },
                        tooltip: 'Copy text',
                      ),
                      const SizedBox(width: 8),
                      // Edit & Resend (direct edit without showing menu again)
                      _ActionButton(
                        icon: Icons.edit_rounded,
                        onTap: () {
                          _toggleUserActions();
                          // Direct edit functionality without showing copy/edit menu again
                          final chatPageState = context.findAncestorStateOfType<ChatPageState>();
                          if (chatPageState != null) {
                            chatPageState._editMessage(widget.message);
                          }
                        },
                        tooltip: 'Edit & Resend',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // iOS-style action buttons that slide in for bot messages
          if (canShowActions && _showActions)
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-0.2, 0),
                end: Offset.zero,
              ).animate(_actionsAnimation),
              child: FadeTransition(
                opacity: _actionsAnimation,
                child: Container(
                  margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Thumbs up
                      _ActionButton(
                        icon: Icons.thumb_up_rounded,
                        onTap: () => _giveFeedback(context, true),
                        tooltip: 'Good response',
                      ),
                      const SizedBox(width: 8),
                      // Thumbs down
                      _ActionButton(
                        icon: Icons.thumb_down_rounded,
                        onTap: () => _giveFeedback(context, false),
                        tooltip: 'Bad response',
                      ),
                      const SizedBox(width: 8),
                      // Copy
                      _ActionButton(
                        icon: Icons.content_copy_rounded,
                        onTap: () => _copyMessage(context),
                        tooltip: 'Copy text',
                      ),
                      const SizedBox(width: 8),
                      // Regenerate
                      _ActionButton(
                        icon: Icons.refresh_rounded,
                        onTap: () {
                          widget.onRegenerate?.call();
                          _toggleActions();
                        },
                        tooltip: 'Regenerate',
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  
  const _ActionButton({
    required this.icon, 
    required this.onTap,
    this.tooltip,
  });
  
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.black,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon, 
              color: const Color(0xFF000000), 
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------
   INPUT BAR – Clean Design with Icons Below
---------------------------------------------------------- */
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.awaitingReply,
    required this.isEditing,
    required this.onCancelEdit,
    required this.externalToolsService,
    required this.onImageUpload,
    this.uploadedImagePath,
    required this.onClearImage,
    required this.isImageGenerationMode,
    required this.selectedImageModel,
    required this.availableImageModels,
    required this.onImageModelChanged,
    required this.onCancelImageGeneration,
    required this.isGeneratingImage,
    required this.followUpMode,
    required this.onToggleFollowUp,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool awaitingReply;
  final bool isEditing;
  final VoidCallback onCancelEdit;
  final ExternalToolsService externalToolsService;
  final VoidCallback onImageUpload;
  final String? uploadedImagePath;
  final VoidCallback onClearImage;
  final bool isImageGenerationMode;
  final String selectedImageModel;
  final List<String> availableImageModels;
  final Function(String) onImageModelChanged;
  final VoidCallback onCancelImageGeneration;
  final bool isGeneratingImage;
  final bool followUpMode;
  final VoidCallback onToggleFollowUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F3F0), // Main theme background
      ),
      child: Column(
        children: [
          // Edit mode indicator
          if (isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12, top: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF000000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF000000).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, color: Color(0xFF000000), size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Editing message...", 
                      style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onCancelEdit();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),

          // Image generation mode indicator
          if (isImageGenerationMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12, top: 16),
              decoration: BoxDecoration(
                color: Color(0xFF2D3748).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(0xFF2D3748).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  FaIcon(FontAwesomeIcons.paintBrush, color: Color(0xFF2D3748), size: 16),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Image Generation Mode", 
                      style: TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onCancelImageGeneration();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Color(0xFF2D3748),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),

          // Model selection chips for image generation
          if (isImageGenerationMode)
            Container(
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
              child: Row(
                children: [
                  Text(
                    'Model: ',
                    style: TextStyle(
                      color: Color(0xFF2D3748),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 8),
                                     ...availableImageModels.map((model) => Container(
                     margin: EdgeInsets.only(right: 8),
                     child: GestureDetector(
                       onTap: () {
                         HapticFeedback.lightImpact();
                         onImageModelChanged(model);
                       },
                       child: Container(
                         padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: selectedImageModel == model 
                               ? Color(0xFF2D3748) 
                               : Color(0xFF2D3748).withOpacity(0.1),
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(
                             color: Color(0xFF2D3748).withOpacity(0.3),
                           ),
                         ),
                         child: Text(
                           model.toUpperCase(),
                           style: TextStyle(
                             color: selectedImageModel == model 
                                 ? Colors.white 
                                 : Color(0xFF2D3748),
                             fontWeight: FontWeight.w600,
                             fontSize: 12,
                           ),
                         ),
                       ),
                     ),
                   )).toList(),
                   
                   Spacer(),
                   
                   // Follow-up toggle
                   GestureDetector(
                     onTap: () {
                       HapticFeedback.lightImpact();
                       setState(() => _followUpMode = !_followUpMode);
                     },
                     child: Container(
                       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(
                         color: _followUpMode 
                             ? Color(0xFF2D3748) 
                             : Color(0xFF2D3748).withOpacity(0.1),
                         borderRadius: BorderRadius.circular(16),
                         border: Border.all(
                           color: Color(0xFF2D3748).withOpacity(0.3),
                         ),
                       ),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           FaIcon(
                             FontAwesomeIcons.link,
                             size: 10,
                             color: _followUpMode 
                                 ? Colors.white 
                                 : Color(0xFF2D3748),
                           ),
                           SizedBox(width: 4),
                           Text(
                             'Follow-up',
                             style: TextStyle(
                               color: _followUpMode 
                                   ? Colors.white 
                                   : Color(0xFF2D3748),
                               fontWeight: FontWeight.w600,
                               fontSize: 12,
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                ],
              ),
            ),
          
          // Main input container (smaller height)
          Container(
            margin: EdgeInsets.fromLTRB(20, isEditing ? 0 : 16, 20, 0),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white, // White input background
              borderRadius: BorderRadius.circular(24), // Fully rounded border on both sides
              border: Border.all(
                color: const Color(0xFFEAE9E5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment button (moved to left side)
                if (!awaitingReply && !isImageGenerationMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (uploadedImagePath != null) {
                          onClearImage();
                        } else {
                          onImageUpload();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: uploadedImagePath != null 
                              ? Colors.red.withOpacity(0.1)
                              : const Color(0xFFA3A3A3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          uploadedImagePath != null 
                              ? FontAwesomeIcons.times
                              : FontAwesomeIcons.plus,
                          color: uploadedImagePath != null 
                              ? Colors.red
                              : const Color(0xFFA3A3A3),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                
                // Text input field with reduced height
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !awaitingReply,
                    maxLines: 3, // Reduced from 6
                    minLines: 1, // Reduced from 3
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: const Color(0xFF000000),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 16,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: awaitingReply 
                          ? 'AhamAI is responding...' 
                          : isGeneratingImage
                              ? 'Generating image...'
                              : isImageGenerationMode
                                  ? 'Enter your image prompt...'
                              : externalToolsService.isExecuting
                                  ? 'External tool is running...'
                                  : uploadedImagePath != null
                                      ? 'Image uploaded - Describe or ask about it...'
                                      : 'Message AhamAI',
                      hintStyle: const TextStyle(
                        color: Color(0xFFA3A3A3),
                        fontSize: 16,
                        height: 1.4,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, // Increased padding for better rounded appearance
                        vertical: 12 // Reduced from 18
                      ),
                    ),
                  ),
                ),
                
                // Send/Stop button
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 6), // Adjusted padding
                  child: GestureDetector(
                    onTap: awaitingReply ? onStop : onSend,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10), // Smaller padding
                      decoration: BoxDecoration(
                        color: awaitingReply 
                            ? Colors.red.withOpacity(0.1)
                            : const Color(0xFF000000),
                        borderRadius: BorderRadius.circular(12), // Smaller radius
                      ),
                      child: awaitingReply 
                          ? Icon(Icons.stop_circle, color: Colors.red, size: 18)
                          : isGeneratingImage
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(
                                  isImageGenerationMode 
                                      ? FontAwesomeIcons.magic 
                                      : Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Icons below input bar
          if (!awaitingReply)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image preview removed as requested
                  
                  // Action icons row - removed web search, moved image upload to input field
                  Row(
                    children: [
                      const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4A9B8E),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------
   CODE PANEL - Collapsible panel for code blocks
---------------------------------------------------------- */
class _CodePanel extends StatefulWidget {
  final List<CodeContent> codes;
  
  const _CodePanel({required this.codes});
  
  @override
  State<_CodePanel> createState() => _CodePanelState();
}

class _CodePanelState extends State<_CodePanel> with SingleTickerProviderStateMixin {
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
  
  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '📋 Code copied to clipboard!',
          style: TextStyle(
            color: Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isHtmlCode(String code, String extension) {
    // Check if the code is HTML based on extension or content
    final htmlExtensions = ['html', 'htm', 'xhtml'];
    if (htmlExtensions.contains(extension.toLowerCase())) {
      return true;
    }
    
    // Check if code contains HTML tags
    final htmlTagPattern = RegExp(r'<\s*\/?\s*[a-zA-Z][^>]*>', caseSensitive: false);
    return htmlTagPattern.hasMatch(code);
  }

  void _previewCode(String code, String extension) {
    if (!_isHtmlCode(code, extension)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '👁️ Preview is only available for HTML code',
            style: TextStyle(
              color: Color(0xFF000000),
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.orange.shade100,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          elevation: 4,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _CodePreviewScreen(
          htmlCode: code,
          title: 'HTML Preview',
        ),
      ),
    );
  }
  
  String _getCodePreview() {
    if (widget.codes.isEmpty) return '';
    final firstCode = widget.codes.first;
    final preview = firstCode.code.length > 50 
        ? '${firstCode.code.substring(0, 50)}...'
        : firstCode.code;
    return preview;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F0),
        borderRadius: BorderRadius.circular(12),
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
                    Icons.code_rounded,
                    size: 16,
                    color: const Color(0xFF000000),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isExpanded 
                          ? '${widget.codes.length} Code Block${widget.codes.length > 1 ? 's' : ''}'
                          : _getCodePreview(),
                      style: GoogleFonts.inter(
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
                children: widget.codes.map((codeContent) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE9E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with language and copy button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF000000),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                codeContent.extension.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFFFFFF),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Preview button for HTML code
                            if (_isHtmlCode(codeContent.code, codeContent.extension))
                              IconButton(
                                onPressed: () => _previewCode(codeContent.code, codeContent.extension),
                                icon: const Icon(
                                  Icons.preview_rounded,
                                  size: 16,
                                  color: Color(0xFF000000),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            // Copy button
                            IconButton(
                              onPressed: () => _copyCode(codeContent.code),
                              icon: const Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: Color(0xFF000000),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Code content
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              codeContent.code,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
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
      margin: const EdgeInsets.only(left: 12, top: 8, bottom: 4),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(12),
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA3A3A3),
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
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFFFFF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        thought.text,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF000000),
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

/* ----------------------------------------------------------
   TOOL RESULTS PANEL - Displays external tool execution results
---------------------------------------------------------- */
class _ToolResultsPanel extends StatefulWidget {
  final Map<String, dynamic> toolData;
  
  const _ToolResultsPanel({required this.toolData});
  
  @override
  State<_ToolResultsPanel> createState() => _ToolResultsPanelState();
}

class _ToolResultsPanelState extends State<_ToolResultsPanel> with SingleTickerProviderStateMixin {
  bool _isExpanded = true; // Start expanded for better visibility
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
    // Start expanded
    _animationController.forward();
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
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF000000).withOpacity(0.1)),
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
                    Icons.build_circle_rounded,
                    size: 16,
                    color: const Color(0xFF000000),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tool Results (${widget.toolData.length})',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF000000),
                        fontWeight: FontWeight.w600,
                      ),
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
                children: widget.toolData.entries.map((entry) {
                  final toolName = entry.key;
                  final result = entry.value as Map<String, dynamic>;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE9E5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with tool name and status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: result['success'] == true ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  toolName.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFFFFFF),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                result['success'] == true ? Icons.check_circle : Icons.error,
                                size: 16,
                                color: result['success'] == true ? Colors.green : Colors.red,
                              ),
                              const Spacer(),
                              if (result['execution_time'] != null)
                                Text(
                                  'Executed',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFFA3A3A3),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Tool result content
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              
                              // Result details
                              if ((result['url'] != null) ||
                                  (result['models'] != null) ||
                                  (result['new_model'] != null) ||
                                  (result['api_status'] != null) ||
                                  (result['error'] != null))
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (result['url'] != null)
                                        _buildResultRow('URL', result['url']),
                                      if (result['models'] != null)
                                        _buildResultRow('Models Count', '${(result['models'] as List).length}'),
                                      if (result['new_model'] != null)
                                        _buildResultRow('New Model', result['new_model']),
                                      if (result['api_status'] != null)
                                        _buildResultRow('API Status', result['api_status']),
                                      if (result['error'] != null)
                                        _buildResultRow('Error', result['error'], isError: true),
                                    ],
                                  ),
                                ),

                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
                color: isError ? Colors.red[300] : const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
}

/* ----------------------------------------------------------
   ANIMATED MODE ICON - Reusable component with animated border
---------------------------------------------------------- */
class _AnimatedModeIcon extends StatefulWidget {
  final bool isActive;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AnimatedModeIcon({
    required this.isActive,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_AnimatedModeIcon> createState() => _AnimatedModeIconState();
}

class _AnimatedModeIconState extends State<_AnimatedModeIcon> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clean icon with subtle active state
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isActive 
                          ? const Color(0xFF6366F1).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: FaIcon(
                        widget.icon,
                        color: widget.isActive 
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF6B7280),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isActive 
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ----------------------------------------------------------
   CODE PREVIEW SCREEN - Full screen HTML preview with webview
---------------------------------------------------------- */
class _CodePreviewScreen extends StatefulWidget {
  final String htmlCode;
  final String title;

  const _CodePreviewScreen({
    required this.htmlCode,
    required this.title,
  });

  @override
  State<_CodePreviewScreen> createState() => _CodePreviewScreenState();
}

class _CodePreviewScreenState extends State<_CodePreviewScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      );

    // Load the HTML content with basic styling for better presentation
    final styledHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HTML Preview</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            margin: 20px;
            color: #333;
            background-color: #fff;
        }
        * {
            box-sizing: border-box;
        }
    </style>
</head>
<body>
${widget.htmlCode}
</body>
</html>
    ''';

    _webViewController.loadHtmlString(styledHtml);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
        backgroundColor: const Color(0xFFF4F3F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: Color(0xFF000000),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF000000),
            ),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _initializeWebView();
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF4F3F0),
      body: Stack(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: WebViewWidget(controller: _webViewController),
            ),
          ),
          if (_isLoading)
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF000000)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading HTML Preview...',
                      style: TextStyle(
                        color: Color(0xFFA3A3A3),
                        fontWeight: FontWeight.w500,
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
}