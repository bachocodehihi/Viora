import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/message_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../utils/time_formatter.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';
import 'widgets/chat_call_bubble.dart';

class PinMessageScreen extends StatefulWidget {
  final String? conversationId;
  final List<Map<String, dynamic>> initialPinnedMessages;

  const PinMessageScreen({
    super.key,
    this.conversationId,
    this.initialPinnedMessages = const [],
  });

  @override
  State<PinMessageScreen> createState() => _PinMessageScreenState();
}

class _PinMessageScreenState extends State<PinMessageScreen> {
  Language get l10n => context.l10n;
  late List<Map<String, dynamic>> _pinnedMessages;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _pinnedMessages = List<Map<String, dynamic>>.from(widget.initialPinnedMessages);

    SessionService.getUserId().then((id) {
      if (mounted && id != null) {
        setState(() {
          _currentUserId = id;
        });
      }
    });

    SocketService.onMessagePinned(_onMessagePinned);
    SocketService.onMessageUnpinned(_onMessageUnpinned);
  }

  @override
  void dispose() {
    SocketService.offMessagePinned(_onMessagePinned);
    SocketService.offMessageUnpinned(_onMessageUnpinned);
    super.dispose();
  }

  void _onMessagePinned(Map<String, dynamic> data) {
    if (!mounted) return;
    final targetConvId = data['conversationId']?.toString();
    if (widget.conversationId != null && targetConvId != null && targetConvId != widget.conversationId) return;

    if (data['pinnedMessages'] is List) {
      setState(() {
        _pinnedMessages = List<Map<String, dynamic>>.from(
          (data['pinnedMessages'] as List).whereType<Map<String, dynamic>>(),
        );
      });
    } else if (data['pinnedMessage'] is Map) {
      final newMsg = Map<String, dynamic>.from(data['pinnedMessage'] as Map);
      final newId = (newMsg['id'] ?? newMsg['_id'])?.toString();
      setState(() {
        _pinnedMessages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == newId);
        _pinnedMessages.add(newMsg);
      });
    }
  }

  void _onMessageUnpinned(Map<String, dynamic> data) {
    if (!mounted) return;
    final targetConvId = data['conversationId']?.toString();
    if (widget.conversationId != null && targetConvId != null && targetConvId != widget.conversationId) return;

    if (data['pinnedMessages'] is List) {
      setState(() {
        _pinnedMessages = List<Map<String, dynamic>>.from(
          (data['pinnedMessages'] as List).whereType<Map<String, dynamic>>(),
        );
      });
    } else {
      final removedId = data['messageId']?.toString();
      setState(() {
        if (removedId != null) {
          _pinnedMessages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == removedId);
        } else {
          _pinnedMessages.clear();
        }
      });
    }
  }

  void _popWithCurrentList([String? selectedMsgId]) {
    Navigator.pop(context, {
      'pinnedMessages': _pinnedMessages,
      if (selectedMsgId != null && selectedMsgId.isNotEmpty) 'selectedMessageId': selectedMsgId,
    });
  }

  void _unpinMessage(Map<String, dynamic> msg) async {
    final msgId = (msg['id'] ?? msg['_id'])?.toString();
    if (msgId == null) return;

    setState(() {
      _pinnedMessages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == msgId);
    });

    AppToast.info(context, l10n.messageUnpinned);

    final effectiveConvId = widget.conversationId ?? msg['conversationId']?.toString();
    await MessageService.unPinMessage(
      conversationId: effectiveConvId,
      messageId: msgId,
    );
  }

  void _unpinAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.unpinAll),
        content: Text(l10n.confirmUnpinAll),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: TextStyle(color: context.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.unpinMessage, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _pinnedMessages.clear();
      });

      AppToast.info(context, l10n.messageUnpinned);

      await MessageService.unPinMessage(
        conversationId: widget.conversationId,
      );
    }
  }

  void _selectMessage(Map<String, dynamic> msg) {
    final msgId = (msg['id'] ?? msg['_id'])?.toString();
    _popWithCurrentList(msgId);
  }

  Widget _buildMessageContent(Map<String, dynamic> msg) {
    final type = msg['type']?.toString() ?? 'text';
    final text = msg['text']?.toString() ?? msg['content']?.toString() ?? '';
    final imageUrl = msg['imageUrl']?.toString() ??
        ((msg['attachments'] is List && (msg['attachments'] as List).isNotEmpty)
            ? (msg['attachments'] as List).first.toString()
            : null);

    if (type == 'image' || imageUrl != null) {
      final cleanText = text.trim();
      final bool hasCaption = cleanText.isNotEmpty && !Language.isImagePlaceholder(cleanText);
      final displayText = hasCaption ? cleanText : '[${l10n.imageCaptionOnly}]';

      return Row(
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: Image.network(
                imageUrl,
                width: 44.r,
                height: 44.r,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 44.r,
                  height: 44.r,
                  color: AppColors.gray.withValues(alpha: 0.2),
                  child: Icon(Icons.image_not_supported, size: 20.r, color: context.textMuted),
                ),
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Expanded(
            child: Text(
              displayText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      );
    }

    if (type == 'poll') {
      final question = (msg['poll'] is Map ? msg['poll']['question'] : null) ?? text;
      return Row(
        children: [
          Icon(Icons.poll_rounded, size: 16.r, color: AppColors.blue),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              '[${l10n.poll}] $question',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      );
    }

    if (type == 'location') {
      final loc = msg['location'];
      String address = '';
      if (loc is Map) {
        address = (loc['address'] ?? loc['name'] ?? '').toString();
      }
      return Row(
        children: [
          Icon(Icons.location_on_rounded, size: 16.r, color: Colors.redAccent),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              address.isNotEmpty ? address : (text.isNotEmpty ? text : l10n.stoppedSharingLocation),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      );
    }

    if (type == 'call' || msg['call'] != null) {
      final callMap = msg['call'] is Map ? (msg['call'] as Map) : const {};
      final bool isVideo = callMap['callType']?.toString() == 'video';
      final desc = ChatCallBubble.describeCall(context, msg, isMe: msg['isMe'] == true);
      final summary = ChatCallBubble.formatSummary(context, msg, isMe: msg['isMe'] == true);
      return Row(
        children: [
          Icon(
            desc.isMissedAccent && msg['isMe'] != true
                ? (isVideo ? Icons.missed_video_call_rounded : Icons.phone_missed_rounded)
                : (isVideo ? Icons.videocam_rounded : Icons.phone_rounded),
            size: 16.r,
            color: desc.isMissedAccent && msg['isMe'] != true ? AppColors.red : AppColors.blue,
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      );
    }

    if (type == 'audio') {
      return Row(
        children: [
          Icon(Icons.mic_rounded, size: 16.r, color: AppColors.blue),
          SizedBox(width: 4.w),
          Text(
            l10n.voiceRecordingFeature,
            style: TextStyle(
              fontSize: 13.sp,
              color: context.textPrimary,
            ),
          ),
        ],
      );
    }

    if (type == 'video') {
      return Row(
        children: [
          Icon(Icons.videocam_rounded, size: 16.r, color: Colors.orangeAccent),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              text.isNotEmpty ? text : '[Video]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      );
    }

    if (type == 'file') {
      return Row(
        children: [
          Icon(Icons.insert_drive_file_rounded, size: 16.r, color: AppColors.blue),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              text.isNotEmpty ? text : '[File]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13.5.sp,
        color: context.textPrimary,
        height: 1.3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popWithCurrentList();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _popWithCurrentList,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pinnedMessageTitle,
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
              ),
              if (_pinnedMessages.isNotEmpty)
                Text(
                  '${_pinnedMessages.length} ${l10n.pinned}',
                  style: TextStyle(fontSize: 12.sp, color: context.textMuted),
                ),
            ],
          ),
          actions: [
            if (_pinnedMessages.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 'unpin_all') {
                    _unpinAll();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'unpin_all',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all_rounded, color: Colors.redAccent, size: 20.r),
                        SizedBox(width: 8.w),
                        Text(l10n.unpinAll, style: const TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _pinnedMessages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 76.r,
                      height: 76.r,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.push_pin_outlined,
                        size: 38.r,
                        color: AppColors.blue,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      l10n.noPinnedMessagesYet,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                itemCount: _pinnedMessages.length,
                separatorBuilder: (context, index) => SizedBox(height: 10.h),
                itemBuilder: (context, index) {

                  final msg = _pinnedMessages[_pinnedMessages.length - 1 - index];
                  final senderName = (msg['senderName'] ?? '').toString();
                  final senderAvatar = (msg['senderAvatar'] ?? msg['avatar'] ?? '').toString();
                  final time = TimeFormatter.formatChatTime(
                    context,
                    date: msg['createdAt'],
                    fallbackTime: msg['time']?.toString(),
                  );
                  final senderId = (msg['senderId'] ?? '').toString();
                  final bool isMe = (senderId.isNotEmpty && _currentUserId != null && senderId == _currentUserId) ||
                      (msg['isMe'] == true && (senderId.isEmpty || _currentUserId == null));
                  final displayName = isMe ? l10n.you : (senderName.isNotEmpty ? senderName : widget.conversationId ?? '');

                return Material(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(12.r),
                  elevation: 0.5,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: () => _selectMessage(msg),
                    child: Padding(
                      padding: EdgeInsets.all(12.r),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppAvatar(
                            avatar: senderAvatar,
                            name: displayName,
                            radius: 18.r,
                            fontSize: 12.sp,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5.sp,
                                          color: context.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (time.isNotEmpty) ...[
                                      SizedBox(width: 6.w),
                                      Text(
                                        time,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: context.textMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                _buildMessageContent(msg),
                              ],
                            ),
                          ),
                          SizedBox(width: 6.w),
                          IconButton(
                            icon: Icon(
                              Icons.push_pin_rounded,
                              color: AppColors.blue,
                              size: 20.r,
                            ),
                            onPressed: () => _unpinMessage(msg),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
