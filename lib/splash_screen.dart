import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late AnimationController _playController;
  late AnimationController _fadeController;
  
  late Animation<double> _robotFloatAnimation;
  late Animation<double> _robotRotateAnimation;
  late Animation<Offset> _robotSlideAnimation;
  late Animation<double> _textScaleAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _robotPlayAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Robot animation controller (floating)
    _robotController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Robot play animation (circling around text)
    _playController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    
    // Fade out controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Robot floating animation
    _robotFloatAnimation = Tween<double>(
      begin: -15.0,
      end: 15.0,
    ).animate(CurvedAnimation(
      parent: _robotController,
      curve: Curves.easeInOut,
    ));
    
    // Robot rotation animation
    _robotRotateAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(
      parent: _robotController,
      curve: Curves.easeInOut,
    ));
    
    // Robot slide in animation
    _robotSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.2, 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _robotController,
      curve: Curves.elasticOut,
    ));
    
    // Robot play animation (moves around the text)
    _robotPlayAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _playController,
      curve: Curves.easeInOut,
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
      curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
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
    // Start robot floating animation (repeating)
    _robotController.repeat(reverse: true);
    
    // Start text animation FIRST
    await Future.delayed(const Duration(milliseconds: 300));
    _textController.forward();
    
    // Start robot playing around text after text appears
    await Future.delayed(const Duration(milliseconds: 800));
    _playController.forward();
    
    // Wait for play animation, then fade out
    await Future.delayed(const Duration(seconds: 2));
    _fadeController.forward();
    
    // Complete splash after fade
    await Future.delayed(const Duration(milliseconds: 800));
    widget.onComplete();
  }

  @override
  void dispose() {
    _robotController.dispose();
    _textController.dispose();
    _playController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF4F3F0),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F3F0), // App's background color
        body: AnimatedBuilder(
          animation: Listenable.merge([
            _robotController, 
            _textController,
            _playController,
            _fadeController
          ]),
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // AhamAI Text (appears first, stays in center)
                    Transform.scale(
                      scale: _textScaleAnimation.value,
                      child: Opacity(
                        opacity: _textOpacityAnimation.value,
                        child: Text(
                          'AhamAI',
                          style: GoogleFonts.spaceMono(
                            fontSize: 42,
                            color: const Color(0xFF000000),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                    
                    // Robot playing around the text (above it)
                    _buildPlayingRobot(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildPlayingRobot() {
    // Calculate robot position around the text (circular motion, above the text)
    final radius = 100.0; // Larger radius to avoid touching text
    final angle = _robotPlayAnimation.value;
    final x = radius * math.cos(angle);
    final y = (radius * math.sin(angle)) - 20; // Offset upward to play above text
    
    return Transform.translate(
      offset: Offset(x, y),
      child: SlideTransition(
        position: _robotSlideAnimation,
        child: Transform.translate(
          offset: Offset(0, _robotFloatAnimation.value),
          child: Transform.rotate(
            angle: _robotRotateAnimation.value,
            child: Transform.scale(
              scale: 0.7, // Smaller robot to avoid touching text
              child: _buildRobot(),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRobot() {
    return Container(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: RobotPainter(),
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
      Rect.fromCenter(center: center.translate(0, 8), width: 40, height: 50),
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRect, paint);
    canvas.drawRRect(bodyRect, strokePaint);
    
    // Robot Head (circle)
    paint.color = Colors.white;
    canvas.drawCircle(center.translate(0, -18), 20, paint);
    canvas.drawCircle(center.translate(0, -18), 20, strokePaint);
    
    // Eyes (normal happy eyes)
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(-6, -20), 3, paint);
    canvas.drawCircle(center.translate(6, -20), 3, paint);
    
    // Eye sparkles (playful effect)
    paint.color = Colors.white;
    canvas.drawCircle(center.translate(-5, -21), 1, paint);
    canvas.drawCircle(center.translate(7, -21), 1, paint);
    
    // Happy mouth (normal smile)
    strokePaint.strokeWidth = 2;
    strokePaint.strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, -12), width: 12, height: 8),
      0,
      math.pi,
      false,
      strokePaint,
    );
    
    // Antenna with flag pole
    strokePaint.strokeWidth = 2;
    canvas.drawLine(
      center.translate(0, -38),
      center.translate(0, -55), // Taller for flag
      strokePaint,
    );
    
    // Indian Flag (real flag design) 🇮🇳
    final flagWidth = 16.0;
    final flagHeight = 12.0;
    final flagLeft = center.translate(-flagWidth/2, -55);
    
    // Flag pole attachment
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(-flagWidth/2, -55), 1, paint);
    
    // Saffron stripe (top)
    paint.color = const Color(0xFFFF9933);
    canvas.drawRect(
      Rect.fromLTWH(flagLeft.dx, flagLeft.dy, flagWidth, flagHeight/3),
      paint,
    );
    
    // White stripe (middle)
    paint.color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(flagLeft.dx, flagLeft.dy + flagHeight/3, flagWidth, flagHeight/3),
      paint,
    );
    
    // Green stripe (bottom)
    paint.color = const Color(0xFF138808);
    canvas.drawRect(
      Rect.fromLTWH(flagLeft.dx, flagLeft.dy + 2*flagHeight/3, flagWidth, flagHeight/3),
      paint,
    );
    
    // Chakra (wheel) in center of flag
    paint.color = const Color(0xFF000080);
    final chakraCenter = center.translate(0, -55 + flagHeight/2);
    canvas.drawCircle(chakraCenter, 2, paint);
    
    // Chakra spokes (simplified)
    strokePaint.strokeWidth = 0.5;
    strokePaint.color = const Color(0xFF000080);
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi) / 4;
      final dx = 1.5 * math.cos(angle);
      final dy = 1.5 * math.sin(angle);
      canvas.drawLine(
        chakraCenter,
        chakraCenter.translate(dx, dy),
        strokePaint,
      );
    }
    
    // Flag border
    strokePaint.strokeWidth = 1;
    strokePaint.color = const Color(0xFF000000);
    canvas.drawRect(
      Rect.fromLTWH(flagLeft.dx, flagLeft.dy, flagWidth, flagHeight),
      strokePaint,
    );
    
    // Arms (normal playful pose)
    strokePaint.strokeWidth = 3;
    strokePaint.strokeCap = StrokeCap.round;
    
    // Left arm (waving)
    canvas.drawLine(
      center.translate(-20, -2),
      center.translate(-30, -12),
      strokePaint,
    );
    
    // Right arm (pointing/playing)
    canvas.drawLine(
      center.translate(20, -2),
      center.translate(32, -8),
      strokePaint,
    );
    
    // Legs
    canvas.drawLine(
      center.translate(-10, 33),
      center.translate(-10, 45),
      strokePaint,
    );
    
    canvas.drawLine(
      center.translate(10, 33),
      center.translate(10, 45),
      strokePaint,
    );
    
    // Feet
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(-10, 47), 3, paint);
    canvas.drawCircle(center.translate(10, 47), 3, paint);
    
    // Body details (chest panel)
    strokePaint.strokeWidth = 1;
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, 3), width: 16, height: 20),
      const Radius.circular(3),
    );
    canvas.drawRRect(panelRect, strokePaint);
    
    // Chest buttons
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(-4, -2), 1.5, paint);
    canvas.drawCircle(center.translate(4, -2), 1.5, paint);
    canvas.drawCircle(center.translate(0, 6), 1.5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}