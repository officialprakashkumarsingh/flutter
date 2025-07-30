import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// A lightweight service responsible for collecting repository context and
/// basic project-type detection. The heavy UI logic stays in `coder_page.dart`,
/// while this class can be unit-tested independently.
class CoderLogicService {
  CoderLogicService({
    required String githubToken,
    required String repoFullName,
    required String branch,
    http.Client? httpClient,
  })  : _token = githubToken,
        _repo = repoFullName,
        _branch = branch,
        _client = httpClient ?? http.Client();

  final String _token;
  final String _repo; // e.g. owner/repo
  final String _branch;
  final http.Client _client;

  /// Collects a bird’s-eye view of the repository such as number of files,
  /// file names, unique extensions, detected project type and main
  /// technologies. The returned map structure purposefully matches the one
  /// that `CoderPage` was previously producing so that the UI requires only
  /// minimal changes.
  Future<Map<String, dynamic>> getRepositoryContext(String userTask) async {
    try {
      // STEP 1: find the latest commit SHA for the branch so that we can fetch
      // a recursive tree in a single API call.
      final branchRes = await _client.get(
        Uri.parse('https://api.github.com/repos/$_repo/branches/$_branch'),
        headers: _headers,
      );
      if (branchRes.statusCode != 200) throw 'Unable to fetch branch info';
      final branchJson = json.decode(branchRes.body);
      final String commitSha = branchJson['commit']['sha'];

      // STEP 2: fetch the complete tree recursively. For large repositories
      // the GitHub API caps the response to ~100k entries which is more than
      // enough for our purposes.
      final treeRes = await _client.get(
        Uri.parse(
            'https://api.github.com/repos/$_repo/git/trees/$commitSha?recursive=1'),
        headers: _headers,
      );
      if (treeRes.statusCode != 200) throw 'Unable to fetch repository tree';
      final treeJson = json.decode(treeRes.body);
      final List<dynamic> tree = treeJson['tree'] as List<dynamic>;

      // Filter blobs only (skip sub-trees)
      final List<String> filePaths = tree
          .where((t) => t['type'] == 'blob')
          .map<String>((t) => t['path'] as String)
          .toList();

      final fileCount = filePaths.length;
      final Set<String> extensions = {};
      final List<String> fileNamesLower = [];
      for (final fp in filePaths) {
        final ext = p.extension(fp).toLowerCase();
        if (ext.isNotEmpty) extensions.add(ext);
        fileNamesLower.add(fp.toLowerCase());
      }

      final projectType = _detectProjectTypeWithUserContext(
          fileNamesLower, userTask.toLowerCase());
      final technologies = _getProjectTechnologies(
          fileNamesLower, extensions.toList(growable: false));

      return {
        'fileCount': fileCount,
        'languages': extensions.toList(growable: false),
        // We don’t want to blow the prompt size. Return at most 40 paths.
        'files': filePaths.take(40).toList(growable: false),
        'projectType': projectType,
        'technologies': technologies,
        'fileNames': fileNamesLower,
      };
    } catch (e) {
      // Fallback – if anything goes wrong we still return a minimal context so
      // that the caller can decide what to do.
      return {
        'fileCount': 0,
        'languages': [],
        'files': [],
        'projectType': 'Unknown',
        'technologies': ['Unknown'],
        'fileNames': [],
        'error': e.toString(),
      };
    }
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github.v3+json',
      };

  /// Basic project-type detection copied (and slightly trimmed) from the old
  /// implementation so that results stay consistent while we refactor.
  String _detectProjectType(List<String> fileNames) {
    bool anyEndsWith(String suffix) =>
        fileNames.any((f) => f.endsWith(suffix.toLowerCase()));
    bool anyContains(String piece) =>
        fileNames.any((f) => f.contains(piece.toLowerCase()));

    if (anyContains('package.json')) return 'Node.js/JavaScript';
    if (anyContains('pubspec.yaml')) return 'Flutter/Dart';
    if (anyContains('requirements.txt') ||
        anyContains('setup.py') ||
        anyContains('pyproject.toml')) return 'Python';
    if (anyContains('pom.xml') || anyContains('build.gradle')) return 'Java';
    if (anyContains('cargo.toml')) return 'Rust';
    if (anyContains('go.mod')) return 'Go';
    if (anyContains('composer.json')) return 'PHP';
    if (anyContains('gemfile')) return 'Ruby';
    if (anyEndsWith('.html') || anyEndsWith('.css') || anyEndsWith('.js')) {
      return 'Web Development';
    }
    if (anyEndsWith('.py')) return 'Python';
    if (anyEndsWith('.java')) return 'Java';
    if (anyEndsWith('.cpp') || anyEndsWith('.c') || anyEndsWith('.h')) {
      return 'C/C++';
    }
    if (anyEndsWith('.cs')) return 'C#';
    if (anyEndsWith('.swift')) return 'Swift';
    if (anyEndsWith('.kt')) return 'Kotlin';
    return 'General';
  }

  String _detectProjectTypeWithUserContext(
      List<String> fileNames, String userRequest) {
    final repoType = _detectProjectType(fileNames);
    if (repoType != 'General' && repoType != 'Web Development') return repoType;

    final userType = _analyzeUserRequestForLanguage(userRequest);
    return userType != 'Unknown' ? userType : repoType;
  }

  String _analyzeUserRequestForLanguage(String request) {
    final r = request.toLowerCase();
    if (r.contains('python') ||
        r.contains('django') ||
        r.contains('flask') ||
        r.contains('fastapi')) return 'Python';
    if (r.contains('javascript') ||
        r.contains('node') ||
        r.contains('express') ||
        r.contains('react')) return 'Node.js/JavaScript';
    if (r.contains('flutter') || r.contains('dart')) return 'Flutter/Dart';
    if (r.contains('java') || r.contains('spring')) return 'Java';
    if (r.contains('c++') || r.contains('cpp')) return 'C/C++';
    if (r.contains('golang') || r.contains('go ')) return 'Go';
    if (r.contains('rust')) return 'Rust';
    if (r.contains('php') || r.contains('laravel')) return 'PHP';
    if (r.contains('c#') || r.contains('.net')) return 'C#';
    return 'Unknown';
  }

  List<String> _getProjectTechnologies(
      List<String> fileNames, List<String> extensions) {
    final techs = <String>{};

    void addIf(bool cond, String tech) {
      if (cond) techs.add(tech);
    }

    // Front-end
    addIf(extensions.contains('.html'), 'HTML');
    addIf(extensions.contains('.css'), 'CSS');
    addIf(extensions.contains('.js'), 'JavaScript');
    addIf(extensions.contains('.ts'), 'TypeScript');
    addIf(extensions.contains('.jsx'), 'React');
    addIf(extensions.contains('.tsx'), 'React+TypeScript');
    addIf(extensions.contains('.vue'), 'Vue.js');

    // Back-end / others
    addIf(extensions.contains('.py'), 'Python');
    addIf(extensions.contains('.java'), 'Java');
    addIf(extensions.any((e) => ['.c', '.cpp'].contains(e)), 'C/C++');
    addIf(extensions.contains('.cs'), 'C#');
    addIf(extensions.contains('.php'), 'PHP');
    addIf(extensions.contains('.rb'), 'Ruby');
    addIf(extensions.contains('.go'), 'Go');
    addIf(extensions.contains('.rs'), 'Rust');
    addIf(extensions.contains('.dart'), 'Dart');

    // Heuristics based on filenames
    addIf(fileNames.any((f) => f.contains('react')), 'React');
    addIf(fileNames.any((f) => f.contains('angular')), 'Angular');
    addIf(fileNames.any((f) => f.contains('vue')), 'Vue');
    addIf(fileNames.any((f) => f.contains('next')), 'Next.js');
    addIf(fileNames.any((f) => f.contains('nuxt')), 'Nuxt.js');
    addIf(fileNames.any((f) => f.contains('express')), 'Express.js');
    addIf(fileNames.any((f) => f.contains('flask')), 'Flask');
    addIf(fileNames.any((f) => f.contains('django')), 'Django');

    return techs.isEmpty ? ['Unknown'] : techs.toList(growable: false);
  }

  /// It is **very** important to close the underlying client to avoid socket
  /// exhaustion when the service is no longer needed.
  void dispose() {
    _client.close();
  }
}