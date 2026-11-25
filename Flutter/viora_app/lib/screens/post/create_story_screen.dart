import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../l10n/language.dart';
import '../../services/story_service.dart';
import '../../widgets/toast/app_toast.dart';

class CreateStoryScreen extends StatefulWidget {
  final String? userAvatar;
  final String? userName;

  const CreateStoryScreen({
    super.key,
    this.userAvatar,
    this.userName,
  });

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedMedia;
  bool _isTextStory = true;
  bool _isPosting = false;
  final String _privacy = 'friends';

  final List<List<Color>> _presetGradients = const [
    [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
    [Color(0xFF4A00E0), Color(0xFF8E2DE2)], // Purple
    [Color(0xFF00C6FF), Color(0xFF0072FF)], // Ocean
    [Color(0xFF11998E), Color(0xFF38EF7D)], // Emerald
    [Color(0xFFF857A6), Color(0xFFFF5858)], // Pink
    [Color(0xFF141E30), Color(0xFF243B55)], // Dark Royal
    [Color(0xFF000000), Color(0xFF434343)], // Charcoal
  ];

  int _selectedGradientIndex = 0;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1440,
        maxHeight: 2560,
        imageQuality: 88,
      );
      if (picked != null) {
        setState(() {
          _selectedMedia = File(picked.path);
          _isTextStory = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  String _getGradientHex() {
    final colors = _presetGradients[_selectedGradientIndex];
    return colors.map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}').join(',');
  }

  Future<void> _handlePost() async {
    if (_isPosting) return;
    final l10n = context.l10n;

    final content = _textController.text.trim();
    if (_isTextStory && content.isEmpty) {
      AppToast.show(context, l10n.enterStoryContentPrompt, isError: true);
      return;
    }

    if (!_isTextStory && _selectedMedia == null) {
      AppToast.show(context, l10n.chooseStoryImagePrompt, isError: true);
      return;
    }

    setState(() => _isPosting = true);

    try {
      final success = await StoryService.createStory(
        mediaFile: _isTextStory ? null : _selectedMedia,
        content: content,
        mediaType: _isTextStory ? 'text' : 'image',
        backgroundColor: _getGradientHex(),
        privacy: _privacy,
      );

      if (mounted) {
        if (success) {
          AppToast.success(context, l10n.storyPostSuccess);
          Navigator.pop(context, true);
        } else {
          AppToast.show(context, l10n.storyPostFailed, isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '$e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentGradient = _presetGradients[_selectedGradientIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [

            Positioned.fill(
              child: _isTextStory
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: currentGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontFamily,
                          fontFamilyFallback: AppTheme.fontFallback,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2)),
                          ],
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.tapToTypeStoryHint,
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w500,
                            fontFamily: AppTheme.fontFamily,
                            fontFamilyFallback: AppTheme.fontFallback,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    )
                  : (_selectedMedia != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              _selectedMedia!,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 120.h,
                              left: 20.w,
                              right: 20.w,
                              child: TextField(
                                controller: _textController,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n.addCaptionStoryHint,
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 16.sp,
                                  ),
                                  filled: true,
                                  fillColor: Colors.black.withValues(alpha: 0.4),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20.r),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(color: Colors.black)),
            ),

            Positioned(
              top: 10.h,
              left: 16.w,
              right: 16.w,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white, size: 28.r),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isTextStory = true;
                              _selectedMedia = null;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: _isTextStory ? AppColors.blue : Colors.transparent,
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.title_rounded, color: Colors.white, size: 16.r),
                                SizedBox(width: 4.w),
                                Text(l10n.storyTextMode, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        GestureDetector(
                          onTap: () => _pickImage(ImageSource.gallery),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: !_isTextStory ? AppColors.blue : Colors.transparent,
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.photo_library_rounded, color: Colors.white, size: 16.r),
                                SizedBox(width: 4.w),
                                Text(l10n.storyPhotoMode, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26.r),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ],
              ),
            ),

            if (_isTextStory)
              Positioned(
                bottom: 90.h,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 44.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    itemCount: _presetGradients.length,
                    itemBuilder: (ctx, i) {
                      final isSelected = _selectedGradientIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedGradientIndex = i),
                        child: Container(
                          width: 36.r,
                          height: 36.r,
                          margin: EdgeInsets.symmetric(horizontal: 6.w),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _presetGradients[i],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            boxShadow: [
                              BoxShadow(color: Colors.black38, blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            Positioned(
              bottom: 20.h,
              left: 20.w,
              right: 20.w,
              child: SizedBox(
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _handlePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                    elevation: 4,
                  ),
                  child: _isPosting
                      ? SizedBox(
                          width: 24.r,
                          height: 24.r,
                          child: const CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 20.r),
                            SizedBox(width: 8.w),
                            Text(
                              l10n.shareToStory,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
