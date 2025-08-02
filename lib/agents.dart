import 'dart:convert';
import 'dart:io';
import 'agents/web_search_agent.dart';

/// External Agents Service
/// Coordinates all AI agents and capabilities
class AgentsService {
  
  /// Process agent requests from AI
  /// Analyzes AI response and triggers appropriate agents
  static Future<String?> processAgentRequest(String message, String aiResponse) async {
    try {
      // Check if AI needs current web search data
      if (_needsWebSearch(message, aiResponse)) {
        String searchQuery = _extractSearchQuery(message, aiResponse);
        if (searchQuery.isNotEmpty) {
          print('🌐 AGENTS: Performing web search for: $searchQuery');
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

  /// Determine if the query needs current web search data
  static bool _needsWebSearch(String message, String aiResponse) {
    final currentDataIndicators = [
      'current', 'latest', 'recent', 'today', 'now', 'this year', '2024', '2025',
      'what is happening', 'what\'s happening', 'news', 'update', 'breaking',
      'price', 'stock', 'weather', 'forecast', 'live', 'real-time',
      'trending', 'popular', 'viral', 'search for', 'find information',
      'look up', 'research', 'web search', 'google'
    ];
    
    final timeSensitiveTopics = [
      'cryptocurrency', 'crypto', 'bitcoin', 'stock market', 'stocks',
      'weather', 'news', 'events', 'sports scores', 'election',
      'technology news', 'tech news', 'product launch', 'release date'
    ];
    
    final lowerMessage = message.toLowerCase();
    final lowerResponse = aiResponse.toLowerCase();
    
    // Check if message contains current data indicators
    for (final indicator in currentDataIndicators) {
      if (lowerMessage.contains(indicator)) {
        return true;
      }
    }
    
    // Check if topic is time-sensitive
    for (final topic in timeSensitiveTopics) {
      if (lowerMessage.contains(topic)) {
        return true;
      }
    }
    
    // Check if AI response suggests it needs current data
    if (lowerResponse.contains('i don\'t have current') ||
        lowerResponse.contains('my knowledge cutoff') ||
        lowerResponse.contains('as of my last update') ||
        lowerResponse.contains('outdated') ||
        lowerResponse.contains('may have changed')) {
      return true;
    }
    
    return false;
  }

  /// Extract search query from user message or AI response
  static String _extractSearchQuery(String message, String aiResponse) {
    // Clean up the message by removing common prefixes
    String query = message;
    
    // Remove common question starters
    query = query.replaceAll(RegExp(r'^(what|how|when|where|why|who|can you|please|could you)\s+', caseSensitive: false), '');
    query = query.replaceAll(RegExp(r'^(tell me|show me|find|search|look up|get|give me)\s+', caseSensitive: false), '');
    query = query.replaceAll(RegExp(r'^(about|for|the)\s+', caseSensitive: false), '');
    
    // Remove question marks and extra spaces
    query = query.replaceAll('?', '').trim();
    
    // If query is too short, use the original message
    if (query.length < 3) {
      query = message.replaceAll('?', '').trim();
    }
    
    // Limit length for search
    if (query.length > 100) {
      query = query.substring(0, 100);
    }
    
    return query;
  }
  
  /// Get system prompt addition for agents functionality
  static String getSystemPromptAddition() {
    return '''

🤖 **AI CAPABILITIES & DATA SOURCES:**

📸 **DIRECT SCREENSHOT GENERATION:**
- You can show website screenshots directly using WordPress mshots service
- Use this format: `![Screenshot](https://s.wordpress.com/mshots/v1/https%3A%2F%2Fwww.google.com)`
- Example URL encoding: `google.com` becomes `https%3A%2F%2Fwww.google.com`
- Always URL-encode the target website properly
- Show screenshots when discussing websites, demonstrating tools, or explaining web concepts

🌐 **CURRENT WEB SEARCH DATA:**
- When users ask for current, recent, or time-sensitive information, the app will automatically fetch live web search results
- You MUST prioritize and use ONLY the current web search results when they are provided
- Web search results will appear in your context with format: **WEB_SEARCH_DATA_START** ... **WEB_SEARCH_DATA_END**
- NEVER use outdated information from your training data when current web search results are available
- Always mention when you're using current web search data vs. your training knowledge
- Web search includes: latest news, current prices, recent events, trending topics, real-time data

🎯 **DATA PRIORITY RULES:**
1. **FIRST PRIORITY**: Current web search results (if provided)
2. **SECOND PRIORITY**: Your training knowledge (only for non-time-sensitive topics)
3. **Always indicate your data source** to users (current web search vs. training data)

🔍 **TRIGGERS FOR WEB SEARCH:**
- Current events, news, prices, weather, sports scores
- "Latest", "recent", "current", "today", "now", "2024", "2025"
- Stock prices, cryptocurrency, real-time data
- Product launches, technology updates, trending topics

**Use current data when available, be transparent about your sources!** 🌐📊✨''';
  }
}