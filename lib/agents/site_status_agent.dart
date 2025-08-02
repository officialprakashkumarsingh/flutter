import 'dart:io';
import 'package:http/http.dart' as http;

/// Site Status Checker Agent
/// Checks if websites are up or down
class SiteStatusAgent {
  
  /// Check if a website is up or down
  static Future<String?> checkSiteStatus(String url) async {
    try {
      print('🌐 STATUS: Checking site: $url');
      
      // Clean and validate URL
      final cleanUrl = _cleanUrl(url);
      if (cleanUrl == null) {
        return '🚫 Invalid URL format: $url';
      }
      
      // Perform status check
      final result = await _performStatusCheck(cleanUrl);
      return result;
      
    } catch (e) {
      print('❌ STATUS: Error checking site: $e');
      return '❌ Error checking $url: ${e.toString()}';
    }
  }
  
  /// Check if AI response requests site status check
  static bool shouldCheckSiteStatus(String response) {
    final lowerResponse = response.toLowerCase();
    
    // Look for status check indicators
    final statusKeywords = [
      'is up',
      'is down',
      'site status',
      'website status',
      'check if',
      'is working',
      'is online',
      'is offline',
      'status check',
      'ping',
      'test site',
      'check site',
      'website up',
      'website down',
      'server status',
      'uptime',
      'downtime',
    ];
    
    // Must contain status keyword AND a URL-like pattern
    final hasStatusKeyword = statusKeywords.any((keyword) => lowerResponse.contains(keyword));
    final hasUrlPattern = RegExp(r'https?://[^\s]+|www\.[^\s]+|\b[a-zA-Z0-9-]+\.[a-zA-Z]{2,}\b').hasMatch(response);
    
    return hasStatusKeyword && hasUrlPattern;
  }
  
  /// Extract URLs from AI response for status checking
  static List<String> extractUrlsForStatusCheck(String response) {
    final urls = <String>[];
    
    // URL patterns to match
    final urlPatterns = [
      RegExp(r'https?://[^\s\)]+'), // Full URLs
      RegExp(r'www\.[^\s\)]+'), // www URLs
      RegExp(r'\b[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/[^\s\)]*)?'), // Domain URLs
    ];
    
    for (final pattern in urlPatterns) {
      final matches = pattern.allMatches(response);
      for (final match in matches) {
        String url = match.group(0)!;
        
        // Clean up the URL
        url = url.replaceAll(RegExp(r'[,.\)]+$'), ''); // Remove trailing punctuation
        
        if (_isValidUrl(url)) {
          urls.add(url);
        }
      }
    }
    
    return urls.toSet().toList(); // Remove duplicates
  }
  
  /// Clean and validate URL
  static String? _cleanUrl(String url) {
    try {
      String cleanUrl = url.trim();
      
      // Add protocol if missing
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      
      // Validate URL
      final uri = Uri.parse(cleanUrl);
      if (!uri.hasScheme || !uri.hasAuthority || !uri.host.contains('.')) {
        return null;
      }
      
      return cleanUrl;
    } catch (e) {
      return null;
    }
  }
  
  /// Validate if a string could be a URL
  static bool _isValidUrl(String url) {
    try {
      String testUrl = url;
      if (!testUrl.startsWith('http://') && !testUrl.startsWith('https://')) {
        testUrl = 'https://$testUrl';
      }
      
      final uri = Uri.parse(testUrl);
      return uri.hasScheme && uri.hasAuthority && uri.host.contains('.');
    } catch (e) {
      return false;
    }
  }
  
  /// Perform the actual status check
  static Future<String> _performStatusCheck(String url) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Try HEAD request first (faster)
      final headResponse = await http.head(
        Uri.parse(url),
        headers: {
          'User-Agent': 'AhamAI-StatusChecker/1.0',
        },
      ).timeout(const Duration(seconds: 10));
      
      stopwatch.stop();
      
      return _formatStatusResponse(url, headResponse.statusCode, stopwatch.elapsedMilliseconds, 'HEAD');
      
    } catch (e) {
      // If HEAD fails, try GET request
      try {
        stopwatch.reset();
        stopwatch.start();
        
        final getResponse = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'AhamAI-StatusChecker/1.0',
          },
        ).timeout(const Duration(seconds: 15));
        
        stopwatch.stop();
        
        return _formatStatusResponse(url, getResponse.statusCode, stopwatch.elapsedMilliseconds, 'GET');
        
      } catch (e2) {
        stopwatch.stop();
        
        // Determine error type
        String errorType = 'Unknown error';
        if (e2.toString().contains('TimeoutException')) {
          errorType = 'Connection timeout';
        } else if (e2.toString().contains('SocketException')) {
          errorType = 'DNS resolution failed or connection refused';
        } else if (e2.toString().contains('HandshakeException')) {
          errorType = 'SSL/TLS handshake failed';
        } else if (e2.toString().contains('HttpException')) {
          errorType = 'HTTP protocol error';
        }
        
        return _formatErrorResponse(url, errorType, stopwatch.elapsedMilliseconds);
      }
    }
  }
  
  /// Format successful status response
  static String _formatStatusResponse(String url, int statusCode, int responseTime, String method) {
    final buffer = StringBuffer();
    
    // Determine status
    final isUp = statusCode >= 200 && statusCode < 400;
    final statusIcon = isUp ? '✅' : '❌';
    final statusText = isUp ? 'UP' : 'DOWN';
    
    buffer.writeln('🌐 **Site Status Check**');
    buffer.writeln('🔗 **URL**: $url');
    buffer.writeln('$statusIcon **Status**: $statusText');
    buffer.writeln('📊 **HTTP Code**: $statusCode ${_getStatusCodeMeaning(statusCode)}');
    buffer.writeln('⏱️ **Response Time**: ${responseTime}ms');
    buffer.writeln('🔧 **Method**: $method');
    
    // Add interpretation
    if (isUp) {
      buffer.writeln('✅ **Result**: Website is accessible and responding normally');
    } else {
      buffer.writeln('❌ **Result**: Website returned an error status');
      buffer.writeln('💡 **Suggestion**: ${_getStatusCodeSuggestion(statusCode)}');
    }
    
    return buffer.toString();
  }
  
  /// Format error response
  static String _formatErrorResponse(String url, String errorType, int elapsedTime) {
    final buffer = StringBuffer();
    
    buffer.writeln('🌐 **Site Status Check**');
    buffer.writeln('🔗 **URL**: $url');
    buffer.writeln('❌ **Status**: DOWN');
    buffer.writeln('🚫 **Error**: $errorType');
    buffer.writeln('⏱️ **Time Elapsed**: ${elapsedTime}ms');
    buffer.writeln('❌ **Result**: Website is not accessible');
    
    // Add troubleshooting suggestions
    buffer.writeln();
    buffer.writeln('🔍 **Possible Causes**:');
    if (errorType.contains('timeout')) {
      buffer.writeln('• Server is overloaded or very slow');
      buffer.writeln('• Network connectivity issues');
      buffer.writeln('• Firewall blocking requests');
    } else if (errorType.contains('DNS')) {
      buffer.writeln('• Domain name doesn\'t exist');
      buffer.writeln('• DNS server issues');
      buffer.writeln('• Typo in the URL');
    } else if (errorType.contains('SSL')) {
      buffer.writeln('• SSL certificate problems');
      buffer.writeln('• Outdated security protocols');
      buffer.writeln('• Try HTTP instead of HTTPS');
    } else {
      buffer.writeln('• Server is down or not responding');
      buffer.writeln('• Network connectivity problems');
      buffer.writeln('• URL might be incorrect');
    }
    
    return buffer.toString();
  }
  
  /// Get human-readable meaning of HTTP status codes
  static String _getStatusCodeMeaning(int code) {
    switch (code) {
      case 200: return '(OK)';
      case 201: return '(Created)';
      case 301: return '(Moved Permanently)';
      case 302: return '(Found/Redirect)';
      case 304: return '(Not Modified)';
      case 400: return '(Bad Request)';
      case 401: return '(Unauthorized)';
      case 403: return '(Forbidden)';
      case 404: return '(Not Found)';
      case 429: return '(Too Many Requests)';
      case 500: return '(Internal Server Error)';
      case 502: return '(Bad Gateway)';
      case 503: return '(Service Unavailable)';
      case 504: return '(Gateway Timeout)';
      default:
        if (code >= 200 && code < 300) return '(Success)';
        if (code >= 300 && code < 400) return '(Redirect)';
        if (code >= 400 && code < 500) return '(Client Error)';
        if (code >= 500) return '(Server Error)';
        return '(Unknown)';
    }
  }
  
  /// Get suggestion based on status code
  static String _getStatusCodeSuggestion(int code) {
    switch (code) {
      case 404: return 'The page or resource was not found. Check the URL.';
      case 403: return 'Access forbidden. You may not have permission to access this resource.';
      case 401: return 'Authentication required. The site requires login credentials.';
      case 500: return 'Server error. The website\'s server is experiencing problems.';
      case 502: return 'Bad gateway. The server received an invalid response from upstream.';
      case 503: return 'Service unavailable. The server is temporarily overloaded or down for maintenance.';
      case 504: return 'Gateway timeout. The server took too long to respond.';
      case 429: return 'Too many requests. You\'re being rate limited. Try again later.';
      default: return 'Check the website directly in a browser for more details.';
    }
  }
}