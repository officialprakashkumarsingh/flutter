import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// External Agents Service
/// Provides AI with external tools and capabilities
class AgentsService {
  static const String _wordpressPreviewUrl = 'https://s.wordpress.com/mshots/v1/';
  static const String _plantumlUrl = 'https://www.plantuml.com/plantuml/png/';
  
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
      
      // WordPress screenshots are always available - no need to test
      return screenshotUrl;
      
    } catch (e) {
      print('❌ AGENTS: Error generating screenshot: $e');
      return null;
    }
  }
  
  /// Diagram generation agent using PlantUML service
  /// Takes PlantUML code and returns a diagram image URL
  static Future<String?> generateDiagram(String plantumlCode) async {
    try {
      // Validate PlantUML code
      if (plantumlCode.trim().isEmpty) {
        print('🚫 AGENTS: Empty PlantUML code provided');
        return null;
      }
      
      // Clean the PlantUML code
      String cleanCode = plantumlCode.trim();
      
      // Add @startuml/@enduml if not present
      if (!cleanCode.startsWith('@start')) {
        if (!cleanCode.startsWith('@startuml')) {
          cleanCode = '@startuml\n$cleanCode\n@enduml';
        }
      }
      
      // Encode PlantUML code using PlantUML encoding
      final encodedCode = _encodePlantUML(cleanCode);
      if (encodedCode == null) {
        print('🚫 AGENTS: Failed to encode PlantUML code');
        return null;
      }
      
      // Generate diagram URL using direct encoding
      final diagramUrl = '$_plantumlUrl$encodedCode';
      
      print('📊 AGENTS: Generated diagram URL for PlantUML code');
      print('🔗 AGENTS: Diagram URL: $diagramUrl');
      
      // Return diagram URL directly - PlantUML service is reliable
      return diagramUrl;
      
    } catch (e) {
      print('❌ AGENTS: Error generating diagram: $e');
      return null;
    }
  }
  
  /// Encode PlantUML code for URL using base64 encoding
  static String? _encodePlantUML(String plantuml) {
    try {
      // Simple base64 encoding for PlantUML
      final bytes = utf8.encode(plantuml);
      final base64String = base64Encode(bytes);
      
      // URL-safe base64 encoding
      final encoded = base64String
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '');
      
      return encoded;
    } catch (e) {
      print('❌ AGENTS: Error encoding PlantUML: $e');
      return null;
    }
  }
  
  /// Process agent requests from AI
  /// Analyzes the AI's message and determines if any agents should be triggered
  static Future<String?> processAgentRequest(String message, String aiResponse) async {
    try {
      String? result;
      
      // Check for diagram generation first
      if (_shouldGenerateDiagram(aiResponse)) {
        final plantumlCode = _extractPlantUMLFromResponse(aiResponse);
        if (plantumlCode != null) {
          print('🤖 AGENTS: AI requesting diagram generation');
          final diagramUrl = await generateDiagram(plantumlCode);
          
                     if (diagramUrl != null) {
             result = '\n\n![Generated Diagram]($diagramUrl)';
           }
        }
      }
      
      // Check for screenshot generation
      if (result == null && _shouldGenerateScreenshot(aiResponse)) {
        final url = _extractUrlFromResponse(aiResponse);
        if (url != null) {
          print('🤖 AGENTS: AI requesting screenshot for: $url');
          final screenshotUrl = await generateScreenshot(url);
          
                     if (screenshotUrl != null) {
             result = '\n\n![Website Screenshot]($screenshotUrl)';
           }
        }
      }
      
      return result;
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
  
  /// Check if the AI response indicates a diagram should be generated
  static bool _shouldGenerateDiagram(String response) {
    final lowerResponse = response.toLowerCase();
    
    // Look for diagram indicators
    final diagramKeywords = [
      'diagram',
      'flowchart',
      'chart',
      'graph',
      'uml',
      'sequence diagram',
      'class diagram',
      'activity diagram',
      'use case',
      'mind map',
      'workflow',
      'process flow',
      'architecture',
      'visual representation',
      'plantuml'
    ];
    
    return diagramKeywords.any((keyword) => lowerResponse.contains(keyword));
  }
  
  /// Extract PlantUML code from AI response
  static String? _extractPlantUMLFromResponse(String response) {
    // Look for code blocks with plantuml, uml, or diagram
    final codeBlockPatterns = [
      RegExp(r'```(?:plantuml|uml|diagram)\s*\n(.*?)\n```', multiLine: true, dotAll: true),
      RegExp(r'```\s*\n(@startuml.*?@enduml)\s*\n```', multiLine: true, dotAll: true),
    ];
    
    for (final pattern in codeBlockPatterns) {
      final match = pattern.firstMatch(response);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    
    // Look for inline PlantUML syntax
    final inlinePattern = RegExp(r'@startuml.*?@enduml', multiLine: true, dotAll: true);
    final inlineMatch = inlinePattern.firstMatch(response);
    if (inlineMatch != null) {
      return inlineMatch.group(0);
    }
    
    // If no explicit PlantUML found but diagram keywords present, generate simple flowchart
    if (_shouldGenerateDiagram(response)) {
      // Extract potential process steps or items for auto-diagram generation
      final lines = response.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.trim())
          .toList();
      
      if (lines.length > 1) {
        // Create a simple flowchart from the response
        final steps = <String>[];
        for (int i = 0; i < lines.length && i < 5; i++) {
          final line = lines[i];
          if (line.length > 10 && !line.startsWith('```')) {
            steps.add(line.replaceAll(RegExp(r'[^\w\s]'), '').trim());
          }
        }
        
        if (steps.length >= 2) {
          final flowchart = steps.map((step) => 'rectangle "$step"').join('\n');
          return '@startuml\n$flowchart\n@enduml';
        }
      }
    }
    
    return null;
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
- You have access to an intelligent screenshot generation agent using WordPress preview
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

📊 **DIAGRAM GENERATION:**
- You have access to an intelligent PlantUML diagram generation agent
- When discussing processes, workflows, architectures, or when users ask for visual representations, you can create diagrams automatically
- Simply mention diagram-related concepts naturally - the system will detect and generate appropriate diagrams
- Examples that trigger diagrams:
  - "Here's a flowchart of the process"
  - "Let me create a diagram to show this"
  - "The workflow looks like this"
  - "Here's the architecture diagram"
- You can also include explicit PlantUML code in code blocks:
  ```plantuml
  @startuml
  A --> B: Process
  B --> C: Complete
  @enduml
  ```
- Diagrams will be embedded directly in your response as images
- Supports flowcharts, UML diagrams, sequence diagrams, class diagrams, and more

🎯 **NATURAL USAGE:**
- Don't announce these features unless specifically asked
- Use them naturally when discussing websites, processes, or visual concepts
- The system automatically detects when screenshots or diagrams would be helpful
- Focus on being helpful - the technical magic happens behind the scenes

**Be natural and mention websites or visual concepts when they're relevant to help users!** 🌐📊✨''';
  }
}