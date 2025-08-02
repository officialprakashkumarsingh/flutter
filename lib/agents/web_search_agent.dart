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

class WebImageResult {
  final String title;
  final String url;
  final String imageUrl;
  final String? description;
  final int? width;
  final int? height;
  final String source;

  WebImageResult({
    required this.title,
    required this.url,
    required this.imageUrl,
    this.description,
    this.width,
    this.height,
    required this.source,
  });

  factory WebImageResult.fromJson(Map<String, dynamic> json) {
    return WebImageResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['thumbnail']?['src'] ?? json['src'] ?? '',
      description: json['description'],
      width: json['properties']?['width'] ?? json['width'],
      height: json['properties']?['height'] ?? json['height'],
      source: json['meta_url']?['netloc'] ?? json['source'] ?? '',
    );
  }
}

class WebVideoResult {
  final String title;
  final String url;
  final String thumbnailUrl;
  final String? description;
  final String? duration;
  final String? creator;
  final String? publishDate;
  final String source;

  WebVideoResult({
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    this.description,
    this.duration,
    this.creator,
    this.publishDate,
    required this.source,
  });

  factory WebVideoResult.fromJson(Map<String, dynamic> json) {
    return WebVideoResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnail']?['src'] ?? '',
      description: json['description'],
      duration: json['video']?['duration'],
      creator: json['video']?['creator'],
      publishDate: json['age'],
      source: json['meta_url']?['netloc'] ?? '',
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

// Web Search Agent
class WebSearchAgent {
  static const String _apiKey = 'BSAGvn27KGywhzSPWjem5a_r41ZYaB2';
  static const String _baseUrl = 'https://api.search.brave.com/res/v1';

  /// Perform comprehensive web search
  static Future<String?> performWebSearch(String query) async {
    try {
      print('🌐 WEB SEARCH: Starting search for: $query');
      
      // Perform all searches in parallel for better performance
      final futures = await Future.wait([
        _searchWeb(query),
        _searchImages(query),
        _searchVideos(query),
      ]);

      final webResults = futures[0] as List<WebSearchResult>? ?? [];
      final imageResults = futures[1] as List<WebImageResult>? ?? [];
      final videoResults = futures[2] as List<WebVideoResult>? ?? [];

      // Always return results even if some categories are empty
      print('🌐 SEARCH RESULTS: Web: ${webResults.length}, Images: ${imageResults.length}, Videos: ${videoResults.length}');

      final searchResults = WebSearchResults(
        webResults: webResults,
        imageResults: imageResults,
        videoResults: videoResults,
        query: query,
        totalResults: webResults.length + imageResults.length + videoResults.length,
      );

      // Format results for AI context
      final formattedResults = _formatResultsForAI(searchResults);
      
      // Create JSON data for UI display
      final jsonData = {
        'type': 'web_search_results',
        'query': query,
        'total_results': searchResults.totalResults,
        'web_results': webResults?.map((r) => {
          'title': r.title,
          'url': r.url,
          'description': r.description,
          'source': r.source,
        }).toList() ?? [],
        'image_results': imageResults?.map((r) => {
          'title': r.title,
          'url': r.url,
          'src': r.imageUrl,
          'description': r.description,
          'width': r.width,
          'height': r.height,
          'source': r.source,
        }).toList() ?? [],
        'video_results': videoResults?.map((r) => {
          'title': r.title,
          'url': r.url,
          'thumbnail': {'src': r.thumbnailUrl},
          'description': r.description,
          'video': {
            'duration': r.duration,
            'creator': r.creator,
          },
          'age': r.publishDate,
          'source': r.source,
        }).toList() ?? [],
      };

      return '\n\n**WEB_SEARCH_DATA_START**\n${jsonEncode(jsonData)}\n**WEB_SEARCH_DATA_END**\n\n$formattedResults';
    } catch (e) {
      print('❌ WEB SEARCH: Error in web search: $e');
      return null;
    }
  }

  /// Search web results
  static Future<List<WebSearchResult>?> _searchWeb(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/web/search?q=${Uri.encodeComponent(query)}&safesearch=strict&count=15&search_lang=en&country=us&spellcheck=1'),
        headers: {
          'X-Subscription-Token': _apiKey,
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip',
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
        Uri.parse('$_baseUrl/images/search?q=${Uri.encodeComponent(query)}&safesearch=strict&count=15&search_lang=en&country=us&spellcheck=1'),
        headers: {
          'X-Subscription-Token': _apiKey,
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip',
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
        Uri.parse('$_baseUrl/videos/search?q=${Uri.encodeComponent(query)}&count=15&country=us&search_lang=en&spellcheck=1'),
        headers: {
          'X-Subscription-Token': _apiKey,
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip',
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

  /// Format search results for AI context
  static String _formatResultsForAI(WebSearchResults results) {
    final buffer = StringBuffer();
    
    buffer.writeln('🌐 **CURRENT WEB SEARCH RESULTS FOR: "${results.query}"**');
    buffer.writeln('📊 Total Results: ${results.totalResults}');
    buffer.writeln('⏰ Retrieved: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    if (results.webResults.isNotEmpty) {
      buffer.writeln('📰 **WEB RESULTS:**');
      for (int i = 0; i < results.webResults.length; i++) {
        final result = results.webResults[i];
        buffer.writeln('${i + 1}. **${result.title}**');
        buffer.writeln('   Source: ${result.source}');
        buffer.writeln('   ${result.description}');
        buffer.writeln('   URL: ${result.url}');
        buffer.writeln();
      }
    }

    if (results.imageResults.isNotEmpty) {
      buffer.writeln('🖼️ **IMAGE RESULTS:**');
      for (int i = 0; i < results.imageResults.length; i++) {
        final result = results.imageResults[i];
        buffer.writeln('${i + 1}. **${result.title}**');
        buffer.writeln('   Source: ${result.source}');
        if (result.description?.isNotEmpty == true) {
          buffer.writeln('   Description: ${result.description}');
        }
        buffer.writeln('   Image URL: ${result.imageUrl}');
        buffer.writeln();
      }
    }

    if (results.videoResults.isNotEmpty) {
      buffer.writeln('🎥 **VIDEO RESULTS:**');
      for (int i = 0; i < results.videoResults.length; i++) {
        final result = results.videoResults[i];
        buffer.writeln('${i + 1}. **${result.title}**');
        buffer.writeln('   Source: ${result.source}');
        if (result.creator?.isNotEmpty == true) {
          buffer.writeln('   Creator: ${result.creator}');
        }
        if (result.duration?.isNotEmpty == true) {
          buffer.writeln('   Duration: ${result.duration}');
        }
        if (result.publishDate?.isNotEmpty == true) {
          buffer.writeln('   Published: ${result.publishDate}');
        }
        buffer.writeln('   ${result.description}');
        buffer.writeln('   URL: ${result.url}');
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Extract text content for AI processing
  static String extractTextContent(WebSearchResults results) {
    return _formatResultsForAI(results);
  }
}

// Google-Style Search Results Widget
class WebSearchResultsWidget extends StatefulWidget {
  final WebSearchResults results;

  const WebSearchResultsWidget({
    Key? key,
    required this.results,
  }) : super(key: key);

  @override
  State<WebSearchResultsWidget> createState() => _WebSearchResultsWidgetState();
}

class _WebSearchResultsWidgetState extends State<WebSearchResultsWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Always use 3 tabs (Web, Images, Videos)
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always show all 3 tabs regardless of results
    final availableTabs = <Widget>[
      // Web tab
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 16),
            const SizedBox(width: 4),
            Text('Web (${widget.results.webResults.length})'),
          ],
        ),
      ),
      // Images tab
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image, size: 16),
            const SizedBox(width: 4),
            Text('Images (${widget.results.imageResults.length})'),
          ],
        ),
      ),
      // Videos tab
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle, size: 16),
            const SizedBox(width: 4),
            Text('Videos (${widget.results.videoResults.length})'),
          ],
        ),
      ),
    ];

    // Always show all 3 tab views
    final tabViews = <Widget>[
      _buildWebResults(),
      _buildImageResults(),
      _buildVideoResults(),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - removed borders
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF09090B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search results for "${widget.results.query}"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF09090B),
                    ),
                  ),
                ),
                Text(
                  '${widget.results.totalResults} results',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Bar - removed all borders
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: availableTabs,
              labelColor: const Color(0xFF0F172A),
              unselectedLabelColor: const Color(0xFF71717A),
              indicatorColor: const Color(0xFF0F172A),
              indicatorWeight: 2,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              dividerColor: Colors.transparent, // Remove divider line
            ),
          ),
          
          // Tab Views
          Container(
            height: 400,
            color: Colors.white,
            child: TabBarView(
              controller: _tabController,
              children: tabViews,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebResults() {
    if (widget.results.webResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No web results found',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF71717A),
            ),
          ),
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.results.webResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final result = widget.results.webResults[index];
        return InkWell(
          onTap: () => _launchUrl(result.url),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.source,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF71717A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  result.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF71717A),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageResults() {
    if (widget.results.imageResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No image results found',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF71717A),
            ),
          ),
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: widget.results.imageResults.length,
      itemBuilder: (context, index) {
        final result = widget.results.imageResults[index];
        return InkWell(
          onTap: () => _launchUrl(result.url),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: [
                  Expanded(
                    child: Image.network(
                      result.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFF4F4F5),
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Color(0xFF71717A),
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (result.title.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        result.title,
                        style: const TextStyle(
                          fontSize: 12,
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
    );
  }

  Widget _buildVideoResults() {
    if (widget.results.videoResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No video results found',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF71717A),
            ),
          ),
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.results.videoResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final result = widget.results.videoResults[index];
        return InkWell(
          onTap: () => _launchUrl(result.url),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Container(
                  width: 120,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFFF4F4F5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Image.network(
                          result.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.play_circle,
                                color: Color(0xFF71717A),
                                size: 32,
                              ),
                            );
                          },
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        if (result.duration?.isNotEmpty == true)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                result.duration!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (result.creator?.isNotEmpty == true)
                        Text(
                          result.creator!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      if (result.publishDate?.isNotEmpty == true)
                        Text(
                          result.publishDate!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      if (result.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          result.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF71717A),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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