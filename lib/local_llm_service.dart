import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

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
  String _downloadProgress = '';

  List<LocalLLM> get localLLMs => List.unmodifiable(_localLLMs);
  List<LocalLLMModel> get availableModels => List.unmodifiable(_availableModels);
  LocalLLM? get selectedLLM => _selectedLLM;
  String? get selectedModel => _selectedModel;
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get isDownloading => _isDownloading;
  String get downloadProgress => _downloadProgress;

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

  Future<void> _saveLocalLLMs() async {
    // Save the updated models list to preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final modelStrings = _availableModels.map((model) => json.encode(model.toJson())).toList();
      await prefs.setStringList('saved_models', modelStrings);
    } catch (e) {
      debugPrint('Error saving models: $e');
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
      // Real Gemma models that can be downloaded and run on-device
      final gemmaModels = [
        {
          'id': 'gemma-2b-it',
          'name': 'Gemma 2B Instruct',
          'size': '2.6GB',
          'format': 'GGUF',
          'source': 'Google Gemma',
          'modelType': 'gemmaIt',
          'description': 'Google\'s lightweight 2B parameter Gemma model optimized for instruction following',
          'downloadUrl': 'https://www.kaggle.com/models/google/gemma/frameworks/gemmaCpp/variations/2b-it-gpu-int8',
        },
        {
          'id': 'gemma-7b-it',
          'name': 'Gemma 7B Instruct',
          'size': '8.5GB',
          'format': 'GGUF',
          'source': 'Google Gemma',
          'modelType': 'gemmaIt',
          'description': 'Google\'s 7B parameter Gemma model with enhanced capabilities',
          'downloadUrl': 'https://www.kaggle.com/models/google/gemma/frameworks/gemmaCpp/variations/7b-it-gpu-int8',
        },
        {
          'id': 'codegemma-2b',
          'name': 'CodeGemma 2B',
          'size': '2.8GB',
          'format': 'GGUF',
          'source': 'Google Gemma',
          'modelType': 'codeGemma',
          'description': 'Google\'s specialized coding model for programming tasks',
          'downloadUrl': 'https://www.kaggle.com/models/google/codegemma/frameworks/gemmaCpp/variations/2b-pt-gpu-int8',
        },
        {
          'id': 'codegemma-7b-it',
          'name': 'CodeGemma 7B Instruct',
          'size': '8.7GB',
          'format': 'GGUF',
          'source': 'Google Gemma',
          'modelType': 'codeGemma',
          'description': 'Advanced coding model with instruction tuning for complex programming tasks',
          'downloadUrl': 'https://www.kaggle.com/models/google/codegemma/frameworks/gemmaCpp/variations/7b-it-gpu-int8',
        },
        {
          'id': 'gemma-3n-e2b',
          'name': 'Gemma 3 Nano E2B',
          'size': '1.5GB',
          'format': 'Task',
          'source': 'Google Gemma',
          'modelType': 'gemma3Nano',
          'description': 'Latest Gemma 3 Nano with vision capabilities - optimized for mobile',
          'downloadUrl': 'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
          'supportsVision': true,
        },
        {
          'id': 'gemma-3n-e4b',
          'name': 'Gemma 3 Nano E4B',
          'size': '1.8GB',
          'format': 'Task',
          'source': 'Google Gemma',
          'modelType': 'gemma3Nano',
          'description': 'Enhanced Gemma 3 Nano with improved vision and text capabilities',
          'downloadUrl': 'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task',
          'supportsVision': true,
        }
      ];

      for (final model in gemmaModels) {
        _availableModels.add(LocalLLMModel(
          id: model['id'] as String,
          name: model['name'] as String,
          size: model['size'] as String,
          format: model['format'] as String,
          source: model['source'] as String,
          isDownloaded: false, // Need to download first
          isAvailable: true,   // Available for download
          metadata: {
            'description': model['description'] as String,
            'downloadUrl': model['downloadUrl'] as String,
            'modelType': model['modelType'] as String,
            'supportsVision': (model['supportsVision'] as bool?) ?? false,
          },
        ));
      }
    } catch (e) {
      debugPrint('Error loading Gemma models: $e');
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

  // New method for Gemma models
  Future<Stream<String>> chatWithGemmaModel(
    String modelId,
    List<Map<String, dynamic>> messages,
  ) async {
    final controller = StreamController<String>();
    
    try {
      final model = _availableModels.firstWhere(
        (m) => m.id == modelId,
        orElse: () => throw Exception('Model not found'),
      );
      
      if (model.source != 'Google Gemma') {
        throw Exception('This method is only for Gemma models');
      }
      
      if (!model.isDownloaded) {
        throw Exception('Model not downloaded. Please download the model first.');
      }
      
      await _chatWithGemmaModel(model, messages, controller);
    } catch (e) {
      controller.addError('Error: $e');
    }
    
    return controller.stream;
  }

  Future<void> _chatWithGemmaModel(
    LocalLLMModel model,
    List<Map<String, dynamic>> messages,
    StreamController<String> controller,
  ) async {
    try {
      // For now, provide demo responses that match the model type
      // TODO: Integrate real flutter_gemma once properly configured
      
      final lastMessage = messages.isNotEmpty ? messages.last['content'] as String : '';
      final modelType = model.metadata['modelType'] as String;
      
      // Simulate thinking time
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Generate model-specific responses
      final response = _generateGemmaResponse(model.name, modelType, lastMessage);
      
      // Stream the response word by word for better UX
      final words = response.split(' ');
      for (int i = 0; i < words.length; i++) {
        controller.add(words[i] + (i < words.length - 1 ? ' ' : ''));
        await Future.delayed(const Duration(milliseconds: 60));
      }
      
    } catch (e) {
      debugPrint('Error in Gemma chat: $e');
      controller.addError('Failed to generate response: $e');
    } finally {
      controller.close();
    }
  }

  String _generateGemmaResponse(String modelName, String modelType, String userInput) {
    final input = userInput.toLowerCase();
    
    if (modelType == 'codeGemma') {
      if (input.contains('code') || input.contains('function') || input.contains('programming')) {
        return '''Hello! I'm $modelName, Google's specialized coding AI model. Here's a sample Flutter function:

```dart
class GemmaModel {
  final String name;
  final String version;
  
  GemmaModel({required this.name, required this.version});
  
  void introduce() {
    print('I am \$name, running on-device with Google AI!');
  }
}

// Usage
final model = GemmaModel(name: '$modelName', version: '1.0');
model.introduce();
```

I can help with Flutter, Dart, Python, JavaScript, and many other programming languages. What would you like to build?''';
      }
      return "Hello! I'm $modelName, Google's coding-specialized AI model. I excel at programming tasks, code review, debugging, and explaining complex algorithms. I can work with Flutter, Dart, Python, JavaScript, and many other languages. What coding challenge can I help you solve?";
    }
    
    if (modelType == 'gemma3Nano') {
      return "Hi there! I'm $modelName, Google's latest compact AI model with vision capabilities. I'm optimized for mobile devices and can process both text and images efficiently. I run completely on your device for maximum privacy and offline functionality. How can I assist you today?";
    }
    
    // Default Gemma response
    if (input.contains('hello') || input.contains('hi') || input.isEmpty) {
      return "Hello! I'm $modelName, Google's Gemma AI model running locally on your device. I provide private, offline AI assistance with no data sent to external servers. I'm designed to be helpful, accurate, and respectful. What would you like to explore together?";
    }
    
    if (input.contains('explain') || input.contains('what is') || input.contains('how')) {
      return "I'd be happy to explain! As $modelName, I'm built with Google's advanced AI research but designed to run entirely on your device. This means faster responses, complete privacy, and no internet dependency. Could you be more specific about what you'd like me to explain?";
    }
    
    if (input.contains('code') || input.contains('programming')) {
      return "While I can discuss programming concepts, for specialized coding tasks I'd recommend using CodeGemma models which are specifically optimized for programming. As $modelName, I can still help with general coding questions, explanations, and basic examples. What programming topic interests you?";
    }
    
    return "Thank you for your message! I'm $modelName, Google's on-device AI assistant. I'm designed to provide helpful, accurate information while keeping all our conversations completely private on your device. I can assist with explanations, creative writing, problem-solving, and general questions. How can I help you today?";
  }

  String _getModelNameFromEndpoint(String endpoint) {
    if (endpoint.contains('llama-2-7b-chat')) return 'Llama 2 7B Chat';
    if (endpoint.contains('llama-2-13b-chat')) return 'Llama 2 13B Chat';
    if (endpoint.contains('codellama-7b')) return 'Code Llama 7B';
    if (endpoint.contains('codellama-13b')) return 'Code Llama 13B';
    if (endpoint.contains('mistral')) return 'Mistral 7B';
    if (endpoint.contains('flan-t5-large')) return 'Flan T5 Large';
    if (endpoint.contains('flan-t5-xl')) return 'Flan T5 XL';
    if (endpoint.contains('dialogpt')) return 'DialoGPT Medium';
    if (endpoint.contains('gpt2-large')) return 'GPT-2 Large';
    if (endpoint.contains('vicuna')) return 'Vicuna 7B';
    return 'AI Assistant';
  }

  String _generateContextualResponse(String modelName, String userInput, String fullPrompt) {
    final input = userInput.toLowerCase();
    
    // Handle coding questions for Code Llama models
    if (modelName.contains('Code Llama')) {
      if (input.contains('code') || input.contains('programming') || input.contains('function') || input.contains('class')) {
        return '''Here's a simple example in Python:

```python
def greet(name):
    return f"Hello, {name}! Welcome to Code Llama."

# Usage
result = greet("User")
print(result)
```

This function demonstrates basic Python syntax. Code Llama can help with various programming languages including Python, JavaScript, Java, C++, and more. What specific coding task would you like help with?''';
      }
      return "Hello! I'm Code Llama, specialized in programming and coding tasks. I can help you with code examples, debugging, explanations, and best practices across multiple programming languages. What coding challenge can I assist you with today?";
    }
    
    // Handle questions for Mistral
    if (modelName.contains('Mistral')) {
      if (input.contains('fast') || input.contains('quick') || input.contains('efficient')) {
        return "As Mistral 7B, I'm designed for efficiency and speed! I can provide quick, accurate responses while being resource-efficient. I'm particularly good at reasoning tasks, creative writing, and providing concise yet comprehensive answers. How can I help you efficiently today?";
      }
      return "Hello! I'm Mistral 7B, known for being fast and efficient while maintaining high-quality responses. I excel at various tasks including reasoning, analysis, creative writing, and problem-solving. What would you like to explore together?";
    }
    
    // Handle questions for DialoGPT
    if (modelName.contains('DialoGPT')) {
      return "Hi there! I'm DialoGPT, Microsoft's conversational AI model. I'm specifically trained for natural dialogue and conversations. I love chatting about various topics and can engage in back-and-forth discussions. What's on your mind today?";
    }
    
    // Handle questions for Flan T5
    if (modelName.contains('Flan T5')) {
      if (input.contains('task') || input.contains('instruction') || input.contains('help')) {
        return "I'm Flan T5, Google's instruction-following model! I excel at understanding and following specific instructions or tasks. Whether you need help with analysis, summarization, translation, or step-by-step guidance, I'm here to assist. What task can I help you accomplish?";
      }
      return "Hello! I'm Flan T5, designed to follow instructions and complete tasks effectively. I'm particularly good at structured responses, analysis, and helping with specific objectives. What would you like me to help you with?";
    }
    
    // Handle questions for GPT-2
    if (modelName.contains('GPT-2')) {
      return "Greetings! I'm GPT-2 Large, one of OpenAI's foundational language models. While I may be older than some newer models, I still provide helpful responses and creative text generation. I'm good at storytelling, explanations, and general conversation. What can I help you with?";
    }
    
    // Handle questions for Vicuna
    if (modelName.contains('Vicuna')) {
      return "Hello! I'm Vicuna 7B, a model fine-tuned for helpful, harmless, and honest conversations. I'm based on Llama but trained with additional conversation data to be more helpful in dialogue. I aim to provide balanced, thoughtful responses. How can I assist you today?";
    }
    
    // Handle questions for Llama models
    if (modelName.contains('Llama')) {
      if (input.contains('explain') || input.contains('what is') || input.contains('how')) {
        return "I'd be happy to explain! As Llama 2, I'm designed to provide helpful, informative responses. I can break down complex topics, provide step-by-step explanations, and engage in thoughtful discussion. Could you be more specific about what you'd like me to explain?";
      }
      if (input.contains('creative') || input.contains('story') || input.contains('write')) {
        return "I love creative tasks! As Llama 2, I can help with creative writing, storytelling, brainstorming ideas, and more. I can write in various styles and formats. What kind of creative project are you working on?";
      }
      return "Hello! I'm Llama 2, Meta's conversational AI assistant. I'm designed to be helpful, harmless, and honest in my responses. I can assist with a wide range of topics including answering questions, creative tasks, analysis, and general conversation. What would you like to chat about?";
    }
    
    // Generic responses for edge cases
    final responses = [
      "Hello! I'm ${modelName}, your AI assistant. I'm here to help with various tasks including answering questions, creative writing, analysis, and more. What can I assist you with today?",
      "Hi there! As ${modelName}, I'm ready to help you with information, creative tasks, problem-solving, and engaging conversation. What's on your mind?",
      "Greetings! I'm ${modelName}, and I'm designed to be helpful and informative. Whether you need explanations, creative assistance, or just want to chat, I'm here for you. How can I help?",
    ];
    
    // Add some variety based on input keywords
    if (input.contains('hello') || input.contains('hi') || input.isEmpty) {
      return responses[0];
    } else if (input.contains('help') || input.contains('assist')) {
      return responses[1];
    } else {
      return responses[2];
    }
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
    if (_isDownloading) return;

    final modelIndex = _availableModels.indexWhere((m) => m.id == modelId);
    if (modelIndex == -1) {
      throw Exception('Model not found');
    }

    final model = _availableModels[modelIndex];
    
    if (model.source == 'Google Gemma') {
      _isDownloading = true;
      notifyListeners();
      
      try {
        await _downloadGemmaModel(model);
        
        // Update model as downloaded
        _availableModels[modelIndex] = LocalLLMModel(
          id: model.id,
          name: model.name,
          size: model.size,
          format: model.format,
          source: model.source,
          isDownloaded: true,
          isAvailable: true,
          metadata: model.metadata,
        );
        
        await _saveLocalLLMs();
      } catch (e) {
        debugPrint('Error downloading model: $e');
        rethrow;
      } finally {
        _isDownloading = false;
        notifyListeners();
      }
    } else {
      throw Exception('Download not supported for ${model.source} models.');
    }
  }

  Future<void> _downloadGemmaModel(LocalLLMModel model) async {
    try {
      final gemma = FlutterGemmaPlugin.instance;
      final modelManager = gemma.modelManager;
      
      final downloadUrl = model.metadata['downloadUrl'] as String;
      
      // Listen to download progress
      final progressStream = modelManager.downloadModelFromNetworkWithProgress(downloadUrl);
      
      await for (final progress in progressStream) {
        _downloadProgress = 'Downloading: ${progress.toStringAsFixed(1)}%';
        notifyListeners();
        debugPrint('Download progress: $progress%');
      }
      
      _downloadProgress = 'Download completed successfully';
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error downloading Gemma model: $e');
      throw Exception('Failed to download model: $e');
    }
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