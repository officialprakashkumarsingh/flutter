import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as pathLib;

class FileAttachment {
  final String id;
  final String name;
  final String filePath;
  final String mimeType;
  final int size;
  final DateTime uploadedAt;
  final Uint8List? bytes;
  final List<FileAttachment>? extractedFiles;
  final String? textContent;
  final bool isImage;
  final bool isZip;
  final bool isText;
  final bool isCode;

  FileAttachment({
    required this.id,
    required this.name,
    required this.filePath,
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
    return pathLib.extension(name).toLowerCase();
  }

  String get fileIcon {
    if (isImage) return '🖼️';
    if (isZip) return '📦';
    if (isCode) return '💻';
    if (isText) return '📄';
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
    '.html', '.css', '.scss', '.less', '.xml', '.json', '.toml', '.sh', '.bat'
  ];

  static const List<String> supportedImageExtensions = [
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'
  ];

  static const List<String> supportedArchiveExtensions = [
    '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2'
  ];

  static Future<List<FileAttachment>?> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
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
      return null;
    }
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

      String? textContent;
      List<FileAttachment>? extractedFiles;

      if (isText || isCode) {
        try {
          textContent = utf8.decode(bytes);
        } catch (e) {
          textContent = 'Binary file - cannot preview';
        }
      }

      if (isZip && extension == '.zip') {
        try {
          extractedFiles = await _extractZipFile(bytes);
        } catch (e) {
          // Handle error silently
        }
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
      );
    } catch (e) {
      return null;
    }
  }

  static Future<List<FileAttachment>> _extractZipFile(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final List<FileAttachment> extractedFiles = [];

    for (final file in archive) {
      if (file.isFile) {
        try {
          final bytes = Uint8List.fromList(file.content as List<int>);
          final fileName = file.name;
          final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
          final extension = pathLib.extension(fileName).toLowerCase();

          final isImage = supportedImageExtensions.contains(extension);
          final isText = supportedTextExtensions.contains(extension);
          final isCode = supportedCodeExtensions.contains(extension);

          String? textContent;
          if (isText || isCode) {
            try {
              textContent = utf8.decode(bytes);
            } catch (e) {
              textContent = 'Binary file - cannot preview';
            }
          }

          extractedFiles.add(FileAttachment(
            id: '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
            name: fileName,
            filePath: 'extracted:${file.name}',
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
          // Handle error silently
        }
      }
    }

    return extractedFiles;
  }

  static String getFileTypeDescription(FileAttachment file) {
    if (file.isImage) return 'Image';
    if (file.isZip) return 'Archive';
    if (file.isCode) return 'Code File';
    if (file.isText) return 'Text File';
    return 'File';
  }

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
