import 'dart:convert';
import 'package:http/http.dart' as http;
import 'agents/web_search_agent.dart';

/// External Agents Service
/// Coordinates all AI agents and capabilities
class AgentsService {
  
  /// Process agent requests based on user input and AI response
  static Future<String?> processAgentRequest(String message, String aiResponse) async {
    try {
      // Always check if AI needs current web search data using smart detection
      if (await _needsWebSearchSmart(message)) {
        String searchQuery = _extractSearchQuery(message, '');
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

  /// Smart AI-driven detection for when current data is needed
  static Future<bool> _needsWebSearchSmart(String message) async {
    try {
      final request = http.Request('POST', Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ahamaibyprakash25',
      });

      final currentTime = DateTime.now().toIso8601String();
      
      request.body = json.encode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content': '''You are a web search decision engine. Your ONLY job is to determine if a user query requires current/live web data.

Current date/time: $currentTime

Respond with EXACTLY one word: "YES" or "NO"

Respond "YES" for:
- Current events, breaking news, recent happenings
- Live data: weather, stock prices, sports scores, crypto prices
- Recent developments in technology, politics, business
- Trending topics, viral content, social media trends
- Product launches, updates, or reviews from recent months
- Travel conditions, flight status, traffic updates
- Academic papers, research published recently
- Health/medical updates, COVID-19 info, disease outbreaks
- Legal developments, court decisions, new laws
- Entertainment: recent movies, shows, celebrity news
- Shopping: current deals, product availability, pricing

Respond "NO" for:
- Historical facts, established knowledge
- General how-to questions or explanations
- Educational content about established concepts
- Programming/technical tutorials (unless about very recent frameworks)
- Mathematical calculations or scientific principles
- Personal advice or opinions
- Creative writing or storytelling
- Language translation or grammar questions'''
          },
          {
            'role': 'user',
            'content': message
          }
        ],
        'max_tokens': 1,
        'temperature': 0
      });

      final response = await http.Client().send(request);
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseBody);
        final decision = jsonResponse['choices']?[0]?['message']?['content']?.toString().trim().toUpperCase();
        
        print('🤖 SMART SEARCH DECISION: "$message" -> $decision');
        return decision == 'YES';
      }
    } catch (e) {
      print('❌ SMART SEARCH: Error in smart detection: $e');
      // Fallback to simple keyword detection
      return _containsCurrentDataKeywords(message);
    }
    
    return false;
  }

  /// Fallback keyword detection
  static bool _containsCurrentDataKeywords(String message) {
    final currentKeywords = [
      'latest', 'recent', 'current', 'now', 'today', 'news', 'breaking',
      'price', 'weather', 'trending', 'update', 'new', '2024', '2025'
    ];
    final lowerMessage = message.toLowerCase();
    return currentKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// Extract search query from user message
  static String _extractSearchQuery(String message, String aiResponse) {
    // Clean and return the user message as search query
    String query = message.trim();
    
    // Remove common question words and clean up
    query = query.replaceAll(RegExp(r'\b(what|how|when|where|why|who|tell me about|explain|show me|find|search for)\b', caseSensitive: false), '');
    query = query.replaceAll(RegExp(r'[?.,!]'), '');
    query = query.trim();
    
    return query.isNotEmpty ? query : message;
  }

  /// Get system prompt addition for AI context
  static String getSystemPromptAddition() {
    final currentTime = DateTime.now().toIso8601String();
    
    return '''

🤖 **AI CAPABILITIES & DATA SOURCES:**

⏰ **CURRENT TIME CONTEXT:**
Current date and time: $currentTime
Use this timestamp to understand the temporal context of user queries and determine if information might be outdated.

📸 **DIRECT SCREENSHOT GENERATION:**
- You can show website screenshots directly using WordPress mshots service
- Use this format: `![Screenshot](https://s.wordpress.com/mshots/v1/https%3A%2F%2Fwww.google.com)`
- Example URL encoding: `google.com` becomes `https%3A%2F%2Fwww.google.com`
- Always URL-encode the target website properly
- Show screenshots when discussing websites, demonstrating tools, or explaining web concepts

🌐 **CURRENT WEB SEARCH DATA:**
- When you receive web search results, they represent LIVE, CURRENT data from the internet
- You MUST prioritize and use ONLY the current web search results when they are provided
- Web search results will appear in your context with format: **WEB_SEARCH_DATA_START** ... **WEB_SEARCH_DATA_END**
- NEVER use outdated information from your training data when current web search results are available
- Always mention when you're using current web search data vs. your training knowledge
- Web search includes: latest news, current prices, recent events, trending topics, real-time data

🎯 **DATA PRIORITY RULES:**
1. **FIRST PRIORITY**: Current web search results (if provided) - these are live, recent data
2. **SECOND PRIORITY**: Your training knowledge (only for non-time-sensitive topics)
3. **Always indicate your data source** to users (current web search vs. training data)
4. **Be transparent**: If information might be outdated, tell users you'll search for current data

📊 **SEARCH RESULT INTEGRATION:**
- Web search provides: Web results, Images, Videos
- Each category shows 15 results with full details
- Results include thumbnails, descriptions, timestamps, sources
- All results are clickable and lead to original sources

**Use current data when available, be transparent about your sources, and prioritize fresh information!** 🌐📊✨''';
  }
}