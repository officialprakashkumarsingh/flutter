import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocalLLMModel {
  final String id;
  final String name;
  final String size;
  final String format;
  final String source;
  final bool isDownloaded;
  final bool isAvailable;
  final Map<String, dynamic> metadata;

  LocalLLMModel({
    required this.id,
    required this.name,
    required this.size,
    required this.format,
    required this.source,
    this.isDownloaded = false,
    this.isAvailable = false,
    this.metadata = const {},
  });

  factory LocalLLMModel.fromJson(Map<String, dynamic> json) {
    return LocalLLMModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      size: json['size'] ?? '',
      format: json['format'] ?? '',
      source: json['source'] ?? '',
      isDownloaded: json['isDownloaded'] ?? false,
      isAvailable: json['isAvailable'] ?? false,
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'size': size,
      'format': format,
      'source': source,
      'isDownloaded': isDownloaded,
      'isAvailable': isAvailable,
      'metadata': metadata,
    };
  }
}

class LocalLLM {
  final String id;
  final String name;
  final String description;
  final String endpoint;
  final bool isAvailable;
  final Map<String, dynamic> config;
  final List<LocalLLMModel> models;

  LocalLLM({
    required this.id,
    required this.name,
    required this.description,
    required this.endpoint,
    this.isAvailable = false,
    this.config = const {},
    this.models = const [],
  });

  factory LocalLLM.fromJson(Map<String, dynamic> json) {
    final modelsList = (json['models'] as List<dynamic>?)
        ?.map((model) => LocalLLMModel.fromJson(model as Map<String, dynamic>))
        .toList() ?? [];
    
    return LocalLLM(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      endpoint: json['endpoint'] ?? '',
      isAvailable: json['isAvailable'] ?? false,
      config: json['config'] ?? {},
      models: modelsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'endpoint': endpoint,
      'isAvailable': isAvailable,
      'config': config,
      'models': models.map((model) => model.toJson()).toList(),
    };
  }
}

class LocalLLMService extends ChangeNotifier {
  static final LocalLLMService _instance = LocalLLMService._internal();
  factory LocalLLMService() => _instance;
  LocalLLMService._internal() {
    _initializeService();
  }

  final List<LocalLLM> _localLLMs = [];
  final List<LocalLLMModel> _availableModels = [];
  LocalLLM? _selectedLLM;
  String? _selectedModel;
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isDownloading = false;

  List<LocalLLM> get localLLMs => List.unmodifiable(_localLLMs);
  List<LocalLLMModel> get availableModels => List.unmodifiable(_availableModels);
  LocalLLM? get selectedLLM => _selectedLLM;
  String? get selectedModel => _selectedModel;
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get isDownloading => _isDownloading;

  Future<void> _initializeService() async {
    await _loadSavedLLMs();
    await _initializeDefaultLLMs();
    await _loadAvailableModels();
  }

  Future<void> _loadSavedLLMs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLLMs = prefs.getStringList('saved_llms') ?? [];
      
      for (final llmJson in savedLLMs) {
        final llm = LocalLLM.fromJson(json.decode(llmJson));
        _localLLMs.add(llm);
      }
    } catch (e) {
      debugPrint('Error loading saved LLMs: $e');
    }
  }

  Future<void> _saveLLMs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final llmStrings = _localLLMs.map((llm) => json.encode(llm.toJson())).toList();
      await prefs.setStringList('saved_llms', llmStrings);
    } catch (e) {
      debugPrint('Error saving LLMs: $e');
    }
  }

  Future<void> _initializeDefaultLLMs() async {
    _localLLMs.clear();
    
    // Add common local LLM configurations
    _localLLMs.addAll([
      LocalLLM(
        id: 'ollama',
        name: 'Ollama',
        description: 'Local Ollama instance',
        endpoint: 'http://localhost:11434',
        config: {
          'api_path': '/api/generate',
          'models_path': '/api/tags',
          'stream': true,
        },
      ),
      LocalLLM(
        id: 'lm_studio',
        name: 'LM Studio',
        description: 'LM Studio local server',
        endpoint: 'http://localhost:1234',
        config: {
          'api_path': '/v1/chat/completions',
          'models_path': '/v1/models',
          'stream': true,
        },
      ),
      LocalLLM(
        id: 'text_generation_webui',
        name: 'Text Generation WebUI',
        description: 'Oobabooga Text Generation WebUI',
        endpoint: 'http://localhost:5000',
        config: {
          'api_path': '/v1/chat/completions',
          'models_path': '/v1/models',
          'stream': true,
        },
      ),
      LocalLLM(
        id: 'koboldcpp',
        name: 'KoboldCpp',
        description: 'KoboldCpp local server',
        endpoint: 'http://localhost:5001',
        config: {
          'api_path': '/v1/chat/completions',
          'models_path': '/v1/models',
          'stream': true,
        },
      ),
      LocalLLM(
        id: 'custom',
        name: 'Custom Endpoint',
        description: 'Custom local LLM endpoint',
        endpoint: 'http://localhost:8080',
        config: {
          'api_path': '/v1/chat/completions',
          'models_path': '/v1/models',
          'stream': true,
        },
      ),
    ]);
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadAvailableModels() async {
    try {
      // Load hosted models that don't require local servers
      await _loadHostedModels();
      
      // Load local models if available
      await _loadLocalModels();
      
    } catch (e) {
      debugPrint('Error loading available models: $e');
    }
  }

  Future<void> _loadHostedModels() async {
    try {
      // Hosted models that work without local servers - using public APIs
      final hostedModels = [
        {
          'id': 'llama-2-7b-chat',
          'name': 'Llama 2 7B Chat',
          'size': 'Hosted',
          'format': 'API',
          'source': 'Hosted Models',
          'endpoint': 'https://api-inference.huggingface.co/models/meta-llama/Llama-2-7b-chat-hf',
          'description': 'Meta\'s Llama 2 7B model optimized for chat'
        },
        {
          'id': 'llama-2-13b-chat',
          'name': 'Llama 2 13B Chat',
          'size': 'Hosted',
          'format': 'API',
          'source': 'Hosted Models',
          'endpoint': 'https://api-inference.huggingface.co/models/meta-llama/Llama-2-13b-chat-hf',
          'description': 'Meta\'s Llama 2 13B model - more capable than 7B'
        },
        {
          'id': 'codellama-7b',
          'name': 'Code Llama 7B',
          'size': 'Hosted',
          'format': 'API',
          'source': 'Hosted Models',
          'endpoint': 'https://api-inference.huggingface.co/models/codellama/CodeLlama-7b-hf',
          'description': 'Meta\'s specialized coding model'
        },
        {
          'id': 'codellama-13b',
          'name': 'Code Llama 13B',
          'size': 'Hosted',
          'format': 'API',
          'source': 'Hosted Models',
          'endpoint': 'https://api-inference.huggingface.co/models/codellama/CodeLlama-13b-hf',
          'description': 'Larger Code Llama for complex coding tasks'
        },
        {
          'id': 'mistral-7b',
          'name': 'Mistral 7B',
          'size': 'Hosted',
          'format': 'API',
          'source': 'Hosted Models',
          'endpoint': 'https://api-inference.huggingface.co/models/mistralai/Mistral-7B-v0.1',
          'description': 'Mistral AI\'s efficient 7B parameter model'
        },
        {
          'id': 'flan-t5-large',
          'name': 'Flan T5 Large',
          'size': 'Hosted',
          'format': 'API',
          'source': 'Hosted Models',
          'endpoint': 'https://api-inference.huggingface.co/models/google/flan-t5-large',
          'description': 'Google\'s instruction-tuned T5 model'
        },
        {
          'id': 'flan-t5-xl',
          'name': 'Flan T5 XL',
          'size': 'Hosted',
          'format': 'API',
          'source': 'Hosted Models',
          'endpoint': 'https://api-inference.huggingface.co/models/google/flan-t5-xl',
          'description': 'Larger version of Flan T5 for better performance'
        },
        {
          'id': 'dialogpt-medium',
          'name': 'DialoGPT Medium',
          'size': 'Hosted',
          'format': 'API',
          'source': 'Hosted Models',
          'endpoint': 'https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium',
          'description': 'Microsoft\'s conversational AI model'
        },
        {
          'id': 'gpt2-large',
          'name': 'GPT-2 Large',
          'size': 'Hosted',
          'format': 'API',
          'source': 'Hosted Models',
          'endpoint': 'https://api-inference.huggingface.co/models/gpt2-large',
          'description': 'OpenAI\'s GPT-2 Large model'
        },
        {
          'id': 'vicuna-7b',
          'name': 'Vicuna 7B',
          'size': 'Hosted',
          'format': 'API',
          'source': 'Hosted Models',
          'endpoint': 'https://api-inference.huggingface.co/models/lmsys/vicuna-7b-v1.5',
          'description': 'LMSYS Vicuna 7B - fine-tuned from Llama'
        }
      ];

      for (final model in hostedModels) {
        _availableModels.add(LocalLLMModel(
          id: model['id']!,
          name: model['name']!,
          size: model['size']!,
          format: model['format']!,
          source: model['source']!,
          isDownloaded: true, // Hosted models are always "available"
          isAvailable: true,   // No download needed
          metadata: {
            'endpoint': model['endpoint']!,
            'description': model['description']!,
          },
        ));
      }
    } catch (e) {
      debugPrint('Error loading hosted models: $e');
    }
  }

  Future<void> _loadLocalModels() async {
    try {
      // Check for local model directories
      final commonPaths = [
        '~/.ollama/models',
        '~/models',
        '/usr/local/share/ollama/models',
        '/opt/ollama/models',
      ];

      for (final path in commonPaths) {
        await _scanLocalDirectory(path);
      }
    } catch (e) {
      debugPrint('Error loading local models: $e');
    }
  }

  Future<void> _scanLocalDirectory(String path) async {
    try {
      final directory = Directory(path);
      if (await directory.exists()) {
        await for (final entity in directory.list()) {
          if (entity is File && entity.path.endsWith('.gguf')) {
            final fileName = entity.path.split('/').last;
            final stats = await entity.stat();
            final size = '${(stats.size / (1024 * 1024)).round()}MB';
            
            _availableModels.add(LocalLLMModel(
              id: fileName,
              name: fileName.replaceAll('.gguf', ''),
              size: size,
              format: 'GGUF',
              source: 'Local Directory',
              isDownloaded: true,
              isAvailable: true,
              metadata: {'path': entity.path},
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory $path: $e');
    }
  }

  Future<void> scanForAvailableLLMs() async {
    _isScanning = true;
    notifyListeners();

    try {
      for (int i = 0; i < _localLLMs.length; i++) {
        final llm = _localLLMs[i];
        final isAvailable = await _checkLLMAvailability(llm);
        
        _localLLMs[i] = LocalLLM(
          id: llm.id,
          name: llm.name,
          description: llm.description,
          endpoint: llm.endpoint,
          isAvailable: isAvailable,
          config: llm.config,
        );
      }
    } catch (e) {
      debugPrint('Error scanning for LLMs: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> _checkLLMAvailability(LocalLLM llm) async {
    try {
      final uri = Uri.parse('${llm.endpoint}${llm.config['models_path'] ?? '/v1/models'}');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void selectLLM(LocalLLM llm) {
    _selectedLLM = llm;
    notifyListeners();
  }

  Future<List<String>> getAvailableModels(LocalLLM llm) async {
    try {
      final uri = Uri.parse('${llm.endpoint}${llm.config['models_path'] ?? '/v1/models'}');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different API response formats
        if (llm.id == 'ollama') {
          // Ollama format
          final models = data['models'] as List?;
          return models?.map((m) => m['name'] as String).toList() ?? [];
        } else {
          // OpenAI-compatible format
          final models = data['data'] as List?;
          return models?.map((m) => m['id'] as String).toList() ?? [];
        }
      }
    } catch (e) {
      debugPrint('Error fetching models for ${llm.name}: $e');
    }
    return [];
  }

  Future<Stream<String>> chatWithLocalLLM(
    LocalLLM llm,
    String model,
    List<Map<String, dynamic>> messages,
  ) async {
    final controller = StreamController<String>();
    
    try {
      if (llm.id == 'ollama') {
        await _chatWithOllama(llm, model, messages, controller);
      } else {
        await _chatWithOpenAICompatible(llm, model, messages, controller);
      }
    } catch (e) {
      controller.addError('Error: $e');
    }
    
    return controller.stream;
  }

  // New method for hosted models
  Future<Stream<String>> chatWithHostedModel(
    String modelId,
    List<Map<String, dynamic>> messages,
  ) async {
    final controller = StreamController<String>();
    
    try {
      final model = _availableModels.firstWhere(
        (m) => m.id == modelId,
        orElse: () => throw Exception('Model not found'),
      );
      
      if (model.source != 'Hosted Models') {
        throw Exception('This method is only for hosted models');
      }
      
      final endpoint = model.metadata['endpoint'] as String;
      await _chatWithHuggingFaceAPI(endpoint, messages, controller);
    } catch (e) {
      controller.addError('Error: $e');
    }
    
    return controller.stream;
  }

  Future<void> _chatWithHuggingFaceAPI(
    String endpoint,
    List<Map<String, dynamic>> messages,
    StreamController<String> controller,
  ) async {
    // Convert messages to prompt
    final prompt = _convertMessagesToPrompt(messages);
    
    final request = http.Request('POST', Uri.parse(endpoint));
    request.headers['Content-Type'] = 'application/json';
    
    // Use the free Hugging Face Inference API
    request.body = json.encode({
      'inputs': prompt,
      'parameters': {
        'max_new_tokens': 512,
        'temperature': 0.7,
        'do_sample': true,
        'return_full_text': false,
      },
      'options': {
        'wait_for_model': true,
      }
    });

    try {
      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = json.decode(responseBody);
        
        String generatedText = '';
        if (data is List && data.isNotEmpty) {
          generatedText = data[0]['generated_text'] ?? '';
        } else if (data is Map) {
          generatedText = data['generated_text'] ?? data['answer'] ?? data['response'] ?? '';
        }
        
        if (generatedText.isNotEmpty) {
          // Stream the response word by word for better UX
          final words = generatedText.split(' ');
          for (int i = 0; i < words.length; i++) {
            controller.add(words[i] + (i < words.length - 1 ? ' ' : ''));
            await Future.delayed(const Duration(milliseconds: 50));
          }
        } else {
          controller.add('Model response was empty. The model might be loading - please try again in a moment.');
        }
      } else if (response.statusCode == 503) {
        controller.add('Model is currently loading, please try again in a few seconds...');
      } else {
        final errorBody = await response.stream.bytesToString();
        debugPrint('API Error: ${response.statusCode} - $errorBody');
        controller.add('Error: Unable to get response from the model. Status: ${response.statusCode}');
      }
      
      client.close();
    } catch (e) {
      debugPrint('Chat error: $e');
      controller.add('Error connecting to the model: $e');
    }
    
    controller.close();
  }

  Future<void> _chatWithOllama(
    LocalLLM llm,
    String model,
    List<Map<String, dynamic>> messages,
    StreamController<String> controller,
  ) async {
    final prompt = _convertMessagesToPrompt(messages);
    
    final uri = Uri.parse('${llm.endpoint}${llm.config['api_path'] ?? '/api/generate'}');
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({
      'model': model,
      'prompt': prompt,
      'stream': true,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);
      
      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          for (final line in chunk.split('\n')) {
            if (line.trim().isNotEmpty) {
              try {
                final data = json.decode(line);
                final text = data['response'] as String?;
                if (text != null) {
                  controller.add(text);
                }
                if (data['done'] == true) {
                  controller.close();
                  return;
                }
              } catch (e) {
                // Continue on JSON parsing errors
              }
            }
          }
        }
      } else {
        controller.addError('HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
    
    controller.close();
  }

  Future<void> _chatWithOpenAICompatible(
    LocalLLM llm,
    String model,
    List<Map<String, dynamic>> messages,
    StreamController<String> controller,
  ) async {
    final uri = Uri.parse('${llm.endpoint}${llm.config['api_path'] ?? '/v1/chat/completions'}');
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({
      'model': model,
      'messages': messages,
      'stream': true,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);
      
      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          for (final line in chunk.split('\n')) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6);
              if (jsonStr.trim() == '[DONE]') {
                controller.close();
                return;
              }
              
              try {
                final data = json.decode(jsonStr);
                final content = data['choices']?[0]?['delta']?['content'];
                if (content != null) {
                  controller.add(content);
                }
              } catch (e) {
                // Continue on JSON parsing errors
              }
            }
          }
        }
      } else {
        controller.addError('HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
    
    controller.close();
  }

  String _convertMessagesToPrompt(List<Map<String, dynamic>> messages) {
    final buffer = StringBuffer();
    for (final message in messages) {
      final role = message['role'] as String;
      final content = message['content'] as String;
      
      if (role == 'system') {
        buffer.writeln('System: $content');
      } else if (role == 'user') {
        buffer.writeln('Human: $content');
      } else if (role == 'assistant') {
        buffer.writeln('Assistant: $content');
      }
    }
    buffer.write('Assistant: ');
    return buffer.toString();
  }

  Future<void> downloadModel(String modelId) async {
    final modelIndex = _availableModels.indexWhere((m) => m.id == modelId);
    if (modelIndex == -1) {
      throw Exception('Model not found');
    }

    final model = _availableModels[modelIndex];
    
    if (model.source == 'Hosted Models') {
      // Hosted models are always ready - no download needed
      debugPrint('Hosted model ${model.name} is ready to use!');
      return;
    }
    
    throw Exception('Download not supported for ${model.source} models. Use hosted models for instant access.');
  }

  Future<void> _downloadOllamaModel(LocalLLMModel model) async {
    // Check if Ollama is available
    final ollamaLLM = _localLLMs.firstWhere(
      (llm) => llm.id == 'ollama',
      orElse: () => throw Exception('Ollama not available'),
    );

    if (!ollamaLLM.isAvailable) {
      throw Exception('Ollama server not running');
    }

    // Use Ollama's pull command via API with real streaming
    final uri = Uri.parse('${ollamaLLM.endpoint}/api/pull');
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({'name': model.id});

    final streamedResponse = await http.Client().send(request);
    
    if (streamedResponse.statusCode != 200) {
      throw Exception('Failed to download model: ${streamedResponse.statusCode}');
    }

    // Listen to the stream for REAL progress updates
    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      try {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            final data = json.decode(line);
            final status = data['status'] as String?;
            
            if (status != null) {
              debugPrint('Real download progress: $status');
              
              // Check if download is complete
              if (status.contains('success') || status.contains('complete')) {
                break;
              }
              
              // Handle errors
              if (data.containsKey('error')) {
                throw Exception(data['error']);
              }
            }
          }
        }
      } catch (e) {
        if (e is FormatException) {
          continue; // Skip malformed JSON lines
        }
        rethrow;
      }
    }
  }

  Future<void> _downloadHuggingFaceModel(LocalLLMModel model) async {
    // For now, we'll download Hugging Face models through Ollama
    // This is the most practical approach since Ollama can pull many HF models
    final ollamaLLM = _localLLMs.firstWhere(
      (llm) => llm.id == 'ollama',
      orElse: () => throw Exception('Ollama not available. Install Ollama to download Hugging Face models.'),
    );

    if (!ollamaLLM.isAvailable) {
      throw Exception('Ollama server not running. Start Ollama to download models.');
    }

    // Convert Hugging Face model names to Ollama format if needed
    String ollamaModelName = model.id;
    
    // Map common HF models to Ollama equivalents
    final hfToOllamaMap = {
      'gpt2': 'gpt2',
      'gpt2-medium': 'gpt2:medium',
      'gpt2-large': 'gpt2:large',
      'microsoft/DialoGPT-medium': 'dialogpt:medium',
      'microsoft/DialoGPT-large': 'dialogpt:large',
      'codellama/CodeLlama-7b-hf': 'codellama:7b',
      'codellama/CodeLlama-13b-hf': 'codellama:13b',
      'meta-llama/Llama-2-7b-chat-hf': 'llama2:7b-chat',
      'meta-llama/Llama-2-13b-chat-hf': 'llama2:13b-chat',
    };
    
    if (hfToOllamaMap.containsKey(model.id)) {
      ollamaModelName = hfToOllamaMap[model.id]!;
    }

    // Use Ollama's pull command to download the model
    final uri = Uri.parse('${ollamaLLM.endpoint}/api/pull');
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({'name': ollamaModelName});

    final streamedResponse = await http.Client().send(request);
    
    if (streamedResponse.statusCode != 200) {
      throw Exception('Failed to download model: ${streamedResponse.statusCode}');
    }

    // Listen to the stream for REAL progress updates
    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      try {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            final data = json.decode(line);
            final status = data['status'] as String?;
            
            if (status != null) {
              debugPrint('Real HF download progress: $status');
              
              // Check if download is complete
              if (status.contains('success') || status.contains('complete')) {
                break;
              }
              
              // Handle errors
              if (data.containsKey('error')) {
                throw Exception(data['error']);
              }
            }
          }
        }
      } catch (e) {
        if (e is FormatException) {
          continue; // Skip malformed JSON lines
        }
        rethrow;
      }
    }
  }

  Future<void> deleteModel(String modelId) async {
    final modelIndex = _availableModels.indexWhere((m) => m.id == modelId);
    if (modelIndex == -1) return;

    final model = _availableModels[modelIndex];
    
    try {
      if (model.source == 'Ollama Library') {
        await _deleteOllamaModel(model);
      } else if (model.source == 'Local Directory') {
        await _deleteLocalModel(model);
      }
      
      // Update model status
      _availableModels[modelIndex] = LocalLLMModel(
        id: model.id,
        name: model.name,
        size: model.size,
        format: model.format,
        source: model.source,
        isDownloaded: false,
        isAvailable: false,
        metadata: model.metadata,
      );
    } catch (e) {
      debugPrint('Error deleting model $modelId: $e');
      rethrow;
    }
    
    notifyListeners();
  }

  Future<void> _deleteOllamaModel(LocalLLMModel model) async {
    final ollamaLLM = _localLLMs.firstWhere(
      (llm) => llm.id == 'ollama',
      orElse: () => throw Exception('Ollama not available'),
    );

    final uri = Uri.parse('${ollamaLLM.endpoint}/api/delete');
    final response = await http.delete(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': model.id}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete model: ${response.statusCode}');
    }
  }

  Future<void> _deleteLocalModel(LocalLLMModel model) async {
    final path = model.metadata['path'] as String?;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  List<LocalLLMModel> getModelsBySource(String source) {
    return _availableModels.where((model) => model.source == source).toList();
  }

  List<LocalLLMModel> getDownloadedModels() {
    return _availableModels.where((model) => model.isDownloaded).toList();
  }

  List<LocalLLMModel> getAvailableModelsForDownload() {
    return _availableModels.where((model) => !model.isDownloaded).toList();
  }

  void addCustomLLM(String name, String endpoint) {
    final customLLM = LocalLLM(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: 'Custom LLM endpoint',
      endpoint: endpoint,
      config: {
        'api_path': '/v1/chat/completions',
        'models_path': '/v1/models',
        'stream': true,
      },
    );
    
    _localLLMs.add(customLLM);
    _saveLLMs();
    notifyListeners();
  }

  void removeLLM(String id) {
    _localLLMs.removeWhere((llm) => llm.id == id);
    if (_selectedLLM?.id == id) {
      _selectedLLM = null;
    }
    _saveLLMs();
    notifyListeners();
  }

  Future<void> refreshModels() async {
    _availableModels.clear();
    await _loadAvailableModels();
    await scanForAvailableLLMs();
    notifyListeners();
  }
}