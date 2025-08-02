import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'models.dart';
import 'file_attachment_widget.dart';

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
  
  // Typing indicator state
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  
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
    
    // Typing indicator animation
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _typingAnimation = CurvedAnimation(
      parent: _typingAnimationController,
      curve: Curves.easeInOut,
    );
    
    // Initialize code panel controllers
    _initializeCodePanels();
  }
  
  void _initializeCodePanels() {
    final codes = widget.message.codes;
    for (int i = 0; i < codes.length; i++) {
      _codeExpandedStates[i] = true; // Default open
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
    _typingAnimationController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: widget.message.sender == Sender.user 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: widget.message.sender == Sender.user 
                ? _buildUserMessage() 
                : _buildBotMessage(),
          ),
        ],
      ),
    );
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
      _codeExpandedStates[index] = !(_codeExpandedStates[index] ?? true); // Default open
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
          // SVG not supported, show placeholder
          image = Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.image, size: 50, color: Colors.grey),
            ),
          );
        } else {
          // Use Network Image for base64 images
          image = Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            ),
          );
        }
      } else {
        if (url.toLowerCase().endsWith('.svg')) {
          // SVG not supported, show placeholder
          image = Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.image, size: 50, color: Colors.grey),
            ),
          );
        } else {
          // Use Network Image for regular images
          image = Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            ),
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

  // Animated sad emoji widget for image errors
  Widget _buildAnimatedSadEmoji() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.8, end: 1.0),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: const Text(
            '😢',
            style: TextStyle(fontSize: 24),
          ),
        );
      },
      onEnd: () {
        // Restart animation after a brief pause
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {});
          }
        });
      },
    );
  }

  Widget _buildUserMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // User message bubble (first)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            widget.message.text,
            style: const TextStyle(color: Colors.black, fontSize: 16),
          ),
        ),
        // File attachments BELOW the message bubble
        if (widget.message.attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          FileAttachmentWidget(
            attachments: widget.message.attachments,
            isFromUser: widget.message.sender == Sender.user,
          ),
        ],
      ],
    );
  }

  Widget _buildBotMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI message content with inline code panels
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: _buildBotMessageWithInlinePanels(),
        ),
        // File attachments below the message (if any)
        if (widget.message.attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          FileAttachmentWidget(
            attachments: widget.message.attachments,
            isFromUser: false,
          ),
        ],
      ],
    );
  }

  // Build message content with inline code panels at correct positions
  Widget _buildBotMessageWithInlinePanels() {
    final widgets = <Widget>[];
    
    // Add thinking panel first if exists
    if (widget.message.thoughts.isNotEmpty) {
      widgets.add(_buildThinkingPanel());
      widgets.add(const SizedBox(height: 12));
    }
    
    final originalText = widget.message.text;
    final displayText = widget.message.displayText; // Text with code blocks removed
    final codes = widget.message.codes;
    final isStreaming = widget.message.isStreaming;
    
    // DEBUG: Print to understand what's happening
    if (codes.isNotEmpty) {
      print('🔍 DEBUG: originalText length: ${originalText.length}');
      print('🔍 DEBUG: displayText length: ${displayText.length}');
      print('🔍 DEBUG: codes count: ${codes.length}');
      print('🔍 DEBUG: isStreaming: $isStreaming');
      for (int i = 0; i < codes.length; i++) {
        print('🔍 DEBUG: Code $i - Language: ${codes[i].language}, Extension: ${codes[i].extension}');
      }
    }
    
    // If no codes yet or still streaming, show original text or typing indicator
    if (codes.isEmpty || isStreaming) {
      if (originalText.isNotEmpty) {
        // Stop typing animation immediately when text starts streaming
        if (_typingAnimationController.isAnimating) {
          _typingAnimationController.stop();
          _typingAnimationController.reset();
        }
        widgets.add(_buildMarkdownContent(originalText));
      } else if (isStreaming) {
        // Show typing indicator when streaming but no text yet
        widgets.add(_buildTypingIndicator());
        if (!_typingAnimationController.isAnimating) {
          _typingAnimationController.repeat();
        }
      }
    } else {
      // Streaming complete - build inline content with code panels at correct positions
      widgets.addAll(_buildInlineContentWithCodePanels(originalText, displayText, codes));
      // Stop typing animation when streaming is complete
      if (_typingAnimationController.isAnimating) {
        _typingAnimationController.stop();
        _typingAnimationController.reset();
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // Build content with code panels inline at their exact positions
  List<Widget> _buildInlineContentWithCodePanels(String originalText, String displayText, List<CodeContent> codes) {
    final widgets = <Widget>[];
    String remainingText = originalText;
    
    for (int i = 0; i < codes.length; i++) {
      final code = codes[i];
      
      // Find the code block pattern in remaining text
      final codePattern = '```${code.language}\n${code.code}\n```';
      final position = remainingText.indexOf(codePattern);
      
      if (position != -1) {
        // Add text before the code block
        final textBefore = remainingText.substring(0, position).trim();
        if (textBefore.isNotEmpty) {
          // Clean the text (remove thinking tags)
          final cleanText = _cleanText(textBefore);
          if (cleanText.isNotEmpty) {
            widgets.add(_buildMarkdownContent(cleanText));
            widgets.add(const SizedBox(height: 12));
          }
        }
        
        // Add the code panel at its exact position
        widgets.add(_buildCodePanel(code, i));
        widgets.add(const SizedBox(height: 12));
        
        // Update remaining text
        remainingText = remainingText.substring(position + codePattern.length);
      }
    }
    
    // Add any remaining text after all code blocks
    if (remainingText.trim().isNotEmpty) {
      final cleanRemainingText = _cleanText(remainingText.trim());
      if (cleanRemainingText.isNotEmpty) {
        widgets.add(_buildMarkdownContent(cleanRemainingText));
      }
    }
    
    return widgets;
  }

  // Clean text by removing thinking tags
  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'<thinking>.*?</thinking>', dotAll: true), '')
        .replaceAll(RegExp(r'<thoughts>.*?</thoughts>', dotAll: true), '')
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .replaceAll(RegExp(r'<thought>.*?</thought>', dotAll: true), '')
        .replaceAll(RegExp(r'<reason>.*?</reason>', dotAll: true), '')
        .replaceAll(RegExp(r'<reasoning>.*?</reasoning>', dotAll: true), '')
        .trim();
  }


    // Build markdown content widget with enhanced styling and image support
  Widget _buildMarkdownContent(String text) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: double.infinity,
      ),
      child: MarkdownBody(
        data: text,
        selectable: true,
        shrinkWrap: true,
        fitContent: true,
        imageBuilder: (uri, title, alt) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              uri.toString(),
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAnimatedSadEmoji(),
                      const SizedBox(height: 12),
                      Text(
                        'Image could not be loaded',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF71717A),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (alt != null && alt!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          alt!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF09090B)),
                    ),
                  ),
                );
              },
            ),
          );
        },
        styleSheet: MarkdownStyleSheet(
          // Text styles
          p: GoogleFonts.inter(
            color: const Color(0xFF09090B), 
            fontSize: 16,
            height: 1.5,
          ),
          strong: GoogleFonts.inter(
            color: const Color(0xFF09090B), 
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          em: GoogleFonts.inter(
            color: const Color(0xFF09090B), 
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
          
          // Headers
          h1: GoogleFonts.inter(
            color: const Color(0xFF09090B),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          h2: GoogleFonts.inter(
            color: const Color(0xFF09090B),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          h3: GoogleFonts.inter(
            color: const Color(0xFF09090B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          
          // Code styling - white background for code blocks
          code: GoogleFonts.jetBrainsMono(
            backgroundColor: const Color(0xFFF4F4F5),
            color: const Color(0xFF1F2937),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          codeblockPadding: const EdgeInsets.all(16),
          
          // Lists
          listBullet: GoogleFonts.inter(
            color: const Color(0xFF09090B),
            fontSize: 16,
          ),
          
          // Blockquotes
          blockquote: GoogleFonts.inter(
            color: const Color(0xFF71717A),
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
          blockquoteDecoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: Color(0xFF3B82F6), width: 4),
            ),
          ),
          blockquotePadding: const EdgeInsets.all(16),
          
          // Links
          a: GoogleFonts.inter(
            color: const Color(0xFF3B82F6),
            fontSize: 16,
            decoration: TextDecoration.underline,
          ),
          
          // Tables
          tableHead: GoogleFonts.inter(
            color: const Color(0xFF09090B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tableBody: GoogleFonts.inter(
            color: const Color(0xFF09090B),
            fontSize: 14,
          ),
          tableBorder: TableBorder.all(
            color: const Color(0xFFE4E4E7),
            width: 1,
          ),
          tableHeadAlign: TextAlign.left,
          tableColumnWidth: const FlexColumnWidth(),
          
          // Horizontal rule
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: const Color(0xFFE4E4E7),
                width: 1,
              ),
            ),
          ),
          
          // Checkbox styling
          checkbox: GoogleFonts.inter(
            color: const Color(0xFF09090B),
            fontSize: 16,
          ),
          
          // Additional spacing
          h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
          h2Padding: const EdgeInsets.only(top: 12, bottom: 6),
          h3Padding: const EdgeInsets.only(top: 8, bottom: 4),
          pPadding: const EdgeInsets.only(bottom: 8),
          listIndent: 16,
        ),
      ),
    );
  }

  // Thinking Panel Widget - Shadcn UI Style
  Widget _buildThinkingPanel() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with toggle
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _toggleThinking,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'AI Thinking Process',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF09090B),
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _isThinkingExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Expandable content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _isThinkingExpanded
                ? Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.message.thoughts.map((thought) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
                          ),
                          child: Text(
                            thought.text,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF52525B),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // Code Panel Widget - Shadcn UI Style
  Widget _buildCodePanel(CodeContent codeContent, int index) {
    final isExpanded = _codeExpandedStates[index] ?? true; // Default open
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF09090B), // Shadcn dark background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with language and copy button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _toggleCode(index),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Language badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        codeContent.language.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    
                    // Copy button
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _copyCode(codeContent.code),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3F3F46),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: Color(0xFFA1A1AA),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Expand/Collapse button
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Color(0xFFA1A1AA),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Code content with animation
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: isExpanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: HighlightView(
                      codeContent.code,
                      language: codeContent.language,
                      theme: vs2015Theme, // Dark theme for black background
                      padding: const EdgeInsets.all(12),
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _copyCode(String code) {
    HapticFeedback.lightImpact();
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

  // Build smooth typing indicator with three dots animation
  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(0),
          const SizedBox(width: 4),
          _buildDot(1),
          const SizedBox(width: 4),
          _buildDot(2),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final animationValue = _typingAnimationController.value * 3;
        final dotValue = (animationValue - index).clamp(0.0, 1.0);
        final opacity = (math.sin(dotValue * math.pi) * 0.7 + 0.3).clamp(0.3, 1.0);
        final scale = (math.sin(dotValue * math.pi) * 0.3 + 0.7).clamp(0.7, 1.0);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF71717A).withOpacity(opacity),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }


}
