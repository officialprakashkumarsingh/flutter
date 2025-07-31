import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'file_attachment_service.dart';

class FileAttachmentWidget extends StatefulWidget {
  final List<FileAttachment> attachments;
  final bool isFromUser;

  const FileAttachmentWidget({
    super.key,
    required this.attachments,
    this.isFromUser = true,
  });

  @override
  State<FileAttachmentWidget> createState() => _FileAttachmentWidgetState();
}

class _FileAttachmentWidgetState extends State<FileAttachmentWidget>
    with TickerProviderStateMixin {
  final Map<String, bool> _expandedStates = {};
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    for (final attachment in widget.attachments) {
      _expandedStates[attachment.id] = false;
      
      final controller = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      _animationControllers[attachment.id] = controller;
      _animations[attachment.id] = CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleExpansion(String attachmentId) {
    setState(() {
      _expandedStates[attachmentId] = !_expandedStates[attachmentId]!;
      if (_expandedStates[attachmentId]!) {
        _animationControllers[attachmentId]?.forward();
      } else {
        _animationControllers[attachmentId]?.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.attachments.map((attachment) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: _buildAttachmentCard(attachment),
        );
      }).toList(),
    );
  }

  Widget _buildAttachmentCard(FileAttachment attachment) {
    final isExpanded = _expandedStates[attachment.id] ?? false;
    final canPreview = attachment.isText || attachment.isCode || attachment.isImage || attachment.isZip;

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: canPreview ? () => _toggleExpansion(attachment.id) : null,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getFileColor(attachment),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        attachment.fileIcon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              FileAttachmentService.getFileTypeDescription(attachment),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${attachment.sizeFormatted}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (attachment.textContent != null) ...[
                        GestureDetector(
                          onTap: () => _copyContent(attachment),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const FaIcon(
                              FontAwesomeIcons.copy,
                              size: 12,
                              color: Color(0xFFE6E6E6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      if (canPreview) ...[
                        AnimatedRotation(
                          turns: isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (canPreview) ...[
            SizeTransition(
              sizeFactor: _animations[attachment.id] ?? const AlwaysStoppedAnimation(0),
              axisAlignment: -1,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                child: _buildPreviewContent(attachment),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewContent(FileAttachment attachment) {
    if (attachment.isImage) {
      return _buildImagePreview(attachment);
    } else if (attachment.isZip && attachment.extractedFiles != null) {
      return _buildZipPreview(attachment);
    } else if (attachment.textContent != null) {
      return _buildTextPreview(attachment);
    }
    return const SizedBox.shrink();
  }

  Widget _buildImagePreview(FileAttachment attachment) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          attachment.bytes!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 100,
              color: const Color(0xFFF0F0F0),
              child: const Center(
                child: Text('Failed to load image'),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildZipPreview(FileAttachment attachment) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Archive Contents (${attachment.extractedFiles!.length} files):',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          ...attachment.extractedFiles!.map((file) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: null,
            child: Row(
              children: [
                Text(
                  file.fileIcon,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      Text(
                        file.sizeFormatted,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildTextPreview(FileAttachment attachment) {
    if (attachment.textContent == null) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: attachment.isCode
            ? Container(
                padding: const EdgeInsets.all(16),
                child: HighlightView(
                  attachment.textContent!,
                  language: FileAttachmentService.getCodeLanguage(attachment),
                  theme: vs2015Theme,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'JetBrains Mono',
                    height: 1.4,
                    color: Color(0xFFE6E6E6),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  attachment.textContent!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
      ),
    );
  }

  Color _getFileColor(FileAttachment attachment) {
    return Colors.transparent;
  }

  void _copyContent(FileAttachment attachment) {
    if (attachment.textContent != null) {
      Clipboard.setData(ClipboardData(text: attachment.textContent!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${attachment.name} copied to clipboard!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class SimpleFileAttachmentWidget extends StatelessWidget {
  final List<FileAttachment> attachments;
  final bool isFromUser;

  const SimpleFileAttachmentWidget({
    super.key,
    required this.attachments,
    this.isFromUser = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((attachment) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                attachment.fileIcon,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 6),
              Text(
                attachment.name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                attachment.sizeFormatted,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF666666),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
