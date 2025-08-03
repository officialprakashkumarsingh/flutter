import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Simple fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _startAnimation();
  }

  void _startAnimation() async {
    // Start fade animation
    _fadeController.forward();
    
    // Wait and complete
    await Future.delayed(const Duration(milliseconds: 1500));
    widget.onComplete();
  }

  @override
  void dispose() {
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
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomPaint(
          painter: WhatsAppPatternPainter(),
          child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              'AhamAI',
              style: GoogleFonts.spaceMono(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF09090B),
                letterSpacing: -1.0,
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class WhatsAppPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill with white background
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Create dot pattern
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