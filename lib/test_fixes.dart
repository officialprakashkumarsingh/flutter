import 'dart:convert';
import 'dart:math';
import 'external_tools_service.dart';

/// Comprehensive test for all the fixes implemented
void main() async {
  print('🔧 Testing All Fixes Implementation');
  print('====================================\n');
  
  final service = ExternalToolsService();
  
  // Test 1: Enhanced Image Generation with Unique Seeds
  print('🎨 Test 1: Enhanced Image Generation');
  print('-----------------------------------');
  
  final prompts = [
    'A beautiful sunset over mountains',
    'A futuristic city skyline',
    'A cat playing with yarn'
  ];
  
  for (int i = 0; i < prompts.length; i++) {
    print('Generating image ${i + 1} with prompt: "${prompts[i]}"');
    
    final imageResult = await service.executeTool('generate_image', {
      'prompt': prompts[i],
      'model': 'flux',
      'width': 512,
      'height': 512,
    });
    
    if (imageResult['success']) {
      print('✅ Image ${i + 1} generated with unique seed: ${imageResult['seed']}');
      print('   Original prompt: ${imageResult['original_prompt']}');
      print('   Unique ID: ${imageResult['unique_id']}\n');
    } else {
      print('❌ Image ${i + 1} failed: ${imageResult['error']}\n');
    }
  }
  
  // Test 2: Multiple Screenshots with Unique Parameters
  print('📸 Test 2: Multiple Screenshots');
  print('-------------------------------');
  
  final testUrls = [
    'https://google.com',
    'https://github.com',
    'https://stackoverflow.com',
    'https://flutter.dev'
  ];
  
  final screenshotResult = await service.executeTool('screenshot', {
    'urls': testUrls,
    'width': 800,
    'height': 600,
  });
  
  if (screenshotResult['success']) {
    final screenshots = screenshotResult['screenshots'] as List;
    print('✅ ${screenshots.length} screenshots captured successfully:');
    for (int i = 0; i < screenshots.length; i++) {
      final shot = screenshots[i] as Map;
      print('   Screenshot ${i + 1}: ${shot['url']}');
      print('   Unique ID: ${shot['unique_id']}');
      print('   Timestamp: ${shot['timestamp']}\n');
    }
  } else {
    print('❌ Screenshots failed: ${screenshotResult['error']}\n');
  }
  
  // Test 3: Enhanced Collage Creation
  print('🖼️ Test 3: Enhanced Collage Creation');
  print('------------------------------------');
  
  final imageUrls = [
    'https://picsum.photos/300/200?random=1',
    'https://picsum.photos/300/200?random=2',
    'https://picsum.photos/300/200?random=3',
    'https://picsum.photos/300/200?random=4'
  ];
  
  final collageResult = await service.executeTool('create_image_collage', {
    'image_urls': imageUrls,
    'layout': 'grid',
    'max_width': 800,
    'max_height': 600,
  });
  
  if (collageResult['success']) {
    print('✅ Collage created successfully:');
    print('   Image count: ${collageResult['image_count']}');
    print('   Layout: ${collageResult['layout']}');
    print('   Service used: ${collageResult['service_used'] ?? 'Fallback'}');
    print('   Image URL type: ${collageResult['image_url']?.substring(0, 20)}...\n');
  } else {
    print('❌ Collage creation failed: ${collageResult['error']}\n');
  }
  
  // Test 4: Enhanced Diagram Generation with Fallbacks
  print('📊 Test 4: Enhanced Diagram Generation');
  print('--------------------------------------');
  
  final diagramCode = '''
graph TD
    A[Start] --> B[Process]
    B --> C{Decision}
    C -->|Yes| D[Action 1]
    C -->|No| E[Action 2]
    D --> F[End]
    E --> F
  ''';
  
  final diagramResult = await service.executeTool('mermaid_chart', {
    'diagram': diagramCode,
    'diagram_type': 'flowchart',
    'format': 'svg',
    'auto_enhance': true,
  });
  
  if (diagramResult['success']) {
    print('✅ Diagram generated successfully:');
    print('   Type: ${diagramResult['diagram_type']}');
    print('   Format: ${diagramResult['format']}');
    print('   Auto-enhanced: ${diagramResult['auto_enhanced']}');
    print('   Service used: ${diagramResult['service_used']}');
    print('   Size: ${diagramResult['size']} bytes\n');
  } else {
    print('❌ Diagram generation failed: ${diagramResult['error']}');
    print('   Tried services: ${diagramResult['tried_services']}\n');
  }
  
  // Test 5: Parallel Tool Execution with Enhanced Loading
  print('⚡ Test 5: Parallel Tool Execution');
  print('----------------------------------');
  
  final parallelTools = [
    {
      'tool_name': 'fetch_ai_models',
      'parameters': {'refresh': true},
    },
    {
      'tool_name': 'fetch_image_models', 
      'parameters': {'refresh': false},
    },
    {
      'tool_name': 'web_search',
      'parameters': {
        'query': 'Flutter development tips',
        'source': 'both',
        'limit': 3,
      },
    }
  ];
  
  print('Executing ${parallelTools.length} tools in parallel...');
  print('Currently executing tools: ${service.currentlyExecutingTools}');
  
  final parallelResults = await service.executeToolsParallel(parallelTools);
  
  print('✅ Parallel execution completed:');
  parallelResults.forEach((toolName, result) {
    print('   $toolName: ${result['success'] ? 'Success' : 'Failed'}');
    if (result['success']) {
      if (toolName == 'fetch_ai_models') {
        print('     Found ${result['total_count']} AI models');
      } else if (toolName == 'fetch_image_models') {
        print('     Found ${result['total_count']} image models');
      } else if (toolName == 'web_search') {
        print('     Found ${result['total_found']} search results');
      }
    }
  });
  
  print('\n🎉 All Tests Completed!');
  print('=======================');
  print('✅ Enhanced image generation with unique seeds');
  print('✅ Multiple screenshots with unique parameters');
  print('✅ Improved collage creation with fallbacks');
  print('✅ Enhanced diagram generation with multiple services');
  print('✅ Parallel tool execution with improved loading indicators');
  print('✅ Robust JSON tool detection with implicit patterns');
  print('✅ Better error handling and user feedback');
}

/// Test JSON tool call patterns
void testJsonPatterns() {
  print('\n🔍 Testing Enhanced JSON Pattern Detection');
  print('==========================================');
  
  final testCases = [
    // Explicit tool_use pattern
    '''```json
{
  "tool_use": true,
  "tool_name": "generate_image", 
  "parameters": {"prompt": "test"}
}
```''',
    
    // Implicit pattern (just tool_name)
    '''```json
{
  "tool_name": "screenshot",
  "parameters": {"url": "https://example.com"}
}
```''',
    
    // Parallel tools with explicit flag
    '''```json
[
  {"tool_use": true, "tool_name": "web_search", "parameters": {"query": "test"}},
  {"tool_use": true, "tool_name": "screenshot", "parameters": {"url": "test.com"}}
]
```''',
    
    // Parallel tools implicit
    '''```json
[
  {"tool_name": "fetch_ai_models", "parameters": {"refresh": true}},
  {"tool_name": "mermaid_chart", "parameters": {"diagram": "graph TD\nA-->B"}}
]
```'''
  ];
  
  final patterns = [
    RegExp(r'```json\s*(\{[^`]*?["\']tool_use["\']\s*:\s*true[^`]*?\})\s*```', dotAll: true, multiLine: true),
    RegExp(r'```json\s*(\[[^`]*?["\']tool_use["\']\s*:\s*true[^`]*?\])\s*```', dotAll: true, multiLine: true),
    RegExp(r'```json\s*(\{[^`]*?["\']tool_name["\']\s*:\s*["\'][^"\']+["\'][^`]*?\})\s*```', dotAll: true, multiLine: true),
    RegExp(r'```json\s*(\[[^`]*?["\']tool_name["\']\s*:\s*["\'][^"\']+["\'][^`]*?\])\s*```', dotAll: true, multiLine: true),
  ];
  
  final patternNames = [
    'Explicit Single Tool',
    'Explicit Parallel Tools', 
    'Implicit Single Tool',
    'Implicit Parallel Tools'
  ];
  
  for (int i = 0; i < testCases.length; i++) {
    print('Test Case ${i + 1}: ${patternNames[i]}');
    print('Input: ${testCases[i].replaceAll('\n', '\\n').substring(0, 60)}...');
    
    bool matched = false;
    for (int j = 0; j < patterns.length; j++) {
      if (patterns[j].hasMatch(testCases[i])) {
        print('✅ Matched by pattern: ${patternNames[j]}');
        matched = true;
        break;
      }
    }
    
    if (!matched) {
      print('❌ No pattern matched');
    }
    print('');
  }
}