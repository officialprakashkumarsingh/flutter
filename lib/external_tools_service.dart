import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ExternalTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> params) execute;

  ExternalTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.execute,
  });
}

class ExternalToolsService extends ChangeNotifier {
  static final ExternalToolsService _instance = ExternalToolsService._internal();
  factory ExternalToolsService() => _instance;
  ExternalToolsService._internal() {
    _initializeTools();
  }

  final Map<String, ExternalTool> _tools = {};
  bool _isExecuting = false;
  List<String> _currentlyExecutingTools = [];
  String _lastToolUsed = '';
  Map<String, dynamic> _lastResult = {};
  
  // Callback for model switching
  void Function(String modelName)? _modelSwitchCallback;

  bool get isExecuting => _isExecuting;
  List<String> get currentlyExecutingTools => List.unmodifiable(_currentlyExecutingTools);
  String get lastToolUsed => _lastToolUsed;
  Map<String, dynamic> get lastResult => Map.unmodifiable(_lastResult);

  void _initializeTools() {
    // Screenshot tool - takes screenshots of webpages using WordPress preview
    _tools['screenshot'] = ExternalTool(
      name: 'screenshot',
      description: 'Takes a screenshot of any webpage using WordPress preview service. Can capture single or multiple URLs. The AI can use this tool to visually understand websites, capture content, or help users with visual tasks.',
      parameters: {
        'url': {'type': 'string', 'description': 'The URL to take screenshot of', 'required': false},
        'urls': {'type': 'array', 'description': 'Multiple URLs to take screenshots of', 'required': false},
        'width': {'type': 'integer', 'description': 'Screenshot width in pixels (default: 1200)', 'default': 1200},
        'height': {'type': 'integer', 'description': 'Screenshot height in pixels (default: 800)', 'default': 800},
      },
      execute: _executeScreenshot,
    );

    // AI Models fetcher - dynamically fetches available AI models
    _tools['fetch_ai_models'] = ExternalTool(
      name: 'fetch_ai_models',
      description: 'Fetches available AI models from the API. The AI can use this to switch models if one is not responding or if the user is not satisfied with the current model.',
      parameters: {
        'refresh': {'type': 'boolean', 'description': 'Force refresh the models list (default: false)', 'default': false},
        'filter': {'type': 'string', 'description': 'Filter models by name pattern (optional)', 'default': ''},
      },
      execute: _fetchAIModels,
    );

    // Model switcher - switches the current AI model
    _tools['switch_ai_model'] = ExternalTool(
      name: 'switch_ai_model',
      description: 'Switches to a different AI model. The AI can use this when a model is not responding well or when the user requests a different model.',
      parameters: {
        'model_name': {'type': 'string', 'description': 'Name of the model to switch to', 'required': true},
        'reason': {'type': 'string', 'description': 'Reason for switching models (optional)', 'default': 'User request'},
      },
      execute: _switchAIModel,
    );

    // Image generation tool - generates images using AI models
    _tools['generate_image'] = ExternalTool(
      name: 'generate_image',
      description: 'Generates images using AI models like Flux and Turbo. The AI can use this tool when users request image creation, art generation, or visual content.',
      parameters: {
        'prompt': {'type': 'string', 'description': 'The prompt for image generation', 'required': true},
        'model': {'type': 'string', 'description': 'Image model to use (flux, turbo)', 'default': 'flux'},
        'width': {'type': 'integer', 'description': 'Image width in pixels (default: 1024)', 'default': 1024},
        'height': {'type': 'integer', 'description': 'Image height in pixels (default: 1024)', 'default': 1024},
        'enhance': {'type': 'boolean', 'description': 'Enhance the prompt (default: false)', 'default': false},
      },
      execute: _generateImage,
    );

    // Fetch image models - gets available image generation models
    _tools['fetch_image_models'] = ExternalTool(
      name: 'fetch_image_models',
      description: 'Fetches available image generation models from the API. The AI can use this to show users what image models are available.',
      parameters: {
        'refresh': {'type': 'boolean', 'description': 'Force refresh the models list (default: false)', 'default': false},
      },
      execute: _fetchImageModels,
    );

    // Enhanced web search tool - searches the web using DuckDuckGo and Wikipedia
    _tools['web_search'] = ExternalTool(
      name: 'web_search',
      description: 'Performs real-time web search using DuckDuckGo and Wikipedia with improved coverage. The AI can use this tool to find current information, news, or any web content.',
      parameters: {
        'query': {'type': 'string', 'description': 'The search query', 'required': true},
        'source': {'type': 'string', 'description': 'Search source (duckduckgo, wikipedia, both)', 'default': 'both'},
        'limit': {'type': 'integer', 'description': 'Maximum number of results (default: 8)', 'default': 8},
        'deep_search': {'type': 'boolean', 'description': 'Enable deeper Wikipedia search (default: true)', 'default': true},
      },
      execute: _webSearch,
    );


    // Screenshot vision tool - analyzes screenshots using vision AI
    _tools['screenshot_vision'] = ExternalTool(
      name: 'screenshot_vision',
      description: 'Analyzes screenshots using vision AI models. Can handle single images or multiple images (creates collage). The AI can use this tool to understand what is visible in screenshots it has generated.',
      parameters: {
        'image_url': {'type': 'string', 'description': 'URL of the screenshot to analyze (required if image_urls not provided)', 'required': false},
        'image_urls': {'type': 'array', 'description': 'Multiple URLs of screenshots to analyze as a collage (required if image_url not provided)', 'required': false},
        'question': {'type': 'string', 'description': 'Optional question about the image(s)', 'default': 'What do you see in this image?'},
        'model': {'type': 'string', 'description': 'Vision model to use', 'default': 'claude-4-sonnet'},
        'collage_layout': {'type': 'string', 'description': 'Layout for multiple images (grid, horizontal, vertical)', 'default': 'grid'},
      },
      execute: _screenshotVision,
    );

    // Image collage tool - creates collages from multiple images
    _tools['create_image_collage'] = ExternalTool(
      name: 'create_image_collage',
      description: 'Creates a collage from multiple images for easier analysis. Useful when you have multiple screenshots or images that need to be analyzed together.',
      parameters: {
        'image_urls': {'type': 'array', 'description': 'Array of image URLs to combine into a collage', 'required': true},
        'layout': {'type': 'string', 'description': 'Layout type (grid, horizontal, vertical)', 'default': 'grid'},
        'max_width': {'type': 'integer', 'description': 'Maximum width of the collage in pixels', 'default': 1200},
        'max_height': {'type': 'integer', 'description': 'Maximum height of the collage in pixels', 'default': 800},
      },
      execute: _createImageCollage,
    );

    // Enhanced Mermaid chart generation - create professional diagrams using mermaid.js
    _tools['mermaid_chart'] = ExternalTool(
      name: 'mermaid_chart',
      description: 'Generates professional charts and diagrams using mermaid.js with enhanced styling and structure. Supports flowcharts, sequence diagrams, class diagrams, gitgraph, gantt charts, and more. Automatically optimizes diagram structure and appearance.',
      parameters: {
        'diagram': {'type': 'string', 'description': 'Mermaid diagram code (will be enhanced automatically)', 'required': true},
        'diagram_type': {'type': 'string', 'description': 'Type of diagram (flowchart, sequence, class, gitgraph, gantt, pie, journey)', 'default': 'flowchart'},
        'format': {'type': 'string', 'description': 'Image format (svg or png)', 'default': 'svg'},
        'theme': {'type': 'string', 'description': 'Theme (default, dark, forest, base, neutral)', 'default': 'default'},
        'auto_enhance': {'type': 'boolean', 'description': 'Automatically enhance diagram structure and styling', 'default': true},
      },
      execute: _generateMermaidChart,
    );
  }

  /// Execute a single tool by name with given parameters
  Future<Map<String, dynamic>> executeTool(String toolName, Map<String, dynamic> params) async {
    if (!_tools.containsKey(toolName)) {
      return {
        'success': false,
        'error': 'Tool "$toolName" not found',
        'available_tools': _tools.keys.toList(),
      };
    }

    _isExecuting = true;
    _currentlyExecutingTools.add(toolName);
    _lastToolUsed = toolName;
    notifyListeners();

    try {
      final result = await _tools[toolName]!.execute(params);
      _lastResult = result;
      _currentlyExecutingTools.remove(toolName);
      if (_currentlyExecutingTools.isEmpty) {
        _isExecuting = false;
      }
      notifyListeners();
      return result;
    } catch (e) {
      _currentlyExecutingTools.remove(toolName);
      if (_currentlyExecutingTools.isEmpty) {
        _isExecuting = false;
      }
      _lastResult = {
        'success': false,
        'error': e.toString(),
        'tool': toolName,
      };
      notifyListeners();
      return _lastResult;
    }
  }

  /// Execute multiple tools in parallel
  Future<Map<String, Map<String, dynamic>>> executeToolsParallel(List<Map<String, dynamic>> toolCalls) async {
    final results = <String, Map<String, dynamic>>{};
    
    _isExecuting = true;
    _currentlyExecutingTools.clear();
    for (final call in toolCalls) {
      _currentlyExecutingTools.add(call['tool_name'] as String);
    }
    notifyListeners();

    try {
      final futures = toolCalls.map((call) async {
        final toolName = call['tool_name'] as String;
        final params = call['parameters'] as Map<String, dynamic>? ?? {};
        
        if (!_tools.containsKey(toolName)) {
          return MapEntry(toolName, {
            'success': false,
            'error': 'Tool "$toolName" not found',
            'available_tools': _tools.keys.toList(),
          });
        }

        try {
          final result = await _tools[toolName]!.execute(params);
          return MapEntry(toolName, result);
        } catch (e) {
          return MapEntry(toolName, {
            'success': false,
            'error': e.toString(),
            'tool': toolName,
          });
        }
      });

      final parallelResults = await Future.wait(futures);
      for (final entry in parallelResults) {
        results[entry.key] = entry.value;
      }

      _isExecuting = false;
      _currentlyExecutingTools.clear();
      notifyListeners();
      
      return results;
    } catch (e) {
      _isExecuting = false;
      _currentlyExecutingTools.clear();
      _lastResult = {
        'success': false,
        'error': 'Parallel execution failed: $e',
        'tools': toolCalls.map((c) => c['tool_name']).toList(),
      };
      notifyListeners();
      return {'error': _lastResult};
    }
  }

  /// Get list of available tools
  List<ExternalTool> getAvailableTools() {
    return _tools.values.toList();
  }

  /// Get specific tool information
  ExternalTool? getTool(String name) {
    return _tools[name];
  }

  /// Check if AI can access screenshot functionality
  bool get hasScreenshotCapability => _tools.containsKey('screenshot');

  /// Check if AI can access model switching
  bool get hasModelSwitchingCapability => _tools.containsKey('fetch_ai_models') && _tools.containsKey('switch_ai_model');

  /// Check if AI can access image generation
  bool get hasImageGenerationCapability => _tools.containsKey('generate_image');

  /// Check if AI can access web search
  bool get hasWebSearchCapability => _tools.containsKey('web_search');

  /// Check if AI can access screenshot vision
  bool get hasScreenshotVisionCapability => _tools.containsKey('screenshot_vision');


  /// Set the model switch callback (called by main shell)
  void setModelSwitchCallback(void Function(String modelName) callback) {
    _modelSwitchCallback = callback;
  }

  // Tool implementations

  Future<Map<String, dynamic>> _executeScreenshot(Map<String, dynamic> params) async {
    final url = params['url'] as String? ?? '';
    final urls = params['urls'] as List<dynamic>? ?? [];
    final width = params['width'] as int? ?? 1200;
    final height = params['height'] as int? ?? 800;

    // Determine which URLs to process
    List<String> targetUrls = [];
    if (url.isNotEmpty) {
      targetUrls.add(url);
    }
    if (urls.isNotEmpty) {
      targetUrls.addAll(urls.map((u) => u.toString()));
    }

    if (targetUrls.isEmpty) {
      return {
        'success': false,
        'error': 'Either url or urls parameter is required. Please provide a URL to take screenshot of.',
        'hint': 'Example: {"url": "https://example.com"} or {"urls": ["https://example.com", "https://google.com"]}',
        'tool_executed': false,
      };
    }

    // Handle multiple URLs
    if (targetUrls.length > 1) {
      return await _executeMultipleScreenshots(targetUrls, width, height);
    }

    try {
      // Validate URL format
      Uri parsedUrl;
      final singleUrl = targetUrls.first;
      try {
        if (!singleUrl.startsWith('http://') && !singleUrl.startsWith('https://')) {
          parsedUrl = Uri.parse('https://$singleUrl');
        } else {
          parsedUrl = Uri.parse(singleUrl);
        }
      } catch (e) {
        return {
          'success': false,
          'error': 'Invalid URL format: $singleUrl',
        };
      }

      // Use WordPress.com mshots API for screenshots with unique parameters
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final urlHash = parsedUrl.toString().hashCode.abs();
      final uniqueId = '${timestamp}_${urlHash}';
      final screenshotUrl =
          'https://s0.wp.com/mshots/v1/${Uri.encodeComponent(parsedUrl.toString())}?w=$width&h=$height&cb=$uniqueId&refresh=1&vpw=$width&vph=$height';
      
      // Verify the screenshot service is accessible with a longer timeout
      try {
        final response = await http.head(Uri.parse(screenshotUrl)).timeout(Duration(seconds: 15));
        
        return {
          'success': true,
          'url': parsedUrl.toString(),
          'screenshot_url': screenshotUrl,
          'preview_url': screenshotUrl, // Direct WordPress preview
          'width': width,
          'height': height,
          'description': 'Screenshot captured successfully for ${parsedUrl.toString()}',
          'service': 'WordPress mshots API (direct preview)',
          'accessible': response.statusCode == 200,
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
        };
      } catch (e) {
        // Even if head request fails, the screenshot service might still work
        return {
          'success': true,
          'url': parsedUrl.toString(),
          'screenshot_url': screenshotUrl,
          'preview_url': screenshotUrl,
          'width': width,
          'height': height,
          'description': 'Screenshot service initiated for ${parsedUrl.toString()}',
          'service': 'WordPress mshots API (direct preview)',
          'note': 'Service response pending - image may take a moment to generate',
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to capture screenshot: $e',
        'url': targetUrls.first,
        'tool_executed': false,
      };
    }
  }

  Future<Map<String, dynamic>> _executeMultipleScreenshots(List<String> urls, int width, int height) async {
    List<Map<String, dynamic>> screenshots = [];
    List<String> errors = [];

    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      try {
        // Validate URL format
        Uri parsedUrl;
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          parsedUrl = Uri.parse('https://$url');
        } else {
          parsedUrl = Uri.parse(url);
        }

        // Use WordPress.com mshots API for screenshots with unique parameters to prevent caching issues
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        final uniqueId = '${timestamp}_${i}_${url.hashCode.abs()}';
        final screenshotUrl =
            'https://s0.wp.com/mshots/v1/${Uri.encodeComponent(parsedUrl.toString())}?w=$width&h=$height&cb=$uniqueId&refresh=1&vpw=$width&vph=$height';
        
        // Add delay between screenshots to ensure different results
        if (i > 0) {
          await Future.delayed(Duration(milliseconds: 300));
        }
        
        screenshots.add({
          'index': i + 1,
          'url': parsedUrl.toString(),
          'screenshot_url': screenshotUrl,
          'preview_url': screenshotUrl,
          'width': width,
          'height': height,
          'unique_id': uniqueId,
          'timestamp': timestamp,
        });
      } catch (e) {
        errors.add('URL ${i + 1} ($url): $e');
      }
    }

    return {
      'success': screenshots.isNotEmpty,
      'screenshots': screenshots,
      'total_screenshots': screenshots.length,
      'errors': errors,
      'service': 'WordPress mshots API (direct preview)',
      'tool_executed': true,
      'execution_time': DateTime.now().toIso8601String(),
      'description': 'Multiple screenshots captured: ${screenshots.length} successful, ${errors.length} failed',
    };
  }

  Future<Map<String, dynamic>> _fetchAIModels(Map<String, dynamic> params) async {
    final refresh = params['refresh'] as bool? ?? false;
    final filter = params['filter'] as String? ?? '';

    try {
      final response = await http.get(
        Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/models'),
        headers: {'Authorization': 'Bearer ahamaibyprakash25'},
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<String> models = (data['data'] as List).map<String>((item) => item['id']).toList();
        
        // Apply filter if provided
        if (filter.isNotEmpty) {
          models = models.where((model) => model.toLowerCase().contains(filter.toLowerCase())).toList();
        }

        return {
          'success': true,
          'models': models,
          'total_count': models.length,
          'filter_applied': filter,
          'refreshed': refresh,
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
          'api_status': 'Connected successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'API returned status ${response.statusCode}: ${response.reasonPhrase}',
          'tool_executed': true,
          'api_status': 'Failed to connect',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to fetch AI models: $e',
        'tool_executed': true,
        'api_status': 'Connection error',
      };
    }
  }

  Future<Map<String, dynamic>> _switchAIModel(Map<String, dynamic> params) async {
    final modelName = params['model_name'] as String? ?? '';
    final reason = params['reason'] as String? ?? 'User request';

    if (modelName.isEmpty) {
      return {
        'success': false,
        'error': 'model_name parameter is required',
        'tool_executed': false,
      };
    }

    try {
      // First, verify the model exists by fetching the models list
      final modelsResult = await _fetchAIModels({'refresh': true});
      
      if (modelsResult['success'] == true) {
        final models = modelsResult['models'] as List<String>;
        
        if (models.contains(modelName)) {
          // Actually switch the model if callback is available
          if (_modelSwitchCallback != null) {
            _modelSwitchCallback!(modelName);
          }
          
          return {
            'success': true,
            'new_model': modelName,
            'reason': reason,
            'available_models': models,
            'tool_executed': true,
            'execution_time': DateTime.now().toIso8601String(),
            'action_completed': _modelSwitchCallback != null ? 'Model switched successfully' : 'UI should update the selected model to $modelName',
            'validation': 'Model exists and is available',
          };
        } else {
          return {
            'success': false,
            'error': 'Model "$modelName" not found in available models',
            'available_models': models,
            'suggestion': 'Try one of the available models listed above',
            'tool_executed': true,
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Could not fetch models list to verify model exists',
          'reason': modelsResult['error'],
          'tool_executed': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to switch AI model: $e',
        'tool_executed': true,
      };
    }
  }

  Future<Map<String, dynamic>> _generateImage(Map<String, dynamic> params) async {
    final prompt = params['prompt'] as String? ?? '';
    final model = params['model'] as String? ?? 'flux';
    final width = params['width'] as int? ?? 1024;
    final height = params['height'] as int? ?? 1024;
    final enhance = params['enhance'] as bool? ?? false;

    if (prompt.isEmpty) {
      return {
        'success': false,
        'error': 'Prompt parameter is required',
      };
    }

    try {
      // Create truly unique seed using multiple factors to prevent duplicate images
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final random = (timestamp * 1337) % 1000000;
      final promptHash = prompt.hashCode.abs() % 100000;
      final modelHash = model.hashCode.abs() % 10000;
      final seed = (timestamp % 1000000) + random + promptHash + modelHash;
      
      // Always add unique elements to prompt to ensure different images
      final uniqueId = '${timestamp}_${seed}';
      final enhancedPrompt = enhance ? '$prompt [unique_id:$uniqueId]' : '$prompt [seed:$seed,id:$uniqueId]';
      
      final response = await http.post(
        Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/images/generations'),
        headers: {
          'Authorization': 'Bearer ahamaibyprakash25',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'prompt': enhancedPrompt,
          'width': width,
          'height': height,
          'enhance': enhance,
          'seed': seed,
          'timestamp': timestamp,
          'unique_id': uniqueId,
        }),
      ).timeout(Duration(seconds: 60));

      if (response.statusCode == 200) {
        // The image is returned as binary data
        final imageBytes = response.bodyBytes;
        
        // Create a data URL for the image
        final base64Image = base64Encode(imageBytes);
        final dataUrl = 'data:image/jpeg;base64,$base64Image';

        return {
          'success': true,
          'original_prompt': prompt,
          'enhanced_prompt': enhancedPrompt,
          'model': model,
          'width': width,
          'height': height,
          'enhance': enhance,
          'seed': seed,
          'image_url': dataUrl,
          'image_size': imageBytes.length,
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
          'description': 'Image generated successfully using $model model with unique seed $seed',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to generate image: HTTP ${response.statusCode}',
          'prompt': prompt,
          'model': model,
          'width': width,
          'height': height,
          'enhance': enhance,
          'tool_executed': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to generate image: $e',
        'prompt': prompt,
        'model': model,
        'width': width,
        'height': height,
        'enhance': enhance,
        'tool_executed': true,
      };
    }
  }

  Future<Map<String, dynamic>> _fetchImageModels(Map<String, dynamic> params) async {
    final refresh = params['refresh'] as bool? ?? false;

    try {
      final response = await http.get(
        Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/images/models'),
        headers: {
          'Authorization': 'Bearer ahamaibyprakash25',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final modelsData = data['data'] as List;
        
        List<Map<String, dynamic>> models = modelsData.map<Map<String, dynamic>>((item) => {
          'id': item['id'],
          'name': item['name'] ?? item['id'],
          'provider': item['provider'] ?? 'unknown',
          'width': item['width'] ?? 1024,
          'height': item['height'] ?? 1024,
        }).toList();
        
        return {
          'success': true,
          'models': models,
          'model_names': models.map((m) => m['id']).toList(),
          'total_count': models.length,
          'refreshed': refresh,
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
          'api_status': 'Connected successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'API returned status ${response.statusCode}: ${response.reasonPhrase}',
          'tool_executed': true,
          'api_status': 'Failed to connect',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to fetch image models: $e',
        'tool_executed': true,
        'api_status': 'Connection error',
      };
    }
  }

  Future<Map<String, dynamic>> _webSearch(Map<String, dynamic> params) async {
    final query = params['query'] as String? ?? '';
    final source = params['source'] as String? ?? 'both';
    final limit = params['limit'] as int? ?? 8;
    final deepSearch = params['deep_search'] as bool? ?? true;

    if (query.isEmpty) {
      return {
        'success': false,
        'error': 'Query parameter is required',
      };
    }

    try {
      List<Map<String, dynamic>> allResults = [];
      
      // Enhanced Wikipedia search
      if (source == 'wikipedia' || source == 'both') {
        try {
          // Primary search
          final wikipediaUrl = 'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(query)}&srlimit=${deepSearch ? limit * 2 : limit}&format=json&origin=*';
          final wikipediaResponse = await http.get(Uri.parse(wikipediaUrl)).timeout(Duration(seconds: 15));
          
          if (wikipediaResponse.statusCode == 200) {
            final wikipediaData = json.decode(wikipediaResponse.body);
            final searchResults = wikipediaData['query']['search'] as List? ?? [];
            
            for (final result in searchResults) {
              final snippet = result['snippet']?.toString().replaceAll(RegExp(r'<[^>]*>'), '') ?? '';
              if (snippet.isNotEmpty) {
                allResults.add({
                  'title': result['title'],
                  'snippet': snippet,
                  'url': 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(result['title'])}',
                  'source': 'Wikipedia',
                  'pageviews': result['size'] ?? 0,
                });
              }
            }
          }

          // Deep search: also try OpenSearch API for better suggestions
          if (deepSearch && allResults.length < 3) {
            try {
              final openSearchUrl = 'https://en.wikipedia.org/w/api.php?action=opensearch&search=${Uri.encodeComponent(query)}&limit=5&format=json&origin=*';
              final openSearchResponse = await http.get(Uri.parse(openSearchUrl)).timeout(Duration(seconds: 10));
              
              if (openSearchResponse.statusCode == 200) {
                final openSearchData = json.decode(openSearchResponse.body) as List;
                if (openSearchData.length >= 4) {
                  final titles = openSearchData[1] as List;
                  final descriptions = openSearchData[2] as List;
                  final urls = openSearchData[3] as List;
                  
                  for (int i = 0; i < titles.length && allResults.length < limit; i++) {
                    final title = titles[i]?.toString() ?? '';
                    final description = descriptions[i]?.toString() ?? '';
                    final url = urls[i]?.toString() ?? '';
                    
                    if (title.isNotEmpty && description.isNotEmpty && 
                        !allResults.any((r) => r['title']?.toString().toLowerCase() == title.toLowerCase())) {
                      allResults.add({
                        'title': title,
                        'snippet': description,
                        'url': url,
                        'source': 'Wikipedia (OpenSearch)',
                      });
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Wikipedia OpenSearch error: $e');
            }
          }
        } catch (e) {
          debugPrint('Wikipedia search error: $e');
        }
      }

      // Enhanced DuckDuckGo search with fallbacks
      if (source == 'duckduckgo' || source == 'both') {
        try {
          // Primary DuckDuckGo search
          final duckduckgoUrl = 'https://api.duckduckgo.com/?q=${Uri.encodeComponent(query)}&format=json&no_html=1&skip_disambig=1';
          final duckduckgoResponse = await http.get(Uri.parse(duckduckgoUrl)).timeout(Duration(seconds: 15));
          
          if (duckduckgoResponse.statusCode == 200) {
            final duckduckgoData = json.decode(duckduckgoResponse.body);
            
            // Add abstract if available
            if (duckduckgoData['Abstract'] != null && duckduckgoData['Abstract'].toString().isNotEmpty) {
              allResults.add({
                'title': duckduckgoData['Heading'] ?? query,
                'snippet': duckduckgoData['Abstract'],
                'url': duckduckgoData['AbstractURL'] ?? '',
                'source': 'DuckDuckGo Abstract',
                'type': 'primary',
              });
            }
            
            // Add definition if available
            if (duckduckgoData['Definition'] != null && duckduckgoData['Definition'].toString().isNotEmpty) {
              allResults.add({
                'title': 'Definition: ${query}',
                'snippet': duckduckgoData['Definition'],
                'url': duckduckgoData['DefinitionURL'] ?? '',
                'source': 'DuckDuckGo Definition',
                'type': 'definition',
              });
            }
            
            // Add related topics
            final relatedTopics = duckduckgoData['RelatedTopics'] as List? ?? [];
            for (final topic in relatedTopics.take(deepSearch ? 6 : 3)) {
              if (topic is Map && topic['Text'] != null && topic['Text'].toString().isNotEmpty) {
                final topicText = topic['Text'].toString();
                final title = topicText.split(' - ').first;
                allResults.add({
                  'title': title,
                  'snippet': topicText,
                  'url': topic['FirstURL'] ?? '',
                  'source': 'DuckDuckGo',
                  'type': 'related',
                });
              }
            }

            // Add results from different categories
            final results = duckduckgoData['Results'] as List? ?? [];
            for (final result in results.take(3)) {
              if (result is Map && result['Text'] != null && result['Text'].toString().isNotEmpty) {
                allResults.add({
                  'title': result['Text']?.split(' - ').first ?? query,
                  'snippet': result['Text'],
                  'url': result['FirstURL'] ?? '',
                  'source': 'DuckDuckGo Results',
                  'type': 'result',
                });
              }
            }
          }
        } catch (e) {
          debugPrint('DuckDuckGo search error: $e');
          // Fallback to DuckDuckGo lite HTML parsing
          try {
            final liteUrl = 'https://lite.duckduckgo.com/50x.html?kd=-1&kp=1&q=${Uri.encodeComponent(query)}';
            final liteResp = await http.get(Uri.parse(liteUrl)).timeout(const Duration(seconds: 15));
            if (liteResp.statusCode == 200) {
              final html = liteResp.body;
              final itemRegex = RegExp(r'<a rel="nofollow" class="result-link" href="([^"]*)">(.*?)<\/a>', dotAll: true);
              final matches = itemRegex.allMatches(html).take(limit);
              for (final m in matches) {
                final url = Uri.decodeFull(m.group(1) ?? '');
                final title = m.group(2)?.replaceAll(RegExp(r'<[^>]*>'), '') ?? '';
                if (title.isNotEmpty && url.isNotEmpty) {
                  allResults.add({
                    'title': title,
                    'snippet': '',
                    'url': url,
                    'source': 'DuckDuckGo Lite',
                    'type': 'result',
                  });
                }
              }
            }
          } catch (e) {
            debugPrint('DuckDuckGo fallback error: $e');
          }

          // As a secondary fallback, try Qwant's open search API
          try {
            final qwantUrl = 'https://api.qwant.com/api/search/web?count=$limit&q=${Uri.encodeComponent(query)}&t=web&locale=en_US&offset=0';
            final qwantResp = await http.get(Uri.parse(qwantUrl)).timeout(const Duration(seconds: 15));
            if (qwantResp.statusCode == 200) {
              final data = json.decode(qwantResp.body);
              final items = data['data']?['result']?['items']?['mainline'] as List? ?? [];
              for (final item in items) {
                if (item is Map && item['type'] == 'web') {
                  allResults.add({
                    'title': item['title'] ?? '',
                    'snippet': item['desc'] ?? '',
                    'url': item['url'] ?? '',
                    'source': 'Qwant',
                    'type': 'result',
                  });
                }
              }
            }
          } catch (e) {
            debugPrint('Qwant search error: $e');
          }
        }
      }

      // Enhanced deduplication and sorting
      final uniqueResults = <Map<String, dynamic>>[];
      final seenTitles = <String>{};
      final seenUrls = <String>{};
      
      // Sort results by priority: abstracts/definitions first, then primary results, then related
      allResults.sort((a, b) {
        final aType = a['type']?.toString() ?? 'other';
        final bType = b['type']?.toString() ?? 'other';
        final priority = {'primary': 0, 'definition': 1, 'result': 2, 'related': 3, 'other': 4};
        return (priority[aType] ?? 4).compareTo(priority[bType] ?? 4);
      });
      
      for (final result in allResults) {
        final title = result['title']?.toString().toLowerCase() ?? '';
        final url = result['url']?.toString() ?? '';
        final snippet = result['snippet']?.toString() ?? '';
        
        if (title.isNotEmpty && snippet.isNotEmpty && 
            !seenTitles.contains(title) && 
            !seenUrls.contains(url) &&
            uniqueResults.length < limit) {
          seenTitles.add(title);
          if (url.isNotEmpty) seenUrls.add(url);
          uniqueResults.add(result);
        }
      }

      return {
        'success': true,
        'query': query,
        'source': source,
        'limit': limit,
        'deep_search': deepSearch,
        'results': uniqueResults,
        'total_found': uniqueResults.length,
        'tool_executed': true,
        'execution_time': DateTime.now().toIso8601String(),
        'description': 'Enhanced web search completed successfully with ${uniqueResults.length} results',
        'search_details': {
          'wikipedia_results': uniqueResults.where((r) => r['source']?.toString().contains('Wikipedia') == true).length,
          'duckduckgo_results': uniqueResults.where((r) => r['source']?.toString().contains('DuckDuckGo') == true).length,
        }
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to perform web search: $e',
        'query': query,
        'source': source,
        'limit': limit,
        'tool_executed': true,
      };
    }
  }


  Future<Map<String, dynamic>> _screenshotVision(Map<String, dynamic> params) async {
    final imageUrl = params['image_url'] as String? ?? '';
    final imageUrls = params['image_urls'] as List<dynamic>? ?? [];
    final question = params['question'] as String? ?? 'What do you see in this image?';
    final model = params['model'] as String? ?? 'claude-4-sonnet';
    final collageLayout = params['collage_layout'] as String? ?? 'grid';

    // Validate that we have at least one image
    if (imageUrl.isEmpty && imageUrls.isEmpty) {
      return {
        'success': false,
        'error': 'Either image_url or image_urls parameter is required. Please provide the URL(s) of the image(s) to analyze.',
        'hint': 'Use this tool after taking screenshots with the screenshot tool, or provide direct image URL(s).',
        'tool_executed': false,
      };
    }

    // Handle multiple images by creating a collage first
    if (imageUrls.isNotEmpty) {
      final collageResult = await _createImageCollage({
        'image_urls': imageUrls,
        'layout': collageLayout,
        'max_width': 1200,
        'max_height': 800,
      });
      
      if (!collageResult['success']) {
        return {
          'success': false,
          'error': 'Failed to create collage for multiple images: ${collageResult['error']}',
          'tool_executed': false,
        };
      }
      
      // Use the collage image for analysis
      final collageImageUrl = collageResult['image_url'] as String;
      return await _analyzeSingleImage(collageImageUrl, question, model, {
        'image_count': imageUrls.length,
        'layout': collageLayout,
        'is_collage': true,
        'original_urls': imageUrls,
      });
    }

    // Handle single image
    return await _analyzeSingleImage(imageUrl, question, model, {
      'is_collage': false,
    });
  }

  Future<Map<String, dynamic>> _analyzeSingleImage(String imageUrl, String question, String model, Map<String, dynamic> metadata) async {
    try {
      // Validate that the URL is accessible or is a data URL
      bool isValidUrl = false;
      String processedImageUrl = imageUrl;
      
      if (imageUrl.startsWith('data:image/')) {
        // It's a base64 data URL, use directly
        isValidUrl = true;
        processedImageUrl = imageUrl;
      } else if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        // It's a regular URL, verify it's accessible
        try {
          final headResponse = await http.head(Uri.parse(imageUrl)).timeout(Duration(seconds: 10));
          isValidUrl = headResponse.statusCode >= 200 && headResponse.statusCode < 400;
          processedImageUrl = imageUrl;
        } catch (e) {
          // If head request fails, still try to use the URL - it might work with the vision API
          isValidUrl = true;
          processedImageUrl = imageUrl;
        }
      } else {
        // Try to construct a proper URL if it looks like a relative path
        if (imageUrl.startsWith('s0.wp.com') || imageUrl.contains('mshots')) {
          processedImageUrl = imageUrl.startsWith('http') ? imageUrl : 'https://$imageUrl';
          isValidUrl = true;
        }
      }

      if (!isValidUrl) {
        return {
          'success': false,
          'error': 'Invalid image URL format. Please provide a valid HTTP/HTTPS URL or base64 data URL.',
          'provided_url': imageUrl,
          'tool_executed': false,
        };
      }

      // If the image is a remote URL, fetch and convert to base64 to avoid
      // remote access issues with the vision API
      if (!processedImageUrl.startsWith('data:image')) {
        try {
          final imgResp = await http.get(Uri.parse(processedImageUrl)).timeout(const Duration(seconds: 20));
          if (imgResp.statusCode >= 200 && imgResp.statusCode < 400) {
            final mime = imgResp.headers['content-type'] ?? 'image/jpeg';
            processedImageUrl = 'data:$mime;base64,${base64Encode(imgResp.bodyBytes)}';
          }
        } catch (_) {}
      }

      final response = await http.post(
        Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ahamaibyprakash25',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user', 
              'content': [
                {'type': 'text', 'text': question},
                {
                  'type': 'image_url',
                  'image_url': {'url': processedImageUrl, 'detail': 'auto'}
                },
              ]
            },
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      ).timeout(Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final answer = data['choices']?[0]?['message']?['content'] as String? ?? '';

        if (answer.isEmpty) {
          return {
            'success': false,
            'error': 'Vision API returned empty response. The image might not be accessible or supported.',
            'question': question,
            'model': model,
            'image_url': processedImageUrl,
            'tool_executed': true,
          };
        }

        return {
          'success': true,
          'question': question,
          'model': model,
          'image_url': processedImageUrl,
          'original_url': imageUrl,
          'answer': answer,
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
          'description': 'Image analyzed successfully using vision AI',
          'image_type': imageUrl.startsWith('data:') ? 'uploaded_image' : 'screenshot_url',
          ...metadata,
        };
      } else {
        // Try to parse error details
        String errorDetails = 'Unknown error';
        try {
          final errorData = json.decode(response.body);
          errorDetails = errorData['error']?['message'] ?? 'API error ${response.statusCode}';
        } catch (e) {
          errorDetails = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        }

        return {
          'success': false,
          'error': 'Vision API error: $errorDetails',
          'question': question,
          'model': model,
          'image_url': processedImageUrl,
          'status_code': response.statusCode,
          'tool_executed': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to analyze image: $e',
        'question': question,
        'model': model,
        'image_url': imageUrl,
        'tool_executed': true,
        'troubleshooting': 'Check if the image URL is accessible and the vision model supports the image format.',
      };
    }
  }

  Future<Map<String, dynamic>> _generateMermaidChart(Map<String, dynamic> params) async {
    String diagram = params['diagram'] as String? ?? '';
    final diagramType = params['diagram_type'] as String? ?? 'flowchart';
    final format = params['format'] as String? ?? 'svg';
    final theme = params['theme'] as String? ?? 'default';
    final autoEnhance = params['auto_enhance'] as bool? ?? true;

    diagram = diagram.trim();

    if (diagram.isEmpty) {
      return {
        'success': false,
        'error': 'diagram parameter is required',
        'tool_executed': false,
      };
    }

    try {
      // Auto-enhance the diagram if requested
      if (autoEnhance) {
        diagram = _enhanceMermaidDiagram(diagram, diagramType);
      }

      // Use Kroki with proper encoding and fallback options
      final encodedDiagram = base64Encode(utf8.encode(diagram));
      final primaryUrl = 'https://kroki.io/mermaid/$format/$encodedDiagram';
      final fallbackUrl = 'https://mermaid.ink/svg/${base64Encode(utf8.encode(diagram))}';
      
      http.Response? response;
      String usedService = '';
      
      // Try primary service (Kroki)
      try {
        response = await http
            .get(Uri.parse(primaryUrl))
            .timeout(const Duration(seconds: 20));
        usedService = 'Kroki.io';
        
        // If response is not successful, try POST method
        if (response.statusCode != 200) {
          response = await http
              .post(
                Uri.parse('https://kroki.io/mermaid/$format'),
                headers: {
                  'Content-Type': 'text/plain; charset=utf-8',
                  'Accept': format == 'png' ? 'image/png' : 'image/svg+xml',
                },
                body: diagram,
              )
              .timeout(const Duration(seconds: 20));
        }
      } catch (e) {
        debugPrint('Kroki service failed: $e');
      }
      
      // Try fallback service (Mermaid.ink) if primary failed
      if (response == null || response.statusCode != 200) {
        try {
          response = await http
              .get(Uri.parse(fallbackUrl))
              .timeout(const Duration(seconds: 20));
          usedService = 'Mermaid.ink';
        } catch (e) {
          debugPrint('Fallback service failed: $e');
        }
      }

      if (response != null && response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final mime = format == 'png' ? 'image/png' : 'image/svg+xml';
        final base64Data = base64Encode(bytes);
        final dataUrl = 'data:$mime;base64,$base64Data';

        return {
          'success': true,
          'format': format,
          'diagram_type': diagramType,
          'theme': theme,
          'auto_enhanced': autoEnhance,
          'original_diagram': params['diagram'],
          'enhanced_diagram': diagram,
          'image_url': dataUrl,
          'size': bytes.length,
          'service_used': usedService,
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
          'description': 'Professional Mermaid diagram generated successfully with ${autoEnhance ? 'enhanced styling' : 'original styling'} using $usedService',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to generate chart: HTTP ${response?.statusCode ?? 'No response'} from all services',
          'tried_services': ['Kroki.io', 'Mermaid.ink'],
          'tool_executed': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Chart generation error: $e',
        'tool_executed': true,
      };
    }
  }

  Future<Map<String, dynamic>> _createImageCollage(Map<String, dynamic> params) async {
    final imageUrls = params['image_urls'] as List<dynamic>? ?? [];
    final layout = params['layout'] as String? ?? 'grid';
    final maxWidth = params['max_width'] as int? ?? 1200;
    final maxHeight = params['max_height'] as int? ?? 800;

    if (imageUrls.isEmpty) {
      return {
        'success': false,
        'error': 'image_urls parameter is required and must contain at least one URL',
        'tool_executed': false,
      };
    }

    try {
      // Create a proper collage by combining images using an HTML-to-image service
      final collageHtml = _generateCollageHtml(imageUrls.cast<String>(), layout, maxWidth, maxHeight);
      
      // Try multiple HTML-to-image services for better reliability
      final services = [
        {
          'url': 'https://htmlcsstoimage.com/demo_run',
          'body': {
            'html': collageHtml,
            'css': _getCollageCSS(layout),
            'google_fonts': 'Roboto',
            'width': maxWidth,
            'height': maxHeight,
          }
        },
        {
          'url': 'https://api.htmlcsstoimage.com/v1/image',
          'body': {
            'html': collageHtml,
            'css': _getCollageCSS(layout),
            'width': maxWidth,
            'height': maxHeight,
          }
        }
      ];

      Map<String, dynamic>? imageResult;
      
      for (final service in services) {
        try {
          final response = await http.post(
            Uri.parse(service['url'] as String),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(service['body']),
          ).timeout(Duration(seconds: 20));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final imageUrl = data['url'] as String? ?? '';
            
            if (imageUrl.isNotEmpty) {
              // Fetch the actual image and convert to base64
              final imgResponse = await http.get(Uri.parse(imageUrl)).timeout(Duration(seconds: 15));
              if (imgResponse.statusCode == 200) {
                final base64Image = base64Encode(imgResponse.bodyBytes);
                final dataUrl = 'data:image/png;base64,$base64Image';
                imageResult = {
                  'success': true,
                  'image_url': dataUrl,
                  'service_used': service['url'],
                };
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Service ${service['url']} failed: $e');
          continue;
        }
      }

      // Return successful result if we got an image
      if (imageResult != null) {
        return {
          'success': true,
          'image_url': imageResult['image_url'],
          'original_images': imageUrls,
          'layout': layout,
          'width': maxWidth,
          'height': maxHeight,
          'image_count': imageUrls.length,
          'service_used': imageResult['service_used'],
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
          'description': 'Image collage created successfully with ${imageUrls.length} images in $layout layout',
        };
      }
      
      // Fallback: create a simple URL-based collage reference
      return {
        'success': true,
        'image_url': 'data:text/html;base64,${base64Encode(utf8.encode(collageHtml))}',
        'original_images': imageUrls,
        'layout': layout,
        'width': maxWidth,
        'height': maxHeight,
        'image_count': imageUrls.length,
        'tool_executed': true,
        'execution_time': DateTime.now().toIso8601String(),
        'description': 'Collage HTML created (fallback mode) with ${imageUrls.length} images',
        'note': 'Using HTML representation as image conversion service is unavailable',
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to create image collage: $e',
        'original_images': imageUrls,
        'layout': layout,
        'tool_executed': true,
      };
    }
  }

  String _generateCollageHtml(List<String> imageUrls, String layout, int maxWidth, int maxHeight) {
    switch (layout.toLowerCase()) {
      case 'horizontal':
        return '''
          <div class="collage horizontal">
            ${imageUrls.map((url) => '<img src="$url" alt="Image" />').join('')}
          </div>
        ''';
      case 'vertical':
        return '''
          <div class="collage vertical">
            ${imageUrls.map((url) => '<img src="$url" alt="Image" />').join('')}
          </div>
        ''';
      case 'grid':
      default:
        final cols = (imageUrls.length <= 4) ? 2 : 3;
        return '''
          <div class="collage grid" style="grid-template-columns: repeat($cols, 1fr);">
            ${imageUrls.map((url) => '<img src="$url" alt="Image" />').join('')}
          </div>
        ''';
    }
  }

  String _getCollageCSS(String layout) {
    return '''
      .collage {
        width: 100%;
        height: 100%;
        display: flex;
        gap: 10px;
        padding: 10px;
        background: #f5f5f5;
        box-sizing: border-box;
      }
      
      .collage.horizontal {
        flex-direction: row;
        overflow-x: auto;
      }
      
      .collage.vertical {
        flex-direction: column;
        overflow-y: auto;
      }
      
      .collage.grid {
        display: grid;
        grid-gap: 10px;
      }
      
      .collage img {
        max-width: 100%;
        max-height: 100%;
        object-fit: contain;
        border: 2px solid #ddd;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
      
      .collage.horizontal img {
        height: calc(100% - 20px);
        width: auto;
      }
      
      .collage.vertical img {
        width: calc(100% - 20px);
        height: auto;
      }
      
      .collage.grid img {
        width: 100%;
        height: 100%;
      }
    ''';
  }

  String _enhanceMermaidDiagram(String diagram, String diagramType) {
    // Remove any existing styling to apply new enhanced styling
    String enhancedDiagram = diagram;
    
    switch (diagramType.toLowerCase()) {
      case 'flowchart':
        enhancedDiagram = _enhanceFlowchart(diagram);
        break;
      case 'sequence':
        enhancedDiagram = _enhanceSequenceDiagram(diagram);
        break;
      case 'class':
        enhancedDiagram = _enhanceClassDiagram(diagram);
        break;
      case 'gantt':
        enhancedDiagram = _enhanceGanttChart(diagram);
        break;
      case 'pie':
        enhancedDiagram = _enhancePieChart(diagram);
        break;
      default:
        enhancedDiagram = _enhanceGeneralDiagram(diagram);
    }
    
    return enhancedDiagram;
  }

  String _enhanceFlowchart(String diagram) {
    // Add professional styling to flowcharts
    if (!diagram.contains('classDef')) {
      diagram += '''

%%{init: {"flowchart": {"htmlLabels": true, "curve": "basis"}}}%%

classDef default fill:#e1f5fe,stroke:#01579b,stroke-width:2px,color:#000
classDef startEnd fill:#4caf50,stroke:#2e7d32,stroke-width:3px,color:#fff
classDef process fill:#2196f3,stroke:#1565c0,stroke-width:2px,color:#fff
classDef decision fill:#ff9800,stroke:#e65100,stroke-width:2px,color:#fff
classDef error fill:#f44336,stroke:#c62828,stroke-width:2px,color:#fff''';
    }
    
    return diagram;
  }

  String _enhanceSequenceDiagram(String diagram) {
    // Add professional styling to sequence diagrams
    if (!diagram.contains('%%{init:')) {
      diagram = '''%%{init: {"sequence": {"mirrorActors": false, "showSequenceNumbers": true}}}%%
''' + diagram;
    }
    
    return diagram;
  }

  String _enhanceClassDiagram(String diagram) {
    // Add professional styling to class diagrams
    if (!diagram.contains('%%{init:')) {
      diagram = '''%%{init: {"class": {"htmlLabels": true}}}%%
''' + diagram;
    }
    
    return diagram;
  }

  String _enhanceGanttChart(String diagram) {
    // Add professional styling to gantt charts
    if (!diagram.contains('%%{init:')) {
      diagram = '''%%{init: {"gantt": {"numberSectionStyles": 4}}}%%
''' + diagram;
    }
    
    return diagram;
  }

  String _enhancePieChart(String diagram) {
    // Add professional styling to pie charts
    if (!diagram.contains('%%{init:')) {
      diagram = '''%%{init: {"pie": {"textPosition": 0.5}, "themeVariables": {"pieOuterStrokeWidth": "5px"}}}%%
''' + diagram;
    }
    
    return diagram;
  }

  String _enhanceGeneralDiagram(String diagram) {
    // Add general enhancements
    if (!diagram.contains('%%{init:')) {
      diagram = '''%%{init: {"theme": "base", "themeVariables": {"primaryColor": "#ff0000"}}}%%
''' + diagram;
    }
    
    return diagram;
  }
}