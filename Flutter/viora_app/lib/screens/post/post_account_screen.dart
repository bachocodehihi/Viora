import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/contact_service.dart';
import '../../services/post_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';

class PostAccountScreen extends StatefulWidget {
  final String email;
  final String? userAvatar;
  final String? userName;

  const PostAccountScreen({
    super.key,
    required this.email,
    this.userAvatar,
    this.userName,
  });

  @override
  State<PostAccountScreen> createState() => _PostAccountScreenState();
}

class _PostAccountScreenState extends State<PostAccountScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<File> _selectedImages = [];
  bool _hasContent = false;
  bool _isPublishing = false;
  String _privacyOption = 'Public';
  List<Map<String, dynamic>> _exceptedFriends = [];
  List<Map<String, dynamic>> _allowedFriends = [];
  List<Map<String, dynamic>> _friendsList = [];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    _updateHasContent();
  }

  void _updateHasContent() {
    final hasText = _textController.text.trim().isNotEmpty;
    final hasImages = _selectedImages.isNotEmpty;
    final hasContent = hasText || hasImages;
    if (hasContent != _hasContent) {
      setState(() {
        _hasContent = hasContent;
      });
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> picked = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked.isNotEmpty && mounted) {
        setState(() {
          for (var x in picked) {
            if (_selectedImages.length < 10) {
              _selectedImages.add(File(x.path));
            }
          }
        });
        _updateHasContent();
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        AppToast.error(context, l10n.cannotOpenGallery);
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (photo != null && mounted) {
        setState(() {
          if (_selectedImages.length < 10) {
            _selectedImages.add(File(photo.path));
          }
        });
        _updateHasContent();
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        AppToast.error(context, l10n.cannotOpenCamera);
      }
    }
  }

  void _showMediaPickerSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textSubtle.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.addPhotoToPost,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.teal, size: 22),
                ),
                title: Text(l10n.chooseFromGallery, style: TextStyle(fontFamily: 'Inter', color: context.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text(l10n.chooseMultiplePhotos, style: TextStyle(fontFamily: 'Inter', color: context.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImagesFromGallery();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.blue, size: 22),
                ),
                title: Text(l10n.takeNewPhoto, style: TextStyle(fontFamily: 'Inter', color: context.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text(l10n.openCameraInstant, style: TextStyle(fontFamily: 'Inter', color: context.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _takePhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage(int index) {
    if (index >= 0 && index < _selectedImages.length) {
      setState(() {
        _selectedImages.removeAt(index);
      });
      _updateHasContent();
    }
  }

  Future<void> _submitPost() async {
    final content = _textController.text.trim();
    if (content.isEmpty && _selectedImages.isEmpty) return;
    if (_isPublishing) return;

    setState(() {
      _isPublishing = true;
    });

    String privacyValue = 'public';
    List<String>? allowedIds;
    List<String>? exceptedIds;

    if (_privacyOption == 'Friends') {
      privacyValue = 'friends';
    } else if (_privacyOption == 'FriendsExcept') {
      privacyValue = 'friends_except';
      exceptedIds = _exceptedFriends.map((f) => f['id'].toString()).toList();
    } else if (_privacyOption == 'SpecificFriends') {
      privacyValue = 'specific_friends';
      allowedIds = _allowedFriends.map((f) => f['id'].toString()).toList();
    } else if (_privacyOption == 'Only Me') {
      privacyValue = 'private';
    }

    try {
      final result = await PostService.publishPost(
        content: content,
        privacy: privacyValue,
        allowedFriends: allowedIds,
        exceptedFriends: exceptedIds,
        imageFiles: _selectedImages,
        email: widget.email,
        userName: widget.userName,
      );

      if (!mounted) return;

      if (result.success) {
        final postData = result.post;
        final initialLetter = widget.email.isNotEmpty ? widget.email[0].toUpperCase() : 'B';
        final fallbackName = widget.email.contains('@') ? widget.email.split('@')[0] : (widget.email.isNotEmpty ? widget.email : 'bach');
        final displayName = widget.userName != null && widget.userName!.isNotEmpty ? widget.userName! : fallbackName;

        final newPost = {
          'id': postData?['_id']?.toString() ?? postData?['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'userName': displayName,
          'avatar': widget.userAvatar ?? initialLetter,
          'color': AppColors.blue,
          'time': 'just_now',
          'content': content,
          'images': postData?['images'] ?? _selectedImages.map((f) => f.path).toList(),
          'likes': 0,
          'comments': 0,
          'isLiked': false,
        };

        AppToast.success(context, result.message.isNotEmpty ? result.message : l10n.postCreatedSuccess);
        Navigator.pop(context, newPost);
      } else {
        setState(() {
          _isPublishing = false;
        });
        AppToast.error(context, result.message);
      }
    } catch (e) {
      debugPrint('Submit post error: $e');
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
        AppToast.error(context, l10n.postFailedError);
      }
    }
  }

  IconData get _privacyIcon {
    switch (_privacyOption) {
      case 'Friends':
        return Icons.people_rounded;
      case 'FriendsExcept':
        return Icons.person_remove_rounded;
      case 'SpecificFriends':
        return Icons.person_add_alt_1_rounded;
      case 'Only Me':
        return Icons.lock_rounded;
      case 'Public':
      default:
        return Icons.public_rounded;
    }
  }

  String get _privacyLabel {
    switch (_privacyOption) {
      case 'Friends':
        return l10n.friends;
      case 'FriendsExcept':
        return _exceptedFriends.isNotEmpty
            ? l10n.friendsExceptCount(_exceptedFriends.length)
            : l10n.friendsExcept;
      case 'SpecificFriends':
        return _allowedFriends.isNotEmpty
            ? l10n.specificFriendsCount(_allowedFriends.length)
            : l10n.specificFriends;
      case 'Only Me':
        return l10n.onlyMe;
      case 'Public':
      default:
        return l10n.public;
    }
  }

  Future<void> _loadFriends() async {
    if (_friendsList.isNotEmpty) return;
    try {
      final data = await ContactService.fetchContacts();
      if (data != null && data['friends'] != null && mounted) {
        setState(() {
          _friendsList = List<Map<String, dynamic>>.from(data['friends']);
        });
      }
    } catch (_) {}
  }

  Future<void> _showFriendPicker({required bool isExcluding}) async {
    _loadFriends();

    final initialSelected = isExcluding
        ? List<Map<String, dynamic>>.from(_exceptedFriends)
        : List<Map<String, dynamic>>.from(_allowedFriends);

    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      backgroundColor: context.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _FriendPickerModal(
          title: isExcluding ? l10n.friendsExcept : l10n.specificFriends,
          isExcluding: isExcluding,
          initialSelected: initialSelected,
          cachedFriends: _friendsList,
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        if (isExcluding) {
          _exceptedFriends = result;
          _privacyOption = 'FriendsExcept';
        } else {
          _allowedFriends = result;
          _privacyOption = 'SpecificFriends';
        }
      });
    }
  }

  void _showPrivacyPicker() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.textSubtle.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      l10n.whoCanSeePost,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.public_rounded, color: AppColors.blue),
                    title: Text(l10n.public, style: TextStyle(fontFamily: 'Inter', color: context.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(l10n.anyoneOnViora, style: TextStyle(fontFamily: 'Inter', color: context.textMuted, fontSize: 12)),
                    trailing: _privacyOption == 'Public' ? const Icon(Icons.check_circle_rounded, color: AppColors.blue) : null,
                    onTap: () {
                      setState(() => _privacyOption = 'Public');
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_rounded, color: AppColors.teal),
                    title: Text(l10n.friends, style: TextStyle(fontFamily: 'Inter', color: context.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(l10n.allFriendsOnViora, style: TextStyle(fontFamily: 'Inter', color: context.textMuted, fontSize: 12)),
                    trailing: _privacyOption == 'Friends' ? const Icon(Icons.check_circle_rounded, color: AppColors.blue) : null,
                    onTap: () {
                      setState(() => _privacyOption = 'Friends');
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_remove_rounded, color: AppColors.orange),
                    title: Text(l10n.friendsExcept, style: TextStyle(fontFamily: 'Inter', color: context.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _exceptedFriends.isNotEmpty
                          ? '${l10n.friendsExcept}: ${_exceptedFriends.map((f) => f['name']).take(2).join(', ')}${_exceptedFriends.length > 2 ? ' +${_exceptedFriends.length - 2}' : ''}'
                          : l10n.allFriendsExceptFew,
                      style: TextStyle(fontFamily: 'Inter', color: context.textMuted, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_privacyOption == 'FriendsExcept')
                          const Icon(Icons.check_circle_rounded, color: AppColors.blue),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textSubtle),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showFriendPicker(isExcluding: true);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.purple),
                    title: Text(l10n.specificFriends, style: TextStyle(fontFamily: 'Inter', color: context.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _allowedFriends.isNotEmpty
                          ? '${l10n.specificFriends}: ${_allowedFriends.map((f) => f['name']).take(2).join(', ')}${_allowedFriends.length > 2 ? ' +${_allowedFriends.length - 2}' : ''}'
                          : l10n.onlyShowToSpecificFriends,
                      style: TextStyle(fontFamily: 'Inter', color: context.textMuted, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_privacyOption == 'SpecificFriends')
                          const Icon(Icons.check_circle_rounded, color: AppColors.blue),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textSubtle),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showFriendPicker(isExcluding: false);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_rounded, color: AppColors.pink),
                    title: Text(l10n.onlyMe, style: TextStyle(fontFamily: 'Inter', color: context.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(l10n.onlyYouCanSee, style: TextStyle(fontFamily: 'Inter', color: context.textMuted, fontSize: 12)),
                    trailing: _privacyOption == 'Only Me' ? const Icon(Icons.check_circle_rounded, color: AppColors.blue) : null,
                    onTap: () {
                      setState(() => _privacyOption = 'Only Me');
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fallbackName = widget.email.contains('@') ? widget.email.split('@')[0] : (widget.email.isNotEmpty ? widget.email : 'bach');
    final displayName = widget.userName != null && widget.userName!.isNotEmpty ? widget.userName! : fallbackName;

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
          backgroundColor: context.scaffoldBg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            l10n.createPost,
            style: TextStyle(
              fontFamily: 'Inter',
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 10.0, bottom: 10.0),
              child: ElevatedButton(
                onPressed: (_hasContent && !_isPublishing) ? _submitPost : null,
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: context.dividerTheme,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Row(
                  children: [
                    AppAvatar(
                      avatar: widget.userAvatar,
                      name: displayName,
                      radius: 23,
                      fontSize: 16,
                      enableViewer: true,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _showPrivacyPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.actionPillBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: context.borderTheme,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _privacyIcon,
                                  size: 13,
                                  color: context.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _privacyLabel,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: context.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 16,
                                  color: context.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
                            autofocus: true,
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
                              hintText: l10n.whatsOnYourMind,
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
                                    onTap: _showMediaPickerSheet,
                                    child: Container(
                                      width: 95,
                                      height: 95,
                                      decoration: BoxDecoration(
                                        color: context.actionPillBg,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: context.borderTheme,
                                          style: BorderStyle.solid,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate_rounded, color: AppColors.blue, size: 28),
                                          const SizedBox(height: 4),
                                          Text(l10n.add, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: context.textMuted)),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final imageFile = _selectedImages[index];
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        imageFile,
                                        width: 95,
                                        height: 95,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
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
                      onPressed: _showMediaPickerSheet,
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_rounded, color: AppColors.blue, size: 22),
                      onPressed: _takePhoto,
                    ),
                    IconButton(
                      icon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: AppColors.orange, size: 22),
                      onPressed: () {
                        _textController.text += ' 😊';
                        _updateHasContent();
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

class _FriendPickerModal extends StatefulWidget {
  final String title;
  final bool isExcluding;
  final List<Map<String, dynamic>> initialSelected;
  final List<Map<String, dynamic>> cachedFriends;

  const _FriendPickerModal({
    required this.title,
    required this.isExcluding,
    required this.initialSelected,
    required this.cachedFriends,
  });

  @override
  State<_FriendPickerModal> createState() => _FriendPickerModalState();
}

class _FriendPickerModalState extends State<_FriendPickerModal> {
  late List<Map<String, dynamic>> _friends;
  late Set<String> _selectedIds;
  late Map<String, Map<String, dynamic>> _selectedMap;
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _friends = List<Map<String, dynamic>>.from(widget.cachedFriends);
    _selectedIds = {};
    _selectedMap = {};

    for (final f in widget.initialSelected) {
      final id = f['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        _selectedIds.add(id);
        _selectedMap[id] = f;
      }
    }

    if (_friends.isEmpty) {
      _isLoading = true;
      _fetchFriends();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFriends() async {
    try {
      final data = await ContactService.fetchContacts();
      if (data != null && data['friends'] != null && mounted) {
        setState(() {
          _friends = List<Map<String, dynamic>>.from(data['friends']);
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtered = _friends.where((f) {
      final name = (f['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.textSubtle.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final selectedList = _selectedIds.map((id) {
                      return _selectedMap[id] ??
                          _friends.firstWhere(
                            (f) => f['id'].toString() == id,
                            orElse: () => {'id': id, 'name': l10n.friends},
                          );
                    }).toList();
                    Navigator.pop(context, selectedList);
                  },
                  child: Text(
                    l10n.done,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(
                fontFamily: 'Inter',
                color: context.textPrimary,
                fontSize: 14.5,
              ),
              decoration: InputDecoration(
                hintText: l10n.searchFriendsHint,
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  color: context.textPlaceholder,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: context.textMuted,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: context.textMuted,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                fillColor: context.cardBg,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: context.isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: context.isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
                : (filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty ? l10n.noFriendsFound : l10n.noFriendsYet,
                          style: TextStyle(fontFamily: 'Inter', color: context.textMuted, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemBuilder: (ctx, i) {
                          final friend = filtered[i];
                          final id = friend['id']?.toString() ?? '';
                          final isSelected = _selectedIds.contains(id);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: AppAvatar(
                              avatar: friend['avatar'],
                              name: friend['name']?.toString(),
                              color: AppColors.blue,
                              radius: 20,
                            ),
                            title: Text(
                              friend['name']?.toString() ?? '',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            trailing: widget.isExcluding
                                ? Icon(
                                    isSelected
                                        ? Icons.remove_circle_rounded
                                        : Icons.circle_outlined,
                                    color: isSelected ? AppColors.red : context.textSubtle,
                                    size: 22,
                                  )
                                : Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: isSelected ? AppColors.blue : context.textSubtle,
                                    size: 22,
                                  ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(id);
                                  _selectedMap.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                  _selectedMap[id] = friend;
                                }
                              });
                            },
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}
