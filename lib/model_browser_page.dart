import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'local_llm_service.dart';

class ModelBrowserPage extends StatefulWidget {
  const ModelBrowserPage({super.key});

  @override
  State<ModelBrowserPage> createState() => _ModelBrowserPageState();
}

class _ModelBrowserPageState extends State<ModelBrowserPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalLLMService>().refreshConnection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse AI Models'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<LocalLLMService>().refreshConnection();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<LocalLLMService>(
        builder: (context, llmService, child) {
          if (!llmService.isOllamaConnected) {
            return _buildOllamaNotConnectedView(llmService);
          }

          return Column(
            children: [
              if (llmService.downloadProgress.isNotEmpty)
                _buildDownloadProgress(llmService.downloadProgress),
              Expanded(
                child: _buildModelList(llmService),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOllamaNotConnectedView(LocalLLMService llmService) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Ollama Not Connected',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              llmService.ollamaStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showOllamaInstructions(),
              icon: const Icon(Icons.help_outline),
              label: const Text('Setup Instructions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => llmService.refreshConnection(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadProgress(String progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              progress,
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList(LocalLLMService llmService) {
    final models = llmService.availableModels;
    
    if (models.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        return _buildModelCard(model, llmService);
      },
    );
  }

  Widget _buildModelCard(Map<String, dynamic> model, LocalLLMService llmService) {
    final isDownloaded = model['isDownloaded'] as bool;
    final isInstalling = model['isInstalling'] as bool? ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getModelColor(model['family'] as String).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getModelIcon(model['family'] as String),
                    color: _getModelColor(model['family'] as String),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
                    ],
                  ),
                ),
                if (isDownloaded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Downloaded',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.source,
                  label: model['source'] as String,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.storage,
                  label: model['size'] as String,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (isDownloaded) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startChat(model),
                      icon: const Icon(Icons.chat),
                      label: const Text('Chat Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isInstalling ? null : () => _deleteModel(model, llmService),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      foregroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Icon(Icons.delete),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isInstalling ? null : () => _downloadModel(model, llmService),
                      icon: isInstalling 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(isInstalling ? 'Installing...' : 'Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getModelColor(String family) {
    switch (family) {
      case 'llama':
        return Colors.purple;
      case 'gemma':
        return Colors.blue;
      case 'phi':
        return Colors.orange;
      case 'qwen':
        return Colors.green;
      case 'mistral':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getModelIcon(String family) {
    switch (family) {
      case 'llama':
        return Icons.psychology;
      case 'gemma':
        return Icons.diamond;
      case 'phi':
        return Icons.scatter_plot;
      case 'qwen':
        return Icons.translate;
      case 'mistral':
        return Icons.wind_power;
      default:
        return Icons.memory;
    }
  }

  void _downloadModel(Map<String, dynamic> model, LocalLLMService llmService) async {
    try {
      await llmService.downloadModel(model['id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model['name']} downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download ${model['name']}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteModel(Map<String, dynamic> model, LocalLLMService llmService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete ${model['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await llmService.deleteModel(model['id'] as String);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${model['name']} deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete ${model['name']}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

  void _showOllamaInstructions() {
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
                'To download and use local AI models, you need Ollama:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 16),
              Text('1. Visit ollama.ai and download Ollama'),
              SizedBox(height: 8),
              Text('2. Install and start the Ollama application'),
              SizedBox(height: 8),
              Text('3. Ollama will run on http://localhost:11434'),
              SizedBox(height: 8),
              Text('4. Return here and tap the refresh button'),
              SizedBox(height: 16),
              Text(
                'Once connected, you can download and chat with various AI models including Llama, Gemma, Phi, and more.',
                style: TextStyle(fontStyle: FontStyle.italic),
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
}