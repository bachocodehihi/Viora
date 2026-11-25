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
import '../../widgets/bottomsheet/app_livestream_setup_bottomsheet.dart';

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
    _focusNode.addListener(() => setState(() {}));
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

    final borderColor = _focusNode.hasFocus
        ? AppColors.blue
        : (context.isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.15));
    final borderWidth = _focusNode.hasFocus ? 1.5 : 1.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.createGroupPostTitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              Text(
                widget.groupName,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: context.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 10.0, bottom: 10.0),
              child: ElevatedButton(
                onPressed: (_canSubmit && !_isPublishing) ? _submitPost : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: context.isDark ? const Color(0xFF252332) : Colors.black.withValues(alpha: 0.08),
                  disabledForegroundColor: context.textSubtle,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isPublishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.post,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
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
                            padding: EdgeInsets.all(7.r),
                            decoration: BoxDecoration(
                              color: _isAnonymous
                                  ? Colors.orangeAccent.withValues(alpha: 0.15)
                                  : context.textMuted.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.visibility_off_rounded,
                              size: 17.r,
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
                                    fontSize: 13.5.sp,
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
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
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
                                  fontSize: 11.sp,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            autofocus: false,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            textAlignVertical: TextAlignVertical.top,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: context.textPrimary,
                              fontSize: 16,
                              height: 1.45,
                            ),
                            decoration: InputDecoration(
                              filled: false,
                              fillColor: Colors.transparent,
                              hintText: l10n.groupPostHint(widget.groupName),
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                color: context.textPlaceholder,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),

                        if (_selectedImages.isNotEmpty)
                          Container(
                            height: 105,
                            margin: const EdgeInsets.only(top: 12),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedImages.length + (_selectedImages.length < 10 ? 1 : 0),
                              separatorBuilder: (context, index) => const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                if (index == _selectedImages.length) {
                                  return GestureDetector(
                                    onTap: () => _pickImages(ImageSource.gallery),
                                    child: Container(
                                      width: 95,
                                      height: 95,
                                      decoration: BoxDecoration(
                                        color: context.actionPillBg,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: context.borderTheme,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.add_photo_alternate_rounded, color: AppColors.blue, size: 28),
                                          const SizedBox(height: 4),
                                          Text(l10n.add, style: TextStyle(fontSize: 11, color: context.textMuted)),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final file = _selectedImages[index];
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        file,
                                        width: 95,
                                        height: 95,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.borderTheme,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.homeShadow,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      l10n.addAnArticle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.photo_library_rounded, color: AppColors.teal, size: 22),
                      onPressed: () => _pickImages(ImageSource.gallery),
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_rounded, color: AppColors.blue, size: 22),
                      onPressed: () => _pickImages(ImageSource.camera),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sensors_rounded, color: Color(0xFFFF416C), size: 23),
                      tooltip: l10n.liveBadge,
                      onPressed: () {
                        AppLivestreamSetupBottomSheet.show(
                          context,
                          userAvatar: _myAvatar,
                          userName: _myName,
                          groupId: widget.groupId,
                          groupName: widget.groupName,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
