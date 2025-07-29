import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DiagramSaveWidget extends StatefulWidget {
  final String imageUrl;
  final String? diagramType;
  final String? customLabel;

  const DiagramSaveWidget({
    super.key,
    required this.imageUrl,
    this.diagramType,
    this.customLabel,
  });

  @override
  State<DiagramSaveWidget> createState() => _DiagramSaveWidgetState();
}

class _DiagramSaveWidgetState extends State<DiagramSaveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getDefaultLabel() {
    switch (widget.diagramType?.toLowerCase()) {
      case 'generated_image':
        return 'Save Image';
      case 'plantuml':
        return 'Save Diagram';
      default:
        return 'Save File';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: GestureDetector(
                  onTapDown: (_) => _animationController.forward(),
                  onTapUp: (_) => _animationController.reverse(),
                  onTapCancel: () => _animationController.reverse(),
                  onTap: _isSaving ? null : _saveDiagram,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6366F1),
                          const Color(0xFF8B5CF6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSaving)
                          Container(
                            width: 14,
                            height: 14,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          const FaIcon(
                            FontAwesomeIcons.download,
                            size: 14,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _isSaving ? 'Saving...' : (widget.customLabel ?? _getDefaultLabel()),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveDiagram() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Check and request storage permission for Android
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), we need different permissions
        PermissionStatus status;
        
        // Try storage permission first
        status = await Permission.storage.request();
        
        // If storage permission is denied, try media permissions for newer Android
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        
        // If still denied, try photos permission as fallback
        if (!status.isGranted) {
          status = await Permission.photos.request();
        }
        
        if (!status.isGranted) {
          _showSnackBar('Storage permission is required to save images. Please enable in Settings.', isError: true);
          // Try to open app settings
          await openAppSettings();
          return;
        }
      }

      // Extract base64 data from data URL
      if (!widget.imageUrl.startsWith('data:image/')) {
        _showSnackBar('Invalid image format', isError: true);
        return;
      }

      final base64Data = widget.imageUrl.split(',')[1];
      final imageBytes = base64Decode(base64Data);

      // Get the appropriate directory and create AhamAI folder
      Directory? directory;
      if (Platform.isAndroid) {
        // Try Downloads folder first
        directory = Directory('/storage/emulated/0/Download/AhamAI');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        
        // Fallback to external storage if Downloads not accessible
        if (!await directory.exists()) {
          final extStorage = await getExternalStorageDirectory();
          if (extStorage != null) {
            directory = Directory('${extStorage.path}/AhamAI');
            await directory.create(recursive: true);
          }
        }
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        directory = Directory('${docDir.path}/AhamAI');
        await directory.create(recursive: true);
      }

      if (directory == null || !await directory.exists()) {
        _showSnackBar('Could not create AhamAI folder', isError: true);
        return;
      }

      // Create filename with timestamp and proper type
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileType = widget.diagramType ?? 'file';
      final extension = widget.imageUrl.contains('svg') ? 'svg' : 
                       widget.imageUrl.contains('jpeg') ? 'jpg' : 'png';
      final filename = 'aham_${fileType}_$timestamp.$extension';
      final filePath = '${directory.path}/$filename';

      // Write the file
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      // Show success message with AhamAI folder
      final fileName = file.path.split('/').last;
      _showSnackBar('Saved to AhamAI folder: $fileName', isError: false);

      // Add haptic feedback
      HapticFeedback.lightImpact();

    } catch (e) {
      _showSnackBar('Failed to save diagram: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(
              isError ? FontAwesomeIcons.exclamationTriangle : FontAwesomeIcons.checkCircle,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}