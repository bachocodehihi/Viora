import 'dart:io';
import 'package:flutter/material.dart';

class PostImagesGrid extends StatelessWidget {
  final List images;
  final VoidCallback? onImageTap;
  final Function(int index)? onIndexedImageTap;

  const PostImagesGrid({
    super.key,
    required this.images,
    this.onImageTap,
    this.onIndexedImageTap,
  });

  Widget _buildImageWidget(String imgUrl, double width, double height) {
    final isLocal = !imgUrl.startsWith('http');
    return isLocal
        ? Image.file(
            File(imgUrl),
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          )
        : Image.network(
            imgUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          );
  }

  Widget _buildClickablePostImage(int index, double height) {
    final imgUrl = images[index].toString();
    return GestureDetector(
      onTap: () {
        if (onIndexedImageTap != null) {
          onIndexedImageTap!(index);
        } else if (onImageTap != null) {
          onImageTap!();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildImageWidget(imgUrl, double.infinity, height),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      final img = images[0].toString();
      return GestureDetector(
        onTap: () {
          if (onIndexedImageTap != null) {
            onIndexedImageTap!(0);
          } else if (onImageTap != null) {
            onImageTap!();
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _buildImageWidget(img, double.infinity, 220),
        ),
      );
    }

    if (images.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildClickablePostImage(0, 180)),
          const SizedBox(width: 6),
          Expanded(child: _buildClickablePostImage(1, 180)),
        ],
      );
    }

    if (images.length == 3) {
      return Column(
        children: [
          _buildClickablePostImage(0, 180),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildClickablePostImage(1, 120)),
              const SizedBox(width: 6),
              Expanded(child: _buildClickablePostImage(2, 120)),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildClickablePostImage(0, 140)),
            const SizedBox(width: 6),
            Expanded(child: _buildClickablePostImage(1, 140)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildClickablePostImage(2, 140)),
            const SizedBox(width: 6),
            Expanded(
              child: Stack(
                children: [
                  _buildClickablePostImage(3, 140),
                  if (images.length > 4)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          if (onIndexedImageTap != null) {
                            onIndexedImageTap!(3);
                          } else if (onImageTap != null) {
                            onImageTap!();
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+${images.length - 4}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

