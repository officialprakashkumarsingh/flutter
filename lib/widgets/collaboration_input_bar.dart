import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CollaborationInputBar extends StatelessWidget {
  const CollaborationInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.isSending,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F7F4), // Cream background like homescreen
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white, // White input field background like homescreen
          borderRadius: BorderRadius.circular(16), // Same as homescreen
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment button like homescreen
            if (!isSending)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // TODO: Add attachment functionality for rooms
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        FontAwesomeIcons.puzzlePiece,
                        color: Color(0xFF71717A),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Text input field - exactly like homescreen
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isSending,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF09090B),
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: isSending ? 'Sending...' : 'Message...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty && !isSending) {
                    onSend();
                  }
                },
              ),
            ),
            
            // Send button - exactly like homescreen
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isSending 
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isSending ? null : () {
                      HapticFeedback.lightImpact();
                      onSend();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: isSending 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                              ),
                            )
                          : Icon(
                              controller.text.trim().isNotEmpty
                                  ? Icons.arrow_upward_rounded
                                  : Icons.auto_fix_high_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InputPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill with white background
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, size.height), paint);
    
    // Create subtle dot pattern for input area
    final dotPaint = Paint()
      ..color = Colors.grey.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    
    const dotSize = 1.5;
    const spacing = 20.0;
    
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, dotPaint);
        // Add smaller dots for more WhatsApp-like pattern
        if ((x / spacing) % 2 == 0 && (y / spacing) % 2 == 0) {
          canvas.drawCircle(Offset(x + spacing/2, y + spacing/2), dotSize * 0.5, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}