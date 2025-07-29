import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class CoderPage extends StatefulWidget {
  const CoderPage({super.key});

  @override
  State<CoderPage> createState() => _CoderPageState();
}

class _CoderPageState extends State<CoderPage> with TickerProviderStateMixin {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  // GitHub Integration
  String? _githubToken;
  List<Repository> _repositories = [];
  Repository? _selectedRepo;
  List<String> _branches = [];
  String? _selectedBranch;
  
  // File Management
  List<FileItem> _files = [];
  FileItem? _selectedFile;
  String _currentPath = '';
  
  // UI State
  bool _isLoading = false;
  bool _isTokenValid = false;
  String _statusMessage = '';
  
  // Layout
  late TabController _tabController;
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadGitHubToken();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _tokenController.dispose();
    _searchController.dispose();
    _codeController.dispose();
    super.dispose();
  }
  
  // Load saved GitHub token
  Future<void> _loadGitHubToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('github_token');
    if (token != null) {
      setState(() {
        _githubToken = token;
        _tokenController.text = token;
      });
      await _validateToken();
    }
  }
  
  // Save GitHub token
  Future<void> _saveGitHubToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_token', _tokenController.text);
    setState(() {
      _githubToken = _tokenController.text;
    });
    await _validateToken();
  }
  
  // Validate GitHub token
  Future<void> _validateToken() async {
    if (_githubToken == null || _githubToken!.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/user'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _isTokenValid = true;
          _statusMessage = 'Token validated successfully';
        });
        await _fetchRepositories();
      } else {
        setState(() {
          _isTokenValid = false;
          _statusMessage = 'Invalid GitHub token';
        });
      }
    } catch (e) {
      setState(() {
        _isTokenValid = false;
        _statusMessage = 'Error validating token: $e';
      });
    }
    
    setState(() => _isLoading = false);
  }
  
  // Fetch user repositories
  Future<void> _fetchRepositories() async {
    if (!_isTokenValid) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/user/repos?per_page=100&sort=updated'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> repoData = json.decode(response.body);
        setState(() {
          _repositories = repoData.map((repo) => Repository.fromJson(repo)).toList();
          _statusMessage = 'Loaded ${_repositories.length} repositories';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching repositories: $e';
      });
    }
    
    setState(() => _isLoading = false);
  }
  
  // Fetch branches for selected repository
  Future<void> _fetchBranches(Repository repo) async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/${repo.fullName}/branches'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> branchData = json.decode(response.body);
        setState(() {
          _branches = branchData.map((branch) => branch['name'] as String).toList();
          _selectedBranch = _branches.isNotEmpty ? _branches[0] : null;
          _selectedRepo = repo;
        });
        
        if (_selectedBranch != null) {
          await _fetchFiles('');
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching branches: $e';
      });
    }
    
    setState(() => _isLoading = false);
  }
  
  // Fetch files from repository
  Future<void> _fetchFiles(String path) async {
    if (_selectedRepo == null || _selectedBranch == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/${_selectedRepo!.fullName}/contents/$path?ref=$_selectedBranch'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (response.statusCode == 200) {
        final dynamic fileData = json.decode(response.body);
        final List<dynamic> files = fileData is List ? fileData : [fileData];
        
        setState(() {
          _files = files.map((file) => FileItem.fromJson(file)).toList();
          _currentPath = path;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching files: $e';
      });
    }
    
    setState(() => _isLoading = false);
  }
  
  // Fetch file content
  Future<void> _fetchFileContent(FileItem file) async {
    if (file.type != 'file') return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/${_selectedRepo!.fullName}/contents/${file.path}?ref=$_selectedBranch'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (response.statusCode == 200) {
        final fileData = json.decode(response.body);
        final content = base64Decode(fileData['content']);
        final decodedContent = utf8.decode(content);
        
        setState(() {
          _selectedFile = file;
          _codeController.text = decodedContent;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching file content: $e';
      });
    }
    
    setState(() => _isLoading = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'AI Coder',
          style: TextStyle(
            color: Color(0xFF2D3748),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2D3748),
          unselectedLabelColor: const Color(0xFF718096),
          indicatorColor: const Color(0xFF4299E1),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: FaIcon(FontAwesomeIcons.github, size: 16), text: 'Setup'),
            Tab(icon: FaIcon(FontAwesomeIcons.folder, size: 16), text: 'Files'),
            Tab(icon: FaIcon(FontAwesomeIcons.code, size: 16), text: 'Editor'),
            Tab(icon: FaIcon(FontAwesomeIcons.codeBranch, size: 16), text: 'Git'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSetupTab(),
          _buildFilesTab(),
          _buildEditorTab(),
          _buildGitTab(),
        ],
      ),
    );
  }
  
  Widget _buildSetupTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GitHub Integration',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your GitHub personal access token to access repositories.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF718096),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _tokenController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'GitHub Personal Access Token',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
                hintStyle: TextStyle(color: Color(0xFFA0AEC0), fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveGitHubToken,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4299E1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Validate Token', style: TextStyle(fontSize: 14)),
            ),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isTokenValid ? const Color(0xFFF0FFF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isTokenValid ? const Color(0xFF9AE6B4) : const Color(0xFFFCA5A5),
                ),
              ),
              child: Row(
                children: [
                  FaIcon(
                    _isTokenValid ? FontAwesomeIcons.check : FontAwesomeIcons.xmark,
                    size: 14,
                    color: _isTokenValid ? const Color(0xFF38A169) : const Color(0xFFE53E3E),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: _isTokenValid ? const Color(0xFF38A169) : const Color(0xFFE53E3E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_isTokenValid && _repositories.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Repositories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListView.builder(
                  itemCount: _repositories.length,
                  itemBuilder: (context, index) {
                    final repo = _repositories[index];
                    return ListTile(
                      dense: true,
                      leading: FaIcon(
                        repo.isPrivate ? FontAwesomeIcons.lock : FontAwesomeIcons.globe,
                        size: 14,
                        color: const Color(0xFF718096),
                      ),
                      title: Text(
                        repo.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        repo.description ?? 'No description',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        repo.language ?? '',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF4299E1)),
                      ),
                      onTap: () => _fetchBranches(repo),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFilesTab() {
    if (_selectedRepo == null) {
      return const Center(
        child: Text(
          'Select a repository from Setup tab',
          style: TextStyle(color: Color(0xFF718096)),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedRepo!.name} / $_selectedBranch',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
              if (_branches.isNotEmpty)
                PopupMenuButton<String>(
                  onSelected: (branch) {
                    setState(() => _selectedBranch = branch);
                    _fetchFiles('');
                  },
                  itemBuilder: (context) => _branches
                      .map((branch) => PopupMenuItem(
                            value: branch,
                            child: Text(branch, style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4299E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(FontAwesomeIcons.codeBranch, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_currentPath.isNotEmpty)
            GestureDetector(
              onTap: () {
                final parentPath = path.dirname(_currentPath);
                _fetchFiles(parentPath == '.' ? '' : parentPath);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Row(
                  children: [
                    FaIcon(FontAwesomeIcons.arrowLeft, size: 12, color: Color(0xFF4299E1)),
                    SizedBox(width: 8),
                    Text(
                      '.. Back',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4299E1)),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return ListTile(
                    dense: true,
                    leading: FaIcon(
                      file.type == 'dir' 
                          ? FontAwesomeIcons.folder 
                          : FontAwesomeIcons.file,
                      size: 14,
                      color: file.type == 'dir' 
                          ? const Color(0xFFECC94B) 
                          : const Color(0xFF718096),
                    ),
                    title: Text(
                      file.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: () {
                      if (file.type == 'dir') {
                        _fetchFiles(file.path);
                      } else {
                        _fetchFileContent(file);
                        _tabController.animateTo(2); // Switch to editor tab
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEditorTab() {
    if (_selectedFile == null) {
      return const Center(
        child: Text(
          'Select a file from Files tab',
          style: TextStyle(color: Color(0xFF718096)),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.file,
                size: 14,
                color: const Color(0xFF718096),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedFile!.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement save functionality
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48BB78),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Save', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A202C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _codeController,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 12,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                  hintText: 'File content will appear here...',
                  hintStyle: TextStyle(color: Color(0xFF718096)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGitTab() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Git operations will be implemented here',
          style: TextStyle(color: Color(0xFF718096)),
        ),
      ),
    );
  }
}

// Data Models
class Repository {
  final String name;
  final String fullName;
  final String? description;
  final bool isPrivate;
  final String? language;
  final String cloneUrl;
  
  Repository({
    required this.name,
    required this.fullName,
    this.description,
    required this.isPrivate,
    this.language,
    required this.cloneUrl,
  });
  
  factory Repository.fromJson(Map<String, dynamic> json) {
    return Repository(
      name: json['name'],
      fullName: json['full_name'],
      description: json['description'],
      isPrivate: json['private'],
      language: json['language'],
      cloneUrl: json['clone_url'],
    );
  }
}

class FileItem {
  final String name;
  final String path;
  final String type;
  final String? downloadUrl;
  
  FileItem({
    required this.name,
    required this.path,
    required this.type,
    this.downloadUrl,
  });
  
  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'],
      path: json['path'],
      type: json['type'],
      downloadUrl: json['download_url'],
    );
  }
}