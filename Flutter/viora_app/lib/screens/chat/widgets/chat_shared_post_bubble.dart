import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme_helper.dart';
import '../../../l10n/language.dart';
import '../../../services/post_service.dart';
import '../../../widgets/app_avatar.dart';

class ChatSharedPostBubble extends StatefulWidget {
  final Map<String, dynamic> msg;
  final String text;
  final bool isMe;
  final bool isPinned;
  final String author;
  final String content;
  final VoidCallback? onTap;

  const ChatSharedPostBubble({
    super.key,
    required this.msg,
    required this.text,
    required this.isMe,
    this.isPinned = false,
    required this.author,
    required this.content,
    this.onTap,
  });

  @override
  State<ChatSharedPostBubble> createState() => _ChatSharedPostBubbleState();
}

class _ChatSharedPostBubbleState extends State<ChatSharedPostBubble> {
  static final Map<String, Map<String, dynamic>> _cache = {};
  Map<String, dynamic>? _postData;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didUpdateWidget(covariant ChatSharedPostBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.msg != widget.msg ||
        oldWidget.text != widget.text ||
        oldWidget.author != widget.author ||
        oldWidget.content != widget.content) {
      _initData();
    }
  }

  void _initData() {
    if (widget.msg['sharedPost'] is Map) {
      _postData = Map<String, dynamic>.from(widget.msg['sharedPost'] as Map);
      return;
    }
    if (widget.msg['post'] is Map) {
      _postData = Map<String, dynamic>.from(widget.msg['post'] as Map);
      return;
    }

    final postId = (widget.msg['postId'] ?? '').toString().trim();
    final cacheKey = postId.isNotEmpty && postId != 'null'
        ? postId
        : '${widget.author}|${widget.content}';

    if (_cache.containsKey(cacheKey)) {
      _postData = _cache[cacheKey];
      return;
    }

    _fetchPost(cacheKey, postId);
  }

  Future<void> _fetchPost(String cacheKey, String postId) async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      Map<String, dynamic>? fetched;
      if (postId.isNotEmpty && postId != 'null') {
        fetched = await PostService.getPost(postId);
      }
      if (fetched == null && (widget.content.isNotEmpty || widget.author.isNotEmpty)) {
        fetched = await PostService.findPost(
          content: widget.content.isNotEmpty ? widget.content : widget.text,
          authorName: widget.author.isNotEmpty ? widget.author : null,
          postId: postId.isNotEmpty && postId != 'null' ? postId : null,
        );
      }

      if (fetched != null) {
        _cache[cacheKey] = fetched;
        if (mounted) {
          setState(() {
            _postData = fetched;
          });
        }
      }
    } catch (_) {
      // Silently ignore network lookup error and use fallback text
    } finally {
      _isFetching = false;
    }
  }

  static const List<Color> _avatarColors = [
    AppColors.blue,
    AppColors.purple,
    AppColors.pink,
    AppColors.orange,
    AppColors.teal,
  ];

  Color _getAuthorColor(String name) {
    if (name.isEmpty) return AppColors.blue;
    return _avatarColors[name.hashCode.abs() % _avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final bool isAnon = _postData?['isAnonymous'] == true ||
        _postData?['isAnonymous']?.toString() == 'true' ||
        Language.isAnonymousMemberName(widget.author) ||
        Language.isAnonymousMemberName(_postData?['userName']?.toString()) ||
        Language.isAnonymousMemberName(_postData?['authorName']?.toString());

    String displayAuthor = widget.author;
    if (_postData != null) {
      final authorObj = _postData!['author'];
      final authorNameFromObj = (authorObj is Map) ? authorObj['username'] : null;
      final pName = (_postData!['userName'] ??
              _postData!['authorName'] ??
              authorNameFromObj)
          ?.toString()
          .trim();
      if (pName != null && pName.isNotEmpty) {
        displayAuthor = pName;
      }
    }
    if (isAnon) {
      displayAuthor = l10n.anonymousMember;
    } else if (displayAuthor.isEmpty) {
      displayAuthor = l10n.post;
    }

    final String initial = displayAuthor.isNotEmpty
        ? displayAuthor.characters.first.toUpperCase()
        : 'P';

    String? authorAvatar;
    if (!isAnon && _postData != null) {
      final authorObj = _postData!['author'];
      final authorAvatarFromObj = (authorObj is Map) ? authorObj['avatar'] : null;
      final rawAvatar = _postData!['avatar'] ??
          _postData!['authorAvatar'] ??
          authorAvatarFromObj;
      if (rawAvatar != null) {
        authorAvatar = rawAvatar.toString();
      }
    }

    String displayContent = widget.content;
    if (_postData != null) {
      final pContent = (_postData!['content'] ?? '').toString().trim();
      if (pContent.isNotEmpty) {
        displayContent = pContent;
      }
    }
    final String cleanContent = displayContent.trim();

    String groupName = '';
    if (_postData != null) {
      if (_postData!['group'] is Map) {
        groupName = (_postData!['group']['name'] ?? '').toString().trim();
      } else if (_postData!['groupName'] != null) {
        groupName = _postData!['groupName'].toString().trim();
      }
    }

    final bool isLiveStream =
        cleanContent.contains('🔴') || cleanContent.toLowerCase().contains('live stream');
    String liveTitle = '';
    String liveDuration = '';
    if (isLiveStream) {
      final lines = cleanContent
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      for (final line in lines) {
        if (!line.contains('🔴') &&
            !line.toLowerCase().contains('live stream') &&
            liveTitle.isEmpty) {
          liveTitle = line;
        } else if (line.contains('(') && line.contains(')')) {
          final start = line.indexOf('(');
          final end = line.indexOf(')');
          if (end > start) {
            liveDuration = line.substring(start + 1, end).trim();
          }
        }
      }
      if (liveTitle.isEmpty) {
        liveTitle = cleanContent
            .replaceAll('🔴', '')
            .replaceAll('Live stream:', '')
            .trim();
      }
    }

    final cardBgColor = context.isDark ? const Color(0xFF282B33) : const Color(0xFFF1F3F6);
    final borderColor = context.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: 275.w,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.18 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isAnon)
                    Container(
                      width: 34.r,
                      height: 34.r,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC08900),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: CustomPaint(
                        size: Size(20.r, 20.r),
                        painter: const _IncognitoIconPainter(),
                      ),
                    )
                  else if (authorAvatar != null && authorAvatar.isNotEmpty)
                    AppAvatar(
                      avatar: authorAvatar,
                      name: displayAuthor,
                      radius: 17.r,
                      fontSize: 13.sp,
                    )
                  else
                    Container(
                      width: 34.r,
                      height: 34.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getAuthorColor(displayAuthor),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(width: 9.w),
                  Expanded(
                    child: Text(
                      displayAuthor,
                      style: TextStyle(
                        color: context.isDark ? Colors.white : context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: isLiveStream
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  '🔴 LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9.sp,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (liveDuration.isNotEmpty) ...[
                                SizedBox(width: 6.w),
                                Text(
                                  liveDuration,
                                  style: TextStyle(
                                    color: context.isDark ? Colors.white70 : context.textMuted,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            liveTitle.isNotEmpty ? liveTitle : cleanContent,
                            style: TextStyle(
                              color: context.isDark ? Colors.white : context.textPrimary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : Text(
                        cleanContent.isNotEmpty ? cleanContent : '...',
                        style: TextStyle(
                          color: context.isDark
                              ? const Color(0xFFE4E6EB)
                              : const Color(0xFF1C1E21),
                          fontSize: 14.sp,
                          height: 1.38,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),

              if (groupName.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 17.r,
                      height: 17.r,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1877F2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.groups_rounded,
                        size: 11.r,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        groupName,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: context.isDark
                              ? const Color(0xFFB0B3B8)
                              : const Color(0xFF65676B),
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IncognitoIconPainter extends CustomPainter {
  const _IncognitoIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final crownPath = Path();
    crownPath.moveTo(size.width * 0.28, size.height * 0.38);
    crownPath.cubicTo(
      size.width * 0.30, size.height * 0.16,
      size.width * 0.70, size.height * 0.16,
      size.width * 0.72, size.height * 0.38,
    );
    crownPath.close();
    canvas.drawPath(crownPath, fillPaint);

    final brimPath = Path();
    brimPath.moveTo(size.width * 0.15, size.height * 0.40);
    brimPath.quadraticBezierTo(
      size.width * 0.50, size.height * 0.35,
      size.width * 0.85, size.height * 0.40,
    );
    brimPath.quadraticBezierTo(
      size.width * 0.50, size.height * 0.45,
      size.width * 0.15, size.height * 0.40,
    );
    brimPath.close();
    canvas.drawPath(brimPath, fillPaint);

    final leftCenter = Offset(size.width * 0.36, size.height * 0.65);
    final rightCenter = Offset(size.width * 0.64, size.height * 0.65);
    final eyeRadius = size.width * 0.13;
    canvas.drawCircle(leftCenter, eyeRadius, strokePaint);
    canvas.drawCircle(rightCenter, eyeRadius, strokePaint);

    canvas.drawLine(
      Offset(size.width * 0.47, size.height * 0.63),
      Offset(size.width * 0.53, size.height * 0.63),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
