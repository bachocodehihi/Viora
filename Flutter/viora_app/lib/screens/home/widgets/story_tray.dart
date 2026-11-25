import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme_helper.dart';
import '../../../l10n/language.dart';
import '../../../models/story_model.dart';
import '../../../services/livestream_service.dart';
import '../../../services/story_service.dart';
import '../../../widgets/app_avatar.dart';
import '../../live/livestream_audience_screen.dart';
import '../../post/create_story_screen.dart';
import '../../post/story_screen.dart';

class StoryTray extends StatefulWidget {
  final String? userAvatar;
  final String? userName;
  final List<Map<String, dynamic>>? activeLives;

  const StoryTray({
    super.key,
    this.userAvatar,
    this.userName,
    this.activeLives,
  });

  @override
  State<StoryTray> createState() => StoryTrayState();
}

class StoryTrayState extends State<StoryTray> {
  List<UserStoryGroup> _storyGroups = [];
  List<Map<String, dynamic>> _internalLives = [];

  List<Map<String, dynamic>> get _lives => widget.activeLives ?? _internalLives;

  @override
  void initState() {
    super.initState();
    loadStories();
  }

  Future<void> loadStories() async {
    final groupsFuture = StoryService.getStoriesFeed();
    final livesFuture = LivestreamService.getActiveLives();
    final results = await Future.wait([groupsFuture, livesFuture]);
    if (mounted) {
      setState(() {
        _storyGroups = results[0] as List<UserStoryGroup>;
        _internalLives = results[1] as List<Map<String, dynamic>>;
      });
    }
  }

  List<Color> _parseGradient(String bg) {
    if (bg.contains(',')) {
      final parts = bg.split(',');
      final colors = <Color>[];
      for (final p in parts) {
        final clean = p.replaceAll('#', '').trim();
        final intVal = int.tryParse('FF$clean', radix: 16);
        if (intVal != null) colors.add(Color(intVal));
      }
      if (colors.isNotEmpty) return colors;
    }
    if (bg.startsWith('#')) {
      final clean = bg.replaceAll('#', '').trim();
      final intVal = int.tryParse('FF$clean', radix: 16);
      if (intVal != null) return [Color(intVal), Color(intVal)];
    }
    return [const Color(0xFF141E30), const Color(0xFF243B55)];
  }

  void _openCreateStory() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateStoryScreen(
          userAvatar: widget.userAvatar,
          userName: widget.userName,
        ),
      ),
    );
    if (result == true) {
      loadStories();
    }
  }

  void _openStory(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryScreen(
          groups: _storyGroups,
          initialGroupIndex: index,
        ),
      ),
    );
    loadStories();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cardHeight = 155.h;
    final cardWidth = 100.w;
    final lives = _lives;

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 1 + lives.length + _storyGroups.length,
        itemBuilder: (ctx, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _openCreateStory,
              child: Container(
                width: cardWidth,
                margin: EdgeInsets.only(right: 10.w),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: context.isDark ? Colors.white12 : Colors.black12,
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 105.h,
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
                        child: widget.userAvatar != null && widget.userAvatar!.isNotEmpty
                            ? Image.network(
                                widget.userAvatar!,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, e, st) => Container(
                                  color: AppColors.blue.withValues(alpha: 0.15),
                                  child: const Icon(Icons.person, color: AppColors.blue, size: 40),
                                ),
                              )
                            : Container(
                                color: AppColors.blue.withValues(alpha: 0.15),
                                child: const Icon(Icons.person, color: AppColors.blue, size: 40),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 90.h,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 32.r,
                          height: 32.r,
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.cardBg, width: 2.5),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8.h,
                      left: 4.w,
                      right: 4.w,
                      child: Text(
                        l10n.addStory,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (index <= lives.length) {
            final live = lives[index - 1];
            final host = live['host'] as Map<String, dynamic>? ?? {};
            final hostName = host['name']?.toString() ?? l10n.liveBadge;
            final hostAvatar = host['avatar']?.toString();
            final rawTitle = live['title']?.toString() ?? '';
            final liveTitle = (rawTitle == 'Buổi phát trực tiếp' || rawTitle == 'Live Stream' || rawTitle.isEmpty)
                ? l10n.liveStreamTitleDefault
                : rawTitle;
            final thumbnail = live['thumbnail']?.toString();
            final groupName = live['groupName']?.toString();

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LivestreamAudienceScreen(
                      liveId: live['id']?.toString() ?? live['_id']?.toString() ?? '',
                      initialTitle: liveTitle,
                      hostName: hostName,
                      hostAvatar: hostAvatar,
                    ),
                  ),
                );
              },
              child: Container(
                width: cardWidth,
                margin: EdgeInsets.only(right: 10.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFFFF416C),
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF416C).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [

                      if (thumbnail != null && thumbnail.isNotEmpty)
                        Image.network(
                          thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, e, st) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF2C0B14), Color(0xFF14070A)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        )
                      else if (hostAvatar != null && hostAvatar.isNotEmpty)
                        Image.network(
                          hostAvatar,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, e, st) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF2C0B14), Color(0xFF14070A)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2C0B14), Color(0xFF14070A)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.sensors_rounded,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 40.r,
                            ),
                          ),
                        ),

                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),

                      Positioned(
                        top: 8.h,
                        left: 8.w,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                                ),
                                borderRadius: BorderRadius.circular(5.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF416C).withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 4.5.r,
                                    height: 4.5.r,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    l10n.liveBadge.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 5.h),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFFF416C),
                                  width: 2,
                                ),
                              ),
                              child: AppAvatar(
                                avatar: hostAvatar,
                                name: hostName,
                                radius: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        bottom: 8.h,
                        left: 8.w,
                        right: 8.w,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hostName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                                ],
                              ),
                            ),
                            if (groupName != null && groupName.isNotEmpty) ...[
                              SizedBox(height: 1.h),
                              Row(
                                children: [
                                  Icon(Icons.groups_rounded, size: 9.sp, color: Colors.white70),
                                  SizedBox(width: 2.w),
                                  Expanded(
                                    child: Text(
                                      groupName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 8.5.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (liveTitle.isNotEmpty) ...[
                              SizedBox(height: 1.h),
                              Text(
                                liveTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final groupIndex = index - 1 - lives.length;
          final group = _storyGroups[groupIndex];
          final firstStory = group.stories.first;
          final isImage = firstStory.mediaType == 'image' && firstStory.mediaUrl.isNotEmpty;
          final bgColors = _parseGradient(firstStory.backgroundColor);

          return GestureDetector(
            onTap: () => _openStory(groupIndex),
            child: Container(
              width: cardWidth,
              margin: EdgeInsets.only(right: 10.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: group.hasUnseen ? AppColors.blue : (context.isDark ? Colors.white12 : Colors.black12),
                  width: group.hasUnseen ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [

                    if (isImage)
                      Image.network(
                        firstStory.mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, e, st) => Container(color: Colors.black54),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: bgColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 40.h),
                        alignment: Alignment.center,
                        child: Text(
                          firstStory.content,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                    Positioned(
                      top: 8.h,
                      left: 8.w,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: group.hasUnseen ? const Color(0xFFE94057) : Colors.white60,
                            width: 2,
                          ),
                        ),
                        child: AppAvatar(
                          avatar: group.userAvatar,
                          name: group.userName,
                          radius: 14,
                        ),
                      ),
                    ),
                    
                    Positioned(
                      bottom: 8.h,
                      left: 8.w,
                      right: 8.w,
                      child: Text(
                        group.isMe ? l10n.yourStory : group.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
