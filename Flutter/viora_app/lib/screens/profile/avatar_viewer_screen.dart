import '../../l10n/language.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/app_colors.dart';
import '../../widgets/toast/app_toast.dart';

class AvatarViewerScreen extends StatefulWidget {
  final String? imageUrl;
  final String? title;
  final String? fallbackText;
  final Color? fallbackColor;
  final String? heroTag;

  const AvatarViewerScreen({
    super.key,
    this.imageUrl,
    this.title,
    this.fallbackText,
    this.fallbackColor,
    this.heroTag,
  });

  @override
  State<AvatarViewerScreen> createState() => _AvatarViewerScreenState();
}

class _AvatarViewerScreenState extends State<AvatarViewerScreen>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  double _currentScale = 1.0;
  bool _showControls = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.02) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _animateTransformation(Matrix4 target) {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward(from: 0);
  }

  void _handleDoubleTap() {
    if (_currentScale > 1.2) {
      _resetZoom();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final target = Matrix4.translationValues(-position.dx * 1.5, -position.dy * 1.5, 0.0)
        ..multiply(Matrix4.diagonal3Values(2.5, 2.5, 1.0));
      _animateTransformation(target);
    }
  }


  void _resetZoom() {
    _animateTransformation(Matrix4.identity());
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  Future<void> _downloadImage() async {
    final url = widget.imageUrl;
    if (url == null || url.trim().isEmpty) {
      AppToast.info(context, l10n.noImageToDownload);
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        bool saved = false;

        if (!kIsWeb && Platform.isAndroid) {
          final possibleDirs = [
            Directory('/storage/emulated/0/Download'),
            Directory('/storage/emulated/0/Pictures'),
            Directory('/storage/emulated/0/DCIM/Camera'),
            Directory('/storage/emulated/0/DCIM'),
          ];

          Directory? targetDir;
          for (final dir in possibleDirs) {
            try {
              if (dir.existsSync()) {
                targetDir = dir;
                break;
              }
            } catch (_) {}
          }

          if (targetDir != null) {
            final fileName =
                'viora_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final file = File('${targetDir.path}/$fileName');
            await file.writeAsBytes(bytes);
            saved = true;
          }
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
          AppToast.error(
              context, '${l10n.cannotDownloadImage} (${response.statusCode})');
        }
      }
    } catch (e) {
      debugPrint('Download avatar error: $e');
      if (mounted) {
        AppToast.error(
            context, l10n.requestConnectionError);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasImage = widget.imageUrl != null &&
        widget.imageUrl!.trim().isNotEmpty &&
        (widget.imageUrl!.trim().startsWith('http://') ||
            widget.imageUrl!.trim().startsWith('https://') ||
            widget.imageUrl!.trim().startsWith('assets/'));
    final defaultTitle = l10n.avatar;
    final title = widget.title ?? defaultTitle;
    final initial = widget.fallbackText ??
        (widget.title != null &&
                widget.title!.trim().isNotEmpty &&
                widget.title != defaultTitle
            ? widget.title!.trim()[0].toUpperCase()
            : 'U');
    final avatarColor = widget.fallbackColor ?? AppColors.blue;

    Widget imageContent;

    if (hasImage) {
      imageContent = Image.network(
        widget.imageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final totalBytes = loadingProgress.expectedTotalBytes;
          final loadedBytes = loadingProgress.cumulativeBytesLoaded;
          final progress = totalBytes != null && totalBytes > 0
              ? loadedBytes / totalBytes
              : null;

          return Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2.5,
                color: AppColors.blue,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 80,
                  backgroundColor: avatarColor,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    l10n.cannotLoadOriginalImage,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      imageContent = Center(
        child: CircleAvatar(
          radius: 100,
          backgroundColor: avatarColor,
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (widget.heroTag != null) {
      imageContent = Hero(
        tag: widget.heroTag!,
        createRectTween: (begin, end) =>
            MaterialRectCenterArcTween(begin: begin, end: end),
        child: Material(
          type: MaterialType.transparency,
          child: imageContent,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTapDown: (details) => _doubleTapDetails = details,
            onDoubleTap: _handleDoubleTap,
            onVerticalDragEnd: (details) {
              if (_currentScale <= 1.05 &&
                  details.primaryVelocity != null &&
                  details.primaryVelocity!.abs() > 250) {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.8,
                maxScale: 5.0,
                panEnabled: true,
                scaleEnabled: true,
                clipBehavior: Clip.none,
                child: Center(
                  child: imageContent,
                ),
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 8,
                16,
                16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [

                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasImage
                              ? l10n.doubleTapToZoom
                              : l10n.noAvatarUpdated,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: _isDownloading ? null : _downloadImage,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: _isDownloading
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
