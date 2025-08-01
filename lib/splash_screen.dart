import 'package:flutter/material.dart';
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
  late AnimationController _exciteController;
  late AnimationController _pullController;
  late AnimationController _fadeController;
  
  late Animation<double> _robotFloatAnimation;
  late Animation<double> _robotRotateAnimation;
  late Animation<Offset> _robotSlideAnimation;
  late Animation<double> _robotExciteAnimation;
  late Animation<double> _robotJumpAnimation;
  late Animation<Offset> _robotPullPositionAnimation;
  late Animation<Offset> _textPullAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _textScaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Robot animation controller (floating)
    _robotController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Robot excitement animation (laughing, bouncing)
    _exciteController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    // Robot pulling logo from off-screen
    _pullController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
      begin: const Offset(-1.2, 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _robotController,
      curve: Curves.elasticOut,
    ));
    
    // Robot excitement animations (bouncing, scaling)
    _robotExciteAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _exciteController,
      curve: Curves.elasticInOut,
    ));
    
    _robotJumpAnimation = Tween<double>(
      begin: 0.0,
      end: -30.0,
    ).animate(CurvedAnimation(
      parent: _exciteController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    ));
    
    // Robot position when pulling logo
    _robotPullPositionAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(100, 0), // Move to right side to pull logo
    ).animate(CurvedAnimation(
      parent: _pullController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeInOut),
    ));
    
    // Text being pulled from off-screen
    _textPullAnimation = Tween<Offset>(
      begin: const Offset(300, 0), // Start way off-screen to the right
      end: const Offset(0, 0), // End at center
    ).animate(CurvedAnimation(
      parent: _pullController,
      curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
    ));
    
    // Text opacity (only visible when being pulled)
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pullController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeIn),
    ));
    
    // Text scale animation
    _textScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pullController,
      curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
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
    
    // Robot slides in and starts playing
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Robot gets excited, laughs, bounces around
    _exciteController.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 3000));
    
    // Stop excitement and start pulling sequence
    _exciteController.stop();
    _pullController.forward();
    
    // Wait for logo placement, then fade out
    await Future.delayed(const Duration(milliseconds: 2500));
    _fadeController.forward();
    
    // Complete splash after fade
    await Future.delayed(const Duration(milliseconds: 800));
    widget.onComplete();
  }

  @override
  void dispose() {
    _robotController.dispose();
    _exciteController.dispose();
    _pullController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F0), // App's background color
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _robotController, 
          _exciteController,
          _pullController,
          _fadeController
        ]),
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // AhamAI Text (pulled from off-screen)
                  _buildPulledText(),
                  
                  // Excited Robot (bigger, more animated)
                  _buildExcitedRobot(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPulledText() {
    return Transform.translate(
      offset: _textPullAnimation.value,
      child: Transform.scale(
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
    );
  }
  
  Widget _buildExcitedRobot() {
    return Transform.translate(
      offset: _robotPullPositionAnimation.value,
      child: SlideTransition(
        position: _robotSlideAnimation,
        child: Transform.translate(
          offset: Offset(0, _robotFloatAnimation.value + _robotJumpAnimation.value),
          child: Transform.rotate(
            angle: _robotRotateAnimation.value,
            child: Transform.scale(
              scale: _robotExciteAnimation.value * 1.0, // Bigger robot (was 0.7)
              child: _buildRobot(),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRobot() {
    return Container(
      width: 120, // Increased from 100
      height: 120, // Increased from 100
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
    
    // Robot Body (rounded rectangle) - slightly larger
    paint.color = Colors.white;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, 8), width: 45, height: 55),
      const Radius.circular(12),
    );
    canvas.drawRRect(bodyRect, paint);
    canvas.drawRRect(bodyRect, strokePaint);
    
    // Robot Head (circle) - larger
    paint.color = Colors.white;
    canvas.drawCircle(center.translate(0, -18), 22, paint);
    canvas.drawCircle(center.translate(0, -18), 22, strokePaint);
    
    // Eyes (excited/happy eyes) - larger
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(-7, -20), 4, paint);
    canvas.drawCircle(center.translate(7, -20), 4, paint);
    
    // Eye sparkles (playful effect) - more prominent
    paint.color = Colors.white;
    canvas.drawCircle(center.translate(-6, -22), 1.5, paint);
    canvas.drawCircle(center.translate(8, -22), 1.5, paint);
    
    // Big excited smile
    strokePaint.strokeWidth = 3;
    strokePaint.strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, -10), width: 16, height: 12),
      0,
      math.pi,
      false,
      strokePaint,
    );
    
    // Antenna with bouncing effect - taller
    strokePaint.strokeWidth = 2;
    canvas.drawLine(
      center.translate(0, -40),
      center.translate(0, -50),
      strokePaint,
    );
    
    // Antenna tip (glowing) - bigger
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(0, -50), 3, paint);
    paint.color = Colors.white;
    canvas.drawCircle(center.translate(0, -50), 1.5, paint);
    
    // Arms (more excited pose) - longer
    strokePaint.strokeWidth = 4;
    strokePaint.strokeCap = StrokeCap.round;
    
    // Left arm (raised high in excitement)
    canvas.drawLine(
      center.translate(-22, -2),
      center.translate(-35, -18),
      strokePaint,
    );
    
    // Right arm (pulling/reaching)
    canvas.drawLine(
      center.translate(22, -2),
      center.translate(38, -5),
      strokePaint,
    );
    
    // Legs - more stable
    canvas.drawLine(
      center.translate(-12, 35),
      center.translate(-12, 50),
      strokePaint,
    );
    
    canvas.drawLine(
      center.translate(12, 35),
      center.translate(12, 50),
      strokePaint,
    );
    
    // Feet - bigger
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(-12, 52), 4, paint);
    canvas.drawCircle(center.translate(12, 52), 4, paint);
    
    // Body details (chest panel) - larger
    strokePaint.strokeWidth = 1;
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, 3), width: 18, height: 24),
      const Radius.circular(4),
    );
    canvas.drawRRect(panelRect, strokePaint);
    
    // Chest buttons (excited colors) - bigger
    paint.color = const Color(0xFF000000);
    canvas.drawCircle(center.translate(-5, -3), 2, paint);
    canvas.drawCircle(center.translate(5, -3), 2, paint);
    canvas.drawCircle(center.translate(0, 8), 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}