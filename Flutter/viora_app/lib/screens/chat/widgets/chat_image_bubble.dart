import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme_helper.dart';
import '../../../l10n/language.dart';
import 'chat_mention_helper.dart';

class ChatImageBubble extends StatelessWidget {
  final bool isMe;
  final List<String> images;
  final String caption;
  final bool isPinned;
  final bool isUploading;
  final void Function(int index) onImageTap;

  const ChatImageBubble({
    super.key,
    required this.isMe,
    required this.images,
    required this.caption,
    required this.isPinned,
    required this.isUploading,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cleanCap = caption.trim();
    final bool hasCaption = cleanCap.isNotEmpty && !Language.isImagePlaceholder(cleanCap);

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildImageGrid(context, images, isUploading),
        if (hasCaption)
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 10.h),
            child: ChatMessageText(
              text: caption,
              isMe: isMe,
            ),
          ),
        if (isPinned)
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, hasCaption ? 0 : 6.h, 10.w, 6.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.push_pin_rounded,
                  size: 11.r,
                  color: isMe ? Colors.white70 : AppColors.blue,
                ),
                SizedBox(width: 3.w),
                Text(
                  l10n.pinned,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: isMe ? Colors.white70 : AppColors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildImageGrid(BuildContext context, List<String> images, bool isUploading) {
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return SizedBox(
        width: 250.w,
        height: 220.h,
        child: _buildImageTile(
          context: context,
          path: images[0],
          allImages: images,
          index: 0,
          isUploading: isUploading,
        ),
      );
    }

    if (images.length == 2) {
      return SizedBox(
        width: 250.w,
        height: 150.h,
        child: Row(
          children: [
            Expanded(
              child: _buildImageTile(
                context: context,
                path: images[0],
                allImages: images,
                index: 0,
                isUploading: isUploading,
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: _buildImageTile(
                context: context,
                path: images[1],
                allImages: images,
                index: 1,
                isUploading: isUploading,
              ),
            ),
          ],
        ),
      );
    }

    if (images.length == 3) {
      return SizedBox(
        width: 250.w,
        height: 220.h,
        child: Column(
          children: [
            Expanded(
              flex: 12,
              child: _buildImageTile(
                context: context,
                path: images[0],
                allImages: images,
                index: 0,
                isUploading: isUploading,
              ),
            ),
            SizedBox(height: 2.h),
            Expanded(
              flex: 9,
              child: Row(
                children: [
                  Expanded(
                    child: _buildImageTile(
                      context: context,
                      path: images[1],
                      allImages: images,
                      index: 1,
                      isUploading: isUploading,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: _buildImageTile(
                      context: context,
                      path: images[2],
                      allImages: images,
                      index: 2,
                      isUploading: isUploading,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final displayList = images.take(4).toList();
    final int extraCount = images.length - 4;

    return SizedBox(
      width: 250.w,
      height: 220.h,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildImageTile(
                    context: context,
                    path: displayList[0],
                    allImages: images,
                    index: 0,
                    isUploading: isUploading,
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _buildImageTile(
                    context: context,
                    path: displayList[1],
                    allImages: images,
                    index: 1,
                    isUploading: isUploading,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildImageTile(
                    context: context,
                    path: displayList[2],
                    allImages: images,
                    index: 2,
                    isUploading: isUploading,
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _buildImageTile(
                    context: context,
                    path: displayList[3],
                    allImages: images,
                    index: 3,
                    isUploading: isUploading,
                    extraCount: extraCount,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTile({
    required BuildContext context,
    required String path,
    double? width,
    double? height,
    required List<String> allImages,
    required int index,
    bool isUploading = false,
    int extraCount = 0,
  }) {
    final l10n = context.l10n;
    final bool isLocal = !path.startsWith('http://') && !path.startsWith('https://');

    Widget tile = Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: context.isDark ? const Color(0xFF1E1E2C) : Colors.black12,
          child: isLocal
              ? (File(path).existsSync()
                  ? Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildImageError(),
                    )
                  : _buildImageError())
              : Image.network(
                  path,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 24.r,
                        height: 24.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => _buildImageError(),
                ),
        ),
        if (extraCount > 0)
          Container(
            color: Colors.black.withValues(alpha: 0.55),
            alignment: Alignment.center,
            child: Text(
              '+$extraCount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (isUploading && index == 0)
          Container(
            color: Colors.black.withValues(alpha: 0.45),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  l10n.sending,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (width != null || height != null) {
      tile = SizedBox(
        width: width,
        height: height,
        child: tile,
      );
    }

    return GestureDetector(
      onTap: () => onImageTap(index),
      child: tile,
    );
  }

  Widget _buildImageError() {
    return Container(
      color: Colors.grey.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_rounded, size: 28.r, color: Colors.grey),
    );
  }
}

