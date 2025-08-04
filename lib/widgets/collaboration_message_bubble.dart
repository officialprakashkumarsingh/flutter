import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/collaboration_models.dart';

class CollaborationMessageBubble extends StatefulWidget {
  final RoomMessage message;
  final VoidCallback? onReply;
  final String? currentUserId;
  final bool isDirectMessage;

  const CollaborationMessageBubble({
    super.key,
    required this.message,
    this.onReply,
    this.currentUserId,
    this.isDirectMessage = false,
  });

  @override
  State<CollaborationMessageBubble> createState() => _CollaborationMessageBubbleState();
}

class _CollaborationMessageBubbleState extends State<CollaborationMessageBubble> 
    with TickerProviderStateMixin {
  bool _showHeartAnimation = false;
  late AnimationController _heartAnimationController;
  late Animation<double> _heartAnimation;

  @override
  void initState() {
    super.initState();
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _heartAnimation = CurvedAnimation(
      parent: _heartAnimationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    super.dispose();
  }

  void _showHeartEffect() {
    setState(() {
      _showHeartAnimation = true;
    });
    _heartAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _showHeartAnimation = false;
          });
          _heartAnimationController.reset();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.userId == widget.currentUserId;
    final isAI = widget.message.messageType == 'ai';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (isUser) const Spacer(flex: 2),
              Flexible(
                flex: 8,
                child: GestureDetector(
                  onDoubleTap: _showHeartEffect,
                  child: isUser ? _buildUserMessage() : _buildBotMessage(),
                ),
              ),
              if (!isUser) const Spacer(flex: 2),
            ],
          ),
          // Heart animation overlay
          if (_showHeartAnimation)
            Positioned.fill(
              child: Center(
                child: ScaleTransition(
                  scale: _heartAnimation,
                  child: const Text(
                    '❤️',
                    style: TextStyle(fontSize: 32),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // User message bubble - exactly like homescreen
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA), // Exact homescreen color
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            widget.message.content,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF374151),
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Timestamp and actions row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              _formatTimestamp(widget.message.createdAt),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _copyToClipboard(widget.message.content);
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBotMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI response - exactly like homescreen (no background, just markdown)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: MarkdownBody(
            data: widget.message.content,
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF374151),
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
              strong: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
              em: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF374151),
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
              h1: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
              h2: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
              h3: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
              code: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                backgroundColor: const Color(0xFFF3F4F6),
                color: const Color(0xFF374151),
              ),
              codeblockDecoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              blockquote: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF6B7280),
                fontStyle: FontStyle.italic,
              ),
              listBullet: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF374151),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Timestamp and actions row
        Row(
          children: [
            Text(
              _formatTimestamp(widget.message.createdAt),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _copyToClipboard(widget.message.content);
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            if (widget.onReply != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onReply?.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const FaIcon(
                    FontAwesomeIcons.reply,
                    size: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h';
    } else {
      return '${diff.inDays}d';
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF374151),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}