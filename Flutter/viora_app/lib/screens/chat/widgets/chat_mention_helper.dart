import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme_helper.dart';
import '../../../widgets/app_avatar.dart';

String removeDiacritics(String str) {
  const vietnameseMap = {
    'a': 'áàảãạăắằẳẵặâấầẩẫậ',
    'A': 'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬ',
    'd': 'đ',
    'D': 'Đ',
    'e': 'éèẻẽẹêếềểễệ',
    'E': 'ÉÈẺẼẸÊẾỀỂỄỆ',
    'i': 'íìỉĩị',
    'I': 'ÍÌỈĨỊ',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'O': 'ÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢ',
    'u': 'úùủũụưứừửữự',
    'U': 'ÚÙỦŨỤƯỨỪỬỮỰ',
    'y': 'ýỳỷỹỵ',
    'Y': 'ÝỲỶỸỴ',
  };
  var result = str;
  vietnameseMap.forEach((nonDiacritic, diacritics) {
    for (var i = 0; i < diacritics.length; i++) {
      result = result.replaceAll(diacritics[i], nonDiacritic);
    }
  });
  return result;
}

RegExp buildChatMentionRegex(List<String> memberNames) {
  final specialMentions = [
    r'All',
    r'all',
    r'Mọi\s+người',
    r'mọi\s+người',
    r'Moi\s+nguoi',
    r'moi\s+nguoi',
    r'everyone',
    r'Everyone',
  ];

  final escapedNames = memberNames
      .where((n) => n.trim().isNotEmpty)
      .map((n) => RegExp.escape(n.trim()).replaceAll(r'\ ', r'\s+'))
      .toList();

  final allPatterns = [...specialMentions, ...escapedNames];
  final prefixPattern = allPatterns.join('|');

  return RegExp(
    r'(?<![\w\.])(@(?:' + prefixPattern + r')|@[a-zA-Z0-9_\u00C0-\u024F\u1E00-\u1EFF]+)',
    caseSensitive: false,
  );
}

class ChatMentionTextEditingController extends TextEditingController {
  final Color mentionColor;
  List<String> memberNames;

  ChatMentionTextEditingController({
    super.text,
    this.mentionColor = AppColors.blue,
    this.memberNames = const [],
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final fullText = value.text;
    final regex = buildChatMentionRegex(memberNames);
    final matches = regex.allMatches(fullText);

    if (matches.isEmpty) {
      return TextSpan(text: fullText, style: style);
    }

    final List<InlineSpan> children = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        children.add(TextSpan(
          text: fullText.substring(lastEnd, match.start),
          style: style,
        ));
      }
      children.add(TextSpan(
        text: match.group(0),
        style: (style ?? const TextStyle()).copyWith(
          color: mentionColor,
          fontWeight: FontWeight.w600,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < fullText.length) {
      children.add(TextSpan(
        text: fullText.substring(lastEnd),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}

class ChatMessageText extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool isRecalled;
  final List<String> memberNames;

  const ChatMessageText({
    super.key,
    required this.text,
    required this.isMe,
    this.isRecalled = false,
    this.memberNames = const [],
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: isRecalled
          ? (isMe ? Colors.white70 : context.textMuted)
          : (isMe ? Colors.white : context.textPrimary),
      fontSize: 14.5.sp,
      height: 1.35,
      fontStyle: isRecalled ? FontStyle.italic : FontStyle.normal,
    );

    if (isRecalled) {
      return Text(text, style: baseStyle);
    }

    final regex = buildChatMentionRegex(memberNames);
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      final mention = match.group(0) ?? '';
      spans.add(TextSpan(
        text: mention,
        style: baseStyle.copyWith(
          color: (isMe || context.isDark) ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
    );
  }
}

class ChatMentionSuggestionsBox extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const ChatMentionSuggestionsBox({
    super.key,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(maxHeight: 220.h),
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.r),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 4.h),
          itemCount: suggestions.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 0.5,
            color: context.dividerTheme.withValues(alpha: 0.25),
          ),
          itemBuilder: (context, index) {
            final item = suggestions[index];
            final bool isAll = item['isAll'] == true;
            final String name = (item['name'] ?? '').toString();
            final String? subtitle = item['subtitle']?.toString();

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: isAll ? 2.h : 4.h),
              leading: isAll
                  ? Container(
                      width: 36.r,
                      height: 36.r,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.blue, Color(0xFF6C5CE7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.groups_rounded, color: Colors.white, size: 20.r),
                    )
                  : AppAvatar(
                      avatar: item['avatar'],
                      name: name,
                      radius: 18.r,
                      fontSize: 12.sp,
                    ),
              title: Row(
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5.sp,
                      color: isAll ? AppColors.blue : context.textPrimary,
                    ),
                  ),
                  if (isAll) ...[
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'ALL',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: (isAll && subtitle != null && subtitle.isNotEmpty)
                  ? Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: context.textMuted,
                      ),
                    )
                  : null,
              onTap: () {
                HapticFeedback.lightImpact();
                onSelect(item);
              },
            );
          },
        ),
      ),
    );
  }
}
