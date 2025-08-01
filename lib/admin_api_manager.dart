import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum AIModel {
  gpt4('GPT-4', 'gpt-4-turbo-preview'),
  gpt35('GPT-3.5 Turbo', 'gpt-3.5-turbo'),
  claude3('Claude 3 Opus', 'claude-3-opus-20240229'),
  claude3Sonnet('Claude 3 Sonnet', 'claude-3-sonnet-20240229'),
  geminiPro('Gemini Pro', 'gemini-pro'),
  gemini15('Gemini 1.5 Pro', 'gemini-1.5-pro-latest'),
  custom('Custom Model', 'custom');

  const AIModel(this.displayName, this.modelId);
  final String displayName;
  final String modelId;
}

enum APIProvider {
  openai('OpenAI', 'https://api.openai.com/v1/chat/completions'),
  anthropic('Anthropic', 'https://api.anthropic.com/v1/messages'),
  google('Google AI', 'https://generativelanguage.googleapis.com/v1beta/models'),
  custom('Custom', 'https://your-api-endpoint.com');

  const APIProvider(this.displayName, this.defaultEndpoint);
  final String displayName;
  final String defaultEndpoint;
}

class APISettings {
  final AIModel model;
  final APIProvider provider;
  final String apiKey;
  final String endpoint;
  final Map<String, String> headers;
  final Map<String, dynamic> parameters;
  final bool isActive;
  final DateTime lastUpdated;

  APISettings({
    required this.model,
    required this.provider,
    required this.apiKey,
    required this.endpoint,
    required this.headers,
    required this.parameters,
    this.isActive = true,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'model': model.name,
    'provider': provider.name,
    'apiKey': apiKey,
    'endpoint': endpoint,
    'headers': headers,
    'parameters': parameters,
    'isActive': isActive,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory APISettings.fromJson(Map<String, dynamic> json) => APISettings(
    model: AIModel.values.firstWhere((e) => e.name == json['model'], orElse: () => AIModel.gpt35),
    provider: APIProvider.values.firstWhere((e) => e.name == json['provider'], orElse: () => APIProvider.openai),
    apiKey: json['apiKey'] ?? '',
    endpoint: json['endpoint'] ?? APIProvider.openai.defaultEndpoint,
    headers: Map<String, String>.from(json['headers'] ?? {}),
    parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
    isActive: json['isActive'] ?? true,
    lastUpdated: DateTime.tryParse(json['lastUpdated'] ?? '') ?? DateTime.now(),
  );

  APISettings copyWith({
    AIModel? model,
    APIProvider? provider,
    String? apiKey,
    String? endpoint,
    Map<String, String>? headers,
    Map<String, dynamic>? parameters,
    bool? isActive,
  }) => APISettings(
    model: model ?? this.model,
    provider: provider ?? this.provider,
    apiKey: apiKey ?? this.apiKey,
    endpoint: endpoint ?? this.endpoint,
    headers: headers ?? this.headers,
    parameters: parameters ?? this.parameters,
    isActive: isActive ?? this.isActive,
  );
}

class AdminAPIManager {
  static const String _settingsKey = 'admin_api_settings';
  static const String _currentConfigKey = 'current_api_config';
  static const String _configHistoryKey = 'api_config_history';
  
  static APISettings? _currentSettings;
  static final List<Function(APISettings)> _listeners = [];

  /// Initialize with default settings
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!prefs.containsKey(_settingsKey)) {
      // Set default configuration
      final defaultSettings = APISettings(
        model: AIModel.gpt35,
        provider: APIProvider.openai,
        apiKey: '',
        endpoint: APIProvider.openai.defaultEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_API_KEY',
        },
        parameters: {
          'temperature': 0.7,
          'max_tokens': 1000,
          'top_p': 1.0,
          'frequency_penalty': 0.0,
          'presence_penalty': 0.0,
        },
      );
      
      await saveAPISettings(defaultSettings);
    }
    
    _currentSettings = await getCurrentAPISettings();
  }

  /// Get current API settings
  static Future<APISettings> getCurrentAPISettings() async {
    if (_currentSettings != null) return _currentSettings!;
    
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    
    if (settingsJson != null) {
      final settings = APISettings.fromJson(jsonDecode(settingsJson));
      _currentSettings = settings;
      return settings;
    }
    
    // Return default settings if none exist
    return APISettings(
      model: AIModel.gpt35,
      provider: APIProvider.openai,
      apiKey: '',
      endpoint: APIProvider.openai.defaultEndpoint,
      headers: {'Content-Type': 'application/json'},
      parameters: {'temperature': 0.7, 'max_tokens': 1000},
    );
  }

  /// Save API settings
  static Future<void> saveAPISettings(APISettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save current settings
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    
    // Save to history
    await _addToHistory(settings);
    
    // Update cached settings
    _currentSettings = settings;
    
    // Notify listeners
    _notifyListeners(settings);
  }

  /// Get all available models for a provider
  static List<AIModel> getModelsForProvider(APIProvider provider) {
    switch (provider) {
      case APIProvider.openai:
        return [AIModel.gpt4, AIModel.gpt35];
      case APIProvider.anthropic:
        return [AIModel.claude3, AIModel.claude3Sonnet];
      case APIProvider.google:
        return [AIModel.geminiPro, AIModel.gemini15];
      case APIProvider.custom:
        return [AIModel.custom];
    }
  }

  /// Get default headers for a provider
  static Map<String, String> getDefaultHeaders(APIProvider provider, String apiKey) {
    switch (provider) {
      case APIProvider.openai:
        return {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        };
      case APIProvider.anthropic:
        return {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        };
      case APIProvider.google:
        return {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        };
      case APIProvider.custom:
        return {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        };
    }
  }

  /// Get default parameters for a model
  static Map<String, dynamic> getDefaultParameters(AIModel model) {
    switch (model) {
      case AIModel.gpt4:
      case AIModel.gpt35:
        return {
          'temperature': 0.7,
          'max_tokens': 1000,
          'top_p': 1.0,
          'frequency_penalty': 0.0,
          'presence_penalty': 0.0,
        };
      case AIModel.claude3:
      case AIModel.claude3Sonnet:
        return {
          'max_tokens': 1000,
          'temperature': 0.7,
        };
      case AIModel.geminiPro:
      case AIModel.gemini15:
        return {
          'temperature': 0.7,
          'maxOutputTokens': 1000,
          'topP': 1.0,
          'topK': 40,
        };
      case AIModel.custom:
        return {
          'temperature': 0.7,
          'max_tokens': 1000,
        };
    }
  }

  /// Test API connection
  static Future<Map<String, dynamic>> testConnection(APISettings settings) async {
    try {
      // This would be implemented with actual HTTP requests
      // For now, returning a mock response
      await Future.delayed(const Duration(seconds: 1));
      
      if (settings.apiKey.isEmpty || settings.apiKey == 'YOUR_API_KEY') {
        return {
          'success': false,
          'error': 'API key is required',
          'statusCode': 401,
        };
      }
      
      return {
        'success': true,
        'message': 'Connection successful',
        'statusCode': 200,
        'responseTime': '1.2s',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'statusCode': 500,
      };
    }
  }

  /// Get configuration history
  static Future<List<APISettings>> getConfigHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_configHistoryKey);
    
    if (historyJson != null) {
      final List<dynamic> historyList = jsonDecode(historyJson);
      return historyList
          .map((json) => APISettings.fromJson(json))
          .toList()
          .reversed
          .take(10) // Keep last 10 configs
          .toList();
    }
    
    return [];
  }

  /// Add settings to history
  static Future<void> _addToHistory(APISettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getConfigHistory();
    
    history.insert(0, settings);
    if (history.length > 10) {
      history.removeRange(10, history.length);
    }
    
    final historyJson = jsonEncode(history.map((s) => s.toJson()).toList());
    await prefs.setString(_configHistoryKey, historyJson);
  }

  /// Add listener for settings changes
  static void addListener(Function(APISettings) listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  static void removeListener(Function(APISettings) listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners
  static void _notifyListeners(APISettings settings) {
    for (final listener in _listeners) {
      listener(settings);
    }
  }

  /// Get quick presets
  static List<APISettings> getQuickPresets() {
    return [
      APISettings(
        model: AIModel.gpt4,
        provider: APIProvider.openai,
        apiKey: '',
        endpoint: APIProvider.openai.defaultEndpoint,
        headers: getDefaultHeaders(APIProvider.openai, ''),
        parameters: getDefaultParameters(AIModel.gpt4),
      ),
      APISettings(
        model: AIModel.claude3,
        provider: APIProvider.anthropic,
        apiKey: '',
        endpoint: APIProvider.anthropic.defaultEndpoint,
        headers: getDefaultHeaders(APIProvider.anthropic, ''),
        parameters: getDefaultParameters(AIModel.claude3),
      ),
      APISettings(
        model: AIModel.geminiPro,
        provider: APIProvider.google,
        apiKey: '',
        endpoint: APIProvider.google.defaultEndpoint,
        headers: getDefaultHeaders(APIProvider.google, ''),
        parameters: getDefaultParameters(AIModel.geminiPro),
      ),
    ];
  }

  /// Reset to default settings
  static Future<void> resetToDefaults() async {
    final defaultSettings = getQuickPresets().first;
    await saveAPISettings(defaultSettings);
  }

  /// Export settings
  static Future<String> exportSettings() async {
    final settings = await getCurrentAPISettings();
    final history = await getConfigHistory();
    
    return jsonEncode({
      'current': settings.toJson(),
      'history': history.map((s) => s.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
    });
  }

  /// Import settings
  static Future<bool> importSettings(String jsonData) async {
    try {
      final data = jsonDecode(jsonData);
      final settings = APISettings.fromJson(data['current']);
      await saveAPISettings(settings);
      return true;
    } catch (e) {
      return false;
    }
  }
}