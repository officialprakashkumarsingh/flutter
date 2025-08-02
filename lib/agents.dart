import 'dart:convert';
import 'dart:io';
import 'agents/flashcard_agent.dart';

/// External Agents Service
/// Coordinates all AI agents and capabilities
class AgentsService {
  

  

  

  
    /// Process agent requests from AI
  /// Analyzes AI response and triggers appropriate agents
  static Future<String?> processAgentRequest(String message, String aiResponse) async {
    try {
      // Check if AI is trying to generate flashcards
      if (aiResponse.toLowerCase().contains('generate flashcards') ||
          aiResponse.toLowerCase().contains('create flashcards') ||
          aiResponse.toLowerCase().contains('flashcard') ||
          (aiResponse.toLowerCase().contains('study') && aiResponse.toLowerCase().contains('cards'))) {
        
        // Extract topic from message or AI response
        String topic = _extractFlashcardTopic(message, aiResponse);
        if (topic.isNotEmpty) {
          print('🎓 AGENTS: Generating flashcards for topic: $topic');
          final result = await FlashcardAgent.generateFlashcards(topic);
          if (result != null) {
            return result;
          }
        }
      }
        
      return null;
    } catch (e) {
      print('❌ AGENTS: Error processing agent request: $e');
      return null;
    }
  }
  
  /// Extract flashcard topic from user message or AI response
  static String _extractFlashcardTopic(String message, String aiResponse) {
    // Try to extract topic from user message first
    final messageWords = message.toLowerCase().split(' ');
    
    // Look for common flashcard trigger phrases
    final flashcardTriggers = [
      'flashcards for',
      'flashcards on',
      'flashcards about',
      'study cards for',
      'study cards on',
      'create flashcards',
      'generate flashcards',
      'make flashcards'
    ];
    
    for (final trigger in flashcardTriggers) {
      final triggerIndex = message.toLowerCase().indexOf(trigger);
      if (triggerIndex != -1) {
        final afterTrigger = message.substring(triggerIndex + trigger.length).trim();
        if (afterTrigger.isNotEmpty) {
          // Take first few words as topic
          final topicWords = afterTrigger.split(' ').take(5).join(' ');
          return topicWords.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        }
      }
    }
    
    // If no specific trigger found, try to extract subject/topic from the message
    final educationalKeywords = [
      'math', 'algebra', 'geometry', 'calculus', 'trigonometry',
      'science', 'biology', 'chemistry', 'physics', 'astronomy',
      'history', 'geography', 'literature', 'english', 'grammar',
      'computer science', 'programming', 'economics', 'psychology',
      'philosophy', 'art', 'music', 'language', 'french', 'spanish'
    ];
    
    for (final keyword in educationalKeywords) {
      if (message.toLowerCase().contains(keyword)) {
        return keyword;
      }
    }
    
    // Last resort: take the main subject from the message
    final words = message.split(' ');
    if (words.length > 2) {
      return words.skip(1).take(3).join(' ').replaceAll(RegExp(r'[^\w\s]'), '').trim();
    }
    
    return 'General Study Topics';
  }
  

  

  

  
  /// Get system prompt addition for agents functionality
  static String getSystemPromptAddition() {
    return '''

🤖 **AI VISUAL & EDUCATIONAL CAPABILITIES:**

📸 **DIRECT SCREENSHOT GENERATION:**
- You can show website screenshots directly using WordPress mshots service
- Use this format: `![Screenshot](https://s.wordpress.com/mshots/v1/https%3A%2F%2Fwww.google.com)`
- Example URL encoding: `google.com` becomes `https%3A%2F%2Fwww.google.com`
- Full example: `![Google Screenshot](https://s.wordpress.com/mshots/v1/https%3A%2F%2Fwww.google.com)`
- Always URL-encode the target website properly
- This works for any public website - the app supports markdown image rendering
- Show screenshots when discussing websites, demonstrating tools, or explaining web concepts

📚 **FLASHCARD GENERATION FOR STUDENTS:**
- You can create beautiful, interactive flashcards for any study topic
- When users ask for flashcards, study cards, or educational content, mention "generate flashcards"
- Supports subjects like: Math, Science, History, English, Programming, Languages, etc.
- Example triggers: "I'll generate flashcards for [topic]" or "Let me create flashcards about [subject]"
- The app will automatically detect and create colorful, interactive flashcards with:
  • Hover-to-flip animation
  • Beautiful gradient colors
  • Educational content tailored to the topic
  • Study tips and memory techniques
  • Mobile-friendly responsive design

🎯 **NATURAL USAGE:**
- Use direct WordPress screenshots when discussing websites
- Mention "generate flashcards" when students need study materials
- The app's markdown rendering will display all content properly
- Focus on being helpful with visual and educational content

🌟 **STUDENT-FRIENDLY FEATURES:**
- Flashcards cover key concepts, definitions, formulas, and facts
- Include study tips and memory techniques
- Support for all academic subjects
- Beautiful, engaging visual design to improve learning

**Make learning visual and interactive!** 🌐📚✨''';
  }
}