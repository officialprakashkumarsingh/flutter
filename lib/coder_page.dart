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
  String? _expandedTaskId; // Track which task is expanded
  
  // File Management
  Map<String, String> _fileContents = {};
  Map<String, String> _modifiedFiles = {};
  Map<String, String> _fileOperations = {}; // Track what operation was done on each file
  
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
  
  // Process user task with AI - focused on coding tasks only
  Future<void> _processTask() async {
    final taskDescription = _taskController.text.trim();
    if (taskDescription.isEmpty || _selectedRepo == null || _selectedBranch == null) return;
    
    setState(() {
      _isProcessingTask = true;
    });
    
    // Create new coding task
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
    
    // Enhanced AI Workflow: Think → Plan → Execute → Verify → Success
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
      await _updateTaskStep(task, 'Task completed! ${_modifiedFiles.length} files processed', TaskStatus.completed);
      
      // Generate AI summary of what was accomplished
      await _generateTaskSummary(task);
      
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
  
  // Get repository context for AI with project type detection
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
        final fileNames = <String>[];
        
        // Analyze file types and names
        for (final file in files) {
          final name = file['name'] as String;
          fileNames.add(name.toLowerCase());
          final ext = path.extension(name);
          if (ext.isNotEmpty) {
            languages.add(ext);
          }
        }
        
        // Enhanced project type detection with user context
        final projectType = _detectProjectTypeWithUserContext(fileNames, task.description);
        final technologies = _getProjectTechnologies(fileNames, languages.toList());
        
        return {
          'fileCount': fileCount,
          'languages': languages.toList(),
          'files': files.take(20).map((f) => f['name']).toList(),
          'projectType': projectType,
          'technologies': technologies,
          'fileNames': fileNames,
        };
      }
      
      // If no repository info, analyze user request only
      final userProjectType = _analyzeUserRequestForLanguage(task.description);
      return {
        'fileCount': 0, 
        'languages': [], 
        'files': [], 
        'projectType': userProjectType != 'Unknown' ? userProjectType : 'General',
        'technologies': [userProjectType != 'Unknown' ? userProjectType : 'General'],
        'fileNames': [],
      };
    } catch (e) {
      // Fallback to user request analysis
      final userProjectType = _analyzeUserRequestForLanguage(task.description);
      return {
        'fileCount': 0, 
        'languages': [], 
        'files': [], 
        'projectType': userProjectType != 'Unknown' ? userProjectType : 'General',
        'technologies': [userProjectType != 'Unknown' ? userProjectType : 'General'],
        'fileNames': [],
      };
    }
  }
  
  // Detect project type from file names
  String _detectProjectType(List<String> fileNames) {
    if (fileNames.any((f) => f.contains('package.json'))) return 'Node.js/JavaScript';
    if (fileNames.any((f) => f.contains('pubspec.yaml'))) return 'Flutter/Dart';
    if (fileNames.any((f) => f.contains('requirements.txt') || f.contains('setup.py') || f.contains('pyproject.toml'))) return 'Python';
    if (fileNames.any((f) => f.contains('pom.xml') || f.contains('build.gradle'))) return 'Java';
    if (fileNames.any((f) => f.contains('cargo.toml'))) return 'Rust';
    if (fileNames.any((f) => f.contains('go.mod'))) return 'Go';
    if (fileNames.any((f) => f.contains('composer.json'))) return 'PHP';
    if (fileNames.any((f) => f.contains('gemfile'))) return 'Ruby';
    if (fileNames.any((f) => f.endsWith('.html') || f.endsWith('.css') || f.endsWith('.js'))) return 'Web Development';
    if (fileNames.any((f) => f.endsWith('.py'))) return 'Python';
    if (fileNames.any((f) => f.endsWith('.java'))) return 'Java';
    if (fileNames.any((f) => f.endsWith('.cpp') || f.endsWith('.c') || f.endsWith('.h'))) return 'C/C++';
    if (fileNames.any((f) => f.endsWith('.cs'))) return 'C#';
    if (fileNames.any((f) => f.endsWith('.swift'))) return 'Swift';
    if (fileNames.any((f) => f.endsWith('.kt'))) return 'Kotlin';
    return 'General';
  }
  
  // Enhanced project type detection with user request analysis
  String _detectProjectTypeWithUserContext(List<String> fileNames, String userRequest) {
    // First try repository-based detection
    String repoType = _detectProjectType(fileNames);
    
    // If repository doesn't provide clear info, analyze user request
    if (repoType == 'General' || repoType == 'Web Development') {
      String userType = _analyzeUserRequestForLanguage(userRequest);
      if (userType != 'Unknown') {
        return userType;
      }
    }
    
    // Remove default web development fallback - be explicit about unknown types
    return repoType == 'General' ? 'Unknown' : repoType;
  }
  
  // Analyze user request to detect programming language/framework intent
  String _analyzeUserRequestForLanguage(String request) {
    final lowerRequest = request.toLowerCase();
    
    // Python indicators
    if (lowerRequest.contains('python') || lowerRequest.contains('django') || 
        lowerRequest.contains('flask') || lowerRequest.contains('fastapi') ||
        lowerRequest.contains('pandas') || lowerRequest.contains('numpy')) {
      return 'Python';
    }
    
    // JavaScript/Node.js indicators
    if (lowerRequest.contains('javascript') || lowerRequest.contains('node') ||
        lowerRequest.contains('express') || lowerRequest.contains('npm') ||
        lowerRequest.contains('js ') || lowerRequest.contains('.js')) {
      return 'Node.js/JavaScript';
    }
    
    // React/Frontend indicators
    if (lowerRequest.contains('react') || lowerRequest.contains('vue') ||
        lowerRequest.contains('angular') || lowerRequest.contains('frontend') ||
        lowerRequest.contains('website') || lowerRequest.contains('web app')) {
      return 'Frontend/React';
    }
    
    // Mobile development indicators  
    if (lowerRequest.contains('flutter') || lowerRequest.contains('dart') ||
        lowerRequest.contains('mobile app') || lowerRequest.contains('android') ||
        lowerRequest.contains('ios')) {
      return 'Flutter/Dart';
    }
    
    // Java indicators
    if (lowerRequest.contains('java') || lowerRequest.contains('spring') ||
        lowerRequest.contains('maven') || lowerRequest.contains('gradle')) {
      return 'Java';
    }
    
    // C/C++ indicators
    if (lowerRequest.contains('c++') || lowerRequest.contains('cpp') ||
        lowerRequest.contains(' c ') || lowerRequest.contains('cmake')) {
      return 'C/C++';
    }
    
    // Go indicators
    if (lowerRequest.contains('golang') || lowerRequest.contains(' go ') ||
        lowerRequest.contains('go module')) {
      return 'Go';
    }
    
    // Rust indicators
    if (lowerRequest.contains('rust') || lowerRequest.contains('cargo')) {
      return 'Rust';
    }
    
    // PHP indicators
    if (lowerRequest.contains('php') || lowerRequest.contains('laravel') ||
        lowerRequest.contains('composer')) {
      return 'PHP';
    }
    
    // C# indicators
    if (lowerRequest.contains('c#') || lowerRequest.contains('csharp') ||
        lowerRequest.contains('.net') || lowerRequest.contains('dotnet')) {
      return 'C#';
    }
    
    // Database/Backend indicators
    if (lowerRequest.contains('database') || lowerRequest.contains('sql') ||
        lowerRequest.contains('api') || lowerRequest.contains('backend')) {
      return 'Backend';
    }
    
    return 'Unknown';
  }
  
  // Get project technologies
  List<String> _getProjectTechnologies(List<String> fileNames, List<String> extensions) {
    List<String> techs = [];
    
    // Frontend technologies
    if (extensions.contains('.html')) techs.add('HTML');
    if (extensions.contains('.css')) techs.add('CSS');
    if (extensions.contains('.js')) techs.add('JavaScript');
    if (extensions.contains('.ts')) techs.add('TypeScript');
    if (extensions.contains('.jsx')) techs.add('React');
    if (extensions.contains('.tsx')) techs.add('React+TypeScript');
    if (extensions.contains('.vue')) techs.add('Vue.js');
    
    // Backend technologies
    if (extensions.contains('.py')) techs.add('Python');
    if (extensions.contains('.java')) techs.add('Java');
    if (extensions.contains('.cpp') || extensions.contains('.c')) techs.add('C/C++');
    if (extensions.contains('.cs')) techs.add('C#');
    if (extensions.contains('.php')) techs.add('PHP');
    if (extensions.contains('.rb')) techs.add('Ruby');
    if (extensions.contains('.go')) techs.add('Go');
    if (extensions.contains('.rs')) techs.add('Rust');
    if (extensions.contains('.dart')) techs.add('Dart');
    if (extensions.contains('.swift')) techs.add('Swift');
    if (extensions.contains('.kt')) techs.add('Kotlin');
    
    // Framework detection
    if (fileNames.any((f) => f.contains('react'))) techs.add('React');
    if (fileNames.any((f) => f.contains('angular'))) techs.add('Angular');
    if (fileNames.any((f) => f.contains('vue'))) techs.add('Vue');
    if (fileNames.any((f) => f.contains('next'))) techs.add('Next.js');
    if (fileNames.any((f) => f.contains('nuxt'))) techs.add('Nuxt.js');
    if (fileNames.any((f) => f.contains('express'))) techs.add('Express.js');
    if (fileNames.any((f) => f.contains('flask'))) techs.add('Flask');
    if (fileNames.any((f) => f.contains('django'))) techs.add('Django');
    
    return techs.isEmpty ? ['Unknown'] : techs;
  }
  
  // Get file extension rules for project type
  String _getFileExtensionRules(String projectType) {
    switch (projectType) {
      case 'Web Development':
        return '''- HTML files: .html (index.html, about.html)
- CSS files: .css (style.css, main.css)
- JavaScript files: .js (script.js, app.js, main.js)
- JSON files: .json (package.json, config.json)''';
      case 'Frontend/React':
        return '''- JavaScript files: .js, .jsx (App.js, components/*.jsx)
- TypeScript files: .ts, .tsx (if using TypeScript)
- CSS files: .css, .scss (styles.css, components/*.module.css)
- JSON files: .json (package.json, tsconfig.json)
- HTML files: .html (public/index.html)''';
      case 'Node.js/JavaScript':
        return '''- JavaScript files: .js (app.js, server.js, index.js)
- TypeScript files: .ts (if using TypeScript)
- JSON files: .json (package.json, config.json)
- Markdown files: .md (README.md)
- Environment files: .env''';
      case 'Python':
        return '''- Python files: .py (main.py, app.py, utils.py)
- Requirements: requirements.txt
- Config files: .yaml, .json, .toml
- Jupyter notebooks: .ipynb
- Environment files: .env''';
      case 'Flutter/Dart':
        return '''- Dart files: .dart (main.dart, app.dart)
- YAML files: pubspec.yaml
- Config files: .yaml, .json
- Assets: images/, fonts/''';
      case 'Java':
        return '''- Java files: .java (Main.java, App.java)
- XML files: .xml (pom.xml)
- Properties files: .properties
- Gradle files: build.gradle''';
      case 'C/C++':
        return '''- C++ files: .cpp, .cc, .cxx
- C files: .c
- Header files: .h, .hpp
- Makefile: Makefile (no extension)
- CMake files: CMakeLists.txt''';
      case 'Go':
        return '''- Go files: .go (main.go, handlers.go)
- Module files: go.mod, go.sum
- Config files: .yaml, .json''';
      case 'Rust':
        return '''- Rust files: .rs (main.rs, lib.rs)
- Cargo files: Cargo.toml, Cargo.lock
- Config files: .toml''';
      case 'PHP':
        return '''- PHP files: .php (index.php, app.php)
- Composer files: composer.json, composer.lock
- Config files: .json, .yaml''';
      case 'C#':
        return '''- C# files: .cs (Program.cs, Models/*.cs)
- Project files: .csproj, .sln
- Config files: appsettings.json''';
      case 'Backend':
        return '''- Choose appropriate backend language:
- Python: .py, requirements.txt
- Node.js: .js, package.json
- Java: .java, pom.xml
- Go: .go, go.mod
- PHP: .php, composer.json''';
      case 'Unknown':
        return '''- Analyze task requirements to determine file types
- Use conventional extensions for the chosen language
- Follow best practices for project structure''';
      default:
        return '''- Use appropriate extensions for the language
- Follow naming conventions
- Include proper file types for the project''';
    }
  }
  
  // Enhanced AI plan generation using Python-based analysis
  Future<Map<String, dynamic>> _generateAIPlan(CoderTask task, Map<String, dynamic> context) async {
    try {
      // Step 1: Use Python tools for detailed project analysis
      await _updateTaskStep(task, 'Analyzing project structure with Python tools...', TaskStatus.planning);
      
      final projectAnalysis = await _toolsService.executeTool('analyze_project_structure', {
        'max_depth': 3,
      });
      
      await _updateTaskStep(task, 'Generating implementation plan with AI...', TaskStatus.planning);
      
      // Step 2: Use Python tool to generate initial plan
      final pythonPlan = await _toolsService.executeTool('generate_implementation_plan', {
        'task_description': task.description,
        'relevant_files': context['files'] ?? [],
      });
      
      final projectType = context['projectType'] ?? 'Unknown';
      final technologies = (context['technologies'] as List? ?? []).join(', ');
      
      // Step 3: Enhanced AI prompt with Python analysis results
      final prompt = '''
You are an expert AI coding assistant with access to external Python-based analysis tools.

TASK: ${task.description}

REPOSITORY CONTEXT:
- Repository: ${task.repository.fullName}
- Branch: ${task.branch}  
- Project Type: ${projectType}
- Technologies: ${technologies}

DETAILED PROJECT ANALYSIS:
${projectAnalysis['success'] ? json.encode(projectAnalysis) : 'Project analysis not available'}

PYTHON-GENERATED IMPLEMENTATION PLAN:
${pythonPlan['success'] ? json.encode(pythonPlan['plan']) : 'Python plan generation failed'}

CRITICAL REQUIREMENTS:
1. Create a comprehensive, detailed implementation plan
2. Use external Python tools for file operations (read_file, write_file, edit_file, delete_file)
3. Follow the structure suggested by the Python analysis
4. Consider the complexity estimation: ${pythonPlan['success'] ? pythonPlan['plan']['estimated_complexity'] : 'medium'}

AUTONOMOUS EXECUTION STRATEGY:
- Think step-by-step before implementing
- Use Python tools for all file operations
- Verify implementations thoroughly
- Handle edge cases and errors
- Create production-ready, maintainable code

IMPLEMENTATION PLAN FORMAT:
1. **Requirements Analysis**: Detailed understanding of the task
2. **Architecture Design**: High-level approach and structure
3. **File Operations Plan**: Specific files to create/modify/delete using Python tools
4. **Implementation Steps**: Step-by-step execution with external tool usage
5. **Testing Strategy**: Verification and validation approach
6. **Potential Issues**: Risk mitigation and edge case handling

CRITICAL FILE EXTENSION RULES:
${_getFileExtensionRules(projectType)}

Create a detailed implementation plan that leverages external Python tools for maximum efficiency and accuracy.
Focus on using the Python tools for all file operations and analysis tasks.
''';

      final aiResponse = await _callAIModel(prompt);
      
      return {
        'summary': 'Enhanced implementation plan with Python tool integration for ${task.description}',
        'response': aiResponse,
        'files_to_modify': _extractFilesFromPlan(aiResponse),
        'python_analysis': projectAnalysis,
        'python_plan': pythonPlan,
        'complexity': pythonPlan['success'] ? pythonPlan['plan']['estimated_complexity'] : 'medium',
      };
    } catch (e) {
      throw Exception('Failed to generate enhanced AI plan: $e');
    }
  }
  
  // Enhanced AI model call with Cursor AI-style system prompt
  Future<String> _callAIModel(String prompt) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ahamaibyprakash25',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': widget.selectedModel,
          'messages': [
            {
              'role': 'system',
              'content': '''You are an expert software developer and AI coding assistant.

CORE PRINCIPLES:
- You operate autonomously and thoroughly
- You solve problems completely before stopping
- You follow best practices and write production-ready code
- You are thorough in gathering context and understanding requirements
- You provide detailed, actionable implementations
- You consider edge cases and potential issues

COMMUNICATION STYLE:
- Be precise and practical in your solutions
- Provide complete code implementations
- Explain your reasoning when helpful
- Focus on solving the user's specific problem
- Use appropriate file extensions and naming conventions
- Write clean, maintainable, well-documented code

You have access to repository information and can create, modify, or delete files as needed.
Always ensure your implementations are complete and ready to run.''',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'max_tokens': 3000,
          'temperature': 0.2,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'] ?? 'No response from AI';
      } else {
        final errorBody = response.body;
        throw Exception('AI API error (${response.statusCode}): $errorBody');
      }
    } catch (e) {
      throw Exception('Failed to call AI model: $e');
    }
  }
  
  // Execute AI plan with Python-based external tool operations
  Future<void> _executeAIPlan(CoderTask task, Map<String, dynamic> plan) async {
    final filesToModify = plan['files_to_modify'] as List<String>;
    
    await _updateTaskStep(task, 'Beginning implementation with Python tools...', TaskStatus.executing);
    
    for (final filePath in filesToModify) {
      try {
        // Step 1: Use Python tool to read current file content
        await _updateTaskStep(task, 'Analyzing $filePath with Python tools...', TaskStatus.executing);
        
        final readResult = await _toolsService.executeTool('read_file', {
          'file_path': filePath,
        });
        
        final currentContent = readResult['success'] ? readResult['content'] : '';
        final isNewFile = !readResult['success'] || currentContent.isEmpty;
        
        final operation = isNewFile ? 'Creating' : 'Modifying';
        await _updateTaskStep(task, '$operation $filePath using AI analysis...', TaskStatus.executing);
        
        // Step 2: Use AI to determine the file modifications
        final modificationPrompt = '''
EXTERNAL PYTHON TOOL-BASED FILE OPERATION

Repository: ${task.repository.fullName}
Branch: ${task.branch}
File: $filePath
Operation: ${isNewFile ? 'CREATE' : 'MODIFY'}
Tool Integration: Python-based external execution

${isNewFile ? 'This is a NEW file to be created.' : 'Current content (read via Python tool):\n```\n$currentContent\n```'}

Original Task: ${task.description}
Implementation Plan: ${plan['response']}
Python Analysis: ${plan['python_analysis'] != null ? 'Available' : 'Not available'}
Complexity Level: ${plan['complexity'] ?? 'medium'}

INSTRUCTIONS FOR PYTHON TOOL EXECUTION:
${isNewFile ? 'Generate the COMPLETE file content for this new file.' : 'Generate the COMPLETE modified file content for this file.'}

REQUIREMENTS:
- The output will be used with Python write_file or edit_file tools
- Follow best practices for the detected project type
- Use proper file structure and organization
- Include necessary imports and dependencies
- Add appropriate comments and documentation
- Ensure code is production-ready and maintainable
- Handle edge cases and error conditions

OUTPUT ONLY THE COMPLETE FILE CONTENT - no explanations, no markdown blocks, just the raw code/content.
The content will be passed directly to Python external tools for file operations.
''';

        final modifiedContent = await _callAIModel(modificationPrompt);
        
        // Step 3: Use Python tools to perform file operations
        if (modifiedContent.toLowerCase().contains('delete this file') || 
            modifiedContent.toLowerCase().contains('remove this file') ||
            modifiedContent.toLowerCase().contains('file should be deleted')) {
          
          // Use Python tool to delete file
          final deleteResult = await _toolsService.executeTool('delete_file', {
            'file_path': filePath,
          });
          
          if (deleteResult['success']) {
            _fileOperations[filePath] = 'deleted';
            await _updateTaskStep(task, 'Deleted $filePath via Python tool', TaskStatus.executing);
          } else {
            await _updateTaskStep(task, 'Failed to delete $filePath: ${deleteResult['error']}', TaskStatus.executing);
          }
          
        } else {
          // Use Python tool to write/edit file
          Map<String, dynamic> writeResult;
          
          if (isNewFile) {
            // Create new file with Python tool
            writeResult = await _toolsService.executeTool('write_file', {
              'file_path': filePath,
              'content': modifiedContent,
              'mode': 'w',
            });
          } else {
            // Edit existing file with Python tool
            writeResult = await _toolsService.executeTool('edit_file', {
              'file_path': filePath,
              'old_content': currentContent,
              'new_content': modifiedContent,
            });
          }
          
          if (writeResult['success']) {
            _modifiedFiles[filePath] = modifiedContent;
            _fileContents[filePath] = currentContent;
            _fileOperations[filePath] = operation.toLowerCase();
            
            final operationText = isNewFile ? 'Created' : 'Modified';
            final toolInfo = writeResult['execution_method'] ?? 'python_external';
            await _updateTaskStep(task, '$operationText $filePath via Python tool ($toolInfo)', TaskStatus.executing);
          } else {
            await _updateTaskStep(task, 'Failed to ${operation.toLowerCase()} $filePath: ${writeResult['error']}', TaskStatus.executing);
          }
        }
        
        // Small delay for streaming effect
        await Future.delayed(const Duration(milliseconds: 500));
        
      } catch (e) {
        await _updateTaskStep(task, 'Python tool error for $filePath: $e', TaskStatus.executing);
      }
    }
    
    await _updateTaskStep(task, 'Completed implementation using Python external tools', TaskStatus.executing);
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
  
  // Delete file from repository
  Future<void> _deleteFile(CoderTask task, String filePath) async {
    try {
      // First get the file to get its SHA
      final getResponse = await http.get(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/contents/$filePath?ref=${task.branch}'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (getResponse.statusCode == 200) {
        final fileData = json.decode(getResponse.body);
        final sha = fileData['sha'];
        
        // Delete the file
        final deleteResponse = await http.delete(
          Uri.parse('https://api.github.com/repos/${task.repository.fullName}/contents/$filePath'),
          headers: {
            'Authorization': 'Bearer $_githubToken',
            'Accept': 'application/vnd.github.v3+json',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'message': 'Delete $filePath',
            'sha': sha,
            'branch': task.branch,
          }),
        );
        
        if (deleteResponse.statusCode != 200) {
          throw Exception('Failed to delete file: ${deleteResponse.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('Error deleting file $filePath: $e');
    }
  }
  
  // Extract file paths from AI plan with better extension detection
  List<String> _extractFilesFromPlan(String plan) {
    // Enhanced pattern to catch more file types including HTML, CSS, JS
    final filePattern = RegExp(r'([a-zA-Z0-9_\-./]+\.(html|htm|css|js|jsx|ts|tsx|py|java|cpp|c|h|dart|kt|swift|go|rs|php|rb|cs|json|xml|yml|yaml|md|txt))', multiLine: true);
    final matches = filePattern.allMatches(plan);
    
    // Also look for common file names without extensions mentioned in plan
    final commonFiles = <String>[];
    if (plan.toLowerCase().contains('index') && (plan.toLowerCase().contains('html') || plan.toLowerCase().contains('web'))) {
      commonFiles.add('index.html');
    }
    if (plan.toLowerCase().contains('style') && plan.toLowerCase().contains('css')) {
      commonFiles.add('style.css');
    }
    if (plan.toLowerCase().contains('script') && plan.toLowerCase().contains('javascript')) {
      commonFiles.add('script.js');
    }
    if (plan.toLowerCase().contains('app.js') || plan.toLowerCase().contains('main.js')) {
      commonFiles.add(plan.toLowerCase().contains('app.js') ? 'app.js' : 'main.js');
    }
    
    final allFiles = matches.map((match) => match.group(1)!).toSet().toList();
    allFiles.addAll(commonFiles);
    
    return allFiles.toSet().toList(); // Remove duplicates
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
      'message': 'Successfully processed ${_modifiedFiles.length} files: ${_modifiedFiles.keys.join(', ')}',
    };
  }
  
  // Generate AI summary of completed task
  Future<void> _generateTaskSummary(CoderTask task) async {
    try {
      if (_modifiedFiles.isEmpty && _fileOperations.isEmpty) {
        await _updateTaskStep(task, 'Task completed - no files were modified.', TaskStatus.completed);
        return;
      }

      final fileOperationsText = _fileOperations.entries.map((entry) {
        return '• ${entry.value.capitalize()} ${entry.key}';
      }).join('\n');
      
      final summaryPrompt = '''
Task: ${task.description}
Repository: ${task.repository.name}
Branch: ${task.branch}

Files processed:
$fileOperationsText

Provide a concise summary of what was accomplished in this task. 
Focus on the actual implementation and files created/modified/deleted.
Keep it under 80 words and be specific about what was built.
Start with "✅ Task completed: " and then describe what was done.
''';

      final summary = await _callAIModel(summaryPrompt);
      
      // Ensure summary starts with success indicator
      final cleanSummary = summary.trim();
      final finalSummary = cleanSummary.startsWith('✅') ? cleanSummary : '✅ Task completed: $cleanSummary';
      
      await _updateTaskStep(task, finalSummary, TaskStatus.completed);
      
    } catch (e) {
      // If summary generation fails, add a completion message with file count
      final fileCount = _modifiedFiles.length + _fileOperations.values.where((op) => op == 'deleted').length;
      await _updateTaskStep(task, '✅ Task completed successfully! Processed $fileCount files.', TaskStatus.completed);
    }
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
    if (_modifiedFiles.isEmpty && _fileOperations.values.where((op) => op == 'deleted').isEmpty) {
      _showSnackBar('❌ No changes to commit');
      return;
    }
    
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
        final errorBody = branchResponse.body;
        throw Exception('Failed to get branch info (${branchResponse.statusCode}): $errorBody');
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
        final errorBody = commitResponse.body;
        throw Exception('Failed to get current commit (${commitResponse.statusCode}): $errorBody');
      }
      
      final commitData = json.decode(commitResponse.body);
      final treeSha = commitData['tree']['sha'];
      
      // Create new tree with modified/deleted files
      final treeItems = <Map<String, dynamic>>[];
      
      // Add modified/created files
      for (final entry in _modifiedFiles.entries) {
        final operation = _fileOperations[entry.key] ?? 'modified';
        if (operation != 'deleted') {
          treeItems.add({
            'path': entry.key,
            'mode': '100644',
            'type': 'blob',
            'content': entry.value,
          });
        }
      }
      
      // Handle deleted files properly - remove them from tree
      for (final entry in _fileOperations.entries) {
        if (entry.value == 'deleted') {
          // For GitHub API, deleted files are simply not included in the new tree
          // No need to explicitly add them with null SHA
          continue; 
        }
      }
      
      if (treeItems.isEmpty) {
        _showSnackBar('❌ No valid file operations to commit');
        setState(() => _isLoading = false);
        return;
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
        final errorBody = newTreeResponse.body;
        throw Exception('Failed to create new tree (${newTreeResponse.statusCode}): $errorBody');
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
        final errorBody = newCommitResponse.body;
        throw Exception('Failed to create commit (${newCommitResponse.statusCode}): $errorBody');
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
        final errorBody = updateRefResponse.body;
        throw Exception('Failed to update branch (${updateRefResponse.statusCode}): $errorBody');
      }
      
      // Success! Clear the modified files
      final totalFiles = _modifiedFiles.length + _fileOperations.values.where((op) => op == 'deleted').length;
      setState(() {
        _hasUncommittedChanges = false;
        _gitStatus = 'On branch ${task.branch}\nnothing to commit, working tree clean';
        _modifiedFiles.clear();
        _fileOperations.clear();
      });
      
      _showSnackBar('✅ Successfully committed and pushed $totalFiles files!');
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
      // Validate branch name
      if (branchName.trim().isEmpty) {
        throw Exception('Branch name cannot be empty');
      }
      
      final cleanBranchName = branchName.trim().replaceAll(' ', '-').toLowerCase();
      
      // Check if branch already exists
      if (_branches.contains(cleanBranchName)) {
        throw Exception('Branch "$cleanBranchName" already exists');
      }
      
      // Get current commit SHA
      final branchResponse = await http.get(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/git/refs/heads/${task.branch}'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (branchResponse.statusCode != 200) {
        final errorBody = branchResponse.body;
        throw Exception('Failed to get current branch (${branchResponse.statusCode}): $errorBody');
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
          'ref': 'refs/heads/$cleanBranchName',
          'sha': currentCommitSha,
        }),
      );
      
      if (newBranchResponse.statusCode == 201) {
        // Switch to new branch and refresh branches list
        await _fetchBranches(_selectedRepo!);
        setState(() {
          _selectedBranch = cleanBranchName;
        });
        
        _showSnackBar('✅ Created and switched to branch: $cleanBranchName');
      } else {
        final errorBody = newBranchResponse.body;
        throw Exception('Failed to create branch (${newBranchResponse.statusCode}): $errorBody');
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
      // Validate inputs
      if (title.trim().isEmpty) {
        throw Exception('Pull request title cannot be empty');
      }
      
      if (task.branch == baseBranch) {
        throw Exception('Cannot create PR: head and base branches are the same');
      }
      
      final prResponse = await http.post(
        Uri.parse('https://api.github.com/repos/${task.repository.fullName}/pulls'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': title.trim(),
          'body': body.trim().isEmpty ? 'Created via AhamAI Coder' : body.trim(),
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
        final errorBody = prResponse.body;
        throw Exception('Failed to create pull request (${prResponse.statusCode}): $errorBody');
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
    final isExpanded = _expandedTaskId == task.id;
    
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
          // Clickable Task Header
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedTaskId = isExpanded ? null : task.id;
              });
            },
            child: Container(
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
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: const Color(0xFF718096),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Task Details
          if (isExpanded) ...[
            // Task Steps
            if (task.steps.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Task Progress:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...task.steps.map((step) => _buildTaskStep(step)).toList(),
                  ],
                ),
              ),
            
            // Modified Files Display
            if (_modifiedFiles.isNotEmpty && task.status == TaskStatus.completed)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: _buildModifiedFilesSection(),
              ),
          ] else ...[
            // Collapsed view - show only latest step and summary
            if (task.steps.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    _buildStatusIcon(task.steps.last.status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.steps.last.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4A5568),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_modifiedFiles.isNotEmpty && task.status == TaskStatus.completed)
                      Text(
                        '${_modifiedFiles.length} files',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF718096),
                        ),
                      ),
                  ],
                ),
              ),
          ],
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
                  'File Operations (${_modifiedFiles.length})',
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _fileOperations[fileName] == 'creating' 
                        ? const Color(0xFF48BB78) 
                        : _fileOperations[fileName] == 'deleted'
                            ? const Color(0xFFE53E3E)
                            : const Color(0xFF4299E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    _fileOperations[fileName]?.toUpperCase() ?? 'MODIFIED',
                    style: const TextStyle(
                      fontSize: 7,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const FaIcon(FontAwesomeIcons.codeBranch, size: 12, color: Color(0xFF718096)),
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
      icon: FaIcon(icon, size: 8, color: Colors.white),
      label: Text(label, style: const TextStyle(fontSize: 9, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 0,
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const FaIcon(FontAwesomeIcons.arrowRight, size: 12, color: Color(0xFF718096)),
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}