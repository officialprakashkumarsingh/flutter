import 'dart:convert';
import 'agents/web_search_agent.dart';

class AgentsService {
  /// Process agent requests based on AI response (AI decides when to use tools)
  static Future<String?> processAgentRequest(String message, String aiResponse) async {
    try {
      // Check if AI is requesting web search in its response
      if (_isWebSearchRequested(aiResponse)) {
        String searchQuery = _extractSearchQuery(message, aiResponse);
        if (searchQuery.isNotEmpty) {
          print('🌐 AGENTS: AI requested web search for: $searchQuery');
          final result = await WebSearchAgent.performWebSearch(searchQuery);
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

  /// Check if AI is requesting web search in its response
  static bool _isWebSearchRequested(String aiResponse) {
    final webSearchIndicators = [
      'search for',
      'let me search',
      'searching for',
      'web search',
      'look up',
      'find current',
      'get latest',
      'check for updates',
      'search the web',
      'find information about'
    ];
    
    final lowerResponse = aiResponse.toLowerCase();
    return webSearchIndicators.any((indicator) => lowerResponse.contains(indicator));
  }

  /// Extract search query from user message or AI response
  static String _extractSearchQuery(String message, String aiResponse) {
    // Try to extract from AI response first
    final lowerResponse = aiResponse.toLowerCase();
    
    // Look for patterns like "search for X" or "searching for X"
    final searchPatterns = [
      r'search(?:ing)?\s+for\s+["\x27]?([^"\x27.,!?]+)',
      r'look(?:ing)?\s+up\s+["\x27]?([^"\x27.,!?]+)',
      r'find(?:ing)?\s+(?:information\s+about\s+)?["\x27]?([^"\x27.,!?]+)',
      r'get\s+latest\s+(?:information\s+on\s+)?["\x27]?([^"\x27.,!?]+)',
    ];
    
    for (final pattern in searchPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(aiResponse);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    
    // Fallback: clean and return the user message as search query
    String query = message.trim();
    query = query.replaceAll(RegExp(r'\b(what|how|when|where|why|who|tell me about|explain|show me|find|search for)\b', caseSensitive: false), '');
    query = query.replaceAll(RegExp(r'[?.,!]'), '');
    query = query.trim();
    
    return query.isNotEmpty ? query : message;
  }

  /// Get system prompt addition for AI context - includes web search tool availability
  static String getSystemPromptAddition() {
    final currentTime = DateTime.now().toIso8601String();
    
    return '''

🤖 **AI CAPABILITIES & EXTERNAL TOOLS:**

⏰ **CURRENT TIME CONTEXT:**
Current date and time: $currentTime
Use this timestamp to understand the temporal context of user queries.

🌐 **WEB SEARCH TOOL AVAILABLE:**
- You have access to a powerful web search tool for current information
- When you need current, recent, or time-sensitive data, simply mention in your response that you want to search for specific information
- Use phrases like "Let me search for [topic]" or "I'll look up current information about [topic]"
- The search tool will automatically provide: Web results, Images, Videos (up to 15 each)
- You will receive live, current data that you should prioritize over your training knowledge
- **CRITICAL**: NEVER list individual web sources, URLs, or describe search results in detail - they are automatically displayed in a beautiful interactive panel
- **CRITICAL**: Do NOT enumerate sources like "1. Source 1, 2. Source 2" etc. - the panel handles this
- **CRITICAL**: Do NOT describe what the search found - just use the information naturally in your response
- Simply reference the information and let users explore the full results in the interactive panel with Web/Images/Videos tabs

📸 **DIRECT SCREENSHOT GENERATION:**
- You can show website screenshots directly using WordPress mshots service
- Use this format: `![Screenshot](https://s.wordpress.com/mshots/v1/https%3A%2F%2Fwww.google.com)`
- Example URL encoding: `google.com` becomes `https%3A%2F%2Fwww.google.com`
- Always URL-encode the target website properly
- Show screenshots when discussing websites, demonstrating tools, or explaining web concepts

🎯 **DATA PRIORITY RULES:**
1. **FIRST PRIORITY**: Current web search results (when you request them)
2. **SECOND PRIORITY**: Your training knowledge (for established facts)
3. **Always indicate your data source** to users (current web search vs. training data)
4. **Be proactive**: If you think current data would be helpful, request a web search

📊 **WHEN TO USE WEB SEARCH:**
- Current events, breaking news, recent developments
- Live data: weather, stock prices, sports scores, crypto prices
- Recent product launches, technology updates, trending topics
- Current prices, availability, reviews
- Recent academic papers, research, medical updates
- Travel conditions, flight status, traffic updates
- Legal developments, court decisions, new laws
- Entertainment: recent movies, shows, celebrity news

**Example Usage:**
User: "What's the latest news about Tesla?"
You: "Let me search for the latest Tesla news to get you current information."
[Tool will then provide current search results]

**Use the web search tool proactively when current information would benefit the user!** 🌐📊✨''';
  }
}