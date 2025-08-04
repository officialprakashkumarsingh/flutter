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
    
    // Triple immediate feedback for ultra-responsive feel
    HapticFeedback.lightImpact(); // Instant tactile response
    
    // Update state immediately for instant visual feedback
    setState(() {
      _currentIndex = index;
    });
    
    // Jump directly to page with zero delay
    _pageController.jumpToPage(index);
    
    // Additional quick confirmation haptic
    Future.delayed(const Duration(milliseconds: 10), () {
      HapticFeedback.selectionClick();
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
            const SavedPage(), // Saved page
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
        decoration: const BoxDecoration(
          color: Color(0xFFF9F7F4), // Match screen background exactly
          // Removed border/separator
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(_buildHomeIcon(), 0),
            _buildNavItem(_buildCharactersIcon(), 1),
            _buildNavItem(_buildCollabsIcon(), 2),
            _buildNavItem(_buildSavedIcon(), 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(Widget icon, int index) {
    final isSelected = _currentIndex == index;
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNavTap(index),
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFF374151).withOpacity(0.1),
          highlightColor: const Color(0xFF374151).withOpacity(0.05),
          child: Container(
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 150), // Super fast response
              curve: Curves.easeOutCirc, // Smooth but quick
              child: Center(
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Beautiful Material home icon
  Widget _buildHomeIcon() {
    final isSelected = _currentIndex == 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100), // Faster response
      child: Icon(
        isSelected ? Icons.home : Icons.home_outlined,
        size: 24, // Perfect size for Material icons
        color: isSelected 
          ? const Color(0xFF374151) // Active color
          : const Color(0xFF9CA3AF), // Inactive color
      ),
    );
  }

  // Beautiful entertainment mask icon for characters
  Widget _buildCharactersIcon() {
    final isSelected = _currentIndex == 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100), // Faster response
      child: Icon(
        isSelected ? Icons.theater_comedy : Icons.theater_comedy_outlined,
        size: 24,
        color: isSelected 
          ? const Color(0xFF374151)
          : const Color(0xFF9CA3AF),
      ),
    );
  }

  // Beautiful Material collabs icon
  Widget _buildCollabsIcon() {
    final isSelected = _currentIndex == 2;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100), // Faster response
      child: Icon(
        isSelected ? Icons.groups : Icons.groups_outlined,
        size: 24,
        color: isSelected 
          ? const Color(0xFF374151)
          : const Color(0xFF9CA3AF),
      ),
    );
  }

  // Beautiful Material saved icon
  Widget _buildSavedIcon() {
    final isSelected = _currentIndex == 3;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100), // Faster response
      child: Icon(
        isSelected ? Icons.bookmark : Icons.bookmark_outline,
        size: 24,
        color: isSelected 
          ? const Color(0xFF374151) // Active color
          : const Color(0xFF9CA3AF), // Inactive color
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

