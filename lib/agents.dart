import 'dart:convert';
import 'dart:io';
import 'agents/curl_agent.dart';

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
      
      // Site status agent removed as requested
      
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

🌐 **ADVANCED CURL EXECUTION:**
- You have access to an enterprise-grade curl agent with full HTTP capabilities
- Simply mention curl commands naturally - the system detects and executes them automatically
- **Enhanced Features:**
  - Bearer token auto-detection: "Use bearer token abc123" or "Authorization: Bearer abc123"
  - Basic auth support: curl -u username:password
  - Advanced headers: -H "Content-Type: application/json"
  - Data formats: -d, --data-raw, --data-binary
  - User agents: -A "Custom-Agent/1.0"
  - Redirects: -L flag support
  - Quoted arguments and special characters handling
- **Smart Analysis:**
  - Security header detection and analysis
  - Performance metrics (compression, caching)
  - Content type detection (JSON, XML, HTML)
  - Response size analysis and optimization tips
  - Authentication method identification
- **Example Advanced Usage:**
  - "curl -H 'Authorization: Bearer sk-abc123' https://api.openai.com/v1/models"
  - "curl -X POST -d '{\"test\":\"data\"}' https://httpbin.org/post"
  - "Execute curl with bearer token xyz789: curl https://api.github.com/user"



🎯 **NATURAL USAGE:**
- Use direct WordPress screenshots when discussing websites
- Mention curl commands when demonstrating APIs or HTTP requests
- The app's markdown rendering will display all content properly
- All agents work automatically based on your natural conversation

**Use these powerful agents to make your responses more helpful and interactive!** 🌐🔧✨''';
  }
}