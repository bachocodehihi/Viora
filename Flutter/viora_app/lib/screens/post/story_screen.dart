import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../l10n/language.dart';
import '../../models/story_model.dart';
import '../../services/story_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';

class StoryScreen extends StatefulWidget {
  final List<UserStoryGroup> groups;
  final int initialGroupIndex;

  const StoryScreen({
    super.key,
    required this.groups,
    this.initialGroupIndex = 0,
  });

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> with SingleTickerProviderStateMixin {
  late int _currentGroupIndex;
  late int _currentStoryIndex;
  late AnimationController _animController;
  final TextEditingController _replyController = TextEditingController();

  static const Duration _storyDuration = Duration(seconds: 5);

  UserStoryGroup get _currentGroup => widget.groups[_currentGroupIndex];
  StoryItem get _currentStory => _currentGroup.stories[_currentStoryIndex];

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex.clamp(0, widget.groups.length - 1);
    _currentStoryIndex = 0;

    _animController = AnimationController(vsync: this, duration: _storyDuration);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStoryTimeout();
      }
    });

    _startCurrentStory();
  }

  @override
  void dispose() {
    _animController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _startCurrentStory() {
    _animController.stop();
    _animController.reset();
    _animController.duration = _storyDuration;
    _animController.forward();

    final story = _currentStory;
    if (!story.isViewed && !_currentGroup.isMe) {
      story.isViewed = true;
      StoryService.viewStory(story.id);
    }
  }

  void _onStoryTimeout() {
    if (_currentStoryIndex < _currentGroup.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _startCurrentStory();
    } else {
      _goToNextGroup();
    }
  }

  void _goToNextStory() {
    if (_currentStoryIndex < _currentGroup.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _startCurrentStory();
    } else {
      _goToNextGroup();
    }
  }

  void _goToPrevStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startCurrentStory();
    } else {
      _goToPrevGroup();
    }
  }

  void _goToNextGroup() {
    if (_currentGroupIndex < widget.groups.length - 1) {
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndex = 0;
      });
      _startCurrentStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _goToPrevGroup() {
    if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        _currentStoryIndex = widget.groups[_currentGroupIndex].stories.length - 1;
      });
      _startCurrentStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _pause() {
    _animController.stop();
  }

  void _resume() {
    _animController.forward();
  }

  Future<void> _handleDeleteStory() async {
    _pause();
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(l10n.deleteStoryTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(l10n.deleteStoryConfirm, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storyId = _currentStory.id;
      final deleted = await StoryService.deleteStory(storyId);
      if (deleted && mounted) {
        AppToast.success(context, l10n.storyDeletedSuccess);
        _currentGroup.stories.removeAt(_currentStoryIndex);
        if (_currentGroup.stories.isEmpty) {
          widget.groups.removeAt(_currentGroupIndex);
          if (widget.groups.isEmpty) {
            Navigator.pop(context);
            return;
          }
          if (_currentGroupIndex >= widget.groups.length) {
            _currentGroupIndex = widget.groups.length - 1;
          }
          _currentStoryIndex = 0;
        } else {
          if (_currentStoryIndex >= _currentGroup.stories.length) {
            _currentStoryIndex = _currentGroup.stories.length - 1;
          }
        }
        setState(() {});
        _startCurrentStory();
        return;
      }
    }
    _resume();
  }

  void _showViewersSheet() {
    _pause();
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) {
        final viewers = _currentStory.viewers;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  l10n.storyViewersTitle(viewers.length),
                  style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12.h),
                if (viewers.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Center(
                      child: Text(l10n.noStoryViewersYet, style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: viewers.length,
                      itemBuilder: (context, idx) {
                        final v = viewers[idx];
                        final user = v['user'];
                        String name = l10n.member;
                        String? avatar;
                        if (user is Map) {
                          name = user['username']?.toString() ?? name;
                          avatar = user['avatar']?.toString();
                        }
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AppAvatar(avatar: avatar, name: name, radius: 20),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.remove_red_eye_rounded, color: Colors.white38, size: 18),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ).then((_) => _resume());
  }

  void _sendReaction(String reaction) {
    StoryService.reactStory(_currentStory.id, reaction);
    AppToast.success(context, context.l10n.reactedToStoryToast(reaction));
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return context.l10n.justNow;
    if (diff.inMinutes < 60) return '${diff.inMinutes}p';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
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

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty || _currentGroup.stories.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final story = _currentStory;
    final isText = story.mediaType == 'text' || story.mediaUrl.isEmpty;
    final bgColors = _parseGradient(story.backgroundColor);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [

            if (isText)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: bgColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                alignment: Alignment.center,
                child: Text(
                  story.content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26.sp,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              )
            else
              Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    story.mediaUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                    },
                    errorBuilder: (ctx, e, st) => Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 50),
                      ),
                    ),
                  ),
                  if (story.content.isNotEmpty)
                    Positioned(
                      bottom: 90.h,
                      left: 20.w,
                      right: 20.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          story.content,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),

            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goToPrevStory,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goToNextStory,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140.h,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    Row(
                      children: List.generate(_currentGroup.stories.length, (i) {
                        return Expanded(
                          child: Container(
                            height: 3.h,
                            margin: EdgeInsets.symmetric(horizontal: 2.w),
                            child: AnimatedBuilder(
                              animation: _animController,
                              builder: (ctx, child) {
                                double val = 0.0;
                                if (i < _currentStoryIndex) {
                                  val = 1.0;
                                } else if (i == _currentStoryIndex) {
                                  val = _animController.value;
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(2.r),
                                  child: LinearProgressIndicator(
                                    value: val,
                                    backgroundColor: Colors.white.withValues(alpha: 0.35),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 12.h),

                    Row(
                      children: [
                        AppAvatar(
                          avatar: _currentGroup.userAvatar,
                          name: _currentGroup.userName,
                          radius: 18,
                        ),
                        SizedBox(width: 10.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentGroup.userName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                            Text(
                              _formatTimeAgo(story.createdAt),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (_currentGroup.isMe)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            onPressed: _handleDeleteStory,
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 20.h,
              left: 16.w,
              right: 16.w,
              child: SafeArea(
                child: _currentGroup.isMe
                    ? GestureDetector(
                        onTap: _showViewersSheet,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8.w),
                              Text(
                                context.l10n.storyViewersCount(story.viewersCount),
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44.h,
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(22.r),
                                border: Border.all(color: Colors.white30),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                context.l10n.sendStoryReplyHint,
                                style: TextStyle(color: Colors.white60, fontSize: 13.sp),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          ...['❤️', '🔥', '😂', '😍'].map((emoji) {
                            return GestureDetector(
                              onTap: () => _sendReaction(emoji),
                              child: Container(
                                margin: EdgeInsets.only(left: 6.w),
                                child: Text(emoji, style: TextStyle(fontSize: 24.sp)),
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
