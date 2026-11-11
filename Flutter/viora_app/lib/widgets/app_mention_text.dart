import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/theme_helper.dart';
import '../l10n/language.dart';

class AppMentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final int? maxLength;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final Function(String rawMention)? onMentionTap;

  const AppMentionText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
    this.maxLength,
    this.isExpanded = false,
    this.onToggleExpand,
    this.onMentionTap,
  });

  static const String defaultFontFamily = 'Inter';
  static const List<String> defaultFontFallback = ['Inter', 'Roboto', 'sans-serif'];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final hasLimit = maxLength != null && maxLength! > 0;
    final isLong = hasLimit && text.length > maxLength!;
    final displayText = (isLong && !isExpanded)
        ? '${text.substring(0, maxLength!)}...'
        : text;

    final regex = Language.getCommentMentionRegex();
    final matches = regex.allMatches(displayText);

    final effectiveStyle = TextStyle(
      fontFamily: defaultFontFamily,
      fontFamilyFallback: defaultFontFallback,
      fontSize: 13.5,
      height: 1.4,
      color: context.textPrimary,
    ).merge(style);

    final effectiveMentionStyle = TextStyle(
      fontFamily: defaultFontFamily,
      fontFamilyFallback: defaultFontFallback,
      fontSize: effectiveStyle.fontSize ?? 13.5,
      height: effectiveStyle.height ?? 1.4,
      color: AppColors.blue,
      fontWeight: FontWeight.w600,
    ).merge(mentionStyle);

    if (matches.isEmpty && !isLong) {
      return Text(
        displayText,
        style: effectiveStyle,
      );
    }

    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: displayText.substring(lastEnd, match.start),
          style: effectiveStyle,
        ));
      }

      final rawMention = match.group(0) ?? '';
      final displayMention = Language.getLocalizedMentionDisplay(rawMention, l10n);

      spans.add(TextSpan(
        text: displayMention,
        style: effectiveMentionStyle,
      ));

      lastEnd = match.end;
    }

    if (lastEnd < displayText.length) {
      spans.add(TextSpan(
        text: displayText.substring(lastEnd),
        style: effectiveStyle,
      ));
    }

    if (isLong && onToggleExpand != null) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: onToggleExpand,
          child: Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              isExpanded ? ' ${l10n.collapse}' : ' ${l10n.seeMore}',
              style: const TextStyle(
                fontFamily: defaultFontFamily,
                fontFamilyFallback: defaultFontFallback,
                color: AppColors.blue,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ));
    }

    return Text.rich(
      TextSpan(
        style: effectiveStyle,
        children: spans,
      ),
    );
  }
}

