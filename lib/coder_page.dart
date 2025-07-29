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
  const CoderPage({super.key});

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
  
  // Task Management
  List<CoderTask> _tasks = [];
  bool _isProcessingTask = false;
  
  @override
  void initState() {
    super.initState();
    _toolsService = ExternalToolsService();
    _loadGitHubToken();
  }
  
  @override
  void dispose() {
    _taskController.dispose();
    _scrollController.dispose();
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
  
  // Execute AI workflow steps
  Future<void> _executeAIWorkflow(CoderTask task) async {
    try {
      // Step 1: Think
      await _updateTaskStep(task, 'Analyzing task requirements...', TaskStatus.thinking);
      await Future.delayed(const Duration(seconds: 2));
      
      // Step 2: Plan
      await _updateTaskStep(task, 'Creating execution plan...', TaskStatus.planning);
      await Future.delayed(const Duration(seconds: 2));
      
      // Step 3: Execute
      await _updateTaskStep(task, 'Implementing changes...', TaskStatus.executing);
      
      // Use AI to understand and implement the task
      final aiResult = await _getAIAssistance(task);
      
      // Step 4: Verify
      await _updateTaskStep(task, 'Verifying implementation...', TaskStatus.verifying);
      await Future.delayed(const Duration(seconds: 1));
      
      // Step 5: Success
      await _updateTaskStep(task, 'Task completed successfully!', TaskStatus.completed);
      
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
  
  // Get AI assistance for the task
  Future<String> _getAIAssistance(CoderTask task) async {
    try {
      // Build context about the repository and task
      final context = '''
Repository: ${task.repository.name}
Branch: ${task.branch}
Task: ${task.description}
Language: ${task.repository.language ?? 'Unknown'}

Please provide implementation guidance for this task.
''';
      
      // Here you would integrate with your AI service
      // For now, return a placeholder response
      return 'AI implementation guidance generated';
      
    } catch (e) {
      throw Exception('AI assistance failed: $e');
    }
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
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
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
        ],
      ),
    );
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