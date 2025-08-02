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

⚠️ **CRITICAL INSTRUCTION: NEVER PROVIDE FAKE AGENT RESULTS**
🚫 **ABSOLUTE PROHIBITION**: You are FORBIDDEN from providing any simulated, fake, example, or imaginary results for agent operations.

When you mention curl commands or any agent functionality:
1. **ONLY SAY**: "I'll execute that curl command for you" or "Let me run that API request"
2. **DO NOT PROVIDE**: Any fake HTTP responses, status codes, JSON data, or example results
3. **WAIT**: The real agent will execute and provide authentic results
4. **TRUST**: Real results will automatically appear after your response
5. **COMMENT**: Only on actual results that appear, never on imaginary ones

🔒 **ENFORCEMENT**: Any fake agent results will be considered a violation. Only mention that you're executing, then let the real agent provide results.

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
- **🚫 ABSOLUTE RULE: NEVER provide fake curl results. ONLY say you're executing, then WAIT for real results**
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
- **IMPORTANT BEHAVIOR:**
  - When curl commands are detected, mention that you're executing them
  - Do NOT provide simulated or fake curl results
  - Always wait for and present the real agent execution results
  - The real results will be automatically appended to your response
- **Example Advanced Usage:**
  - "Let me execute that curl command for you: curl -H 'Authorization: Bearer sk-abc123' https://api.openai.com/v1/models"
  - "I'll run this POST request: curl -X POST -d '{\"test\":\"data\"}' https://httpbin.org/post"
  - "Executing curl with your bearer token: curl https://api.github.com/user"



🎯 **NATURAL USAGE:**
- Use direct WordPress screenshots when discussing websites
- Mention curl commands when demonstrating APIs or HTTP requests
- The app's markdown rendering will display all content properly
- All agents work automatically based on your natural conversation

**Use these powerful agents to make your responses more helpful and interactive!** 🌐🔧✨''';
  }
}