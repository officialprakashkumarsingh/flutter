import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Curl Command Agent
/// Executes curl-like HTTP requests safely
class CurlAgent {
  
  /// Execute a curl command safely
  static Future<String?> executeCurl(String command) async {
    try {
      print('🌐 CURL: Executing command: $command');
      
      // Parse curl command
      final curlParams = _parseCurlCommand(command);
      if (curlParams == null) {
        print('🚫 CURL: Invalid curl command format');
        return null;
      }
      
      // Execute HTTP request
      final result = await _executeHttpRequest(curlParams);
      return result;
      
    } catch (e) {
      print('❌ CURL: Error executing curl: $e');
      return null;
    }
  }
  
  /// Check if AI response requests curl execution
  static bool shouldExecuteCurl(String response) {
    final lowerResponse = response.toLowerCase();
    
    // Look for curl indicators
    final curlKeywords = [
      'curl',
      'execute curl',
      'run curl',
      'curl command',
      'make http request',
      'fetch url',
      'http get',
      'http post',
      'api request',
      'test endpoint',
    ];
    
    return curlKeywords.any((keyword) => lowerResponse.contains(keyword)) ||
           response.contains('curl ');
  }
  
  /// Extract curl command from AI response
  static String? extractCurlCommand(String response) {
    // Look for curl command in code blocks
    final codeBlockPattern = RegExp(r'```(?:bash|shell|curl)?\s*\n?(curl\s+[^\n`]+)', multiLine: true, caseSensitive: false);
    final codeMatch = codeBlockPattern.firstMatch(response);
    if (codeMatch != null) {
      return codeMatch.group(1)?.trim();
    }
    
    // Look for inline curl command
    final inlinePattern = RegExp(r'curl\s+[^\n]+', caseSensitive: false);
    final inlineMatch = inlinePattern.firstMatch(response);
    if (inlineMatch != null) {
      return inlineMatch.group(0)?.trim();
    }
    
    return null;
  }
  
  /// Parse curl command into HTTP parameters
  static Map<String, dynamic>? _parseCurlCommand(String command) {
    try {
      final parts = command.split(' ');
      if (parts.isEmpty || parts[0].toLowerCase() != 'curl') {
        return null;
      }
      
      String? url;
      String method = 'GET';
      Map<String, String> headers = {};
      String? body;
      bool followRedirects = false;
      int? timeout;
      
      for (int i = 1; i < parts.length; i++) {
        final part = parts[i];
        
        if (part.startsWith('http://') || part.startsWith('https://')) {
          url = part;
        } else if (part == '-X' || part == '--request') {
          if (i + 1 < parts.length) {
            method = parts[i + 1].toUpperCase();
            i++;
          }
        } else if (part == '-H' || part == '--header') {
          if (i + 1 < parts.length) {
            final header = parts[i + 1];
            final colonIndex = header.indexOf(':');
            if (colonIndex > 0) {
              final key = header.substring(0, colonIndex).trim();
              final value = header.substring(colonIndex + 1).trim();
              headers[key] = value;
            }
            i++;
          }
        } else if (part == '-d' || part == '--data') {
          if (i + 1 < parts.length) {
            body = parts[i + 1];
            if (method == 'GET') method = 'POST'; // Auto-switch to POST for data
            i++;
          }
        } else if (part == '-L' || part == '--location') {
          followRedirects = true;
        } else if (part == '--max-time') {
          if (i + 1 < parts.length) {
            timeout = int.tryParse(parts[i + 1]);
            i++;
          }
        }
      }
      
      if (url == null) return null;
      
      return {
        'url': url,
        'method': method,
        'headers': headers,
        'body': body,
        'followRedirects': followRedirects,
        'timeout': timeout ?? 10, // Default 10 seconds
      };
      
    } catch (e) {
      print('❌ CURL: Error parsing command: $e');
      return null;
    }
  }
  
  /// Execute HTTP request based on parsed parameters
  static Future<String?> _executeHttpRequest(Map<String, dynamic> params) async {
    try {
      final url = Uri.parse(params['url']);
      final method = params['method'] as String;
      final headers = Map<String, String>.from(params['headers']);
      final body = params['body'] as String?;
      final timeout = Duration(seconds: params['timeout'] as int);
      
      // Security check - only allow safe domains
      if (!_isSafeUrl(url)) {
        return '🚫 Security: URL not allowed for curl execution';
      }
      
      http.Response response;
      
      switch (method) {
        case 'GET':
          response = await http.get(url, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await http.post(url, headers: headers, body: body).timeout(timeout);
          break;
        case 'PUT':
          response = await http.put(url, headers: headers, body: body).timeout(timeout);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers).timeout(timeout);
          break;
        case 'HEAD':
          response = await http.head(url, headers: headers).timeout(timeout);
          break;
        default:
          return '🚫 Unsupported HTTP method: $method';
      }
      
      // Format response
      final result = _formatCurlResponse(response, method);
      return result;
      
    } catch (e) {
      return '❌ CURL Error: ${e.toString()}';
    }
  }
  
  /// Check if URL is safe for curl execution
  static bool _isSafeUrl(Uri url) {
    // Block localhost and private IPs for security
    final host = url.host.toLowerCase();
    
    // Block localhost
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return false;
    }
    
    // Block private IP ranges
    if (host.startsWith('192.168.') || 
        host.startsWith('10.') || 
        host.startsWith('172.')) {
      return false;
    }
    
    // Only allow HTTPS for security (with some HTTP exceptions for testing)
    if (url.scheme != 'https' && !_isAllowedHttpSite(host)) {
      return false;
    }
    
    return true;
  }
  
  /// Allow some specific HTTP sites for testing
  static bool _isAllowedHttpSite(String host) {
    final allowedHttpSites = [
      'httpbin.org',
      'jsonplaceholder.typicode.com',
      'api.github.com',
      'httpstat.us',
    ];
    
    return allowedHttpSites.any((site) => host.contains(site));
  }
  
  /// Format curl response for display
  static String _formatCurlResponse(http.Response response, String method) {
    final buffer = StringBuffer();
    
    // Status line
    buffer.writeln('🌐 **Curl Response**');
    buffer.writeln('📊 **Status**: ${response.statusCode} ${response.reasonPhrase}');
    buffer.writeln('🔗 **Method**: $method');
    buffer.writeln();
    
    // Headers
    if (response.headers.isNotEmpty) {
      buffer.writeln('📋 **Response Headers**:');
      response.headers.forEach((key, value) {
        buffer.writeln('• **$key**: $value');
      });
      buffer.writeln();
    }
    
    // Body (if not HEAD request)
    if (method != 'HEAD' && response.body.isNotEmpty) {
      buffer.writeln('📄 **Response Body**:');
      
      // Try to format JSON
      try {
        final jsonData = json.decode(response.body);
        final prettyJson = JsonEncoder.withIndent('  ').convert(jsonData);
        buffer.writeln('```json');
        buffer.writeln(prettyJson);
        buffer.writeln('```');
      } catch (e) {
        // Not JSON, show as text
        buffer.writeln('```');
        buffer.writeln(response.body.length > 1000 
            ? '${response.body.substring(0, 1000)}...\n[Response truncated - ${response.body.length} total characters]'
            : response.body);
        buffer.writeln('```');
      }
    }
    
    return buffer.toString();
  }
}