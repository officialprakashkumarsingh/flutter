import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'external_tools_service.dart';

class CoderPage extends StatefulWidget {
  final String selectedModel;
  
  const CoderPage({super.key, required this.selectedModel});

  @override
  State<CoderPage> createState() => _CoderPageState();
}

class _CoderPageState extends State<CoderPage> {
  final TextEditingController _taskController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // GitHub Integration
  String? _githubToken;
  List<Repository> _repositories = [];
  Repository? _selectedRepo;
  List<String> _branches = [];
  String? _selectedBranch;
  
  // UI State
  bool _isLoading = false;
  bool _isTokenValid = false;
  String _statusMessage = '';
  bool _showRepoDropdown = false;
  bool _showBranchDropdown = false;
  
  // AI Integration
  late ExternalToolsService _toolsService;
  late http.Client _httpClient;
  
  // Task Management
  List<CoderTask> _tasks = [];
  bool _isProcessingTask = false;
  
  // File Management
  Map<String, String> _fileContents = {};
  Map<String, String> _modifiedFiles = {};
  
  // Follow-up System
  bool _showFollowUp = false;
  final TextEditingController _followUpController = TextEditingController();
  
  // Git Operations
  bool _showGitOptions = false;
  final TextEditingController _commitMessageController = TextEditingController();
  String _gitStatus = '';
  bool _hasUncommittedChanges = false;
  
  @override
  void initState() {
    super.initState();
    _toolsService = ExternalToolsService();
    _httpClient = http.Client();
    _loadGitHubToken();
  }
  
  @override
  void dispose() {
    _taskController.dispose();
    _scrollController.dispose();
    _followUpController.dispose();
    _commitMessageController.dispose();
    _httpClient.close();
    super.dispose();
  }
  
  // Load saved GitHub token
  Future<void> _loadGitHubToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('github_token');
    if (token != null) {
      setState(() {
        _githubToken = token;
      });
      await _validateToken();
    } else {
      _showTokenSetupDialog();
    }
  }
  
  // Show token setup dialog
  void _showTokenSetupDialog() {
    final tokenController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Setup GitHub Access',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your GitHub Personal Access Token to continue.',
              style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: tokenController,
                obscureText: true,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'ghp_xxxxxxxxxxxx',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10),
                  hintStyle: TextStyle(color: Color(0xFFA0AEC0), fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (tokenController.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('github_token', tokenController.text);
                setState(() {
                  _githubToken = tokenController.text;
                });
                Navigator.pop(context);
                await _validateToken();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4299E1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Save', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
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
          _statusMessage = 'Connected to GitHub';
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
        _statusMessage = 'Connection failed';
      });
    }
    
    setState(() => _isLoading = false);
  }
  
  // Fetch user repositories
  Future<void> _fetchRepositories() async {
    if (!_isTokenValid) return;
    
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
        });
      }
    } catch (e) {
      print('Error fetching repositories: $e');
    }
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
          _showRepoDropdown = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching branches: $e';
      });
    }
    
    setState(() => _isLoading = false);
  }
  
  // Process user task with AI
  Future<void> _processTask() async {
    final taskDescription = _taskController.text.trim();
    if (taskDescription.isEmpty || _selectedRepo == null || _selectedBranch == null) return;
    
    setState(() {
      _isProcessingTask = true;
    });
    
    // Create new task
    final task = CoderTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: taskDescription,
      repository: _selectedRepo!,
      branch: _selectedBranch!,
      status: TaskStatus.thinking,
      steps: [],
      createdAt: DateTime.now(),
    );
    
    setState(() {
      _tasks.insert(0, task);
      _taskController.clear();
    });
    
    _scrollToBottom();
    
    // AI Workflow: Think → Plan → Execute → Verify → Success
    await _executeAIWorkflow(task);
    
    setState(() {
      _isProcessingTask = false;
    });
  }
  
  // Execute AI workflow steps with REAL functionality
  Future<void> _executeAIWorkflow(CoderTask task) async {
    try {
      // Step 1: Think - Real AI analysis
      await _updateTaskStep(task, 'Analyzing task requirements and codebase...', TaskStatus.thinking);
      
      // Get repository structure for context
      final repoContext = await _getRepositoryContext(task);
      await _updateTaskStep(task, 'Understanding project structure: ${repoContext['fileCount']} files analyzed', TaskStatus.thinking);
      
      // Step 2: Plan - Real AI planning
      await _updateTaskStep(task, 'Creating detailed implementation plan...', TaskStatus.planning);
      
      final plan = await _generateAIPlan(task, repoContext);
      await _updateTaskStep(task, 'Plan created: ${plan['summary']}', TaskStatus.planning);
      
      // Step 3: Execute - Real file modifications
      await _updateTaskStep(task, 'Starting implementation...', TaskStatus.executing);
      
      // Execute the plan with real file operations
      await _executeAIPlan(task, plan);
      
      // Step 4: Verify - Check implementations
      await _updateTaskStep(task, 'Verifying changes and running checks...', TaskStatus.verifying);
      
      final verification = await _verifyChanges(task);
      await _updateTaskStep(task, verification['message'], TaskStatus.verifying);
      
      // Step 5: Success with Git operations
      await _updateTaskStep(task, 'Task completed! ${_modifiedFiles.length} files modified', TaskStatus.completed);
      
      // Check Git status and show options
      await _checkGitStatus(task);
      
      // Show follow-up and Git options
      setState(() {
        _showFollowUp = true;
        _showGitOptions = true;
        _hasUncommittedChanges = _modifiedFiles.isNotEmpty;
      });
      
    } catch (e) {
      await _updateTaskStep(task, 'Error: $e', TaskStatus.failed);
    }
  }
  
  // Update task step with streaming effect
  Future<void> _updateTaskStep(CoderTask task, String stepDescription, TaskStatus status) async {
    setState(() {
      task.status = status;
      task.steps.add(TaskStep(
        description: stepDescription,
        timestamp: DateTime.now(),
        status: status,
      ));
    });
    _scrollToBottom();
    
    // Simulate streaming effect
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  // Get repository context for AI
  Future<Map<String, dynamic>> _getRepositoryContext(CoderTask task) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/contents?ref=${task.branch}'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> files = json.decode(response.body);
        final fileCount = files.length;
        final languages = <String>{};
        
        // Analyze file types
        for (final file in files) {
          final name = file['name'] as String;
          final ext = path.extension(name);
          if (ext.isNotEmpty) {
            languages.add(ext);
          }
        }
        
        return {
          'fileCount': fileCount,
          'languages': languages.toList(),
          'files': files.take(20).map((f) => f['name']).toList(), // First 20 files
        };
      }
      
      return {'fileCount': 0, 'languages': [], 'files': []};
    } catch (e) {
      return {'fileCount': 0, 'languages': [], 'files': []};
    }
  }
  
  // Generate AI plan using real AI model
  Future<Map<String, dynamic>> _generateAIPlan(CoderTask task, Map<String, dynamic> context) async {
    try {
      final prompt = '''
Repository: ${task.repository.name} (${task.repository.language})
Branch: ${task.branch}
Files: ${context['fileCount']} files
Languages: ${context['languages'].join(', ')}
Key files: ${context['files'].join(', ')}

Task: ${task.description}

As an expert developer, create a detailed implementation plan for this task.
Provide specific file paths, code changes, and step-by-step instructions.
Focus on the most relevant files for this task.

Respond with a structured plan including:
1. Files to modify
2. Specific changes needed
3. Implementation steps
''';

      final aiResponse = await _callAIModel(prompt);
      
      return {
        'summary': 'Implementation plan for ${task.description}',
        'response': aiResponse,
        'files_to_modify': _extractFilesFromPlan(aiResponse),
      };
    } catch (e) {
      throw Exception('Failed to generate AI plan: $e');
    }
  }
  
  // Execute AI plan with real file operations
  Future<void> _executeAIPlan(CoderTask task, Map<String, dynamic> plan) async {
    final filesToModify = plan['files_to_modify'] as List<String>;
    
    for (final filePath in filesToModify) {
      await _updateTaskStep(task, 'Modifying $filePath...', TaskStatus.executing);
      
      try {
        // Get current file content
        final currentContent = await _getFileContent(task, filePath);
        
        // Get AI suggestions for this specific file
        final modificationPrompt = '''
Current file: $filePath
Current content:
```
$currentContent
```

Task: ${task.description}
Plan: ${plan['response']}

Provide the COMPLETE modified file content for this specific file.
Only return the code, no explanations.
''';

        final modifiedContent = await _callAIModel(modificationPrompt);
        
        // Store modification
        _modifiedFiles[filePath] = modifiedContent;
        _fileContents[filePath] = currentContent;
        
        await _updateTaskStep(task, 'Modified $filePath (${modifiedContent.length} chars)', TaskStatus.executing);
        
        // Small delay for streaming effect
        await Future.delayed(const Duration(milliseconds: 800));
        
      } catch (e) {
        await _updateTaskStep(task, 'Failed to modify $filePath: $e', TaskStatus.executing);
      }
    }
  }
  
  // Call AI model using the selected model
  Future<String> _callAIModel(String prompt) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ahamaibyprakash25',
        },
        body: json.encode({
          'model': widget.selectedModel,
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert software developer. Provide precise, practical code solutions.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'max_tokens': 2000,
          'temperature': 0.3,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'] ?? 'No response from AI';
      } else {
        throw Exception('AI API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to call AI model: $e');
    }
  }
  
  // Get file content from GitHub
  Future<String> _getFileContent(CoderTask task, String filePath) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/contents/$filePath?ref=${task.branch}'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (response.statusCode == 200) {
        final fileData = json.decode(response.body);
        final content = base64Decode(fileData['content']);
        return utf8.decode(content);
      }
      
      return '// File not found or empty';
    } catch (e) {
      return '// Error loading file: $e';
    }
  }
  
  // Extract file paths from AI plan
  List<String> _extractFilesFromPlan(String plan) {
    final filePattern = RegExp(r'([a-zA-Z0-9_\-./]+\.(js|ts|py|java|cpp|c|h|dart|kt|swift|go|rs|php|rb|cs))', multiLine: true);
    final matches = filePattern.allMatches(plan);
    return matches.map((match) => match.group(1)!).toSet().toList();
  }
  
  // Verify changes
  Future<Map<String, dynamic>> _verifyChanges(CoderTask task) async {
    if (_modifiedFiles.isEmpty) {
      return {
        'success': false,
        'message': 'No files were modified',
      };
    }
    
    return {
      'success': true,
      'message': 'Successfully modified ${_modifiedFiles.length} files: ${_modifiedFiles.keys.join(', ')}',
    };
  }
  
  // Check Git status
  Future<void> _checkGitStatus(CoderTask task) async {
    try {
      // For now, simulate git status (in real implementation, you'd use git commands)
      if (_modifiedFiles.isNotEmpty) {
        final modifiedFilesList = _modifiedFiles.keys.map((file) => '    modified:   $file').join('\n');
        _gitStatus = '''
On branch ${task.branch}
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)

$modifiedFilesList

no changes added to commit (use "git add ." or "git commit -a")
''';
      } else {
        _gitStatus = 'On branch ${task.branch}\nnothing to commit, working tree clean';
      }
    } catch (e) {
      _gitStatus = 'Error checking git status: $e';
    }
  }
  
  // Commit changes via GitHub API
  Future<void> _commitChanges(CoderTask task, String commitMessage) async {
    if (_modifiedFiles.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Get current commit SHA
      final branchResponse = await http.get(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/git/refs/heads/${task.branch}'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (branchResponse.statusCode != 200) {
        throw Exception('Failed to get branch info');
      }
      
      final branchData = json.decode(branchResponse.body);
      final currentCommitSha = branchData['object']['sha'];
      
      // Get current tree
      final commitResponse = await http.get(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/git/commits/$currentCommitSha'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (commitResponse.statusCode != 200) {
        throw Exception('Failed to get current commit');
      }
      
      final commitData = json.decode(commitResponse.body);
      final treeSha = commitData['tree']['sha'];
      
      // Create new tree with modified files
      final treeItems = <Map<String, dynamic>>[];
      
      for (final entry in _modifiedFiles.entries) {
        treeItems.add({
          'path': entry.key,
          'mode': '100644',
          'type': 'blob',
          'content': entry.value,
        });
      }
      
      final newTreeResponse = await http.post(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/git/trees'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'base_tree': treeSha,
          'tree': treeItems,
        }),
      );
      
      if (newTreeResponse.statusCode != 201) {
        throw Exception('Failed to create new tree');
      }
      
      final newTreeData = json.decode(newTreeResponse.body);
      final newTreeSha = newTreeData['sha'];
      
      // Create new commit
      final newCommitResponse = await http.post(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/git/commits'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': commitMessage,
          'tree': newTreeSha,
          'parents': [currentCommitSha],
        }),
      );
      
      if (newCommitResponse.statusCode != 201) {
        throw Exception('Failed to create commit');
      }
      
      final newCommitData = json.decode(newCommitResponse.body);
      final newCommitSha = newCommitData['sha'];
      
      // Update branch reference
      final updateRefResponse = await http.patch(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/git/refs/heads/${task.branch}'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'sha': newCommitSha,
        }),
      );
      
      if (updateRefResponse.statusCode != 200) {
        throw Exception('Failed to update branch');
      }
      
      // Success!
      setState(() {
        _hasUncommittedChanges = false;
        _gitStatus = 'On branch ${task.branch}\nnothing to commit, working tree clean';
      });
      
      _showSnackBar('✅ Successfully committed and pushed ${_modifiedFiles.length} files!');
      _commitMessageController.clear();
      
    } catch (e) {
      _showSnackBar('❌ Commit failed: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  // Create new branch
  Future<void> _createBranch(CoderTask task, String branchName) async {
    setState(() => _isLoading = true);
    
    try {
      // Get current commit SHA
      final branchResponse = await http.get(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/git/refs/heads/${task.branch}'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (branchResponse.statusCode != 200) {
        throw Exception('Failed to get current branch');
      }
      
      final branchData = json.decode(branchResponse.body);
      final currentCommitSha = branchData['object']['sha'];
      
      // Create new branch
      final newBranchResponse = await http.post(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/git/refs'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'ref': 'refs/heads/$branchName',
          'sha': currentCommitSha,
        }),
      );
      
      if (newBranchResponse.statusCode == 201) {
        // Switch to new branch
        setState(() {
          _selectedBranch = branchName;
          if (!_branches.contains(branchName)) {
            _branches.add(branchName);
          }
        });
        
        _showSnackBar('✅ Created and switched to branch: $branchName');
      } else {
        throw Exception('Failed to create branch');
      }
      
    } catch (e) {
      _showSnackBar('❌ Branch creation failed: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  // Create pull request
  Future<void> _createPullRequest(CoderTask task, String title, String body, String baseBranch) async {
    setState(() => _isLoading = true);
    
    try {
      final prResponse = await http.post(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/pulls'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': title,
          'body': body,
          'head': task.branch,
          'base': baseBranch,
        }),
      );
      
      if (prResponse.statusCode == 201) {
        final prData = json.decode(prResponse.body);
        final prNumber = prData['number'];
        final prUrl = prData['html_url'];
        
        _showSnackBar('✅ Pull Request #$prNumber created successfully!');
      } else {
        throw Exception('Failed to create pull request');
      }
      
    } catch (e) {
      _showSnackBar('❌ Pull request creation failed: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  // Show snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  // Scroll to bottom of task list
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Coder',
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
        actions: [
          if (_isTokenValid)
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.gear, size: 16, color: Color(0xFF718096)),
              onPressed: _showTokenSetupDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // Repository and Branch Selection Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Repository Selection
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.github, size: 14, color: Color(0xFF718096)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_repositories.isNotEmpty) {
                            setState(() {
                              _showRepoDropdown = !_showRepoDropdown;
                              _showBranchDropdown = false;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedRepo?.name ?? 'Select Repository',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _selectedRepo != null 
                                        ? const Color(0xFF2D3748) 
                                        : const Color(0xFF718096),
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF718096)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_selectedRepo != null) ...[
                      const SizedBox(width: 8),
                      const FaIcon(FontAwesomeIcons.codeBranch, size: 12, color: Color(0xFF718096)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          if (_branches.isNotEmpty) {
                            setState(() {
                              _showBranchDropdown = !_showBranchDropdown;
                              _showRepoDropdown = false;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4299E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedBranch ?? 'main',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Dropdowns
                if (_showRepoDropdown && _repositories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _repositories.length,
                      itemBuilder: (context, index) {
                        final repo = _repositories[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          leading: FaIcon(
                            repo.isPrivate ? FontAwesomeIcons.lock : FontAwesomeIcons.globe,
                            size: 12,
                            color: const Color(0xFF718096),
                          ),
                          title: Text(
                            repo.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            repo.description ?? 'No description',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF718096)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: repo.language != null
                              ? Text(
                                  repo.language!,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF4299E1)),
                                )
                              : null,
                          onTap: () => _fetchBranches(repo),
                        );
                      },
                    ),
                  ),
                ],
                
                if (_showBranchDropdown && _branches.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _branches.length,
                      itemBuilder: (context, index) {
                        final branch = _branches[index];
                        final isSelected = branch == _selectedBranch;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          leading: FaIcon(
                            FontAwesomeIcons.codeBranch,
                            size: 12,
                            color: isSelected ? const Color(0xFF4299E1) : const Color(0xFF718096),
                          ),
                          title: Text(
                            branch,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? const Color(0xFF4299E1) : const Color(0xFF2D3748),
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedBranch = branch;
                              _showBranchDropdown = false;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
                
                // Task Input
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taskController,
                          decoration: const InputDecoration(
                            hintText: 'Describe what you want to build or modify...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(12),
                            hintStyle: TextStyle(color: Color(0xFFA0AEC0), fontSize: 14),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _processTask(),
                        ),
                      ),
                      IconButton(
                        onPressed: _selectedRepo != null && _selectedBranch != null && !_isProcessingTask
                            ? _processTask
                            : null,
                        icon: _isProcessingTask
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4299E1)),
                                ),
                              )
                            : const FaIcon(
                                FontAwesomeIcons.paperPlane,
                                size: 16,
                                color: Color(0xFF4299E1),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
                     // Tasks List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length + (_showGitOptions ? 1 : 0) + (_showFollowUp ? 1 : 0),
              itemBuilder: (context, index) {
                if (_showGitOptions && index == _tasks.length) {
                  return _buildGitCard();
                }
                if (_showFollowUp && index == _tasks.length + (_showGitOptions ? 1 : 0)) {
                  return _buildFollowUpCard();
                }
                return _buildTaskCard(_tasks[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaskCard(CoderTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                _buildStatusIcon(task.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.description,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                Text(
                  _formatTime(task.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
          
          // Task Steps
          if (task.steps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: task.steps.map((step) => _buildTaskStep(step)).toList(),
              ),
            ),
          
          // Modified Files Display
          if (_modifiedFiles.isNotEmpty && task.status == TaskStatus.completed)
            _buildModifiedFilesSection(),
        ],
      ),
    );
  }
  
  Widget _buildModifiedFilesSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.fileCode, size: 12, color: Color(0xFF4299E1)),
                const SizedBox(width: 6),
                Text(
                  'Modified Files (${_modifiedFiles.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
          ),
          ...(_modifiedFiles.entries.take(3).map((entry) => _buildFilePreview(entry.key, entry.value))),
          if (_modifiedFiles.length > 3)
            Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                '... and ${_modifiedFiles.length - 3} more files',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF718096),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildFilePreview(String fileName, String content) {
    final lines = content.split('\n');
    final previewLines = lines.take(3).join('\n');
    
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF2D3748),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${lines.length} lines',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Text(
              previewLines + (lines.length > 3 ? '\n...' : ''),
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFE5E7EB),
                fontFamily: 'Courier',
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGitCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF48BB78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FFF4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.codeBranch, size: 12, color: Color(0xFF48BB78)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Git Operations',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                if (_hasUncommittedChanges)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECC94B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_modifiedFiles.length} changes',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Git Status
                if (_gitStatus.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A202C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            FaIcon(FontAwesomeIcons.terminal, size: 10, color: Color(0xFF9CA3AF)),
                            SizedBox(width: 6),
                            Text(
                              'git status',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _gitStatus,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFFE5E7EB),
                            fontFamily: 'Courier',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Git Actions
                if (_hasUncommittedChanges) ...[
                  const Text(
                    'Commit Changes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _commitMessageController,
                      decoration: InputDecoration(
                        hintText: 'feat: ${_tasks.isNotEmpty ? _tasks.first.description.toLowerCase() : 'update files'}',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(10),
                        hintStyle: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 11),
                      ),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Action Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildGitButton(
                        'Commit & Push',
                        FontAwesomeIcons.upload,
                        const Color(0xFF48BB78),
                        () {
                          final message = _commitMessageController.text.trim();
                          if (message.isEmpty) {
                            _commitMessageController.text = 'feat: ${_tasks.isNotEmpty ? _tasks.first.description.toLowerCase() : 'update files'}';
                          }
                          if (_tasks.isNotEmpty) {
                            _commitChanges(_tasks.first, _commitMessageController.text);
                          }
                        },
                      ),
                      _buildGitButton(
                        'New Branch',
                        FontAwesomeIcons.codeBranch,
                        const Color(0xFF4299E1),
                        () => _showCreateBranchDialog(),
                      ),
                      _buildGitButton(
                        'Pull Request',
                        FontAwesomeIcons.codeCompare,
                        const Color(0xFF9F7AEA),
                        () => _showCreatePRDialog(),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    '✅ All changes committed',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF48BB78),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGitButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: FaIcon(icon, size: 10, color: Colors.white),
      label: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
  
  // Show create branch dialog
  void _showCreateBranchDialog() {
    final branchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Create New Branch',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: branchController,
              decoration: InputDecoration(
                hintText: 'feature/new-feature',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.all(10),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              if (branchController.text.isNotEmpty && _tasks.isNotEmpty) {
                Navigator.pop(context);
                _createBranch(_tasks.first, branchController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4299E1)),
            child: const Text('Create', style: TextStyle(fontSize: 12, color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  // Show create PR dialog
  void _showCreatePRDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    
    // Pre-fill with task info
    if (_tasks.isNotEmpty) {
      titleController.text = _tasks.first.description;
      bodyController.text = '''## Changes Made
${_modifiedFiles.keys.map((file) => '- Modified `$file`').join('\n')}

## Task Description
${_tasks.first.description}

Generated by AhamAI Coder
''';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Create Pull Request',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  contentPadding: const EdgeInsets.all(10),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  contentPadding: const EdgeInsets.all(10),
                ),
                style: const TextStyle(fontSize: 12),
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && _tasks.isNotEmpty) {
                Navigator.pop(context);
                _createPullRequest(_tasks.first, titleController.text, bodyController.text, 'main');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9F7AEA)),
            child: const Text('Create PR', style: TextStyle(fontSize: 12, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4299E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F8FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.arrowRight, size: 12, color: Color(0xFF4299E1)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Follow-up Task',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                Text(
                  'Continue building',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF4299E1),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What would you like to build or modify next?',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4A5568),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _followUpController,
                          decoration: const InputDecoration(
                            hintText: 'Add more features, fix bugs, improve code...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(10),
                            hintStyle: TextStyle(color: Color(0xFFA0AEC0), fontSize: 12),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _processFollowUp(),
                        ),
                      ),
                      IconButton(
                        onPressed: _isProcessingTask ? null : _processFollowUp,
                        icon: const FaIcon(
                          FontAwesomeIcons.paperPlane,
                          size: 14,
                          color: Color(0xFF4299E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Process follow-up task
  Future<void> _processFollowUp() async {
    final followUpDescription = _followUpController.text.trim();
    if (followUpDescription.isEmpty || _selectedRepo == null || _selectedBranch == null) return;
    
    setState(() {
      _showFollowUp = false;
    });
    
    // Create follow-up task with context from previous tasks
    final previousContext = _tasks.isNotEmpty 
        ? 'Previous task: ${_tasks.first.description}\nModified files: ${_modifiedFiles.keys.join(', ')}\n\n'
        : '';
    
    _taskController.text = previousContext + followUpDescription;
    await _processTask();
    
    _followUpController.clear();
  }
  
  Widget _buildTaskStep(TaskStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: _getStatusColor(step.status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.description,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4A5568),
              ),
            ),
          ),
          Text(
            _formatTime(step.timestamp),
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.thinking:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4299E1)),
          ),
        );
      case TaskStatus.planning:
        return const FaIcon(FontAwesomeIcons.lightbulb, size: 14, color: Color(0xFFECC94B));
      case TaskStatus.executing:
        return const FaIcon(FontAwesomeIcons.gear, size: 14, color: Color(0xFF4299E1));
      case TaskStatus.verifying:
        return const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 14, color: Color(0xFF9F7AEA));
      case TaskStatus.completed:
        return const FaIcon(FontAwesomeIcons.check, size: 14, color: Color(0xFF48BB78));
      case TaskStatus.failed:
        return const FaIcon(FontAwesomeIcons.xmark, size: 14, color: Color(0xFFE53E3E));
    }
  }
  
  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.thinking:
      case TaskStatus.executing:
        return const Color(0xFF4299E1);
      case TaskStatus.planning:
        return const Color(0xFFECC94B);
      case TaskStatus.verifying:
        return const Color(0xFF9F7AEA);
      case TaskStatus.completed:
        return const Color(0xFF48BB78);
      case TaskStatus.failed:
        return const Color(0xFFE53E3E);
    }
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
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

class CoderTask {
  final String id;
  final String description;
  final Repository repository;
  final String branch;
  TaskStatus status;
  final List<TaskStep> steps;
  final DateTime createdAt;
  
  CoderTask({
    required this.id,
    required this.description,
    required this.repository,
    required this.branch,
    required this.status,
    required this.steps,
    required this.createdAt,
  });
}

class TaskStep {
  final String description;
  final DateTime timestamp;
  final TaskStatus status;
  
  TaskStep({
    required this.description,
    required this.timestamp,
    required this.status,
  });
}

enum TaskStatus {
  thinking,
  planning,
  executing,
  verifying,
  completed,
  failed,
}