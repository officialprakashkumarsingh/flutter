import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as pathLib;
import 'apk_extraction_service.dart';

class FileAttachment {
  final String id;
  final String name;
  final String filePath;
  final String mimeType;
  final int size;
  final DateTime uploadedAt;
  final Uint8List bytes;
  final List<FileAttachment>? extractedFiles;
  final String? textContent;
  final bool isImage;
  final bool isZip;
  final bool isText;
  final bool isCode;
  final bool isPdf;
  final bool isApk;

  FileAttachment({
    required this.id,
    required this.name,
    required this.filePath,
    required this.mimeType,
    required this.size,
    required this.uploadedAt,
    required this.bytes,
    this.extractedFiles,
    this.textContent,
    required this.isImage,
    required this.isZip,
    required this.isText,
    required this.isCode,
    required this.isPdf,
    required this.isApk,
  });

  String get fileIcon {
    if (isApk) return '📱';
    if (isImage) return '🖼️';
    if (isZip) return '📦';
    if (isPdf) return '📕';
    if (isCode) return '💻';
    if (isText) return '📄';
    return '📎';
  }

  String get sizeFormatted {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

class FileAttachmentService {
  static const List<String> supportedImageExtensions = [
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'
  ];

  static const List<String> supportedTextExtensions = [
    '.txt', '.md', '.rtf'
  ];

  static const List<String> supportedCodeExtensions = [
    '.dart', '.js', '.ts', '.html', '.css', '.json', '.xml', '.yaml', '.yml',
    '.py', '.java', '.c', '.cpp', '.h', '.hpp', '.cs', '.php', '.rb', '.go',
    '.rs', '.swift', '.kt', '.scala', '.sh', '.bat', '.ps1', '.sql', '.r'
  ];

  static const List<String> supportedArchiveExtensions = [
    '.zip', '.rar', '.7z', '.tar', '.gz', '.apk'
  ];

  static const List<String> supportedPdfExtensions = ['.pdf'];

  static Future<List<FileAttachment>?> pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );

      if (result != null) {
        List<FileAttachment> attachments = [];
        for (PlatformFile file in result.files) {
          final attachment = await _processFile(file);
          if (attachment != null) {
            attachments.add(attachment);
          }
        }
        return attachments;
      }
    } catch (e) {
      print('Error picking files: $e');
    }
    return null;
  }

  static Future<FileAttachment?> _processFile(PlatformFile file) async {
    try {
      final bytes = file.bytes!;
      final fileName = file.name;
      final filePath = file.path!;
      final fileSize = file.size;
      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
      final extension = pathLib.extension(fileName).toLowerCase();

      final isImage = supportedImageExtensions.contains(extension);
      final isZip = supportedArchiveExtensions.contains(extension);
      final isText = supportedTextExtensions.contains(extension);
      final isCode = supportedCodeExtensions.contains(extension);
      final isPdf = supportedPdfExtensions.contains(extension);
      final isApk = extension == '.apk';

      String? textContent;
      List<FileAttachment>? extractedFiles;

      // Read text content for text-based files
      if (isText || isCode) {
        try {
          textContent = utf8.decode(bytes);
        } catch (e) {
          textContent = 'Binary file - cannot preview';
        }
      }

      // Extract ZIP files
      if (isZip && extension == '.zip') {
        try {
          extractedFiles = await _extractZipFile(bytes);
        } catch (e) {
          print('Error extracting ZIP: $e');
        }
      }

      // Extract APK files
      if (isApk) {
        try {
          final apkResult = await ApkExtractionService.extractApk(bytes, fileName);
          textContent = ApkExtractionService.generateAnalysisReport(apkResult);
        } catch (e) {
          textContent = 'Error extracting APK: $e';
        }
      }

      // PDF placeholder for now
      if (isPdf) {
        textContent = 'PDF file - ${fileName} (${(fileSize / 1024).toStringAsFixed(1)}KB)';
      }

      return FileAttachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: fileName,
        filePath: filePath,
        mimeType: mimeType,
        size: fileSize,
        uploadedAt: DateTime.now(),
        bytes: bytes,
        extractedFiles: extractedFiles,
        textContent: textContent,
        isImage: isImage,
        isZip: isZip,
        isText: isText,
        isCode: isCode,
        isApk: isApk,
        isPdf: isPdf,
      );
    } catch (e) {
      print('Error processing file: $e');
      return null;
    }
  }

  static Future<List<FileAttachment>> _extractZipFile(Uint8List zipBytes) async {
    final extractedFiles = <FileAttachment>[];
    
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      
      for (final file in archive) {
        if (file.isFile) {
          final bytes = file.content as Uint8List;
          final fileName = file.name;
          final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
          final extension = pathLib.extension(fileName).toLowerCase();

          final isImage = supportedImageExtensions.contains(extension);
          final isText = supportedTextExtensions.contains(extension);
          final isCode = supportedCodeExtensions.contains(extension);
          final isPdf = supportedPdfExtensions.contains(extension);

          String? textContent;
          if (isText || isCode) {
            try {
              textContent = utf8.decode(bytes);
            } catch (e) {
              textContent = 'Binary content';
            }
          }

          extractedFiles.add(FileAttachment(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + fileName.hashCode.toString(),
            name: fileName,
            filePath: fileName,
            mimeType: mimeType,
            size: bytes.length,
            uploadedAt: DateTime.now(),
            bytes: bytes,
            textContent: textContent,
            isImage: isImage,
            isZip: false,
            isText: isText,
            isCode: isCode,
            isApk: false,
            isPdf: isPdf,
          ));
        }
      }
    } catch (e) {
      print('Error extracting ZIP: $e');
    }
    
    return extractedFiles;
  }

  static String getFileTypeDescription(FileAttachment file) {
    if (file.isApk) return 'Android APK';
    if (file.isImage) return 'Image';
    if (file.isZip) return 'Archive';
    if (file.isPdf) return 'PDF Document';
    if (file.isCode) return 'Code File';
    if (file.isText) return 'Text File';
    return 'File';
  }

  static String getCodeLanguage(FileAttachment file) {
    if (!file.isCode) return 'text';
    
    final extension = pathLib.extension(file.name).toLowerCase();
    const languageMap = {
      '.dart': 'dart',
      '.js': 'javascript',
      '.ts': 'typescript',
      '.html': 'html',
      '.css': 'css',
      '.json': 'json',
      '.xml': 'xml',
      '.yaml': 'yaml',
      '.yml': 'yaml',
      '.py': 'python',
      '.java': 'java',
      '.c': 'c',
      '.cpp': 'cpp',
      '.h': 'c',
      '.hpp': 'cpp',
      '.cs': 'csharp',
      '.php': 'php',
      '.rb': 'ruby',
      '.go': 'go',
      '.rs': 'rust',
      '.swift': 'swift',
      '.kt': 'kotlin',
      '.scala': 'scala',
      '.sh': 'bash',
      '.bat': 'batch',
      '.ps1': 'powershell',
      '.sql': 'sql',
      '.r': 'r',
    };
    
    return languageMap[extension] ?? 'text';
  }
}