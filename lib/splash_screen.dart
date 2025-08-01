import 'package:flutter/material.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _robotController;
  late AnimationController _textController;
  late AnimationController _fadeController;
  
  late Animation<double> _robotFloatAnimation;
  late Animation<double> _robotRotateAnimation;
  late Animation<Offset> _robotSlideAnimation;
  late Animation<double> _textScaleAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Robot animation controller
    _robotController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Fade out controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Robot floating animation
    _robotFloatAnimation = Tween<double>(
      begin: -20.0,
      end: 20.0,
    ).animate(CurvedAnimation(
      parent: _robotController,
      curve: Curves.easeInOut,
    ));
    
    // Robot rotation animation
    _robotRotateAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _robotController,
      curve: Curves.easeInOut,
    ));
    
    // Robot slide in animation
    _robotSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _robotController,
      curve: Curves.elasticOut,
    ));
    
    // Text scale animation
    _textScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.elasticOut,
    ));
    
    // Text opacity animation
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    ));
    
    // Fade out animation
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _startAnimations();
  }
  
  void _startAnimations() async {
    // Start robot animation (repeating)
    _robotController.repeat(reverse: true);
    
    // Delay and start text animation
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();
    
    // Wait for animations to complete, then fade out
    await Future.delayed(const Duration(seconds: 3));
    _fadeController.forward();
    
    // Complete splash after fade
    await Future.delayed(const Duration(milliseconds: 800));
    widget.onComplete();
  }

  @override
  void dispose() {
    _robotController.dispose();
    _textController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F0), // App's background color
      body: AnimatedBuilder(
        animation: Listenable.merge([_robotController, _textController, _fadeController]),
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Robot
                  SlideTransition(
                    position: _robotSlideAnimation,
                    child: Transform.translate(
                      offset: Offset(0, _robotFloatAnimation.value),
                      child: Transform.rotate(
                        angle: _robotRotateAnimation.value,
                        child: _buildRobot(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // AhamAI Banner
                  Transform.scale(
                    scale: _textScaleAnimation.value,
                    child: Opacity(
                      opacity: _textOpacityAnimation.value,
                      child: _buildAhamAIBanner(),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Subtitle
                  Transform.scale(
                    scale: _textScaleAnimation.value * 0.8,
                    child: Opacity(
                      opacity: _textOpacityAnimation.value * 0.7,
                      child: Text(
                        'Intelligent AI Assistant',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFFA3A3A3),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.2,
                        ),
                      ),
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
  
  Widget _buildRobot() {
    return Container(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: RobotPainter(),
      ),
    );
  }
  
  Widget _buildAhamAIBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAE9E5), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AI Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // AhamAI Text
          Text(
            'AhamAI',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF000000),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class RobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 3;
    
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF000000);
    
    final center = Offset(size.width / 2, size.height / 2);
    
    // Robot Body (rounded rectangle)
    paint.color = Colors.white;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, 10), width: 50, height: 60),
      const Radius.circular(12),
    );
    canvas.drawRRect(bodyRect, paint);
    canvas.drawRRect(bodyRect, strokePaint);
    
    // Robot Head (circle)
    paint.color = Colors.white;
    canvas.drawCircle(center.translate(0, -20), 25, paint);
    canvas.drawCircle(center.translate(0, -20), 25, strokePaint);
    
    // Eyes
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(-8, -24), 4, paint);
    canvas.drawCircle(center.translate(8, -24), 4, paint);
    
    // Eye glow effect
    paint.color = const Color(0xFF000000).withOpacity(0.3);
    canvas.drawCircle(center.translate(-8, -24), 6, paint);
    canvas.drawCircle(center.translate(8, -24), 6, paint);
    
    // Mouth (small arc)
    strokePaint.strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, -12), width: 12, height: 8),
      0,
      math.pi,
      false,
      strokePaint,
    );
    
    // Antenna
    strokePaint.strokeWidth = 2;
    canvas.drawLine(
      center.translate(0, -45),
      center.translate(0, -55),
      strokePaint,
    );
    
    // Antenna tip
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(0, -55), 3, paint);
    
    // Arms
    strokePaint.strokeWidth = 3;
    strokePaint.strokeCap = StrokeCap.round;
    
    // Left arm
    canvas.drawLine(
      center.translate(-25, 0),
      center.translate(-40, -10),
      strokePaint,
    );
    
    // Right arm
    canvas.drawLine(
      center.translate(25, 0),
      center.translate(40, -10),
      strokePaint,
    );
    
    // Legs
    canvas.drawLine(
      center.translate(-12, 40),
      center.translate(-12, 55),
      strokePaint,
    );
    
    canvas.drawLine(
      center.translate(12, 40),
      center.translate(12, 55),
      strokePaint,
    );
    
    // Feet
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(-12, 58), 4, paint);
    canvas.drawCircle(center.translate(12, 58), 4, paint);
    
    // Body details (chest panel)
    strokePaint.strokeWidth = 1;
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, 5), width: 20, height: 25),
      const Radius.circular(4),
    );
    canvas.drawRRect(panelRect, strokePaint);
    
    // Chest buttons
    paint.color = const Color(0xFFA3A3A3);
    canvas.drawCircle(center.translate(-5, 0), 2, paint);
    canvas.drawCircle(center.translate(5, 0), 2, paint);
    canvas.drawCircle(center.translate(0, 8), 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}