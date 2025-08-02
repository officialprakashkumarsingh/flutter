import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

class FlashcardAgent {
  static const String _agentName = 'Flashcard Generator';
  
  static Future<String?> generateFlashcards(String topic) async {
    try {
      print('🎓 FlashcardAgent: Generating flashcards for topic: $topic');
      
      // Generate flashcards data
      final flashcards = await _generateFlashcardsData(topic);
      
      if (flashcards.isEmpty) {
        return null;
      }
      
      // Generate HTML for beautiful flashcards
      final html = _generateFlashcardsHTML(topic, flashcards);
      
      print('✅ FlashcardAgent: Generated ${flashcards.length} flashcards successfully');
      
      return '''
📚 **Flashcard Generator Results**

**Topic**: $topic  
**Total Cards**: ${flashcards.length}

${_generateTextSummary(flashcards)}

---

**Interactive Flashcards:**

$html
''';
      
    } catch (e) {
      print('❌ FlashcardAgent Error: $e');
      return '''
❌ **Flashcard Generation Failed**

**Error**: Could not generate flashcards for "$topic"
**Reason**: $e

**Try**:
- Make sure the topic is clear and specific
- Check your internet connection
- Try a different topic or rephrase
''';
    }
  }
  
  static List<Map<String, String>> _generateFlashcardsData(String topic) {
    // Generate educational flashcards based on topic
    final flashcards = <Map<String, String>>[];
    
    // Common study topics with sample flashcards
    final topicKeywords = topic.toLowerCase();
    
    if (topicKeywords.contains('math') || topicKeywords.contains('algebra') || topicKeywords.contains('geometry')) {
      flashcards.addAll([
        {'front': 'What is the Pythagorean Theorem?', 'back': 'a² + b² = c² - In a right triangle, the square of the hypotenuse equals the sum of squares of the other two sides.'},
        {'front': 'What is the quadratic formula?', 'back': 'x = (-b ± √(b²-4ac)) / 2a - Used to solve quadratic equations of the form ax² + bx + c = 0'},
        {'front': 'What is the area of a circle?', 'back': 'A = πr² - Where r is the radius of the circle'},
        {'front': 'What is the slope formula?', 'back': 'm = (y₂ - y₁) / (x₂ - x₁) - Measures the steepness of a line between two points'},
      ]);
    } else if (topicKeywords.contains('science') || topicKeywords.contains('biology') || topicKeywords.contains('chemistry')) {
      flashcards.addAll([
        {'front': 'What is photosynthesis?', 'back': '6CO₂ + 6H₂O + light energy → C₆H₁₂O₆ + 6O₂ - Process by which plants convert light energy into chemical energy'},
        {'front': 'What is DNA?', 'back': 'Deoxyribonucleic Acid - A double helix molecule that carries genetic instructions for all living organisms'},
        {'front': 'What is the atomic structure?', 'back': 'Atoms consist of protons (+), neutrons (neutral) in the nucleus, and electrons (-) orbiting around'},
        {'front': 'What is mitosis?', 'back': 'Cell division process that produces two identical diploid cells from one parent cell'},
      ]);
    } else if (topicKeywords.contains('history') || topicKeywords.contains('world war') || topicKeywords.contains('ancient')) {
      flashcards.addAll([
        {'front': 'When did World War II end?', 'back': 'September 2, 1945 - Japan formally surrendered aboard the USS Missouri in Tokyo Bay'},
        {'front': 'Who was the first President of the United States?', 'back': 'George Washington (1789-1797) - Led the Continental Army and presided over the Constitutional Convention'},
        {'front': 'What was the Renaissance?', 'back': 'Cultural movement (14th-17th century) marking transition from medieval to modern Europe, emphasizing art, science, and humanism'},
        {'front': 'When did the Roman Empire fall?', 'back': '476 AD (Western) / 1453 AD (Eastern) - Western fell to Germanic tribes, Eastern (Byzantine) fell to Ottoman Empire'},
      ]);
    } else if (topicKeywords.contains('english') || topicKeywords.contains('literature') || topicKeywords.contains('grammar')) {
      flashcards.addAll([
        {'front': 'What is a metaphor?', 'back': 'A figure of speech that directly compares two unlike things without using "like" or "as" (e.g., "Life is a journey")'},
        {'front': 'What is alliteration?', 'back': 'Repetition of initial consonant sounds in consecutive words (e.g., "Peter Piper picked...")'},
        {'front': 'What is the difference between "their," "there," and "they\'re"?', 'back': 'Their = possessive (their book), There = place (over there), They\'re = contraction (they are)'},
        {'front': 'What is a protagonist?', 'back': 'The main character in a story, often the hero who drives the plot forward and faces conflicts'},
      ]);
    } else {
      // Generic educational flashcards for any topic
      flashcards.addAll([
        {'front': 'Key Concept: $topic', 'back': 'This is a fundamental concept in $topic that students should understand and remember.'},
        {'front': 'Important Term in $topic', 'back': 'A crucial vocabulary word or technical term that is essential for mastering $topic.'},
        {'front': 'How does $topic work?', 'back': 'Understanding the process, mechanism, or principles behind $topic is key to learning.'},
        {'front': 'Why is $topic important?', 'back': 'Learning $topic helps build foundational knowledge and connects to broader concepts in the field.'},
        {'front': 'Practice Question: $topic', 'back': 'Apply your knowledge of $topic to solve problems and demonstrate understanding.'},
      ]);
    }
    
    // Add topic-specific generated cards
    final additionalCards = _generateTopicSpecificCards(topic);
    flashcards.addAll(additionalCards);
    
    // Shuffle and limit to reasonable number
    flashcards.shuffle(Random());
    return flashcards.take(8).toList(); // Limit to 8 cards for better UX
  }
  
  static List<Map<String, String>> _generateTopicSpecificCards(String topic) {
    final cards = <Map<String, String>>[];
    
    // Generate study tips card
    cards.add({
      'front': 'Study Tips for $topic',
      'back': '• Break down complex concepts into smaller parts\n• Use active recall and spaced repetition\n• Create visual aids and diagrams\n• Teach the concept to someone else\n• Practice regularly with real examples'
    });
    
    // Generate memory technique card
    cards.add({
      'front': 'Memory Technique for $topic',
      'back': '• Create acronyms or mnemonics\n• Use the "story method" to link concepts\n• Draw mind maps and concept diagrams\n• Use flashcards for key terms\n• Associate new information with what you already know'
    });
    
    // Generate review questions
    cards.add({
      'front': 'Review Questions: $topic',
      'back': '• What are the main principles of $topic?\n• How does $topic relate to other subjects?\n• Can you explain $topic in simple terms?\n• What are common mistakes in $topic?\n• How is $topic used in real life?'
    });
    
    return cards;
  }
  
  static String _generateTextSummary(List<Map<String, String>> flashcards) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < flashcards.length; i++) {
      final card = flashcards[i];
      buffer.writeln('**Card ${i + 1}**: ${card['front']}');
      buffer.writeln('*Answer*: ${card['back']?.split('\n').first ?? ''}');
      if (i < flashcards.length - 1) buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  static String _generateFlashcardsHTML(String topic, List<Map<String, String>> flashcards) {
    final colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', 
      '#FECA57', '#FF9FF3', '#54A0FF', '#5F27CD'
    ];
    
    final buffer = StringBuffer();
    
    buffer.write('''
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px;">
  <style>
    .flashcard-container {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 20px;
      margin: 20px 0;
    }
    
    .flashcard {
      perspective: 1000px;
      height: 200px;
      cursor: pointer;
    }
    
    .flashcard-inner {
      position: relative;
      width: 100%;
      height: 100%;
      text-align: center;
      transition: transform 0.6s;
      transform-style: preserve-3d;
      border-radius: 15px;
      box-shadow: 0 8px 25px rgba(0,0,0,0.15);
    }
    
    .flashcard:hover .flashcard-inner {
      transform: rotateY(180deg);
    }
    
    .flashcard-front, .flashcard-back {
      position: absolute;
      width: 100%;
      height: 100%;
      backface-visibility: hidden;
      border-radius: 15px;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
      box-sizing: border-box;
      color: white;
      font-weight: 500;
      text-shadow: 0 2px 4px rgba(0,0,0,0.3);
    }
    
    .flashcard-back {
      transform: rotateY(180deg);
      font-size: 14px;
      line-height: 1.4;
    }
    
    .topic-header {
      text-align: center;
      margin-bottom: 30px;
      padding: 20px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border-radius: 15px;
      box-shadow: 0 8px 25px rgba(0,0,0,0.15);
    }
    
    .instructions {
      background: #f8f9fa;
      padding: 15px;
      border-radius: 10px;
      margin-bottom: 20px;
      border-left: 4px solid #4ECDC4;
      font-size: 14px;
      color: #555;
    }
    
    .flashcard-counter {
      position: absolute;
      top: 10px;
      right: 15px;
      background: rgba(255,255,255,0.3);
      padding: 5px 10px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: bold;
    }
  </style>
  
  <div class="topic-header">
    <h1 style="margin: 0; font-size: 28px;">📚 Flashcards</h1>
    <p style="margin: 10px 0 0 0; opacity: 0.9; font-size: 18px;">$topic</p>
  </div>
  
  <div class="instructions">
    <strong>💡 How to use:</strong> Hover over each card to flip it and see the answer. Perfect for quick review and memorization!
  </div>
  
  <div class="flashcard-container">
''');
    
    for (int i = 0; i < flashcards.length; i++) {
      final card = flashcards[i];
      final color = colors[i % colors.length];
      
      buffer.write('''
    <div class="flashcard">
      <div class="flashcard-inner">
        <div class="flashcard-front" style="background: linear-gradient(135deg, $color, ${_darkenColor(color)});">
          <div class="flashcard-counter">${i + 1}/${flashcards.length}</div>
          <p style="margin: 0; font-size: 16px; font-weight: 600;">${_escapeHtml(card['front'] ?? '')}</p>
        </div>
        <div class="flashcard-back" style="background: linear-gradient(135deg, ${_darkenColor(color)}, $color);">
          <div class="flashcard-counter">${i + 1}/${flashcards.length}</div>
          <p style="margin: 0;">${_escapeHtml(card['back'] ?? '').replaceAll('\n', '<br>')}</p>
        </div>
      </div>
    </div>
''');
    }
    
    buffer.write('''
  </div>
  
  <div style="text-align: center; margin-top: 30px; padding: 20px; background: #f8f9fa; border-radius: 10px;">
    <p style="margin: 0; color: #666; font-size: 14px;">
      🎯 <strong>Study Tip:</strong> Review these cards multiple times throughout the week for better retention!
    </p>
  </div>
</div>
''');
    
    return buffer.toString();
  }
  
  static String _darkenColor(String color) {
    // Simple color darkening - remove # and convert to darker shade
    final hex = color.replaceAll('#', '');
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    
    final darkerR = (r * 0.8).round().clamp(0, 255);
    final darkerG = (g * 0.8).round().clamp(0, 255);
    final darkerB = (b * 0.8).round().clamp(0, 255);
    
    return '#${darkerR.toRadixString(16).padLeft(2, '0')}${darkerG.toRadixString(16).padLeft(2, '0')}${darkerB.toRadixString(16).padLeft(2, '0')}';
  }
  
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }
}