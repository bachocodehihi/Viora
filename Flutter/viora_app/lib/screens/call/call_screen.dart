import 'dart:async';
import 'dart:math' as math;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/app_colors.dart';
import '../../l10n/language.dart';
import '../../services/call_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';
import '../message/messages_screen.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String? callDocId;
  final String channelName;
  final String appId;
  final String token;
  final String peerName;
  final String peerAvatar;
  final String? peerId;
  final String? conversationId;
  final bool isGroup;
  final String? groupName;
  final String? groupAvatar;
  final List<Map<String, dynamic>> initialParticipants;
  final List<String> targetUserIds;
  final bool isCaller;
  final bool initialVideo;
  final DateTime? initialAnsweredAt;

  const CallScreen({
    super.key,
    required this.callId,
    this.callDocId,
    required this.channelName,
    required this.appId,
    required this.token,
    required this.peerName,
    required this.peerAvatar,
    this.peerId,
    this.conversationId,
    this.isGroup = false,
    this.groupName,
    this.groupAvatar,
    this.initialParticipants = const [],
    this.targetUserIds = const [],
    required this.isCaller,
    this.initialVideo = false,
    this.initialAnsweredAt,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallParticipantProfile {
  final String userId;
  final String name;
  final String avatar;
  final int agoraUid;

  const _CallParticipantProfile({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.agoraUid,
  });
}

class _GroupCallTileItem {
  final int agoraUid;
  final String name;
  final String avatar;
  final bool isLocal;
  final bool isVideoOn;
  final bool isAudioMuted;

  const _GroupCallTileItem({
    required this.agoraUid,
    required this.name,
    required this.avatar,
    required this.isLocal,
    required this.isVideoOn,
    required this.isAudioMuted,
  });
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;
  VideoViewController? _localVideoController;

  final List<int> _remoteUids = [];
  final Map<int, VideoViewController> _remoteVideoControllers = {};
  final Map<int, bool> _remoteVideoActive = {};
  final Map<int, bool> _remoteAudioMuted = {};

  final Map<int, _CallParticipantProfile> _participantsByAgoraUid = {};
  final Map<String, _CallParticipantProfile> _participantsByUserId = {};
  final Set<String> _knownTargetIds = {};
  String _localUserId = '';
  String _localUserName = '';
  String _localUserAvatar = '';
  int _localAgoraUid = 0;
  String? _resolvedGroupAvatar;

  late bool _localVideoEnabled;
  bool _isMuted = false;
  late bool _isSpeakerOn;
  bool _userChangedSpeaker = false;
  bool _isFrontCamera = true;
  bool _swapPiP = false;
  bool _controlsVisible = true;

  bool _isConnected = false;
  bool _peerRinging = false;
  bool _isTerminating = false;
  String? _statusMessage;

  bool _peerMutedFromSocket = false;
  bool? _peerVideoFromSocket;

  Timer? _durationTimer;
  Timer? _ringbackTimer;
  Timer? _noAnswerTimer;
  Timer? _statusPollTimer;
  bool _isPollingStatus = false;
  bool _localJoinedAgora = false;
  DateTime? _answeredAt;
  int _elapsedSeconds = 0;

  double _pipRight = 16;
  double _pipTop = 96;

  late final Function(Map<String, dynamic>) _onCallAccepted;
  late final Function(Map<String, dynamic>) _onCallDeclined;
  late final Function(Map<String, dynamic>) _onCallEnded;
  late final Function(Map<String, dynamic>) _onCallCancelled;
  late final Function(Map<String, dynamic>) _onCallRinging;
  late final Function(Map<String, dynamic>) _onCallMediaState;
  StreamSubscription<Map<String, String>>? _terminalSub;

  String get _displayTitle {
    if (widget.isGroup && widget.groupName != null && widget.groupName!.trim().isNotEmpty) {
      return widget.groupName!.trim();
    }
    return widget.peerName.isNotEmpty ? widget.peerName : 'Viora';
  }

  String get _displayAvatar {
    if (widget.isGroup) {
      final cached = _resolvedGroupAvatar?.trim() ?? '';
      if (cached.isNotEmpty) return cached;
      final gAvatar = widget.groupAvatar?.trim() ?? '';
      if (gAvatar.isNotEmpty) return gAvatar;
      final pAvatar = widget.peerAvatar.trim();
      if (pAvatar.isNotEmpty) return pAvatar;
      return CallService.computeGroupInitials(_displayTitle);
    }
    return widget.peerAvatar;
  }

  bool get _hasAnyRemoteVideo =>
      _remoteUids.any((uid) => _remoteVideoActive[uid] == true && _remoteVideoControllers.containsKey(uid));

  bool get _isVideoUiMode => _localVideoEnabled || _hasAnyRemoteVideo;

  @override
  void initState() {
    super.initState();
    _localVideoEnabled = widget.initialVideo;
    _isSpeakerOn = widget.initialVideo;
    _answeredAt = widget.initialAnsweredAt;
    _resolvedGroupAvatar = widget.groupAvatar;
    _knownTargetIds.addAll(widget.targetUserIds.where((e) => e.isNotEmpty));
    _ingestParticipants(widget.initialParticipants);
    _seedFallbackPeerParticipant();

    CallService.markCallScreenOpened(widget.callId);
    unawaited(_loadLocalUserProfile());
    unawaited(SocketService.init());
    _bindSocketListeners();
    _startStatusPolling();
    _initCallTimers();
    _initAgora();
  }

  Future<void> _loadLocalUserProfile() async {
    final uid = (await SessionService.getUserId()) ?? '';
    final uname = (await SessionService.getUsername()) ?? '';
    final uavatar = (await SessionService.getAvatar()) ?? '';
    if (!mounted) return;
    setState(() {
      _localUserId = uid;
      _localUserName = uname;
      _localUserAvatar = uavatar;
      _localAgoraUid = CallService.agoraUidForUserId(uid);
      if (uid.isNotEmpty) {
        _knownTargetIds.remove(uid);
      }
    });
  }

  void _seedFallbackPeerParticipant() {
    final pId = widget.peerId?.trim() ?? '';
    if (pId.isEmpty || _participantsByUserId.containsKey(pId)) return;
    final uid = CallService.agoraUidForUserId(pId);
    if (uid <= 0) return;
    final profile = _CallParticipantProfile(
      userId: pId,
      name: widget.peerName.isNotEmpty ? widget.peerName : 'Viora',
      avatar: widget.isGroup ? '' : widget.peerAvatar,
      agoraUid: uid,
    );
    _participantsByUserId[pId] = profile;
    _participantsByAgoraUid[uid] = profile;
  }

  void _ingestParticipants(dynamic rawList) {
    final parsed = CallService.parseParticipantsList(rawList);
    if (parsed.isEmpty) return;
    for (final item in parsed) {
      final userId = item['userId']?.toString() ?? '';
      if (userId.isEmpty) continue;
      final agoraUid = (item['agoraUid'] is int)
          ? item['agoraUid'] as int
          : CallService.agoraUidForUserId(userId);
      final profile = _CallParticipantProfile(
        userId: userId,
        name: (item['name']?.toString().trim().isNotEmpty == true)
            ? item['name'].toString().trim()
            : 'Viora',
        avatar: item['avatar']?.toString() ?? '',
        agoraUid: agoraUid,
      );
      _participantsByUserId[userId] = profile;
      if (agoraUid > 0) {
        _participantsByAgoraUid[agoraUid] = profile;
      }
      if (userId != _localUserId) {
        _knownTargetIds.add(userId);
      }
    }
  }

  Future<void> _refreshParticipantsFromServer() async {
    final call = await CallService.fetchCallStatus(
      widget.callId,
      timeout: const Duration(seconds: 3),
    );
    if (!mounted || call == null) return;
    setState(() {
      _ingestParticipants(call['participants']);
      final gAvatar = call['groupAvatar']?.toString().trim() ?? '';
      if (gAvatar.isNotEmpty) {
        _resolvedGroupAvatar = gAvatar;
      }
    });
  }

  void _initCallTimers() {
    if (widget.isCaller) {
      CallSoundHelper.playRingbackPulse();
      _ringbackTimer = Timer.periodic(const Duration(milliseconds: 3400), (_) {
        if (!_isConnected && !_isTerminating) {
          CallSoundHelper.playRingbackPulse();
        }
      });

      _noAnswerTimer = Timer(const Duration(seconds: 35), () async {
        if (!_isConnected && !_isTerminating && mounted) {
          _stopRingingAndTimers();
          await CallService.missedCall(
            callId: widget.callId,
            callDocId: widget.callDocId,
          );
          if (mounted) {
            _finishWithStatus(context.l10n.callNoAnswerStatus);
          }
        }
      });
    }
  }

  void _startStatusPolling() {
    int connectedTick = 0;
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_isTerminating || _isPollingStatus || !mounted) return;
      bool shouldPing = false;
      if (_isConnected) {
        connectedTick++;
        if (widget.isGroup) {
          if (connectedTick % 10 != 0) return;
          shouldPing = true;
          SocketService.emitCallHeartbeat(
            callId: widget.callId,
            callDocId: widget.callDocId,
          );
        } else {
          if (connectedTick % 2 != 0) return;
        }
      }
      _isPollingStatus = true;
      try {
        final call = await CallService.fetchCallStatus(
          widget.callId,
          timeout: const Duration(seconds: 2),
          ping: shouldPing,
        );
        if (!mounted || _isTerminating || call == null) return;
        final status = call['status']?.toString();
        if (status == 'declined') {
          if (!widget.isGroup) {
            _finishWithStatus(context.l10n.callDeclinedStatus);
          }
        } else if (status == 'cancelled') {
          _finishWithStatus(context.l10n.callCancelledStatus);
        } else if (status == 'missed') {
          _finishWithStatus(context.l10n.callNoAnswerStatus);
        } else if (status == 'completed') {
          _finishWithStatus(context.l10n.callEndedStatus);
        } else if (status == 'ongoing' && !_isConnected) {
          final rawAnswered = call['answeredAt']?.toString();
          final parsedAnswered = rawAnswered != null && rawAnswered.isNotEmpty
              ? DateTime.tryParse(rawAnswered)
              : null;
          if (parsedAnswered != null) {
            _answeredAt ??= parsedAnswered;
          }
          _ingestParticipants(call['participants']);
          if (widget.isCaller || _localJoinedAgora) {
            _startConnectedTimer(answeredAt: _answeredAt);
          }
        } else if (call['participants'] != null) {
          _ingestParticipants(call['participants']);
        }
      } finally {
        _isPollingStatus = false;
      }
    });
  }

  void _stopRingingAndTimers() {
    _ringbackTimer?.cancel();
    _ringbackTimer = null;
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    CallSoundHelper.stopRingback();
  }

  void _startConnectedTimer({DateTime? answeredAt}) {
    if (answeredAt != null) {
      _answeredAt ??= answeredAt;
    }
    final effectiveAnsweredAt = _answeredAt;
    if (!_isConnected && effectiveAnsweredAt != null && _elapsedSeconds == 0) {
      final diff = DateTime.now().difference(effectiveAnsweredAt).inSeconds;
      if (diff > 0 && diff < 86400) {
        _elapsedSeconds = diff;
      }
    }
    if (_isConnected && _durationTimer != null) return;
    _stopRingingAndTimers();
    _isConnected = true;
    SocketService.emitCallHeartbeat(
      callId: widget.callId,
      callDocId: widget.callDocId,
    );
    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
    if (mounted) setState(() {});
  }

  String get _formattedDuration {
    final hours = _elapsedSeconds ~/ 3600;
    final mins = (_elapsedSeconds % 3600) ~/ 60;
    final secs = _elapsedSeconds % 60;
    final mStr = mins.toString().padLeft(2, '0');
    final sStr = secs.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  void _ensureRemoteVideoDecoding() {
    final engine = _engine;
    if (engine == null || _isTerminating) return;
    unawaited(
      engine.enableVideo().then((_) async {
        if (!_localVideoEnabled && !_isTerminating && _engine != null) {
          await _engine!.enableLocalVideo(false);
          await _engine!.muteLocalVideoStream(true);
        }
      }).catchError((_) {}),
    );
  }

  void _bindSocketListeners() {
    _onCallRinging = (data) {
      if (!mounted || data['callId']?.toString() != widget.callId) return;
      if (widget.isCaller && !_isConnected) {
        setState(() => _peerRinging = true);
      }
    };

    _onCallAccepted = (data) {
      if (!mounted || data['callId']?.toString() != widget.callId) return;
      final rawAnswered = data['answeredAt']?.toString();
      final parsedAnswered = rawAnswered != null && rawAnswered.isNotEmpty
          ? DateTime.tryParse(rawAnswered)
          : null;
      final acceptedBy = data['acceptedBy']?.toString() ?? '';
      if (acceptedBy.isNotEmpty) {
        final rawUid = int.tryParse(data['agoraUid']?.toString() ?? '') ?? 0;
        final agoraUid = rawUid > 0 ? rawUid : CallService.agoraUidForUserId(acceptedBy);
        final profile = _CallParticipantProfile(
          userId: acceptedBy,
          name: (data['accepterName']?.toString().trim().isNotEmpty == true)
              ? data['accepterName'].toString().trim()
              : (_participantsByUserId[acceptedBy]?.name ?? 'Viora'),
          avatar: (data['accepterAvatar']?.toString().trim().isNotEmpty == true)
              ? data['accepterAvatar'].toString().trim()
              : (_participantsByUserId[acceptedBy]?.avatar ?? ''),
          agoraUid: agoraUid,
        );
        _participantsByUserId[acceptedBy] = profile;
        if (agoraUid > 0) {
          _participantsByAgoraUid[agoraUid] = profile;
        }
        if (acceptedBy != _localUserId) {
          _knownTargetIds.add(acceptedBy);
        }
      }
      _ingestParticipants(data['participants']);
      _startConnectedTimer(answeredAt: parsedAnswered);
    };

    _onCallDeclined = (data) {
      if (!mounted || data['callId']?.toString() != widget.callId) return;
      if (!widget.isGroup && !_isTerminating) {
        _finishWithStatus(context.l10n.callDeclinedStatus);
      }
    };

    _onCallEnded = (data) {
      if (!mounted || data['callId']?.toString() != widget.callId) return;
      if (!_isTerminating) {
        _finishWithStatus(context.l10n.callEndedStatus);
      }
    };

    _onCallCancelled = (data) {
      if (!mounted || data['callId']?.toString() != widget.callId) return;
      if (!_isTerminating) {
        _finishWithStatus(context.l10n.callCancelledStatus);
      }
    };

    _onCallMediaState = (data) {
      if (!mounted || data['callId']?.toString() != widget.callId) return;
      final senderUserId = data['userId']?.toString() ?? '';
      final isVideoOn = data['isVideoOn'] == true;
      final isAudioMuted = data['isAudioMuted'] == true;
      if (isVideoOn) {
        _ensureRemoteVideoDecoding();
      }
      setState(() {
        _peerMutedFromSocket = isAudioMuted;
        _peerVideoFromSocket = isVideoOn;
        if (widget.isGroup && senderUserId.isNotEmpty) {
          final targetUid = _participantsByUserId[senderUserId]?.agoraUid ??
              CallService.agoraUidForUserId(senderUserId);
          if (targetUid > 0) {
            _remoteVideoActive[targetUid] = isVideoOn;
            _remoteAudioMuted[targetUid] = isAudioMuted;
          }
        } else if (!widget.isGroup && _remoteUids.isNotEmpty) {
          _remoteVideoActive[_remoteUids.first] = isVideoOn;
          _remoteAudioMuted[_remoteUids.first] = isAudioMuted;
        }
      });
      if (isVideoOn && !_isSpeakerOn && !_userChangedSpeaker) {
        _setSpeaker(true);
      }
    };

    SocketService.onCallRinging(_onCallRinging);
    SocketService.onCallAccepted(_onCallAccepted);
    SocketService.onCallDeclined(_onCallDeclined);
    SocketService.onCallEnded(_onCallEnded);
    SocketService.onCallCancelled(_onCallCancelled);
    SocketService.onCallMediaState(_onCallMediaState);

    _terminalSub = CallService.terminalCallStream.listen((event) {
      if (!mounted || _isTerminating) return;
      if (event['callId'] != widget.callId) return;
      final type = event['type'];
      if (type == 'call_declined') {
        if (!widget.isGroup) {
          _finishWithStatus(context.l10n.callDeclinedStatus);
        }
      } else if (type == 'call_cancelled') {
        _finishWithStatus(context.l10n.callCancelledStatus);
      } else if (type == 'call_missed') {
        _finishWithStatus(context.l10n.callNoAnswerStatus);
      } else if (type == 'call_ended') {
        _finishWithStatus(context.l10n.callEndedStatus);
      }
    });
  }

  VideoViewController _createLocalController() {
    return VideoViewController(
      rtcEngine: _engine!,
      canvas: const VideoCanvas(
        uid: 0,
        renderMode: RenderModeType.renderModeHidden,
      ),
      useFlutterTexture: true,
      useAndroidSurfaceView: false,
    );
  }

  VideoViewController _createRemoteController(int uid) {
    return VideoViewController.remote(
      rtcEngine: _engine!,
      canvas: VideoCanvas(
        uid: uid,
        renderMode: RenderModeType.renderModeHidden,
      ),
      connection: RtcConnection(channelId: widget.channelName),
      useFlutterTexture: true,
      useAndroidSurfaceView: false,
    );
  }

  Future<void> _initAgora() async {
    try {
      if (widget.appId.isEmpty || widget.channelName.isEmpty || widget.token.isEmpty) {
        if (mounted) {
          _finishWithStatus(
            context.l10n.cannotJoinCall,
            notifyServer: widget.isCaller && !_isConnected,
          );
        }
        return;
      }

      await CallSoundHelper.stopRingtone();

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: widget.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            _localJoinedAgora = true;
            Future.delayed(const Duration(milliseconds: 150), () {
              if (!_isTerminating && _engine != null) {
                _setSpeaker(_isSpeakerOn);
              }
            });
            if (!widget.isCaller && _answeredAt != null && !_isConnected && !_isTerminating) {
              _startConnectedTimer(answeredAt: _answeredAt);
            }
            if (mounted) setState(() {});
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (!mounted) return;
            _startConnectedTimer(answeredAt: _answeredAt);
            if (widget.isGroup && !_participantsByAgoraUid.containsKey(remoteUid)) {
              unawaited(_refreshParticipantsFromServer());
            }
            setState(() {
              if (!_remoteUids.contains(remoteUid)) {
                _remoteUids.add(remoteUid);
              }
              _remoteVideoControllers.putIfAbsent(
                remoteUid,
                () => _createRemoteController(remoteUid),
              );
              if (_peerVideoFromSocket != null && !widget.isGroup) {
                _remoteVideoActive[remoteUid] = _peerVideoFromSocket!;
              } else {
                _remoteVideoActive.putIfAbsent(remoteUid, () => false);
              }
            });
          },
          onRemoteVideoStateChanged: (
            RtcConnection connection,
            int remoteUid,
            RemoteVideoState state,
            RemoteVideoStateReason reason,
            int elapsed,
          ) {
            if (!mounted) return;
            if (state == RemoteVideoState.remoteVideoStateDecoding) {
              _ensureRemoteVideoDecoding();
              _startConnectedTimer(answeredAt: _answeredAt);
              setState(() {
                if (!_remoteUids.contains(remoteUid)) {
                  _remoteUids.add(remoteUid);
                }
                _remoteVideoControllers.putIfAbsent(
                  remoteUid,
                  () => _createRemoteController(remoteUid),
                );
                _remoteVideoActive[remoteUid] = true;
              });
              if (!_isSpeakerOn && !_userChangedSpeaker) {
                _setSpeaker(true);
              }
            } else if (state == RemoteVideoState.remoteVideoStateStopped ||
                state == RemoteVideoState.remoteVideoStateFrozen ||
                state == RemoteVideoState.remoteVideoStateFailed) {
              setState(() {
                _remoteVideoActive[remoteUid] = false;
              });
            }
          },
          onFirstRemoteVideoDecoded: (
            RtcConnection connection,
            int remoteUid,
            int width,
            int height,
            int elapsed,
          ) {
            if (!mounted) return;
            _ensureRemoteVideoDecoding();
            _startConnectedTimer(answeredAt: _answeredAt);
            setState(() {
              if (!_remoteUids.contains(remoteUid)) {
                _remoteUids.add(remoteUid);
              }
              _remoteVideoControllers.putIfAbsent(
                remoteUid,
                () => _createRemoteController(remoteUid),
              );
              _remoteVideoActive[remoteUid] = true;
            });
          },
          onUserMuteVideo: (RtcConnection connection, int remoteUid, bool muted) {
            if (!mounted) return;
            setState(() {
              _remoteVideoActive[remoteUid] = !muted;
            });
          },
          onUserEnableVideo: (RtcConnection connection, int remoteUid, bool enabled) {
            if (!mounted) return;
            if (enabled) {
              _ensureRemoteVideoDecoding();
            }
            setState(() {
              _remoteVideoActive[remoteUid] = enabled;
            });
          },
          onUserMuteAudio: (RtcConnection connection, int remoteUid, bool muted) {
            if (!mounted) return;
            setState(() {
              _remoteAudioMuted[remoteUid] = muted;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            if (!mounted) return;
            final oldController = _remoteVideoControllers.remove(remoteUid);
            _remoteVideoActive.remove(remoteUid);
            _remoteAudioMuted.remove(remoteUid);
            _remoteUids.remove(remoteUid);
            setState(() {});
            WidgetsBinding.instance.addPostFrameCallback((_) {
              oldController?.dispose();
            });

            if (!widget.isGroup && _remoteUids.isEmpty && !_isTerminating) {
              _finishWithStatus(context.l10n.callEndedStatus);
            }
          },
          onConnectionStateChanged: (
            RtcConnection connection,
            ConnectionStateType state,
            ConnectionChangedReasonType reason,
          ) {
            debugPrint('[Agora Call] connection state: $state, reason: $reason');
            if (!mounted || _isTerminating) return;
            if (state == ConnectionStateType.connectionStateFailed &&
                (reason == ConnectionChangedReasonType.connectionChangedInvalidAppId ||
                    reason == ConnectionChangedReasonType.connectionChangedInvalidChannelName ||
                    reason == ConnectionChangedReasonType.connectionChangedInvalidToken ||
                    reason == ConnectionChangedReasonType.connectionChangedTokenExpired ||
                    reason == ConnectionChangedReasonType.connectionChangedJoinFailed ||
                    reason == ConnectionChangedReasonType.connectionChangedRejectedByServer)) {
              _finishWithStatus(
                context.l10n.cannotJoinCall,
                notifyServer: widget.isCaller && !_isConnected,
              );
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[Agora Call] Error: $err, $msg');
            if (!mounted || _isTerminating) return;
            if (err == ErrorCodeType.errInvalidAppId ||
                err == ErrorCodeType.errInvalidToken ||
                err == ErrorCodeType.errTokenExpired ||
                err == ErrorCodeType.errInvalidChannelName) {
              _finishWithStatus(
                context.l10n.cannotJoinCall,
                notifyServer: widget.isCaller && !_isConnected,
              );
            }
          },
        ),
      );

      try {
        await _engine!.enableAudio();
      } catch (e) {
        debugPrint('[Agora Call] enableAudio error: $e');
      }

      try {
        await _engine!.setDefaultAudioRouteToSpeakerphone(_isSpeakerOn);
      } catch (e) {
        debugPrint('[Agora Call] setDefaultAudioRouteToSpeakerphone error: $e');
      }

      if (_localVideoEnabled) {
        try {
          await _engine!.enableVideo();
          await _engine!.enableLocalVideo(true);
          _localVideoController = _createLocalController();
          await _engine!.startPreview();
          await _engine!.muteLocalVideoStream(false);
        } catch (e) {
          debugPrint('[Agora Call] local video init error: $e');
        }
      } else {
        try {
          await _engine!.enableVideo();
          await _engine!.enableLocalVideo(false);
          await _engine!.muteLocalVideoStream(true);
        } catch (e) {
          debugPrint('[Agora Call] audio-only video prep error: $e');
        }
      }

      if (mounted) setState(() {});

      try {
        final effectiveLocalUid = _localAgoraUid > 0
            ? _localAgoraUid
            : CallService.agoraUidForUserId(await SessionService.getUserId());
        _localAgoraUid = effectiveLocalUid;
        await _engine!.joinChannel(
          token: widget.token,
          channelId: widget.channelName,
          uid: effectiveLocalUid,
          options: ChannelMediaOptions(
            channelProfile: ChannelProfileType.channelProfileCommunication,
            publishMicrophoneTrack: true,
            publishCameraTrack: _localVideoEnabled,
            enableAudioRecordingOrPlayout: true,
            autoSubscribeAudio: true,
            autoSubscribeVideo: true,
          ),
        );
      } catch (e) {
        debugPrint('[Agora Call] joinChannel error: $e');
        if (mounted && !_isTerminating) {
          _finishWithStatus(
            context.l10n.cannotJoinCall,
            notifyServer: widget.isCaller && !_isConnected,
          );
        }
      }
    } catch (e) {
      debugPrint('[Agora Call] init error: $e');
      if (mounted && !_isTerminating) {
        _finishWithStatus(
          context.l10n.cannotJoinCall,
          notifyServer: widget.isCaller && !_isConnected,
        );
      }
    }
  }

  Future<void> _setSpeaker(bool enabled) async {
    try {
      await _engine?.setEnableSpeakerphone(enabled);
      if (mounted) {
        setState(() => _isSpeakerOn = enabled);
      }
    } catch (e) {
      debugPrint('[Agora Call] setEnableSpeakerphone error: $e');
    }
  }

  Future<void> _toggleMute() async {
    if (_isTerminating) return;
    final nextMuted = !_isMuted;
    try {
      await _engine?.muteLocalAudioStream(nextMuted);
      await _engine?.updateChannelMediaOptions(
        ChannelMediaOptions(
          publishMicrophoneTrack: !nextMuted,
          publishCameraTrack: _localVideoEnabled,
        ),
      );
      if (mounted) {
        setState(() => _isMuted = nextMuted);
      }
      SocketService.emitCallMediaState(
        callId: widget.callId,
        targetUserIds: _resolvedTargets,
        isVideoOn: _localVideoEnabled,
        isAudioMuted: nextMuted,
      );
    } catch (e) {
      debugPrint('[Agora Call] toggleMute error: $e');
    }
  }

  Future<void> _toggleSpeaker() async {
    _userChangedSpeaker = true;
    await _setSpeaker(!_isSpeakerOn);
  }

  Future<void> _toggleCamera() async {
    if (_isTerminating || _engine == null) return;
    final nextVideo = !_localVideoEnabled;

    if (nextVideo) {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final req = await Permission.camera.request();
        if (!req.isGranted) {
          if (mounted) {
            AppToast.error(context, context.l10n.cameraPermissionRequired);
          }
          return;
        }
      }

      try {
        try {
          await _engine!.enableVideo();
        } catch (_) {}
        await _engine!.enableLocalVideo(true);
        await _engine!.startPreview();
        await _engine!.muteLocalVideoStream(false);
        await _engine!.updateChannelMediaOptions(
          ChannelMediaOptions(
            publishCameraTrack: true,
            publishMicrophoneTrack: !_isMuted,
          ),
        );
        final ctrl = _createLocalController();
        if (mounted) {
          setState(() {
            _localVideoController = ctrl;
            _localVideoEnabled = true;
          });
        }
        if (!_isSpeakerOn && !_userChangedSpeaker) {
          await _setSpeaker(true);
        }
        SocketService.emitCallMediaState(
          callId: widget.callId,
          targetUserIds: _resolvedTargets,
          isVideoOn: true,
          isAudioMuted: _isMuted,
        );
      } catch (e) {
        debugPrint('[Agora Call] enable camera error: $e');
      }
    } else {
      final oldCtrl = _localVideoController;
      if (mounted) {
        setState(() {
          _localVideoEnabled = false;
          _localVideoController = null;
          _swapPiP = false;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldCtrl?.dispose();
      });

      try {
        await _engine!.muteLocalVideoStream(true);
        await _engine!.enableLocalVideo(false);
        await _engine!.stopPreview();
        await _engine!.updateChannelMediaOptions(
          ChannelMediaOptions(
            publishCameraTrack: false,
            publishMicrophoneTrack: !_isMuted,
          ),
        );
        SocketService.emitCallMediaState(
          callId: widget.callId,
          targetUserIds: _resolvedTargets,
          isVideoOn: false,
          isAudioMuted: _isMuted,
        );
      } catch (e) {
        debugPrint('[Agora Call] disable camera error: $e');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (!_localVideoEnabled || _engine == null) return;
    try {
      await _engine!.switchCamera();
      if (mounted) {
        setState(() => _isFrontCamera = !_isFrontCamera);
      }
    } catch (e) {
      debugPrint('[Agora Call] switchCamera error: $e');
    }
  }

  List<String> get _resolvedTargets {
    if (_knownTargetIds.isNotEmpty) return _knownTargetIds.toList();
    if (widget.targetUserIds.isNotEmpty) return widget.targetUserIds;
    if (widget.peerId != null && widget.peerId!.isNotEmpty) return [widget.peerId!];
    return const [];
  }

  Future<void> _hangUp() async {
    if (_isTerminating) return;
    _finishWithStatus(
      context.l10n.callEndedStatus,
      notifyServer: true,
      endForAll: false,
    );
  }

  Future<void> _finishWithStatus(
    String statusText, {
    bool notifyServer = false,
    bool endForAll = false,
  }) async {
    if (_isTerminating) return;
    _isTerminating = true;
    _stopRingingAndTimers();
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _terminalSub?.cancel();
    _terminalSub = null;
    _durationTimer?.cancel();
    _durationTimer = null;

    if (mounted) {
      setState(() => _statusMessage = statusText);
    }

    if (notifyServer) {
      unawaited(
        CallService.endCall(
          callId: widget.callId,
          callDocId: widget.callDocId,
          endForAll: endForAll,
        ),
      );
    }

    await CallSoundHelper.stopRingtone();
    await CallService.dismissCallFromFcm({'callId': widget.callId});

    await _cleanupAgora().timeout(const Duration(seconds: 2), onTimeout: () {});

    await Future.delayed(const Duration(milliseconds: 550));
    CallService.markCallScreenClosed(widget.callId);
    CallService.notifyCallLogSync(widget.conversationId);
    MessagesScreen.triggerRefresh();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _cleanupAgora() async {
    try {
      final engine = _engine;
      _engine = null;
      if (engine != null) {
        await engine.stopPreview();
        await engine.leaveChannel();
        await engine.release();
      }
    } catch (e) {
      debugPrint('[Agora Call] cleanup error: $e');
    }
  }

  @override
  void dispose() {
    _stopRingingAndTimers();
    _statusPollTimer?.cancel();
    _terminalSub?.cancel();
    _durationTimer?.cancel();
    CallSoundHelper.stopRingtone();
    SocketService.offCallRinging(_onCallRinging);
    SocketService.offCallAccepted(_onCallAccepted);
    SocketService.offCallDeclined(_onCallDeclined);
    SocketService.offCallEnded(_onCallEnded);
    SocketService.offCallCancelled(_onCallCancelled);
    SocketService.offCallMediaState(_onCallMediaState);
    CallService.markCallScreenClosed(widget.callId);

    final engine = _engine;
    _engine = null;
    if (engine != null) {
      engine.leaveChannel().then((_) => engine.release()).catchError((_) {});
    }
    super.dispose();
  }

  String _currentStatusLabel(Language l10n) {
    if (_statusMessage != null) return _statusMessage!;
    if (_isConnected) return _formattedDuration;
    if (widget.isCaller) {
      return _peerRinging ? l10n.ringingStatus : l10n.callingStatus;
    }
    return l10n.connectingStatus;
  }

  bool get _isSinglePeerMuted {
    if (widget.isGroup) return false;
    if (_remoteUids.isNotEmpty) {
      final uid = _remoteUids.first;
      if (_remoteAudioMuted[uid] == true) return true;
    }
    return _peerMutedFromSocket;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusText = _currentStatusLabel(l10n);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1C),
        body: widget.isGroup
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0E1628), Color(0xFF080C16)],
                  ),
                ),
                child: Column(
                  children: [
                    _buildTopOverlay(l10n, statusText),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        child: _buildGroupStage(l10n, statusText),
                      ),
                    ),
                    _buildBottomControls(l10n),
                  ],
                ),
              )
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_isVideoUiMode) {
                    setState(() => _controlsVisible = !_controlsVisible);
                  }
                },
                child: Stack(
                  children: [
                    // Main background / remote video or voice layout
                    Positioned.fill(
                      child: _isVideoUiMode
                          ? _buildVideoStage(l10n, statusText)
                          : _buildVoiceStage(l10n, statusText),
                    ),

                    // Draggable PiP card when local camera OR swapped view is active
                    if (_shouldShowPiP) _buildDraggablePiP(),

                    // Top bar (visible in video mode or subtle header)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      top: _controlsVisible || !_isVideoUiMode ? 0 : -120.h,
                      left: 0,
                      right: 0,
                      child: _buildTopOverlay(l10n, statusText),
                    ),

                    // Bottom call control dock
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      bottom: _controlsVisible || !_isVideoUiMode ? 0 : -180.h,
                      left: 0,
                      right: 0,
                      child: _buildBottomControls(l10n),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  bool get _shouldShowPiP {
    if (widget.isGroup) return false;
    if (!_isVideoUiMode) return false;
    if (_swapPiP && _localVideoEnabled && _hasAnyRemoteVideo) return true;
    return _localVideoEnabled && _localVideoController != null && (_hasAnyRemoteVideo || _isConnected);
  }

  Widget _buildGroupStage(Language l10n, String statusText) {
    if (_remoteUids.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.1,
                  colors: [
                    Color(0xFF1A2A48),
                    Color(0xFF0D1424),
                    Color(0xFF090E1A),
                  ],
                ),
              ),
            ),
            if (_localVideoEnabled && _localVideoController != null) ...[
              AgoraVideoView(controller: _localVideoController!),
              Container(color: Colors.black.withValues(alpha: 0.42)),
            ],
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 148.w,
                          height: 148.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.blue.withValues(alpha: 0.16),
                          ),
                        ),
                        AppAvatar(
                          avatar: _displayAvatar,
                          name: _displayTitle,
                          color: AppColors.blue,
                          radius: 60.r,
                          fontSize: 36.sp,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 2.5.w,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      _displayTitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isConnected
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withValues(alpha: 0.72),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        letterSpacing: _isConnected ? 1.2 : 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tiles = <_GroupCallTileItem>[];
    for (int i = 0; i < _remoteUids.length; i++) {
      final uid = _remoteUids[i];
      final profile = _participantsByAgoraUid[uid];
      final resolvedName = (profile != null && profile.name.trim().isNotEmpty)
          ? profile.name.trim()
          : (widget.peerId != null &&
                  CallService.agoraUidForUserId(widget.peerId) == uid &&
                  widget.peerName.isNotEmpty)
              ? widget.peerName
              : 'Member ${i + 1}';
      final resolvedAvatar = profile?.avatar ?? '';
      final isCamOn =
          _remoteVideoActive[uid] == true && _remoteVideoControllers.containsKey(uid);
      final isAudioOff = _remoteAudioMuted[uid] == true;
      tiles.add(
        _GroupCallTileItem(
          agoraUid: uid,
          name: resolvedName,
          avatar: resolvedAvatar,
          isLocal: false,
          isVideoOn: isCamOn,
          isAudioMuted: isAudioOff,
        ),
      );
    }

    tiles.add(
      _GroupCallTileItem(
        agoraUid: 0,
        name: _localUserName.trim().isNotEmpty ? _localUserName.trim() : l10n.you,
        avatar: _localUserAvatar,
        isLocal: true,
        isVideoOn: _localVideoEnabled && _localVideoController != null,
        isAudioMuted: _isMuted,
      ),
    );

    return _buildResponsiveGroupTilesLayout(tiles);
  }

  Widget _buildResponsiveGroupTilesLayout(List<_GroupCallTileItem> tiles) {
    final count = tiles.length;
    if (count == 2) {
      return Column(
        children: [
          Expanded(child: _buildGroupParticipantTile(tiles[0], tileCount: count)),
          SizedBox(height: 8.h),
          Expanded(child: _buildGroupParticipantTile(tiles[1], tileCount: count)),
        ],
      );
    }

    if (count == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildGroupParticipantTile(tiles[0], tileCount: count)),
                SizedBox(width: 8.w),
                Expanded(child: _buildGroupParticipantTile(tiles[1], tileCount: count)),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(child: _buildGroupParticipantTile(tiles[2], tileCount: count)),
        ],
      );
    }

    if (count == 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildGroupParticipantTile(tiles[0], tileCount: count)),
                SizedBox(width: 8.w),
                Expanded(child: _buildGroupParticipantTile(tiles[1], tileCount: count)),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildGroupParticipantTile(tiles[2], tileCount: count)),
                SizedBox(width: 8.w),
                Expanded(child: _buildGroupParticipantTile(tiles[3], tileCount: count)),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tileWidth = (constraints.maxWidth - 8.w) / 2;
        final double tileHeight = ((constraints.maxHeight - 16.h) / 3).clamp(120.h, 220.h);
        final double ratio = tileHeight > 0 ? (tileWidth / tileHeight) : 0.82;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8.w,
            mainAxisSpacing: 8.h,
            childAspectRatio: ratio,
          ),
          itemCount: count,
          itemBuilder: (context, idx) =>
              _buildGroupParticipantTile(tiles[idx], tileCount: count),
        );
      },
    );
  }

  Widget _buildGroupParticipantTile(_GroupCallTileItem tile, {required int tileCount}) {
    final VideoViewController? videoCtrl = tile.isLocal
        ? _localVideoController
        : _remoteVideoControllers[tile.agoraUid];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double shortestSide = math.min(constraints.maxWidth, constraints.maxHeight);
        final double maxAvatarRadius = tileCount <= 2 ? 46.r : 36.r;
        final double avatarRadius = (shortestSide * 0.23).clamp(22.r, maxAvatarRadius);
        final double avatarFontSize = (avatarRadius * 0.62).clamp(14.sp, 26.sp);
        final double nameFontSize =
            (tileCount <= 2 ? 15.sp : 13.sp).clamp(11.sp, 16.sp);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131D33),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1.2.w,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 12.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17.r),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.1),
                      radius: 0.95,
                      colors: [
                        Color(0xFF1D2E50),
                        Color(0xFF10192C),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.blue.withValues(alpha: 0.14),
                            ),
                            child: AppAvatar(
                              avatar: tile.avatar,
                              name: tile.name,
                              radius: avatarRadius,
                              fontSize: avatarFontSize,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.24),
                                width: 2.w,
                              ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            tile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: nameFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (tile.isVideoOn && videoCtrl != null)
                  AgoraVideoView(controller: videoCtrl),
                if (tile.isVideoOn || tile.isAudioMuted)
                  Positioned(
                    left: 10.w,
                    right: 10.w,
                    bottom: 8.h,
                    child: Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.52),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1.w,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7.w,
                                  height: 7.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tile.isAudioMuted
                                        ? Colors.redAccent
                                        : const Color(0xFF4ADE80),
                                  ),
                                ),
                                if (tile.isVideoOn) ...[
                                  SizedBox(width: 6.w),
                                  Flexible(
                                    child: Text(
                                      tile.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                if (tile.isAudioMuted) ...[
                                  SizedBox(width: 5.w),
                                  Icon(
                                    Icons.mic_off_rounded,
                                    color: Colors.redAccent,
                                    size: 13.sp,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceStage(Language l10n, String statusText) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.25),
          radius: 1.15,
          colors: [
            Color(0xFF1A2A48),
            Color(0xFF0D1424),
            Color(0xFF070A12),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 90.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 156.w,
                      height: 156.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.blue.withValues(alpha: 0.14),
                      ),
                    ),
                    AppAvatar(
                      avatar: widget.peerAvatar,
                      name: _displayTitle,
                      radius: 64.r,
                      fontSize: 40.sp,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2.5.w,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28.w),
                  child: Text(
                    _displayTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  statusText,
                  style: TextStyle(
                    color: _isConnected
                        ? const Color(0xFF4ADE80)
                        : Colors.white.withValues(alpha: 0.72),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    letterSpacing: _isConnected ? 1.2 : 0.2,
                  ),
                ),
                if (_isSinglePeerMuted) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic_off_rounded, color: Colors.redAccent, size: 15.sp),
                        SizedBox(width: 6.w),
                        Text(
                          l10n.peerMuted,
                          style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoStage(Language l10n, String statusText) {
    final activeRemoteUids = _remoteUids
        .where((uid) => _remoteVideoActive[uid] == true && _remoteVideoControllers.containsKey(uid))
        .toList();

    // If user swapped local to fullscreen and there is exactly 1 remote video
    if (_swapPiP && _localVideoEnabled && _localVideoController != null) {
      return AgoraVideoView(controller: _localVideoController!);
    }

    // Multi-party remote video grid for group calls
    if (widget.isGroup && activeRemoteUids.length > 1) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: 72.h, bottom: 112.h, left: 8.w, right: 8.w),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              childAspectRatio: 0.75,
            ),
            itemCount: activeRemoteUids.length,
            itemBuilder: (context, idx) {
              final uid = activeRemoteUids[idx];
              return ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: AgoraVideoView(controller: _remoteVideoControllers[uid]!),
              );
            },
          ),
        ),
      );
    }

    // 1-1 or single remote stream active
    if (activeRemoteUids.isNotEmpty) {
      final uid = activeRemoteUids.first;
      return AgoraVideoView(controller: _remoteVideoControllers[uid]!);
    }

    // Local camera is ON, remote peer hasn't joined yet -> fullscreen local preview while calling!
    if (!_isConnected && _localVideoEnabled && _localVideoController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AgoraVideoView(controller: _localVideoController!),
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppAvatar(
                    avatar: widget.peerAvatar,
                    name: _displayTitle,
                    radius: 52.r,
                    fontSize: 32.sp,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    _displayTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    statusText,
                    style: TextStyle(color: Colors.white70, fontSize: 15.sp),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Connected in audio mode while local camera was turned ON mid-call (peer cam is OFF)
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF142038), Color(0xFF090E1A)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 70.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(
                avatar: widget.peerAvatar,
                name: _displayTitle,
                radius: 54.r,
                fontSize: 34.sp,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
              ),
              SizedBox(height: 16.h),
              Text(
                _displayTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                l10n.peerCameraOff,
                style: TextStyle(color: Colors.white60, fontSize: 13.5.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggablePiP() {
    final screenSize = MediaQuery.of(context).size;
    final pipW = 112.w;
    final pipH = 160.h;
    final sideMargin = 12.w;
    final topMin = 48.h;
    final bottomReserve = 130.h;

    Widget? pipContent;
    if (_swapPiP && _hasAnyRemoteVideo) {
      final firstRemoteUid = _remoteUids.firstWhere(
        (uid) => _remoteVideoActive[uid] == true && _remoteVideoControllers.containsKey(uid),
      );
      pipContent = AgoraVideoView(controller: _remoteVideoControllers[firstRemoteUid]!);
    } else if (_localVideoEnabled && _localVideoController != null) {
      pipContent = AgoraVideoView(controller: _localVideoController!);
    }

    if (pipContent == null) return const SizedBox.shrink();

    return Positioned(
      right: _pipRight.clamp(sideMargin, screenSize.width - pipW - sideMargin),
      top: _pipTop.clamp(topMin, screenSize.height - pipH - bottomReserve),
      child: GestureDetector(
        onTap: () {
          if (_hasAnyRemoteVideo && _localVideoEnabled) {
            setState(() => _swapPiP = !_swapPiP);
          }
        },
        onPanUpdate: (details) {
          setState(() {
            _pipRight = (_pipRight - details.delta.dx)
                .clamp(sideMargin, screenSize.width - pipW - sideMargin);
            _pipTop = (_pipTop + details.delta.dy)
                .clamp(topMin, screenSize.height - pipH - bottomReserve);
          });
        },
        child: Container(
          width: pipW,
          height: pipH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5.w),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 16.r,
                offset: Offset(0, 6.h),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15.r),
            child: pipContent,
          ),
        ),
      ),
    );
  }

  Widget _buildTopOverlay(Language l10n, String statusText) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8.h,
        left: 16.w,
        right: 16.w,
        bottom: widget.isGroup ? 10.h : 16.h,
      ),
      decoration: (_isVideoUiMode && !widget.isGroup)
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.transparent,
                ],
              ),
            )
          : null,
      child: Row(
        children: [
          if (_isVideoUiMode || widget.isGroup) ...[
            AppAvatar(
              avatar: _displayAvatar,
              name: _displayTitle,
              color: widget.isGroup ? AppColors.blue : null,
              radius: 20.r,
              fontSize: 16.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      if (_isConnected)
                        Container(
                          width: 7.w,
                          height: 7.w,
                          margin: EdgeInsets.only(right: 6.w),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else
            const Spacer(),
          if (_localVideoEnabled)
            _TopCircleIcon(
              icon: _isFrontCamera
                  ? Icons.cameraswitch_rounded
                  : Icons.cameraswitch_outlined,
              onTap: _switchCamera,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(Language l10n) {
    return Container(
      padding: EdgeInsets.only(
        top: widget.isGroup ? 10.h : 18.h,
        bottom: MediaQuery.of(context).padding.bottom + (widget.isGroup ? 16.h : 24.h),
        left: 20.w,
        right: 20.w,
      ),
      decoration: (_isVideoUiMode && !widget.isGroup)
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            )
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(36.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.w,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ControlButton(
              icon: _localVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: _localVideoEnabled ? l10n.cameraOn : l10n.cameraOff,
              isActive: _localVideoEnabled,
              activeColor: Colors.white,
              activeIconColor: const Color(0xFF0F172A),
              onTap: _toggleCamera,
            ),
            _ControlButton(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _isMuted ? l10n.micOff : l10n.micOn,
              isActive: _isMuted,
              activeColor: Colors.white,
              activeIconColor: const Color(0xFF0F172A),
              onTap: _toggleMute,
            ),
            _ControlButton(
              icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
              label: _isSpeakerOn ? l10n.speakerOn : l10n.earpiece,
              isActive: _isSpeakerOn,
              activeColor: Colors.white,
              activeIconColor: const Color(0xFF0F172A),
              onTap: _toggleSpeaker,
            ),
            _ControlButton(
              icon: Icons.call_end_rounded,
              label: l10n.endCallLabel,
              isActive: true,
              activeColor: const Color(0xFFEF4444),
              activeIconColor: Colors.white,
              onTap: _hangUp,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopCircleIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42.w,
        height: 42.w,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 22.sp),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color activeIconColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.activeIconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(
              color: isActive ? activeColor : Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? activeIconColor : Colors.white,
              size: 25.sp,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

