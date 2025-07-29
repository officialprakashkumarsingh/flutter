import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _llmService.addListener(_onLLMServiceChanged);
    _scanForLLMs();
  }

  @override
  void dispose() {
    _llmService.removeListener(_onLLMServiceChanged);
    _nameController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  void _onLLMServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _scanForLLMs() async {
    await _llmService.scanForAvailableLLMs();
  }

  void _showAddCustomLLMDialog() {
    _nameController.clear();
    _endpointController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF4F3F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Custom LLM',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'My Custom LLM',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _endpointController,
              decoration: InputDecoration(
                labelText: 'Endpoint URL',
                hintText: 'http://localhost:8080',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: const Color(0xFFA3A3A3)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty && 
                  _endpointController.text.isNotEmpty) {
                _llmService.addCustomLLM(
                  _nameController.text,
                  _endpointController.text,
                );
                Navigator.pop(context);
                _scanForLLMs();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _selectLLM(LocalLLM llm) {
    _llmService.selectLLM(llm);
    Navigator.pop(context, llm);
  }

  Widget _buildLLMCard(LocalLLM llm) {
    final isSelected = _llmService.selectedLLM?.id == llm.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEAE9E5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: const Color(0xFF000000), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: llm.isAvailable ? () => _selectLLM(llm) : null,
          borderRadius: BorderRadius.circular(16),
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
                        color: llm.isAvailable 
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFFF87171).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        llm.isAvailable ? Icons.computer : Icons.error_outline,
                        color: llm.isAvailable 
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF87171),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            llm.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF000000),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            llm.description,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFFA3A3A3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: const Color(0xFF000000),
                        size: 24,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F3F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 16,
                        color: const Color(0xFFA3A3A3),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          llm.endpoint,
                          style: GoogleFonts.robotoMono(
                            fontSize: 12,
                            color: const Color(0xFF000000),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: llm.isAvailable 
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF87171),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        llm.isAvailable ? 'Available' : 'Offline',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (llm.id.startsWith('custom_'))
                      IconButton(
                        onPressed: () {
                          _llmService.removeLLM(llm.id);
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFF87171),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
             icon: const Icon(
               Icons.explore_rounded,
               color: Color(0xFF000000),
             ),
           ),
           IconButton(
             onPressed: _llmService.isScanning ? null : _scanForLLMs,
             icon: _llmService.isScanning
                 ? const SizedBox(
                     width: 20,
                     height: 20,
                     child: CircularProgressIndicator(
                       strokeWidth: 2,
                       color: Color(0xFF000000),
                     ),
                   )
                 : const Icon(
                     Icons.refresh_rounded,
                     color: Color(0xFF000000),
                   ),
           ),
           IconButton(
             onPressed: _showAddCustomLLMDialog,
             icon: const Icon(
               Icons.add_rounded,
               color: Color(0xFF000000),
             ),
           ),
           const SizedBox(width: 8),
         ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Local LLMs',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF000000),
                  ),
                ),
                const SizedBox(height: 8),
                                 Text(
                   'Connect to locally running AI models like Ollama, LM Studio, and more.',
                   style: GoogleFonts.inter(
                     fontSize: 16,
                     color: const Color(0xFFA3A3A3),
                   ),
                 ),
                 const SizedBox(height: 16),
                 ElevatedButton.icon(
                   onPressed: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => const ModelBrowserPage(),
                       ),
                     );
                   },
                   icon: const Icon(Icons.explore_rounded, size: 20),
                   label: const Text('Browse & Download Models'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF3B82F6),
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(12),
                     ),
                   ),
                 ),
              ],
            ),
          ),
          Expanded(
            child: _llmService.localLLMs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.computer_outlined,
                          size: 64,
                          color: const Color(0xFFA3A3A3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Local LLMs Found',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFA3A3A3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Make sure your local LLM server is running',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFFA3A3A3),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _llmService.localLLMs.length,
                    itemBuilder: (context, index) {
                      final llm = _llmService.localLLMs[index];
                      return _buildLLMCard(llm);
                    },
                  ),
          ),
          if (_llmService.selectedLLM != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Connected to ${_llmService.selectedLLM!.name}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF000000),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _llmService.selectedLLM),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF000000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Use Selected'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}