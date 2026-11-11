import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../services/livestream_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';
import '../../l10n/language.dart';
import 'widgets/live_reaction_overlay.dart';
class LivestreamAudienceScreen extends StatefulWidget {
  final String liveId;
  final String? initialTitle;
  final String? hostName;
  final String? hostAvatar;

  const LivestreamAudienceScreen({
    super.key,
    required this.liveId,
    this.initialTitle,
    this.hostName,
    this.hostAvatar,
  });

  @override
  State<LivestreamAudienceScreen> createState() => _LivestreamAudienceScreenState();
}

class _LivestreamAudienceScreenState extends State<LivestreamAudienceScreen> {
  Language get l10n => context.l10n;
  RtcEngine? _engine;
  bool _isLoading = true;
  bool _isEnded = false;
  int? _remoteUid;
  VideoViewController? _videoViewController;

  String? _appId;
  String? _channelName;
  String? _token;
  String? _title;
  String? _currentHostName;
  String? _currentHostAvatar;

  int _viewersCount = 0;
  int _likesCount = 0;
  bool _isCommentBlocked = false;
  final List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _myUserId;
  String? _myName;
  String? _myAvatar;

  bool _showComments = true;
  double _commentDragDx = 0;

  bool _showReactionBar = false;
  final List<Widget> _floatingParticles = [];

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _currentHostName = widget.hostName;
    _currentHostAvatar = widget.hostAvatar;

    _startFlow();
  }

  Future<void> _startFlow() async {
    await _loadUserSession();
    if (mounted) {
      await _loadLiveInfoAndJoin();
    }
  }

  Future<void> _loadUserSession() async {
    _myUserId = await SessionService.getUserId();
    _myName = await SessionService.getUsername();
    _myAvatar = await SessionService.getAvatar();
  }

  Future<void> _loadLiveInfoAndJoin() async {
    final res = await LivestreamService.getLiveDetail(widget.liveId);

    if (!mounted) return;

    if (res == null || res['success'] != true) {
      AppToast.error(context, l10n.cannotLoadLiveStream);
      Navigator.pop(context);
      return;
    }

    if (res['isEnded'] == true) {
      setState(() {
        _isLoading = false;
        _isEnded = true;
      });
      return;
    }

    _appId = res['appId']?.toString();
    _token = res['token']?.toString();
    _channelName = res['channelName']?.toString();
    final live = res['liveStream'] as Map<String, dynamic>?;

    if (live != null) {
      _title = live['title']?.toString() ?? _title;
      _viewersCount = (live['viewersCount'] as num?)?.toInt() ?? 0;
      _likesCount = (live['likesCount'] as num?)?.toInt() ?? 0;

      final host = live['host'] as Map<String, dynamic>?;
      if (host != null) {
        _currentHostName = host['name']?.toString() ?? _currentHostName;
        _currentHostAvatar = host['avatar']?.toString() ?? _currentHostAvatar;
      }
    }

    setState(() => _isLoading = false);

    _initSocket();
    _initAgora();
  }

  void _setupRemoteVideo(int uid) {
    if (_remoteUid == uid && _videoViewController != null) return;
    _videoViewController?.dispose();
    _remoteUid = uid;
    if (_engine != null && _channelName != null) {
      _videoViewController = VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(
          uid: uid,
          renderMode: RenderModeType.renderModeHidden,
        ),
        connection: RtcConnection(channelId: _channelName!),
        useFlutterTexture: true,
        useAndroidSurfaceView: false,
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _initAgora() async {
    try {
      if (_appId == null || _channelName == null || _token == null) return;

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: _appId!,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[Agora Viewer] Joined channel: ${connection.channelId}');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[Agora Viewer] Host broadcast started with UID: $remoteUid');
            _setupRemoteVideo(remoteUid);
          },
          onRemoteVideoStateChanged: (
            RtcConnection connection,
            int remoteUid,
            RemoteVideoState state,
            RemoteVideoStateReason reason,
            int elapsed,
          ) {
            debugPrint('[Agora Viewer] Remote video state: $state for UID: $remoteUid');
            if (state == RemoteVideoState.remoteVideoStateDecoding ||
                state == RemoteVideoState.remoteVideoStateStarting) {
              _setupRemoteVideo(remoteUid);
            }
          },
          onFirstRemoteVideoDecoded: (
            RtcConnection connection,
            int remoteUid,
            int width,
            int height,
            int elapsed,
          ) {
            debugPrint('[Agora Viewer] First remote video decoded: $remoteUid ($width x $height)');
            _setupRemoteVideo(remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('[Agora Viewer] Host went offline');
            if (mounted) {
              _videoViewController?.dispose();
              _videoViewController = null;
              setState(() => _remoteUid = null);
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[Agora Viewer] Error: $err, $msg');
          },
        ),
      );

      await _engine!.enableVideo();
      await _engine!.enableAudio();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);

      await _engine!.joinChannel(
        token: _token!,
        channelId: _channelName!,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      debugPrint('[Agora Viewer] _initAgora error: $e');
    }
  }

  void _initSocket() {
    SocketService.joinLive(widget.liveId, userId: _myUserId, userName: _myName, userAvatar: _myAvatar);

    SocketService.onLiveComment((data) {
      if (!mounted) return;
      if (data['liveId']?.toString() == widget.liveId) {
        setState(() {
          _comments.add(data);
        });
        _scrollToBottom();
      }
    });

    SocketService.onLiveReaction((data) {
      if (!mounted) return;
      if (data['liveId']?.toString() == widget.liveId) {
        setState(() {
          _likesCount = (data['likesCount'] as num?)?.toInt() ?? (_likesCount + 1);
        });
        final reactionType = data['reaction']?.toString() ?? 'love';
        _spawnFloatingReaction(reactionType);
      }
    });

    SocketService.onLiveViewersUpdated((data) {
      if (!mounted) return;
      if (data['liveId']?.toString() == widget.liveId) {
        final count = (data['viewersCount'] as num?)?.toInt();
        if (count != null) {
          setState(() => _viewersCount = count);
        }
      }
    });

    SocketService.onLiveEnded((data) {
      if (!mounted) return;
      if (data['liveId']?.toString() == widget.liveId) {
        setState(() => _isEnded = true);
      }
    });

    SocketService.onKickedFromLive((data) {
      if (!mounted) return;
      if (data['liveId']?.toString() == widget.liveId) {
        Navigator.pop(context);
        AppToast.error(context, l10n.kickedFromLiveNotice);
      }
    });

    SocketService.onLiveCommentBlocked((data) {
      if (!mounted) return;
      if (data['liveId']?.toString() == widget.liveId) {
        final isBlocked = data['isBlocked'] == true;
        setState(() {
          _isCommentBlocked = isBlocked;
        });
        if (isBlocked) {
          AppToast.warning(context, l10n.hostBlockedYourComment);
        } else {
          AppToast.success(context, l10n.hostUnblockedYourComment);
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendComment() {
    if (_isCommentBlocked) {
      AppToast.warning(context, l10n.youAreBlockedFromCommentingLive);
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    SocketService.sendLiveComment(
      liveId: widget.liveId,
      comment: text,
      userId: _myUserId,
      userName: _myName,
      userAvatar: _myAvatar,
    );
    _commentController.clear();
  }

  void _sendReaction(String reactionType) {
    SocketService.sendLiveReaction(
      liveId: widget.liveId,
      reaction: reactionType,
      userId: _myUserId,
    );
    _spawnFloatingReaction(reactionType);
  }

  void _spawnFloatingReaction(String reactionType) {
    final key = UniqueKey();
    setState(() {
      _floatingParticles.add(
        LiveFloatingParticle(
          key: key,
          reactionId: reactionType,
          onComplete: () {
            if (mounted) {
              setState(() {
                _floatingParticles.removeWhere((w) => w.key == key);
              });
            }
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    SocketService.leaveLive(widget.liveId, userId: _myUserId);
    _videoViewController?.dispose();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    if (_isEnded) {
      return Scaffold(
        backgroundColor: const Color(0xFF13131F),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_off_rounded, size: 50, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.liveStreamEnded,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.thankYouForJoiningLive(_currentHostName ?? l10n.host),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white60),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(l10n.backToNewsfeed, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [

              Positioned.fill(
                child: _buildRemoteVideo(),
              ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: _buildHeader(),
              ),

              Positioned(
                right: 14.w,
                bottom: (MediaQuery.of(context).viewInsets.bottom > 0
                        ? MediaQuery.of(context).viewInsets.bottom + 8.h
                        : (MediaQuery.of(context).padding.bottom > 0
                            ? MediaQuery.of(context).padding.bottom + 8.h
                            : 16.h)) + 46.h,
                width: 100.w,
                height: 200.h,
                child: IgnorePointer(
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: _floatingParticles,
                  ),
                ),
              ),

              Positioned(
                left: 14.w,
                right: _showComments ? null : 14.w,
                bottom: (MediaQuery.of(context).viewInsets.bottom > 0
                        ? MediaQuery.of(context).viewInsets.bottom + 8.h
                        : (MediaQuery.of(context).padding.bottom > 0
                            ? MediaQuery.of(context).padding.bottom + 8.h
                            : 16.h)) + 54.h,
                width: _showComments ? MediaQuery.of(context).size.width * 0.75 : null,
                height: 230.h,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) {
                    _commentDragDx = 0;
                  },
                  onHorizontalDragUpdate: (details) {
                    _commentDragDx += details.delta.dx;
                  },
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (_commentDragDx > 30 || velocity > 150) {
                      if (_showComments) {
                        setState(() => _showComments = false);
                      }
                    } else if (_commentDragDx < -30 || velocity < -150) {
                      if (!_showComments) {
                        setState(() => _showComments = true);
                      }
                    }
                  },
                  child: AnimatedSlide(
                    offset: _showComments ? Offset.zero : const Offset(1.3, 0),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    child: AnimatedOpacity(
                      opacity: _showComments ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_showComments,
                        child: _buildCommentsOverlay(),
                      ),
                    ),
                  ),
                ),
              ),

              if (_showReactionBar)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _showReactionBar = false),
                    behavior: HitTestBehavior.translucent,
                  ),
                ),

              if (_showReactionBar)
                Positioned(
                  right: 14.w,
                  bottom: (MediaQuery.of(context).viewInsets.bottom > 0
                          ? MediaQuery.of(context).viewInsets.bottom + 8.h
                          : (MediaQuery.of(context).padding.bottom > 0
                              ? MediaQuery.of(context).padding.bottom + 8.h
                              : 16.h)) + 46.h,
                  child: LiveReactionBar(
                    onSelect: (rId) => _sendReaction(rId),
                    onClose: () => setState(() => _showReactionBar = false),
                  ),
                ),

              Positioned(
                left: 14.w,
                right: 14.w,
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 8.h
                    : (MediaQuery.of(context).padding.bottom > 0
                        ? MediaQuery.of(context).padding.bottom + 8.h
                        : 16.h),
                child: _buildBottomBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_videoViewController != null && _remoteUid != null) {
      return AgoraVideoView(
        controller: _videoViewController!,
      );
    }

    return Container(
      color: const Color(0xFF13131F),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(
              avatar: _currentHostAvatar,
              name: _currentHostName ?? l10n.host,
              radius: 40,
              fontSize: 26,
            ),
            const SizedBox(height: 16),
            Text(
              _currentHostName ?? l10n.host,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.connectingBroadcastSignal,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(
                avatar: _currentHostAvatar,
                name: _currentHostName ?? l10n.host,
                radius: 14,
                fontSize: 11,
              ),
              const SizedBox(width: 8),
              Text(
                _currentHostName ?? l10n.host,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle, color: Colors.white, size: 8),
              const SizedBox(width: 4),
              Text(
                l10n.liveBadge.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 13),
              const SizedBox(width: 4),
              Text(
                formatLiveCount(_viewersCount),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        const Spacer(),

        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsOverlay() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white, Colors.white],
        stops: [0.0, 0.2, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: _comments.length,
        itemBuilder: (ctx, idx) {
          final c = _comments[idx];
          final name = c['userName']?.toString() ?? l10n.audience;
          final comment = c['comment']?.toString() ?? '';
          final avatar = c['userAvatar']?.toString();

          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: EdgeInsets.only(bottom: 6.h),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppAvatar(avatar: avatar, name: name, radius: 11.r, fontSize: 9.sp),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: const ['Inter', 'Roboto', 'sans-serif'],
                          fontSize: 12.5.sp,
                          color: Colors.white,
                        ),
                        children: [
                          TextSpan(
                            text: '$name: ',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          TextSpan(text: comment),
                        ],
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Row(
      children: [

        Expanded(
          child: Container(
            height: 40.h,
            decoration: BoxDecoration(
              color: _isCommentBlocked
                  ? Colors.redAccent.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: _isCommentBlocked
                    ? Colors.redAccent.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.14),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _commentController,
              enabled: !_isCommentBlocked,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendComment(),
              style: TextStyle(
                color: _isCommentBlocked ? Colors.white60 : Colors.white,
                fontSize: 13.5.sp,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                hintText: _isCommentBlocked
                    ? l10n.commentBlockedHint
                    : l10n.writeCommentHint,
                hintStyle: TextStyle(
                  color: _isCommentBlocked
                      ? Colors.redAccent.withValues(alpha: 0.80)
                      : Colors.white.withValues(alpha: 0.60),
                  fontSize: 12.5.sp,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
              ),
            ),
          ),
        ),
        SizedBox(width: 4.w),

        GestureDetector(
          onTap: _sendComment,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
            child: Icon(
              Icons.send_rounded,
              color: AppColors.blue,
              size: 24.r,
            ),
          ),
        ),
        SizedBox(width: 6.w),

        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _showReactionBar = !_showReactionBar);
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _sendReaction('like');
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 42.r,
            height: 42.r,
            decoration: BoxDecoration(
              color: _showReactionBar
                  ? Colors.black.withValues(alpha: 0.60)
                  : Colors.black.withValues(alpha: 0.38),
              shape: BoxShape.circle,
              border: Border.all(
                color: _showReactionBar
                    ? Colors.white.withValues(alpha: 0.30)
                    : Colors.white.withValues(alpha: 0.14),
                width: 0.8,
              ),
            ),
            child: Center(
              child: Image.asset(
                'assets/icons/like.png',
                width: 26.r,
                height: 26.r,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
