import 'dart:convert';
import 'dart:io';
import 'agents/curl_agent.dart';
import 'agents/site_status_agent.dart';

/// External Agents Service
/// Coordinates all AI agents and capabilities
class AgentsService {
  

  

  

  
    /// Process agent requests from AI
  /// Analyzes AI response and triggers appropriate agents
  static Future<String?> processAgentRequest(String message, String aiResponse) async {
    try {
      String? result;
      
      // Check for curl command execution
      if (CurlAgent.shouldExecuteCurl(aiResponse)) {
        final curlCommand = CurlAgent.extractCurlCommand(aiResponse);
        if (curlCommand != null) {
          print('🤖 AGENTS: AI requesting curl execution');
          final curlResult = await CurlAgent.executeCurl(curlCommand);
          if (curlResult != null) {
            result = '\n\n$curlResult';
          }
        }
      }
      
      // Check for site status checking (if no curl result)
      if (result == null && SiteStatusAgent.shouldCheckSiteStatus(aiResponse)) {
        final urls = SiteStatusAgent.extractUrlsForStatusCheck(aiResponse);
        if (urls.isNotEmpty) {
          print('🤖 AGENTS: AI requesting site status check for ${urls.length} URLs');
          final statusResults = <String>[];
          
          // Check each URL (limit to 3 to avoid overload)
          for (final url in urls.take(3)) {
            final statusResult = await SiteStatusAgent.checkSiteStatus(url);
            if (statusResult != null) {
              statusResults.add(statusResult);
            }
          }
          
          if (statusResults.isNotEmpty) {
            result = '\n\n${statusResults.join('\n\n---\n\n')}';
          }
        }
      }
      
      return result;
    } catch (e) {
      print('❌ AGENTS: Error processing agent request: $e');
      return null;
    }
  }
  

  

  

  
  /// Get system prompt addition for agents functionality
  static String getSystemPromptAddition() {
    return '''

🤖 **AI AGENT CAPABILITIES:**

📸 **DIRECT SCREENSHOT GENERATION:**
- You can show website screenshots directly using WordPress mshots service
- Use this format: `![Screenshot](https://s.wordpress.com/mshots/v1/https%3A%2F%2Fwww.google.com)`
- Example URL encoding: `google.com` becomes `https%3A%2F%2Fwww.google.com`
- Full example: `![Google Screenshot](https://s.wordpress.com/mshots/v1/https%3A%2F%2Fwww.google.com)`
- Always URL-encode the target website properly
- This works for any public website - the app supports markdown image rendering
- Show screenshots when discussing websites, demonstrating tools, or explaining web concepts

🌐 **CURL COMMAND EXECUTION:**
- You have access to a curl agent that can execute HTTP requests safely
- Simply mention curl commands naturally in your responses - the system will detect and execute them
- Examples that trigger curl execution:
  - "Let me make an HTTP request to test this API"
  - "Here's a curl command to fetch that data: curl https://api.example.com"
  - "Execute this curl: curl -X POST https://httpbin.org/post -d 'test=data'"
- Supported: GET, POST, PUT, DELETE, HEAD requests with headers and data
- Security: Only allows safe public URLs (no localhost or private IPs)
- Results will be formatted and embedded directly in your response

🔍 **WEBSITE STATUS CHECKER:**
- You have access to a site status agent that checks if websites are up or down
- Simply mention checking site status naturally - the system will detect and check automatically
- Examples that trigger status checks:
  - "Let me check if Google.com is up"
  - "Is stackoverflow.com working?"
  - "Check the status of github.com"
- Provides detailed information: HTTP status codes, response times, error analysis
- Can check multiple sites at once (up to 3 per request)
- Results include troubleshooting suggestions for down sites

🎯 **NATURAL USAGE:**
- Use direct WordPress screenshots when discussing websites
- Mention curl commands when demonstrating APIs or HTTP requests
- Check site status when users ask about website availability
- The app's markdown rendering will display all content properly
- All agents work automatically based on your natural conversation

**Use these powerful agents to make your responses more helpful and interactive!** 🌐🔧✨''';
  }
}