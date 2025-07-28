import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'file_upload_service.dart';
import 'file_viewer_page.dart';

class FileUploadWidget extends StatefulWidget {
  final Function(String)? onFilesUploaded;
  
  const FileUploadWidget({
    super.key,
    this.onFilesUploaded,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  final FileUploadService _fileService = FileUploadService();
  bool _isUploading = false;

  void _showUploadBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFFF4F3F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFC4C4C4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_rounded, color: Color(0xFF000000), size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Attach Files',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    const Spacer(),
                    if (_fileService.uploadedFiles.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _fileService.clearAllFiles();
                          });
                          setState(() {});
                        },
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFA3A3A3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFFA3A3A3)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Upload options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildUploadButton(
                        context: context,
                        icon: Icons.folder_zip_rounded,
                        label: 'Upload ZIP',
                        subtitle: 'Extract and upload all files',
                        color: const Color(0xFF000000),
                        onTap: () => _uploadZipFile(setModalState),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildUploadButton(
                        context: context,
                        icon: Icons.upload_file_rounded,
                        label: 'Upload Files',
                        subtitle: 'Select individual files',
                        color: const Color(0xFF000000),
                        onTap: () => _uploadIndividualFiles(setModalState),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF000000)),
                      const SizedBox(height: 12),
                      Text(
                        'Uploading files...',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFA3A3A3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Uploaded files list
              if (_fileService.uploadedFiles.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Uploaded Files (${_fileService.uploadedFiles.length})',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF000000),
                        ),
                      ),
                      const Spacer(),
                      if (_fileService.uploadedFiles.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF000000),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextButton(
                            onPressed: () {
                              final content = _fileService.getAllContentForAI();
                              widget.onFilesUploaded?.call(content);
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Send to AI',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _fileService.uploadedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _fileService.uploadedFiles[index];
                      return _buildFileItem(file, setModalState);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAE9E5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC4C4C4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFA3A3A3),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(UploadedFile file, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC4C4C4)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF000000).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            file.type.icon,
            color: const Color(0xFF000000),
            size: 20,
          ),
        ),
        title: Text(
          file.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: const Color(0xFF000000),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${file.type.name} • ${_formatFileSize(file.bytes.length)}',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFFA3A3A3),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FileViewerPage(file: file),
                  ),
                );
              },
              icon: const Icon(Icons.visibility_rounded, size: 20),
              color: const Color(0xFF000000),
            ),
            IconButton(
              onPressed: () {
                setModalState(() {
                  _fileService.removeFile(file);
                });
                setState(() {});
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: const Color(0xFFA3A3A3),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadZipFile(StateSetter setModalState) async {
    setModalState(() => _isUploading = true);
    
    try {
      final files = await _fileService.uploadZipFile();
      if (files.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded ${files.length} files'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error uploading ZIP file'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setModalState(() => _isUploading = false);
      setState(() {});
    }
  }

  Future<void> _uploadIndividualFiles(StateSetter setModalState) async {
    setModalState(() => _isUploading = true);
    
    try {
      final files = await _fileService.uploadIndividualFiles();
      if (files.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded ${files.length} files'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error uploading files'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setModalState(() => _isUploading = false);
      setState(() {});
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showUploadBottomSheet(context),
      icon: Stack(
        children: [
          const Icon(Icons.attachment, size: 20),
          if (_fileService.uploadedFiles.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      color: Colors.grey.shade600,
    );
  }
}