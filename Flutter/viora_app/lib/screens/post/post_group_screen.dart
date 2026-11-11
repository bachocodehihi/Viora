import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';

class PostGroupScreen extends StatefulWidget {
  final String email;

  const PostGroupScreen({
    super.key,
    required this.email,
  });

  @override
  State<PostGroupScreen> createState() => _PostGroupScreenState();
}

class _PostGroupScreenState extends State<PostGroupScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasContent = false;
  String _privacyOption = 'Public';

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasContent) {
      setState(() {
        _hasContent = hasText;
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

  void _submitPost() {
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    final initialLetter = widget.email.isNotEmpty ? widget.email[0].toUpperCase() : 'B';
    final userName = widget.email.contains('@') ? widget.email.split('@')[0] : (widget.email.isNotEmpty ? widget.email : 'bach');

    final newPost = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'userName': userName,
      'avatar': initialLetter,
      'color': AppColors.blue,
      'time': 'just_now',
      'createdAt': DateTime.now().toIso8601String(),
      'content': content,
      'likes': 0,
      'comments': 0,
      'isLiked': false,
    };

    Navigator.pop(context, newPost);
  }

  void _showPrivacyPicker() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
              subtitle: Text(l10n.onlyFriendsOnViora, style: TextStyle(fontFamily: 'Inter', color: context.textMuted, fontSize: 12)),
              trailing: _privacyOption == 'Friends' ? const Icon(Icons.check_circle_rounded, color: AppColors.blue) : null,
              onTap: () {
                setState(() => _privacyOption = 'Friends');
                Navigator.pop(ctx);
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final initialLetter = widget.email.isNotEmpty ? widget.email[0].toUpperCase() : 'B';
    final userName = widget.email.contains('@') ? widget.email.split('@')[0] : (widget.email.isNotEmpty ? widget.email : 'bach');

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
                onPressed: _hasContent ? _submitPost : null,
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
                child: Text(
                  l10n.post,
                  style: const TextStyle(
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
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.blue,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.blue.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: CircleAvatar(
                        backgroundColor: context.cardBg,
                        child: Text(
                          initialLetter,
                          style: const TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
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
                                  _privacyOption == 'Public'
                                      ? Icons.public_rounded
                                      : (_privacyOption == 'Friends' ? Icons.people_rounded : Icons.lock_rounded),
                                  size: 13,
                                  color: context.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _privacyOption == 'Public' ? l10n.public : (_privacyOption == 'Friends' ? l10n.friends : l10n.onlyMe),
                                  style: TextStyle(
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
                  child: GestureDetector(
                    onTap: () {
                      if (!_focusNode.hasFocus) {
                        FocusScope.of(context).requestFocus(_focusNode);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: borderColor,
                          width: borderWidth,
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        autofocus: true,
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          height: 1.45,
                        ),
                        decoration: InputDecoration(
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: l10n.whatsOnYourMind,
                          hintStyle: TextStyle(
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.photo_library_rounded, color: AppColors.teal, size: 22),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.blue, size: 22),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: AppColors.orange, size: 22),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.location_on_rounded, color: AppColors.red, size: 22),
                      onPressed: () {},
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
