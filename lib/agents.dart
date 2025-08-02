import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// External Agents Service
/// Provides AI with external tools and capabilities
class AgentsService {
  static const String _wordpressPreviewUrl = 'https://s.wordpress.com/mshots/v1/';
  
  /// Screenshot generation agent using WordPress preview service
  /// Takes a URL and returns a screenshot image URL
  static Future<String?> generateScreenshot(String url) async {
    try {
      // Validate URL
      if (!_isValidUrl(url)) {
        print('🚫 AGENTS: Invalid URL provided: $url');
        return null;
      }
      
      // Clean and encode the URL
      String cleanUrl = url.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      
      // Generate screenshot URL using WordPress service
      // Format: https://s.wordpress.com/mshots/v1/{encoded_url}?w=1200&h=800
      final encodedUrl = Uri.encodeComponent(cleanUrl);
      final screenshotUrl = '${_wordpressPreviewUrl}$encodedUrl?w=1200&h=800';
      
      print('🎨 AGENTS: Generated screenshot URL for $cleanUrl');
      print('🔗 AGENTS: Screenshot URL: $screenshotUrl');
      
      // Test if the screenshot service responds
      final response = await http.head(Uri.parse(screenshotUrl));
      if (response.statusCode == 200) {
        return screenshotUrl;
      } else {
        print('🚫 AGENTS: Screenshot service returned ${response.statusCode}');
        return null;
      }
      
    } catch (e) {
      print('❌ AGENTS: Error generating screenshot: $e');
      return null;
    }
  }
  
  /// Process agent requests from AI
  /// Analyzes the AI's message and determines if any agents should be triggered
  static Future<String?> processAgentRequest(String message, String aiResponse) async {
    try {
      // Check if AI is trying to show a website or generate a screenshot
      if (_shouldGenerateScreenshot(aiResponse)) {
        final url = _extractUrlFromResponse(aiResponse);
        if (url != null) {
          print('🤖 AGENTS: AI requesting screenshot for: $url');
          final screenshotUrl = await generateScreenshot(url);
          
          if (screenshotUrl != null) {
            // Return markdown image syntax for the screenshot
            return '\n\n![Website Screenshot]($screenshotUrl)\n\n*Screenshot of $url*';
          }
        }
      }
      
      return null;
    } catch (e) {
      print('❌ AGENTS: Error processing agent request: $e');
      return null;
    }
  }
  
  /// Check if the AI response indicates a screenshot should be generated
  static bool _shouldGenerateScreenshot(String response) {
    final lowerResponse = response.toLowerCase();
    
    // Look for screenshot indicators
    final screenshotKeywords = [
      'screenshot',
      'preview',
      'show you',
      'take a look',
      'here\'s what',
      'website looks like',
      'visual preview',
      'see the site',
      'capture of',
      'image of the site'
    ];
    
    // Look for URL patterns
    final urlPattern = RegExp(r'https?://[^\s]+|www\.[^\s]+|\b[a-zA-Z0-9-]+\.[a-zA-Z]{2,}\b');
    
    return screenshotKeywords.any((keyword) => lowerResponse.contains(keyword)) &&
           urlPattern.hasMatch(response);
  }
  
  /// Extract URL from AI response
  static String? _extractUrlFromResponse(String response) {
    // Match various URL patterns
    final urlPatterns = [
      RegExp(r'https?://[^\s\)]+'), // Full URLs
      RegExp(r'www\.[^\s\)]+'), // www URLs
      RegExp(r'\b[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/[^\s\)]*)?'), // Domain URLs
    ];
    
    for (final pattern in urlPatterns) {
      final match = pattern.firstMatch(response);
      if (match != null) {
        String url = match.group(0)!;
        
        // Clean up the URL
        url = url.replaceAll(RegExp(r'[,.\)]+$'), ''); // Remove trailing punctuation
        
        if (_isValidUrl(url)) {
          return url;
        }
      }
    }
    
    return null;
  }
  
  /// Validate if a string is a valid URL
  static bool _isValidUrl(String url) {
    try {
      String testUrl = url;
      if (!testUrl.startsWith('http://') && !testUrl.startsWith('https://')) {
        testUrl = 'https://$testUrl';
      }
      
      final uri = Uri.parse(testUrl);
      return uri.hasScheme && uri.hasAuthority && uri.host.contains('.');
    } catch (e) {
      return false;
    }
  }
  
  /// Get system prompt addition for agents functionality
  static String getSystemPromptAddition() {
    return '''

🤖 **EXTERNAL AGENTS & TOOLS:**

📸 **SCREENSHOT GENERATION:**
- You have access to an intelligent screenshot generation agent
- When users ask about websites, want to see how sites look, or you mention specific URLs, the system can automatically generate screenshots
- Simply mention websites naturally in your responses - the agent will detect and capture them automatically
- Examples that trigger screenshots:
  - "Let me show you how GitHub looks"
  - "Here's a preview of that website"
  - "Take a look at google.com"
  - "The site reddit.com has an interesting design"
- NO special commands needed - just be natural and mention URLs when relevant
- Screenshots will be embedded directly in your response as images
- This works for any public website or domain

🎯 **NATURAL USAGE:**
- Don't announce the screenshot feature unless specifically asked
- Use it naturally when discussing websites, tools, or online resources
- The system automatically detects when screenshots would be helpful
- Focus on being helpful - the technical magic happens behind the scenes

**Be natural and mention websites when they're relevant to help users!** 🌐✨''';
  }
}