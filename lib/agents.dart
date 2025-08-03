import 'dart:convert';
import 'dart:io';


/// External Agents Service
/// Coordinates all AI agents and capabilities
class AgentsService {
  

  

  

  
    /// Process agent requests from AI
  /// Analyzes AI response and triggers appropriate agents
  static Future<String?> processAgentRequest(String message, String aiResponse) async {
    try {
      // Flashcard functionality has been removed
      // This function is kept for future agent integrations
      return null;
    } catch (e) {
      print('❌ AGENTS: Error processing agent request: $e');
      return null;
    }
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

🎯 **NATURAL USAGE:**
- Use direct WordPress screenshots when discussing websites
- The app's markdown rendering will display all content properly
- Focus on being helpful with visual and educational content

**Make learning visual and interactive!** 🌐📚✨''';
  }
}