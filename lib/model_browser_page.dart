import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'local_llm_service.dart';
import 'hosted_model_chat_page.dart';

class ModelBrowserPage extends StatefulWidget {
  const ModelBrowserPage({super.key});

  @override
  State<ModelBrowserPage> createState() => _ModelBrowserPageState();
}

class _ModelBrowserPageState extends State<ModelBrowserPage> with TickerProviderStateMixin {
  final LocalLLMService _llmService = LocalLLMService();
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _llmService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _llmService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshModels() async {
    await _llmService.refreshModels();
  }

  Future<void> _downloadModel(LocalLLMModel model) async {
    try {
      await _llmService.downloadModel(model.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${model.name} downloaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteModel(LocalLLMModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete ${model.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _llmService.deleteModel(model.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.name} deleted successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildModelCard(LocalLLMModel model) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getSourceColor(model.source).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getSourceIcon(model.source),
                    color: _getSourceColor(model.source),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF000000),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getSourceColor(model.source),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              model.source,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            model.size,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFA3A3A3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            model.format,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFA3A3A3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (model.isDownloaded)
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  )
                else if (_llmService.isDownloading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (model.source == 'Google Gemma' && model.isDownloaded)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _chatWithGemmaModel(model),
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('Chat Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else if (model.source == 'Google Gemma' && !model.isDownloaded)
                  Expanded(
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _llmService.isDownloading ? null : () => _downloadModel(model),
                          icon: _llmService.isDownloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download, size: 16),
                          label: Text(_llmService.isDownloading ? 'Downloading...' : 'Download'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (_llmService.isDownloading && _llmService.downloadProgress.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _llmService.downloadProgress,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFFA3A3A3),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  )
                else if (!model.isDownloaded && model.source != 'Local Directory')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _llmService.isDownloading ? null : () => _downloadModel(model),
                      icon: const Icon(Icons.download, size: 16),
                      label: Text(_llmService.isDownloading ? 'Downloading...' : 'Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getSourceColor(model.source),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else if (model.isDownloaded)
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteModel(model),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Use this model
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Using ${model.name}')),
                              );
                            },
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text('Use'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _chatWithGemmaModel(LocalLLMModel model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostedModelChatPage(
          modelId: model.id,
          modelName: model.name,
        ),
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'Google Gemma':
        return const Color(0xFF4285F4);
      case 'Ollama Library':
        return const Color(0xFF3B82F6);
      case 'Hugging Face':
        return const Color(0xFFEF4444);
      case 'Local Directory':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'Google Gemma':
        return Icons.auto_awesome;
      case 'Ollama Library':
        return Icons.local_library;
      case 'Hugging Face':
        return Icons.cloud_download;
      case 'Local Directory':
        return Icons.folder;
      default:
        return Icons.smart_toy;
    }
  }

  Widget _buildTabContent(String source) {
    final models = _llmService.getModelsBySource(source);
    
    if (models.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getSourceIcon(source),
              size: 64,
              color: const Color(0xFFA3A3A3),
            ),
            const SizedBox(height: 16),
            Text(
              'No models from $source',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFA3A3A3),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection or refresh',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFA3A3A3),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: models.length,
      itemBuilder: (context, index) {
        return _buildModelCard(models[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadedCount = _llmService.getDownloadedModels().length;
    final availableCount = _llmService.availableModels.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F3F0),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color(0xFF000000),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Model Browser',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF000000),
              ),
            ),
            Text(
              '$downloadedCount downloaded • $availableCount available',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFA3A3A3),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refreshModels,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF000000),
          unselectedLabelColor: const Color(0xFFA3A3A3),
          indicatorColor: const Color(0xFF000000),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
                      tabs: const [
              Tab(text: 'Google Gemma'),
              Tab(text: 'Local'),
            ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Google Gemma models
          _buildTabContent('Google Gemma'),
          _buildTabContent('Local Directory'),
        ],
      ),
    );
  }
}