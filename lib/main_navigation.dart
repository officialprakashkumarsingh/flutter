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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F4), // Cream background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
              child: SafeArea(
          child: Container(
            height: 60, // Slightly smaller
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        ),
    );
  }

  Widget _buildNavItem(Widget icon, int index) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), // Faster response
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // iOS-style icon with instant scale, then reset
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0, // Clean scale effect
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOutCubic,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.transparent, // No background colors
                  borderRadius: BorderRadius.circular(12),
                ),
                child: icon,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeIcon() {
    final isSelected = _currentIndex == 0;
    return FaIcon(
      FontAwesomeIcons.house, // Beautiful house icon
      size: 20, // Slightly larger for better visibility
      color: isSelected 
        ? const Color(0xFF09090B) // Pure black when active
        : const Color(0xFF64748B), // Grey when inactive
    );
  }

  Widget _buildCharactersIcon() {
    final isSelected = _currentIndex == 1;
    return FaIcon(
      FontAwesomeIcons.robot, // Perfect robot icon for AI characters
      size: 20,
      color: isSelected 
        ? const Color(0xFF09090B) // Pure black when active
        : const Color(0xFF64748B), // Grey when inactive
    );
  }

  Widget _buildCollabsIcon() {
    final isSelected = _currentIndex == 2;
    return FaIcon(
      FontAwesomeIcons.peopleGroup, // Beautiful collaboration icon
      size: 20,
      color: isSelected 
        ? const Color(0xFF09090B) // Pure black when active
        : const Color(0xFF64748B), // Grey when inactive
    );
  }

  Widget _buildHistoryIcon() {
    final isSelected = _currentIndex == 3;
    return FaIcon(
      FontAwesomeIcons.clockRotateLeft, // Perfect history/time icon
      size: 20,
      color: isSelected 
        ? const Color(0xFF09090B) // Pure black when active
        : const Color(0xFF64748B), // Grey when inactive
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