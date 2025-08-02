import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

class FileUploadService {
  static final FileUploadService _instance = FileUploadService._internal();
  factory FileUploadService() => _instance;
  FileUploadService._internal();

  List<UploadedFile> _uploadedFiles = [];
  List<UploadedFile> get uploadedFiles => _uploadedFiles;

  // Upload and extract zip file
  Future<List<UploadedFile>> uploadZipFile() async {
    try {
      fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final fileName = result.files.single.name;
        
        // Extract zip file
        final archive = ZipDecoder().decodeBytes(bytes);
        final extractedFiles = <UploadedFile>[];
        
        for (final file in archive) {
          if (file.isFile) {
            final content = file.content as List<int>;
            final uploadedFile = UploadedFile(
              name: file.name,
              content: String.fromCharCodes(content),
              bytes: Uint8List.fromList(content),
              type: _getFileType(file.name),
              uploadTime: DateTime.now(),
            );
            extractedFiles.add(uploadedFile);
          }
        }
        
        _uploadedFiles.addAll(extractedFiles);
        return extractedFiles;
      }
    } catch (e) {
      print('Error uploading zip file: $e');
    }
    return [];
  }

  // Upload individual files
  Future<List<UploadedFile>> uploadIndividualFiles() async {
    try {
      fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: fp.FileType.any,
        withData: true,
      );

      if (result != null) {
        final uploadedFiles = <UploadedFile>[];
        
        for (final file in result.files) {
          if (file.bytes != null) {
            final uploadedFile = UploadedFile(
              name: file.name,
              content: String.fromCharCodes(file.bytes!),
              bytes: file.bytes!,
              type: _getFileType(file.name),
              uploadTime: DateTime.now(),
            );
            uploadedFiles.add(uploadedFile);
          }
        }
        
        _uploadedFiles.addAll(uploadedFiles);
        return uploadedFiles;
      }
    } catch (e) {
      print('Error uploading files: $e');
    }
    return [];
  }

  FileType _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'html':
      case 'htm':
        return FileType.html;
      case 'css':
        return FileType.css;
      case 'js':
      case 'javascript':
        return FileType.javascript;
      case 'json':
        return FileType.json;
      case 'xml':
        return FileType.xml;
      case 'txt':
        return FileType.text;
      case 'md':
        return FileType.markdown;
      case 'dart':
        return FileType.dart;
      case 'py':
        return FileType.python;
      case 'java':
        return FileType.java;
      case 'cpp':
      case 'c':
        return FileType.cpp;
      case 'jpg':
      case 'jpeg':
        return FileType.jpg;
      case 'png':
        return FileType.png;
      case 'gif':
        return FileType.gif;
      case 'svg':
        return FileType.svg;
      default:
        return FileType.other;
    }
  }

  void removeFile(UploadedFile file) {
    _uploadedFiles.remove(file);
  }

  void clearAllFiles() {
    _uploadedFiles.clear();
  }

  // Get all uploaded content as a single string for AI processing
  String getAllContentForAI() {
    final buffer = StringBuffer();
    buffer.writeln('=== UPLOADED FILES CONTENT ===\n');
    
    for (final file in _uploadedFiles) {
      buffer.writeln('File: ${file.name}');
      buffer.writeln('Type: ${file.type.name}');
      buffer.writeln('Upload Time: ${file.uploadTime}');
      buffer.writeln('Content:');
      buffer.writeln('---');
      buffer.writeln(file.content);
      buffer.writeln('---\n');
    }
    
    return buffer.toString();
  }
}

class UploadedFile {
  final String name;
  final String content;
  final Uint8List bytes;
  final FileType type;
  final DateTime uploadTime;

  UploadedFile({
    required this.name,
    required this.content,
    required this.bytes,
    required this.type,
    required this.uploadTime,
  });
}

enum FileType {
  html,
  css,
  javascript,
  json,
  xml,
  text,
  markdown,
  dart,
  python,
  java,
  cpp,
  jpg,
  png,
  gif,
  svg,
  other,
}

extension FileTypeExtension on FileType {
  String get name {
    switch (this) {
      case FileType.html:
        return 'HTML';
      case FileType.css:
        return 'CSS';
      case FileType.javascript:
        return 'JavaScript';
      case FileType.json:
        return 'JSON';
      case FileType.xml:
        return 'XML';
      case FileType.text:
        return 'Text';
      case FileType.markdown:
        return 'Markdown';
      case FileType.dart:
        return 'Dart';
      case FileType.python:
        return 'Python';
      case FileType.java:
        return 'Java';
      case FileType.cpp:
        return 'C/C++';
      case FileType.jpg:
        return 'JPG Image';
      case FileType.png:
        return 'PNG Image';
      case FileType.gif:
        return 'GIF Image';
      case FileType.svg:
        return 'SVG Image';
      case FileType.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case FileType.html:
        return Colors.orange;
      case FileType.css:
        return Colors.blue;
      case FileType.javascript:
        return Colors.yellow.shade700;
      case FileType.json:
        return Colors.green;
      case FileType.xml:
        return Colors.purple;
      case FileType.text:
        return Colors.grey;
      case FileType.markdown:
        return Colors.indigo;
      case FileType.dart:
        return Colors.blue.shade800;
      case FileType.python:
        return Colors.green.shade700;
      case FileType.java:
        return Colors.red.shade700;
      case FileType.cpp:
        return Colors.blue.shade900;
      case FileType.jpg:
      case FileType.png:
      case FileType.gif:
      case FileType.svg:
        return Colors.pink.shade400;
      case FileType.other:
        return Colors.grey.shade600;
    }
  }

  IconData get icon {
    switch (this) {
      case FileType.html:
        return Icons.language;
      case FileType.css:
        return Icons.style;
      case FileType.javascript:
        return Icons.code;
      case FileType.json:
        return Icons.data_object;
      case FileType.xml:
        return Icons.code;
      case FileType.text:
        return Icons.text_snippet;
      case FileType.markdown:
        return Icons.article;
      case FileType.dart:
        return Icons.flutter_dash;
      case FileType.python:
        return Icons.code;
      case FileType.java:
        return Icons.coffee;
      case FileType.cpp:
        return Icons.code;
      case FileType.jpg:
      case FileType.png:
      case FileType.gif:
      case FileType.svg:
        return Icons.image;
      case FileType.other:
        return Icons.insert_drive_file;
    }
  }
}