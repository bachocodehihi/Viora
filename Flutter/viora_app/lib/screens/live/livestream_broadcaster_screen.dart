import 'dart:async';
import 'dart:math' as math;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../services/livestream_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/toast/app_toast.dart';
import '../../l10n/language.dart';
import 'widgets/live_reaction_overlay.dart';
class LivestreamBroadcasterScreen extends StatefulWidget {
  final Map<String, dynamic> liveData;
  final String initialMode;
  final String? hostName;
  final String? hostAvatar;

  const LivestreamBroadcasterScreen({
    super.key,
    required this.liveData,
    required this.initialMode,
    this.hostName,
    this.hostAvatar,
  });

  @override
  State<LivestreamBroadcasterScreen> createState() => _LivestreamBroadcasterScreenState();
}

class _LivestreamBroadcasterScreenState extends State<LivestreamBroadcasterScreen> {
  RtcEngine? _engine;
  VideoViewController? _localVideoController;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isFrontCamera = true;
  bool _isScreenSharing = false;

  int _viewersCount = 0;
  int _likesCount = 0;
  List<Map<String, dynamic>> _viewersList = [];
  final Set<String> _blockedUserIds = {};
  StateSetter? _viewersModalSetState;
  final List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _durationTimer;
  int _elapsedSeconds = 0;

  bool _showComments = true;
  double _commentDragDx = 0;

  bool _showReactionBar = false;
  final Map<String, int> _reactionsCount = {};
  final List<Widget> _floatingParticles = [];

  String get _liveId => widget.liveData['liveStream']?['id']?.toString() ?? '';
  String get _channelName => widget.liveData['channelName']?.toString() ?? '';
  String get _token => widget.liveData['token']?.toString() ?? '';
  String get _appId => widget.liveData['appId']?.toString() ?? '';
  String get _title => widget.liveData['liveStream']?['title']?.toString() ?? l10n.liveStreamTitleDefault;

  @override
  void initState() {
    super.initState();
    _isScreenSharing = widget.initialMode == 'screen';

    final liveStream = widget.liveData['liveStream'];
    if (liveStream != null) {
      _likesCount = (liveStream['likesCount'] as num?)?.toInt() ?? 0;
      final rc = liveStream['reactionsCount'];
      if (rc is Map) {
        rc.forEach((k, v) {
          if (v is num) _reactionsCount[k.toString()] = v.toInt();
        });
      }
    }

    _initAgora();
    _initSocket();
    _startTimer();
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  String get _formattedDuration {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _initAgora() async {
    try {
      if (_appId.isEmpty || _channelName.isEmpty || _token.isEmpty) {
        debugPrint('[Agora] Missing appId, channelName, or token');
        return;
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[Agora] Host joined channel: ${connection.channelId}');
            if (mounted) setState(() => _isJoined = true);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[Agora] Remote user joined: $remoteUid');
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('[Agora] Remote user offline: $remoteUid');
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[Agora] Error: $err, $msg');
          },
        ),
      );

      await _engine!.enableVideo();
      await _engine!.enableAudio();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      if (_isScreenSharing) {
        try {
          await _engine!.startScreenCapture(const ScreenCaptureParameters2(
            captureAudio: true,
            captureVideo: true,
          ));
        } catch (e) {
          debugPrint('[Agora] startScreenCapture error: $e');
        }
      } else {
        await _engine!.startPreview();
        _localVideoController = VideoViewController(
          rtcEngine: _engine!,
          canvas: const VideoCanvas(
            uid: 0,
            renderMode: RenderModeType.renderModeHidden,
          ),
          useFlutterTexture: true,
          useAndroidSurfaceView: false,
        );
      }

      await _engine!.joinChannel(
        token: _token,
        channelId: _channelName,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: !_isScreenSharing,
          publishScreenCaptureVideo: _isScreenSharing,
          publishScreenCaptureAudio: _isScreenSharing,
          publishScreenTrack: _isScreenSharing,
          publishMicrophoneTrack: true,
        ),
      );
    } catch (e) {
      debugPrint('[Agora] _initAgora error: $e');
    }
  }

  void _initSocket() {
    SocketService.joinLive(_liveId, userName: widget.hostName, userAvatar: widget.hostAvatar);

    SocketService.onLiveComment((data) {
      if (!mounted) return;
      if (data['liveId']?.toString() == _liveId) {
        setState(() {
          _comments.add(data);
        });
        _scrollToBottom();
      }
    });

    SocketService.onLiveReaction((data) {
      if (!mounted) return;
      if (data['liveId']?.toString() == _liveId) {
        final reactionType = data['reaction']?.toString() ?? 'love';
        setState(() {
          _likesCount = (data['likesCount'] as num?)?.toInt() ?? (_likesCount + 1);
          final rCount = data['reactionsCount'];
          if (rCount is Map) {
            rCount.forEach((k, v) {
              if (v is num) _reactionsCount[k.toString()] = v.toInt();
            });
          } else {
            _reactionsCount[reactionType] = (_reactionsCount[reactionType] ?? 0) + 1;
          }
        });
        _spawnFloatingReaction(reactionType);
      }
    });

    SocketService.onLiveViewersUpdated((data) {
      if (!mounted) return;
      if (data['liveId']?.toString() == _liveId) {
        final count = (data['viewersCount'] as num?)?.toInt();
        final list = data['viewers'];
        setState(() {
          if (count != null) _viewersCount = count;
          if (list is List) {
            _viewersList = List<Map<String, dynamic>>.from(list);
            for (final item in _viewersList) {
              final uId = item['userId']?.toString();
              if (uId != null && uId.isNotEmpty) {
                if (item['isCommentBlocked'] == true) {
                  _blockedUserIds.add(uId);
                } else if (item['isCommentBlocked'] == false) {
                  _blockedUserIds.remove(uId);
                }
              }
            }
          }
        });
        if (_viewersModalSetState != null) {
          _viewersModalSetState!(() {});
        }
      }
    });

    SocketService.onLiveViewersList((data) {
      if (!mounted) return;
      if (data['liveId']?.toString() == _liveId) {
        final list = data['viewers'];
        if (list is List) {
          setState(() {
            _viewersList = List<Map<String, dynamic>>.from(list);
            _viewersCount = _viewersList.length;
            for (final item in _viewersList) {
              final uId = item['userId']?.toString();
              if (uId != null && uId.isNotEmpty) {
                if (item['isCommentBlocked'] == true) {
                  _blockedUserIds.add(uId);
                } else if (item['isCommentBlocked'] == false) {
                  _blockedUserIds.remove(uId);
                }
              }
            }
          });
          if (_viewersModalSetState != null) {
            _viewersModalSetState!(() {});
          }
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

  Future<void> _switchCamera() async {
    if (_engine != null && !_isScreenSharing) {
      await _engine!.switchCamera();
      setState(() => _isFrontCamera = !_isFrontCamera);
    }
  }

  Future<void> _toggleMute() async {
    if (_engine != null) {
      final next = !_isMuted;
      await _engine!.muteLocalAudioStream(next);
      setState(() => _isMuted = next);
    }
  }

  void _sendHostComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    SocketService.sendLiveComment(
      liveId: _liveId,
      comment: text,
      userName: '${widget.hostName ?? 'Host'} (${l10n.author})',
      userAvatar: widget.hostAvatar,
    );
    _commentController.clear();
  }

  void _sendHostReaction(String reactionType) {
    if (_liveId.isEmpty) return;
    SocketService.sendLiveReaction(
      liveId: _liveId,
      reaction: reactionType,
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

  Future<void> _confirmEndLive() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.endLiveStreamTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          l10n.endLiveStreamConfirm,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.continueLive, style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.end, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldEnd == true && mounted) {
      _showSaveAsPostDialog();
    }
  }

  void _showSaveAsPostDialog() {
    bool saveAsPost = true;
    final captionController = TextEditingController(text: _title);
    String privacy = 'public';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E2C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        l10n.liveStreamEndedToast,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(l10n.duration, _formattedDuration, Icons.timer_outlined),
                        _buildStatItem(l10n.views, '$_viewersCount', Icons.visibility_outlined),
                        _buildStatItem(l10n.likes, '$_likesCount', Icons.favorite_border_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setModalState(() => saveAsPost = !saveAsPost),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.saveLiveAsPost,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.saveLiveAsPostDesc,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AppSwitch(
                          value: saveAsPost,
                          onChanged: (val) => setModalState(() => saveAsPost = val),
                        ),
                      ],
                    ),
                  ),

                  if (saveAsPost) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: captionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: l10n.liveFeelingsHint,
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
                        filled: true,
                        fillColor: const Color(0xFF2A2A3E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              await LivestreamService.endLive(
                                _liveId,
                                saveAsPost: saveAsPost,
                                caption: captionController.text.trim(),
                                privacy: privacy,
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              saveAsPost ? l10n.postToFeedAndDone : l10n.done,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
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

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _commentController.dispose();
    _scrollController.dispose();
    SocketService.leaveLive(_liveId);
    _localVideoController?.dispose();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                child: _buildVideoSurface(),
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
                  child: LiveReactionStatsBar(
                    reactionsCount: _reactionsCount,
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

  Widget _buildVideoSurface() {
    if (_isScreenSharing) {
      return Container(
        color: const Color(0xFF13131F),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.screen_share_rounded, size: 48, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.screenSharingTitle,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.screenSharingDesc,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_localVideoController != null && _isJoined) {
      return AgoraVideoView(
        controller: _localVideoController!,
      );
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
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
                avatar: widget.hostAvatar,
                name: widget.hostName ?? l10n.you,
                radius: 14,
                fontSize: 11,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.hostName ?? l10n.you,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formattedDuration,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
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

        GestureDetector(
          onTap: _showViewersBottomSheet,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.8,
              ),
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
        ),

        const Spacer(),

        GestureDetector(
          onTap: _confirmEndLive,
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
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
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
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendHostComment(),
              style: TextStyle(color: Colors.white, fontSize: 13.5.sp),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                hintText: l10n.writeCommentHint,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 13.sp,
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
          onTap: _sendHostComment,
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

        _buildCircleButton(
          icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: Colors.white,
          bgColor: _isMuted ? Colors.redAccent.withValues(alpha: 0.85) : null,
          onTap: _toggleMute,
        ),
        SizedBox(width: 6.w),

        if (!_isScreenSharing) ...[
          _buildCircleButton(
            icon: Icons.flip_camera_ios_rounded,
            onTap: _switchCamera,
          ),
          SizedBox(width: 6.w),
        ],

        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _showReactionBar = !_showReactionBar);
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _sendHostReaction('love');
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 38.r,
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            decoration: BoxDecoration(
              color: _showReactionBar
                  ? Colors.black.withValues(alpha: 0.60)
                  : Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(19.r),
              border: Border.all(
                color: _showReactionBar
                    ? Colors.white.withValues(alpha: 0.30)
                    : Colors.white.withValues(alpha: 0.14),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/heart.png',
                  width: 18.r,
                  height: 18.r,
                  filterQuality: FilterQuality.high,
                ),
                SizedBox(width: 5.w),
                Text(
                  formatLiveCount(_likesCount),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    Color color = Colors.white,
    Color? bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38.r,
        height: 38.r,
        decoration: BoxDecoration(
          color: bgColor ?? Colors.black.withValues(alpha: 0.38),
          shape: BoxShape.circle,
          border: Border.all(
            color: bgColor != null ? Colors.transparent : Colors.white.withValues(alpha: 0.14),
            width: 0.8,
          ),
        ),
        child: Center(
          child: Icon(icon, color: color, size: 19.r),
        ),
      ),
    );
  }

  void _showViewersBottomSheet() {
    SocketService.getLiveViewers(_liveId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            _viewersModalSetState = setModalState;

            return Container(
              height: MediaQuery.of(context).size.height * 0.55,
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [

                  Container(
                    margin: EdgeInsets.only(top: 8.h, bottom: 8.h),
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    child: Row(
                      children: [
                        Icon(Icons.remove_red_eye_rounded, color: AppColors.blue, size: 20.r),
                        SizedBox(width: 8.w),
                        Text(
                          l10n.liveViewersCount(_viewersList.length),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(bottomSheetContext),
                          child: Container(
                            padding: EdgeInsets.all(5.r),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            child: Icon(Icons.close_rounded, color: Colors.white70, size: 18.r),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

                  Expanded(
                    child: _viewersList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline_rounded, size: 48.r, color: Colors.white24),
                                SizedBox(height: 8.h),
                                Text(
                                  l10n.noViewersInRoom,
                                  style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                            itemCount: _viewersList.length,
                            separatorBuilder: (_, __) => Divider(
                              color: Colors.white.withValues(alpha: 0.06),
                              height: 12.h,
                            ),
                            itemBuilder: (ctx, idx) {
                              final v = _viewersList[idx];
                              final userId = v['userId']?.toString() ?? '';
                              final rawName = v['userName']?.toString();
                              final userName = (rawName != null && rawName.trim().isNotEmpty)
                                  ? rawName
                                  : l10n.liveViewerDefault;
                              final userAvatar = v['userAvatar']?.toString();
                              final isBlocked = _blockedUserIds.contains(userId) || v['isCommentBlocked'] == true;

                              return InkWell(
                                onTap: () => _showViewerActionSheet(v, setModalState),
                                borderRadius: BorderRadius.circular(12.r),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
                                  child: Row(
                                    children: [
                                      AppAvatar(
                                        avatar: userAvatar,
                                        name: userName,
                                        radius: 19.r,
                                        fontSize: 12.sp,
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              userName,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (isBlocked) ...[
                                              SizedBox(height: 2.h),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent.withValues(alpha: 0.18),
                                                  borderRadius: BorderRadius.circular(4.r),
                                                  border: Border.all(
                                                    color: Colors.redAccent.withValues(alpha: 0.35),
                                                    width: 0.6,
                                                  ),
                                                ),
                                                child: Text(
                                                  l10n.commentBlockedTag,
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 22.r),
                                        onPressed: () => _showViewerActionSheet(v, setModalState),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _viewersModalSetState = null;
    });
  }

  void _showViewerActionSheet(Map<String, dynamic> viewer, void Function(void Function()) setModalState) {
    final userId = viewer['userId']?.toString() ?? '';
    final rawName = viewer['userName']?.toString();
    final userName = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName
        : l10n.liveViewerDefault;
    final isBlocked = _blockedUserIds.contains(userId) || viewer['isCommentBlocked'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (actionCtx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.r)),
              ),
              Row(
                children: [
                  AppAvatar(avatar: viewer['userAvatar']?.toString(), name: userName, radius: 16.r),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      userName,
                      style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Divider(color: Colors.white12, height: 1),
              SizedBox(height: 6.h),

              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: isBlocked ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBlocked ? Icons.speaker_notes_rounded : Icons.speaker_notes_off_rounded,
                    color: isBlocked ? Colors.greenAccent : Colors.orangeAccent,
                    size: 20.r,
                  ),
                ),
                title: Text(
                  isBlocked ? l10n.unblockLiveComment : l10n.blockLiveComment,
                  style: TextStyle(
                    color: isBlocked ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  isBlocked ? l10n.unblockLiveCommentDesc : l10n.blockLiveCommentDesc,
                  style: TextStyle(color: Colors.white54, fontSize: 11.5.sp),
                ),
                onTap: () {
                  final willBlock = !isBlocked;
                  if (willBlock) {
                    _blockedUserIds.add(userId);
                    viewer['isCommentBlocked'] = true;
                  } else {
                    _blockedUserIds.remove(userId);
                    viewer['isCommentBlocked'] = false;
                  }

                  SocketService.blockLiveComment(
                    liveId: _liveId,
                    userId: userId,
                    isBlocked: willBlock,
                  );

                  Navigator.pop(actionCtx);

                  setState(() {});
                  setModalState(() {});
                  if (_viewersModalSetState != null) {
                    _viewersModalSetState!(() {});
                  }

                  if (willBlock) {
                    AppToast.warning(context, l10n.blockedUserCommentToast(userName));
                  } else {
                    AppToast.success(context, l10n.unblockedUserCommentToast(userName));
                  }
                },
              ),

              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_remove_rounded,
                    color: Colors.redAccent,
                    size: 20.r,
                  ),
                ),
                title: Text(
                  l10n.kickFromLive,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n.kickFromLiveDesc,
                  style: TextStyle(color: Colors.white54, fontSize: 11.5.sp),
                ),
                onTap: () {
                  SocketService.kickLiveViewer(
                    liveId: _liveId,
                    userId: userId,
                  );
                  Navigator.pop(actionCtx);
                  setState(() {
                    _viewersList.removeWhere((item) => item['userId'] == userId);
                    _viewersCount = math.max(0, _viewersCount - 1);
                  });
                  setModalState(() {});
                  if (_viewersModalSetState != null) {
                    _viewersModalSetState!(() {});
                  }
                  AppToast.info(context, l10n.kickedUserFromLiveToast(userName));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
