import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'main_shell.dart';
import 'characters_page.dart';
import 'collaboration_page.dart';

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
    _iconAnimations = List.generate(3, (index) {
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
    
    setState(() {
      _currentIndex = index;
    });
    
    // Direct page jump - no swiping through pages
    _pageController.jumpToPage(index);
    
    // Icon animation
    _navAnimationController.reset();
    _navAnimationController.forward();
    
    // Haptic feedback for native feel
    HapticFeedback.lightImpact();
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
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, _buildHomeIcon(), 'Home'),
              _buildNavItem(1, _buildCharactersIcon(), 'Characters'),
              _buildNavItem(2, _buildCollabsIcon(), 'Collabs'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, Widget icon, String label) {
    final isSelected = index == _currentIndex;
    
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: AnimatedBuilder(
        animation: _navAnimationController,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected 
                ? const Color(0xFF09090B).withOpacity(0.08)
                : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: isSelected ? _iconAnimations[index].value : 0.9,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    child: icon,
                  ),
                ),
                // No labels as requested
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeIcon() {
    final isSelected = _currentIndex == 0;
    return FaIcon(
      FontAwesomeIcons.house,
      size: 20,
      color: isSelected 
        ? const Color(0xFF09090B)
        : const Color(0xFF71717A),
    );
  }

  Widget _buildCharactersIcon() {
    final isSelected = _currentIndex == 1;
    return FaIcon(
      FontAwesomeIcons.robot,
      size: 20,
      color: isSelected 
        ? const Color(0xFF7C3AED)
        : const Color(0xFF71717A),
    );
  }

  Widget _buildCollabsIcon() {
    final isSelected = _currentIndex == 2;
    return FaIcon(
      FontAwesomeIcons.userGroup,
      size: 20,
      color: isSelected 
        ? const Color(0xFF22C55E)
        : const Color(0xFF71717A),
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