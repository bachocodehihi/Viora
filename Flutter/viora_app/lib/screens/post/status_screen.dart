import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/profile_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/app_avatar.dart';

class StatusScreen extends StatefulWidget {
  final String? currentNote;
  final dynamic userAvatar;
  final String? userName;

  const StatusScreen({
    super.key,
    this.currentNote,
    this.userAvatar,
    this.userName,
  });

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  static const int _maxChars = 60;

  final List<String> _quickEmojis = [
    '💭', '☕', '🎧', '✨', '📚', '🍕', '🎮', '🏖️', '😴', '🔥', '❤️', '🎶', '🍔', '🎉'
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.currentNote ?? '');
    _textController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasText => _textController.text.trim().isNotEmpty;

  void _onEmojiTap(String emoji) {
    final currentText = _textController.text;
    if (currentText.length + emoji.length <= _maxChars) {
      final newText = currentText + emoji;
      _textController.text = newText;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
    }
  }

  Future<void> _shareNote() async {
    final note = _textController.text.trim();
    if (note.isEmpty) return;
    final userId = await SessionService.getUserId();
    await ProfileService.updateNote(note);
    if (userId != null && userId.isNotEmpty) {
      SocketService.sendUpdateNote(userId: userId, note: note);
    }
    if (!mounted) return;
    Navigator.pop(context, note);
  }

  Future<void> _deleteNote() async {
    final userId = await SessionService.getUserId();
    await ProfileService.updateNote('');
    if (userId != null && userId.isNotEmpty) {
      SocketService.sendUpdateNote(userId: userId, note: '');
    }
    if (!mounted) return;
    Navigator.pop(context, '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasExistingNote = widget.currentNote != null && widget.currentNote!.trim().isNotEmpty;

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
          titleSpacing: 0,
          title: Text(
            l10n.thoughtNote,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14.0, top: 10.0, bottom: 10.0),
              child: ElevatedButton(
                onPressed: _hasText ? _shareNote : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: context.isDark
                      ? const Color(0xFF252332)
                      : Colors.black.withValues(alpha: 0.08),
                  disabledForegroundColor: context.textSubtle,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  l10n.share,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 290, minHeight: 72),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: _focusNode.hasFocus
                                  ? AppColors.blue.withValues(alpha: 0.6)
                                  : context.borderTheme,
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _focusNode.hasFocus
                                    ? AppColors.blue.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLength: _maxChars,
                            maxLines: 3,
                            minLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.whatsOnYourMind,
                              hintStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.normal,
                                color: context.textMuted,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: false,
                              fillColor: Colors.transparent,
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.cardBg,
                            border: Border.all(
                              color: _focusNode.hasFocus
                                  ? AppColors.blue.withValues(alpha: 0.7)
                                  : context.borderTheme,
                              width: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.cardBg,
                            border: Border.all(
                              color: _focusNode.hasFocus
                                  ? AppColors.blue.withValues(alpha: 0.5)
                                  : context.borderTheme,
                              width: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        AppAvatar(
                          avatar: widget.userAvatar,
                          name: widget.userName,
                          radius: 46,
                          fontSize: 24,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.userName ?? l10n.you,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 36),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.moodAndFeelings,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: context.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 46,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _quickEmojis.length,
                            itemBuilder: (context, index) {
                              final emoji = _quickEmojis[index];
                              return GestureDetector(
                                onTap: () => _onEmojiTap(emoji),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: context.actionPillBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: context.borderTheme),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const Spacer(),

                        if (hasExistingNote) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _deleteNote,
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 20),
                              label: Text(
                                l10n.deleteCurrentNote,
                                style: const TextStyle(
                                  color: AppColors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
