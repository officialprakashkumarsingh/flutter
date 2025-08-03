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
    return CustomPaint(
      painter: InputPatternPainter(),
      child: Container(
        padding: const EdgeInsets.only(bottom: 16),
        decoration: const BoxDecoration(
          color: Colors.transparent, // Transparent to show pattern
        ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white, // White background only for typing area
          borderRadius: BorderRadius.circular(12), // Shadcn style rounded corners
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text input field
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isSending,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: const Color(0xFF000000),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(
                  color: Color(0xFF09090B),
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: isSending 
                      ? 'Sending message...' 
                      : 'Message the team...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            
            // Send button
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 6),
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
                      padding: const EdgeInsets.all(10),
                      child: isSending 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                              ),
                            )
                          : const FaIcon(
                              FontAwesomeIcons.arrowUp,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
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

class InputPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill with white background
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
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