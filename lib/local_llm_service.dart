import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocalLLM {
  final String id;
  final String name;
  final String description;
  final String endpoint;
  final bool isAvailable;
  final Map<String, dynamic> config;

  LocalLLM({
    required this.id,
    required this.name,
    required this.description,
    required this.endpoint,
    this.isAvailable = false,
    this.config = const {},
  });

  factory LocalLLM.fromJson(Map<String, dynamic> json) {
    return LocalLLM(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      endpoint: json['endpoint'] ?? '',
      isAvailable: json['isAvailable'] ?? false,
      config: json['config'] ?? {},
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
    };
  }
}

class LocalLLMService extends ChangeNotifier {
  static final LocalLLMService _instance = LocalLLMService._internal();
  factory LocalLLMService() => _instance;
  LocalLLMService._internal() {
    _initializeDefaultLLMs();
  }

  final List<LocalLLM> _localLLMs = [];
  LocalLLM? _selectedLLM;
  bool _isInitialized = false;
  bool _isScanning = false;

  List<LocalLLM> get localLLMs => List.unmodifiable(_localLLMs);
  LocalLLM? get selectedLLM => _selectedLLM;
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;

  void _initializeDefaultLLMs() {
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
    notifyListeners();
  }

  void removeLLM(String id) {
    _localLLMs.removeWhere((llm) => llm.id == id);
    if (_selectedLLM?.id == id) {
      _selectedLLM = null;
    }
    notifyListeners();
  }
}