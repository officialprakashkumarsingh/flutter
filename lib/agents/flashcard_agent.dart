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
    Color(0xFF4A90E2), // Blue
    Color(0xFF7ED321), // Green
    Color(0xFFE1A627), // Orange
    Color(0xFFE94B3C), // Red
    Color(0xFF9013FE), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE91E63), // Pink
    Color(0xFF795548), // Brown
  ];
  
  static Future<String?> generateFlashcards(String topic) async {
    try {
      print('🎓 FlashcardAgent: Generating flashcards for topic: $topic');
      
      // Generate flashcards data with improved AI-like content
      final flashcards = await _generateSmartFlashcards(topic);
      
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
📚 **Smart Flashcard Generator**

**Topic**: $topic  
**Generated Cards**: ${flashcards.length}
**Learning Method**: Active Recall & Spaced Repetition

${_generateTextSummary(flashcards)}

💡 **Study Tips**: Review these cards multiple times, test yourself, and practice active recall for best results!

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
- Try a different topic or rephrase your request
- Examples: "Create flashcards for photosynthesis", "Generate math flashcards for algebra"
''';
    }
  }
  
  static Future<List<FlashcardData>> _generateSmartFlashcards(String topic) async {
    final flashcards = <FlashcardData>[];
    final cleanTopic = topic.toLowerCase().trim();
    
    // Generate content based on intelligent topic analysis
    List<Map<String, String>> cardContent = [];
    
    // Mathematics topics
    if (_isTopicRelated(cleanTopic, ['math', 'algebra', 'geometry', 'calculus', 'trigonometry', 'statistics', 'probability'])) {
      cardContent = await _generateMathFlashcards(topic);
    }
    // Science topics
    else if (_isTopicRelated(cleanTopic, ['biology', 'chemistry', 'physics', 'science', 'anatomy', 'genetics', 'ecology'])) {
      cardContent = await _generateScienceFlashcards(topic);
    }
    // History topics
    else if (_isTopicRelated(cleanTopic, ['history', 'ancient', 'medieval', 'war', 'civilization', 'empire', 'revolution'])) {
      cardContent = await _generateHistoryFlashcards(topic);
    }
    // Language and Literature
    else if (_isTopicRelated(cleanTopic, ['english', 'literature', 'grammar', 'writing', 'poetry', 'shakespeare', 'novel'])) {
      cardContent = await _generateLanguageFlashcards(topic);
    }
    // Programming and Computer Science
    else if (_isTopicRelated(cleanTopic, ['programming', 'code', 'computer', 'javascript', 'python', 'java', 'html', 'css', 'algorithm'])) {
      cardContent = await _generateProgrammingFlashcards(topic);
    }
    // Geography
    else if (_isTopicRelated(cleanTopic, ['geography', 'country', 'capital', 'continent', 'ocean', 'mountain', 'river'])) {
      cardContent = await _generateGeographyFlashcards(topic);
    }
    // General/Custom topics
    else {
      cardContent = await _generateGeneralFlashcards(topic);
    }
    
    // Convert to FlashcardData objects with colors
    for (int i = 0; i < cardContent.length && i < 8; i++) {
      final card = cardContent[i];
      flashcards.add(FlashcardData(
        front: card['front']!,
        back: card['back']!,
        color: _cardColors[i % _cardColors.length],
      ));
    }
    
    // Shuffle for variety but keep educational progression
    flashcards.shuffle(Random());
    return flashcards.take(6).toList(); // Limit to 6 cards for optimal UX
  }
  
  static bool _isTopicRelated(String topic, List<String> keywords) {
    return keywords.any((keyword) => topic.contains(keyword));
  }
  
  static Future<List<Map<String, String>>> _generateMathFlashcards(String topic) async {
    final cards = <Map<String, String>>[];
    final cleanTopic = topic.toLowerCase();
    
    if (cleanTopic.contains('algebra')) {
      cards.addAll([
        {
          'front': 'What is the quadratic formula?',
          'back': 'x = (-b ± √(b²-4ac)) / 2a\n\nUsed to solve equations of the form ax² + bx + c = 0\n\nExample: For x² - 5x + 6 = 0\na=1, b=-5, c=6'
        },
        {
          'front': 'How do you factor x² + 5x + 6?',
          'back': '(x + 2)(x + 3)\n\nFind two numbers that:\n• Multiply to give 6\n• Add to give 5\n\nThose numbers are 2 and 3'
        },
        {
          'front': 'What is the slope-intercept form?',
          'back': 'y = mx + b\n\nWhere:\n• m = slope\n• b = y-intercept\n• x = independent variable\n• y = dependent variable'
        },
      ]);
    } else if (cleanTopic.contains('geometry')) {
      cards.addAll([
        {
          'front': 'What is the Pythagorean Theorem?',
          'back': 'a² + b² = c²\n\nIn a right triangle:\n• a, b = legs\n• c = hypotenuse\n\nExample: If a=3 and b=4, then c=5'
        },
        {
          'front': 'How do you find the area of a circle?',
          'back': 'A = πr²\n\nWhere:\n• A = area\n• π ≈ 3.14159\n• r = radius\n\nExample: r=5 → A = π(5)² = 25π ≈ 78.54'
        },
        {
          'front': 'What are the properties of similar triangles?',
          'back': 'Similar triangles have:\n• Same angles\n• Proportional sides\n• Equal ratios of corresponding sides\n\nAAA, SAS, SSS similarity rules'
        },
      ]);
    } else {
      // General math
      cards.addAll([
        {
          'front': 'What is the order of operations (PEMDAS)?',
          'back': 'P - Parentheses\nE - Exponents\nM - Multiplication\nD - Division\nA - Addition\nS - Subtraction\n\nWork left to right for operations of equal precedence'
        },
        {
          'front': 'How do you convert a fraction to a percentage?',
          'back': '1. Divide numerator by denominator\n2. Multiply by 100\n3. Add % symbol\n\nExample: 3/4 = 0.75 = 75%'
        },
      ]);
    }
    
    // Add topic-specific study tips
    cards.add({
      'front': 'Study Strategy for $topic',
      'back': '✓ Practice problems daily\n✓ Show all work steps\n✓ Check your answers\n✓ Identify patterns\n✓ Use visual aids and graphs\n✓ Teach concepts to others'
    });
    
    return cards;
  }
  
  static Future<List<Map<String, String>>> _generateScienceFlashcards(String topic) async {
    final cards = <Map<String, String>>[];
    final cleanTopic = topic.toLowerCase();
    
    if (cleanTopic.contains('biology') || cleanTopic.contains('cell')) {
      cards.addAll([
        {
          'front': 'What is photosynthesis?',
          'back': '6CO₂ + 6H₂O + light energy → C₆H₁₂O₆ + 6O₂\n\nProcess where plants convert:\n• Light energy → Chemical energy\n• Carbon dioxide + Water → Glucose + Oxygen'
        },
        {
          'front': 'What are the main parts of a cell?',
          'back': 'Cell Membrane: Controls what enters/exits\nNucleus: Contains DNA\nCytoplasm: Gel-like substance\nMitochondria: Powerhouse (makes ATP)\nRibosomes: Make proteins'
        },
        {
          'front': 'What is DNA?',
          'back': 'Deoxyribonucleic Acid\n\n• Double helix structure\n• Contains genetic information\n• Made of 4 bases: A, T, G, C\n• A pairs with T, G pairs with C'
        },
      ]);
    } else if (cleanTopic.contains('chemistry')) {
      cards.addAll([
        {
          'front': 'What is the periodic table organized by?',
          'back': 'Atomic Number (number of protons)\n\n• Rows = Periods\n• Columns = Groups/Families\n• Elements in same group have similar properties'
        },
        {
          'front': 'What is a chemical bond?',
          'back': 'Force that holds atoms together\n\nTypes:\n• Ionic: Transfer electrons\n• Covalent: Share electrons\n• Metallic: Sea of electrons'
        },
      ]);
    } else if (cleanTopic.contains('physics')) {
      cards.addAll([
        {
          'front': 'What is Newton\'s First Law?',
          'back': 'Law of Inertia\n\n"An object at rest stays at rest, an object in motion stays in motion, unless acted upon by an external force"\n\nExample: Seatbelts in cars'
        },
        {
          'front': 'What is the formula for force?',
          'back': 'F = ma\n\nWhere:\n• F = Force (Newtons)\n• m = mass (kg)\n• a = acceleration (m/s²)\n\nForce = mass × acceleration'
        },
      ]);
    }
    
    cards.add({
      'front': 'Science Study Method for $topic',
      'back': '🔬 Observe patterns\n📝 Take detailed notes\n🧪 Do experiments/labs\n📊 Analyze data\n🔗 Connect concepts\n📚 Review regularly'
    });
    
    return cards;
  }
  
  static Future<List<Map<String, String>>> _generateHistoryFlashcards(String topic) async {
    final cards = <Map<String, String>>[];
    
    cards.addAll([
      {
        'front': 'When did World War II end?',
        'back': 'September 2, 1945\n\n• Europe: May 8, 1945 (V-E Day)\n• Pacific: September 2, 1945 (V-J Day)\n• Japan surrendered on USS Missouri'
      },
      {
        'front': 'What caused the American Revolution?',
        'back': 'Key Causes:\n• Taxation without representation\n• Boston Tea Party (1773)\n• Intolerable Acts (1774)\n• British military presence\n• Desire for self-governance'
      },
      {
        'front': 'What was the Renaissance?',
        'back': 'Cultural rebirth (14th-17th century)\n\n• Rediscovered Greek/Roman learning\n• Art: Leonardo, Michelangelo\n• Science: Galileo, Copernicus\n• Literature: Shakespeare'
      },
    ]);
    
    cards.add({
      'front': 'History Study Tips for $topic',
      'back': '📅 Create timelines\n🗺️ Use maps and visuals\n👥 Remember key figures\n⚡ Understand cause/effect\n📖 Read primary sources\n🧠 Make connections'
    });
    
    return cards;
  }
  
  static Future<List<Map<String, String>>> _generateLanguageFlashcards(String topic) async {
    final cards = <Map<String, String>>[];
    
    cards.addAll([
      {
        'front': 'What is a metaphor?',
        'back': 'Direct comparison without "like" or "as"\n\nExample: "Life is a journey"\n\nCompares life to a journey to show similarities in experiences and progression'
      },
      {
        'front': 'What\'s the difference between "their," "there," and "they\'re"?',
        'back': 'THEIR = possessive (their book)\nTHERE = place/location (over there)\nTHEY\'RE = contraction (they are)\n\nTrick: Replace with "they are" to test'
      },
      {
        'front': 'What is alliteration?',
        'back': 'Repetition of initial consonant sounds\n\nExample: "Peter Piper picked..."\n\nUsed for rhythm, emphasis, and memorability in poetry and prose'
      },
    ]);
    
    return cards;
  }
  
  static Future<List<Map<String, String>>> _generateProgrammingFlashcards(String topic) async {
    final cards = <Map<String, String>>[];
    final cleanTopic = topic.toLowerCase();
    
    if (cleanTopic.contains('javascript')) {
      cards.addAll([
        {
          'front': 'What is a JavaScript function?',
          'back': 'Reusable block of code\n\nSyntax:\nfunction name(parameters) {\n  // code here\n  return value;\n}\n\nExample: function add(a, b) { return a + b; }'
        },
        {
          'front': 'What is the difference between == and === in JavaScript?',
          'back': '== : Loose equality (type coercion)\n=== : Strict equality (no type coercion)\n\nExample:\n"5" == 5 → true\n"5" === 5 → false'
        },
      ]);
    } else if (cleanTopic.contains('python')) {
      cards.addAll([
        {
          'front': 'How do you create a list in Python?',
          'back': 'my_list = [1, 2, 3, "hello"]\n\n• Lists are ordered and mutable\n• Can contain different data types\n• Access with index: my_list[0]'
        },
        {
          'front': 'What is a Python dictionary?',
          'back': 'Key-value pairs storage\n\nmy_dict = {"name": "John", "age": 25}\n\n• Access: my_dict["name"]\n• Mutable and unordered\n• Keys must be immutable'
        },
      ]);
    }
    
    cards.add({
      'front': 'Programming Study Strategy',
      'back': '💻 Code every day\n🐛 Debug systematically\n📚 Read documentation\n🏗️ Build projects\n👥 Join coding communities\n🔄 Practice, practice, practice!'
    });
    
    return cards;
  }
  
  static Future<List<Map<String, String>>> _generateGeographyFlashcards(String topic) async {
    return [
      {
        'front': 'What are the 7 continents?',
        'back': '1. Asia (largest)\n2. Africa\n3. North America\n4. South America\n5. Antarctica\n6. Europe\n7. Australia/Oceania (smallest)'
      },
      {
        'front': 'What are the 5 oceans?',
        'back': '1. Pacific (largest)\n2. Atlantic\n3. Indian\n4. Southern/Antarctic\n5. Arctic (smallest)\n\nPacific covers 1/3 of Earth\'s surface!'
      },
      {
        'front': 'Geography Study Method',
        'back': '🗺️ Use maps and atlases\n📍 Learn capitals and locations\n🌍 Understand physical features\n📊 Study population and climate data\n🧩 Use map puzzles and games'
      },
    ];
  }
  
  static Future<List<Map<String, String>>> _generateGeneralFlashcards(String topic) async {
    return [
      {
        'front': 'Key Concept: $topic',
        'back': 'This is a fundamental concept that requires understanding and memorization. Focus on the main principles and how they apply in different contexts.'
      },
      {
        'front': 'Important Facts about $topic',
        'back': 'Essential information that forms the foundation of knowledge in this area. Practice recalling these facts regularly for better retention.'
      },
      {
        'front': 'How to Study $topic Effectively',
        'back': '📝 Take organized notes\n🔄 Use spaced repetition\n🎯 Focus on key concepts\n🧠 Test your understanding\n📚 Use multiple resources\n👥 Study with others'
      },
      {
        'front': 'Applications of $topic',
        'back': 'Understanding where and how this knowledge applies in real-world situations helps reinforce learning and shows practical value.'
      },
    ];
  }
  
  static String _generateTextSummary(List<FlashcardData> flashcards) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < flashcards.length; i++) {
      final card = flashcards[i];
      buffer.writeln('**Card ${i + 1}**: ${card.front}');
      final shortAnswer = card.back.split('\n').first;
      buffer.writeln('*Preview*: ${shortAnswer.length > 60 ? '${shortAnswer.substring(0, 60)}...' : shortAnswer}');
      if (i < flashcards.length - 1) buffer.writeln();
    }
    
    return buffer.toString();
  }
}

// Flutter widget for displaying flashcards with improved size and design
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
        // Increased height significantly
        height: 280,
        margin: const EdgeInsets.all(12),
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
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.flashcard.color,
                      widget.flashcard.color.withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.flashcard.color.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Card counter
                    Positioned(
                      top: 16,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          '${widget.index + 1}/${widget.total}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    // Main content area with better padding
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 60),
                        child: Center(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..rotateY(isShowingFront ? 0 : 3.14159),
                            child: SingleChildScrollView(
                              child: Text(
                                isShowingFront
                                    ? widget.flashcard.front
                                    : widget.flashcard.back,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isShowingFront ? 18 : 16,
                                  fontWeight: isShowingFront ? FontWeight.bold : FontWeight.w500,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Tap hint with better positioning
                    if (isShowingFront)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tap to see answer',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Back hint
                    if (!isShowingFront)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.flip,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tap to flip back',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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

// Improved grid widget with better layout and spacing
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
        // Enhanced header
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A90E2).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🧠 Smart Flashcards',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      topic,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${flashcards.length} Cards • Active Recall Method',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Enhanced instructions
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: const Color(0xFF4A90E2), width: 5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF4A90E2),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to Use These Flashcards',
                      style: TextStyle(
                        color: Color(0xFF2C3E50),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap each card to reveal the answer. Study regularly for best results!',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Improved flashcards grid with single column on mobile for better readability
        Container(
          margin: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use single column on smaller screens for better readability
              final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
              final childAspectRatio = constraints.maxWidth > 600 ? 1.2 : 1.4;
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: flashcards.length,
                itemBuilder: (context, index) {
                  return FlashcardWidget(
                    flashcard: flashcards[index],
                    index: index,
                    total: flashcards.length,
                  );
                },
              );
            },
          ),
        ),
        // Enhanced study tips
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28A745).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Color(0xFF28A745),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Study Tips for Maximum Retention',
                    style: TextStyle(
                      color: Color(0xFF2C3E50),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '• Review cards multiple times throughout the week\n'
                '• Test yourself without looking at answers first\n'
                '• Use spaced repetition - review difficult cards more often\n'
                '• Study in short, focused sessions (15-30 minutes)\n'
                '• Create your own examples for each concept',
                style: TextStyle(
                  color: Color(0xFF495057),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}