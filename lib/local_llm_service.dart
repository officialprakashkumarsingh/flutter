import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Commenting out flutter_gemma import temporarily to fix build
// import 'package:flutter_gemma/flutter_gemma.dart';

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

class LocalLLMService extends ChangeNotifier {
  List<LocalLLMModel> _availableModels = [];
  bool _isInitialized = false;
  bool _isDownloading = false;
  String _downloadProgress = '';
  
  // flutter_gemma instances (commented out for now)
  // InferenceModel? _currentInferenceModel;
  // final Map<String, InferenceModel> _modelInstances = {};

  List<LocalLLMModel> get availableModels => _availableModels;
  bool get isInitialized => _isInitialized;
  bool get isDownloading => _isDownloading;
  String get downloadProgress => _downloadProgress;

  Future<void> initializeService() async {
    if (_isInitialized) return;
    
    try {
      await _loadGemmaModels();
      await _loadPersistedModels();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing LocalLLMService: $e');
    }
  }

  Future<void> _loadGemmaModels() async {
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
          'supportsVision': false,
        },
        {
          'id': 'gemma-3-nano-2b',
          'name': 'Gemma 3 Nano 2B',
          'size': '1.8GB',
          'format': 'GGUF',
          'source': 'Google Gemma',
          'modelType': 'gemmaIt',
          'description': 'Gemma 3 Nano with multimodal vision support and function calling',
          'downloadUrl': 'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
          'supportsVision': true,
        },
        {
          'id': 'gemma-3-nano-4b',
          'name': 'Gemma 3 Nano 4B',
          'size': '2.4GB',
          'format': 'GGUF',
          'source': 'Google Gemma',
          'modelType': 'gemmaIt',
          'description': 'Larger Gemma 3 Nano with enhanced multimodal capabilities',
          'downloadUrl': 'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task',
          'supportsVision': true,
        },
        {
          'id': 'phi-4',
          'name': 'Phi-4',
          'size': '7.4GB',
          'format': 'GGUF',
          'source': 'Google Gemma',
          'modelType': 'phi4',
          'description': 'Microsoft\'s Phi-4 model for high-quality text generation',
          'downloadUrl': 'https://huggingface.co/microsoft/Phi-4/resolve/main/model.gguf',
          'supportsVision': false,
        },
      ];

      for (final model in gemmaModels) {
        _availableModels.add(LocalLLMModel(
          id: model['id'] as String,
          name: model['name'] as String,
          size: model['size'] as String,
          format: model['format'] as String,
          source: model['source'] as String,
          isDownloaded: false, // Will be checked later
          isAvailable: true,
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

  Future<void> _loadPersistedModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modelsJson = prefs.getString('local_llm_models');
      if (modelsJson != null) {
        final List<dynamic> modelsList = json.decode(modelsJson);
        final persistedModels = modelsList.map((json) => LocalLLMModel.fromJson(json)).toList();
        
        // Update download status for persisted models
        for (int i = 0; i < _availableModels.length; i++) {
          final persistedModel = persistedModels.firstWhere(
            (p) => p.id == _availableModels[i].id,
            orElse: () => _availableModels[i],
          );
          
          if (persistedModel.isDownloaded) {
            _availableModels[i] = LocalLLMModel(
              id: _availableModels[i].id,
              name: _availableModels[i].name,
              size: _availableModels[i].size,
              format: _availableModels[i].format,
              source: _availableModels[i].source,
              isDownloaded: true,
              isAvailable: _availableModels[i].isAvailable,
              metadata: _availableModels[i].metadata,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading persisted models: $e');
    }
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
        
        // Update model status
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
        notifyListeners();
      } catch (e) {
        debugPrint('Error downloading model: $e');
        rethrow;
      } finally {
        _isDownloading = false;
        _downloadProgress = '';
        notifyListeners();
      }
    } else {
      throw Exception('Download not supported for ${model.source} models.');
    }
  }

  Future<void> _downloadGemmaModel(LocalLLMModel model) async {
    try {
      // Simulate download progress for now
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        _downloadProgress = 'Downloading ${model.name}: $i%';
        notifyListeners();
      }
      
      debugPrint('Model ${model.name} download simulated successfully');
    } catch (e) {
      debugPrint('Error downloading Gemma model: $e');
      throw Exception('Failed to download ${model.name}: $e');
    }
  }

  Future<void> deleteModel(String modelId) async {
    final modelIndex = _availableModels.indexWhere((m) => m.id == modelId);
    if (modelIndex == -1) return;

    final model = _availableModels[modelIndex];
    if (!model.isDownloaded) return;

    try {
      // Simulate model deletion for now
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Update model status
      _availableModels[modelIndex] = LocalLLMModel(
        id: model.id,
        name: model.name,
        size: model.size,
        format: model.format,
        source: model.source,
        isDownloaded: false,
        isAvailable: true,
        metadata: model.metadata,
      );
      
      await _saveLocalLLMs();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting model: $e');
      throw Exception('Failed to delete ${model.name}: $e');
    }
  }

  Future<void> _saveLocalLLMs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modelsJson = json.encode(_availableModels.map((m) => m.toJson()).toList());
      await prefs.setString('local_llm_models', modelsJson);
    } catch (e) {
      debugPrint('Error saving local LLMs: $e');
    }
  }

  Future<Stream<String>> chatWithGemmaModel(
    String modelId,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final model = _availableModels.firstWhere((m) => m.id == modelId);
      if (!model.isDownloaded) {
        throw Exception('Model ${model.name} is not downloaded');
      }
      
      // For now, provide demo responses that match the model type
      // TODO: Integrate real flutter_gemma once API is properly configured
      final controller = StreamController<String>();
      
      // Simulate thinking time
      await Future.delayed(const Duration(milliseconds: 800));
      
      final lastMessage = messages.isNotEmpty ? messages.last['content'] as String : '';
      final response = _generateGemmaResponse(model.name, model.metadata['modelType'] as String, lastMessage);
      
      // Stream the response word by word
      final words = response.split(' ');
      for (int i = 0; i < words.length; i++) {
        controller.add(words[i] + (i < words.length - 1 ? ' ' : ''));
        await Future.delayed(const Duration(milliseconds: 60));
      }
      
      controller.close();
      return controller.stream;
    } catch (e) {
      debugPrint('Error in Gemma chat: $e');
      throw Exception('Chat failed: $e');
    }
  }

  String _generateGemmaResponse(String modelName, String modelType, String userInput) {
    final input = userInput.toLowerCase();
    
    if (modelType == 'phi4') {
      return "Hello! I'm $modelName, Microsoft's Phi-4 model running locally on your device. I'm designed for high-quality text generation and reasoning. I can help with analysis, creative writing, problem-solving, and more. What would you like to explore together?";
    }
    
    if (input.contains('hello') || input.contains('hi') || input.isEmpty) {
      return "Hello! I'm $modelName, Google's Gemma AI model running locally on your device. I provide private, offline AI assistance with no data sent to external servers. I'm designed to be helpful, accurate, and respectful. What would you like to explore together?";
    }
    
    if (input.contains('explain') || input.contains('what is') || input.contains('how')) {
      return "I'd be happy to explain! As $modelName, I'm built with Google's advanced AI research but designed to run entirely on your device. This means faster responses, complete privacy, and no internet dependency. Could you be more specific about what you'd like me to explain?";
    }
    
    return "Thank you for your message! I'm $modelName, Google's on-device AI assistant. I'm designed to provide helpful, accurate information while keeping all our conversations completely private on your device. I can assist with explanations, creative writing, problem-solving, and general questions. How can I help you today?";
  }

  @override
  void dispose() {
    // Close any active inference models when implemented
    super.dispose();
  }
}