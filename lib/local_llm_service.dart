import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// TODO: Re-enable when Gradle compatibility issues are resolved
// import 'package:flutter_gemma/flutter_gemma.dart';
import 'models.dart';

class LocalLLMService extends ChangeNotifier {
  List<Map<String, dynamic>> _availableModels = [];
  String _downloadProgress = '';
  
  // Flutter Gemma instances (simulated for now due to Gradle compatibility)
  // InferenceModel? _currentInferenceModel;
  // final Map<String, InferenceModel> _modelInstances = {};

  List<Map<String, dynamic>> get availableModels => _availableModels;
  String get downloadProgress => _downloadProgress;

  LocalLLMService() {
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _loadGemmaModels();
    await _loadPersistedModels();
    notifyListeners();
  }

  Future<void> _loadGemmaModels() async {
    _availableModels = [
      {
        'id': 'gemma-3n-e2b-it',
        'name': 'Gemma 3 Nano E2B (1.5B)',
        'description': 'Compact multimodal model for vision + text',
        'source': 'Google Gemma',
        'downloadUrl': 'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
        'filename': 'gemma-3n-E2B-it-int4.task',
        'modelType': 'gemmaIt',
        'supportImage': true,
        'isDownloaded': false,
        'size': '1.2 GB'
      },
      {
        'id': 'gemma-3n-e4b-it',
        'name': 'Gemma 3 Nano E4B (1.5B)',
        'description': 'Advanced multimodal model for vision + text',
        'source': 'Google Gemma',
        'downloadUrl': 'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task',
        'filename': 'gemma-3n-E4B-it-int4.task',
        'modelType': 'gemmaIt',
        'supportImage': true,
        'isDownloaded': false,
        'size': '1.2 GB'
      },
      {
        'id': 'gemma-3-1b-it',
        'name': 'Gemma 3 1B',
        'description': 'Lightweight text-only model',
        'source': 'Google Gemma',
        'downloadUrl': 'https://huggingface.co/google/gemma-3-1b-it-litert-preview/resolve/main/gemma-3-1b-it-int4.task',
        'filename': 'gemma-3-1b-it-int4.task',
        'modelType': 'gemmaIt',
        'supportImage': false,
        'isDownloaded': false,
        'size': '800 MB'
      },
    ];
    notifyListeners();
  }

  Future<void> _loadPersistedModels() async {
    final prefs = await SharedPreferences.getInstance();
    final modelsJson = prefs.getString('downloaded_models');
    if (modelsJson != null) {
      final downloadedModels = Map<String, bool>.from(jsonDecode(modelsJson));
      for (var model in _availableModels) {
        model['isDownloaded'] = downloadedModels[model['id']] ?? false;
      }
      notifyListeners();
    }
  }

  Future<void> _saveLocalLLMs() async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedModels = <String, bool>{};
    for (var model in _availableModels) {
      downloadedModels[model['id'] as String] = model['isDownloaded'] as bool;
    }
    await prefs.setString('downloaded_models', jsonEncode(downloadedModels));
  }

  // TODO: Re-enable when flutter_gemma is properly integrated
  // ModelType _getModelType(String modelTypeString) {
  //   switch (modelTypeString) {
  //     case 'gemmaIt':
  //       return ModelType.gemmaIt;
  //     case 'deepSeek':
  //       return ModelType.deepSeek;
  //     case 'phi':
  //       return ModelType.phi;
  //     default:
  //       return ModelType.gemmaIt;
  //   }
  // }

  // Future<InferenceModel> _getOrCreateInferenceModel(String modelId) async {
  //   if (_modelInstances.containsKey(modelId)) {
  //     return _modelInstances[modelId]!;
  //   }

  //   final model = _availableModels.firstWhere((m) => m['id'] == modelId);
  //   final gemma = FlutterGemmaPlugin.instance;

  //   final inferenceModel = await gemma.createModel(
  //     modelType: _getModelType(model['modelType'] as String),
  //     preferredBackend: PreferredBackend.gpu,
  //     maxTokens: model['supportImage'] as bool ? 4096 : 2048,
  //     supportImage: model['supportImage'] as bool,
  //     maxNumImages: 1,
  //   );

  //   _modelInstances[modelId] = inferenceModel;
  //   return inferenceModel;
  // }

  Future<void> downloadModel(String modelId) async {
    try {
      final model = _availableModels.firstWhere((m) => m['id'] == modelId);
      
      // TODO: Replace with real flutter_gemma implementation once Gradle is fixed
      // final gemma = FlutterGemmaPlugin.instance;
      // final modelManager = gemma.modelManager;

      _downloadProgress = 'Preparing download...';
      notifyListeners();

      // Simulated download with realistic progress and timing
      final random = Random();
      for (int i = 0; i <= 100; i += random.nextInt(8) + 3) {
        if (i > 100) i = 100;
        await Future.delayed(Duration(milliseconds: 200 + random.nextInt(300)));
        _downloadProgress = 'Downloading ${model['name']}... ${i}%';
        notifyListeners();
        
        // Simulate occasional slower progress for large models
        if (i > 30 && i < 70 && random.nextBool()) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      // Final processing step
      _downloadProgress = 'Processing model...';
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 800));

      // TODO: Real implementation would be:
      // await for (final progress in modelManager.downloadModelFromNetworkWithProgress(
      //   model['downloadUrl'] as String,
      // )) {
      //   _downloadProgress = 'Downloading... ${progress.toStringAsFixed(1)}%';
      //   notifyListeners();
      // }

      // Mark as downloaded
      model['isDownloaded'] = true;
      _downloadProgress = '';
      await _saveLocalLLMs();
      notifyListeners();

    } catch (e) {
      _downloadProgress = '';
      notifyListeners();
      throw Exception('Failed to download model: $e');
    }
  }

  Future<void> deleteModel(String modelId) async {
    try {
      final model = _availableModels.firstWhere((m) => m['id'] == modelId);
      
      // TODO: Replace with real flutter_gemma implementation
      // final gemma = FlutterGemmaPlugin.instance;
      // final modelManager = gemma.modelManager;
      // await modelManager.deleteModel();

      // Simulate deletion process
      await Future.delayed(const Duration(milliseconds: 800));

      // TODO: Close any existing inference model for this model
      // if (_modelInstances.containsKey(modelId)) {
      //   await _modelInstances[modelId]!.close();
      //   _modelInstances.remove(modelId);
      // }

      model['isDownloaded'] = false;
      await _saveLocalLLMs();
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete model: $e');
    }
  }

  Stream<String> chatWithGemmaModel(String modelId, List<Message> messages) async* {
    try {
      final inferenceModel = await _getOrCreateInferenceModel(modelId);
      final model = _availableModels.firstWhere((m) => m['id'] == modelId);
      final supportImage = model['supportImage'] as bool;

      // Create chat instance
      final chat = await inferenceModel.createChat(
        temperature: 0.8,
        randomSeed: 1,
        topK: 1,
        supportImage: supportImage,
      );

      // Convert and add messages to chat
      for (final message in messages) {
        if (message.isUser) {
          Message gemmaMessage;
          if (message.imageBytes != null && supportImage) {
            gemmaMessage = Message.withImage(
              text: message.content,
              imageBytes: message.imageBytes!,
              isUser: true,
            );
          } else {
            gemmaMessage = Message.text(
              text: message.content,
              isUser: true,
            );
          }
          await chat.addQueryChunk(gemmaMessage);
        }
      }

      // Generate response stream
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          yield response.token;
        }
      }

    } catch (e) {
      yield 'Error: ${e.toString()}';
    }
  }

  @override
  void dispose() {
    // Close all model instances
    for (final model in _modelInstances.values) {
      model.close();
    }
    _modelInstances.clear();
    _currentInferenceModel?.close();
    super.dispose();
  }
}