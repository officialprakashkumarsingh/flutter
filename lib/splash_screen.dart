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
  late AnimationController _logoController;
  late AnimationController _fadeController;
  
  late Animation<double> _robotFloatAnimation;
  late Animation<double> _robotRotateAnimation;
  late Animation<Offset> _robotSlideAnimation;
  late Animation<double> _robotExciteAnimation;
  late Animation<double> _robotJumpAnimation;
  late Animation<Offset> _logoAppearAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _logoScaleAnimation;
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
    
    // Logo magical appearance (independent of robot)
    _logoController = AnimationController(
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
    
    // Logo magical appearance (independent animation)
    _logoAppearAnimation = Tween<Offset>(
      begin: const Offset(0, 100), // Appears from bottom center
      end: const Offset(0, 0), // Goes to center
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    // Logo opacity (fades in magically)
    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));
    
    // Logo scale animation
    _logoScaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
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
    
    // Robot gets excited, laughs, bounces around (no touching logo)
    _exciteController.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 3000));
    
    // Stop robot excitement
    _exciteController.stop();
    
    // Logo appears magically by itself (robot just watches)
    await Future.delayed(const Duration(milliseconds: 500));
    _logoController.forward();
    
    // Wait for logo to settle, then fade out
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
    _logoController.dispose();
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
          _logoController,
          _fadeController
        ]),
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // AhamAI Logo (appears magically)
                  _buildMagicalLogo(),
                  
                  // Robot (plays around, stays on left side)
                  _buildPlayfulRobot(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildMagicalLogo() {
    return Transform.translate(
      offset: _logoAppearAnimation.value,
      child: Transform.scale(
        scale: _logoScaleAnimation.value,
        child: Opacity(
          opacity: _logoOpacityAnimation.value,
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
  
  Widget _buildPlayfulRobot() {
    // Robot stays on the left side, doesn't touch logo
    return Transform.translate(
      offset: const Offset(-80, 0), // Keep robot on left side
      child: SlideTransition(
        position: _robotSlideAnimation,
        child: Transform.translate(
          offset: Offset(0, _robotFloatAnimation.value + _robotJumpAnimation.value),
          child: Transform.rotate(
            angle: _robotRotateAnimation.value,
            child: Transform.scale(
              scale: _robotExciteAnimation.value * 1.0, // Bigger robot
              child: _buildRobot(),
            ),
          ),
        ),
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
    
    // Antenna tip with India Flag! 🇮🇳
    paint.color = Colors.white;
    canvas.drawCircle(center.translate(0, -50), 6, paint);
    canvas.drawCircle(center.translate(0, -50), 6, strokePaint);
    
    // India Flag in the antenna bulb
    // Saffron (top)
    paint.color = const Color(0xFFFF9933);
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, -50), width: 10, height: 10),
      -math.pi, math.pi / 3, true, paint);
    
    // White (middle)
    paint.color = Colors.white;
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(0, -50), width: 10, height: 3.3),
      paint);
    
    // Green (bottom)
    paint.color = const Color(0xFF138808);
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, -50), width: 10, height: 10),
      0, math.pi / 3, true, paint);
    
    // Chakra (wheel) in center - simplified
    paint.color = const Color(0xFF000080);
    canvas.drawCircle(center.translate(0, -50), 1.5, paint);
    
    // Arms (excited pose, pointing towards center where logo will appear)
    strokePaint.strokeWidth = 4;
    strokePaint.strokeCap = StrokeCap.round;
    
    // Left arm (raised in excitement)
    canvas.drawLine(
      center.translate(-22, -2),
      center.translate(-35, -18),
      strokePaint,
    );
    
    // Right arm (pointing towards center, not touching)
    canvas.drawLine(
      center.translate(22, -2),
      center.translate(40, -8),
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