import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'image_generation_service.dart';

class ImageGenerationDialog extends StatefulWidget {
  const ImageGenerationDialog({Key? key}) : super(key: key);

  @override
  State<ImageGenerationDialog> createState() => _ImageGenerationDialogState();
}

class _ImageGenerationDialogState extends State<ImageGenerationDialog> {
  final TextEditingController _promptController = TextEditingController();
  String _selectedModel = 'flux';
  bool _isGenerating = false;
  bool _enhance = false;
  Map<String, dynamic>? _generatedImage;
  List<String> _availableModels = ['flux', 'turbo'];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    final result = await ImageGenerationService.getImageModels();
    if (mounted) {
      setState(() {
        _availableModels = List<String>.from(result['models'] ?? ['flux', 'turbo']);
        if (!_availableModels.contains(_selectedModel)) {
          _selectedModel = _availableModels.first;
        }
      });
    }
  }

  Future<void> _generateImage() async {
    if (_promptController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please enter a prompt';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _generatedImage = null;
    });

    final result = await ImageGenerationService.generateImage(
      prompt: _promptController.text.trim(),
      model: _selectedModel,
      enhance: _enhance,
    );

    if (mounted) {
      setState(() {
        _isGenerating = false;
        if (result['success']) {
          _generatedImage = result;
          _error = null;
        } else {
          _error = result['error'];
          _generatedImage = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.paintBrush,
                  color: Color(0xFF2D3748),
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(
                  'Generate Image',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Color(0xFF718096)),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Prompt Input
            Text(
              'Prompt',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _promptController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe the image you want to generate...',
                  hintStyle: TextStyle(color: Color(0xFFA0AEC0)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
                style: TextStyle(color: Color(0xFF2D3748)),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Model Selection and Options
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Model',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedModel,
                          isExpanded: true,
                          underline: SizedBox(),
                          onChanged: (value) {
                            setState(() {
                              _selectedModel = value!;
                            });
                          },
                          items: _availableModels.map((model) {
                            return DropdownMenuItem(
                              value: model,
                              child: Text(
                                model.toUpperCase(),
                                style: TextStyle(color: Color(0xFF2D3748)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Options',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _enhance,
                            onChanged: (value) {
                              setState(() {
                                _enhance = value ?? false;
                              });
                            },
                            activeColor: Color(0xFF2D3748),
                          ),
                          Text(
                            'Enhance prompt',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2D3748),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isGenerating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Generating...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(FontAwesomeIcons.magic, size: 16),
                          SizedBox(width: 8),
                          Text('Generate Image'),
                        ],
                      ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Error or Result
            if (_error != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Generated Image
            if (_generatedImage != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generated Image',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _generatedImage!['image_bytes'],
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Model: ${_generatedImage!['model'].toString().toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF718096),
                          ),
                        ),
                        Spacer(),
                        Text(
                          'Size: ${_generatedImage!['size_kb']}KB',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}