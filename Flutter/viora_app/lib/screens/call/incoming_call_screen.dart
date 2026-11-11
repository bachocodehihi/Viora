import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../l10n/language.dart';
import '../../services/call_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/app_avatar.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String? callDocId;
  final String channelName;
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final String callType;
  final String? conversationId;
  final bool isGroup;
  final String? groupName;
  final String? groupAvatar;
  final List<Map<String, dynamic>> initialParticipants;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    this.callDocId,
    required this.channelName,
    required this.callerId,
    required this.callerName,
    required this.callerAvatar,
    required this.callType,
    this.conversationId,
    this.isGroup = false,
    this.groupName,
    this.groupAvatar,
    this.initialParticipants = const [],
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _timeoutTimer;
  Timer? _statusPollTimer;
  bool _isPollingStatus = false;
  bool _isProcessing = false;
  bool _isClosed = false;

  late final Function(Map<String, dynamic>) _onCallCancelled;
  late final Function(Map<String, dynamic>) _onCallMissed;
  late final Function(Map<String, dynamic>) _onCallEnded;
  late final Function(Map<String, dynamic>) _onCallDeclined;
  StreamSubscription<String>? _localCancelSub;

  bool get _isVideo => widget.callType == 'video';

  String get _displayTitle {
    if (widget.isGroup && widget.groupName != null && widget.groupName!.trim().isNotEmpty) {
      return widget.groupName!.trim();
    }
    return widget.callerName.isNotEmpty ? widget.callerName : 'Viora';
  }

  String get _displayAvatar {
    if (widget.isGroup) {
      final gAvatar = widget.groupAvatar?.trim() ?? '';
      if (gAvatar.isNotEmpty) return gAvatar;
      return CallService.computeGroupInitials(_displayTitle);
    }
    return widget.callerAvatar;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    CallSoundHelper.startRingtone();
    SocketService.init().then((_) {
      if (!_isClosed && mounted) {
        SocketService.emitCallRinging(
          callId: widget.callId,
          callerId: widget.callerId,
        );
      }
    });
    SocketService.emitCallRinging(
      callId: widget.callId,
      callerId: widget.callerId,
    );

    _onCallCancelled = (data) {
      if (data['callId']?.toString() == widget.callId) {
        _closeScreen();
      }
    };
    _onCallMissed = (data) {
      if (data['callId']?.toString() == widget.callId) {
        _closeScreen();
      }
    };
    _onCallEnded = (data) {
      if (data['callId']?.toString() == widget.callId) {
        _closeScreen();
      }
    };
    _onCallDeclined = (data) {
      if (data['callId']?.toString() == widget.callId) {
        _closeScreen();
      }
    };

    SocketService.onCallCancelled(_onCallCancelled);
    SocketService.onCallMissed(_onCallMissed);
    SocketService.onCallEnded(_onCallEnded);
    SocketService.onCallDeclined(_onCallDeclined);
    _localCancelSub = CallService.cancelledCallStream.listen((cancelledId) {
      if (cancelledId == widget.callId) {
        _closeScreen();
      }
    });

    _statusPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_isClosed || _isProcessing || _isPollingStatus || !mounted) return;
      _isPollingStatus = true;
      try {
        final call = await CallService.fetchCallStatus(
          widget.callId,
          timeout: const Duration(seconds: 2),
        );
        final status = call?['status']?.toString();
        if (status != null && status != 'ringing' && !_isClosed && !_isProcessing && mounted) {
          _closeScreen();
        }
      } finally {
        _isPollingStatus = false;
      }
    });

    _timeoutTimer = Timer(const Duration(seconds: 36), () {
      _closeScreen();
    });
  }

  void _closeScreen() {
    if (_isClosed) return;
    _isClosed = true;
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    CallSoundHelper.stopRingtone();
    CallService.markIncomingScreenClosed(widget.callId);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleDecline() async {
    if (_isProcessing || _isClosed) return;
    setState(() => _isProcessing = true);
    CallSoundHelper.stopRingtone();
    unawaited(
      CallService.declineCall(
        callId: widget.callId,
        callDocId: widget.callDocId,
      ),
    );
    _closeScreen();
  }

  Future<void> _handleAccept() async {
    if (_isProcessing || _isClosed) return;
    setState(() => _isProcessing = true);
    _statusPollTimer?.cancel();
    CallSoundHelper.stopRingtone();

    await CallService.acceptFromIncomingScreen(
      context: context,
      callId: widget.callId,
      callDocId: widget.callDocId,
      channelName: widget.channelName,
      callerId: widget.callerId,
      callerName: widget.callerName,
      callerAvatar: widget.callerAvatar,
      callType: widget.callType,
      conversationId: widget.conversationId,
      isGroup: widget.isGroup,
      groupName: widget.groupName,
      groupAvatar: _displayAvatar,
      initialParticipants: widget.initialParticipants,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _statusPollTimer?.cancel();
    _pulseController.dispose();
    CallSoundHelper.stopRingtone();
    SocketService.offCallCancelled(_onCallCancelled);
    SocketService.offCallMissed(_onCallMissed);
    SocketService.offCallEnded(_onCallEnded);
    SocketService.offCallDeclined(_onCallDeclined);
    _localCancelSub?.cancel();
    CallService.markIncomingScreenClosed(widget.callId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A1120),
                Color(0xFF111C33),
                Color(0xFF090D16),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(height: 36.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.w,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isVideo ? Icons.videocam_rounded : Icons.phone_in_talk_rounded,
                        color: AppColors.blue,
                        size: 16.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _isVideo ? l10n.incomingVideoCall : l10n.incomingVoiceCall,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 210.w,
                  height: 210.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final value = _pulseController.value;
                          return Container(
                            width: 130.w + (75.w * value),
                            height: 130.w + (75.w * value),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.blue.withValues(alpha: (1 - value) * 0.45),
                                width: 2.w,
                              ),
                            ),
                          );
                        },
                      ),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final shifted = (_pulseController.value + 0.5) % 1.0;
                          return Container(
                            width: 130.w + (75.w * shifted),
                            height: 130.w + (75.w * shifted),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.blue.withValues(alpha: (1 - shifted) * 0.12),
                            ),
                          );
                        },
                      ),
                      AppAvatar(
                        avatar: _displayAvatar,
                        name: _displayTitle,
                        color: widget.isGroup ? AppColors.blue : null,
                        radius: 62.r,
                        fontSize: 38.sp,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 3.w,
                        ),
                      ),
                    ],
                  ),
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
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.isGroup &&
                    widget.callerName.isNotEmpty &&
                    widget.callerName != _displayTitle) ...[
                  SizedBox(height: 8.h),
                  Text(
                    widget.callerName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15.sp,
                    ),
                  ),
                ],
                const Spacer(flex: 2),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 42.w, vertical: 36.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ActionButton(
                        icon: Icons.call_end_rounded,
                        label: l10n.declineCall,
                        backgroundColor: const Color(0xFFEF4444),
                        onTap: _isProcessing ? null : _handleDecline,
                      ),
                      _ActionButton(
                        icon: _isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        label: l10n.acceptCall,
                        backgroundColor: const Color(0xFF22C55E),
                        onTap: _isProcessing ? null : _handleAccept,
                        isLoading: _isProcessing,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.45),
                  blurRadius: 20.r,
                  spreadRadius: 2.r,
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 26.w,
                      height: 26.w,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 32.sp),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

