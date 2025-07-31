import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lightweight local code indexer that mirrors the current branch so Coder
/// can perform instant, offline-style full-text searches.
class CodeIndexService {
  CodeIndexService({
    required String githubToken,
    required String repoFullName,
    required String branch,
    http.Client? httpClient,
  })  : _token = githubToken,
        _repo = repoFullName,
        _branch = branch,
        _client = httpClient ?? http.Client();

  final String _token;
  final String _repo;
  final String _branch;
  final http.Client _client;

  /// path -> raw content (UTF-8, truncated if oversized)
  final Map<String, String> _fileContents = {};

  bool _isIndexing = false;
  DateTime? _indexedAt;

  bool get isReady => _fileContents.isNotEmpty;
  bool get isIndexing => _isIndexing;

  /// Build or refresh the local index.
  /// Only text blobs under [maxFileSize] bytes are downloaded for speed.
  Future<void> buildIndex({int maxFileSize = 50 * 1024}) async {
    if (_isIndexing) return;
    _isIndexing = true;
    try {
      // Step 1: list files via GitHub Trees API (recursive)
      final branchRes = await _client.get(
        Uri.parse('https://api.github.com/repos/$_repo/branches/$_branch'),
        headers: _headers,
      );
      if (branchRes.statusCode != 200) {
        throw 'Unable to fetch branch info';
      }
      final branchJson = json.decode(branchRes.body);
      final String commitSha = branchJson['commit']['sha'];

      final treeRes = await _client.get(
        Uri.parse(
          'https://api.github.com/repos/$_repo/git/trees/$commitSha?recursive=1'),
        headers: _headers,
      );
      if (treeRes.statusCode != 200) {
        throw 'Unable to fetch repository tree';
      }
      final treeJson = json.decode(treeRes.body);
      final List<dynamic> tree = treeJson['tree'] as List<dynamic>;

      final textBlobs = tree.where((t) => t['type'] == 'blob');
      _fileContents.clear();

      for (final blob in textBlobs) {
        final int size = blob['size'] ?? 0;
        final String path = blob['path'];
        if (size > maxFileSize) continue; // skip huge files

        final rawRes = await _client.get(
          Uri.parse(
            'https://raw.githubusercontent.com/$_repo/$_branch/$path'),
        );
        if (rawRes.statusCode == 200) {
          _fileContents[path] = rawRes.body;
        }
      }
      _indexedAt = DateTime.now();
    } finally {
      _isIndexing = false;
    }
  }

  /// Simple full-text search through indexed files.
  /// Returns up to [maxResults] matches containing snippet and path.
  List<Map<String, dynamic>> search(String query, {int maxResults = 50}) {
    if (!isReady) return [];
    final lower = query.toLowerCase();
    final results = <Map<String, dynamic>>[];

    for (final entry in _fileContents.entries) {
      final path = entry.key;
      final content = entry.value;
      final idx = content.toLowerCase().indexOf(lower);
      if (idx != -1) {
        final start = idx - 40 < 0 ? 0 : idx - 40;
        final end = idx + query.length + 40 > content.length
            ? content.length
            : idx + query.length + 40;
        final snippet = content.substring(start, end).replaceAll('\n', ' ');
        results.add({'path': path, 'snippet': snippet});
        if (results.length >= maxResults) break;
      }
    }
    return results;
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github.v3+json',
      };

  void dispose() {
    _client.close();
  }
}