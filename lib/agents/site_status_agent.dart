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
  
  /// Perform the actual status check with advanced analysis
  static Future<String> _performStatusCheck(String url) async {
    final stopwatch = Stopwatch()..start();
    final results = <String, dynamic>{};
    
    try {
      // Enhanced user agent
      final headers = {
        'User-Agent': 'AhamAI-StatusChecker/2.0 (Advanced Analysis Bot)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
      };
      
      // Step 1: Try HEAD request first (fastest)
      http.Response? response;
      String method = 'HEAD';
      
      try {
        response = await http.head(
          Uri.parse(url),
          headers: headers,
        ).timeout(const Duration(seconds: 8));
        stopwatch.stop();
        results['method'] = 'HEAD';
        results['responseTime'] = stopwatch.elapsedMilliseconds;
      } catch (e) {
        // Step 2: If HEAD fails, try GET request
        try {
          stopwatch.reset();
          stopwatch.start();
          method = 'GET';
          
          response = await http.get(
            Uri.parse(url),
            headers: headers,
          ).timeout(const Duration(seconds: 12));
          
          stopwatch.stop();
          results['method'] = 'GET';
          results['responseTime'] = stopwatch.elapsedMilliseconds;
        } catch (e2) {
          stopwatch.stop();
          return _formatAdvancedErrorResponse(url, e2, stopwatch.elapsedMilliseconds);
        }
      }
      
      if (response != null) {
        // Advanced analysis
        results['statusCode'] = response.statusCode;
        results['headers'] = response.headers;
        results['bodySize'] = response.body.length;
        results['url'] = url;
        
        // Performance analysis
        results.addAll(await _performAdvancedAnalysis(url, response));
        
        return _formatAdvancedStatusResponse(results);
      }
      
      return _formatErrorResponse(url, 'No response received', stopwatch.elapsedMilliseconds);
      
    } catch (e) {
      stopwatch.stop();
      return _formatAdvancedErrorResponse(url, e, stopwatch.elapsedMilliseconds);
    }
  }
  
  /// Perform advanced website analysis
  static Future<Map<String, dynamic>> _performAdvancedAnalysis(String url, http.Response response) async {
    final analysis = <String, dynamic>{};
    
    // SSL/TLS Analysis
    final uri = Uri.parse(url);
    if (uri.scheme == 'https') {
      analysis['ssl'] = 'Enabled (HTTPS)';
      analysis['sslScore'] = 100;
    } else {
      analysis['ssl'] = 'Not Enabled (HTTP)';
      analysis['sslScore'] = 0;
    }
    
    // Security Headers Analysis
    analysis['security'] = _analyzeSecurityHeaders(response.headers);
    
    // Performance Analysis
    analysis['performance'] = _analyzePerformance(response);
    
    // Content Analysis
    analysis['content'] = _analyzeContent(response);
    
    // CDN Detection
    analysis['cdn'] = _detectCDN(response.headers);
    
    // Server Analysis
    analysis['server'] = _analyzeServer(response.headers);
    
    return analysis;
  }
  
  /// Analyze security headers
  static Map<String, dynamic> _analyzeSecurityHeaders(Map<String, String> headers) {
    final security = <String, dynamic>{};
    final securityHeaders = {
      'strict-transport-security': 'HSTS',
      'x-frame-options': 'Clickjacking Protection',
      'x-content-type-options': 'MIME Sniffing Protection',
      'x-xss-protection': 'XSS Protection',
      'content-security-policy': 'Content Security Policy',
      'referrer-policy': 'Referrer Policy',
      'permissions-policy': 'Permissions Policy',
    };
    
    final found = <String>[];
    final missing = <String>[];
    
    for (final entry in securityHeaders.entries) {
      if (headers.containsKey(entry.key)) {
        found.add(entry.value);
      } else {
        missing.add(entry.value);
      }
    }
    
    security['found'] = found;
    security['missing'] = missing;
    security['score'] = ((found.length / securityHeaders.length) * 100).round();
    
    return security;
  }
  
  /// Analyze performance metrics
  static Map<String, dynamic> _analyzePerformance(http.Response response) {
    final performance = <String, dynamic>{};
    
    // Compression
    final encoding = response.headers['content-encoding'];
    performance['compression'] = encoding ?? 'None';
    
    // Caching
    final cacheControl = response.headers['cache-control'];
    final expires = response.headers['expires'];
    final etag = response.headers['etag'];
    
    performance['caching'] = {
      'cache-control': cacheControl ?? 'Not set',
      'expires': expires ?? 'Not set',
      'etag': etag != null ? 'Present' : 'Not set',
    };
    
    // Content size
    performance['contentSize'] = response.body.length;
    performance['sizeCategory'] = _categorizeSizeValue(response.body.length);
    
    return performance;
  }
  
  /// Analyze content type and structure
  static Map<String, dynamic> _analyzeContent(http.Response response) {
    final content = <String, dynamic>{};
    
    final contentType = response.headers['content-type'] ?? 'Unknown';
    content['type'] = contentType;
    
    if (contentType.contains('html')) {
      content['category'] = 'Web Page';
      content['charset'] = _extractCharset(contentType);
    } else if (contentType.contains('json')) {
      content['category'] = 'API Response';
    } else if (contentType.contains('xml')) {
      content['category'] = 'XML Document';
    } else if (contentType.contains('image')) {
      content['category'] = 'Image';
    } else {
      content['category'] = 'Other';
    }
    
    return content;
  }
  
  /// Detect CDN usage
  static String _detectCDN(Map<String, String> headers) {
    final cdnIndicators = {
      'cloudflare': ['cf-ray', 'cf-cache-status', 'server'],
      'cloudfront': ['x-amz-cf-id', 'x-cache'],
      'fastly': ['fastly-debug-digest', 'x-served-by'],
      'maxcdn': ['x-cache'],
      'keycdn': ['x-edge-location'],
      'bunnycdn': ['bunnycdn-cache-status'],
    };
    
    for (final entry in cdnIndicators.entries) {
      for (final indicator in entry.value) {
        final headerValue = headers[indicator]?.toLowerCase() ?? '';
        if (headerValue.contains(entry.key) || 
            (entry.key == 'cloudflare' && headers.containsKey('cf-ray'))) {
          return entry.key.toUpperCase();
        }
      }
    }
    
    return 'None detected';
  }
  
  /// Analyze server information
  static Map<String, dynamic> _analyzeServer(Map<String, String> headers) {
    final server = <String, dynamic>{};
    
    final serverHeader = headers['server'] ?? 'Unknown';
    server['software'] = serverHeader;
    
    if (serverHeader.toLowerCase().contains('nginx')) {
      server['type'] = 'Nginx';
    } else if (serverHeader.toLowerCase().contains('apache')) {
      server['type'] = 'Apache';
    } else if (serverHeader.toLowerCase().contains('cloudflare')) {
      server['type'] = 'Cloudflare';
    } else if (serverHeader.toLowerCase().contains('microsoft')) {
      server['type'] = 'IIS';
    } else {
      server['type'] = 'Other/Unknown';
    }
    
    return server;
  }
  
  /// Extract charset from content-type
  static String _extractCharset(String contentType) {
    final charsetMatch = RegExp(r'charset=([^;]+)').firstMatch(contentType);
    return charsetMatch?.group(1) ?? 'Not specified';
  }
  
  /// Categorize content size
  static String _categorizeSizeValue(int size) {
    if (size < 1024) return 'Very Small (${size} bytes)';
    if (size < 10240) return 'Small (${(size / 1024).toStringAsFixed(1)} KB)';
    if (size < 102400) return 'Medium (${(size / 1024).toStringAsFixed(1)} KB)';
    if (size < 1048576) return 'Large (${(size / 1024).toStringAsFixed(1)} KB)';
    return 'Very Large (${(size / 1048576).toStringAsFixed(1)} MB)';
  }
  
  /// Format advanced status response
  static String _formatAdvancedStatusResponse(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    
    final statusCode = results['statusCode'] as int;
    final responseTime = results['responseTime'] as int;
    final method = results['method'] as String;
    final url = results['url'] as String;
    
    // Determine status
    final isUp = statusCode >= 200 && statusCode < 400;
    final statusIcon = isUp ? '✅' : '❌';
    final statusText = isUp ? 'UP' : 'DOWN';
    
    // Main status
    buffer.writeln('🌐 **Advanced Site Analysis**');
    buffer.writeln('🔗 **URL**: $url');
    buffer.writeln('$statusIcon **Status**: $statusText');
    buffer.writeln('📊 **HTTP Code**: $statusCode ${_getStatusCodeMeaning(statusCode)}');
    buffer.writeln('⏱️ **Response Time**: ${_categorizeResponseTime(responseTime)}');
    buffer.writeln('🔧 **Method**: $method');
    buffer.writeln();
    
    // SSL/TLS Analysis
    if (results.containsKey('ssl')) {
      final sslScore = results['sslScore'] as int;
      final sslIcon = sslScore == 100 ? '🔒' : '⚠️';
      buffer.writeln('$sslIcon **SSL/TLS**: ${results['ssl']} (Score: $sslScore/100)');
    }
    
    // Security Analysis
    if (results.containsKey('security')) {
      final security = results['security'] as Map<String, dynamic>;
      final score = security['score'] as int;
      final found = security['found'] as List;
      final securityIcon = score >= 70 ? '🛡️' : score >= 40 ? '⚠️' : '🚨';
      
      buffer.writeln('$securityIcon **Security Score**: $score/100');
      if (found.isNotEmpty) {
        buffer.writeln('  ✅ **Found**: ${found.join(', ')}');
      }
      final missing = security['missing'] as List;
      if (missing.isNotEmpty && missing.length <= 3) {
        buffer.writeln('  ❌ **Missing**: ${missing.join(', ')}');
      }
    }
    
    // Performance Analysis
    if (results.containsKey('performance')) {
      final performance = results['performance'] as Map<String, dynamic>;
      final compression = performance['compression'] as String;
      final sizeCategory = performance['sizeCategory'] as String;
      
      buffer.writeln('⚡ **Performance**:');
      buffer.writeln('  📦 **Compression**: $compression');
      buffer.writeln('  📏 **Content Size**: $sizeCategory');
      
      final caching = performance['caching'] as Map<String, dynamic>;
      final cacheControl = caching['cache-control'] as String;
      if (cacheControl != 'Not set') {
        buffer.writeln('  💾 **Caching**: Configured');
      }
    }
    
    // Content Analysis
    if (results.containsKey('content')) {
      final content = results['content'] as Map<String, dynamic>;
      buffer.writeln('📄 **Content**: ${content['category']} (${content['type']})');
    }
    
    // CDN Detection
    if (results.containsKey('cdn')) {
      final cdn = results['cdn'] as String;
      final cdnIcon = cdn != 'None detected' ? '🌐' : 'ℹ️';
      buffer.writeln('$cdnIcon **CDN**: $cdn');
    }
    
    // Server Analysis
    if (results.containsKey('server')) {
      final server = results['server'] as Map<String, dynamic>;
      buffer.writeln('🖥️ **Server**: ${server['type']}');
    }
    
    buffer.writeln();
    
    // Overall assessment
    if (isUp) {
      buffer.writeln('✅ **Overall**: Website is fully operational and accessible');
      
      // Performance recommendations
      if (results.containsKey('performance')) {
        final performance = results['performance'] as Map<String, dynamic>;
        final recommendations = <String>[];
        
        if (performance['compression'] == 'None') {
          recommendations.add('Enable compression (gzip/brotli)');
        }
        
        final caching = performance['caching'] as Map<String, dynamic>;
        if (caching['cache-control'] == 'Not set') {
          recommendations.add('Configure caching headers');
        }
        
        if (results.containsKey('security')) {
          final security = results['security'] as Map<String, dynamic>;
          final score = security['score'] as int;
          if (score < 70) {
            recommendations.add('Improve security headers');
          }
        }
        
        if (recommendations.isNotEmpty) {
          buffer.writeln('💡 **Optimization Tips**: ${recommendations.join(', ')}');
        }
      }
    } else {
      buffer.writeln('❌ **Issue Detected**: ${_getStatusCodeSuggestion(statusCode)}');
    }
    
    return buffer.toString();
  }
  
  /// Format advanced error response
  static String _formatAdvancedErrorResponse(String url, dynamic error, int elapsedTime) {
    final buffer = StringBuffer();
    
    // Determine detailed error type
    String errorType = 'Unknown error';
    String errorCategory = '🚫';
    final suggestions = <String>[];
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('timeoutexception')) {
      errorType = 'Connection timeout';
      errorCategory = '⏰';
      suggestions.addAll([
        'Server may be overloaded or very slow',
        'Check your internet connection',
        'Try again in a few minutes',
      ]);
    } else if (errorString.contains('socketexception')) {
      if (errorString.contains('failed host lookup')) {
        errorType = 'DNS resolution failed';
        errorCategory = '🔍';
        suggestions.addAll([
          'Domain name might not exist',
          'Check for typos in the URL',
          'DNS server issues',
        ]);
      } else {
        errorType = 'Connection refused';
        errorCategory = '🚪';
        suggestions.addAll([
          'Server is not accepting connections',
          'Firewall blocking the request',
          'Server may be down',
        ]);
      }
    } else if (errorString.contains('handshakeexception')) {
      errorType = 'SSL/TLS handshake failed';
      errorCategory = '🔐';
      suggestions.addAll([
        'SSL certificate issues',
        'Outdated security protocols',
        'Try HTTP instead of HTTPS',
      ]);
    } else if (errorString.contains('httpexception')) {
      errorType = 'HTTP protocol error';
      errorCategory = '📡';
      suggestions.addAll([
        'Invalid HTTP response from server',
        'Server configuration issues',
        'Protocol version mismatch',
      ]);
    }
    
    buffer.writeln('🌐 **Advanced Site Analysis**');
    buffer.writeln('🔗 **URL**: $url');
    buffer.writeln('❌ **Status**: DOWN');
    buffer.writeln('$errorCategory **Error**: $errorType');
    buffer.writeln('⏱️ **Time Elapsed**: ${elapsedTime}ms');
    buffer.writeln();
    
    // Detailed analysis
    final uri = Uri.tryParse(url);
    if (uri != null) {
      buffer.writeln('🔍 **Technical Details**:');
      buffer.writeln('• **Protocol**: ${uri.scheme.toUpperCase()}');
      buffer.writeln('• **Domain**: ${uri.host}');
      if (uri.hasPort) {
        buffer.writeln('• **Port**: ${uri.port}');
      }
      buffer.writeln();
    }
    
    // Quick diagnostics
    buffer.writeln('🔧 **Quick Diagnostics**:');
    suggestions.forEach((suggestion) {
      buffer.writeln('• $suggestion');
    });
    
    // Additional troubleshooting
    buffer.writeln();
    buffer.writeln('💡 **Troubleshooting Steps**:');
    buffer.writeln('1. Verify the URL is correct');
    buffer.writeln('2. Check your internet connection');
    buffer.writeln('3. Try accessing from a different network');
    buffer.writeln('4. Contact the website administrator if issues persist');
    
    return buffer.toString();
  }
  
  /// Categorize response time
  static String _categorizeResponseTime(int ms) {
    if (ms < 100) return '${ms}ms (Excellent)';
    if (ms < 300) return '${ms}ms (Good)';
    if (ms < 1000) return '${ms}ms (Fair)';
    if (ms < 3000) return '${ms}ms (Slow)';
    return '${ms}ms (Very Slow)';
  }
  
  /// Format successful status response (legacy - kept for compatibility)
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