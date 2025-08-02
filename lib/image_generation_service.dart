import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ImageGenerationService {
  static const String _baseUrl = 'https://ahamai-api.officialprakashkrsingh.workers.dev/v1';
  static const String _apiKey = 'ahamaibyprakash25';

  /// Get available image models
  static Future<Map<String, dynamic>> getImageModels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models/image'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'models': data['model_names'] ?? ['flux', 'turbo'],
          'total_count': data['total_count'] ?? 2,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch models: HTTP ${response.statusCode}',
          'models': ['flux', 'turbo'], // fallback
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
        'models': ['flux', 'turbo'], // fallback
      };
    }
  }

  /// Generate image with direct API call
  static Future<Map<String, dynamic>> generateImage({
    required String prompt,
    String model = 'flux',
    int width = 1024,
    int height = 1024,
    bool enhance = false,
  }) async {
    if (prompt.trim().isEmpty) {
      return {
        'success': false,
        'error': 'Prompt cannot be empty',
      };
    }

    try {
      // Create unique seed to prevent duplicates
      final now = DateTime.now();
      final timestamp = now.microsecondsSinceEpoch;
      final seed = timestamp + prompt.hashCode.abs();

      final response = await http.post(
        Uri.parse('$_baseUrl/images/generations'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
        },
        body: jsonEncode({
          'model': model,
          'prompt': prompt,
          'width': width,
          'height': height,
          'enhance': enhance,
          'seed': seed,
          'timestamp': timestamp,
          'force_unique': true,
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
          'image_url': dataUrl,
          'image_bytes': imageBytes,
          'prompt': prompt,
          'model': model,
          'width': width,
          'height': height,
          'seed': seed,
          'size_kb': (imageBytes.length / 1024).round(),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to generate image: HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to generate image: $e',
      };
    }
  }
}