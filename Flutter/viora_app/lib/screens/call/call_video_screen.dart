import 'package:flutter/material.dart';
import 'call_screen.dart';

class CallVideoScreen extends StatelessWidget {
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
  final List<String> targetUserIds;
  final bool isCaller;

  const CallVideoScreen({
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
    this.targetUserIds = const [],
    required this.isCaller,
  });

  @override
  Widget build(BuildContext context) {
    return CallScreen(
      callId: callId,
      callDocId: callDocId,
      channelName: channelName,
      appId: appId,
      token: token,
      peerName: peerName,
      peerAvatar: peerAvatar,
      peerId: peerId,
      conversationId: conversationId,
      isGroup: isGroup,
      groupName: groupName,
      targetUserIds: targetUserIds,
      isCaller: isCaller,
      initialVideo: true,
    );
  }
}

