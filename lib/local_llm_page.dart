import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'local_llm_service.dart';
import 'model_browser_page.dart';

class LocalLLMPage extends StatefulWidget {
  const LocalLLMPage({super.key});

  @override
  State<LocalLLMPage> createState() => _LocalLLMPageState();
}

class _LocalLLMPageState extends State<LocalLLMPage> {
  final LocalLLMService _llmService = LocalLLMService();

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _llmService.initializeService();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'Local LLMs',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModelBrowserPage(),
                ),
              );
            },
            icon: const FaIcon(
              FontAwesomeIcons.compass,
              color: Color(0xFF000000),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: _llmService,
        builder: (context, child) {
          final downloadedModels = _llmService.availableModels.where((m) => m.isDownloaded).toList();
          final availableModels = _llmService.availableModels.where((m) => !m.isDownloaded).toList();
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.smart_toy,
                        size: 48,
                        color: const Color(0xFF4285F4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Google Gemma AI',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF000000),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Run AI models locally on your device for complete privacy and offline capabilities',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFFA3A3A3),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ModelBrowserPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Browse & Download Models'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Downloaded Models Section
                if (downloadedModels.isNotEmpty) ...[
                  Text(
                    'Downloaded Models',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...downloadedModels.map((model) => _buildModelCard(model, true)),
                  const SizedBox(height: 24),
                ],
                
                // Available Models Section
                if (availableModels.isNotEmpty) ...[
                  Text(
                    'Available Models',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...availableModels.take(3).map((model) => _buildModelCard(model, false)),
                  
                  if (availableModels.length > 3) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ModelBrowserPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility),
                        label: Text('View All ${availableModels.length} Models'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4285F4),
                        ),
                      ),
                    ),
                  ],
                ],
                
                // Empty State
                if (downloadedModels.isEmpty && availableModels.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_download,
                          size: 64,
                          color: const Color(0xFFA3A3A3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Models Available',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFA3A3A3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check your internet connection and try refreshing',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFFA3A3A3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModelCard(LocalLLMModel model, bool isDownloaded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDownloaded ? Border.all(color: const Color(0xFF10B981), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.smart_toy,
                  color: const Color(0xFF4285F4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
                    ),
                    Text(
                      model.metadata['description'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFA3A3A3),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isDownloaded)
                Icon(
                  Icons.check_circle,
                  color: const Color(0xFF10B981),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
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
    );
  }
}