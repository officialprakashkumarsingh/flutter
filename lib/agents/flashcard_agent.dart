import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

class FlashcardData {
  final String front;
  final String back;
  final Color color;

  FlashcardData({
    required this.front,
    required this.back,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
    'front': front,
    'back': back,
    'color': color.value,
  };

  factory FlashcardData.fromJson(Map<String, dynamic> json) => FlashcardData(
    front: json['front'],
    back: json['back'],
    color: Color(json['color']),
  );
}

class FlashcardAgent {
  static const String _agentName = 'Flashcard Generator';
  
  static const List<Color> _cardColors = [
    Color(0xFFFF6B6B), // Red
    Color(0xFF4ECDC4), // Teal
    Color(0xFF45B7D1), // Blue
    Color(0xFF96CEB4), // Green
    Color(0xFFFECA57), // Yellow
    Color(0xFFFF9FF3), // Pink
    Color(0xFF54A0FF), // Light Blue
    Color(0xFF5F27CD), // Purple
  ];
  
  static Future<String?> generateFlashcards(String topic) async {
    try {
      print('🎓 FlashcardAgent: Generating flashcards for topic: $topic');
      
      // Generate flashcards data
      final flashcards = await _generateFlashcardsData(topic);
      
      if (flashcards.isEmpty) {
        return null;
      }
      
      print('✅ FlashcardAgent: Generated ${flashcards.length} flashcards successfully');
      
      // Return JSON data that the UI can render as Flutter widgets
      final flashcardsJson = {
        'type': 'flashcards',
        'topic': topic,
        'count': flashcards.length,
        'cards': flashcards.map((card) => card.toJson()).toList(),
      };
      
      return '''
📚 **Flashcard Generator Results**

**Topic**: $topic  
**Total Cards**: ${flashcards.length}

${_generateTextSummary(flashcards)}

**FLASHCARD_DATA_START**
${jsonEncode(flashcardsJson)}
**FLASHCARD_DATA_END**
''';
      
    } catch (e) {
      print('❌ FlashcardAgent Error: $e');
      return '''
❌ **Flashcard Generation Failed**

**Error**: Could not generate flashcards for "$topic"
**Reason**: $e

**Try**:
- Make sure the topic is clear and specific
- Try a different topic or rephrase
''';
    }
  }
  
  static List<FlashcardData> _generateFlashcardsData(String topic) {
    final flashcards = <FlashcardData>[];
    final topicKeywords = topic.toLowerCase();
    
    // Generate content based on topic
    List<Map<String, String>> cardContent = [];
    
    if (topicKeywords.contains('math') || topicKeywords.contains('algebra') || topicKeywords.contains('geometry')) {
      cardContent.addAll([
        {'front': 'What is the Pythagorean Theorem?', 'back': 'a² + b² = c²\n\nIn a right triangle, the square of the hypotenuse equals the sum of squares of the other two sides.'},
        {'front': 'What is the quadratic formula?', 'back': 'x = (-b ± √(b²-4ac)) / 2a\n\nUsed to solve quadratic equations of the form ax² + bx + c = 0'},
        {'front': 'What is the area of a circle?', 'back': 'A = πr²\n\nWhere r is the radius of the circle'},
        {'front': 'What is the slope formula?', 'back': 'm = (y₂ - y₁) / (x₂ - x₁)\n\nMeasures the steepness of a line between two points'},
      ]);
    } else if (topicKeywords.contains('science') || topicKeywords.contains('biology') || topicKeywords.contains('chemistry')) {
      cardContent.addAll([
        {'front': 'What is photosynthesis?', 'back': '6CO₂ + 6H₂O + light energy → C₆H₁₂O₆ + 6O₂\n\nProcess by which plants convert light energy into chemical energy'},
        {'front': 'What is DNA?', 'back': 'Deoxyribonucleic Acid\n\nA double helix molecule that carries genetic instructions for all living organisms'},
        {'front': 'What is the atomic structure?', 'back': 'Atoms consist of:\n• Protons (+) in nucleus\n• Neutrons (neutral) in nucleus\n• Electrons (-) orbiting around'},
        {'front': 'What is mitosis?', 'back': 'Cell division process that produces two identical diploid cells from one parent cell'},
      ]);
    } else if (topicKeywords.contains('history') || topicKeywords.contains('world war') || topicKeywords.contains('ancient')) {
      cardContent.addAll([
        {'front': 'When did World War II end?', 'back': 'September 2, 1945\n\nJapan formally surrendered aboard the USS Missouri in Tokyo Bay'},
        {'front': 'Who was the first President of the United States?', 'back': 'George Washington (1789-1797)\n\nLed the Continental Army and presided over the Constitutional Convention'},
        {'front': 'What was the Renaissance?', 'back': 'Cultural movement (14th-17th century)\n\nMarking transition from medieval to modern Europe, emphasizing art, science, and humanism'},
        {'front': 'When did the Roman Empire fall?', 'back': '476 AD (Western) / 1453 AD (Eastern)\n\nWestern fell to Germanic tribes, Eastern (Byzantine) fell to Ottoman Empire'},
      ]);
    } else if (topicKeywords.contains('english') || topicKeywords.contains('literature') || topicKeywords.contains('grammar')) {
      cardContent.addAll([
        {'front': 'What is a metaphor?', 'back': 'A figure of speech that directly compares two unlike things without using "like" or "as"\n\nExample: "Life is a journey"'},
        {'front': 'What is alliteration?', 'back': 'Repetition of initial consonant sounds in consecutive words\n\nExample: "Peter Piper picked..."'},
        {'front': 'What is the difference between "their," "there," and "they\'re"?', 'back': '• Their = possessive (their book)\n• There = place (over there)\n• They\'re = contraction (they are)'},
        {'front': 'What is a protagonist?', 'back': 'The main character in a story\n\nOften the hero who drives the plot forward and faces conflicts'},
      ]);
    } else {
      // Generic educational flashcards for any topic
      cardContent.addAll([
        {'front': 'Key Concept: $topic', 'back': 'This is a fundamental concept in $topic that students should understand and remember.'},
        {'front': 'Important Term in $topic', 'back': 'A crucial vocabulary word or technical term that is essential for mastering $topic.'},
        {'front': 'How does $topic work?', 'back': 'Understanding the process, mechanism, or principles behind $topic is key to learning.'},
        {'front': 'Why is $topic important?', 'back': 'Learning $topic helps build foundational knowledge and connects to broader concepts in the field.'},
      ]);
    }
    
    // Add topic-specific study cards
    cardContent.addAll([
      {'front': 'Study Tips for $topic', 'back': '• Break down complex concepts into smaller parts\n• Use active recall and spaced repetition\n• Create visual aids and diagrams\n• Teach the concept to someone else\n• Practice regularly with real examples'},
      {'front': 'Memory Technique for $topic', 'back': '• Create acronyms or mnemonics\n• Use the "story method" to link concepts\n• Draw mind maps and concept diagrams\n• Use flashcards for key terms\n• Associate new information with what you already know'},
    ]);
    
    // Convert to FlashcardData objects with colors
    for (int i = 0; i < cardContent.length && i < 8; i++) {
      final card = cardContent[i];
      flashcards.add(FlashcardData(
        front: card['front']!,
        back: card['back']!,
        color: _cardColors[i % _cardColors.length],
      ));
    }
    
    // Shuffle for variety
    flashcards.shuffle(Random());
    return flashcards.take(6).toList(); // Limit to 6 cards for better UX
  }
  
  static String _generateTextSummary(List<FlashcardData> flashcards) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < flashcards.length; i++) {
      final card = flashcards[i];
      buffer.writeln('**Card ${i + 1}**: ${card.front}');
      buffer.writeln('*Answer*: ${card.back.split('\n').first}');
      if (i < flashcards.length - 1) buffer.writeln();
    }
    
    return buffer.toString();
  }
}

// Flutter widget for displaying flashcards
class FlashcardWidget extends StatefulWidget {
  final FlashcardData flashcard;
  final int index;
  final int total;

  const FlashcardWidget({
    Key? key,
    required this.flashcard,
    required this.index,
    required this.total,
  }) : super(key: key);

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (!_isFlipped) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: Container(
        height: 200,
        margin: const EdgeInsets.all(8),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final isShowingFront = _animation.value < 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_animation.value * 3.14159),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.flashcard.color,
                      widget.flashcard.color.withOpacity(0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Card counter
                    Positioned(
                      top: 12,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.index + 1}/${widget.total}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    // Card content
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateY(isShowingFront ? 0 : 3.14159),
                          child: Text(
                            isShowingFront
                                ? widget.flashcard.front
                                : widget.flashcard.back,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    // Tap hint
                    if (isShowingFront)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Text(
                          'Tap to flip',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Grid widget for displaying multiple flashcards
class FlashcardGrid extends StatelessWidget {
  final List<FlashcardData> flashcards;
  final String topic;

  const FlashcardGrid({
    Key? key,
    required this.flashcards,
    required this.topic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.school,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📚 Flashcards',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Instructions
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: const Border(
              left: BorderSide(color: Color(0xFF4ECDC4), width: 4),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: Color(0xFF4ECDC4),
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap each card to flip it and see the answer. Perfect for quick review and memorization!',
                  style: TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Flashcards grid
        Container(
          margin: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: flashcards.length,
            itemBuilder: (context, index) {
              return FlashcardWidget(
                flashcard: flashcards[index],
                index: index,
                total: flashcards.length,
              );
            },
          ),
        ),
        // Study tip
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.tips_and_updates,
                color: Color(0xFF667eea),
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Study Tip: Review these cards multiple times throughout the week for better retention!',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}