import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart' as html_widget hide ImageSource;
import 'dart:convert';

import 'models.dart';
import 'file_attachment_widget.dart';
import 'cached_image_widget.dart';
import 'crypto_chart_widget.dart';
import 'chat_page.dart'; // For accessing ChatPageState

/* ----------------------------------------------------------
   MESSAGE BUBBLE & ACTION BUTTONS - iOS Style Interactions
---------------------------------------------------------- */
class MessageBubble extends StatefulWidget {
  final Message message;
  final VoidCallback? onRegenerate;
  final VoidCallback? onUserMessageTap;
  final Function(String)? onSaveImage;
  final Function(Message)? onEditMessage;
  
  const MessageBubble({
    super.key,
    required this.message,
    this.onRegenerate,
    this.onUserMessageTap,
    this.onSaveImage,
    this.onEditMessage,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with TickerProviderStateMixin {
  bool _showActions = false;
  late AnimationController _actionsAnimationController;
  late Animation<double> _actionsAnimation;
  bool _showUserActions = false;
  late AnimationController _userActionsAnimationController;
  late Animation<double> _userActionsAnimation;
  
  // Thinking panel state
  bool _isThinkingExpanded = false;
  late AnimationController _thinkingAnimationController;
  late Animation<double> _thinkingAnimation;
  
  // Code panel state
  Map<int, bool> _codeExpandedStates = {};
  Map<int, AnimationController> _codeAnimationControllers = {};
  Map<int, Animation<double>> _codeAnimations = {};

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
    
    _thinkingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _thinkingAnimation = CurvedAnimation(
      parent: _thinkingAnimationController,
      curve: Curves.easeInOut,
    );
    
    // Initialize code panel controllers
    _initializeCodePanels();
  }
  
  void _initializeCodePanels() {
    final codes = widget.message.codes;
    for (int i = 0; i < codes.length; i++) {
      _codeExpandedStates[i] = false;
      _codeAnimationControllers[i] = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      _codeAnimations[i] = CurvedAnimation(
        parent: _codeAnimationControllers[i]!,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _actionsAnimationController.dispose();
    _userActionsAnimationController.dispose();
    _thinkingAnimationController.dispose();
    _disposeCodeControllers();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize if codes changed
    if (oldWidget.message.codes.length != widget.message.codes.length) {
      _disposeCodeControllers();
      _initializeCodePanels();
    }
  }
  
  void _disposeCodeControllers() {
    for (final controller in _codeAnimationControllers.values) {
      controller.dispose();
    }
    _codeAnimationControllers.clear();
    _codeAnimations.clear();
    _codeExpandedStates.clear();
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

  void _toggleThinking() {
    setState(() {
      _isThinkingExpanded = !_isThinkingExpanded;
      if (_isThinkingExpanded) {
        _thinkingAnimationController.forward();
      } else {
        _thinkingAnimationController.reverse();
      }
    });
  }

  void _toggleCode(int index) {
    setState(() {
      _codeExpandedStates[index] = !(_codeExpandedStates[index] ?? false);
      if (_codeExpandedStates[index]!) {
        _codeAnimationControllers[index]?.forward();
      } else {
        _codeAnimationControllers[index]?.reverse();
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

  Widget _buildImageWidget(String url) {
    // Check if this is a PlantUML diagram URL
    final isDiagram = url.contains('plantuml.com') || 
                     url.contains('kroki.io/plantuml') || 
                     url.contains('planttext.com/api/plantuml');
    
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
          // Use CachedImageWidget for base64 images too with proper fitting
          image = CachedImageWidget(
            imageUrl: url,
            fit: BoxFit.cover,
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
          // Use CachedImageWidget for network images with proper fitting
          image = CachedImageWidget(
            imageUrl: url,
            fit: BoxFit.cover,
          );
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            // DIAGRAM FIX: Remove height constraint for diagrams to show full content
            constraints: isDiagram 
                ? const BoxConstraints(maxWidth: double.infinity) // No height limit for diagrams
                : const BoxConstraints(maxHeight: 300, maxWidth: double.infinity), // Keep limit for other images
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: image,
            ),
          ),
          // Save button for all images (base64 and network)
          if (url.startsWith('data:image') || url.startsWith('http'))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => widget.onSaveImage?.call(url.split('?').first), // Remove query params for saving
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D3748),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.download,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildMarkdownText(String text) {
    return MarkdownBody(
      data: text,
      imageBuilder: (uri, title, alt) {
        return _buildImageWidget(uri.toString());
      },
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
    final hasThoughts = isBot && widget.message.thoughts.isNotEmpty;

    Widget bubbleContent = Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: isBot ? Colors.transparent : const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: isBot
          ? _buildBotMessageWithCodePanels()
          : _buildUserMessageWithAttachments(),
    );

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Thinking panel for bot messages with thoughts
          if (hasThoughts) _buildThinkingPanel(),
          
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
                      ActionButton(
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
                      ActionButton(
                        icon: Icons.edit_rounded,
                        onTap: () {
                          _toggleUserActions();
                          _toggleUserActions();
                          // Use the user message tap for now
                          widget.onUserMessageTap?.call();
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
                      ActionButton(
                        icon: Icons.thumb_up_rounded,
                        onTap: () => _giveFeedback(context, true),
                        tooltip: 'Good response',
                      ),
                      const SizedBox(width: 8),
                      // Thumbs down
                      ActionButton(
                        icon: Icons.thumb_down_rounded,
                        onTap: () => _giveFeedback(context, false),
                        tooltip: 'Bad response',
                      ),
                      const SizedBox(width: 8),
                      // Copy
                      ActionButton(
                        icon: Icons.content_copy_rounded,
                        onTap: () => _copyMessage(context),
                        tooltip: 'Copy text',
                      ),
                      const SizedBox(width: 8),
                      // Regenerate
                      ActionButton(
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

  Widget _buildThinkingPanel() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle
          GestureDetector(
            onTap: _toggleThinking,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    turns: _isThinkingExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Thinking',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          SizeTransition(
            sizeFactor: _thinkingAnimation,
            axisAlignment: -1,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8), // Original light background for header
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.message.thoughts.map((thought) => 
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      thought.text.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBotMessageWithCodePanels() {
    final text = widget.message.text;
    final codes = widget.message.codes;
    
    if (codes.isEmpty) {
      return _buildBotMessageContent(widget.message.displayText);
    }
    
    // Build content by replacing code blocks with panels and showing other content normally
    List<Widget> contentWidgets = [];
    String remainingText = text;
    int codeIndex = 0;
    
    // Find all code block positions in the original text
    for (final code in codes) {
      final pattern = RegExp('```${code.language}\\s*.*?```', dotAll: true);
      final match = pattern.firstMatch(remainingText);
      
      if (match != null) {
        // Add text before the code block
        final beforeText = remainingText.substring(0, match.start).trim();
        if (beforeText.isNotEmpty) {
          contentWidgets.add(_buildMarkdownText(beforeText));
          contentWidgets.add(const SizedBox(height: 8));
        }
        
        // Add the code panel
        contentWidgets.add(_buildCodePanel(code, codeIndex));
        contentWidgets.add(const SizedBox(height: 8));
        
        // Update remaining text
        remainingText = remainingText.substring(match.end).trim();
        codeIndex++;
      }
    }
    
    // Add any remaining text after all code blocks
    if (remainingText.isNotEmpty) {
      contentWidgets.add(_buildMarkdownText(remainingText));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }
  
  Widget _buildUserMessageWithAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Message text
        if (widget.message.text.isNotEmpty)
          Text(
            widget.message.text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF000000),
              fontWeight: FontWeight.w500,
            ),
          ),
        
        // File attachments
        if (widget.message.attachments.isNotEmpty) ...[
          if (widget.message.text.isNotEmpty) const SizedBox(height: 12),
          FileAttachmentWidget(
            attachments: widget.message.attachments,
            isFromUser: true,
          ),
        ],
      ],
    );
  }
  
  Widget _buildCodePanel(CodeContent code, int index) {
    final isExpanded = _codeExpandedStates[index] ?? false;
    final isHtml = code.language.toLowerCase() == 'html';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with language and actions
          GestureDetector(
            onTap: () => _toggleCode(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8), // Original light background for header
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      code.language.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ),
                  // Copy button with FontAwesome icon
                  GestureDetector(
                    onTap: () => _copyCode(code.code),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF404040), width: 1),
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.copy,
                        size: 12,
                        color: Color(0xFFE6E6E6),
                      ),
                    ),
                  ),
                  if (isHtml) ...[
                    const SizedBox(width: 8),
                    // Preview button for HTML with FontAwesome icon
                    GestureDetector(
                      onTap: () => _previewHtml(code.code),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2D2D),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF404040), width: 1),
                        ),
                        child: const FaIcon(
                          FontAwesomeIcons.eye,
                          size: 12,
                          color: Color(0xFFE6E6E6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Expandable code content
          SizeTransition(
            sizeFactor: _codeAnimations[index] ?? const AlwaysStoppedAnimation(0),
            axisAlignment: -1,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1e1e1e),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1), // Keep light border for content
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a), // Dark terminal background
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: HighlightView(
                  code.code,
                  language: code.language,
                  theme: vs2015Theme, // Dark AMOLED theme
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'JetBrains Mono', // Better monospace font
                    height: 1.4,
                    color: Color(0xFFE6E6E6), // Light text on dark background
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Code copied to clipboard!',
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
  }
  
  void _previewHtml(String htmlCode) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HTML Preview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: html_widget.HtmlWidget(
                      htmlCode,
                      enableCaching: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  
  const ActionButton({
    super.key,
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