import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:typed_data';

class CachedImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImageWidget({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Handle base64 images (common for generated images/diagrams)
    if (imageUrl.startsWith('data:image/')) {
      return Image.memory(
        _base64ToUint8List(imageUrl),
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => 
          errorWidget ?? _buildErrorWidget(),
      );
    }

    // Handle network images with caching
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      memCacheWidth: width?.round(),
      memCacheHeight: height?.round(),
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA3A3A3)),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE57373),
          width: 1,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Color(0xFFE57373),
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              'Failed to load image',
              style: TextStyle(
                color: Color(0xFFE57373),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Uint8List _base64ToUint8List(String dataUrl) {
    final base64String = dataUrl.split(',')[1];
    return base64Decode(base64String);
  }
}