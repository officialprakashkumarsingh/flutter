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
  final bool isLeftAligned;

  const CollaborationMessageBubble({
    super.key,
    required this.message,
    this.onReply,
    this.currentUserId,
    this.isDirectMessage = false,
    this.isLeftAligned = true,
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
            mainAxisAlignment: widget.isLeftAligned ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (!widget.isLeftAligned) const Spacer(flex: 2),
              Flexible(
                flex: 8,
                child: GestureDetector(
                  onDoubleTap: _showHeartEffect,
                  child: _buildMessage(),
                ),
              ),
              if (widget.isLeftAligned) const Spacer(flex: 2),
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

  Widget _buildMessage() {
    final isAI = widget.message.messageType == MessageType.ai;
    final senderName = _getSenderName();
    final avatarLetter = _getAvatarLetter();
    
    return Column(
      crossAxisAlignment: widget.isLeftAligned ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        // Sender info row
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLeftAligned) ...[
                // Avatar circle with first letter
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isAI ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      avatarLetter,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  senderName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ] else ...[
                Text(
                  senderName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 8),
                // Avatar circle with first letter
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isAI ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      avatarLetter,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Message bubble
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAI ? Colors.white : const Color(0xFFF8F9FA), // User messages match homescreen exactly
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isAI 
              ? MarkdownBody(
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
                      height: 1.6,
                    ),
                  ),
                )
              : Text(
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
        
        // Timestamp row (no copy button)
        Row(
          mainAxisAlignment: widget.isLeftAligned ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            Text(
              _formatTimestamp(widget.message.createdAt),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w400,
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
        // AI response - with white background
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, // Clean white for AI messages
            borderRadius: BorderRadius.circular(16),
          ),
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

  String _getSenderName() {
    if (widget.message.messageType == MessageType.ai) {
      return 'AhamAI';
    }
    return widget.message.userName;
  }

  String _getAvatarLetter() {
    final senderName = _getSenderName();
    if (widget.message.messageType == MessageType.ai) {
      return 'AI';
    }
    
    // Try to get first letter of email or name
    if (senderName.isNotEmpty) {
      return senderName[0].toUpperCase();
    }
    return 'U';
  }
}