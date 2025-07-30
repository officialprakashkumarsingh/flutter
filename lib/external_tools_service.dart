import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show zlib;
import 'cache_manager.dart';

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
    // Screenshot tool removed - not needed for core functionality

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

    // Image generation completely removed - now handled by direct UI only



    // Image collage tool removed - not needed for core functionality

    // Enhanced PlantUML diagram generation - create professional high-quality diagrams using PlantUML
    _tools['plantuml_chart'] = ExternalTool(
      name: 'plantuml_chart',
      description: 'Generates professional high-quality diagrams using PlantUML with robust syntax support. Supports UML diagrams, flowcharts, sequence diagrams, class diagrams, use case diagrams, component diagrams, deployment diagrams, activity diagrams, state diagrams, and more. Auto-enhances diagram structure and provides multiple fallback services.',
      parameters: {
        'diagram': {'type': 'string', 'description': 'PlantUML diagram code (will be enhanced automatically)', 'required': true},
        'diagram_type': {'type': 'string', 'description': 'Type of diagram (sequence, class, usecase, activity, component, deployment, state, object, timing, mindmap, wbs, gantt, salt)', 'default': 'sequence'},
        'format': {'type': 'string', 'description': 'Image format (svg, png)', 'default': 'png'},
        'quality': {'type': 'string', 'description': 'Image quality (low, medium, high, ultra)', 'default': 'ultra'},
        'resolution': {'type': 'string', 'description': 'Image resolution (720p, 1080p, 1440p, 4k)', 'default': '1080p'},
        'theme': {'type': 'string', 'description': 'PlantUML theme (default, cerulean, cyborg, journal, lumen, sketchy, spacelab, united)', 'default': 'default'},
        'auto_enhance': {'type': 'boolean', 'description': 'Automatically enhance diagram structure and styling', 'default': true},
      },
      execute: _generatePlantUMLChart,
    );

    // Crypto Market Data - Real-time cryptocurrency information
    _tools['crypto_market_data'] = ExternalTool(
      name: 'crypto_market_data',
      description: 'Get real-time cryptocurrency market data including prices, market cap, volume, and 24h changes. Supports multiple coins and currencies.',
      parameters: {
        'coins': {'type': 'string', 'description': 'Comma-separated coin IDs (e.g., "bitcoin,ethereum,cardano")', 'required': true},
        'vs_currencies': {'type': 'string', 'description': 'Currency for prices (usd, eur, btc)', 'default': 'usd'},
        'include_market_cap': {'type': 'boolean', 'description': 'Include market capitalization', 'default': true},
        'include_24hr_vol': {'type': 'boolean', 'description': 'Include 24h trading volume', 'default': true},
        'include_24hr_change': {'type': 'boolean', 'description': 'Include 24h price change', 'default': true},
      },
      execute: _getCryptoMarketData,
    );

    // Crypto Price History - Historical data and charts
    _tools['crypto_price_history'] = ExternalTool(
      name: 'crypto_price_history',
      description: 'Get historical cryptocurrency price data, market cap, and volume over specified time periods with chart data.',
      parameters: {
        'coin_id': {'type': 'string', 'description': 'Cryptocurrency ID (e.g., bitcoin, ethereum)', 'required': true},
        'vs_currency': {'type': 'string', 'description': 'Currency for prices (usd, eur, btc)', 'default': 'usd'},
        'days': {'type': 'string', 'description': 'Time period: 1, 7, 14, 30, 90, 180, 365, max', 'default': '7'},
        'interval': {'type': 'string', 'description': 'Data interval: daily, hourly (if days <= 1)', 'default': 'daily'},
      },
      execute: _getCryptoPriceHistory,
    );

    // Crypto Global Statistics - Market overview and DeFi data
    _tools['crypto_global_stats'] = ExternalTool(
      name: 'crypto_global_stats',
      description: 'Get global cryptocurrency market statistics including total market cap, trading volume, market cap dominance, and DeFi statistics.',
      parameters: {
        'include_defi': {'type': 'boolean', 'description': 'Include DeFi market statistics', 'default': true},
      },
      execute: _getCryptoGlobalStats,
    );

    // Crypto Trending - Trending coins and market sentiment
    _tools['crypto_trending'] = ExternalTool(
      name: 'crypto_trending',
      description: 'Get trending cryptocurrencies, top gainers, top losers, and market sentiment indicators.',
      parameters: {
        'category': {'type': 'string', 'description': 'Type of trending data: search_trending, top_gainers, top_losers', 'default': 'search_trending'},
        'time_period': {'type': 'string', 'description': 'Time period for gainers/losers: 1h, 24h, 7d', 'default': '24h'},
        'limit': {'type': 'int', 'description': 'Number of results to return (max 100)', 'default': 10},
      },
      execute: _getCryptoTrending,
    );

    // Python-based File Operations - External tool execution
    _tools['read_file'] = ExternalTool(
      name: 'read_file',
      description: 'Read content from a file or specific lines from a file using Python execution.',
      parameters: {
        'file_path': {'type': 'string', 'description': 'Path to the file to read', 'required': true},
        'start_line': {'type': 'int', 'description': 'Start line number (1-indexed, optional)', 'default': null},
        'end_line': {'type': 'int', 'description': 'End line number (1-indexed, optional)', 'default': null},
      },
      execute: _executeFileOperation,
    );

    _tools['write_file'] = ExternalTool(
      name: 'write_file',
      description: 'Write content to a file using Python execution.',
      parameters: {
        'file_path': {'type': 'string', 'description': 'Path to the file to write', 'required': true},
        'content': {'type': 'string', 'description': 'Content to write to the file', 'required': true},
        'mode': {'type': 'string', 'description': 'Write mode (w for overwrite, a for append)', 'default': 'w'},
      },
      execute: _executeFileOperation,
    );

    _tools['edit_file'] = ExternalTool(
      name: 'edit_file',
      description: 'Edit a file by replacing old content with new content using Python execution.',
      parameters: {
        'file_path': {'type': 'string', 'description': 'Path to the file to edit', 'required': true},
        'old_content': {'type': 'string', 'description': 'Old content to replace', 'required': true},
        'new_content': {'type': 'string', 'description': 'New content to replace with', 'required': true},
      },
      execute: _executeFileOperation,
    );

    _tools['delete_file'] = ExternalTool(
      name: 'delete_file',
      description: 'Delete a file using Python execution.',
      parameters: {
        'file_path': {'type': 'string', 'description': 'Path to the file to delete', 'required': true},
      },
      execute: _executeFileOperation,
    );

    _tools['list_directory'] = ExternalTool(
      name: 'list_directory',
      description: 'List contents of a directory using Python execution.',
      parameters: {
        'dir_path': {'type': 'string', 'description': 'Path to the directory to list', 'default': '.'},
        'include_hidden': {'type': 'boolean', 'description': 'Include hidden files and directories', 'default': false},
      },
      execute: _executeFileOperation,
    );

    _tools['create_directory'] = ExternalTool(
      name: 'create_directory',
      description: 'Create a directory using Python execution.',
      parameters: {
        'dir_path': {'type': 'string', 'description': 'Path to the directory to create', 'required': true},
      },
      execute: _executeFileOperation,
    );

    _tools['search_files'] = ExternalTool(
      name: 'search_files',
      description: 'Search for files matching a pattern using Python execution.',
      parameters: {
        'pattern': {'type': 'string', 'description': 'Search pattern (glob style)', 'required': true},
        'dir_path': {'type': 'string', 'description': 'Directory to search in', 'default': '.'},
        'extensions': {'type': 'list', 'description': 'List of file extensions to filter', 'default': null},
      },
      execute: _executeFileOperation,
    );

    // Python-based Code Analysis Tools
    _tools['analyze_project_structure'] = ExternalTool(
      name: 'analyze_project_structure',
      description: 'Analyze the overall project structure and dependencies using Python execution.',
      parameters: {
        'max_depth': {'type': 'int', 'description': 'Maximum depth for directory tree analysis', 'default': 3},
      },
      execute: _executeCodeAnalysis,
    );

    _tools['analyze_file_content'] = ExternalTool(
      name: 'analyze_file_content',
      description: 'Analyze the content and structure of a specific file using Python execution.',
      parameters: {
        'file_path': {'type': 'string', 'description': 'Path to the file to analyze', 'required': true},
      },
      execute: _executeCodeAnalysis,
    );

    _tools['generate_implementation_plan'] = ExternalTool(
      name: 'generate_implementation_plan',
      description: 'Generate a detailed implementation plan for a coding task using Python execution.',
      parameters: {
        'task_description': {'type': 'string', 'description': 'Description of the task to implement', 'required': true},
        'relevant_files': {'type': 'list', 'description': 'List of relevant files for context', 'default': null},
      },
      execute: _executeCodeAnalysis,
    );

    // Get Local IP tool removed - not needed for core functionality
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

    // Check cache first (except for real-time tools)
    if (!['crypto_market_data', 'crypto_trending'].contains(toolName)) {
      final cachedResult = await CacheManager.instance.getCachedToolResult(toolName, params);
      if (cachedResult != null) {
        _lastResult = cachedResult;
        _lastToolUsed = toolName;
        notifyListeners();
        return cachedResult;
      }
    }

    _isExecuting = true;
    _currentlyExecutingTools.add(toolName);
    _lastToolUsed = toolName;
    notifyListeners();

    try {
      final result = await _tools[toolName]!.execute(params);
      _lastResult = result;
      
      // Cache successful results
      if (result['success'] == true) {
        await CacheManager.instance.cacheToolResult(toolName, params, result);
      }
      
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

  /// Execute multiple tools SEQUENTIALLY (NO PARALLEL EXECUTION)
  Future<Map<String, Map<String, dynamic>>> executeToolsParallel(List<Map<String, dynamic>> toolCalls) async {
    final results = <String, Map<String, dynamic>>{};
    
    // Execute tools ONE BY ONE instead of in parallel
    for (final call in toolCalls) {
      final toolName = call['tool_name'] as String;
      final params = call['parameters'] as Map<String, dynamic>? ?? {};
      
      debugPrint('Executing tool sequentially: $toolName');
      final result = await executeTool(toolName, params);
      results[toolName] = result;
      
      // Wait between tools to prevent overwhelming
      await Future.delayed(Duration(milliseconds: 200));
    }
    
    return results;
  }

  /// OLD PARALLEL EXECUTION (DISABLED)
  Future<Map<String, Map<String, dynamic>>> _executeToolsParallelOLD(List<Map<String, dynamic>> toolCalls) async {
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
  // Image generation now handled by direct UI



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

  // Image generation method removed - now handled by direct UI






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

  /// Generate PlantUML diagrams with multiple fallback services and high quality
  Future<Map<String, dynamic>> _generatePlantUMLChart(Map<String, dynamic> params) async {
    String diagram = params['diagram']?.toString() ?? '';
    final diagramType = params['diagram_type']?.toString() ?? 'sequence';
    final format = params['format']?.toString() ?? 'png';
    final quality = params['quality']?.toString() ?? 'ultra';
    final resolution = params['resolution']?.toString() ?? '1080p';
    final theme = params['theme']?.toString() ?? 'default';
    final autoEnhance = _parseBool(params['auto_enhance']) ?? true;

    diagram = diagram.trim();

    if (diagram.isEmpty) {
      // Provide a default diagram if none is provided
      diagram = '''
Alice -> Bob: Hello Bob, how are you?
Bob --> Alice: I am good thanks!
''';
    }

    try {
      // Auto-enhance the diagram if requested
      if (autoEnhance) {
        diagram = _enhancePlantUMLDiagram(diagram, diagramType, theme, quality: quality, resolution: resolution);
      }

      // Try PlantUML services with multiple fallbacks
      final services = [
        {
          'name': 'PlantUML Server',
          'method': 'plantuml_server',
        },
        {
          'name': 'Kroki.io',
          'method': 'kroki',
        },
        {
          'name': 'PlantText',
          'method': 'planttext',
        },
      ];

      for (final service in services) {
        try {
          final result = await _tryPlantUMLService(diagram, format, service['method']!, quality: quality, resolution: resolution);
          if (result['success'] == true) {
            return {
              'success': true,
              'format': format,
              'quality': quality,
              'resolution': resolution,
              'diagram_type': diagramType,
              'theme': theme,
              'auto_enhanced': autoEnhance,
              'original_diagram': params['diagram'],
              'enhanced_diagram': diagram,
              'image_url': result['image_url'],
              'size': result['size'],
              'service_used': service['name'],
              'description': 'High-quality PlantUML diagram generated successfully in $resolution resolution with ${autoEnhance ? 'enhanced styling' : 'original styling'} using ${service['name']}',
            };
          }
        } catch (e) {
          debugPrint('${service['name']} failed: $e');
          continue;
        }
      }

      return {
        'success': false,
        'error': 'All PlantUML services failed',
        'message': 'Unable to generate diagram from any available service',
        'tried_services': services.map((s) => s['name']).toList(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'PlantUML generation error: $e',
        'message': 'Error occurred during diagram generation',
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



  // PlantUML Service Implementations
  
  Future<Map<String, dynamic>> _tryPlantUMLService(String diagram, String format, String method, {String quality = 'ultra', String resolution = '1080p'}) async {
    switch (method) {
      case 'plantuml_server':
        return await _generateWithPlantUMLServer(diagram, format, quality: quality, resolution: resolution);
      case 'kroki':
        return await _generateWithKroki(diagram, format, quality: quality, resolution: resolution);
      case 'planttext':
        return await _generateWithPlantText(diagram, format, quality: quality, resolution: resolution);
      default:
        throw Exception('Unknown PlantUML service method: $method');
    }
  }

  Future<Map<String, dynamic>> _generateWithPlantUMLServer(String diagram, String format, {String quality = 'ultra', String resolution = '1080p'}) async {
    try {
      // Use POST method with simple text body for better reliability
      final response = await http.post(
        Uri.parse('https://www.plantuml.com/plantuml/$format'),
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Accept': format == 'png' ? 'image/png' : 'image/svg+xml',
        },
        body: diagram,
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final mime = format == 'png' ? 'image/png' : 'image/svg+xml';
        final base64Data = base64Encode(bytes);
        final dataUrl = 'data:$mime;base64,$base64Data';

        return {
          'success': true,
          'image_url': dataUrl,
          'size': bytes.length,
        };
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Fallback: try with URL encoding
      try {
        final encodedDiagram = _encodePlantUML(diagram);
        final url = 'https://www.plantuml.com/plantuml/$format/$encodedDiagram';
        
        final response = await http.get(Uri.parse(url), headers: {
          'Accept': format == 'png' ? 'image/png' : 'image/svg+xml',
        }).timeout(Duration(seconds: 20));

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final mime = format == 'png' ? 'image/png' : 'image/svg+xml';
          final base64Data = base64Encode(bytes);
          final dataUrl = 'data:$mime;base64,$base64Data';

          return {
            'success': true,
            'image_url': dataUrl,
            'size': bytes.length,
          };
        }
      } catch (e2) {
        // Continue to throw original error
      }
      throw Exception('PlantUML Server failed: $e');
    }
  }

  Future<Map<String, dynamic>> _generateWithKroki(String diagram, String format, {String quality = 'ultra', String resolution = '1080p'}) async {
    final encodedDiagram = base64Encode(utf8.encode(diagram));
    final url = 'https://kroki.io/plantuml/$format/$encodedDiagram';
    
    // Try GET first
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'Accept': format == 'png' ? 'image/png' : 'image/svg+xml',
      }).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final mime = format == 'png' ? 'image/png' : 'image/svg+xml';
        final base64Data = base64Encode(bytes);
        final dataUrl = 'data:$mime;base64,$base64Data';

        return {
          'success': true,
          'image_url': dataUrl,
          'size': bytes.length,
        };
      }
    } catch (e) {
      // Fall back to POST if GET fails
    }

    // Try POST method
    final response = await http.post(
      Uri.parse('https://kroki.io/plantuml/$format'),
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Accept': format == 'png' ? 'image/png' : 'image/svg+xml',
      },
      body: diagram,
    ).timeout(Duration(seconds: 20));

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final mime = format == 'png' ? 'image/png' : 'image/svg+xml';
      final base64Data = base64Encode(bytes);
      final dataUrl = 'data:$mime;base64,$base64Data';

      return {
        'success': true,
        'image_url': dataUrl,
        'size': bytes.length,
      };
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _generateWithPlantText(String diagram, String format, {String quality = 'ultra', String resolution = '1080p'}) async {
    final encodedDiagram = _encodePlantUML(diagram);
    final url = 'https://www.planttext.com/api/plantuml/$format/$encodedDiagram';
    
    final response = await http.get(Uri.parse(url), headers: {
      'Accept': format == 'png' ? 'image/png' : 'image/svg+xml',
    }).timeout(Duration(seconds: 20));

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final mime = format == 'png' ? 'image/png' : 'image/svg+xml';
      final base64Data = base64Encode(bytes);
      final dataUrl = 'data:$mime;base64,$base64Data';

      return {
        'success': true,
        'image_url': dataUrl,
        'size': bytes.length,
      };
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  String _encodePlantUML(String plantuml) {
    try {
      // Simplified PlantUML encoding - use URL encoding instead of complex deflate
      return Uri.encodeComponent(plantuml);
    } catch (e) {
      // Fallback: simple base64 encoding
      return base64Encode(utf8.encode(plantuml)).replaceAll('/', '_').replaceAll('+', '-');
    }
  }

  String _enhancePlantUMLDiagram(String diagram, String diagramType, String theme, {String quality = 'ultra', String resolution = '1080p'}) {
    // Remove existing @startuml and @enduml if present
    diagram = diagram.replaceAll(RegExp(r'@startuml.*?\n?'), '');
    diagram = diagram.replaceAll(RegExp(r'@enduml.*?\n?'), '');
    diagram = diagram.trim();

    String enhanced = '@startuml\n';

    // Add high-quality settings for crisp, HD diagrams
    enhanced += '!define PLANTUML_LIMIT_SIZE 16384\n'; // Increase size limit
    enhanced += 'skinparam dpi 300\n'; // High DPI for crisp quality
    enhanced += 'skinparam antialiasing true\n'; // Smooth edges
    enhanced += 'skinparam shadowing true\n'; // Better visual depth
    enhanced += 'skinparam defaultFontSize 14\n'; // Readable font size
    
    // Resolution-based scaling
    switch (resolution) {
      case '4k':
        enhanced += 'skinparam defaultFontSize 18\n';
        enhanced += 'skinparam minClassWidth 120\n';
        break;
      case '1440p':
        enhanced += 'skinparam defaultFontSize 16\n';
        enhanced += 'skinparam minClassWidth 100\n';
        break;
      case '1080p':
        enhanced += 'skinparam defaultFontSize 14\n';
        enhanced += 'skinparam minClassWidth 80\n';
        break;
      case '720p':
        enhanced += 'skinparam defaultFontSize 12\n';
        enhanced += 'skinparam minClassWidth 60\n';
        break;
    }

    // Add theme if not default
    if (theme != 'default') {
      enhanced += '!theme $theme\n';
    }

    // Add diagram-specific enhancements
    switch (diagramType.toLowerCase()) {
      case 'sequence':
        enhanced += _enhanceSequenceDiagram(diagram);
        break;
      case 'class':
        enhanced += _enhanceClassDiagram(diagram);
        break;
      case 'usecase':
        enhanced += _enhanceUseCaseDiagram(diagram);
        break;
      case 'activity':
        enhanced += _enhanceActivityDiagram(diagram);
        break;
      case 'component':
        enhanced += _enhanceComponentDiagram(diagram);
        break;
      case 'deployment':
        enhanced += _enhanceDeploymentDiagram(diagram);
        break;
      case 'state':
        enhanced += _enhanceStateDiagram(diagram);
        break;
      default:
        enhanced += diagram;
    }

    enhanced += '\n@enduml';
    return enhanced;
  }

  String _enhanceSequenceDiagram(String diagram) {
    if (!diagram.contains('skinparam')) {
      return '''
skinparam backgroundColor #FEFEFE
skinparam actor {
  BackgroundColor #E1F5FE
  BorderColor #01579B
}
skinparam participant {
  BackgroundColor #E8F5E8
  BorderColor #2E7D32
}
skinparam sequence {
  ArrowColor #1976D2
  LifeLineBorderColor #1976D2
  MessageAlignment center
}
autoactivate on

$diagram''';
    }
    return diagram;
  }

  String _enhanceClassDiagram(String diagram) {
    if (!diagram.contains('skinparam')) {
      return '''
skinparam backgroundColor #FEFEFE
skinparam class {
  BackgroundColor #E3F2FD
  BorderColor #1565C0
  ArrowColor #1976D2
}
skinparam stereotypeCBackgroundColor #FFE0B2
hide empty members

$diagram''';
    }
    return diagram;
  }

  String _enhanceUseCaseDiagram(String diagram) {
    if (!diagram.contains('skinparam')) {
      return '''
skinparam backgroundColor #FEFEFE
skinparam usecase {
  BackgroundColor #E8F5E8
  BorderColor #388E3C
  ArrowColor #4CAF50
}
skinparam actor {
  BackgroundColor #FFF3E0
  BorderColor #F57C00
}

$diagram''';
    }
    return diagram;
  }

  String _enhanceActivityDiagram(String diagram) {
    if (!diagram.contains('skinparam')) {
      return '''
skinparam backgroundColor #FEFEFE
skinparam activity {
  BackgroundColor #E1F5FE
  BorderColor #0277BD
  DiamondBackgroundColor #FFF8E1
  DiamondBorderColor #F9A825
}
start

$diagram

stop''';
    }
    return diagram;
  }

  String _enhanceComponentDiagram(String diagram) {
    if (!diagram.contains('skinparam')) {
      return '''
skinparam backgroundColor #FEFEFE
skinparam component {
  BackgroundColor #E8F5E8
  BorderColor #2E7D32
  ArrowColor #4CAF50
}
skinparam interface {
  BackgroundColor #FFF3E0
  BorderColor #F57C00
}

$diagram''';
    }
    return diagram;
  }

  String _enhanceDeploymentDiagram(String diagram) {
    if (!diagram.contains('skinparam')) {
      return '''
skinparam backgroundColor #FEFEFE
skinparam node {
  BackgroundColor #E3F2FD
  BorderColor #1565C0
}
skinparam artifact {
  BackgroundColor #F3E5F5
  BorderColor #7B1FA2
}

$diagram''';
    }
    return diagram;
  }

  String _enhanceStateDiagram(String diagram) {
    if (!diagram.contains('skinparam')) {
      return '''
skinparam backgroundColor #FEFEFE
skinparam state {
  BackgroundColor #E1F5FE
  BorderColor #0277BD
  ArrowColor #1976D2
}

$diagram''';
    }
    return diagram;
  }

  // Crypto Tools Implementation
  
  /// Get real-time cryptocurrency market data with multiple API fallbacks
  Future<Map<String, dynamic>> _getCryptoMarketData(Map<String, dynamic> params) async {
    try {
      // Safe parameter extraction with proper type handling
      String coins = params['coins']?.toString() ?? '';
      final vsCurrencies = params['vs_currencies']?.toString() ?? 'usd';
      final includeMarketCap = _parseBool(params['include_market_cap']) ?? true;
      final include24hrVol = _parseBool(params['include_24hr_vol']) ?? true;
      final include24hrChange = _parseBool(params['include_24hr_change']) ?? true;

      if (coins.isEmpty) {
        return {
          'success': false,
          'error': 'coins parameter is required',
          'message': 'Please provide at least one cryptocurrency ID',
        };
      }

      // Convert symbols to coin IDs
      coins = _convertSymbolsToCoinIds(coins);

      // Try CoinGecko first (primary)
      try {
        final result = await _fetchCoinGeckoMarketData(coins, vsCurrencies, includeMarketCap, include24hrVol, include24hrChange);
        if (result['success'] == true) return result;
      } catch (e) {
        debugPrint('CoinGecko API failed: $e');
      }

      // Try CoinCap as fallback
      try {
        final result = await _fetchCoinCapMarketData(coins);
        if (result['success'] == true) return result;
      } catch (e) {
        debugPrint('CoinCap API failed: $e');
      }

      // Try CryptoCompare as last fallback
      try {
        final result = await _fetchCryptoCompareMarketData(coins, vsCurrencies);
        if (result['success'] == true) return result;
      } catch (e) {
        debugPrint('CryptoCompare API failed: $e');
      }

      return {
        'success': false,
        'error': 'All crypto APIs failed',
        'message': 'Unable to fetch data from CoinGecko, CoinCap, or CryptoCompare',
        'tried_apis': ['CoinGecko', 'CoinCap', 'CryptoCompare'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error fetching crypto market data: $e',
        'message': 'Network or parsing error occurred',
      };
    }
  }

  /// Get historical cryptocurrency price data with multiple API fallbacks
  Future<Map<String, dynamic>> _getCryptoPriceHistory(Map<String, dynamic> params) async {
    try {
      // Safe parameter extraction
      String coinId = params['coin_id']?.toString() ?? '';
      final vsCurrency = params['vs_currency']?.toString() ?? 'usd';
      final days = params['days']?.toString() ?? '7';
      final interval = params['interval']?.toString() ?? 'daily';

      if (coinId.isEmpty) {
        return {
          'success': false,
          'error': 'coin_id parameter is required',
          'message': 'Please provide a cryptocurrency ID',
        };
      }

      // Convert symbol to coin ID if needed
      coinId = _convertSymbolsToCoinIds(coinId);

      // Try CoinGecko first
      try {
        final result = await _fetchCoinGeckoPriceHistory(coinId, vsCurrency, days, interval);
        if (result['success'] == true) return result;
      } catch (e) {
        debugPrint('CoinGecko price history failed: $e');
      }

      // Try CoinCap as fallback
      try {
        final result = await _fetchCoinCapPriceHistory(coinId, days);
        if (result['success'] == true) return result;
      } catch (e) {
        debugPrint('CoinCap price history failed: $e');
      }

      return {
        'success': false,
        'error': 'All price history APIs failed',
        'message': 'Unable to fetch historical data from available APIs',
        'tried_apis': ['CoinGecko', 'CoinCap'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error fetching price history: $e',
        'message': 'Network or parsing error occurred',
      };
    }
  }

  /// Get global cryptocurrency market statistics with API fallbacks
  Future<Map<String, dynamic>> _getCryptoGlobalStats(Map<String, dynamic> params) async {
    try {
      final includeDefi = _parseBool(params['include_defi']) ?? true;

      // Try CoinGecko first
      try {
        final result = await _fetchCoinGeckoGlobalStats(includeDefi);
        if (result['success'] == true) return result;
      } catch (e) {
        debugPrint('CoinGecko global stats failed: $e');
      }

      // Try CoinCap as fallback
      try {
        final result = await _fetchCoinCapGlobalStats();
        if (result['success'] == true) return result;
      } catch (e) {
        debugPrint('CoinCap global stats failed: $e');
      }

      return {
        'success': false,
        'error': 'All global stats APIs failed',
        'message': 'Unable to fetch global statistics from available APIs',
        'tried_apis': ['CoinGecko', 'CoinCap'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error fetching global stats: $e',
        'message': 'Network or parsing error occurred',
      };
    }
  }

  /// Get trending cryptocurrencies and market sentiment with API fallbacks
  Future<Map<String, dynamic>> _getCryptoTrending(Map<String, dynamic> params) async {
    try {
      final category = params['category']?.toString() ?? 'search_trending';
      final timePeriod = params['time_period']?.toString() ?? '24h';
      final limit = _parseInt(params['limit']) ?? 10;

      // Try CoinGecko first
      try {
        final result = await _fetchCoinGeckoTrending(category, timePeriod, limit);
        if (result['success'] == true) return result;
      } catch (e) {
        debugPrint('CoinGecko trending failed: $e');
      }

      // Try CoinCap as fallback
      try {
        final result = await _fetchCoinCapTrending(limit);
        if (result['success'] == true) return result;
      } catch (e) {
        debugPrint('CoinCap trending failed: $e');
      }

      return {
        'success': false,
        'error': 'All trending APIs failed',
        'message': 'Unable to fetch trending data from available APIs',
        'tried_apis': ['CoinGecko', 'CoinCap'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error fetching trending data: $e',
        'message': 'Network or parsing error occurred',
      };
    }
  }

  // Helper methods for safe type parsing
  bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is double) return value.toInt();
    return null;
  }

  // Crypto symbol to coin ID mapping
  String _convertSymbolsToCoinIds(String input) {
    // Common cryptocurrency symbol mappings
    final symbolMap = {
      'btc': 'bitcoin',
      'eth': 'ethereum',
      'ada': 'cardano',
      'dot': 'polkadot',
      'sol': 'solana',
      'matic': 'polygon',
      'avax': 'avalanche-2',
      'link': 'chainlink',
      'atom': 'cosmos',
      'xrp': 'ripple',
      'ltc': 'litecoin',
      'bch': 'bitcoin-cash',
      'xlm': 'stellar',
      'vet': 'vechain',
      'fil': 'filecoin',
      'trx': 'tron',
      'eos': 'eos',
      'xmr': 'monero',
      'dash': 'dash',
      'zec': 'zcash',
      'etc': 'ethereum-classic',
      'bsv': 'bitcoin-sv',
      'xtz': 'tezos',
      'neo': 'neo',
      'mkr': 'maker',
      'comp': 'compound-coin',
      'aave': 'aave',
      'snx': 'havven',
      'uni': 'uniswap',
      'sushi': 'sushi',
      '1inch': '1inch',
      'crv': 'curve-dao-token',
      'yfi': 'yearn-finance',
      'bal': 'balancer',
      'zrx': '0x',
      'bat': 'basic-attention-token',
      'enj': 'enjincoin',
      'mana': 'decentraland',
      'sand': 'the-sandbox',
      'gala': 'gala',
      'axs': 'axie-infinity',
      'chz': 'chiliz',
      'flow': 'flow',
      'icp': 'internet-computer',
      'hbar': 'hedera-hashgraph',
      'algo': 'algorand',
      'egld': 'elrond-erd-2',
      'near': 'near',
      'ftm': 'fantom',
      'one': 'harmony',
      'waves': 'waves',
      'kava': 'kava',
      'band': 'band-protocol',
      'rune': 'thorchain',
      'luna': 'terra-luna',
      'ust': 'terrausd',
      'mir': 'mirror-protocol',
      'anc': 'anchor-protocol',
    };

    // Split by comma and convert each symbol
    final coins = input.split(',');
    final convertedCoins = coins.map((coin) {
      final trimmed = coin.trim().toLowerCase();
      // If it's already a valid coin ID (like 'bitcoin'), keep it as is
      // Otherwise, try to convert from symbol map
      return symbolMap[trimmed] ?? trimmed;
    }).toList();

    return convertedCoins.join(',');
  }

  // CoinGecko API implementations
  Future<Map<String, dynamic>> _fetchCoinGeckoMarketData(String coins, String vsCurrencies, bool includeMarketCap, bool include24hrVol, bool include24hrChange) async {
    final uri = Uri.parse('https://api.coingecko.com/api/v3/simple/price').replace(queryParameters: {
      'ids': coins,
      'vs_currencies': vsCurrencies,
      'include_market_cap': includeMarketCap.toString(),
      'include_24hr_vol': include24hrVol.toString(),
      'include_24hr_change': include24hrChange.toString(),
      'include_last_updated_at': 'true',
    });

    final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'success': true,
        'data': data,
        'message': 'Successfully retrieved crypto market data from CoinGecko',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'CoinGecko API',
      };
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _fetchCoinGeckoPriceHistory(String coinId, String vsCurrency, String days, String interval) async {
    final uri = Uri.parse('https://api.coingecko.com/api/v3/coins/$coinId/market_chart').replace(queryParameters: {
      'vs_currency': vsCurrency,
      'days': days,
      'interval': interval,
    });

    final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'success': true,
        'data': data,
        'coin_id': coinId,
        'currency': vsCurrency,
        'time_period': days,
        'interval': interval,
        'message': 'Successfully retrieved price history from CoinGecko',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'CoinGecko API',
      };
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _fetchCoinGeckoGlobalStats(bool includeDefi) async {
    final uri = Uri.parse('https://api.coingecko.com/api/v3/global');
    final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      Map<String, dynamic> result = {
        'success': true,
        'global_data': data['data'],
        'message': 'Successfully retrieved global market statistics from CoinGecko',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'CoinGecko API',
      };

      // Get DeFi data if requested
      if (includeDefi) {
        try {
          final defiUri = Uri.parse('https://api.coingecko.com/api/v3/global/decentralized_finance_defi');
          final defiResponse = await http.get(defiUri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
          
          if (defiResponse.statusCode == 200) {
            final defiData = json.decode(defiResponse.body);
            result['defi_data'] = defiData['data'];
            result['message'] = 'Successfully retrieved global market and DeFi statistics from CoinGecko';
          }
        } catch (e) {
          result['defi_error'] = 'Failed to fetch DeFi data: $e';
        }
      }

      return result;
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _fetchCoinGeckoTrending(String category, String timePeriod, int limit) async {
    Map<String, dynamic> result = {
      'success': true,
      'category': category,
      'time_period': timePeriod,
      'limit': limit,
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'CoinGecko API',
    };

    if (category == 'search_trending') {
      final uri = Uri.parse('https://api.coingecko.com/api/v3/search/trending');
      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        result['trending_data'] = data;
        result['message'] = 'Successfully retrieved trending search data from CoinGecko';
        return result;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } else if (category == 'top_gainers' || category == 'top_losers') {
      final uri = Uri.parse('https://api.coingecko.com/api/v3/coins/markets').replace(queryParameters: {
        'vs_currency': 'usd',
        'order': 'market_cap_desc',
        'per_page': '100',
        'page': '1',
        'sparkline': 'false',
        'price_change_percentage': timePeriod,
      });

      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        
        data.sort((a, b) {
          final aChange = (a['price_change_percentage_${timePeriod.replaceAll('h', 'h').replaceAll('d', 'd')}'] ?? 0.0) as num;
          final bChange = (b['price_change_percentage_${timePeriod.replaceAll('h', 'h').replaceAll('d', 'd')}'] ?? 0.0) as num;
          return category == 'top_gainers' ? bChange.compareTo(aChange) : aChange.compareTo(bChange);
        });

        result['market_data'] = data.take(limit).toList();
        result['message'] = 'Successfully retrieved $category for $timePeriod period from CoinGecko';
        return result;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    }

    return result;
  }

  // CoinCap API implementations (fallback)
  Future<Map<String, dynamic>> _fetchCoinCapMarketData(String coins) async {
    final coinIds = coins.split(',').map((coin) => coin.trim()).join(',');
    final uri = Uri.parse('https://api.coincap.io/v2/assets').replace(queryParameters: {
      'ids': coinIds,
    });

    final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Transform CoinCap data to match CoinGecko format
      Map<String, dynamic> transformedData = {};
      if (data['data'] is List) {
        for (var asset in data['data']) {
          transformedData[asset['id']] = {
            'usd': double.tryParse(asset['priceUsd'] ?? '0') ?? 0,
            'usd_market_cap': double.tryParse(asset['marketCapUsd'] ?? '0') ?? 0,
            'usd_24h_vol': double.tryParse(asset['volumeUsd24Hr'] ?? '0') ?? 0,
            'usd_24h_change': double.tryParse(asset['changePercent24Hr'] ?? '0') ?? 0,
            'last_updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          };
        }
      }

      return {
        'success': true,
        'data': transformedData,
        'message': 'Successfully retrieved crypto market data from CoinCap (fallback)',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'CoinCap API',
      };
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _fetchCoinCapPriceHistory(String coinId, String days) async {
    final interval = days == '1' ? 'm15' : 'd1';
    final uri = Uri.parse('https://api.coincap.io/v2/assets/$coinId/history').replace(queryParameters: {
      'interval': interval,
    });

    final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Transform CoinCap history to match CoinGecko format
      List<List<num>> prices = [];
      if (data['data'] is List) {
        for (var point in data['data']) {
          final timestamp = point['time'];
          final price = double.tryParse(point['priceUsd'] ?? '0') ?? 0;
          prices.add([timestamp, price]);
        }
      }

      return {
        'success': true,
        'data': {
          'prices': prices,
          'market_caps': [], // CoinCap doesn't provide historical market caps
          'total_volumes': [], // CoinCap doesn't provide historical volumes
        },
        'coin_id': coinId,
        'time_period': days,
        'message': 'Successfully retrieved price history from CoinCap (fallback)',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'CoinCap API',
      };
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _fetchCoinCapGlobalStats() async {
    final uri = Uri.parse('https://api.coincap.io/v2/assets');
    final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data['data'] is List) {
        final assets = data['data'] as List;
        double totalMarketCap = 0;
        double totalVolume = 0;
        
        for (var asset in assets) {
          totalMarketCap += double.tryParse(asset['marketCapUsd'] ?? '0') ?? 0;
          totalVolume += double.tryParse(asset['volumeUsd24Hr'] ?? '0') ?? 0;
        }

        return {
          'success': true,
          'global_data': {
            'total_market_cap': {'usd': totalMarketCap},
            'total_volume': {'usd': totalVolume},
            'active_cryptocurrencies': assets.length,
            'message': 'Global stats calculated from CoinCap top assets',
          },
          'message': 'Successfully retrieved global market statistics from CoinCap (fallback)',
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'CoinCap API',
        };
      }
    }
    
    throw Exception('HTTP ${response.statusCode}');
  }

  Future<Map<String, dynamic>> _fetchCoinCapTrending(int limit) async {
    final uri = Uri.parse('https://api.coincap.io/v2/assets').replace(queryParameters: {
      'limit': limit.toString(),
    });

    final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      return {
        'success': true,
        'trending_data': {
          'coins': data['data'] ?? [],
        },
        'message': 'Successfully retrieved trending data from CoinCap (fallback)',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'CoinCap API',
      };
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  // CryptoCompare API implementation (additional fallback)
  Future<Map<String, dynamic>> _fetchCryptoCompareMarketData(String coins, String vsCurrency) async {
    final coinSymbols = coins.split(',').map((coin) => coin.trim().toUpperCase()).join(',');
    final uri = Uri.parse('https://min-api.cryptocompare.com/data/pricemultifull').replace(queryParameters: {
      'fsyms': coinSymbols,
      'tsyms': vsCurrency.toUpperCase(),
    });

    final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Transform CryptoCompare data
      Map<String, dynamic> transformedData = {};
      if (data['RAW'] is Map) {
        for (var symbol in data['RAW'].keys) {
          final coinData = data['RAW'][symbol][vsCurrency.toUpperCase()];
          transformedData[symbol.toLowerCase()] = {
            vsCurrency: coinData['PRICE'] ?? 0,
            '${vsCurrency}_market_cap': coinData['MKTCAP'] ?? 0,
            '${vsCurrency}_24h_vol': coinData['TOTALVOLUME24HTO'] ?? 0,
            '${vsCurrency}_24h_change': coinData['CHANGEPCT24HOUR'] ?? 0,
            'last_updated_at': coinData['LASTUPDATE'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          };
        }
      }

      return {
        'success': true,
        'data': transformedData,
        'message': 'Successfully retrieved crypto market data from CryptoCompare (fallback)',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'CryptoCompare API',
      };
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  /// Get the local IP address - Network utility
  Future<Map<String, dynamic>> _getLocalIP(Map<String, dynamic> params) async {
    try {
      // Get all network interfaces
      final interfaces = await NetworkInterface.list();
      String? localIP;
      
      // Look for WiFi or ethernet interface
      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('wlan') || 
            interface.name.toLowerCase().contains('wifi') ||
            interface.name.toLowerCase().contains('eth')) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              localIP = addr.address;
              break;
            }
          }
          if (localIP != null) break;
        }
      }
      
      // Fallback to any non-loopback IPv4 address
      if (localIP == null) {
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              localIP = addr.address;
              break;
            }
          }
          if (localIP != null) break;
        }
      }
      
      if (localIP != null) {
        return {
          'success': true,
          'local_ip': localIP,
          'description': 'Local IP address for network connections',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        return {
          'success': false,
          'error': 'No suitable network interface found',
          'description': 'Could not find a non-loopback IPv4 address',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to get local IP: $e',
        'description': 'Error occurred while querying network interfaces',
      };
    }
  }

  /// Execute Python-based file operations with enhanced error handling
  Future<Map<String, dynamic>> _executeFileOperation(Map<String, dynamic> params) async {
    try {
      final String operation = _lastToolUsed; // Use the current tool name as operation
      
      // CRITICAL FIX: Use absolute path to Python script to avoid path issues
      String pythonScriptPath = 'python_tools/file_operations.py';
      
      // Try to find the actual script location
      final possibleScriptPaths = [
        '/workspace/python_tools/file_operations.py',
        'python_tools/file_operations.py',
        '${Directory.current.path}/python_tools/file_operations.py',
        './python_tools/file_operations.py',
      ];
      
      for (final path in possibleScriptPaths) {
        if (File(path).existsSync()) {
          pythonScriptPath = path;
          break;
        }
      }
      
      final List<String> args = ['python3', pythonScriptPath, operation];
      
      // CRITICAL FIX: Ensure we're working in the project root directory
      // The Flutter app might be running from /data/data/... on Android
      // We need to ensure Python tools work in a writable location
      
      String workingDir = Directory.current.path;
      
      // Try to find the actual project root or use a reliable working directory
      final possibleRoots = [
        '/workspace',
        '/tmp/coder_workspace', 
        Directory.current.path,
        '${Directory.current.path}/coder_files',
      ];
      
      String finalWorkingDir = workingDir;
      for (final root in possibleRoots) {
        final dir = Directory(root);
        if (dir.existsSync() || root.startsWith('/tmp')) {
          try {
            if (!dir.existsSync()) {
              dir.createSync(recursive: true);
            }
            // Test if writable
            final testFile = File('$root/.test_write');
            testFile.writeAsStringSync('test');
            testFile.deleteSync();
            finalWorkingDir = root;
            break;
          } catch (e) {
            // Continue to next option
            continue;
          }
        }
      }
      
      args.addAll(['--base-path', finalWorkingDir]);
      
      // Add operation-specific arguments
      switch (operation) {
        case 'read_file':
          args.addAll(['--file-path', params['file_path']]);
          if (params['start_line'] != null) {
            args.addAll(['--start-line', params['start_line'].toString()]);
          }
          if (params['end_line'] != null) {
            args.addAll(['--end-line', params['end_line'].toString()]);
          }
          break;
        case 'write_file':
          args.addAll(['--file-path', params['file_path']]);
          // Use proper escaping for content to handle spaces and special characters
          final content = params['content'] ?? '';
          args.addAll(['--content', content]);
          args.addAll(['--mode', params['mode'] ?? 'w']);
          break;
        case 'edit_file':
          args.addAll(['--file-path', params['file_path']]);
          args.addAll(['--old-content', params['old_content'] ?? '']);
          args.addAll(['--new-content', params['new_content'] ?? '']);
          break;
        case 'delete_file':
          args.addAll(['--file-path', params['file_path']]);
          break;
        case 'list_directory':
          args.addAll(['--dir-path', params['dir_path'] ?? '.']);
          if (params['include_hidden'] == true) {
            args.add('--include-hidden');
          }
          break;
        case 'create_directory':
          args.addAll(['--dir-path', params['dir_path']]);
          break;
        case 'search_files':
          args.addAll(['--pattern', params['pattern']]);
          args.addAll(['--dir-path', params['dir_path'] ?? '.']);
          if (params['extensions'] != null) {
            args.add('--extensions');
            args.addAll((params['extensions'] as List).map((e) => e.toString()));
          }
          break;
      }

      // Debug logging for file operations
      print('DEBUG FILE OPS: Current working directory: ${Directory.current.path}');
      print('DEBUG FILE OPS: Executing command: ${args.join(' ')}');
      print('DEBUG FILE OPS: Full args: $args');
      print('DEBUG FILE OPS: Params: $params');

      final result = await Process.run(args[0], args.sublist(1));
      
      print('DEBUG FILE OPS: Exit code: ${result.exitCode}');
      print('DEBUG FILE OPS: Stdout: ${result.stdout}');
      print('DEBUG FILE OPS: Stderr: ${result.stderr}');
      
      if (result.exitCode == 0) {
        try {
          final Map<String, dynamic> output = json.decode(result.stdout);
          output['timestamp'] = DateTime.now().toIso8601String();
          output['execution_method'] = 'python_external';
          return output;
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to parse Python tool output: $e',
            'raw_output': result.stdout,
            'operation': operation,
          };
        }
      } else {
        // Enhanced error reporting for failed Python tool execution
        return {
          'success': false,
          'error': 'Python tool execution failed',
          'exit_code': result.exitCode,
          'stderr': result.stderr.toString().trim(),
          'stdout': result.stdout.toString().trim(),
          'operation': operation,
          'command_executed': args.join(' '),
          'working_directory': Directory.current.path,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      // Enhanced error reporting for execution failures
      return {
        'success': false,
        'error': 'Failed to execute file operation: $e',
        'operation': _lastToolUsed,
        'working_directory': Directory.current.path,
        'timestamp': DateTime.now().toIso8601String(),
        'error_type': e.runtimeType.toString(),
      };
    }
  }

  /// Execute Python-based code analysis
  Future<Map<String, dynamic>> _executeCodeAnalysis(Map<String, dynamic> params) async {
    try {
      final String operation = _lastToolUsed; // Use the current tool name as operation
      final List<String> args = ['python3', 'python_tools/code_analysis.py', operation];
      
      // Add operation-specific arguments
      switch (operation) {
        case 'analyze_project_structure':
          if (params['max_depth'] != null) {
            args.addAll(['--max-depth', params['max_depth'].toString()]);
          }
          break;
        case 'analyze_file_content':
          args.addAll(['--file-path', params['file_path']]);
          break;
        case 'generate_implementation_plan':
          args.addAll(['--task-description', params['task_description']]);
          if (params['relevant_files'] != null) {
            args.add('--relevant-files');
            args.addAll((params['relevant_files'] as List).map((e) => e.toString()));
          }
          break;
      }

      final result = await Process.run(args[0], args.sublist(1));
      
      if (result.exitCode == 0) {
        try {
          final Map<String, dynamic> output = json.decode(result.stdout);
          output['timestamp'] = DateTime.now().toIso8601String();
          output['execution_method'] = 'python_external';
          return output;
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to parse Python analysis output: $e',
            'raw_output': result.stdout,
            'operation': operation,
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Python analysis tool execution failed',
          'exit_code': result.exitCode,
          'stderr': result.stderr,
          'operation': operation,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to execute code analysis: $e',
        'operation': params['operation'] ?? 'unknown',
      };
    }
  }


}
