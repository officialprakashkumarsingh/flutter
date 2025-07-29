import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ollama_dart/ollama_dart.dart';
import 'models.dart';

class LocalLLMService extends ChangeNotifier {
  List<Map<String, dynamic>> _availableModels = [];
  String _downloadProgress = '';
  OllamaClient? _ollamaClient;
  bool _isOllamaConnected = false;
  String _ollamaStatus = 'Checking Ollama connection...';

  List<Map<String, dynamic>> get availableModels => _availableModels;
  String get downloadProgress => _downloadProgress;
  bool get isOllamaConnected => _isOllamaConnected;
  String get ollamaStatus => _ollamaStatus;

  LocalLLMService() {
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _initializeOllamaClient();
    await _loadAvailableModels();
    await _checkOllamaConnection();
    notifyListeners();
  }

  Future<void> _initializeOllamaClient() async {
    try {
      _ollamaClient = OllamaClient(
        baseUrl: 'http://localhost:11434/api',
      );
    } catch (e) {
      debugPrint('Error initializing Ollama client: $e');
    }
  }

  Future<void> _checkOllamaConnection() async {
    if (_ollamaClient == null) {
      _ollamaStatus = 'Ollama client not initialized';
      _isOllamaConnected = false;
      notifyListeners();
      return;
    }

    try {
      final version = await _ollamaClient!.getVersion();
      _ollamaStatus = 'Connected to Ollama v${version.version}';
      _isOllamaConnected = true;
      await _refreshInstalledModels();
    } catch (e) {
      _ollamaStatus = 'Ollama not running. Please start Ollama server.';
      _isOllamaConnected = false;
      debugPrint('Ollama connection error: $e');
    }
    notifyListeners();
  }

  Future<void> _loadAvailableModels() async {
    _availableModels = [
      {
        'id': 'llama3.2:1b',
        'name': 'Llama 3.2 1B',
        'description': 'Fast and efficient 1B parameter model',
        'size': '1.3 GB',
        'source': 'Meta',
        'isDownloaded': false,
        'isInstalling': false,
        'family': 'llama'
      },
      {
        'id': 'llama3.2:3b',
        'name': 'Llama 3.2 3B',
        'description': 'Balanced performance 3B parameter model',
        'size': '2.0 GB',
        'source': 'Meta',
        'isDownloaded': false,
        'isInstalling': false,
        'family': 'llama'
      },
      {
        'id': 'gemma2:2b',
        'name': 'Gemma 2 2B',
        'description': 'Google\'s efficient 2B parameter model',
        'size': '1.6 GB',
        'source': 'Google',
        'isDownloaded': false,
        'isInstalling': false,
        'family': 'gemma'
      },
      {
        'id': 'phi3.5:3.8b',
        'name': 'Phi-3.5 3.8B',
        'description': 'Microsoft\'s compact yet powerful model',
        'size': '2.2 GB',
        'source': 'Microsoft',
        'isDownloaded': false,
        'isInstalling': false,
        'family': 'phi'
      },
      {
        'id': 'qwen2.5:1.5b',
        'name': 'Qwen2.5 1.5B',
        'description': 'Alibaba\'s multilingual model',
        'size': '1.0 GB',
        'source': 'Alibaba',
        'isDownloaded': false,
        'isInstalling': false,
        'family': 'qwen'
      },
      {
        'id': 'mistral:7b',
        'name': 'Mistral 7B',
        'description': 'High-quality 7B parameter model',
        'size': '4.1 GB',
        'source': 'Mistral AI',
        'isDownloaded': false,
        'isInstalling': false,
        'family': 'mistral'
      },
    ];
  }

  Future<void> _refreshInstalledModels() async {
    if (!_isOllamaConnected || _ollamaClient == null) return;

    try {
      final models = await _ollamaClient!.listModels();
      final installedModelNames = models.models?.map((m) => m.model).toSet() ?? {};

      for (var model in _availableModels) {
        model['isDownloaded'] = installedModelNames.contains(model['id']);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing installed models: $e');
    }
  }

  Future<void> downloadModel(String modelId) async {
    if (!_isOllamaConnected || _ollamaClient == null) {
      throw Exception('Ollama is not connected. Please start Ollama server.');
    }

    final model = _availableModels.firstWhere((m) => m['id'] == modelId);
    model['isInstalling'] = true;
    _downloadProgress = 'Starting download...';
    notifyListeners();

    try {
      final stream = _ollamaClient!.pullModelStream(
        request: PullModelRequest(model: modelId),
      );

      await for (final response in stream) {
        final status = response.status ?? '';
        
        if (response.completed != null && response.total != null) {
          final progress = (response.completed! / response.total!) * 100;
          _downloadProgress = 'Downloading ${model['name']}: ${progress.toStringAsFixed(1)}%';
        } else {
          _downloadProgress = 'Downloading ${model['name']}: $status';
        }
        notifyListeners();

        if (status.toLowerCase().contains('success') || 
            status.toLowerCase().contains('complete')) {
          break;
        }
      }

      model['isDownloaded'] = true;
      model['isInstalling'] = false;
      _downloadProgress = '';
      notifyListeners();

    } catch (e) {
      model['isInstalling'] = false;
      _downloadProgress = '';
      notifyListeners();
      throw Exception('Failed to download $modelId: $e');
    }
  }

  Future<void> deleteModel(String modelId) async {
    if (!_isOllamaConnected || _ollamaClient == null) {
      throw Exception('Ollama is not connected. Please start Ollama server.');
    }

    try {
      await _ollamaClient!.deleteModel(model: modelId);
      
      final model = _availableModels.firstWhere((m) => m['id'] == modelId);
      model['isDownloaded'] = false;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete $modelId: $e');
    }
  }

  Stream<String> chatWithOllamaModel(String modelId, List<Message> messages) async* {
    if (!_isOllamaConnected || _ollamaClient == null) {
      yield 'Error: Ollama is not connected. Please start Ollama server.';
      return;
    }

    try {
      // Convert our messages to Ollama format
      final ollamaMessages = messages.map((msg) {
        return ollama_dart.Message(
          role: msg.isUser ? MessageRole.user : MessageRole.assistant,
          content: msg.content,
        );
      }).toList();

      // Generate chat completion stream
      final stream = _ollamaClient!.generateChatCompletionStream(
        request: GenerateChatCompletionRequest(
          model: modelId,
          messages: ollamaMessages,
          stream: true,
        ),
      );

      await for (final response in stream) {
        final content = response.message?.content;
        if (content != null && content.isNotEmpty) {
          yield content;
        }
      }
    } catch (e) {
      yield 'Error: Failed to generate response: $e';
    }
  }

  Future<void> refreshConnection() async {
    _ollamaStatus = 'Reconnecting...';
    notifyListeners();
    await _checkOllamaConnection();
  }

  Future<List<Map<String, dynamic>>> getRunningModels() async {
    if (!_isOllamaConnected || _ollamaClient == null) {
      return [];
    }

    try {
      final response = await _ollamaClient!.listRunningModels();
      return response.models?.map((model) => {
        'name': model.name ?? '',
        'model': model.model ?? '',
        'size': model.size ?? 0,
        'digest': model.digest ?? '',
        'details': model.details?.toJson() ?? {},
        'expires_at': model.expiresAt?.toIso8601String() ?? '',
        'size_vram': model.sizeVram ?? 0,
      }).toList() ?? [];
    } catch (e) {
      debugPrint('Error getting running models: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _ollamaClient = null;
    super.dispose();
  }
}