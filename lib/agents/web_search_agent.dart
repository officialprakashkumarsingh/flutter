import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Data Models
class WebSearchResult {
  final String title;
  final String url;
  final String description;
  final String source;

  WebSearchResult({
    required this.title,
    required this.url,
    required this.description,
    required this.source,
  });

  factory WebSearchResult.fromJson(Map<String, dynamic> json) {
    return WebSearchResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      description: json['description'] ?? '',
      source: json['meta_url']?['netloc'] ?? '',
    );
  }
}





// Web Search Agent
class WebSearchAgent {
  static const String _apiKey = 'BSAGvn27KGywhzSPWjem5a_r41ZYaB2';
  static const String _baseUrl = 'https://api.search.brave.com/res/v1';

    /// Perform web search (web results only)
  static Future<String?> performWebSearch(String query) async {
    try {
      print('🌐 WEB SEARCH: Starting search for: $query');
      
      // Only search web results
      final webResults = await _searchWeb(query);

      if (webResults.isEmpty) {
        return null;
      }

      print('🌐 SEARCH RESULTS: Web: ${webResults.length}');
      print('🌐 WEB SEARCH: Web results sample: ${webResults.take(2).map((e) => e.title).toList()}');

      // Create simplified JSON data for iOS-style favicon display
      final jsonData = {
        'type': 'web_search_results',
        'query': query,
        'total_results': webResults.length,
        'web_results': webResults.map((r) => {
          'title': r.title,
          'url': r.url,
          'description': r.description,
          'source': r.source,
          'favicon': 'https://www.google.com/s2/favicons?domain=${Uri.parse(r.url).host}&sz=32',
        }).toList(),
      };

      // No AI formatting - just pass the JSON data to UI
      return '\n\n**WEB_SEARCH_DATA_START**\n${jsonEncode(jsonData)}\n**WEB_SEARCH_DATA_END**\n\n';
    } catch (e) {
      print('❌ WEB SEARCH: Error in web search: $e');
      return null;
    }
  }

  /// Search web results
  static Future<List<WebSearchResult>> _searchWeb(String query) async {
    try {
      final url = '$_baseUrl/web/search?q=${Uri.encodeComponent(query)}&safesearch=strict&count=15&search_lang=en&country=us&spellcheck=1';
      print('🌐 WEB API: Calling $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Subscription-Token': _apiKey,
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip',
        },
      );

      print('🌐 WEB API: Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final webResults = data['web']?['results'] as List? ?? [];
        print('🌐 WEB API: Found ${webResults.length} web results');
        
        return webResults.map((result) => WebSearchResult.fromJson(result)).toList();
      } else {
        print('❌ WEB SEARCH: Web search failed with status: ${response.statusCode}, body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ WEB SEARCH: Error in web search: $e');
      return [];
    }
  }






}

// iOS-Style Simple Favicon List Widget
class WebSearchResultsWidget extends StatelessWidget {
  final Map<String, dynamic> results;

  const WebSearchResultsWidget({
    super.key,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final webResults = results['web_results'] as List<dynamic>? ?? [];
    final query = results['query'] as String? ?? '';

    if (webResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Sources',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF71717A),
              ),
            ),
          ),
          // Horizontal scrollable favicon list
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: webResults.length > 10 ? 10 : webResults.length, // Limit to 10
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final result = webResults[index];
                final url = result['url'] as String? ?? '';
                final title = result['title'] as String? ?? '';
                final favicon = result['favicon'] as String? ?? '';

                return GestureDetector(
                  onTap: () => _launchUrl(url),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        favicon,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFF4F4F5),
                            child: const Icon(
                              Icons.language,
                              color: Color(0xFF71717A),
                              size: 20,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }
}