import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/collaboration_models.dart';

class CollaborationMessageBubble extends StatefulWidget {
  final RoomMessage message;
  final bool isOwnMessage;

  const CollaborationMessageBubble({
    super.key,
    required this.message,
    required this.isOwnMessage,
  });

  @override
  State<CollaborationMessageBubble> createState() => _CollaborationMessageBubbleState();
}

class _CollaborationMessageBubbleState extends State<CollaborationMessageBubble> with TickerProviderStateMixin {
  bool _showActions = false;
  late AnimationController _actionsAnimationController;
  late Animation<double> _actionsAnimation;

  @override
  void initState() {
    super.initState();
    _actionsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _actionsAnimation = CurvedAnimation(
      parent: _actionsAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _actionsAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
      child: Column(
        crossAxisAlignment: widget.isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _buildMessageContainer(),
          if (_showActions) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildMessageContainer() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showActions = !_showActions;
          if (_showActions) {
            _actionsAnimationController.forward();
          } else {
            _actionsAnimationController.reverse();
          }
        });
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.isOwnMessage ? [
            _buildMessageBubble(),
            const SizedBox(width: 8),
            _buildAvatar(),
          ] : [
            _buildAvatar(),
            const SizedBox(width: 8),
            _buildMessageBubble(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (widget.message.messageType == 'system') {
      return const SizedBox.shrink(); // No avatar for system messages
    }

    IconData avatarIcon;
    Color avatarColor;
    Color backgroundColor;

    switch (widget.message.messageType) {
      case 'ai':
        avatarIcon = FontAwesomeIcons.robot;
        avatarColor = const Color(0xFF25D366); // WhatsApp green
        backgroundColor = const Color(0xFFF0F9FF);
        break;
      default:
        // Generate color based on username for consistency
        final colorIndex = widget.message.userName.hashCode % 6;
        final colors = [
          const Color(0xFF3B82F6), // Blue
          const Color(0xFF10B981), // Green  
          const Color(0xFF8B5CF6), // Purple
          const Color(0xFFF59E0B), // Orange
          const Color(0xFFEF4444), // Red
          const Color(0xFF06B6D4), // Cyan
        ];
        
        avatarIcon = FontAwesomeIcons.user;
        avatarColor = Colors.white;
        backgroundColor = colors[colorIndex];
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: FaIcon(
          avatarIcon,
          size: 12,
          color: avatarColor,
        ),
      ),
    );
  }

  Widget _buildMessageBubble() {
    return Flexible(
      child: Container(
        decoration: BoxDecoration(
          color: _getBubbleColor(),
          borderRadius: _getBubbleBorderRadius(),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageHeader(),
            _buildMessageContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageHeader() {
    if (widget.message.messageType == 'system') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
                     Text(
             widget.message.userName,
             style: GoogleFonts.inter(
               fontSize: 12,
               fontWeight: FontWeight.w600,
               color: widget.message.messageType == 'ai'
                   ? const Color(0xFF25D366) // Green for AI
                   : const Color(0xFF1F2937), // Dark gray for users
             ),
           ),
           const SizedBox(width: 6),
           Text(
             _formatTime(widget.message.createdAt),
             style: GoogleFonts.inter(
               fontSize: 11,
               color: const Color(0xFF6B7280), // Gray for timestamp
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12, 
        widget.message.messageType == 'system' ? 8 : 0, 
        12, 
        8
      ),
      child: widget.message.messageType == 'ai' 
          ? _buildMarkdownContent()
          : _buildTextContent(),
    );
  }

  Widget _buildTextContent() {
    return Text(
      widget.message.content,
      style: GoogleFonts.inter(
        fontSize: 14,
        height: 1.4,
        color: _getTextColor(),
        fontWeight: widget.message.messageType == 'system' 
            ? FontWeight.w500 
            : FontWeight.w400,
      ),
    );
  }

  Widget _buildMarkdownContent() {
    return MarkdownBody(
      data: widget.message.content,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.inter(
          fontSize: 14,
          height: 1.4,
          color: const Color(0xFF09090B),
        ),
        code: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          backgroundColor: const Color(0xFFF1F5F9),
          color: const Color(0xFF1E293B),
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E4E7)),
        ),
        codeblockPadding: const EdgeInsets.all(12),
      ),
      selectable: true,
    );
  }

  Widget _buildActionButtons() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        child: FadeTransition(
          opacity: _actionsAnimation,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                icon: FontAwesomeIcons.copy,
                onTap: _copyMessage,
                tooltip: 'Copy message',
              ),
              if (widget.message.messageType == 'ai') ...[
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: FontAwesomeIcons.thumbsUp,
                  onTap: () => _showSnackBar('Response noted!'),
                  tooltip: 'Good response',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: FaIcon(
              icon,
              size: 12,
              color: const Color(0xFF71717A),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBubbleColor() {
    switch (widget.message.messageType) {
      case 'ai':
        return const Color(0xFFF0F9FF); // Light blue for AI
      case 'system':
        return const Color(0xFFFEF3C7); // Light yellow for system
      default:
        return widget.isOwnMessage 
            ? const Color(0xFFDCF8C6) // WhatsApp green for own messages
            : Colors.white; // White for others
    }
  }

  BorderRadius _getBubbleBorderRadius() {
    const radius = Radius.circular(12);
    const smallRadius = Radius.circular(4);

    if (widget.message.messageType == 'system') {
      return BorderRadius.circular(8);
    }

    return widget.isOwnMessage
        ? const BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: radius,
            bottomRight: smallRadius,
          )
        : const BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: smallRadius,
            bottomRight: radius,
          );
  }

  Color _getTextColor() {
    switch (widget.message.messageType) {
      case 'ai':
        return const Color(0xFF1F2937); // Dark gray for AI
      case 'system':
        return const Color(0xFF92400E); // Amber dark for system
      default:
        return const Color(0xFF1F2937); // Dark gray for all messages
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  void _copyMessage() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    _showSnackBar('Message copied');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}