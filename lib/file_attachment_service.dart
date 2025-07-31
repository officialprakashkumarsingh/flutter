import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

class FileAttachment {
  final String id;
  final String name;
  final String path;
  final String mimeType;
  final int size;
  final DateTime uploadedAt;
  final Uint8List? bytes;
  final List<FileAttachment>? extractedFiles; // For zip files
  final String? textContent; // For text-based files
  final bool isImage;
  final bool isZip;
  final bool isText;
  final bool isCode;

  FileAttachment({
    required this.id,
    required this.name,
    required this.path,
    required this.mimeType,
    required this.size,
    required this.uploadedAt,
    this.bytes,
    this.extractedFiles,
    this.textContent,
    required this.isImage,
    required this.isZip,
    required this.isText,
    required this.isCode,
  });

  String get sizeFormatted {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String get fileExtension {
    return path.extension(name).toLowerCase();
  }

  String get fileIcon {
    if (isImage) return '🖼️';
    if (isZip) return '📦';
    if (isCode) return '💻';
    if (isText) return '📄';
    if (fileExtension == '.pdf') return '📕';
    if (fileExtension == '.json') return '📊';
    if (fileExtension == '.xml') return '🔧';
    return '📁';
  }
}

class FileAttachmentService {
  static const List<String> supportedTextExtensions = [
    '.txt', '.md', '.readme', '.log', '.conf', '.config', '.ini', '.yml', '.yaml'
  ];

  static const List<String> supportedCodeExtensions = [
    '.dart', '.js', '.ts', '.py', '.java', '.kt', '.swift', '.cpp', '.c', '.cs',
    '.php', '.rb', '.go', '.rs', '.scala', '.pl', '.lua', '.r', '.m', '.sql',
    '.html', '.css', '.scss', '.less', '.xml', '.json', '.toml', '.sh', '.bat',
    '.ps1', '.fish', '.zsh', '.hs', '.ex', '.erl', '.clj', '.ml', '.fs', '.lisp',
    '.scm', '.jl', '.nim', '.zig', '.cr', '.v', '.sol', '.vy', '.move', '.asm',
    '.s', '.vhd', '.sv'
  ];

  static const List<String> supportedImageExtensions = [
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'
  ];

  static const List<String> supportedArchiveExtensions = [
    '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2'
  ];

  /// Pick files from device
  static Future<List<FileAttachment>?> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true, // Get file bytes
      );

      if (result == null || result.files.isEmpty) return null;

      final List<FileAttachment> attachments = [];

      for (final file in result.files) {
        if (file.bytes == null || file.path == null) continue;

        final attachment = await _processFile(file);
        if (attachment != null) {
          attachments.add(attachment);
        }
      }

      return attachments.isNotEmpty ? attachments : null;
    } catch (e) {
      print('Error picking files: $e');
      return null;
    }
  }

  /// Process a single file and create FileAttachment
  static Future<FileAttachment?> _processFile(PlatformFile file) async {
    try {
      final bytes = file.bytes!;
      final fileName = file.name;
      final filePath = file.path!;
      final fileSize = file.size;
      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
      final extension = path.extension(fileName).toLowerCase();

      final isImage = supportedImageExtensions.contains(extension);
      final isZip = supportedArchiveExtensions.contains(extension);
      final isText = supportedTextExtensions.contains(extension);
      final isCode = supportedCodeExtensions.contains(extension);

      String? textContent;
      List<FileAttachment>? extractedFiles;

      // Read text content for text-based files
      if (isText || isCode) {
        try {
          textContent = utf8.decode(bytes);
        } catch (e) {
          // If UTF-8 decoding fails, try with Latin-1
          try {
            textContent = latin1.decode(bytes);
          } catch (e) {
            textContent = 'Binary file - cannot preview';
          }
        }
      }

      // Extract zip files
      if (isZip && extension == '.zip') {
        try {
          extractedFiles = await _extractZipFile(bytes);
        } catch (e) {
          print('Error extracting zip: $e');
        }
      }

      return FileAttachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: fileName,
        path: filePath,
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
      );
    } catch (e) {
      print('Error processing file ${file.name}: $e');
      return null;
    }
  }

  /// Extract files from a zip archive
  static Future<List<FileAttachment>> _extractZipFile(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final List<FileAttachment> extractedFiles = [];

    for (final file in archive) {
      if (file.isFile) {
        try {
          final bytes = Uint8List.fromList(file.content as List<int>);
          final fileName = file.name;
          final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
          final extension = path.extension(fileName).toLowerCase();

          final isImage = supportedImageExtensions.contains(extension);
          final isText = supportedTextExtensions.contains(extension);
          final isCode = supportedCodeExtensions.contains(extension);

          String? textContent;
          if (isText || isCode) {
            try {
              textContent = utf8.decode(bytes);
            } catch (e) {
              try {
                textContent = latin1.decode(bytes);
              } catch (e) {
                textContent = 'Binary file - cannot preview';
              }
            }
          }

          extractedFiles.add(FileAttachment(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_${file.name}',
            name: fileName,
            path: 'extracted:${file.name}',
            mimeType: mimeType,
            size: bytes.length,
            uploadedAt: DateTime.now(),
            bytes: bytes,
            textContent: textContent,
            isImage: isImage,
            isZip: false,
            isText: isText,
            isCode: isCode,
          ));
        } catch (e) {
          print('Error extracting file ${file.name}: $e');
        }
      }
    }

    return extractedFiles;
  }

  /// Get file type description
  static String getFileTypeDescription(FileAttachment file) {
    if (file.isImage) return 'Image';
    if (file.isZip) return 'Archive';
    if (file.isCode) return 'Code File';
    if (file.isText) return 'Text File';
    if (file.fileExtension == '.pdf') return 'PDF Document';
    if (file.fileExtension == '.json') return 'JSON Data';
    if (file.fileExtension == '.xml') return 'XML Document';
    return 'File';
  }

  /// Get syntax highlighting language for code files
  static String getCodeLanguage(FileAttachment file) {
    final ext = file.fileExtension;
    const Map<String, String> languageMap = {
      '.dart': 'dart',
      '.js': 'javascript',
      '.ts': 'typescript',
      '.py': 'python',
      '.java': 'java',
      '.kt': 'kotlin',
      '.swift': 'swift',
      '.cpp': 'cpp',
      '.c': 'c',
      '.cs': 'csharp',
      '.php': 'php',
      '.rb': 'ruby',
      '.go': 'go',
      '.rs': 'rust',
      '.html': 'html',
      '.css': 'css',
      '.json': 'json',
      '.xml': 'xml',
      '.sql': 'sql',
      '.sh': 'bash',
      '.yml': 'yaml',
      '.yaml': 'yaml',
    };
    return languageMap[ext] ?? 'text';
  }
}