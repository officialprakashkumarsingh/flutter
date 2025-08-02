import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as pathLib;

class ApkExtractionService {
  /// Main method to extract and analyze APK file
  static Future<ApkAnalysisResult> extractApk(Uint8List apkBytes, String fileName) async {
    try {
      // Decode the APK (ZIP archive)
      final archive = ZipDecoder().decodeBytes(apkBytes);
      
      // Initialize result
      final result = ApkAnalysisResult(fileName: fileName);
      
      // Extract AndroidManifest.xml
      await _extractManifest(archive, result);
      
      // Extract resources and layouts
      await _extractResources(archive, result);
      
      // Extract assets
      await _extractAssets(archive, result);
      
      // Analyze file structure
      await _analyzeFileStructure(archive, result);
      
      // Extract META-INF information
      await _extractMetaInfo(archive, result);
      
      return result;
    } catch (e) {
      return ApkAnalysisResult(
        fileName: fileName,
        error: 'Failed to extract APK: $e',
      );
    }
  }

  /// Extract and parse AndroidManifest.xml
  static Future<void> _extractManifest(Archive archive, ApkAnalysisResult result) async {
    try {
      final manifestFile = archive.files.firstWhere(
        (file) => file.name == 'AndroidManifest.xml',
        orElse: () => throw Exception('AndroidManifest.xml not found'),
      );

      if (manifestFile.content != null) {
        // AndroidManifest.xml is usually in binary format, but we'll try to parse it
        final content = manifestFile.content as List<int>;
        final contentStr = utf8.decode(content, allowMalformed: true);
        
        result.manifestContent = contentStr;
        
        // Try to parse as XML if it's readable
        try {
          final document = XmlDocument.parse(contentStr);
          _parseManifestXml(document, result);
        } catch (e) {
          result.manifestContent = 'Binary AndroidManifest.xml detected - readable content extracted where possible';
          // For binary manifests, we can still extract some basic info
          _extractBinaryManifestInfo(content, result);
        }
      }
    } catch (e) {
      result.manifestContent = 'Could not extract AndroidManifest.xml: $e';
    }
  }

  /// Parse readable AndroidManifest.xml
  static void _parseManifestXml(XmlDocument document, ApkAnalysisResult result) {
    final manifest = document.findElements('manifest').first;
    
    // Extract package info
    result.packageName = manifest.getAttribute('package') ?? 'Unknown';
    result.versionName = manifest.getAttribute('android:versionName') ?? 'Unknown';
    result.versionCode = manifest.getAttribute('android:versionCode') ?? 'Unknown';
    
    // Extract uses-sdk info
    final usesSdk = manifest.findElements('uses-sdk').firstOrNull;
    if (usesSdk != null) {
      result.minSdkVersion = usesSdk.getAttribute('android:minSdkVersion') ?? 'Unknown';
      result.targetSdkVersion = usesSdk.getAttribute('android:targetSdkVersion') ?? 'Unknown';
    }
    
    // Extract permissions
    final permissions = manifest.findElements('uses-permission');
    result.permissions = permissions
        .map((perm) => perm.getAttribute('android:name') ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    
    // Extract application components
    final application = manifest.findElements('application').firstOrNull;
    if (application != null) {
      // Activities
      final activities = application.findElements('activity');
      result.activities = activities
          .map((activity) => activity.getAttribute('android:name') ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      
      // Services
      final services = application.findElements('service');
      result.services = services
          .map((service) => service.getAttribute('android:name') ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      
      // Receivers
      final receivers = application.findElements('receiver');
      result.receivers = receivers
          .map((receiver) => receiver.getAttribute('android:name') ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    }
  }

  /// Extract basic info from binary AndroidManifest.xml
  static void _extractBinaryManifestInfo(List<int> content, ApkAnalysisResult result) {
    // For binary manifests, we can try to extract some strings
    final contentStr = String.fromCharCodes(content, 0, content.length);
    
    // Look for common package patterns
    final packageRegex = RegExp(r'([a-z][a-z0-9_]*\.)+[a-z][a-z0-9_]*');
    final packageMatches = packageRegex.allMatches(contentStr);
    if (packageMatches.isNotEmpty) {
      result.packageName = packageMatches.first.group(0) ?? 'Unknown';
    }
    
    // Look for permission strings
    final permissionRegex = RegExp(r'android\.permission\.[A-Z_]+');
    final permissionMatches = permissionRegex.allMatches(contentStr);
    result.permissions = permissionMatches
        .map((match) => match.group(0) ?? '')
        .where((perm) => perm.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Extract resources (layouts, strings, etc.)
  static Future<void> _extractResources(Archive archive, ApkAnalysisResult result) async {
    final resourceFiles = <String, String>{};
    
    for (final file in archive.files) {
      if (file.isFile && file.content != null) {
        final fileName = file.name;
        
        // Extract XML files from res/ folder
        if (fileName.startsWith('res/') && fileName.endsWith('.xml')) {
          try {
            final content = file.content as List<int>;
            final contentStr = utf8.decode(content, allowMalformed: true);
            
            // Try to parse as XML
            try {
              final document = XmlDocument.parse(contentStr);
              resourceFiles[fileName] = document.toXmlString(pretty: true);
            } catch (e) {
              resourceFiles[fileName] = 'Binary XML file - content: ${contentStr.substring(0, 200)}...';
            }
          } catch (e) {
            resourceFiles[fileName] = 'Could not read XML file: $e';
          }
        }
        
        // List drawable/mipmap files
        if (fileName.startsWith('res/drawable/') || fileName.startsWith('res/mipmap/')) {
          final fileSize = (file.content as List<int>).length;
          result.drawableFiles[fileName] = '${(fileSize / 1024).toStringAsFixed(1)} KB';
        }
      }
    }
    
    result.resourceFiles = resourceFiles;
  }

  /// Extract assets folder content
  static Future<void> _extractAssets(Archive archive, ApkAnalysisResult result) async {
    final assetFiles = <String, String>{};
    
    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith('assets/') && file.content != null) {
        try {
          final content = file.content as List<int>;
          final fileName = file.name;
          final extension = pathLib.extension(fileName).toLowerCase();
          
          // Try to read text-based files
          if (_isTextBasedFile(extension)) {
            final contentStr = utf8.decode(content, allowMalformed: true);
            assetFiles[file.name] = contentStr;
          } else {
            final fileSize = content.length;
            assetFiles[file.name] = 'Binary file - Size: ${(fileSize / 1024).toStringAsFixed(1)} KB';
          }
        } catch (e) {
          assetFiles[file.name] = 'Could not read asset file: $e';
        }
      }
    }
    
    result.assetFiles = assetFiles;
  }

  /// Analyze overall file structure
  static Future<void> _analyzeFileStructure(Archive archive, ApkAnalysisResult result) async {
    final structure = <String, FileInfo>{};
    int totalSize = 0;
    
    for (final file in archive.files) {
      if (file.isFile && file.content != null) {
        final content = file.content as List<int>;
        final size = content.length;
        totalSize += size;
        
        structure[file.name] = FileInfo(
          name: file.name,
          size: size,
          type: _getFileType(file.name),
          isReadable: _isReadableFile(file.name),
        );
      }
    }
    
    result.fileStructure = structure;
    result.totalSize = totalSize;
    result.fileCount = structure.length;
  }

  /// Extract META-INF information
  static Future<void> _extractMetaInfo(Archive archive, ApkAnalysisResult result) async {
    final metaFiles = <String, String>{};
    
    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith('META-INF/') && file.content != null) {
        try {
          final content = file.content as List<int>;
          final contentStr = utf8.decode(content, allowMalformed: true);
          metaFiles[file.name] = contentStr;
        } catch (e) {
          metaFiles[file.name] = 'Binary META-INF file: ${file.name}';
        }
      }
    }
    
    result.metaFiles = metaFiles;
  }

  /// Check if file extension is text-based
  static bool _isTextBasedFile(String extension) {
    const textExtensions = {
      '.txt', '.xml', '.json', '.html', '.css', '.js', '.md', '.properties',
      '.conf', '.config', '.ini', '.log', '.sql', '.csv', '.yaml', '.yml'
    };
    return textExtensions.contains(extension);
  }

  /// Get file type description
  static String _getFileType(String fileName) {
    if (fileName.endsWith('.dex')) return 'Compiled Code';
    if (fileName.endsWith('.xml')) return 'XML Resource';
    if (fileName.endsWith('.arsc')) return 'Compiled Resources';
    if (fileName.endsWith('.so')) return 'Native Library';
    if (fileName.contains('drawable/') || fileName.contains('mipmap/')) return 'Image Resource';
    if (fileName.startsWith('assets/')) return 'Asset File';
    if (fileName.startsWith('META-INF/')) return 'Signature/Metadata';
    if (fileName.startsWith('res/')) return 'App Resource';
    return 'Other';
  }

  /// Check if file is readable (text-based)
  static bool _isReadableFile(String fileName) {
    final extension = pathLib.extension(fileName).toLowerCase();
    return _isTextBasedFile(extension) || fileName.endsWith('.xml');
  }

  /// Generate formatted analysis report
  static String generateAnalysisReport(ApkAnalysisResult result) {
    final buffer = StringBuffer();
    
    buffer.writeln('--- APK Analysis: ${result.fileName} ---\n');
    
    if (result.error != null) {
      buffer.writeln('❌ ERROR: ${result.error}\n');
      return buffer.toString();
    }
    
    // App Information
    buffer.writeln('📱 APP INFORMATION:');
    buffer.writeln('Package: ${result.packageName}');
    buffer.writeln('Version Name: ${result.versionName}');
    buffer.writeln('Version Code: ${result.versionCode}');
    buffer.writeln('Min SDK: ${result.minSdkVersion}');
    buffer.writeln('Target SDK: ${result.targetSdkVersion}');
    buffer.writeln('Total Size: ${(result.totalSize / (1024 * 1024)).toStringAsFixed(2)} MB');
    buffer.writeln('File Count: ${result.fileCount}');
    buffer.writeln();
    
    // Permissions
    if (result.permissions.isNotEmpty) {
      buffer.writeln('🔐 PERMISSIONS (${result.permissions.length}):');
      for (final permission in result.permissions.take(10)) {
        buffer.writeln('- $permission');
      }
      if (result.permissions.length > 10) {
        buffer.writeln('... and ${result.permissions.length - 10} more');
      }
      buffer.writeln();
    }
    
    // Components
    if (result.activities.isNotEmpty) {
      buffer.writeln('📱 ACTIVITIES (${result.activities.length}):');
      for (final activity in result.activities.take(5)) {
        buffer.writeln('- $activity');
      }
      if (result.activities.length > 5) {
        buffer.writeln('... and ${result.activities.length - 5} more');
      }
      buffer.writeln();
    }
    
    if (result.services.isNotEmpty) {
      buffer.writeln('⚙️ SERVICES (${result.services.length}):');
      for (final service in result.services.take(5)) {
        buffer.writeln('- $service');
      }
      if (result.services.length > 5) {
        buffer.writeln('... and ${result.services.length - 5} more');
      }
      buffer.writeln();
    }
    
    // File Structure Summary
    buffer.writeln('📁 FILE STRUCTURE:');
    final groupedFiles = <String, List<FileInfo>>{};
    for (final file in result.fileStructure.values) {
      groupedFiles.putIfAbsent(file.type, () => []).add(file);
    }
    
    for (final entry in groupedFiles.entries) {
      final type = entry.key;
      final files = entry.value;
      final totalSize = files.fold(0, (sum, file) => sum + file.size);
      buffer.writeln('├── $type: ${files.length} files (${(totalSize / 1024).toStringAsFixed(1)} KB)');
    }
    buffer.writeln();
    
    // Extracted Resources
    if (result.resourceFiles.isNotEmpty) {
      buffer.writeln('📄 EXTRACTED XML RESOURCES (${result.resourceFiles.length}):');
      for (final entry in result.resourceFiles.entries.take(3)) {
        buffer.writeln('--- ${entry.key} ---');
        buffer.writeln(entry.value.length > 500 
            ? '${entry.value.substring(0, 500)}...\n[Content truncated]'
            : entry.value);
        buffer.writeln();
      }
      if (result.resourceFiles.length > 3) {
        buffer.writeln('... and ${result.resourceFiles.length - 3} more XML files');
      }
      buffer.writeln();
    }
    
    // Extracted Assets
    if (result.assetFiles.isNotEmpty) {
      buffer.writeln('💾 EXTRACTED ASSETS (${result.assetFiles.length}):');
      for (final entry in result.assetFiles.entries.take(3)) {
        buffer.writeln('--- ${entry.key} ---');
        buffer.writeln(entry.value.length > 300
            ? '${entry.value.substring(0, 300)}...\n[Content truncated]'
            : entry.value);
        buffer.writeln();
      }
      if (result.assetFiles.length > 3) {
        buffer.writeln('... and ${result.assetFiles.length - 3} more asset files');
      }
      buffer.writeln();
    }
    
    // AndroidManifest content
    if (result.manifestContent.isNotEmpty) {
      buffer.writeln('📋 ANDROID MANIFEST:');
      buffer.writeln(result.manifestContent.length > 1000
          ? '${result.manifestContent.substring(0, 1000)}...\n[Content truncated]'
          : result.manifestContent);
      buffer.writeln();
    }
    
    buffer.writeln('--- End of ${result.fileName} Analysis ---');
    
    return buffer.toString();
  }
}

/// Result class for APK analysis
class ApkAnalysisResult {
  final String fileName;
  String? error;
  
  // App Info
  String packageName = 'Unknown';
  String versionName = 'Unknown';
  String versionCode = 'Unknown';
  String minSdkVersion = 'Unknown';
  String targetSdkVersion = 'Unknown';
  
  // Components
  List<String> permissions = [];
  List<String> activities = [];
  List<String> services = [];
  List<String> receivers = [];
  
  // Content
  String manifestContent = '';
  Map<String, String> resourceFiles = {};
  Map<String, String> assetFiles = {};
  Map<String, String> drawableFiles = {};
  Map<String, String> metaFiles = {};
  
  // Structure
  Map<String, FileInfo> fileStructure = {};
  int totalSize = 0;
  int fileCount = 0;
  
  ApkAnalysisResult({required this.fileName, this.error});
}

/// File information class
class FileInfo {
  final String name;
  final int size;
  final String type;
  final bool isReadable;
  
  FileInfo({
    required this.name,
    required this.size,
    required this.type,
    required this.isReadable,
  });
}