import '../../l10n/language.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/app_colors.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';

class PostImageViewerScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String? authorName;
  final String? authorAvatar;
  final String? postTime;
  final String? postContent;

  const PostImageViewerScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.authorName,
    this.authorAvatar,
    this.postTime,
    this.postContent,
  });

  @override
  State<PostImageViewerScreen> createState() => _PostImageViewerScreenState();
}

class _PostImageViewerScreenState extends State<PostImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  bool _isDownloading = false;
  bool _isTextExpanded = false;

  final Map<int, TransformationController> _transformControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.isEmpty ? 0 : widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  TransformationController _getController(int index) {
    return _transformControllers.putIfAbsent(index, () => TransformationController());
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _transformControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _handleDoubleTap(int index) {
    final controller = _getController(index);
    if (controller.value.getMaxScaleOnAxis() > 1.2) {
      controller.value = Matrix4.identity();
    } else {
      controller.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
    }
  }

  Future<void> _downloadCurrentImage() async {
    if (widget.images.isEmpty || _isDownloading) return;
    final currentUrl = widget.images[_currentIndex];

    if (!currentUrl.startsWith('http://') && !currentUrl.startsWith('https://')) {
      AppToast.success(context, l10n.imageAlreadyOnDevice);
      return;
    }

    setState(() => _isDownloading = true);

    try {
      final response = await http.get(Uri.parse(currentUrl)).timeout(const Duration(seconds: 25));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final possibleDirs = [
          Directory('/storage/emulated/0/Download'),
          Directory('/storage/emulated/0/Pictures'),
          Directory('/storage/emulated/0/DCIM/Camera'),
        ];

        bool saved = false;
        for (final dir in possibleDirs) {
          try {
            if (dir.existsSync()) {
              final fileName = 'viora_post_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final file = File('${dir.path}/$fileName');
              await file.writeAsBytes(bytes);
              saved = true;
              break;
            }
          } catch (_) {}
        }

        if (mounted) {
          if (saved) {
            AppToast.success(context, l10n.imageSavedToDownloads);
          } else {
            AppToast.success(context, l10n.downloadImageSuccess);
          }
        }
      } else {
        if (mounted) {
          AppToast.error(context, '${l10n.downloadImageError} (${response.statusCode})');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.downloadConnectionError);
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.images.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.noImageFound, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ],
          ),
        ),
      );
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          GestureDetector(
            onTap: _toggleControls,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                });
                for (final key in _transformControllers.keys) {
                  if (key != idx) {
                    _transformControllers[key]?.value = Matrix4.identity();
                  }
                }
              },
              itemBuilder: (context, index) {
                final imgPath = widget.images[index];
                final isLocal = !imgPath.startsWith('http://') && !imgPath.startsWith('https://');
                final controller = _getController(index);

                return GestureDetector(
                  onDoubleTap: () => _handleDoubleTap(index),
                  child: InteractiveViewer(
                    transformationController: controller,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(
                      child: isLocal
                          ? Image.file(
                              File(imgPath),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white54,
                                size: 54,
                              ),
                            )
                          : Image.network(
                              imgPath,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 38,
                                    height: 38,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white.withValues(alpha: 0.8),
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white54,
                                size: 54,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            top: _showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: topPadding + 6,
                bottom: 12,
                left: 14,
                right: 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (widget.images.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _downloadCurrentImage,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: _isDownloading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            bottom: _showControls ? 0 : -220,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: 24,
                bottom: bottomPadding + 12,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  if (widget.authorName != null && widget.authorName!.isNotEmpty)
                    Row(
                      children: [
                        AppAvatar(
                          avatar: widget.authorAvatar,
                          name: widget.authorName,
                          radius: 18,
                          enableViewer: false,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.authorName!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (widget.postTime != null && widget.postTime!.isNotEmpty)
                                Text(
                                  widget.postTime!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  if (widget.postContent != null && widget.postContent!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isTextExpanded = !_isTextExpanded;
                        });
                      },
                      child: Text(
                        widget.postContent!.trim(),
                        maxLines: _isTextExpanded ? 10 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  if (widget.images.length > 1) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.images.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, thumbIdx) {
                          final thumbImg = widget.images[thumbIdx];
                          final isLocalThumb = !thumbImg.startsWith('http://') && !thumbImg.startsWith('https://');
                          final isSelected = thumbIdx == _currentIndex;

                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                thumbIdx,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.blue : Colors.white.withValues(alpha: 0.25),
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Opacity(
                                  opacity: isSelected ? 1.0 : 0.6,
                                  child: isLocalThumb
                                      ? Image.file(
                                          File(thumbImg),
                                          fit: BoxFit.cover,
                                        )
                                      : Image.network(
                                          thumbImg,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Colors.white12,
                                            child: const Icon(Icons.broken_image, size: 20, color: Colors.white38),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
