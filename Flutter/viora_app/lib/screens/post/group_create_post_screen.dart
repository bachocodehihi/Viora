import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/post_service.dart';
import '../../services/session_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/toast/app_toast.dart';
import '../../l10n/language.dart';

class GroupCreatePostScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupAvatar;
  final String? userAvatar;
  final String? userName;

  const GroupCreatePostScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupAvatar,
    this.userAvatar,
    this.userName,
  });

  @override
  State<GroupCreatePostScreen> createState() => _GroupCreatePostScreenState();
}

class _GroupCreatePostScreenState extends State<GroupCreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<File> _selectedImages = [];
  bool _isAnonymous = false;
  bool _isPublishing = false;

  String? _myAvatar;
  String? _myName;

  @override
  void initState() {
    super.initState();
    _myAvatar = widget.userAvatar;
    _myName = widget.userName;
    _loadUserSession();
    _textController.addListener(() => setState(() {}));
  }

  Future<void> _loadUserSession() async {
    if (_myAvatar != null && _myName != null) return;
    final av = _myAvatar ?? await SessionService.getAvatar();
    final name = _myName ?? await SessionService.getUsername();
    if (mounted) {
      setState(() {
        _myAvatar = av;
        _myName = name;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      (_textController.text.trim().isNotEmpty || _selectedImages.isNotEmpty) &&
      !_isPublishing;

  Future<void> _pickImages(ImageSource source) async {
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        final List<XFile> picked = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1920,
        );
        if (picked.isNotEmpty && mounted) {
          setState(() {
            for (final x in picked) {
              if (_selectedImages.length < 10) {
                _selectedImages.add(File(x.path));
              }
            }
          });
        }
      } else {
        final XFile? picked = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
        );
        if (picked != null && mounted) {
          setState(() {
            if (_selectedImages.length < 10) {
              _selectedImages.add(File(picked.path));
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        AppToast.error(context, l10n.cannotPickImage);
      }
    }
  }

  Future<void> _submitPost() async {
    final text = _textController.text.trim();
    if (!_canSubmit) return;

    setState(() => _isPublishing = true);

    try {
      final result = await PostService.publishPost(
        content: text,
        groupId: widget.groupId,
        imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
        isAnonymous: _isAnonymous,
        userName: _myName,
      );

      if (!mounted) return;

      if (result.success) {
        AppToast.success(context, l10n.postToGroupSuccess);
        Navigator.pop(context, true);
      } else {
        final errorMsg = l10n.errorFromCode(result.code, fallbackMessage: result.message);
        AppToast.error(context, errorMsg);
      }
    } catch (e) {
      debugPrint('Submit group post error: $e');
      if (mounted) {
        AppToast.error(context, '${l10n.errorPostingPostPrefix}$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.textPrimary, size: 24.r),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.createGroupPostTitle,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            Text(
              widget.groupName,
              style: TextStyle(
                fontSize: 12.sp,
                color: context.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: ElevatedButton(
              onPressed: _canSubmit ? _submitPost : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
              ),
              child: _isPublishing
                  ? SizedBox(
                      width: 16.r,
                      height: 16.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.post,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    children: [
                      if (_isAnonymous)
                        Container(
                          width: 44.r,
                          height: 44.r,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.visibility_off_rounded,
                            color: Colors.white70,
                            size: 22.r,
                          ),
                        )
                      else
                        AppAvatar(
                          avatar: _myAvatar,
                          name: _myName,
                          radius: 22.r,
                          fontSize: 15.sp,
                        ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAnonymous ? l10n.anonymousMember : (_myName ?? l10n.you),
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: _isAnonymous
                                    ? Colors.orangeAccent.withValues(alpha: 0.15)
                                    : AppColors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: _isAnonymous
                                      ? Colors.orangeAccent.withValues(alpha: 0.4)
                                      : AppColors.blue.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isAnonymous ? Icons.shield_rounded : Icons.groups_rounded,
                                    size: 12.r,
                                    color: _isAnonymous ? Colors.orangeAccent : AppColors.blue,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    _isAnonymous ? l10n.anonymousPostLabel : l10n.postInGroupLabel,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _isAnonymous ? Colors.orangeAccent : AppColors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16.h),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: _isAnonymous
                            ? Colors.orangeAccent.withValues(alpha: 0.5)
                            : context.borderTheme,
                        width: _isAnonymous ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: _isAnonymous
                                ? Colors.orangeAccent.withValues(alpha: 0.15)
                                : context.textMuted.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.visibility_off_rounded,
                            size: 18.r,
                            color: _isAnonymous ? Colors.orangeAccent : context.textMuted,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.postAnonymously,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                              Text(
                                l10n.anonymousPostDesc,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSwitch(
                          value: _isAnonymous,
                          activeColor: Colors.orangeAccent,
                          onChanged: (val) {
                            setState(() {
                              _isAnonymous = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  if (_isAnonymous) ...[
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: Colors.orangeAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14.r, color: Colors.orangeAccent),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              l10n.anonymousNotice,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 16.h),

                  TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: null,
                    minLines: 5,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: context.textPrimary,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.groupPostHint(widget.groupName),
                      hintStyle: TextStyle(
                        fontSize: 16.sp,
                        color: context.textMuted.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  if (_selectedImages.isNotEmpty) ...[
                    SizedBox(height: 16.h),
                    Text(
                      l10n.attachedImagesCount(_selectedImages.length, 10),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _selectedImages.length == 1 ? 1 : 2,
                        crossAxisSpacing: 8.w,
                        mainAxisSpacing: 8.h,
                        childAspectRatio: _selectedImages.length == 1 ? 1.6 : 1.0,
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        final file = _selectedImages[index];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: Image.file(
                                file,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6.r,
                              right: 6.r,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.all(5.r),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14.r,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],

                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: context.cardBg,
              border: Border(
                top: BorderSide(color: context.borderTheme, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Text(
                  l10n.addToPost,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.photo_library_rounded, color: Colors.green, size: 24.r),
                  onPressed: () => _pickImages(ImageSource.gallery),
                ),
                IconButton(
                  icon: Icon(Icons.camera_alt_rounded, color: Colors.blue, size: 24.r),
                  onPressed: () => _pickImages(ImageSource.camera),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
