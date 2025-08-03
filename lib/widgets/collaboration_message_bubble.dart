import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/collaboration_models.dart';

class CollaborationMessageBubble extends StatefulWidget {
  final RoomMessage message;
  final bool isOwnMessage;
  final Function(RoomMessage)? onReply;

  const CollaborationMessageBubble({
    super.key,
    required this.message,
    required this.isOwnMessage,
    this.onReply,
  });

  @override
  State<CollaborationMessageBubble> createState() => _CollaborationMessageBubbleState();
}

class _CollaborationMessageBubbleState extends State<CollaborationMessageBubble> with TickerProviderStateMixin {
  bool _showActions = false;
  late AnimationController _actionsAnimationController;
  late Animation<double> _actionsAnimation;
  
  // Slide to reply variables
  double _slideOffset = 0.0;
  bool _isSliding = false;
  
  // Heart animation variables
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  bool _showHeart = false;

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
    
    // Heart animation setup
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _heartScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: Curves.elasticOut,
    ));
    _heartOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _actionsAnimationController.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Special layout for system messages
    if (widget.message.messageType == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9).withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.message.content,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    
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
      onDoubleTap: () {
        _showHeartAnimation();
      },
      onHorizontalDragStart: widget.onReply != null && widget.message.messageType != 'system' 
          ? (_) {
              setState(() {
                _isSliding = true;
                _slideOffset = 0.0;
              });
            }
          : null,
      onHorizontalDragUpdate: widget.onReply != null && widget.message.messageType != 'system'
          ? (details) {
              if (_isSliding) {
                setState(() {
                  // Only allow sliding to the left
                  final newOffset = _slideOffset + details.delta.dx;
                  _slideOffset = newOffset.clamp(-80.0, 0.0);
                });
              }
            }
          : null,
      onHorizontalDragEnd: widget.onReply != null && widget.message.messageType != 'system'
          ? (_) {
              if (_isSliding) {
                // Trigger reply if slid enough
                if (_slideOffset <= -40.0) {
                  widget.onReply!(widget.message);
                  HapticFeedback.mediumImpact();
                }
                
                // Reset slide offset with animation
                setState(() {
                  _isSliding = false;
                  _slideOffset = 0.0;
                });
              }
            }
          : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: _isSliding ? 0 : 200),
        transform: Matrix4.translationValues(_slideOffset, 0, 0),
        child: Stack(
          children: [
            // Reply icon that appears when sliding
            if (_slideOffset < -10.0)
              Positioned(
                right: 60, // More space from bubble
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: (-_slideOffset / 60.0).clamp(0.0, 1.0), // Smoother fade-in
                    duration: const Duration(milliseconds: 100),
                    child: AnimatedScale(
                      scale: (-_slideOffset / 60.0).clamp(0.5, 1.0), // Scale animation
                      duration: const Duration(milliseconds: 100),
                                              child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withOpacity(0.12),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366).withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.reply_rounded,
                              size: 18,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ),
                    ),
                  ),
                ),
              ),
            
            // Message content with heart overlay
            Stack(
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: _buildMessageBubble(),
                ),
                
                // Heart animation overlay
                if (_showHeart)
                  Positioned.fill(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _heartAnimationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _heartScaleAnimation.value,
                            child: Opacity(
                              opacity: _heartOpacityAnimation.value,
                              child: const FaIcon(
                                FontAwesomeIcons.solidHeart,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAvatar() {
    if (widget.message.messageType == 'system') {
      return const SizedBox.shrink(); // No avatar for system messages
    }

    Color backgroundColor;
    Widget avatarChild;

    switch (widget.message.messageType) {
      case 'ai':
        backgroundColor = const Color(0xFF7C3AED); // Purple for AI
        avatarChild = const FaIcon(
          FontAwesomeIcons.robot,
          size: 8,
          color: Colors.white,
        );
        break;
      default:
        // Generate color based on username for consistency
        final colorIndex = widget.message.userName.hashCode % 8;
        final colors = [
          const Color(0xFF34C759), // Green
          const Color(0xFFFF9500), // Orange  
          const Color(0xFF5856D6), // Purple
          const Color(0xFFFF2D92), // Pink
          const Color(0xFF32D74B), // Light Green
          const Color(0xFFFF6482), // Coral
          const Color(0xFF64D2FF), // Light Blue
          const Color(0xFFBF5AF2), // Light Purple
        ];
        
        backgroundColor = colors[colorIndex];
        
        // Use first character of userName
        String displayChar = widget.message.userName.isNotEmpty 
            ? widget.message.userName[0].toUpperCase()
            : '?';
        
        avatarChild = Text(
          displayChar,
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        );
        break;
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(child: avatarChild),
    );
  }

  Widget _buildAvatar() {
    if (widget.message.messageType == 'system') {
      return const SizedBox.shrink(); // No avatar for system messages
    }

    Color backgroundColor;
    Widget avatarChild;

    switch (widget.message.messageType) {
      case 'ai':
        backgroundColor = CupertinoColors.systemBlue;
        avatarChild = const FaIcon(
          FontAwesomeIcons.robot,
          size: 12,
          color: Colors.white,
        );
        break;
      default:
        // Generate color based on username for consistency
        final colorIndex = widget.message.userName.hashCode % 8;
        final colors = [
          const Color(0xFF34C759), // Green
          const Color(0xFFFF9500), // Orange  
          const Color(0xFF5856D6), // Purple
          const Color(0xFFFF2D92), // Pink
          const Color(0xFF32D74B), // Light Green
          const Color(0xFFFF6482), // Coral
          const Color(0xFF64D2FF), // Light Blue
          const Color(0xFFBF5AF2), // Light Purple
        ];
        
        backgroundColor = colors[colorIndex];
        
        // Use first character of userName (which often comes from email)
        final firstChar = widget.message.userName.isNotEmpty 
            ? widget.message.userName[0].toUpperCase()
            : '?';
        
        avatarChild = Text(
          firstChar,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        );
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: avatarChild,
      ),
    );
  }

  Widget _buildMessageBubble() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMessageHeader(),
        _buildMessageContent(),
      ],
    );
  }

  Widget _buildMessageHeader() {
    if (widget.message.messageType == 'system') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar BEFORE name (as requested)
          _buildCompactAvatar(),
          const SizedBox(width: 6),
          Text(
            widget.message.messageType == 'ai' ? 'AhamAI' : widget.message.userName,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.message.messageType == 'ai'
                  ? const Color(0xFF7C3AED) // Purple for AI
                  : const Color(0xFF09090B), // Dark for users
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatTime(widget.message.createdAt),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF71717A), // Gray for all timestamps
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: _buildMarkdownContent(), // Use markdown for all messages
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
        return Colors.transparent; // Transparent for AI messages
      case 'system':
        return const Color(0xFFF1F5F9).withOpacity(0.7); // Light gray for system
      default:
        return Colors.transparent; // Transparent for all messages - no bubble backgrounds
    }
  }
  
  Color _getUserBubbleColor() {
    // Generate different colors for different users based on their username
    final colors = [
      const Color(0xFF34C759), // Green
      const Color(0xFFFF9500), // Orange  
      const Color(0xFF5856D6), // Purple
      const Color(0xFFFF2D92), // Pink
      const Color(0xFF32D74B), // Light Green
      const Color(0xFFFF6482), // Coral (replacing yellow)
      const Color(0xFF64D2FF), // Light Blue
      const Color(0xFFBF5AF2), // Light Purple
    ];
    
    final hash = widget.message.userName.hashCode;
    return colors[hash.abs() % colors.length];
  }

  BorderRadius _getBubbleBorderRadius() {
    const radius = Radius.circular(18);
    const smallRadius = Radius.circular(6);

    if (widget.message.messageType == 'system') {
      return BorderRadius.circular(12);
    }

    if (widget.message.messageType == 'ai') {
      return BorderRadius.circular(16);
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
        return const Color(0xFF09090B); // Dark text for transparent AI bubble
      case 'system':
        return const Color(0xFF71717A); // Subtle gray for system
      default:
        return const Color(0xFF09090B); // Dark text for all transparent messages
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

  void _showHeartAnimation() {
    setState(() {
      _showHeart = true;
    });
    
    _heartAnimationController.reset();
    _heartAnimationController.forward().then((_) {
      setState(() {
        _showHeart = false;
      });
    });
    
    // Add haptic feedback for better UX
    HapticFeedback.lightImpact();
  }
}