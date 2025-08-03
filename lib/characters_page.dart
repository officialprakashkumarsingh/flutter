import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CharactersPage extends StatefulWidget {
  const CharactersPage({super.key});

  @override
  State<CharactersPage> createState() => _CharactersPageState();
}

class _CharactersPageState extends State<CharactersPage> {
  @override
  Widget build(BuildContext context) {
    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F4), // Cream background
      body: CustomPaint(
        painter: CharactersPatternPainter(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Characters',
                  style: GoogleFonts.spaceMono( // Same font as AhamAI
                    fontSize: 20, // Bigger and consistent
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF09090B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI personalities and assistants',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF71717A),
                  ),
                ),
                const SizedBox(height: 32),

                // Characters grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _characters.length,
                    itemBuilder: (context, index) {
                      final character = _characters[index];
                      return _buildCharacterCard(character);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterCard(Character character) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E4E7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Character avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: character.color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FaIcon(
                  character.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Character name
            Text(
              character.name,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF09090B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Character description
            Expanded(
              child: Text(
                character.description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF71717A),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Coming soon badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Coming Soon',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final List<Character> _characters = [
    Character(
      name: 'AhamAI Assistant',
      description: 'General purpose AI assistant for any task',
      icon: FontAwesomeIcons.robot,
      color: const Color(0xFF7C3AED),
    ),
    Character(
      name: 'Code Expert',
      description: 'Specialized in programming and development',
      icon: FontAwesomeIcons.code,
      color: const Color(0xFF059669),
    ),
    Character(
      name: 'Creative Writer',
      description: 'Helps with creative writing and storytelling',
      icon: FontAwesomeIcons.feather,
      color: const Color(0xFFDC2626),
    ),
    Character(
      name: 'Study Buddy',
      description: 'Educational assistant for learning',
      icon: FontAwesomeIcons.graduationCap,
      color: const Color(0xFF2563EB),
    ),
    Character(
      name: 'Business Advisor',
      description: 'Strategic business and entrepreneurship guidance',
      icon: FontAwesomeIcons.briefcase,
      color: const Color(0xFF7C2D12),
    ),
    Character(
      name: 'Health Coach',
      description: 'Wellness and healthy lifestyle guidance',
      icon: FontAwesomeIcons.heartPulse,
      color: const Color(0xFFBE123C),
    ),
  ];
}

class Character {
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  Character({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class CharactersPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill with cream background
    final paint = Paint()..color = const Color(0xFFF9F7F4);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Create subtle dot pattern
    final dotPaint = Paint()
      ..color = Colors.grey.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    
    const dotSize = 1.2;
    const spacing = 25.0;
    
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, dotPaint);
        // Add variation for subtle texture
        if ((x / spacing) % 3 == 0 && (y / spacing) % 3 == 0) {
          canvas.drawCircle(Offset(x + spacing/2, y + spacing/2), dotSize * 0.6, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}