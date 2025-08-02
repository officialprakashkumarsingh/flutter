import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// External Agents Service
/// Provides AI with external tools and capabilities
class AgentsService {
  // Multiple PlantUML services for robustness
  static const List<String> _plantumlServices = [
    'https://www.plantuml.com/plantuml/png/',
    'https://plantuml-server.kkeisuke.dev/png/',
    'https://kroki.io/plantuml/png/',
  ];
  

  
  /// Diagram generation agent using PlantUML service with fallbacks
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
        cleanCode = '@startuml\n$cleanCode\n@enduml';
      }
      
      print('📊 AGENTS: Generating diagram for PlantUML code:');
      print('🔍 AGENTS: Code: $cleanCode');
      
      // Try multiple encoding methods and services
      final encodingMethods = [
        () => _encodePlantUMLDeflate(cleanCode),
        () => _encodePlantUMLSimple(cleanCode),
        () => _encodePlantUMLDirect(cleanCode),
      ];
      
      for (int methodIndex = 0; methodIndex < encodingMethods.length; methodIndex++) {
        final encodedCode = encodingMethods[methodIndex]();
        if (encodedCode == null) continue;
        
        print('🔄 AGENTS: Trying encoding method ${methodIndex + 1}');
        
        // Try each service with this encoding
        for (int serviceIndex = 0; serviceIndex < _plantumlServices.length; serviceIndex++) {
          final service = _plantumlServices[serviceIndex];
          String diagramUrl;
          
          // Different URL formats for different services
          if (service.contains('kroki.io')) {
            diagramUrl = '${service}$encodedCode';
          } else {
            diagramUrl = '${service}$encodedCode';
          }
          
          print('🔗 AGENTS: Trying service ${serviceIndex + 1}: $diagramUrl');
          
          // Test if this combination works
          try {
            final response = await http.head(Uri.parse(diagramUrl)).timeout(const Duration(seconds: 5));
            if (response.statusCode == 200) {
              print('✅ AGENTS: Success with service ${serviceIndex + 1}, method ${methodIndex + 1}');
              return diagramUrl;
            }
          } catch (e) {
            print('❌ AGENTS: Service ${serviceIndex + 1} failed: $e');
            continue;
          }
        }
      }
      
      print('🚫 AGENTS: All PlantUML services and encoding methods failed');
      return null;
      
    } catch (e) {
      print('❌ AGENTS: Error generating diagram: $e');
      return null;
    }
  }
  
  /// PlantUML deflate + base64 encoding (official method)
  static String? _encodePlantUMLDeflate(String plantuml) {
    try {
      // This is the proper PlantUML encoding but requires zlib
      // For now, return null to fall back to other methods
      return null;
    } catch (e) {
      print('❌ AGENTS: Error with deflate encoding: $e');
      return null;
    }
  }
  
  /// Simple base64 encoding for PlantUML
  static String? _encodePlantUMLSimple(String plantuml) {
    try {
      final bytes = utf8.encode(plantuml);
      final base64String = base64Encode(bytes);
      
      // URL-safe base64 encoding
      final encoded = base64String
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '');
      
      return encoded;
    } catch (e) {
      print('❌ AGENTS: Error with simple encoding: $e');
      return null;
    }
  }
  
  /// Direct URL encoding for PlantUML
  static String? _encodePlantUMLDirect(String plantuml) {
    try {
      // Direct URL component encoding
      return Uri.encodeComponent(plantuml);
    } catch (e) {
      print('❌ AGENTS: Error with direct encoding: $e');
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
      
      
      
      return result;
    } catch (e) {
      print('❌ AGENTS: Error processing agent request: $e');
      return null;
    }
  }
  

  
  /// Check if the AI response indicates a diagram should be generated
  static bool _shouldGenerateDiagram(String response) {
    final lowerResponse = response.toLowerCase();
    
    // Look for explicit PlantUML code blocks first
    if (response.contains('@startuml') || 
        RegExp(r'```(?:plantuml|uml|diagram)', caseSensitive: false).hasMatch(response)) {
      return true;
    }
    
    // Look for diagram indicators
    final diagramKeywords = [
      'diagram',
      'flowchart', 
      'flow chart',
      'chart',
      'graph',
      'uml',
      'sequence diagram',
      'class diagram',
      'activity diagram',
      'use case diagram',
      'mind map',
      'workflow',
      'process flow',
      'architecture diagram',
      'visual representation',
      'plantuml',
      'let me create a diagram',
      'here\'s a diagram',
      'show this as a diagram',
      'visualize this',
      'create a visual',
    ];
    
    return diagramKeywords.any((keyword) => lowerResponse.contains(keyword));
  }
  
  /// Extract PlantUML code from AI response
  static String? _extractPlantUMLFromResponse(String response) {
    // Look for code blocks with plantuml, uml, or diagram
    final codeBlockPatterns = [
      RegExp(r'```(?:plantuml|uml|diagram)\s*\n(.*?)\n```', multiLine: true, dotAll: true),
      RegExp(r'```\s*\n(@startuml.*?@enduml)\s*\n```', multiLine: true, dotAll: true),
      RegExp(r'```plantuml\s*(.*?)\s*```', multiLine: true, dotAll: true),
    ];
    
    for (final pattern in codeBlockPatterns) {
      final match = pattern.firstMatch(response);
      if (match != null) {
        final code = match.group(1)?.trim();
        if (code != null && code.isNotEmpty) {
          print('🔍 AGENTS: Found PlantUML code block: $code');
          return code;
        }
      }
    }
    
    // Look for inline PlantUML syntax
    final inlinePattern = RegExp(r'@startuml.*?@enduml', multiLine: true, dotAll: true);
    final inlineMatch = inlinePattern.firstMatch(response);
    if (inlineMatch != null) {
      final code = inlineMatch.group(0);
      print('🔍 AGENTS: Found inline PlantUML: $code');
      return code;
    }
    
    // Generate simple diagram based on response content
    if (_shouldGenerateDiagram(response)) {
      print('🔍 AGENTS: Generating simple diagram from response');
      return _generateSimpleDiagram(response);
    }
    
    return null;
  }
  
  /// Generate a simple PlantUML diagram from response content
  static String _generateSimpleDiagram(String response) {
    final lowerResponse = response.toLowerCase();
    
    // Try to create a simple flowchart
    if (lowerResponse.contains('process') || lowerResponse.contains('step') || lowerResponse.contains('flow')) {
      return '''@startuml
start
:Process Input;
:Analyze Data;
:Generate Output;
stop
@enduml''';
    }
    
    // Try to create a simple class diagram
    if (lowerResponse.contains('class') || lowerResponse.contains('object')) {
      return '''@startuml
class User {
  +name: String
  +email: String
  +login()
}
class System {
  +process()
  +validate()
}
User --> System : uses
@enduml''';
    }
    
    // Default simple diagram
    return '''@startuml
participant User
participant System
User -> System : Request
System -> System : Process
System -> User : Response
@enduml''';
  }
  

  
  /// Get system prompt addition for agents functionality
  static String getSystemPromptAddition() {
    return '''

🤖 **VISUAL CAPABILITIES:**

📸 **DIRECT SCREENSHOT GENERATION:**
- You can show website screenshots directly using WordPress mshots service
- Use this format: `![Screenshot](https://s.wordpress.com/mshots/v1/https%3A%2F%2Fwww.google.com)`
- Example URL encoding: `google.com` becomes `https%3A%2F%2Fwww.google.com`
- Full example: `![Google Screenshot](https://s.wordpress.com/mshots/v1/https%3A%2F%2Fwww.google.com)`
- Always URL-encode the target website properly
- This works for any public website - the app supports markdown image rendering
- Show screenshots when discussing websites, demonstrating tools, or explaining web concepts

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
- Use direct WordPress screenshots when discussing websites
- Create diagrams naturally when explaining processes or concepts
- The app's markdown rendering will display all images properly
- Focus on being helpful with visual content

**Show websites and create diagrams to make your responses more visual and helpful!** 🌐📊✨''';
  }
}