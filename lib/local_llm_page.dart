import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'local_llm_service.dart';
import 'model_browser_page.dart';

class LocalLLMPage extends StatefulWidget {
  const LocalLLMPage({super.key});

  @override
  State<LocalLLMPage> createState() => _LocalLLMPageState();
}

class _LocalLLMPageState extends State<LocalLLMPage> {
  @override
  void initState() {
    super.initState();
    // Refresh connection status when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalLLMService>().refreshConnection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local AI Models'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<LocalLLMService>().refreshConnection();
            },
            tooltip: 'Refresh connection',
          ),
        ],
      ),
      body: Consumer<LocalLLMService>(
        builder: (context, llmService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOllamaStatusCard(llmService),
                const SizedBox(height: 20),
                _buildHeaderSection(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 20),
                _buildDownloadedModels(llmService),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOllamaStatusCard(LocalLLMService llmService) {
    final isConnected = llmService.isOllamaConnected;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ollama Server Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        llmService.ollamaStatus,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isConnected ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isConnected)
                  TextButton.icon(
                    onPressed: () => _showOllamaInstructions(context),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Help'),
                  ),
              ],
            ),
            if (!isConnected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To use local AI models, you need Ollama running:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Install Ollama from ollama.ai\n2. Start Ollama server\n3. Tap refresh above',
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.deepPurple, Colors.purple],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Local AI Models',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Run AI models locally on your device with complete privacy',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.download,
                    label: 'Browse Models',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModelBrowserPage(),
                        ),
                      );
                    },
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Consumer<LocalLLMService>(
                    builder: (context, llmService, child) {
                      return _buildActionButton(
                        icon: Icons.info_outline,
                        label: 'Running Models',
                        onPressed: llmService.isOllamaConnected
                            ? () => _showRunningModels(context, llmService)
                            : null,
                        color: Colors.green,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadedModels(LocalLLMService llmService) {
    final downloadedModels = llmService.availableModels
        .where((model) => model['isDownloaded'] as bool)
        .toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Downloaded Models',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (downloadedModels.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_download_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No models downloaded yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse and download models to get started',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else
              ...downloadedModels.map((model) => _buildModelCard(model, llmService)),
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(Map<String, dynamic> model, LocalLLMService llmService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.memory,
              color: Colors.deepPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  model['description'] as String,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${model['size']} • ${model['source']}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: llmService.isOllamaConnected
                ? () => _startChat(model)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Chat'),
          ),
        ],
      ),
    );
  }

  void _startChat(Map<String, dynamic> model) {
    Navigator.pushNamed(
      context,
      '/local_llm_chat',
      arguments: {
        'modelId': model['id'],
        'modelName': model['name'],
      },
    );
  }

  void _showOllamaInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setup Ollama'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To use local AI models, you need to install and run Ollama:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 16),
              Text('1. Visit ollama.ai and download Ollama for your system'),
              SizedBox(height: 8),
              Text('2. Install and start the Ollama application'),
              SizedBox(height: 8),
              Text('3. Ollama will run on http://localhost:11434'),
              SizedBox(height: 8),
              Text('4. Return here and tap the refresh button'),
              SizedBox(height: 16),
              Text(
                'Note: Ollama must be running for local AI features to work.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showRunningModels(BuildContext context, LocalLLMService llmService) async {
    final runningModels = await llmService.getRunningModels();
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Running Models'),
        content: SizedBox(
          width: double.maxFinite,
          child: runningModels.isEmpty
              ? const Text('No models are currently running.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: runningModels.length,
                  itemBuilder: (context, index) {
                    final model = runningModels[index];
                    return ListTile(
                      leading: const Icon(Icons.memory),
                      title: Text(model['model'] as String),
                      subtitle: Text('Size: ${(model['size'] as int) ~/ (1024 * 1024)} MB'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}