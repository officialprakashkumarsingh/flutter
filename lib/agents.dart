import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// External Agents Service
/// Provides AI with external tools and capabilities
class AgentsService {
  static const String _plantumlUrl = 'https://www.plantuml.com/plantuml/png/';
  

  
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
      
      
      
      return result;
    } catch (e) {
      print('❌ AGENTS: Error processing agent request: $e');
      return null;
    }
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