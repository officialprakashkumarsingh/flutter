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

  Widget _buildUserMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // User message bubble (first)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEAE9E5),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                decoration: null, // Transparent background for AI messages
                padding: const EdgeInsets.all(16),
                child: _buildBotMessageWithInlinePanels(),
              ),
            ),
          ],
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

  // Build message content with inline code panels
  Widget _buildBotMessageWithInlinePanels() {
    final widgets = <Widget>[];
    
    // Add thinking panel first if exists
    if (widget.message.thoughts.isNotEmpty) {
      widgets.add(_buildThinkingPanel());
      widgets.add(const SizedBox(height: 12));
    }
    
    // Parse the original text to find where code blocks appear
    String remainingText = widget.message.text;
    final codes = widget.message.codes;
    
    // If no code blocks, just show the display text
    if (codes.isEmpty) {
      widgets.add(_buildMarkdownContent(widget.message.displayText));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }
    
    // Build content with inline code panels
    int codeIndex = 0;
    for (final code in codes) {
      // Find the code block in the original text
      final codePattern = '```${code.language}\n${code.code}\n```';
      final codePosition = remainingText.indexOf(codePattern);
      
      if (codePosition != -1) {
        // Add text before the code block
        final textBefore = remainingText.substring(0, codePosition).trim();
        if (textBefore.isNotEmpty) {
          widgets.add(_buildMarkdownContent(textBefore));
          widgets.add(const SizedBox(height: 12));
        }
        
        // Add the code panel right where the code appears
        widgets.add(_buildCodePanel(code, codeIndex));
        widgets.add(const SizedBox(height: 12));
        
        // Update remaining text
        remainingText = remainingText.substring(codePosition + codePattern.length);
        codeIndex++;
      }
    }
    
    // Add any remaining text after all code blocks
    if (remainingText.trim().isNotEmpty) {
      widgets.add(_buildMarkdownContent(remainingText.trim()));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // Build markdown content widget
  Widget _buildMarkdownContent(String text) {
    return Container(
      width: double.infinity,
      child: MarkdownBody(
        data: text,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(color: Colors.black, fontSize: 16),
          strong: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          em: const TextStyle(color: Colors.black, fontStyle: FontStyle.italic),
          code: TextStyle(
            backgroundColor: Colors.grey[800],
            color: Colors.green,
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          blockquoteDecoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(4),
            border: Border(left: BorderSide(color: Colors.blue, width: 4)),
          ),
        ),
      ),
    );
  }

  // Thinking Panel Widget
  Widget _buildThinkingPanel() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA), // Light background for thinking
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
      ),
      child: Column(
        children: [
          // Header with toggle
          GestureDetector(
                         onTap: _toggleThinking,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.brain,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Thinking Process',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isThinkingExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: FaIcon(
                      FontAwesomeIcons.chevronDown,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
                          ),
                          child: Text(
                            thought.text,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                              height: 1.4,
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

  // Code Panel Widget with Clean Styling (like thinking panel)
  Widget _buildCodePanel(CodeContent codeContent, int index) {
    final isExpanded = _codeExpandedStates[index] ?? false;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black, // Single AMOLED Black background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        children: [
          // Header with language, copy, and preview buttons (no separate background)
          GestureDetector(
            onTap: () => _toggleCode(index),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Language badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      codeContent.language.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  
                  // Copy button
                  GestureDetector(
                    onTap: () => _copyCode(codeContent.code),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[800], // Subtle gray for contrast
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.copy,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Preview button (for HTML/CSS/JS)
                  if (_isWebCode(codeContent.language)) ...[
                    GestureDetector(
                      onTap: () => _previewWebCode(codeContent, index),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[800], // Subtle gray for contrast
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const FaIcon(
                          FontAwesomeIcons.eye,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  
                  // Expand/Collapse button
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const FaIcon(
                      FontAwesomeIcons.chevronDown,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
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

  // Check if code is web-related (HTML, CSS, JS)
  bool _isWebCode(String language) {
    return ['html', 'css', 'javascript', 'js'].contains(language.toLowerCase());
  }

  // Enhanced web code preview that combines HTML/CSS/JS
  void _previewWebCode(CodeContent currentCode, int index) {
    // Collect all web-related code blocks from the message
    String htmlContent = '';
    String cssContent = '';
    String jsContent = '';
    
    // Get all code blocks from the message
    for (final code in widget.message.codes) {
      final lang = code.language.toLowerCase();
      if (lang == 'html') {
        htmlContent += code.code + '\n';
      } else if (lang == 'css') {
        cssContent += code.code + '\n';
      } else if (lang == 'javascript' || lang == 'js') {
        jsContent += code.code + '\n';
      }
    }
    
    // If current code is one of the web languages and not found in loop, use current
    final currentLang = currentCode.language.toLowerCase();
    if (currentLang == 'html' && htmlContent.isEmpty) {
      htmlContent = currentCode.code;
    } else if (currentLang == 'css' && cssContent.isEmpty) {
      cssContent = currentCode.code;
    } else if ((currentLang == 'javascript' || currentLang == 'js') && jsContent.isEmpty) {
      jsContent = currentCode.code;
    }
    
    // Create combined HTML file
    String combinedHtml = htmlContent;
    
    // If no HTML but we have CSS/JS, create a basic HTML structure
    if (combinedHtml.isEmpty && (cssContent.isNotEmpty || jsContent.isNotEmpty)) {
      combinedHtml = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Preview</title>
</head>
<body>
    <h1>CSS/JS Preview</h1>
    <p>This preview contains the CSS and JavaScript code blocks.</p>
</body>
</html>''';
    }
    
    // Add CSS if present
    if (cssContent.isNotEmpty) {
      if (combinedHtml.contains('</head>')) {
        combinedHtml = combinedHtml.replaceFirst(
          '</head>',
          '    <style>\n$cssContent\n    </style>\n</head>'
        );
      } else {
        // If no head tag, add style at the beginning
        combinedHtml = '<style>\n$cssContent\n</style>\n$combinedHtml';
      }
    }
    
    // Add JavaScript if present
    if (jsContent.isNotEmpty) {
      if (combinedHtml.contains('</body>')) {
        combinedHtml = combinedHtml.replaceFirst(
          '</body>',
          '    <script>\n$jsContent\n    </script>\n</body>'
        );
      } else {
        // If no body tag, add script at the end
        combinedHtml = '$combinedHtml\n<script>\n$jsContent\n</script>';
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Web Preview (${currentCode.language.toUpperCase()})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                child: html_widget.HtmlWidget(
                  combinedHtml,
                  onTapUrl: (url) {
                    return false; // Don't handle URL taps in preview
                  },
                ),
              ),
            ],
          ),
        ),
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


}
