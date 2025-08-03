import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'main_shell.dart';
import 'characters_page.dart';
import 'collaboration_page.dart';
import 'history_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _navAnimationController;
  late List<Animation<double>> _iconAnimations;
  String _selectedModel = 'claude-3-7-sonnet'; // Manage selected model at top level

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Animation controller for smooth icon transitions
    _navAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Create animations for each nav item
    _iconAnimations = List.generate(4, (index) {
      return Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: _navAnimationController,
          curve: index == _currentIndex ? Curves.elasticOut : Curves.easeInOut,
        ),
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _navAnimationController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    
    // Immediate haptic feedback for ultra-responsive feel
    HapticFeedback.selectionClick();
    
    // Update state immediately for instant visual feedback
    setState(() {
      _currentIndex = index;
    });
    
    // Jump directly to page with no delay
    _pageController.jumpToPage(index);
    
    // Light second haptic for smooth confirmation
    Future.delayed(const Duration(milliseconds: 30), () {
      HapticFeedback.lightImpact();
    });
  }

  void _updateSelectedModel(String model) {
    setState(() {
      _selectedModel = model;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F4), // Cream background
      body: CustomPaint(
        painter: MainPatternPainter(),
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // Disable swiping
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            _navAnimationController.reset();
            _navAnimationController.forward();
          },
          children: [
            MainShell(
              selectedModel: _selectedModel,
              onModelChanged: _updateSelectedModel,
            ), // Home page (current chat interface)
            const CharactersPage(), // Characters page  
            CollaborationPageWrapper(selectedModel: _selectedModel), // Collabs page
            const HistoryPage(), // History page
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return SafeArea(
      child: Container(
        height: 70, // Slightly taller for better ergonomics
        margin: const EdgeInsets.only(bottom: 8), // Lift higher for easier access
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F7F4), // Match screen background exactly
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(0), // No rounded corners for seamless look
          ),
          border: Border(
            top: BorderSide(
              color: Colors.grey.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(_buildHomeIcon(), 0),
            _buildNavItem(_buildCharactersIcon(), 1),
            _buildNavItem(_buildCollabsIcon(), 2),
            _buildNavItem(_buildHistoryIcon(), 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(Widget icon, int index) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Better touch area
        child: AnimatedScale(
          scale: isSelected ? 1.2 : 1.0, // More pronounced scale for better visibility
          duration: const Duration(milliseconds: 200),
          curve: Curves.elasticOut, // Cool elastic animation
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected 
                ? Colors.black.withOpacity(0.05) // Subtle background when active
                : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: icon,
          ),
        ),
      ),
    );
  }

  // Custom painted home icon
  Widget _buildHomeIcon() {
    final isSelected = _currentIndex == 0;
    return CustomPaint(
      size: const Size(22, 22), // Smaller, more proportional size
      painter: HomeIconPainter(
        color: isSelected 
          ? const Color(0xFF374151) // Lighter gray when active (like Perplexity)
          : const Color(0xFF9CA3AF), // Light gray when inactive
        isSelected: isSelected,
      ),
    );
  }

  // Custom painted characters icon
  Widget _buildCharactersIcon() {
    final isSelected = _currentIndex == 1;
    return CustomPaint(
      size: const Size(22, 22), // Smaller, more proportional size
      painter: CharactersIconPainter(
        color: isSelected 
          ? const Color(0xFF374151) // Lighter gray when active
          : const Color(0xFF9CA3AF), // Light gray when inactive
        isSelected: isSelected,
      ),
    );
  }

  // Custom painted collabs icon
  Widget _buildCollabsIcon() {
    final isSelected = _currentIndex == 2;
    return CustomPaint(
      size: const Size(22, 22), // Smaller, more proportional size
      painter: CollabsIconPainter(
        color: isSelected 
          ? const Color(0xFF374151) // Lighter gray when active
          : const Color(0xFF9CA3AF), // Light gray when inactive
        isSelected: isSelected,
      ),
    );
  }

  // Custom painted history icon
  Widget _buildHistoryIcon() {
    final isSelected = _currentIndex == 3;
    return CustomPaint(
      size: const Size(22, 22), // Smaller, more proportional size
      painter: HistoryIconPainter(
        color: isSelected 
          ? const Color(0xFF374151) // Lighter gray when active
          : const Color(0xFF9CA3AF), // Light gray when inactive
        isSelected: isSelected,
      ),
    );
  }
}

// Wrapper for collaboration page to handle navigation context
class CollaborationPageWrapper extends StatelessWidget {
  final String selectedModel;
  
  const CollaborationPageWrapper({super.key, required this.selectedModel});

  @override
  Widget build(BuildContext context) {
    return ChatsPage(selectedModel: selectedModel);
  }
}

// Pattern painter for consistent background
class MainPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill with cream background
    final paint = Paint()..color = const Color(0xFFF9F7F4);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Create subtle dot pattern
    final dotPaint = Paint()
      ..color = Colors.grey.withOpacity(0.03)
      ..style = PaintingStyle.fill;
    
    const dotSize = 1.0;
    const spacing = 30.0;
    
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, dotPaint);
        // Add variation for subtle texture
        if ((x / spacing) % 3 == 0 && (y / spacing) % 3 == 0) {
          canvas.drawCircle(Offset(x + spacing/2, y + spacing/2), dotSize * 0.7, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom icon painters with better proportions and modern design
class HomeIconPainter extends CustomPainter {
  final Color color;
  final bool isSelected;
  
  HomeIconPainter({required this.color, required this.isSelected});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    final path = Path();
    
    // Modern minimalist house shape - better proportions
    path.moveTo(size.width * 0.25, size.height * 0.75);
    path.lineTo(size.width * 0.25, size.height * 0.5);
    path.lineTo(size.width * 0.5, size.height * 0.3);
    path.lineTo(size.width * 0.75, size.height * 0.5);
    path.lineTo(size.width * 0.75, size.height * 0.75);
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Door - more proportional
    final doorRect = Rect.fromLTWH(
      size.width * 0.45, 
      size.height * 0.6, 
      size.width * 0.1, 
      size.width * 0.15
    );
    canvas.drawRect(doorRect, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class CharactersIconPainter extends CustomPainter {
  final Color color;
  final bool isSelected;
  
  CharactersIconPainter({required this.color, required this.isSelected});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Modern AI/robot head design - cleaner and smaller
    final headRadius = size.width * 0.14;
    final headCenter = Offset(size.width * 0.5, size.height * 0.4);
    
    // Head circle
    canvas.drawCircle(headCenter, headRadius, paint);
    
    // Body rectangle - more proportional
    final bodyRect = Rect.fromLTWH(
      size.width * 0.4, 
      size.height * 0.54, 
      size.width * 0.2, 
      size.height * 0.25
    );
    canvas.drawRoundRect(bodyRect, const Radius.circular(4), paint);
    
    // Simple eyes (if selected)
    if (isSelected) {
      final eyePaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(size.width * 0.46, size.height * 0.37), 
        1.5, 
        eyePaint
      );
      canvas.drawCircle(
        Offset(size.width * 0.54, size.height * 0.37), 
        1.5, 
        eyePaint
      );
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class CollabsIconPainter extends CustomPainter {
  final Color color;
  final bool isSelected;
  
  CollabsIconPainter({required this.color, required this.isSelected});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Three people in a more compact, modern arrangement
    final radius = size.width * 0.06;
    
    // Person 1 (left)
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.35), 
      radius, 
      paint
    );
    
    // Person 2 (center, slightly elevated)
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.32), 
      radius, 
      paint
    );
    
    // Person 3 (right)
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.35), 
      radius, 
      paint
    );
    
    // Simple connection line at bottom
    if (isSelected) {
      final path = Path();
      path.moveTo(size.width * 0.25, size.height * 0.65);
      path.lineTo(size.width * 0.75, size.height * 0.65);
      canvas.drawPath(path, paint);
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class HistoryIconPainter extends CustomPainter {
  final Color color;
  final bool isSelected;
  
  HistoryIconPainter({required this.color, required this.isSelected});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.25;
    
    // Clock circle - more proportional
    canvas.drawCircle(center, radius, paint);
    
    // Clock hands - simpler design
    final path = Path();
    
    // Short hour hand (pointing to 3)
    path.moveTo(center.dx, center.dy);
    path.lineTo(center.dx + radius * 0.5, center.dy);
    
    // Long minute hand (pointing to 12)
    path.moveTo(center.dx, center.dy);
    path.lineTo(center.dx, center.dy - radius * 0.7);
    
    canvas.drawPath(path, paint);
    
    // Center dot
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.5, centerPaint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}