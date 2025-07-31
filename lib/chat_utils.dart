import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'file_attachment_service.dart';
import 'models.dart';

/* ----------------------------------------------------------
   CHAT UTILITIES - Helper Functions for Chat Operations
---------------------------------------------------------- */
class ChatUtils {
  
  /// Extract all file contents and prepare them for AI processing
  static String prepareAttachmentsForAI(List<FileAttachment> attachments) {
    if (attachments.isEmpty) return '';
    
    final StringBuffer aiContent = StringBuffer();
    
    for (final attachment in attachments) {
      aiContent.writeln('\n--- ${FileAttachmentService.getFileTypeDescription(attachment)}: ${attachment.name} ---');
      
      if (attachment.isPdf) {
        // PDF text content already extracted
        aiContent.writeln(attachment.textContent ?? 'PDF content could not be extracted');
      } else if (attachment.isText || attachment.isCode) {
        // Text/Code files
        aiContent.writeln(attachment.textContent ?? 'File content could not be read');
      } else if (attachment.isImage) {
        // Image files - describe for AI
        aiContent.writeln('[IMAGE ATTACHMENT: ${attachment.name} - ${attachment.sizeFormatted}]');
        aiContent.writeln('User has uploaded an image file. Please use your vision capabilities to analyze this image.');
      } else if (attachment.isZip && attachment.extractedFiles != null) {
        // ZIP files - include extracted content
        aiContent.writeln('Archive containing ${attachment.extractedFiles!.length} files:');
        for (final extractedFile in attachment.extractedFiles!) {
          aiContent.writeln('\n  File: ${extractedFile.name}');
          if (extractedFile.textContent != null) {
            aiContent.writeln('  Content:');
            aiContent.writeln('  ${extractedFile.textContent}');
          }
        }
      } else {
        // Other file types
        aiContent.writeln('[FILE ATTACHMENT: ${attachment.name} - ${attachment.sizeFormatted}]');
        aiContent.writeln('Binary file attachment - metadata only');
      }
      
      aiContent.writeln('--- End of ${attachment.name} ---\n');
    }
    
    return aiContent.toString();
  }
  
  /// Create a complete message for AI including attachments
  static String buildAIMessage(String userText, List<FileAttachment> attachments) {
    final StringBuffer fullMessage = StringBuffer();
    
    // Add user text
    if (userText.isNotEmpty) {
      fullMessage.writeln(userText);
    }
    
    // Add attachment content
    final attachmentContent = prepareAttachmentsForAI(attachments);
    if (attachmentContent.isNotEmpty) {
      fullMessage.writeln(attachmentContent);
    }
    
    return fullMessage.toString().trim();
  }
  
  /// Check if message has images for vision processing
  static bool hasImages(List<FileAttachment> attachments) {
    return attachments.any((attachment) => attachment.isImage);
  }
  
  /// Get all image attachments for vision API
  static List<FileAttachment> getImageAttachments(List<FileAttachment> attachments) {
    return attachments.where((attachment) => attachment.isImage).toList();
  }
  
  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
  
  /// Clean markdown from text for AI processing
  static String cleanMarkdownForAI(String text) {
    // Remove markdown formatting that might confuse AI
    return text
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Italic
        .replaceAll(RegExp(r'`(.*?)`'), r'$1') // Inline code
        .replaceAll(RegExp(r'```.*?```', dotAll: true), '') // Code blocks
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // Headers
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1') // Links
        .trim();
  }
  
  /// Extract system prompt context from attachments
  static String buildSystemContext(List<FileAttachment> attachments) {
    if (attachments.isEmpty) return '';
    
    final fileTypes = <String>{};
    var hasImages = false;
    var hasPDFs = false;
    var hasCode = false;
    var hasText = false;
    
    for (final attachment in attachments) {
      if (attachment.isImage) hasImages = true;
      if (attachment.isPdf) hasPDFs = true;
      if (attachment.isCode) hasCode = true;
      if (attachment.isText) hasText = true;
      fileTypes.add(FileAttachmentService.getFileTypeDescription(attachment));
    }
    
    final context = StringBuffer();
    context.writeln('Context: User has attached ${attachments.length} file(s):');
    context.writeln('File types: ${fileTypes.join(', ')}');
    
    if (hasImages) {
      context.writeln('- Use your vision capabilities to analyze uploaded images');
    }
    if (hasPDFs) {
      context.writeln('- PDF text content has been extracted and provided');
    }
    if (hasCode) {
      context.writeln('- Code files are included for review and analysis');
    }
    if (hasText) {
      context.writeln('- Text documents are included for reference');
    }
    
    context.writeln('Please analyze all provided content and respond appropriately.');
    
    return context.toString();
  }
  
  /// Check if external tools references should be removed
  static String removeExternalToolsReferences(String text) {
    // Remove any remaining external tools references
    return text
        .replaceAll(RegExp(r'External\s+tools?\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'tool\s+is\s+running', caseSensitive: false), 'processing')
        .replaceAll(RegExp(r'external\s+tool', caseSensitive: false), 'feature')
        .trim();
  }
  
  /// Handle image picker for unified attachment
  static Future<List<FileAttachment>?> handleUnifiedAttachment() async {
    try {
      // Show choice dialog for image vs file
      // For now, direct to file picker that handles both
      return await FileAttachmentService.pickFiles();
    } catch (e) {
      print('Error in unified attachment: $e');
      return null;
    }
  }
  
  /// Convert ImagePicker result to FileAttachment
  static Future<FileAttachment?> convertImageToAttachment(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final name = imageFile.name;
      final size = bytes.length;
      
      return FileAttachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        filePath: imageFile.path,
        mimeType: imageFile.mimeType ?? 'image/jpeg',
        size: size,
        uploadedAt: DateTime.now(),
        bytes: bytes,
        isImage: true,
        isZip: false,
        isText: false,
        isCode: false,
        isPdf: false,
      );
    } catch (e) {
      print('Error converting image to attachment: $e');
      return null;
    }
  }
  
  /// Validate attachment before processing
  static bool isValidAttachment(FileAttachment attachment) {
    // Check file size limits
    const maxFileSize = 50 * 1024 * 1024; // 50MB limit
    if (attachment.size > maxFileSize) {
      return false;
    }
    
    // Check if content was extracted successfully for text files
    if ((attachment.isText || attachment.isCode || attachment.isPdf) && 
        attachment.textContent == null) {
      return false;
    }
    
    return true;
  }
  
  /// Get file extension from filename
  static String getFileExtension(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? '.${parts.last.toLowerCase()}' : '';
  }
  
  /// Check if file type is supported
  static bool isSupportedFileType(String extension) {
    return FileAttachmentService.supportedImageExtensions.contains(extension) ||
           FileAttachmentService.supportedTextExtensions.contains(extension) ||
           FileAttachmentService.supportedCodeExtensions.contains(extension) ||
           FileAttachmentService.supportedArchiveExtensions.contains(extension) ||
           FileAttachmentService.supportedPdfExtensions.contains(extension);
  }
}