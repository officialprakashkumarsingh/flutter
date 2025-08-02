import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
      // Handle quoted arguments properly
      final parts = _parseCommandLine(command);
      if (parts.isEmpty || parts[0].toLowerCase() != 'curl') {
        return null;
      }
      
      String? url;
      String method = 'GET';
      Map<String, String> headers = {};
      String? body;
      bool followRedirects = false;
      int? timeout;
      String? userAgent;
      bool includeHeaders = false;
      bool silent = false;
      String? outputFile;
      
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
              final value = header.substring(colonIndex + 1).trim().replaceAll('"', '');
              headers[key] = value;
            }
            i++;
          }
        } else if (part == '-d' || part == '--data' || part == '--data-raw') {
          if (i + 1 < parts.length) {
            body = parts[i + 1];
            // Auto-set Content-Type if it looks like JSON and not already set
            if (body.trim().startsWith('{') && !headers.containsKey('Content-Type')) {
              headers['Content-Type'] = 'application/json';
            }
            if (method == 'GET') method = 'POST'; // Auto-switch to POST for data
            i++;
          }
        } else if (part == '--data-binary') {
          if (i + 1 < parts.length) {
            body = parts[i + 1];
            headers['Content-Type'] = 'application/octet-stream';
            if (method == 'GET') method = 'POST';
            i++;
          }
        } else if (part == '-L' || part == '--location') {
          followRedirects = true;
        } else if (part == '--max-time') {
          if (i + 1 < parts.length) {
            timeout = int.tryParse(parts[i + 1]);
            i++;
          }
        } else if (part == '-A' || part == '--user-agent') {
          if (i + 1 < parts.length) {
            userAgent = parts[i + 1];
            i++;
          }
        } else if (part == '-i' || part == '--include') {
          includeHeaders = true;
        } else if (part == '-s' || part == '--silent') {
          silent = true;
        } else if (part == '-o' || part == '--output') {
          if (i + 1 < parts.length) {
            outputFile = parts[i + 1];
            i++;
          }
        } else if (part == '-u' || part == '--user') {
          if (i + 1 < parts.length) {
            final auth = parts[i + 1];
            final encodedAuth = base64Encode(utf8.encode(auth));
            headers['Authorization'] = 'Basic $encodedAuth';
            i++;
          }
        } else if (part.startsWith('--header=')) {
          final header = part.substring(9);
          final colonIndex = header.indexOf(':');
          if (colonIndex > 0) {
            final key = header.substring(0, colonIndex).trim();
            final value = header.substring(colonIndex + 1).trim().replaceAll('"', '');
            headers[key] = value;
          }
        }
      }
      
      // Auto-detect bearer token patterns in message context
      final bearerToken = _extractBearerToken(command);
      if (bearerToken != null) {
        headers['Authorization'] = 'Bearer $bearerToken';
      }
      
      // Set default user agent if not specified
      if (userAgent != null) {
        headers['User-Agent'] = userAgent;
      } else if (!headers.containsKey('User-Agent')) {
        headers['User-Agent'] = 'AhamAI-CurlAgent/2.0';
      }
      
      if (url == null) return null;
      
      return {
        'url': url,
        'method': method,
        'headers': headers,
        'body': body,
        'followRedirects': followRedirects,
        'timeout': timeout ?? 15, // Increased default timeout
        'includeHeaders': includeHeaders,
        'silent': silent,
        'outputFile': outputFile,
      };
      
    } catch (e) {
      print('❌ CURL: Error parsing command: $e');
      return null;
    }
  }
  
  /// Parse command line arguments properly handling quotes
  static List<String> _parseCommandLine(String command) {
    final parts = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    bool inSingleQuotes = false;
    bool escaped = false;
    
    for (int i = 0; i < command.length; i++) {
      final char = command[i];
      
      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }
      
      if (char == '\\') {
        escaped = true;
        continue;
      }
      
      if (char == '"' && !inSingleQuotes) {
        inQuotes = !inQuotes;
        continue;
      }
      
      if (char == "'" && !inQuotes) {
        inSingleQuotes = !inSingleQuotes;
        continue;
      }
      
      if (char == ' ' && !inQuotes && !inSingleQuotes) {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      
      buffer.write(char);
    }
    
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }
    
    return parts;
  }
  
  /// Extract bearer token from command or surrounding context
  static String? _extractBearerToken(String command) {
    // Look for bearer token in authorization header
    final bearerPattern = RegExp(r'Authorization:\s*Bearer\s+([^\s"]+)', caseSensitive: false);
          final match = bearerPattern.firstMatch(command);
      if (match != null) {
        return match.group(1);
      }
    
    // Look for standalone bearer token mention
    final tokenPattern = RegExp(r'\bbearer[:\s]+([a-zA-Z0-9_\-\.]+)', caseSensitive: false);
          final tokenMatch = tokenPattern.firstMatch(command);
      if (tokenMatch != null) {
        return tokenMatch.group(1);
      }
      
      // Look for API key patterns
      final apiKeyPattern = RegExp(r'\bapi[_\s]*key[:\s]+([a-zA-Z0-9_\-\.]+)', caseSensitive: false);
      final apiMatch = apiKeyPattern.firstMatch(command);
      if (apiMatch != null) {
        return apiMatch.group(1);
      }
      
      return null;
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
      final result = _formatCurlResponse(response, method, params);
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
  static String _formatCurlResponse(http.Response response, String method, [Map<String, dynamic>? params]) {
    final buffer = StringBuffer();
    
    // Enhanced status line with performance metrics
    buffer.writeln('🌐 **Advanced Curl Response**');
    buffer.writeln('🎯 **URL**: ${response.request?.url}');
    buffer.writeln('📊 **Status**: ${response.statusCode} ${response.reasonPhrase ?? _getStatusMeaning(response.statusCode)}');
    buffer.writeln('🔗 **Method**: $method');
    buffer.writeln('📦 **Content Length**: ${response.contentLength ?? response.body.length} bytes');
    
    // Show authentication if used
    if (params != null && params['headers'] != null) {
      final headers = params['headers'] as Map<String, String>;
      if (headers.containsKey('Authorization')) {
        final authType = headers['Authorization']!.split(' ')[0];
        buffer.writeln('🔐 **Authentication**: $authType');
      }
    }
    
    buffer.writeln();
    
    // Enhanced headers analysis
    if (response.headers.isNotEmpty) {
      buffer.writeln('📋 **Response Headers** (${response.headers.length} total):');
      
      // Important headers first
      final importantHeaders = ['content-type', 'cache-control', 'server', 'date', 'expires', 'etag'];
      for (final important in importantHeaders) {
        if (response.headers.containsKey(important)) {
          buffer.writeln('• **${_capitalizeHeader(important)}**: ${response.headers[important]}');
        }
      }
      
      // Other headers
      final otherHeaders = response.headers.entries
          .where((entry) => !importantHeaders.contains(entry.key.toLowerCase()))
          .toList();
      
      if (otherHeaders.isNotEmpty) {
        buffer.writeln('• **Other Headers**:');
        for (final header in otherHeaders) {
          buffer.writeln('  - **${_capitalizeHeader(header.key)}**: ${header.value}');
        }
      }
      buffer.writeln();
    }
    
    // Security analysis
    _addSecurityAnalysis(buffer, response);
    
    // Performance analysis
    _addPerformanceAnalysis(buffer, response);
    
    // Body analysis and formatting (if not HEAD request)
    if (method != 'HEAD' && response.body.isNotEmpty) {
      _formatResponseBody(buffer, response);
    } else if (method == 'HEAD') {
      buffer.writeln('ℹ️ **HEAD Request**: No body content (headers only)');
    } else if (response.body.isEmpty) {
      buffer.writeln('📭 **Empty Response**: No body content returned');
    }
    
    return buffer.toString();
  }
  
  /// Add security analysis to response
  static void _addSecurityAnalysis(StringBuffer buffer, http.Response response) {
    final securityHeaders = {
      'strict-transport-security': '🔒 HSTS',
      'x-frame-options': '🖼️ Frame Protection',
      'x-content-type-options': '📎 Content Sniffing Protection',
      'x-xss-protection': '🛡️ XSS Protection',
      'content-security-policy': '🔐 CSP',
      'referrer-policy': '🔗 Referrer Policy',
    };
    
    final foundSecurity = <String>[];
    for (final entry in securityHeaders.entries) {
      if (response.headers.containsKey(entry.key)) {
        foundSecurity.add(entry.value);
      }
    }
    
    if (foundSecurity.isNotEmpty) {
      buffer.writeln('🛡️ **Security Features**: ${foundSecurity.join(', ')}');
    } else {
      buffer.writeln('⚠️ **Security**: No common security headers detected');
    }
  }
  
  /// Add performance analysis to response
  static void _addPerformanceAnalysis(StringBuffer buffer, http.Response response) {
    final compressionHeaders = ['gzip', 'deflate', 'br'];
    final encoding = response.headers['content-encoding'];
    
    if (encoding != null && compressionHeaders.contains(encoding)) {
      buffer.writeln('⚡ **Compression**: $encoding enabled');
    }
    
    final cacheControl = response.headers['cache-control'];
    if (cacheControl != null) {
      buffer.writeln('💾 **Caching**: $cacheControl');
    }
    
    buffer.writeln();
  }
  
  /// Format response body with smart content detection
  static void _formatResponseBody(StringBuffer buffer, http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final body = response.body;
    
    buffer.writeln('📄 **Response Body**:');
    
    // JSON formatting
    if (contentType.contains('json') || _isJsonContent(body)) {
      try {
        final jsonData = json.decode(body);
        final prettyJson = JsonEncoder.withIndent('  ').convert(jsonData);
        buffer.writeln('```json');
        buffer.writeln(prettyJson.length > 2000 
            ? '${prettyJson.substring(0, 2000)}...\n[JSON truncated - ${prettyJson.length} total characters]'
            : prettyJson);
        buffer.writeln('```');
        buffer.writeln('📊 **JSON Analysis**: ${_analyzeJson(jsonData)}');
      } catch (e) {
        buffer.writeln('```');
        buffer.writeln(body.length > 1000 
            ? '${body.substring(0, 1000)}...\n[Content truncated - ${body.length} total characters]'
            : body);
        buffer.writeln('```');
      }
    }
    // XML/HTML formatting
    else if (contentType.contains('xml') || contentType.contains('html')) {
      buffer.writeln('```${contentType.contains('html') ? 'html' : 'xml'}');
      buffer.writeln(body.length > 1500 
          ? '${body.substring(0, 1500)}...\n[${contentType.contains('html') ? 'HTML' : 'XML'} truncated - ${body.length} total characters]'
          : body);
      buffer.writeln('```');
    }
    // Plain text or other
    else {
      buffer.writeln('```');
      buffer.writeln(body.length > 1000 
          ? '${body.substring(0, 1000)}...\n[Response truncated - ${body.length} total characters]'
          : body);
      buffer.writeln('```');
    }
  }
  
  /// Check if content is JSON
  static bool _isJsonContent(String content) {
    final trimmed = content.trim();
    return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
           (trimmed.startsWith('[') && trimmed.endsWith(']'));
  }
  
  /// Analyze JSON structure
  static String _analyzeJson(dynamic json) {
    if (json is Map) {
      return '${json.length} properties';
    } else if (json is List) {
      return '${json.length} items';
    } else {
      return 'Single value';
    }
  }
  
  /// Capitalize header names
  static String _capitalizeHeader(String header) {
    return header.split('-').map((word) => 
        word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase()
    ).join('-');
  }
  
  /// Get status code meaning
  static String _getStatusMeaning(int code) {
    switch (code) {
      case 200: return 'OK';
      case 201: return 'Created';
      case 204: return 'No Content';
      case 301: return 'Moved Permanently';
      case 302: return 'Found';
      case 400: return 'Bad Request';
      case 401: return 'Unauthorized';
      case 403: return 'Forbidden';
      case 404: return 'Not Found';
      case 429: return 'Too Many Requests';
      case 500: return 'Internal Server Error';
      case 502: return 'Bad Gateway';
      case 503: return 'Service Unavailable';
      default: return 'Unknown';
    }
  }
}