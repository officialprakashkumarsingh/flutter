import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class WebSearchResult {
  final String title;
  final String url;
  final String description;
  final String? snippet;
  final DateTime? publishedDate;

  WebSearchResult({
    required this.title,
    required this.url,
    required this.description,
    this.snippet,
    this.publishedDate,
  });

  factory WebSearchResult.fromJson(Map<String, dynamic> json) {
    return WebSearchResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      description: json['description'] ?? '',
      snippet: json['snippet'],
      publishedDate: json['published_date'] != null 
          ? DateTime.tryParse(json['published_date'])
          : null,
    );
  }
}

class WebImageResult {
  final String title;
  final String url;
  final String imageUrl;
  final String? description;
  final int? width;
  final int? height;

  WebImageResult({
    required this.title,
    required this.url,
    required this.imageUrl,
    this.description,
    this.width,
    this.height,
  });

  factory WebImageResult.fromJson(Map<String, dynamic> json) {
    return WebImageResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['src'] ?? '',
      description: json['description'],
      width: json['width'],
      height: json['height'],
    );
  }
}

class WebVideoResult {
  final String title;
  final String url;
  final String? thumbnailUrl;
  final String? description;
  final String? duration;
  final DateTime? publishedDate;

  WebVideoResult({
    required this.title,
    required this.url,
    this.thumbnailUrl,
    this.description,
    this.duration,
    this.publishedDate,
  });

  factory WebVideoResult.fromJson(Map<String, dynamic> json) {
    return WebVideoResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnail']?['src'],
      description: json['description'],
      duration: json['duration'],
      publishedDate: json['published_date'] != null 
          ? DateTime.tryParse(json['published_date'])
          : null,
    );
  }
}

class WebSearchResults {
  final List<WebSearchResult> webResults;
  final List<WebImageResult> imageResults;
  final List<WebVideoResult> videoResults;
  final String query;
  final int totalResults;

  WebSearchResults({
    required this.webResults,
    required this.imageResults,
    required this.videoResults,
    required this.query,
    required this.totalResults,
  });
}

class WebSearchAgent {
  static const String _agentName = 'Web Search';
  static const String _apiKey = 'BSAGvn27KGywhzSPWjem5a_r41ZYaB2';
  static const String _baseUrl = 'https://api.search.brave.com/res/v1';

  /// Perform a comprehensive web search including web, images, and videos
  static Future<String?> performWebSearch(String query) async {
    try {
      print('🌐 WEB SEARCH: Searching for: $query');
      
      final results = await _searchAll(query);
      if (results == null) return null;

      // Create a formatted response with search results
      final searchData = {
        'type': 'web_search_results',
        'query': query,
        'timestamp': DateTime.now().toIso8601String(),
        'web_results': results.webResults.map((r) => {
          'title': r.title,
          'url': r.url,
          'description': r.description,
          'snippet': r.snippet,
          'published_date': r.publishedDate?.toIso8601String(),
        }).toList(),
        'image_results': results.imageResults.map((r) => {
          'title': r.title,
          'url': r.url,
          'image_url': r.imageUrl,
          'description': r.description,
          'width': r.width,
          'height': r.height,
        }).toList(),
        'video_results': results.videoResults.map((r) => {
          'title': r.title,
          'url': r.url,
          'thumbnail_url': r.thumbnailUrl,
          'description': r.description,
          'duration': r.duration,
          'published_date': r.publishedDate?.toIso8601String(),
        }).toList(),
        'total_results': results.totalResults,
      };

      return '**WEB_SEARCH_DATA_START**\n${jsonEncode(searchData)}\n**WEB_SEARCH_DATA_END**';
    } catch (e) {
      print('❌ WEB SEARCH: Error performing search: $e');
      return null;
    }
  }

  /// Search all content types (web, images, videos)
  static Future<WebSearchResults?> _searchAll(String query) async {
    try {
      final futures = await Future.wait([
        _searchWeb(query),
        _searchImages(query),
        _searchVideos(query),
      ]);

      final webResults = futures[0] as List<WebSearchResult>? ?? [];
      final imageResults = futures[1] as List<WebImageResult>? ?? [];
      final videoResults = futures[2] as List<WebVideoResult>? ?? [];

      return WebSearchResults(
        webResults: webResults,
        imageResults: imageResults,
        videoResults: videoResults,
        query: query,
        totalResults: webResults.length + imageResults.length + videoResults.length,
      );
    } catch (e) {
      print('❌ WEB SEARCH: Error in search all: $e');
      return null;
    }
  }

  /// Search web results
  static Future<List<WebSearchResult>?> _searchWeb(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/web/search?q=${Uri.encodeComponent(query)}&count=8'),
        headers: {
          'X-Subscription-Token': _apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final webResults = data['web']?['results'] as List? ?? [];
        
        return webResults.map((result) => WebSearchResult.fromJson(result)).toList();
      } else {
        print('❌ WEB SEARCH: Web search failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ WEB SEARCH: Error in web search: $e');
      return null;
    }
  }

  /// Search image results
  static Future<List<WebImageResult>?> _searchImages(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/images/search?q=${Uri.encodeComponent(query)}&count=6'),
        headers: {
          'X-Subscription-Token': _apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageResults = data['results'] as List? ?? [];
        
        return imageResults.map((result) => WebImageResult.fromJson(result)).toList();
      } else {
        print('❌ WEB SEARCH: Image search failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ WEB SEARCH: Error in image search: $e');
      return null;
    }
  }

  /// Search video results
  static Future<List<WebVideoResult>?> _searchVideos(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/search?q=${Uri.encodeComponent(query)}&count=4'),
        headers: {
          'X-Subscription-Token': _apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videoResults = data['results'] as List? ?? [];
        
        return videoResults.map((result) => WebVideoResult.fromJson(result)).toList();
      } else {
        print('❌ WEB SEARCH: Video search failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ WEB SEARCH: Error in video search: $e');
      return null;
    }
  }

  /// Extract text content from search results for AI processing
  static String extractTextContent(WebSearchResults results) {
    final buffer = StringBuffer();
    
    buffer.writeln('CURRENT WEB SEARCH RESULTS FOR: "${results.query}"');
    buffer.writeln('Retrieved on: ${DateTime.now().toString()}');
    buffer.writeln('Total results: ${results.totalResults}');
    buffer.writeln();

    if (results.webResults.isNotEmpty) {
      buffer.writeln('📄 WEB RESULTS:');
      for (int i = 0; i < results.webResults.length; i++) {
        final result = results.webResults[i];
        buffer.writeln('${i + 1}. ${result.title}');
        buffer.writeln('   URL: ${result.url}');
        buffer.writeln('   Description: ${result.description}');
        if (result.snippet != null) {
          buffer.writeln('   Snippet: ${result.snippet}');
        }
        if (result.publishedDate != null) {
          buffer.writeln('   Published: ${result.publishedDate}');
        }
        buffer.writeln();
      }
    }

    if (results.imageResults.isNotEmpty) {
      buffer.writeln('🖼️ IMAGE RESULTS:');
      for (int i = 0; i < results.imageResults.length; i++) {
        final result = results.imageResults[i];
        buffer.writeln('${i + 1}. ${result.title}');
        buffer.writeln('   Source: ${result.url}');
        buffer.writeln('   Image URL: ${result.imageUrl}');
        if (result.description != null) {
          buffer.writeln('   Description: ${result.description}');
        }
        buffer.writeln();
      }
    }

    if (results.videoResults.isNotEmpty) {
      buffer.writeln('🎥 VIDEO RESULTS:');
      for (int i = 0; i < results.videoResults.length; i++) {
        final result = results.videoResults[i];
        buffer.writeln('${i + 1}. ${result.title}');
        buffer.writeln('   URL: ${result.url}');
        if (result.description != null) {
          buffer.writeln('   Description: ${result.description}');
        }
        if (result.duration != null) {
          buffer.writeln('   Duration: ${result.duration}');
        }
        if (result.publishedDate != null) {
          buffer.writeln('   Published: ${result.publishedDate}');
        }
        buffer.writeln();
      }
    }

    buffer.writeln('---');
    buffer.writeln('INSTRUCTIONS: Use ONLY the above current web search results to answer the user\'s question. Do not use any outdated information from your training data. Base your response entirely on these fresh web search results.');

    return buffer.toString();
  }
}

/// Widget to display web search results in shadcn UI style
class WebSearchResultsWidget extends StatelessWidget {
  final WebSearchResults results;

  const WebSearchResultsWidget({
    super.key,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF09090B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Web Search: "${results.query}"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF09090B),
                    ),
                  ),
                ),
                Text(
                  '${results.totalResults} results',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Web Results
                if (results.webResults.isNotEmpty) ...[
                  _buildSectionHeader('📄 Web Results'),
                  const SizedBox(height: 8),
                  ...results.webResults.take(3).map((result) => _buildWebResultCard(result)),
                  const SizedBox(height: 16),
                ],

                // Image Results
                if (results.imageResults.isNotEmpty) ...[
                  _buildSectionHeader('🖼️ Images'),
                  const SizedBox(height: 8),
                  _buildImageGrid(results.imageResults),
                  const SizedBox(height: 16),
                ],

                // Video Results
                if (results.videoResults.isNotEmpty) ...[
                  _buildSectionHeader('🎥 Videos'),
                  const SizedBox(height: 8),
                  ...results.videoResults.take(2).map((result) => _buildVideoResultCard(result)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF09090B),
      ),
    );
  }

  Widget _buildWebResultCard(WebSearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _launchUrl(result.url),
            child: Text(
              result.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2563EB),
                decoration: TextDecoration.underline,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF71717A),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            result.url,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF22C55E),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<WebImageResult> images) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          final image = images[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _launchUrl(image.url),
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                        child: Image.network(
                          image.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFF8F9FA),
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Color(0xFF71717A),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        image.title,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF09090B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoResultCard(WebVideoResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: result.thumbnailUrl != null
                  ? Image.network(
                      result.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFF8F9FA),
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: Color(0xFF71717A),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: const Color(0xFFF8F9FA),
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Color(0xFF71717A),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _launchUrl(result.url),
                  child: Text(
                    result.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2563EB),
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (result.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF71717A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (result.duration != null) ...[
                      Text(
                        result.duration!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (result.publishedDate != null)
                      Text(
                        _formatDate(result.publishedDate!),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF71717A),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}