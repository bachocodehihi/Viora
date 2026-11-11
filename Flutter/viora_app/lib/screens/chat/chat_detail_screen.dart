import '../../l10n/language.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../post/post_image_viewer_screen.dart';
import '../../services/call_service.dart';
import '../../services/message_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/reaction/fb_reaction_box.dart';
import '../../widgets/toast/app_toast.dart';
import 'chat_info_screen.dart';
import 'share_location_screen.dart';
import '../message/messages_screen.dart';
import '../../services/socket_service.dart';
import '../../services/session_service.dart';
import '../../widgets/bottomsheet/app_create_poll_bottomsheet.dart';
import 'controllers/chat_poll_controller.dart';
import 'widgets/chat_poll_bubble.dart';
import 'widgets/chat_pinned_banner.dart';
import 'widgets/chat_location_bubble.dart';
import 'widgets/chat_image_bubble.dart';
import 'widgets/chat_call_bubble.dart';
import 'widgets/chat_message_context_menu.dart';
import 'widgets/chat_mention_helper.dart';

class ChatDetailScreen extends StatefulWidget {
  final String name;
  final String avatar;
  final Color color;
  final List<Map<String, dynamic>> initialMessages;
  final bool? hasMoreMessages;
  final String? conversationId;
  final String? receiverId;
  final bool? isGroup;
  final bool? isFriend;
  final bool? isOnline;
  final bool? showActiveStatus;
  final bool? isBlocked;
  final String? currentUserId;
  final String? currentUsername;
  final String? currentUserAvatar;

  const ChatDetailScreen({
    super.key,
    required this.name,
    required this.avatar,
    required this.color,
    required this.initialMessages,
    this.hasMoreMessages,
    this.conversationId,
    this.receiverId,
    this.isGroup,
    this.isFriend,
    this.isOnline,
    this.showActiveStatus,
    this.isBlocked,
    this.currentUserId,
    this.currentUsername,
    this.currentUserAvatar,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatMentionTextEditingController _messageController = ChatMentionTextEditingController();
  bool _showMentionList = false;
  String _mentionQuery = '';
  List<Map<String, dynamic>> _mentionSuggestions = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late List<Map<String, dynamic>> _messages;
  final bool _isTyping = false;
  Map<String, dynamic>? _replyingTo;
  List<Map<String, dynamic>> _pinnedMessages = [];
  bool _isPinnedExpanded = false;
  Map<String, dynamic>? _highlightedMessage;
  static const int _messagePageSize = 15;
  final Map<String, GlobalKey> _messageKeys = {};
  final GlobalKey _plusButtonKey = GlobalKey();
  final Set<String> _showTimestampKeys = {};
  bool _hasMoreOlderMessages = false;
  bool _isLoadingOlderMessages = false;
  bool _hasLoadedOlderChunks = false;

  String _messageStableKey(Map<String, dynamic> msg, int index) {
    final id = (msg['id'] ?? msg['_id'])?.toString();
    if (id != null && id.isNotEmpty) return 'id:$id';
    final tempId = msg['tempId']?.toString();
    if (tempId != null && tempId.isNotEmpty) return 'tmp:$tempId';
    final createdAt = msg['createdAt']?.toString() ?? '';
    final text = msg['text']?.toString() ?? '';
    final isMe = msg['isMe'] == true ? '1' : '0';
    if (createdAt.isNotEmpty) return 'loc:${createdAt}_${isMe}_$text';
    return 'idx:$index:$text';
  }
  String? _activeConversationId;
  bool? _serverIsGroup;
  bool _isBlocked = false;
  bool _isBlockedPromptShown = false;
  bool _isStartingCall = false;
  String? _otherUserId;
  String? _otherUserWhoCanMessage;
  bool? _otherUserIsFriend;
  bool? _otherUserOnline;
  bool? _otherUserShowActiveStatus;
  String? _currentUserId;
  String? _currentUsername;
  String? _currentUserAvatar;
  List<Map<String, dynamic>> _groupMembers = [];
  List<Map<String, dynamic>> get groupMembers => _groupMembers;
  late final ChatPollController _pollController;
  Function(Map<String, dynamic>)? _socketNewMessageCb;
  Function(Map<String, dynamic>)? _socketCallMessageUpdatedCb;
  Function(Map<String, dynamic>)? _socketFriendAcceptedCb;
  Function(Map<String, dynamic>)? _socketFriendRemovedCb;
  Function(String)? _socketUserOnlineCb;
  Function(String)? _socketUserOfflineCb;
  Function(Map<String, dynamic>)? _socketActiveStatusChangedCb;
  StreamSubscription<String?>? _callLogSyncSub;

  Language get l10n => context.l10n;

  Map<String, dynamic>? get _latestPinnedMessage =>
      _pinnedMessages.isNotEmpty ? _pinnedMessages.last : null;

  String? get _effectiveConversationId => _activeConversationId ?? widget.conversationId;

  bool get _effectiveIsFriend => _otherUserIsFriend ?? (widget.isFriend == true);

  bool get _effectiveShowActiveStatus =>
      _otherUserShowActiveStatus ?? (widget.showActiveStatus ?? (widget.isOnline == true));

  bool get _canShowActiveStatus =>
      !_isGroup && _effectiveIsFriend && !_isBlocked && _effectiveShowActiveStatus;

  bool get _effectiveIsOnline =>
      _effectiveShowActiveStatus && (_otherUserOnline ?? (widget.isOnline == true));

  List<Map<String, dynamic>> get _displayMessages {
    if (!_isBlocked) return _messages;
    return _messages.where((m) => m['isMe'] == true).toList();
  }

  void _showBlockedUserPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: dlgCtx.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: AppColors.red, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: dlgCtx.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.unblockToChatDesc,
          style: TextStyle(fontSize: 14, color: dlgCtx.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dlgCtx);
              Navigator.pop(context);
            },
            child: Text(
              l10n.skip,
              style: TextStyle(color: dlgCtx.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dlgCtx);
              await _handleUnblockUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              l10n.unblock,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartCall({required bool initialVideo}) async {
    if (_isStartingCall) return;
    _isStartingCall = true;
    try {
      await CallService.startOutgoingCall(
        context: context,
        initialVideo: initialVideo,
        receiverId: _isGroup ? null : (_otherUserId ?? widget.receiverId),
        conversationId: _effectiveConversationId,
        isGroup: _isGroup,
        peerName: widget.name,
        peerAvatar: widget.avatar,
      );
      if (mounted) {
        _loadConversationData();
        MessagesScreen.triggerRefresh();
      }
    } finally {
      _isStartingCall = false;
    }
  }

  Future<void> _handleJoinCall(Map<String, dynamic> callData) async {
    if (_isStartingCall) return;
    final callId = callData['callId']?.toString() ?? '';
    final callDocId = callData['callDocId']?.toString();
    final isVideo = callData['callType']?.toString() == 'video';
    if (callId.isEmpty && (callDocId == null || callDocId.isEmpty)) {
      await _handleStartCall(initialVideo: isVideo);
      return;
    }
    _isStartingCall = true;
    try {
      await CallService.joinActiveCall(
        context: context,
        callId: callId,
        callDocId: callDocId,
        initialVideo: isVideo,
        conversationId: _effectiveConversationId,
        peerName: widget.name,
        peerAvatar: widget.avatar,
      );
      if (mounted) {
        _loadConversationData();
        MessagesScreen.triggerRefresh();
      }
    } finally {
      _isStartingCall = false;
    }
  }

  Future<void> _handleUnblockUser() async {
    String? targetId = _otherUserId ?? widget.receiverId;
    if ((targetId == null || targetId.isEmpty) && _groupMembers.isNotEmpty) {
      final other = _groupMembers.firstWhere(
        (m) => m['id']?.toString() != _currentUserId,
        orElse: () => {},
      );
      targetId = other['id']?.toString();
    }
    if (targetId == null || targetId.isEmpty) return;

    final success = await ProfileService.unblockAccount(targetId);
    if (success && mounted) {
      setState(() {
        _isBlocked = false;
      });
      MessagesScreen.triggerRefresh();
      AppToast.success(context, '${l10n.unblockedSuccess} ${widget.name}');
      _loadConversationData();
    }
  }

  bool _isMessagePinned(Map<String, dynamic> msg) {
    final msgId = (msg['id'] ?? msg['_id'])?.toString();
    if (msgId == null || msgId.isEmpty) return false;
    return _pinnedMessages.any((p) {
      final pId = (p['id'] ?? p['_id'])?.toString();
      return pId == msgId;
    });
  }

  bool get _isGroup {
    if (_serverIsGroup != null) return _serverIsGroup!;
    if (widget.isGroup != null) return widget.isGroup!;
    return widget.receiverId == null && widget.conversationId != null;
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onInputChangedForMentions);
    _scrollController.addListener(_onMessagesScroll);
    _activeConversationId = widget.conversationId;
    _otherUserId = widget.receiverId;
    final rawInitial = List<Map<String, dynamic>>.from(widget.initialMessages);
    _messages = rawInitial.length > _messagePageSize
        ? rawInitial.sublist(rawInitial.length - _messagePageSize)
        : rawInitial;
    _hasMoreOlderMessages = widget.hasMoreMessages ?? (_messages.length >= _messagePageSize);
    _isBlocked = widget.isBlocked ?? false;
    if (_isBlocked) {
      _isBlockedPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isBlocked) {
          _showBlockedUserPrompt();
        }
      });
    }
    _currentUserId = widget.currentUserId;
    _currentUsername = widget.currentUsername;
    _currentUserAvatar = widget.currentUserAvatar;

    _pollController = ChatPollController(
      getMessages: () => _messages,
      getCurrentUserId: () => _currentUserId,
      getCurrentUsername: () => _currentUsername,
      getCurrentUserAvatar: () => _currentUserAvatar,
      getActiveConversationId: () => _activeConversationId ?? widget.conversationId,
      getGroupMembers: () => _groupMembers,
      getDefaultOtherName: () => widget.name,
      getDefaultOtherAvatar: () => widget.avatar,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onScrollToBottom: ({bool animated = false}) => _scrollToBottom(animated: animated),
      onClearMessageKeys: () => _messageKeys.clear(),
    );

    if (_currentUserId == null) {
      SessionService.getUserId().then((uId) {
        if (mounted && uId != null) {
          setState(() {
            _currentUserId = uId;
          });
        }
      });
    }
    if (_currentUsername == null) {
      SessionService.getUsername().then((uName) {
        if (mounted && uName != null) {
          setState(() {
            _currentUsername = uName;
          });
        }
      });
    }
    if (_currentUserAvatar == null) {
      SessionService.getAvatar().then((uAvatar) {
        if (mounted && uAvatar != null) {
          setState(() {
            _currentUserAvatar = uAvatar;
          });
        }
      });
    }
    _initSocket();
    _callLogSyncSub = CallService.callLogSyncStream.listen((convId) {
      if (!mounted) return;
      final activeId = _effectiveConversationId;
      if (convId != null &&
          convId.isNotEmpty &&
          activeId != null &&
          activeId.isNotEmpty &&
          convId != activeId) {
        return;
      }
      _loadConversationData();
    });
    _loadConversationData();
  }

  void _onMessagesScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingOlderMessages || !_hasMoreOlderMessages) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    final double threshold = pos.maxScrollExtent <= 200 ? pos.maxScrollExtent * 0.25 : 140.0;
    if (pos.pixels > 4.0 && pos.pixels >= pos.maxScrollExtent - threshold) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlderMessages || !_hasMoreOlderMessages) return;
    final currentConvId = _activeConversationId ?? widget.conversationId;
    final currentReceiverId = widget.receiverId ?? (!_isGroup ? widget.name : null);
    if ((currentConvId == null || currentConvId.isEmpty) &&
        (currentReceiverId == null || currentReceiverId.isEmpty)) {
      return;
    }
    if (_messages.isEmpty) return;

    Map<String, dynamic>? oldestMsg;
    for (final m in _messages) {
      final id = (m['id'] ?? m['_id'])?.toString();
      final createdAt = m['createdAt']?.toString();
      if ((id != null && id.isNotEmpty && !id.startsWith('temp_')) ||
          (createdAt != null && createdAt.isNotEmpty)) {
        oldestMsg = m;
        break;
      }
    }
    if (oldestMsg == null) return;

    final String? before = oldestMsg['createdAt']?.toString();
    final rawId = (oldestMsg['id'] ?? oldestMsg['_id'])?.toString();
    final String? beforeId =
        (rawId != null && rawId.isNotEmpty && !rawId.startsWith('temp_')) ? rawId : null;

    if (mounted) {
      setState(() {
        _isLoadingOlderMessages = true;
      });
    }

    try {
      final res = await MessageService.loadMessages(
        conversationId: currentConvId,
        receiverId: currentConvId != null ? null : currentReceiverId,
        limit: _messagePageSize,
        before: before,
        beforeId: beforeId,
      );
      if (!mounted) return;
      if (res != null && res['data'] is List) {
        final fetched = List<Map<String, dynamic>>.from(res['data']);
        final existingIds = _messages
            .map((m) => (m['id'] ?? m['_id'])?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
        final Set<String> seenFetchedIds = {};
        final olderToPrepend = fetched.where((m) {
          final mId = (m['id'] ?? m['_id'])?.toString();
          if (mId != null && mId.isNotEmpty) {
            if (existingIds.contains(mId) || !seenFetchedIds.add(mId)) {
              return false;
            }
          }
          return true;
        }).toList();

        setState(() {
          _hasLoadedOlderChunks = true;
          if (olderToPrepend.isNotEmpty) {
            _messages.insertAll(0, olderToPrepend);
          }
          _hasMoreOlderMessages = res['hasMore'] == true;
          _isLoadingOlderMessages = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error loading older messages: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingOlderMessages = false;
      });
    }
  }

  void _initSocket() {
    SocketService.init();

    final currentConvId = _activeConversationId ?? widget.conversationId;
    if (currentConvId != null && currentConvId.isNotEmpty) {
      SocketService.joinConversation(currentConvId);
    }

    _socketNewMessageCb = (newMsgData) async {
      if (!mounted) return;
      if (_isBlocked) return;
      final msgConvId = newMsgData['conversationId']?.toString();
      final activeId = _activeConversationId ?? widget.conversationId;
      final senderId = newMsgData['senderId']?.toString();
      final List<String> participantIds = newMsgData['participantIds'] is List
          ? (newMsgData['participantIds'] as List).map((e) => e.toString()).toList()
          : const [];

      if (activeId == null || activeId.isEmpty) {
        if (_isGroup) return;
        final targetOtherId = _otherUserId ?? widget.receiverId;
        if (targetOtherId == null || targetOtherId.isEmpty) return;
        final bool matchesOther =
            senderId == targetOtherId || participantIds.contains(targetOtherId);
        if (!matchesOther) return;
        if (msgConvId != null && msgConvId.isNotEmpty) {
          _activeConversationId = msgConvId;
          SocketService.joinConversation(msgConvId);
        }
      } else if (msgConvId != null && msgConvId != activeId) {
        return;
      }

      final msgId = (newMsgData['id'] ?? newMsgData['_id'])?.toString();
      final exists = _messages.any((m) => (m['id'] ?? m['_id'])?.toString() == msgId);
      if (exists) return;

      final myUserId = await SessionService.getUserId();
      final bool isMe = (myUserId != null && myUserId.isNotEmpty && senderId == myUserId);

      if (isMe && msgId != null) {
        final optIdx = _messages.indexWhere(
          (m) =>
              (m['id'] == null || m['id'] == '' || m['id'].toString().startsWith('temp_')) &&
              (m['text'] == newMsgData['text'] || m['tempId'] != null),
        );
        if (optIdx != -1) {
          setState(() {
            _messages[optIdx] = {
              ..._messages[optIdx],
              ...newMsgData,
              'id': msgId,
              'isMe': true,
              'isUploading': false,
            };
          });
          return;
        }
      }

      final bool shouldAutoScroll =
          isMe || !_scrollController.hasClients || _scrollController.offset < 200;
      setState(() {
        final incoming = Map<String, dynamic>.from(newMsgData);
        incoming['isMe'] = isMe;
        _messages.add(incoming);
      });
      if (shouldAutoScroll) {
        _scrollToBottom();
      }

      final effectiveConvId = _activeConversationId ?? widget.conversationId ?? msgConvId;
      if (!isMe && effectiveConvId != null && effectiveConvId.isNotEmpty && myUserId != null) {
        SocketService.sendMarkRead(conversationId: effectiveConvId, userId: myUserId);
      }
    };
    SocketService.onNewMessage(_socketNewMessageCb!);

    _socketCallMessageUpdatedCb = (updatedMsgData) async {
      if (!mounted || _isBlocked) return;
      final msgConvId = updatedMsgData['conversationId']?.toString();
      final activeId = _activeConversationId ?? widget.conversationId;
      if (activeId != null && msgConvId != null && msgConvId != activeId) return;

      final msgId = (updatedMsgData['id'] ?? updatedMsgData['_id'])?.toString();
      final updatedCallId = updatedMsgData['call'] is Map
          ? (updatedMsgData['call'] as Map)['callId']?.toString()
          : null;

      final myUserId = _currentUserId ?? await SessionService.getUserId();
      final senderId = updatedMsgData['senderId']?.toString();
      final bool isMe = myUserId != null && myUserId.isNotEmpty && senderId == myUserId;

      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) {
          final mId = (m['id'] ?? m['_id'])?.toString();
          if (msgId != null && msgId.isNotEmpty && mId == msgId) return true;
          if (updatedCallId != null && updatedCallId.isNotEmpty && m['call'] is Map) {
            return (m['call'] as Map)['callId']?.toString() == updatedCallId;
          }
          return false;
        });

        if (idx != -1) {
          _messages[idx] = {
            ..._messages[idx],
            ...updatedMsgData,
            'isMe': isMe,
          };
        } else {
          final incoming = Map<String, dynamic>.from(updatedMsgData);
          incoming['isMe'] = isMe;
          _messages.add(incoming);
        }
      });
    };
    SocketService.onCallMessageUpdated(_socketCallMessageUpdatedCb!);

    SocketService.onMessagesRead((data) async {
      if (!mounted) return;
      final convId = data['conversationId']?.toString();
      final activeId = _activeConversationId ?? widget.conversationId;
      if (activeId != null && convId != null && convId != activeId) return;

      final readerId = data['readerId']?.toString();
      final myUserId = _currentUserId ?? await SessionService.getUserId();

      if (readerId == null || readerId.isEmpty || (myUserId != null && readerId == myUserId)) {
        return;
      }

      final String rawReaderName = data['readerName']?.toString().trim() ?? '';
      final String rawReaderAvatar = data['readerAvatar']?.toString().trim() ?? '';
      final resolvedMember = (rawReaderName.isEmpty || rawReaderAvatar.isEmpty)
          ? _resolveMemberInfo(readerId)
          : null;

      final String readerName = rawReaderName.isNotEmpty
          ? rawReaderName
          : ((resolvedMember?['name'] ?? '').isNotEmpty
              ? resolvedMember!['name']!
              : (_isGroup ? l10n.groupMember : widget.name));
      final String readerAvatar = rawReaderAvatar.isNotEmpty
          ? rawReaderAvatar
          : ((resolvedMember?['avatar'] ?? '').isNotEmpty
              ? resolvedMember!['avatar']!
              : (_isGroup ? '' : widget.avatar));

      setState(() {
        for (int i = _messages.length - 1; i >= 0; i--) {
          final msg = _messages[i];
          if (msg['isMe'] == true && msg['recipientOnlyFriends'] != true) {
            final List seenList = List.from(msg['seenBy'] ?? []);
            final existingIdx = seenList.indexWhere(
              (s) => (s is Map ? s['id']?.toString() : s?.toString()) == readerId,
            );
            if (existingIdx == -1) {
              seenList.add({
                'id': readerId,
                'name': readerName,
                'avatar': readerAvatar,
              });
              msg['seenBy'] = seenList;
            } else if (seenList[existingIdx] is Map) {
              final existing = Map<String, dynamic>.from(seenList[existingIdx] as Map);
              final existingAvatar = existing['avatar']?.toString().trim() ?? '';
              final existingName = existing['name']?.toString().trim() ?? '';
              if ((existingAvatar.isEmpty && readerAvatar.isNotEmpty) ||
                  (existingName.isEmpty && readerName.isNotEmpty)) {
                seenList[existingIdx] = {
                  ...existing,
                  'id': readerId,
                  'name': existingName.isNotEmpty ? existingName : readerName,
                  'avatar': existingAvatar.isNotEmpty ? existingAvatar : readerAvatar,
                };
                msg['seenBy'] = seenList;
              }
            }
          }
        }
      });
    });

    SocketService.onMessageRecalled((data) {
      if (!mounted) return;
      final msgId = data['messageId']?.toString();
      if (msgId == null) return;
      final idx = _messages.indexWhere((m) => m['id']?.toString() == msgId);
      if (idx != -1) {
        setState(() {
          _messages[idx]['isRecalled'] = true;
          _messages[idx]['text'] = l10n.messageHasBeenRecalled;
        });
      }
    });

    SocketService.onMessagePinned(_handleMessagePinned);
    SocketService.onMessageUnpinned(_handleMessageUnpinned);

    SocketService.onMessageReaction((data) {
      if (!mounted) return;
      final msgId = data['messageId']?.toString();
      if (msgId == null) return;
      final idx = _messages.indexWhere((m) => m['id']?.toString() == msgId);
      if (idx != -1) {
        setState(() {
          final senderUserId = data['userId']?.toString();
          final isFromMe = senderUserId != null && _currentUserId != null && senderUserId == _currentUserId;
          if (isFromMe) {
            _messages[idx]['myReaction'] = data['reaction'];
          }
          _messages[idx]['reaction'] = data['displayReaction'] ?? data['reaction'];
          if (data['reactions'] is List) {
            _messages[idx]['reactions'] = data['reactions'];
          }
        });
      }
    });

    SocketService.onLocationStopped((data) {
      if (!mounted) return;
      final msgId = data['messageId']?.toString();
      final convId = data['conversationId']?.toString();
      final activeId = _activeConversationId ?? widget.conversationId;
      if (activeId != null && convId != null && convId != activeId) return;

      setState(() {
        for (var m in _messages) {
          final senderObj = m['sender'];
          final sId = (m['senderId'] ?? (senderObj is Map ? (senderObj['_id'] ?? senderObj['id']) : senderObj))?.toString();
          final stoppedUserId = data['userId']?.toString();
          final isSenderMatch = stoppedUserId != null &&
              (sId == stoppedUserId ||
                  (m['isMe'] == true && _currentUserId != null && stoppedUserId == _currentUserId));

          final mId = (m['id'] ?? m['_id'])?.toString();
          if ((msgId != null && msgId.isNotEmpty && mId == msgId) ||
              (isSenderMatch && m['type'] == 'location')) {
            final loc = Map<String, dynamic>.from(m['location'] ?? {});
            loc['isLive'] = false;
            loc['status'] = 'stopped';
            m['location'] = loc;
            m['text'] = l10n.stoppedSharingLocation;
          }
        }
      });
    });

    SocketService.onLocationUpdated((data) {
      if (!mounted) return;
      final msgId = data['messageId']?.toString();
      final convId = data['conversationId']?.toString();
      final activeId = _activeConversationId ?? widget.conversationId;
      if (activeId != null && convId != null && convId != activeId) return;

      final loc = data['location'];
      if (loc is Map) {
        setState(() {
          for (var m in _messages) {
            if (m['id']?.toString() == msgId) {
              m['location'] = Map<String, dynamic>.from(loc);
              final address = loc['address']?.toString() ?? '';
              final name = loc['name']?.toString() ?? '';
              if (address.isNotEmpty) {
                m['text'] = address;
              } else if (name.isNotEmpty) {
                m['text'] = name;
              }
            }
          }
        });
      }
    });

    SocketService.onPollUpdated(_handlePollUpdated);

    _socketFriendAcceptedCb = (data) {
      if (!mounted || _isGroup) return;
      final uid = data['userId']?.toString();
      if (uid != null && uid.isNotEmpty && uid == _otherUserId) {
        setState(() {
          _otherUserIsFriend = true;
          if (data.containsKey('showActiveStatus')) {
            final bool show = data['showActiveStatus'] == true;
            _otherUserShowActiveStatus = show;
            _otherUserOnline = show && (data['online'] == true);
          }
        });
        _loadConversationData();
      }
    };
    SocketService.onFriendRequestAccepted(_socketFriendAcceptedCb!);

    _socketFriendRemovedCb = (data) {
      if (!mounted || _isGroup) return;
      final uid = data['userId']?.toString();
      if (uid != null && uid.isNotEmpty && uid == _otherUserId) {
        setState(() {
          _otherUserIsFriend = false;
          _otherUserShowActiveStatus = false;
          _otherUserOnline = false;
        });
      }
    };
    SocketService.onFriendRemoved(_socketFriendRemovedCb!);

    _socketUserOnlineCb = (uid) {
      if (!mounted || _isGroup || uid.isEmpty) return;
      final targetId = _otherUserId ?? widget.receiverId;
      if (targetId == null || uid != targetId) return;
      if (_effectiveIsFriend && !_isBlocked && _effectiveShowActiveStatus) {
        setState(() {
          _otherUserOnline = true;
        });
      }
    };
    SocketService.onUserOnline(_socketUserOnlineCb!);

    _socketUserOfflineCb = (uid) {
      if (!mounted || _isGroup || uid.isEmpty) return;
      final targetId = _otherUserId ?? widget.receiverId;
      if (targetId == null || uid != targetId) return;
      setState(() {
        _otherUserOnline = false;
      });
    };
    SocketService.onUserOffline(_socketUserOfflineCb!);

    _socketActiveStatusChangedCb = (data) {
      if (!mounted || _isGroup) return;
      final uid = data['userId']?.toString();
      final targetId = _otherUserId ?? widget.receiverId;
      if (uid == null || targetId == null || uid != targetId) return;
      final bool show = data['showActiveStatus'] != false;
      final bool online = show && (data['isOnline'] == true || data['online'] == true);
      setState(() {
        _otherUserShowActiveStatus = show;
        _otherUserOnline = online;
      });
    };
    SocketService.onUserActiveStatusChanged(_socketActiveStatusChangedCb!);
  }

  void _handlePollUpdated(Map<String, dynamic> data) {
    if (!mounted) return;
    _pollController.handlePollUpdated(data);
  }

  void _toggleMessageReaction(Map<String, dynamic> msg, String targetReaction) {
    final messageId = msg['id']?.toString();
    final String current = msg['myReaction']?.toString() ?? msg['reaction']?.toString() ?? '';
    final String newReaction = (current == targetReaction) ? '' : targetReaction;

    setState(() {
      msg['myReaction'] = newReaction.isEmpty ? null : newReaction;
      msg['reaction'] = newReaction.isEmpty ? null : newReaction;
    });

    if (messageId != null && messageId.isNotEmpty) {
      final convId = _activeConversationId ?? widget.conversationId;
      MessageService.reactMessage(
        messageId: messageId,
        reaction: newReaction,
        conversationId: convId,
      );
      SocketService.emitReactMessage(
        messageId: messageId,
        reaction: newReaction,
        conversationId: convId,
      );
    }
  }

  void _loadConversationData() async {
    final currentConvId = _activeConversationId ?? widget.conversationId;
    final currentReceiverId = widget.receiverId ?? (!_isGroup ? widget.name : null);
    if ((currentConvId == null || currentConvId.isEmpty) &&
        (currentReceiverId == null || currentReceiverId.isEmpty)) {
      return;
    }

    final res = await MessageService.loadMessages(
      conversationId: currentConvId,
      receiverId: currentReceiverId,
      limit: _messagePageSize,
    );
    if (res != null && mounted) {
      bool isContentChanged = false;
      setState(() {
        if (res['conversationId'] != null) {
          _activeConversationId = res['conversationId'].toString();
          SocketService.joinConversation(_activeConversationId!);
        }
        if (res['type'] != null) {
          _serverIsGroup = res['type'] == 'group_chat';
        } else if (res['isGroup'] != null) {
          _serverIsGroup = res['isGroup'] == true;
        }
        if (res['data'] is List) {
          final serverMsgs = List<Map<String, dynamic>>.from(res['data']);
          for (int i = 0; i < serverMsgs.length; i++) {
            final sMsg = serverMsgs[i];
            if (sMsg['type'] == 'poll') {
              final sId = (sMsg['id'] ?? sMsg['_id'])?.toString();
              final localIdx = _messages.indexWhere((m) => (m['id'] ?? m['_id'])?.toString() == sId);
              if (localIdx != -1) {
                final localMsg = _messages[localIdx];
                final localPoll = localMsg['poll'];
                final serverPoll = sMsg['poll'];
                if (localPoll is Map && serverPoll is Map) {
                  final Map? localLastVote = localPoll['lastVote'] is Map ? (localPoll['lastVote'] as Map) : null;
                  final Map? serverLastVote = serverPoll['lastVote'] is Map ? (serverPoll['lastVote'] as Map) : null;
                  final localUpdate = DateTime.tryParse(localLastVote?['updatedAt']?.toString() ?? '') ??
                      DateTime.tryParse(localMsg['createdAt']?.toString() ?? '');
                  final serverUpdate = DateTime.tryParse(serverLastVote?['updatedAt']?.toString() ?? '') ??
                      DateTime.tryParse(sMsg['createdAt']?.toString() ?? '');
                  if (localUpdate != null && serverUpdate != null && localUpdate.isAfter(serverUpdate)) {
                    serverMsgs[i]['poll'] = localPoll;
                  }
                }
              }
            }
          }

          if (_messages.isEmpty) {
            _messages = serverMsgs;
            _messageKeys.clear();
            _hasMoreOlderMessages = res['hasMore'] == true;
            isContentChanged = true;
          } else {
            late final List<Map<String, dynamic>> nextMessages;
            if (_hasLoadedOlderChunks) {
              if (serverMsgs.isEmpty) {
                nextMessages = _messages;
              } else {
                final serverIds = serverMsgs
                    .map((m) => (m['id'] ?? m['_id'])?.toString())
                    .whereType<String>()
                    .where((id) => id.isNotEmpty)
                    .toSet();
                int firstOverlapIdx = -1;
                if (serverIds.isNotEmpty) {
                  firstOverlapIdx = _messages.indexWhere((m) {
                    final id = (m['id'] ?? m['_id'])?.toString();
                    return id != null && id.isNotEmpty && serverIds.contains(id);
                  });
                }
                final firstServerDate = DateTime.tryParse(
                  serverMsgs.first['createdAt']?.toString() ?? '',
                )?.toUtc();
                final preservedOlder = <Map<String, dynamic>>[];
                for (int i = 0; i < _messages.length; i++) {
                  final m = _messages[i];
                  final mId = (m['id'] ?? m['_id'])?.toString();
                  if (mId != null && mId.isNotEmpty && serverIds.contains(mId)) {
                    continue;
                  }
                  if (firstOverlapIdx != -1) {
                    if (i < firstOverlapIdx) {
                      preservedOlder.add(m);
                    }
                  } else if (firstServerDate != null) {
                    final mDate = DateTime.tryParse(m['createdAt']?.toString() ?? '')?.toUtc();
                    if (mDate != null && mDate.isBefore(firstServerDate)) {
                      preservedOlder.add(m);
                    }
                  }
                }
                nextMessages = [...preservedOlder, ...serverMsgs];
              }
            } else {
              _hasMoreOlderMessages = res['hasMore'] == true;
              final serverIds = serverMsgs
                  .map((m) => (m['id'] ?? m['_id'])?.toString())
                  .whereType<String>()
                  .where((id) => id.isNotEmpty)
                  .toSet();
              final pendingUploads = _messages.where((m) {
                if (m['isUploading'] != true) return false;
                final mId = (m['id'] ?? m['_id'])?.toString();
                return mId == null || mId.isEmpty || !serverIds.contains(mId);
              }).toList();
              nextMessages = [...serverMsgs, ...pendingUploads];
            }

            if (_messages.length != nextMessages.length) {
              isContentChanged = true;
            } else {
              for (int i = 0; i < nextMessages.length; i++) {
                final sMsg = nextMessages[i];
                final mMsg = _messages[i];
                final sId = (sMsg['id'] ?? sMsg['_id'])?.toString();
                final mId = (mMsg['id'] ?? mMsg['_id'])?.toString();
                if (sId != mId) {
                  isContentChanged = true;
                  break;
                }
                if (sMsg['type'] == 'poll') {
                  final sPoll = sMsg['poll'];
                  final mPoll = mMsg['poll'];
                  final sVotes = sPoll is Map ? sPoll['totalVotes'] : null;
                  final mVotes = mPoll is Map ? mPoll['totalVotes'] : null;
                  final Map? sLastVote = (sPoll is Map && sPoll['lastVote'] is Map) ? (sPoll['lastVote'] as Map) : null;
                  final Map? mLastVote = (mPoll is Map && mPoll['lastVote'] is Map) ? (mPoll['lastVote'] as Map) : null;
                  final sLastVoteTime = sLastVote?['updatedAt']?.toString();
                  final mLastVoteTime = mLastVote?['updatedAt']?.toString();
                  final sOptionId = sLastVote?['optionId']?.toString();
                  final mOptionId = mLastVote?['optionId']?.toString();
                  if (sVotes != mVotes || sLastVoteTime != mLastVoteTime || sOptionId != mOptionId) {
                    isContentChanged = true;
                    break;
                  }
                }
                if (sMsg['type'] == 'location') {
                  final sLoc = sMsg['location'] is Map ? sMsg['location'] as Map : null;
                  final mLoc = mMsg['location'] is Map ? mMsg['location'] as Map : null;
                  final sLive = sLoc?['isLive'] != false && sLoc?['status'] != 'stopped';
                  final mLive = mLoc?['isLive'] != false && mLoc?['status'] != 'stopped';
                  if (sLive != mLive || sLoc?['status'] != mLoc?['status']) {
                    isContentChanged = true;
                    break;
                  }
                }
                if (sMsg['type'] == 'call' || mMsg['type'] == 'call') {
                  final sCall = sMsg['call'] is Map ? sMsg['call'] as Map : null;
                  final mCall = mMsg['call'] is Map ? mMsg['call'] as Map : null;
                  if (sCall?['status']?.toString() != mCall?['status']?.toString() ||
                      sCall?['duration']?.toString() != mCall?['duration']?.toString() ||
                      sMsg['text']?.toString() != mMsg['text']?.toString()) {
                    isContentChanged = true;
                    break;
                  }
                }
              }
            }
            if (isContentChanged) {
              _messages = nextMessages;
              _messageKeys.clear();
            }
          }
        }
        if (res['pinnedMessages'] is List) {
          _pinnedMessages = List<Map<String, dynamic>>.from(
            (res['pinnedMessages'] as List).whereType<Map<String, dynamic>>(),
          );
        } else if (res['pinnedMessage'] is Map) {
          _pinnedMessages = [Map<String, dynamic>.from(res['pinnedMessage'])];
        }
        if (res['members'] is List) {
          _groupMembers = List<Map<String, dynamic>>.from(
            (res['members'] as List).map((m) => Map<String, dynamic>.from(m)),
          );
        }
        if (res['otherUser'] is Map) {
          final ou = res['otherUser'] as Map;
          final ouId = ou['id']?.toString();
          if (ouId != null && ouId.isNotEmpty) {
            _otherUserId = ouId;
          }
          _otherUserWhoCanMessage = ou['whoCanMessage']?.toString();
          if (ou['isFriend'] != null) {
            _otherUserIsFriend = ou['isFriend'] == true;
          }
          if (ou.containsKey('showActiveStatus') && ou['showActiveStatus'] != null) {
            _otherUserShowActiveStatus = ou['showActiveStatus'] == true;
          }
          if (ou['online'] != null) {
            _otherUserOnline =
                (_otherUserShowActiveStatus ?? true) && (ou['online'] == true);
          }
        }
        if (res['isBlocked'] == true) {
          _isBlocked = true;
          _otherUserId = res['otherUser']?['id']?.toString() ?? widget.receiverId;
          if (!_isBlockedPromptShown) {
            _isBlockedPromptShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _isBlocked) {
                _showBlockedUserPrompt();
              }
            });
          }
        } else {
          _isBlocked = false;
        }
      });
      if (isContentChanged &&
          (!_hasLoadedOlderChunks ||
              !_scrollController.hasClients ||
              _scrollController.offset < 180)) {
        _scrollToBottom(animated: false);
      }

      final myUserId = await SessionService.getUserId();
      _currentUserId = myUserId;
      _currentUsername = await SessionService.getUsername();
      _currentUserAvatar = await SessionService.getAvatar();
      final effectiveConvId = _activeConversationId ?? widget.conversationId;
      if (effectiveConvId != null && myUserId != null && myUserId.isNotEmpty) {
        SocketService.sendMarkRead(conversationId: effectiveConvId, userId: myUserId);
      }
    }
  }

  void _handleMessagePinned(Map<String, dynamic> data) {
    if (!mounted) return;
    final targetConvId = data['conversationId']?.toString().trim();
    final currentConvId = _effectiveConversationId?.trim();
    if (currentConvId != null && targetConvId != null && targetConvId != currentConvId) return;

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

  void _handleMessageUnpinned(Map<String, dynamic> data) {
    if (!mounted) return;
    final targetConvId = data['conversationId']?.toString().trim();
    final currentConvId = _effectiveConversationId?.trim();
    if (currentConvId != null && targetConvId != null && targetConvId != currentConvId) return;

    if (data['pinnedMessages'] is List) {
      setState(() {
        _pinnedMessages = List<Map<String, dynamic>>.from(
          (data['pinnedMessages'] as List).whereType<Map<String, dynamic>>(),
        );
        if (_pinnedMessages.isEmpty) {
          _isPinnedExpanded = false;
        }
      });
    } else {
      final removedId = data['messageId']?.toString();
      setState(() {
        if (removedId != null) {
          _pinnedMessages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == removedId);
        } else {
          _pinnedMessages.clear();
        }
        if (_pinnedMessages.isEmpty) {
          _isPinnedExpanded = false;
        }
      });
    }
  }

  @override
  void dispose() {
    final activeId = _activeConversationId ?? widget.conversationId;
    if (activeId != null && activeId.isNotEmpty) {
      SocketService.leaveConversation(activeId);
    }
    if (_socketNewMessageCb != null) SocketService.offNewMessage(_socketNewMessageCb!);
    if (_socketCallMessageUpdatedCb != null) {
      SocketService.offCallMessageUpdated(_socketCallMessageUpdatedCb!);
    }
    if (_socketFriendAcceptedCb != null) SocketService.offFriendRequestAccepted(_socketFriendAcceptedCb!);
    if (_socketFriendRemovedCb != null) SocketService.offFriendRemoved(_socketFriendRemovedCb!);
    if (_socketUserOnlineCb != null) SocketService.offUserOnline(_socketUserOnlineCb!);
    if (_socketUserOfflineCb != null) SocketService.offUserOffline(_socketUserOfflineCb!);
    if (_socketActiveStatusChangedCb != null) {
      SocketService.offUserActiveStatusChanged(_socketActiveStatusChangedCb!);
    }
    SocketService.offMessageReaction();
    SocketService.offLocationEvents();
    SocketService.offPollUpdated(_handlePollUpdated);
    SocketService.offMessagePinned(_handleMessagePinned);
    SocketService.offMessageUnpinned(_handleMessageUnpinned);
    _callLogSyncSub?.cancel();
    _messageController.removeListener(_onInputChangedForMentions);
    _scrollController.removeListener(_onMessagesScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _triggerReply(Map<String, dynamic> msg, bool isMe) {
    final bool isCallMsg = msg['type'] == 'call' || msg['call'] != null;
    final String replyText = isCallMsg
        ? ChatCallBubble.formatSummary(context, msg, isMe: isMe)
        : (msg['text'] ?? '').toString();
    setState(() {
      _replyingTo = {
        'id': msg['id'],
        'text': replyText,
        'type': msg['type'],
        if (msg['call'] != null) 'call': msg['call'],
        'isMe': isMe,
        'name': isMe ? l10n.yourself : widget.name,
      };
    });
    _focusNode.requestFocus();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      void performScroll() {
        if (!mounted || !_scrollController.hasClients) return;
        const double targetOffset = 0.0;
        if (animated) {
          if (_scrollController.offset.abs() > 2) {
            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        } else {
          if (_scrollController.offset.abs() > 2) {
            _scrollController.jumpTo(targetOffset);
          }
        }
      }

      performScroll();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (_scrollController.offset.abs() > 2) {
          performScroll();
        }
      });
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final replyData = _replyingTo;
    final String? replyToId = replyData?['id']?.toString();
    _messageController.clear();
    if (_showMentionList) {
      setState(() {
        _showMentionList = false;
        _mentionQuery = '';
        _mentionSuggestions = [];
      });
    }
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final timeString = "$hour12:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    final bool isRecipientOnlyFriendsPreCheck = !_isGroup &&
        _otherUserWhoCanMessage == 'friends' &&
        !_effectiveIsFriend;

    late final Map<String, dynamic> newMsg;
    setState(() {
      _replyingTo = null;
      newMsg = <String, dynamic>{
        'text': text,
        'isMe': true,
        'time': timeString,
        'createdAt': now.toIso8601String(),
        'seenBy': [],
        'recipientOnlyFriends': isRecipientOnlyFriendsPreCheck,
      };
      if (replyData != null) {
        newMsg['replyTo'] = replyData;
      }
      _messages.add(newMsg);
    });
    
    _scrollToBottom();

    final currentConvId = _activeConversationId ?? widget.conversationId;
    final effectiveReceiverId = widget.receiverId ?? (!_isGroup ? widget.name : null);

    if (currentConvId != null || effectiveReceiverId != null) {
      final res = await MessageService.sendMessage(
        content: text,
        conversationId: currentConvId,
        receiverId: currentConvId != null ? null : effectiveReceiverId,
        replyToId: replyToId,
      );
      if (res != null && mounted) {
        setState(() {
          final returnedConvId = res['conversationId'] ?? res['data']?['conversationId'];
          if (res['id'] != null) {
            newMsg['id'] = res['id'];
          } else if (res['data']?['id'] != null) {
            newMsg['id'] = res['data']['id'];
          }
          if (res['createdAt'] != null) {
            newMsg['createdAt'] = res['createdAt'];
          } else if (res['data']?['createdAt'] != null) {
            newMsg['createdAt'] = res['data']['createdAt'];
          }
          if (res['time'] != null) {
            newMsg['time'] = res['time'];
          } else if (res['data']?['time'] != null) {
            newMsg['time'] = res['data']['time'];
          }
          final bool isRoF = res['data']?['recipientOnlyFriends'] == true || res['recipientOnlyFriends'] == true;
          if (isRoF) {
            newMsg['recipientOnlyFriends'] = true;
          } else if (res['data'] != null && res['data']['recipientOnlyFriends'] == false) {
            newMsg['recipientOnlyFriends'] = false;
          }
          if (returnedConvId != null) {
            _activeConversationId = returnedConvId.toString();
            SocketService.joinConversation(_activeConversationId!);
          }
        });
        MessagesScreen.triggerRefresh();
      } else if (mounted) {
        setState(() {
          _messages.remove(newMsg);
        });
        final errMsg = MessageService.lastErrorMessage ?? l10n.recipientNotAcceptingStrangerMessages;
        AppToast.error(context, errMsg);
      }
    }
  }

  bool get _isMyLiveLocationActive {
    return _messages.any((m) {
      if (m['isMe'] != true || m['type'] != 'location') return false;
      final loc = m['location'];
      if (loc is Map) {
        return loc['isLive'] != false && loc['status'] != 'stopped';
      }
      return false;
    });
  }

  String? get _myActiveLiveLocationMessageId {
    try {
      final msg = _messages.lastWhere((m) {
        if (m['isMe'] != true || m['type'] != 'location') return false;
        final loc = m['location'];
        if (loc is Map) {
          return loc['isLive'] != false && loc['status'] != 'stopped';
        }
        return false;
      });
      return msg['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openLiveMapScreen({
    String? messageId,
    double? initialLat,
    double? initialLng,
    bool initialIsSharing = false,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    double? otherUserLatitude,
    double? otherUserLongitude,
  }) async {
    final currentConvId = _activeConversationId ?? widget.conversationId;

    final bool amISharing = initialIsSharing || _isMyLiveLocationActive;
    final String? myActiveMsgId = amISharing ? (_myActiveLiveLocationMessageId ?? messageId) : null;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ShareLocationScreen(
          conversationId: currentConvId,
          receiverId: widget.receiverId,
          messageId: myActiveMsgId,
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          initialIsSharing: amISharing,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserAvatar: otherUserAvatar,
          otherUserLatitude: otherUserLatitude ?? (otherUserName != null ? initialLat : null),
          otherUserLongitude: otherUserLongitude ?? (otherUserName != null ? initialLng : null),
        ),
      ),
    );

    if (mounted) {
      _loadConversationData();
    }

    if (result != null && mounted) {
      final msgId = result['messageId']?.toString() ?? myActiveMsgId;
      final isSharing = result['isSharing'] == true;

      setState(() {
        if (!isSharing && amISharing) {
          for (var m in _messages) {
            if (m['isMe'] == true && m['type'] == 'location') {
              final loc = Map<String, dynamic>.from(m['location'] ?? {});
              loc['isLive'] = false;
              loc['status'] = 'stopped';
              m['location'] = loc;
              m['text'] = l10n.stoppedSharingLocation;
            }
          }
        } else if (isSharing && msgId != null) {
          final idx = _messages.indexWhere((m) => m['id']?.toString() == msgId);
          if (idx != -1) {
            final loc = Map<String, dynamic>.from(_messages[idx]['location'] ?? {});
            loc['isLive'] = true;
            loc['status'] = 'active';
            _messages[idx]['location'] = loc;
            _messages[idx]['text'] = l10n.sharingLiveLocation;
          } else if (result['latitude'] != null && result['longitude'] != null) {
            final now = DateTime.now();
            final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
            final timeString = "$hour12:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
            _messages.add({
              'id': msgId,
              'text': l10n.sharingLiveLocation,
              'type': 'location',
              'location': {
                'latitude': result['latitude'],
                'longitude': result['longitude'],
                'name': result['name'] ?? l10n.currentLocation,
                'address': result['address'] ?? '',
                'isLive': true,
                'status': 'active',
              },
              'isMe': true,
              'time': timeString,
              'createdAt': now.toIso8601String(),
            });
            _scrollToBottom();
          }
        }
      });
    }

    _loadConversationData();
  }

  Future<void> _handleOpenCreatePoll() async {
    final result = await AppCreatePollBottomSheet.show(context);
    if (result != null && mounted) {
      _sendPoll(result);
    }
  }

  Future<void> _sendPoll(Map<String, dynamic> pollData) async {
    await _pollController.sendPoll(pollData);
  }

  Future<void> _handleVotePoll(String messageId, String optionId) async {
    await _pollController.votePoll(messageId, optionId);
  }

  Future<void> _openChatInfo() async {
    FocusScope.of(context).unfocus();
    final currentConvId = _activeConversationId ?? widget.conversationId;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatInfoScreen(
          name: widget.name,
          avatar: widget.avatar,
          color: widget.color,
          conversationId: currentConvId,
          receiverId: widget.receiverId,
          messages: _messages,
          pinnedMessage: _latestPinnedMessage,
          pinnedMessages: _pinnedMessages,
          isGroup: _isGroup,
          isOnline: _canShowActiveStatus ? _effectiveIsOnline : null,
        ),
      ),
    );
    if (mounted) {
      _loadConversationData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _messages);
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context, _messages),
          ),
          title: InkWell(
            onTap: _openChatInfo,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  AppAvatar(
                    avatar: widget.avatar,
                    name: widget.name,
                    color: widget.color,
                    radius: 18,
                    fontSize: 14,
                    isOnline: _canShowActiveStatus ? _effectiveIsOnline : null,
                    enableViewer: false,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_canShowActiveStatus)
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _effectiveIsOnline ? AppColors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _effectiveIsOnline ? l10n.online : l10n.offline,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        actions: [
          if ((_isGroup || _effectiveIsFriend) && !_isBlocked) ...[
            IconButton(
              icon: const Icon(Icons.phone_outlined),
              tooltip: l10n.voiceCallTooltip,
              onPressed: () => _handleStartCall(initialVideo: false),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined),
              tooltip: l10n.videoCallTooltip,
              onPressed: () => _handleStartCall(initialVideo: true),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: context.scaffoldBg,
        ),
        child: Column(
          children: [
            if (_pinnedMessages.isNotEmpty)
              ChatPinnedBanner(
                pinnedMessages: _pinnedMessages,
                currentUserId: _currentUserId,
                defaultOtherName: widget.name,
                isExpanded: _isPinnedExpanded,
                onToggleExpanded: () {
                  setState(() {
                    _isPinnedExpanded = !_isPinnedExpanded;
                  });
                },
                onTapMessage: _scrollToMessageById,
                onOpenPinList: _openPinMessageScreen,
                onUnpinMessage: _unpinMessage,
              ),

            Expanded(
              child: Builder(
                builder: (context) {
                  final displayMsgs = _displayMessages;
                  final seenMap = _computeSeenAvatarsMap(displayMsgs);
                  final int itemCount =
                      displayMsgs.length + (_isTyping ? 1 : 0) + (_isLoadingOlderMessages ? 1 : 0);
                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (_isLoadingOlderMessages || !_hasMoreOlderMessages) {
                        return false;
                      }
                      if (notification is OverscrollNotification &&
                          notification.overscroll > 4.0) {
                        _loadOlderMessages();
                      } else if (notification is ScrollUpdateNotification) {
                        final metrics = notification.metrics;
                        if (metrics.maxScrollExtent <= 0 &&
                            (notification.scrollDelta ?? 0) > 0 &&
                            metrics.pixels > 16.0) {
                          _loadOlderMessages();
                        }
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: 24.w,
                        right: 24.w,
                        top: 12.h,
                        bottom: 24.h,
                      ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (_isTyping && index == 0) {
                          return _buildTypingIndicator();
                        }
                        final int adjustedIdx = _isTyping ? index - 1 : index;
                        if (_isLoadingOlderMessages && adjustedIdx >= displayMsgs.length) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Center(
                              child: SizedBox(
                                width: 20.r,
                                height: 20.r,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
                                ),
                              ),
                            ),
                          );
                        }
                        final int msgIndex = displayMsgs.length - 1 - adjustedIdx;
                        final msg = displayMsgs[msgIndex];
                        final String? msgId = (msg['id'] ?? msg['_id'])?.toString();
                        final bool isFirstWithId = msgId != null &&
                            msgId.isNotEmpty &&
                            !msgId.startsWith('temp_') &&
                            displayMsgs.indexWhere((m) => (m['id'] ?? m['_id'])?.toString() == msgId) == msgIndex;
                        final GlobalKey? itemKey = isFirstWithId
                            ? _messageKeys.putIfAbsent(msgId, () => GlobalKey())
                            : null;

                        return _buildMessageItem(
                          key: itemKey,
                          msgs: displayMsgs,
                          msg: msg,
                          index: msgIndex,
                          seenUsers: seenMap[msgIndex] ?? const [],
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            if (_showMentionList && _mentionSuggestions.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: ChatMentionSuggestionsBox(
                  suggestions: _mentionSuggestions,
                  onSelect: _selectMention,
                ),
              ),

            _buildInputBar(),
          ],
        ),
      ),
    ),
  ),
);
}

  Map<String, String>? _resolveMemberInfo(String userId) {
    if (userId.isEmpty) return null;
    for (final m in _groupMembers) {
      final mId = (m['id'] ?? m['_id'])?.toString();
      if (mId == userId) {
        return {
          'name': (m['name'] ?? m['username'] ?? '').toString().trim(),
          'avatar': (m['avatar'] ?? '').toString().trim(),
        };
      }
    }
    for (int i = _messages.length - 1; i >= 0; i--) {
      final msg = _messages[i];
      final rawSender = msg['sender'];
      final sId = (msg['senderId'] ??
              (rawSender is Map ? (rawSender['_id'] ?? rawSender['id']) : rawSender))
          ?.toString();
      if (sId == userId) {
        final sName = (msg['senderName'] ??
                (rawSender is Map ? rawSender['username'] : null) ??
                '')
            .toString()
            .trim();
        final sAvatar = (msg['senderAvatar'] ??
                (rawSender is Map ? rawSender['avatar'] : null) ??
                '')
            .toString()
            .trim();
        if (sName.isNotEmpty || sAvatar.isNotEmpty) {
          return {
            'name': sName,
            'avatar': sAvatar,
          };
        }
      }
    }
    if (!_isGroup && (_otherUserId == userId || widget.receiverId == userId)) {
      return {
        'name': widget.name,
        'avatar': widget.avatar,
      };
    }
    return null;
  }

  Map<int, List<dynamic>> _computeSeenAvatarsMap(List<Map<String, dynamic>> msgs) {
    final Map<int, List<dynamic>> seenMap = {};
    final Set<String> recordedUserIds = {};

    for (int i = msgs.length - 1; i >= 0; i--) {
      final msg = msgs[i];
      if (msg['isMe'] != true || msg['recipientOnlyFriends'] == true) continue;

      final rawSeen = msg['seenBy'] is List ? (msg['seenBy'] as List) : [];
      final rawRead = msg['readBy'] is List ? (msg['readBy'] as List) : [];
      final combined = [...rawSeen, ...rawRead];

      for (var u in combined) {
        String? uId;
        String? uName;
        dynamic uAvatar;
        Color? uColor;

        if (u is Map) {
          uId = u['id']?.toString() ?? u['_id']?.toString();
          uName = u['name']?.toString() ?? u['username']?.toString();
          uAvatar = u['avatar'];
          uColor = u['color'] is Color ? u['color'] as Color : null;
        } else if (u is String) {
          uId = u;
        }

        if (uId == null || uId.isEmpty || (_currentUserId != null && uId == _currentUserId)) {
          continue;
        }

        if (!recordedUserIds.contains(uId)) {
          recordedUserIds.add(uId);
          String resolvedName = (uName ?? '').trim();
          String resolvedAvatar = (uAvatar ?? '').toString().trim();

          if (resolvedName.isEmpty || resolvedAvatar.isEmpty) {
            final member = _resolveMemberInfo(uId);
            if (resolvedName.isEmpty) {
              resolvedName = (member?['name'] ?? '').trim();
            }
            if (resolvedAvatar.isEmpty) {
              resolvedAvatar = (member?['avatar'] ?? '').trim();
            }
          }

          if (_isGroup) {
            if (resolvedName.isEmpty) {
              resolvedName = l10n.groupMember;
            }
          } else {
            if (resolvedName.isEmpty) resolvedName = widget.name;
            if (resolvedAvatar.isEmpty) resolvedAvatar = widget.avatar;
          }

          final userMap = {
            'id': uId,
            'name': resolvedName,
            'avatar': resolvedAvatar,
            'color': uColor ??
                (_isGroup
                    ? AppAvatar.getColorForName(resolvedName)
                    : widget.color),
          };
          seenMap.putIfAbsent(i, () => []).add(userMap);
        }
      }
    }

    return seenMap;
  }

  void _unpinMessage([Map<String, dynamic>? targetMsg]) async {
    final msg = targetMsg ?? _latestPinnedMessage;
    if (msg == null) return;
    final String? pId = (msg['id'] ?? msg['_id'])?.toString();
    if (pId == null) return;

    setState(() {
      _pinnedMessages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == pId);
      if (_pinnedMessages.isEmpty) {
        _isPinnedExpanded = false;
      }
    });
    AppToast.info(context, l10n.messageUnpinned);

    await MessageService.unPinMessage(
      conversationId: _effectiveConversationId,
      messageId: pId,
    );
  }

  Future<void> _scrollToMessageById(String targetId) async {
    if (targetId.isEmpty) return;

    int findIndex(List<Map<String, dynamic>> msgs) {
      return msgs.indexWhere((m) {
        final mId = (m['id'] ?? m['_id'])?.toString();
        return mId != null && mId == targetId;
      });
    }

    int index = findIndex(_displayMessages);
    int safetyCount = 0;
    while (index == -1 && _hasMoreOlderMessages && safetyCount < 10 && mounted) {
      safetyCount++;
      if (_isLoadingOlderMessages) {
        await Future.delayed(const Duration(milliseconds: 120));
      } else {
        await _loadOlderMessages();
      }
      if (!mounted) return;
      index = findIndex(_displayMessages);
    }

    if (index == -1 || !mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final displayMsgs = _displayMessages;
    index = findIndex(displayMsgs);
    if (index == -1) return;

    final targetMsg = displayMsgs[index];
    final key = _messageKeys[targetId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    } else if (_scrollController.hasClients) {
      final total = displayMsgs.length;
      if (total > 1) {
        final double ratioFromBottom = 1.0 - (index / (total - 1));
        final targetOffset = (_scrollController.position.maxScrollExtent * ratioFromBottom)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
        await _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
        if (!mounted) return;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final builtKey = _messageKeys[targetId];
        if (builtKey?.currentContext != null) {
          Scrollable.ensureVisible(
            builtKey!.currentContext!,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: 0.5,
          );
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _highlightedMessage = targetMsg;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _highlightedMessage != null) {
        setState(() {
          _highlightedMessage = null;
        });
      }
    });
  }

  void _openPinMessageScreen() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.pinMessage,
      arguments: {
        'conversationId': _effectiveConversationId,
        'pinnedMessages': _pinnedMessages,
      },
    );

    if (result is Map) {
      if (result['pinnedMessages'] is List) {
        setState(() {
          _pinnedMessages = List<Map<String, dynamic>>.from(
            (result['pinnedMessages'] as List).whereType<Map<String, dynamic>>(),
          );
          if (_pinnedMessages.isEmpty) {
            _isPinnedExpanded = false;
          }
        });
      }
      final selectedId = result['selectedMessageId']?.toString();
      if (selectedId != null && mounted) {
        _scrollToMessageById(selectedId);
      }
    } else if (result is String && mounted) {
      _scrollToMessageById(result);
    }
  }


  double? _parseCoordinate(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }



  Widget _buildBubbleWidget({
    required String text,
    required bool isMe,
    String? type,
    Map<String, dynamic>? location,
    String? reaction,
    Map<String, dynamic>? replyTo,
    VoidCallback? onReactionTap,
    bool isPinned = false,
    bool isHighlighted = false,
    bool isRecalled = false,
    String? messageId,
    Map<String, dynamic>? msg,
  }) {
    final reactionObj = FbReaction.fromId(reaction);
    final rawSender = msg?['sender'];
    final String? bubbleSenderId = msg?['senderId']?.toString() ??
        (rawSender is Map ? rawSender['_id']?.toString() : rawSender?.toString());
    final double? lat = _parseCoordinate(location?['latitude'] ?? location?['lat']);
    final double? lng = _parseCoordinate(location?['longitude'] ?? location?['lng'] ?? location?['lon']);
    final bool isLocation = !isRecalled && type == 'location' && lat != null && lng != null;
    bool isLive = location?['isLive'] != false && location?['status'] != 'stopped';
    if (isLocation && isLive) {
      final senderKey = isMe
          ? '__me__'
          : (msg?['senderId']?.toString() ?? msg?['sender']?.toString() ?? msg?['senderName']?.toString() ?? '');
      final currentMsgId = messageId ?? msg?['id']?.toString();
      final int myIndex = _messages.indexWhere((m) => m['id']?.toString() == currentMsgId);
      if (myIndex != -1) {
        final bool hasNewer = _messages.skip(myIndex + 1).any((m) {
          if (m['type'] != 'location') return false;
          final otherSenderKey = (m['isMe'] == true)
              ? '__me__'
              : (m['senderId']?.toString() ?? m['sender']?.toString() ?? m['senderName']?.toString() ?? '');
          if (otherSenderKey != senderKey) return false;
          final oLoc = m['location'];
          return oLoc is Map && oLoc['isLive'] != false && oLoc['status'] != 'stopped';
        });
        if (hasNewer) {
          isLive = false;
        }
      }
    }
    final String locName = (location?['name'] ?? text).toString();
    final String locAddress = (location?['address'] ?? '').toString();

    final List<String> imageList = [];
    final rawAttachments = msg?['attachments'];
    if (rawAttachments is List) {
      for (var a in rawAttachments) {
        if (a != null && a.toString().trim().isNotEmpty) {
          imageList.add(a.toString().trim());
        }
      }
    }
    if (imageList.isEmpty) {
      final img = msg?['imageUrl'] ?? (type == 'image' && text.startsWith('http') ? text : null);
      if (img != null && img.toString().trim().isNotEmpty) {
        imageList.add(img.toString().trim());
      }
    }
    final bool isImage = !isRecalled && (type == 'image' || imageList.isNotEmpty);
    final bool isPoll = !isRecalled && (type == 'poll' || msg?['poll'] != null);
    final bool isCall = !isRecalled && (type == 'call' || msg?['call'] != null);
    final bool isSpecialBubble = isLocation || isImage || isPoll || isCall;

    final messageBubble = Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          constraints: BoxConstraints(
            maxWidth: isPoll
                ? 280.w
                : (isCall ? 240.w : (isSpecialBubble ? 250.w : 0.72.sw)),
          ),
          padding: isSpecialBubble
              ? EdgeInsets.zero
              : EdgeInsets.only(
                  left: 14.w,
                  right: 14.w,
                  top: 10.h,
                  bottom: reactionObj != null ? 14.h : 10.h,
                ),
          decoration: BoxDecoration(
            color: isPoll ? context.cardBg : (isMe ? AppColors.blue : context.cardBg),
            borderRadius: isPoll
                ? BorderRadius.circular(16.r)
                : BorderRadius.only(
                    topLeft: Radius.circular(18.r),
                    topRight: Radius.circular(18.r),
                    bottomLeft: Radius.circular(isMe ? 18.r : 4.r),
                    bottomRight: Radius.circular(isMe ? 4.r : 18.r),
                  ),
            border: isHighlighted
                ? Border.all(color: Colors.amber, width: 2)
                : (isPoll
                    ? Border.all(color: context.dividerTheme, width: 0.8)
                    : (((isLocation || isCall) && !isMe)
                        ? Border.all(color: context.dividerTheme, width: 0.8)
                        : null)),
            boxShadow: [
              if (isHighlighted)
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: context.chatBubbleShadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
            ],
          ),
          clipBehavior: isSpecialBubble ? Clip.antiAlias : Clip.none,
          child: isPoll
              ? ChatPollBubble(
                  msg: msg ?? {},
                  isMe: isMe,
                  messageId: (messageId ?? msg?['id'] ?? msg?['_id'])?.toString() ?? '',
                  currentUserId: _currentUserId ?? '',
                  onVote: (optId) => _handleVotePoll((messageId ?? msg?['id'] ?? msg?['_id'])?.toString() ?? '', optId),
                  resolveVoters: _pollController.resolveVotersForOption,
                )
              : isLocation
                  ? ChatLocationBubble(
                      isMe: isMe,
                      lat: lat,
                      lng: lng,
                      name: locName,
                      address: locAddress,
                      isPinned: isPinned,
                      isLive: isLive,
                      onTap: () {
                        final otherUserId = _isGroup ? bubbleSenderId : (widget.receiverId ?? bubbleSenderId);
                        final senderName = _isGroup ? (msg?['senderName']?.toString() ?? msg?['name']?.toString()) : widget.name;
                        final senderAvatar = _isGroup ? (msg?['senderAvatar']?.toString() ?? msg?['avatar']?.toString()) : widget.avatar;
                        _openLiveMapScreen(
                          messageId: isMe ? messageId : null,
                          initialLat: lat,
                          initialLng: lng,
                          initialIsSharing: isMe && isLive,
                          otherUserId: isMe ? null : otherUserId,
                          otherUserName: isMe ? null : (senderName ?? widget.name),
                          otherUserAvatar: isMe ? null : (senderAvatar ?? widget.avatar),
                          otherUserLatitude: isMe ? null : lat,
                          otherUserLongitude: isMe ? null : lng,
                        );
                      },
                    )
                  : isImage
                      ? ChatImageBubble(
                          isMe: isMe,
                          images: imageList,
                          caption: text,
                          isPinned: isPinned,
                          isUploading: msg?['isUploading'] == true,
                          onImageTap: (idx) => _openImageViewer(imageList, idx),
                        )
                  : isCall
                      ? ChatCallBubble(
                          msg: msg ?? {},
                          isMe: isMe,
                          isPinned: isPinned,
                          onCallBack: (_isBlocked || (!_isGroup && !_effectiveIsFriend))
                              ? null
                              : (isVideo) => _handleStartCall(initialVideo: isVideo),
                          onJoinCall: (!_isBlocked && _isGroup && msg?['call'] is Map)
                              ? () => _handleJoinCall(
                                    Map<String, dynamic>.from(msg!['call'] as Map),
                                  )
                              : null,
                        )
                                            : Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChatMessageText(
                          text: text,
                          isMe: isMe,
                          isRecalled: isRecalled,
                          memberNames: _availableMentionMembers.map((m) => (m['name'] ?? '').toString()).toList(),
                        ),
                        if (isPinned)
                          Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.push_pin_rounded,
                                  size: 11.r,
                                  color: isMe ? Colors.white70 : AppColors.blue,
                                ),
                                SizedBox(width: 3.w),
                                Text(
                                  l10n.pinned,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: isMe ? Colors.white70 : AppColors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
        ),

        if (reactionObj != null)
          Positioned(
            bottom: -10.h,
            right: isMe ? null : 8.w,
            left: isMe ? 8.w : null,
            child: GestureDetector(
              onTap: onReactionTap,
              child: Container(
                padding: EdgeInsets.all(3.r),
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xFF222030) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.scaffoldBg,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Image.asset(
                  reactionObj.iconPath,
                  width: 16.r,
                  height: 16.r,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
      ],
    );

    if (replyTo == null) {
      return messageBubble;
    }

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: 0.72.sw),
          margin: EdgeInsets.only(bottom: 4.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: context.isDark
                ? const Color(0xFF1E1E2C).withValues(alpha: 0.55)
                : const Color(0xFFE4E6EB).withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                replyTo['name'] ?? '',
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                  color: context.isDark ? Colors.white : context.textPrimary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                (replyTo['type'] == 'call' || replyTo['call'] is Map)
                    ? ChatCallBubble.formatSummary(
                        context,
                        replyTo,
                        isMe: (() {
                          final rawCall = replyTo['call'];
                          final callerId = rawCall is Map
                              ? rawCall['callerId']?.toString()
                              : null;
                          if (_currentUserId != null &&
                              _currentUserId!.isNotEmpty &&
                              callerId != null &&
                              callerId.isNotEmpty) {
                            return callerId == _currentUserId;
                          }
                          return replyTo['isMe'] == true;
                        })(),
                      )
                    : (replyTo['text'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: context.isDark
                      ? Colors.white70
                      : context.textMuted,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        messageBubble,
      ],
    );
  }

  DateTime _getMessageDateTime(Map<String, dynamic> msg) {
    if (msg['createdAt'] != null) {
      if (msg['createdAt'] is DateTime) {
        return msg['createdAt'] as DateTime;
      }
      final parsed = DateTime.tryParse(msg['createdAt'].toString());
      if (parsed != null) {
        return parsed.toLocal();
      }
    }

    final timeStr = msg['time']?.toString() ?? '';
    if (timeStr.isNotEmpty) {
      final directParsed = DateTime.tryParse(timeStr);
      if (directParsed != null) {
        return directParsed.toLocal();
      }
      try {
        final clean = timeStr.trim();
        final match = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM|am|pm|SA|CH|sa|ch))?').firstMatch(clean);
        if (match != null) {
          int hour = int.parse(match.group(1)!);
          final minute = int.parse(match.group(2)!);
          final period = match.group(3)?.toUpperCase();
          if (period == 'PM' || period == 'CH') {
            if (hour < 12) hour += 12;
          } else if (period == 'AM' || period == 'SA') {
            if (hour == 12) hour = 0;
          }
          final now = DateTime.now();
          return DateTime(now.year, now.month, now.day, hour, minute);
        }
      } catch (_) {}
    }

    return DateTime.now();
  }

  bool _shouldShowDateSeparator(int index, List<Map<String, dynamic>> msgs) {
    if (index == 0) return true;
    if (index >= msgs.length) return false;

    final prev = _getMessageDateTime(msgs[index - 1]);
    final curr = _getMessageDateTime(msgs[index]);

    return prev.year != curr.year || prev.month != curr.month || prev.day != curr.day;
  }

  String _formatDateSeparator(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    final l10n = context.l10n;
    final dayNames = [
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
      l10n.sunday,
    ];
    final dayName = dayNames[dt.weekday - 1];

    if (isToday) {
      return l10n.today;
    } else if (isYesterday) {
      return l10n.yesterday;
    } else if (now.difference(dt).inDays < 7 && now.weekday != dt.weekday) {
      return dayName;
    } else if (dt.year == now.year) {
      return "$dayName, ${dt.day}/${dt.month}";
    } else {
      return "$dayName, ${dt.day}/${dt.month}/${dt.year}";
    }
  }

  Widget _buildDateSeparator(DateTime dt, {bool isFirst = false}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: isFirst ? 4.h : 16.h, bottom: 12.h),
        child: Text(
          _formatDateSeparator(dt),
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
            color: context.textMuted,
            letterSpacing: 0.15,
          ),
        ),
      ),
    );
  }

  String _formatMessageTimestamp(Map<String, dynamic> msg, bool isMe) {
    final dt = _getMessageDateTime(msg);
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    final hourStr = dt.hour.toString().padLeft(2, '0');
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final timeStr = "$hourStr:$minuteStr";

    final l10n = context.l10n;
    String timeLabel;
    if (isToday) {
      timeLabel = timeStr;
    } else if (isYesterday) {
      timeLabel = "${l10n.yesterday} $timeStr";
    } else if (now.difference(dt).inDays < 7 && now.weekday != dt.weekday) {
      final dayNames = [l10n.monShort, l10n.tueShort, l10n.wedShort, l10n.thuShort, l10n.friShort, l10n.satShort, l10n.sunShort];
      timeLabel = "${dayNames[dt.weekday - 1]} $timeStr";
    } else if (dt.year == now.year) {
      timeLabel = "${dt.day}/${dt.month} $timeStr";
    } else {
      timeLabel = "${dt.day}/${dt.month}/${dt.year} $timeStr";
    }

    return timeLabel;
  }

  Widget _buildMessageItem({
    required List<Map<String, dynamic>> msgs,
    required Map<String, dynamic> msg,
    required int index,
    required List<dynamic> seenUsers,
    Key? key,
  }) {
    final bool isMe = msg['isMe'] == true;
    final String text = msg['text'] ?? '';
    final String? reaction = msg['reaction']?.toString();
    final Map<String, dynamic>? replyTo = msg['replyTo'] is Map ? Map<String, dynamic>.from(msg['replyTo']) : null;
    final bool isPinned = _isMessagePinned(msg);
    final bool isHighlighted = _highlightedMessage == msg;
    final bool isRecalled = msg['isRecalled'] == true;
    final String msgKey = _messageStableKey(msg, index);
    final bool isShowTime = _showTimestampKeys.contains(msgKey);
    final bool showDateSeparator = _shouldShowDateSeparator(index, msgs);
    final DateTime messageDt = _getMessageDateTime(msg);

    final bool isPoll = msg['type'] == 'poll' || msg['poll'] != null;
    final bool isSystem = msg['type'] == 'system';

    final Widget messageWidget;

    if (isSystem) {
      return const SizedBox.shrink();
    } else if (isPoll) {
      final senderName = (msg['senderName'] ?? msg['name'] ?? '').toString();
      final creatorName = isMe ? l10n.you : (senderName.isNotEmpty ? senderName : widget.name);
      final pollData = msg['poll'] is Map ? (msg['poll'] as Map) : null;
      final lastVote = pollData?['lastVote'] is Map ? (pollData!['lastVote'] as Map) : null;
      String pollHeaderText = '$creatorName ${l10n.createdAPoll}';
      if (lastVote != null) {
        final vId = lastVote['voterId']?.toString() ?? '';
        final vName = lastVote['voterName']?.toString() ?? '';
        final vAction = lastVote['action']?.toString() ?? 'voted';
        final isVoterMe = vId.isNotEmpty && vId == _currentUserId;
        final targetName = isVoterMe ? l10n.you : (vName.isNotEmpty ? vName : widget.name);
        if (vAction == 'changed') {
          pollHeaderText = isVoterMe ? l10n.youChangedVotePoll : '$targetName ${l10n.changedVoteInPoll}';
        } else if (vAction == 'unvoted') {
          pollHeaderText = isVoterMe ? l10n.youUnvotedPoll : '$targetName ${l10n.unvotedPoll}';
        } else {
          pollHeaderText = isVoterMe ? l10n.youVotedPoll : '$targetName ${l10n.votedInPoll}';
        }
      }

      messageWidget = Center(
        key: showDateSeparator ? null : key,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.how_to_vote_rounded, size: 14.r, color: AppColors.blue),
                    SizedBox(width: 5.w),
                    Text(
                      pollHeaderText,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: context.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (bubbleContext) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_showTimestampKeys.contains(msgKey)) {
                          _showTimestampKeys.remove(msgKey);
                        } else {
                          _showTimestampKeys.add(msgKey);
                        }
                      });
                    },
                    onLongPressStart: (details) {
                      final renderBox = bubbleContext.findRenderObject() as RenderBox?;
                      _showMessageContextMenu(
                        context: context,
                        msg: msg,
                        index: index,
                        tapPosition: details.globalPosition,
                        renderBox: renderBox,
                      );
                    },
                    child: _buildBubbleWidget(
                      text: text,
                      isMe: false,
                      type: 'poll',
                      location: null,
                      reaction: null,
                      replyTo: null,
                      isPinned: isPinned,
                      isHighlighted: isHighlighted,
                      isRecalled: false,
                      messageId: (msg['id'] ?? msg['_id'])?.toString(),
                      msg: msg,
                    ),
                  );
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: isShowTime
                    ? Padding(
                        padding: EdgeInsets.only(top: 4.h, bottom: 2.h),
                        child: Text(
                          _formatMessageTimestamp(msg, false),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: context.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    } else if (!isMe) {
      final bool isLastOfOtherCluster =
          index == msgs.length - 1 || msgs[index + 1]['isMe'] == true;

      messageWidget = Align(
        key: showDateSeparator ? null : key,
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: reaction != null ? 18.h : 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyTo != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 3.h, left: 36.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.reply_rounded, size: 13.r, color: context.textMuted),
                      SizedBox(width: 4.w),
                      Text(
                        '${widget.name} ${l10n.repliedTo} ${replyTo['isMe'] == true ? l10n.youLower : (replyTo['name'] ?? '')}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: context.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isLastOfOtherCluster)
                    Padding(
                      padding: EdgeInsets.only(bottom: 2.h),
                      child: AppAvatar(
                        avatar: _isGroup
                            ? (msg['senderAvatar'] ?? msg['avatar'] ?? ((msg['senderName'] ?? '').toString().isNotEmpty ? (msg['senderName'] as String)[0].toUpperCase() : 'U'))
                            : widget.avatar,
                        name: _isGroup ? (msg['senderName'] ?? msg['name'] ?? l10n.groupMember) : widget.name,
                        color: widget.color,
                        radius: 14.r,
                        fontSize: 11.sp,
                        enableViewer: false,
                        onTap: _openChatInfo,
                      ),
                    )
                  else
                    SizedBox(width: 28.w),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isGroup && (msg['senderName'] != null && msg['senderName'].toString().isNotEmpty))
                          Padding(
                            padding: EdgeInsets.only(bottom: 3.h, left: 4.w),
                            child: Text(
                              msg['senderName'].toString(),
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.blue,
                              ),
                            ),
                          ),
                        Builder(
                          builder: (bubbleContext) {
                            return _SwipeToReplyWrapper(
                              isMe: false,
                              onReply: () => _triggerReply(msg, false),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    if (_showTimestampKeys.contains(msgKey)) {
                                      _showTimestampKeys.remove(msgKey);
                                    } else {
                                      _showTimestampKeys.add(msgKey);
                                    }
                                  });
                                },
                                onLongPressStart: (details) {
                                  final renderBox = bubbleContext.findRenderObject() as RenderBox?;
                                  _showMessageContextMenu(
                                    context: context,
                                    msg: msg,
                                    index: index,
                                    tapPosition: details.globalPosition,
                                    renderBox: renderBox,
                                  );
                                },
                                child: _buildBubbleWidget(
                                  text: text,
                                  isMe: isMe,
                                  type: msg['type']?.toString(),
                                  location: msg['location'] is Map ? Map<String, dynamic>.from(msg['location']) : null,
                                  reaction: reaction,
                                  replyTo: replyTo,
                                  isPinned: isPinned,
                                  isHighlighted: isHighlighted,
                                  isRecalled: isRecalled,
                                  messageId: (msg['id'] ?? msg['_id'])?.toString(),
                                  msg: msg,
                                  onReactionTap: () {
                                    _toggleMessageReaction(msg, '');
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: isShowTime
                              ? Padding(
                                  padding: EdgeInsets.only(top: 4.h, left: 4.w, bottom: 2.h),
                                  child: Text(
                                    _formatMessageTimestamp(msg, false),
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: context.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      messageWidget = Align(
        key: showDateSeparator ? null : key,
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: seenUsers.isNotEmpty
                ? (reaction != null ? 8.h : 4.h)
                : (reaction != null ? 18.h : 10.h),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyTo != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 3.h, right: 6.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.reply_rounded, size: 13.r, color: context.textMuted),
                      SizedBox(width: 4.w),
                      Text(
                        '${l10n.you} ${l10n.repliedTo} ${replyTo['name'] == l10n.yourself ? l10n.yourselfLower : (replyTo['name'] ?? '')}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: context.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              Builder(
                builder: (bubbleContext) {
                  return _SwipeToReplyWrapper(
                    isMe: true,
                    onReply: () => _triggerReply(msg, true),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (_showTimestampKeys.contains(msgKey)) {
                            _showTimestampKeys.remove(msgKey);
                          } else {
                            _showTimestampKeys.add(msgKey);
                          }
                        });
                      },
                      onLongPressStart: (details) {
                        final renderBox = bubbleContext.findRenderObject() as RenderBox?;
                        _showMessageContextMenu(
                          context: context,
                          msg: msg,
                          index: index,
                          tapPosition: details.globalPosition,
                          renderBox: renderBox,
                        );
                      },
                      child: _buildBubbleWidget(
                        text: text,
                        isMe: isMe,
                        type: msg['type']?.toString(),
                        location: msg['location'] is Map ? Map<String, dynamic>.from(msg['location']) : null,
                        reaction: reaction,
                        replyTo: replyTo,
                        isPinned: isPinned,
                        isHighlighted: isHighlighted,
                        isRecalled: isRecalled,
                        messageId: (msg['id'] ?? msg['_id'])?.toString(),
                        msg: msg,
                        onReactionTap: () {
                          _toggleMessageReaction(msg, '');
                        },
                      ),
                    ),
                  );
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: isShowTime
                    ? Padding(
                        padding: EdgeInsets.only(top: 4.h, right: 4.w, bottom: 2.h),
                        child: Text(
                          _formatMessageTimestamp(msg, true),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: context.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: (seenUsers.isNotEmpty && msg['recipientOnlyFriends'] != true)
                    ? _buildSeenAvatars(
                        seenUsers,
                        hasReaction: reaction != null,
                        messageIndex: index,
                        messageStableId: msgKey,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    Widget finalWidget = messageWidget;

    if (msg['recipientOnlyFriends'] == true && isMe) {
      finalWidget = Column(
        key: showDateSeparator ? null : key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          messageWidget,
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 16.w),
              child: Text(
                l10n.recipientOnlyReceivesFromFriends,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!showDateSeparator) {
      return finalWidget;
    }

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDateSeparator(messageDt, isFirst: index == 0),
        finalWidget,
      ],
    );
  }

  Widget _buildSeenAvatars(
    List<dynamic> viewers, {
    bool hasReaction = false,
    int? messageIndex,
    String? messageStableId,
  }) {
    if (viewers.isEmpty) return const SizedBox.shrink();

    final displayList = viewers.take(6).toList();
    final remaining = viewers.length - displayList.length;

    return Padding(
      padding: EdgeInsets.only(
        top: hasReaction ? 10.h : 4.h,
        bottom: 6.h,
        right: 2.w,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ...displayList.asMap().entries.map((entry) {
            final int avatarIdx = entry.key;
            final viewer = entry.value;
            dynamic avatar;
            String? name;
            String? viewerId;
            Color? color;

            if (viewer is Map) {
              viewerId = viewer['id']?.toString() ?? viewer['_id']?.toString();
              avatar = viewer['avatar'];
              name = viewer['name']?.toString();
              color = viewer['color'] is Color ? viewer['color'] as Color : null;
            } else if (viewer is String) {
              avatar = viewer;
            }

            final displayName = (name != null && name.trim().isNotEmpty)
                ? name.trim()
                : (_isGroup ? l10n.groupMember : widget.name);
            final userInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
            final userAvatar = (avatar != null && avatar.toString().isNotEmpty) ? avatar : userInitial;
            final uniqueKeyStr = 'seen_${viewerId ?? displayName}_${messageStableId ?? messageIndex ?? 0}_$avatarIdx';

            return TweenAnimationBuilder<double>(
              key: ValueKey(uniqueKeyStr),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, val, child) {
                return Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -12.h * (1.0 - val)),
                    child: Transform.scale(
                      scale: 0.5 + 0.5 * val,
                      child: child,
                    ),
                  ),
                );
              },
              child: GestureDetector(
                onTap: () {
                  AppToast.info(context, '${l10n.seenBy} $displayName');
                },
                child: Container(
                  margin: const EdgeInsets.only(left: 3.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.scaffoldBg,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: AppAvatar(
                      avatar: userAvatar,
                      name: displayName,
                      color: color ?? AppAvatar.getColorForName(displayName),
                      radius: 8.0,
                      fontSize: 8.0,
                    ),
                  ),
                ),
              ),
            );
          }),
          if (remaining > 0)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, val, child) {
                return Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -10.h * (1.0 - val)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 3.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.borderTheme,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '+$remaining',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: AppAvatar(
                avatar: widget.avatar,
                name: widget.name,
                color: widget.color,
                radius: 14,
                fontSize: 11,
                enableViewer: false,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${widget.name} ${l10n.isTyping}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(width: 6),
                  const SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBanner() {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E1E2C) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${l10n.replyingTo} ${_replyingTo!['name'] ?? ''}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _replyingTo!['text'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyingTo = null),
            child: Container(
              padding: EdgeInsets.all(4.r),
              decoration: BoxDecoration(
                color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, size: 16.r, color: context.textMuted),
            ),
          ),
        ],
      ),
    );
  }


  void _openImageViewer(List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostImageViewerScreen(
          images: images,
          initialIndex: initialIndex,
          authorName: widget.name,
          authorAvatar: widget.avatar,
        ),
      ),
    );
  }

  Future<void> _handlePickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      List<XFile> picked = [];

      try {
        picked = await picker.pickMultiImage();
      } catch (_) {}

      if (picked.isEmpty) {
        final XFile? single = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (single != null) {
          picked = [single];
        }
      }

      if (picked.isEmpty) return;

      final List<File> files = picked.map((x) => File(x.path)).toList();
      final List<String> localPaths = files.map((f) => f.path).toList();

      final String caption = _messageController.text.trim();
      _messageController.clear();

      final now = DateTime.now();
      final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
      final timeString = "$hour12:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      final Map<String, dynamic> optimisticMsg = {
        'id': tempId,
        'tempId': tempId,
        'text': caption,
        'type': 'image',
        'isMe': true,
        'time': timeString,
        'createdAt': now.toIso8601String(),
        'attachments': localPaths,
        'imageUrl': localPaths.first,
        'isUploading': true,
        'replyTo': _replyingTo,
        'recipientOnlyFriends': !_isGroup &&
            _otherUserWhoCanMessage == 'friends' &&
            !_effectiveIsFriend,
      };

      final replyId = _replyingTo?['id']?.toString();

      setState(() {
        _messages.add(optimisticMsg);
        _replyingTo = null;
      });
      _scrollToBottom();

      final res = await MessageService.sendMessage(
        content: caption,
        conversationId: _activeConversationId ?? widget.conversationId,
        receiverId: (_activeConversationId != null || widget.conversationId != null) ? null : widget.receiverId,
        replyToId: replyId,
        type: 'image',
        imageFiles: files,
      );

      if (res != null) {
        if (res['conversationId'] != null) {
          _activeConversationId = res['conversationId'].toString();
        }
        setState(() {
          final idx = _messages.indexWhere((m) => m['tempId'] == tempId || m['id'] == tempId);
          if (idx != -1) {
            final bool isRoF = res['data']?['recipientOnlyFriends'] == true || res['recipientOnlyFriends'] == true;
            _messages[idx] = {
              ..._messages[idx],
              ...res,
              'isMe': true,
              'isUploading': false,
              if (isRoF) 'recipientOnlyFriends': true,
            };
          }
        });
        MessagesScreen.triggerRefresh();
      } else {
        if (!mounted) return;
        final errMsg = MessageService.lastErrorMessage ?? l10n.cannotSendImage;
        AppToast.error(context, errMsg);
        setState(() {
          _messages.removeWhere((m) => m['tempId'] == tempId || m['id'] == tempId);
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, l10n.cannotOpenGallery);
    }
  }

  Future<void> _handleTakePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null) return;

      final List<File> files = [File(photo.path)];
      final List<String> localPaths = [photo.path];

      final String caption = _messageController.text.trim();
      _messageController.clear();

      final now = DateTime.now();
      final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
      final timeString = "$hour12:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      final Map<String, dynamic> optimisticMsg = {
        'id': tempId,
        'tempId': tempId,
        'text': caption,
        'type': 'image',
        'isMe': true,
        'time': timeString,
        'createdAt': now.toIso8601String(),
        'attachments': localPaths,
        'imageUrl': localPaths.first,
        'isUploading': true,
        'replyTo': _replyingTo,
        'recipientOnlyFriends': !_isGroup &&
            _otherUserWhoCanMessage == 'friends' &&
            !_effectiveIsFriend,
      };

      final replyId = _replyingTo?['id']?.toString();

      setState(() {
        _messages.add(optimisticMsg);
        _replyingTo = null;
      });
      _scrollToBottom();

      final res = await MessageService.sendMessage(
        content: caption,
        conversationId: _activeConversationId ?? widget.conversationId,
        receiverId: (_activeConversationId != null || widget.conversationId != null) ? null : widget.receiverId,
        replyToId: replyId,
        type: 'image',
        imageFiles: files,
      );

      if (res != null) {
        if (res['conversationId'] != null) {
          _activeConversationId = res['conversationId'].toString();
        }
        setState(() {
          final idx = _messages.indexWhere((m) => m['tempId'] == tempId || m['id'] == tempId);
          if (idx != -1) {
            final bool isRoF = res['data']?['recipientOnlyFriends'] == true || res['recipientOnlyFriends'] == true;
            _messages[idx] = {
              ..._messages[idx],
              ...res,
              'isMe': true,
              'isUploading': false,
              if (isRoF) 'recipientOnlyFriends': true,
            };
          }
        });
        MessagesScreen.triggerRefresh();
      } else {
        if (!mounted) return;
        final errMsg = MessageService.lastErrorMessage ?? l10n.cannotSendImage;
        AppToast.error(context, errMsg);
        setState(() {
          _messages.removeWhere((m) => m['tempId'] == tempId || m['id'] == tempId);
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, l10n.cannotOpenCamera);
    }
  }

  void _handleVoiceRecord() {
    AppToast.info(context, l10n.voiceRecordingFeature);
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final Color itemColor = isDestructive ? AppColors.red : context.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 40.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Icon(icon, size: 20.r, color: itemColor),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
                      color: itemColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMoreOptions() {
    final RenderBox? renderBox = _plusButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset buttonOffset = renderBox?.localToGlobal(Offset.zero) ?? Offset(12.w, MediaQuery.of(context).size.height - 70.h);
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    final double menuWidth = 165.w;
    final double menuLeft = buttonOffset.dx.clamp(12.w, screenWidth - menuWidth - 12.w);
    final double menuBottom = screenHeight - buttonOffset.dy + 8.h;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissAttachmentMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: menuLeft,
              bottom: menuBottom,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF1E1E2C) : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: context.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMenuItem(
                          icon: Icons.camera_alt_outlined,
                          title: l10n.takePhoto,
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            _handleTakePhoto();
                          },
                        ),
                        Divider(height: 1, color: context.dividerTheme),
                        _buildMenuItem(
                          icon: Icons.insert_drive_file_outlined,
                          title: l10n.file,
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            AppToast.info(context, l10n.fileSendFeature);
                          },
                        ),
                        Divider(height: 1, color: context.dividerTheme),
                        _buildMenuItem(
                          icon: Icons.location_on_outlined,
                          title: l10n.location,
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            _openLiveMapScreen();
                          },
                        ),
                        if (_isGroup) ...[
                          Divider(height: 1, color: context.dividerTheme),
                          _buildMenuItem(
                            icon: Icons.poll_outlined,
                            title: l10n.createPoll,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              _handleOpenCreatePoll();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (dialogCtx, anim, secAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            alignment: Alignment.bottomLeft,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildInputActionButton({
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 20,
    Key? key,
  }) {
    return ClipOval(
      key: key,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: context.chatAttachBtnBg,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38.r,
            height: 38.r,
            child: Center(
              child: Icon(icon, color: AppColors.blue, size: iconSize.r),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _availableMentionMembers {
    final Map<String, Map<String, dynamic>> memberMap = {};

    for (final m in _groupMembers) {
      final id = (m['id'] ?? m['_id'])?.toString() ?? '';
      final name = (m['name'] ?? m['username'] ?? m['fullName'] ?? '').toString().trim();
      final avatar = (m['avatar'] ?? '').toString();
      if (name.isNotEmpty) {
        final isMe = (_currentUserId != null && id.isNotEmpty && id == _currentUserId) ||
            (_currentUsername != null && name == _currentUsername);
        if (!isMe) {
          memberMap[id.isNotEmpty ? id : name] = {
            'id': id,
            'name': name,
            'avatar': avatar,
          };
        }
      }
    }

    for (final msg in _messages) {
      final sId = (msg['senderId'] ?? msg['userId'] ?? msg['id'])?.toString() ?? '';
      final sName = (msg['senderName'] ?? msg['name'] ?? msg['username'] ?? '').toString().trim();
      final sAvatar = (msg['senderAvatar'] ?? msg['avatar'] ?? '').toString();
      if (sName.isNotEmpty) {
        final isMe = (_currentUserId != null && sId.isNotEmpty && sId == _currentUserId) ||
            (_currentUsername != null && sName == _currentUsername);
        if (!isMe && !memberMap.containsKey(sId) && !memberMap.containsKey(sName)) {
          memberMap[sId.isNotEmpty ? sId : sName] = {
            'id': sId,
            'name': sName,
            'avatar': sAvatar,
          };
        }
      }
    }

    if (!_isGroup) {
      final otherName = widget.name.trim();
      final otherId = widget.receiverId ?? '';
      if (otherName.isNotEmpty && !memberMap.containsKey(otherName) && !memberMap.containsKey(otherId)) {
        memberMap[otherId.isNotEmpty ? otherId : otherName] = {
          'id': otherId,
          'name': otherName,
          'avatar': widget.avatar,
        };
      }
    }

    return memberMap.values.toList();
  }

  void _onInputChangedForMentions() {
    _messageController.memberNames = _availableMentionMembers
        .map((m) => (m['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();

    final text = _messageController.text;
    final sel = _messageController.selection;
    if (sel.baseOffset > 0 && sel.baseOffset <= text.length) {
      final textBeforeCursor = text.substring(0, sel.baseOffset);
      final match = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(textBeforeCursor);
      if (match != null) {
        final query = match.group(1) ?? '';
        _updateMentionSuggestions(query);
        return;
      }
    }
    if (_showMentionList) {
      setState(() {
        _showMentionList = false;
        _mentionQuery = '';
        _mentionSuggestions = [];
      });
    }
  }

  void _updateMentionSuggestions(String query) {
    final isEn = LanguageManager.isEnglish();
    final allTag = isEn ? '@All' : '@Mọi người';
    final allSubtitle = isEn
        ? 'Mention all members in group'
        : 'Nhắc đến tất cả thành viên trong nhóm';

    final List<Map<String, dynamic>> results = [];
    final cleanQuery = query.trim().toLowerCase();
    final cleanQueryNoDiacritics = removeDiacritics(cleanQuery);

    if (_isGroup) {
      final bool matchAll = cleanQuery.isEmpty ||
          'all'.contains(cleanQuery) ||
          'mọi người'.contains(cleanQuery) ||
          'moi nguoi'.contains(cleanQueryNoDiacritics) ||
          'everyone'.contains(cleanQuery);

      if (matchAll) {
        results.add({
          'id': 'all',
          'name': allTag,
          'tag': allTag,
          'subtitle': allSubtitle,
          'isAll': true,
        });
      }
    }

    final members = _availableMentionMembers;
    for (final m in members) {
      final name = (m['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final nameLower = name.toLowerCase();
      final nameNoDiacritics = removeDiacritics(nameLower);

      final matches = cleanQuery.isEmpty ||
          nameLower.contains(cleanQuery) ||
          nameNoDiacritics.contains(cleanQueryNoDiacritics);

      if (matches) {
        results.add({
          'id': m['id']?.toString() ?? '',
          'name': name,
          'tag': '@$name',
          'avatar': m['avatar']?.toString(),
          'subtitle': null,
          'isAll': false,
        });
      }
    }

    if (mounted) {
      setState(() {
        _mentionQuery = query;
        _mentionSuggestions = results;
        _showMentionList = results.isNotEmpty;
      });
    }
  }

  void _selectMention(Map<String, dynamic> item) {
    final text = _messageController.text;
    final sel = _messageController.selection;
    if (sel.baseOffset < 0) return;

    final textBeforeCursor = text.substring(0, sel.baseOffset);
    final textAfterCursor = text.substring(sel.baseOffset);

    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex != -1) {
      final newPrefix = textBeforeCursor.substring(0, atIndex);
      final tag = item['tag']?.toString() ?? '@${item['name']}';
      final inserted = '$tag ';
      final newText = '$newPrefix$inserted$textAfterCursor';

      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newPrefix.length + inserted.length),
      );
    }

    setState(() {
      _showMentionList = false;
      _mentionQuery = '';
      _mentionSuggestions = [];
    });
    _focusNode.requestFocus();
  }

  Widget _buildInputBar() {
    if (_isBlocked) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: context.cardBg,
          boxShadow: [
            BoxShadow(
              color: context.chatInputShadow,
              blurRadius: 10,
              offset: const Offset(0, -3),
            )
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              const Icon(Icons.block_rounded, color: AppColors.red, size: 20),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  l10n.accountBlockedByYou,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: context.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.skip,
                  style: TextStyle(fontSize: 13.sp, color: context.textMuted),
                ),
              ),
              SizedBox(width: 4.w),
              ElevatedButton(
                onPressed: _handleUnblockUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  l10n.unblock,
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: context.cardBg,
        boxShadow: [
          BoxShadow(
            color: context.chatInputShadow,
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              _buildReplyBanner(),
            Row(
              children: [
                _buildInputActionButton(
                  key: _plusButtonKey,
                  icon: Icons.add_rounded,
                  iconSize: 22,
                  onTap: _handleMoreOptions,
                ),
                SizedBox(width: 6.w),
                _buildInputActionButton(
                  icon: Icons.image_rounded,
                  iconSize: 20,
                  onTap: _handlePickImage,
                ),
                SizedBox(width: 6.w),
                _buildInputActionButton(
                  icon: Icons.mic_rounded,
                  iconSize: 20,
                  onTap: _handleVoiceRecord,
                ),
                SizedBox(width: 8.w),

                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF1E1E2C) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      onSubmitted: (_) => _sendMessage(),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14.sp,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.isDark ? const Color(0xFF1E1E2C) : Colors.grey.withValues(alpha: 0.1),
                        hintText: l10n.typeAMessage,
                        hintStyle: TextStyle(
                          color: context.textMuted,
                          fontSize: 14.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),

                IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(
                    Icons.send_rounded,
                    color: AppColors.blue,
                    size: 28.r,
                  ),
                  splashRadius: 24.r,
                ),
              ],
            ),
          ],
        ),
      ),
    );
}

  void _showMessageContextMenu({
    required BuildContext context,
    required Map<String, dynamic> msg,
    required int index,
    required Offset tapPosition,
    RenderBox? renderBox,
  }) {
    final text = (msg['text'] ?? '').toString();
    final isMe = msg['isMe'] == true;
    final isPinned = _isMessagePinned(msg);
    final String? msgId = (msg['id'] ?? msg['_id'])?.toString();

    ChatMessageContextMenu.show(
      context: context,
      msg: msg,
      index: index,
      tapPosition: tapPosition,
      renderBox: renderBox,
      isPinned: isPinned,
      bubbleWidget: _buildBubbleWidget(
        text: text,
        isMe: isMe,
        type: msg['type']?.toString(),
        location: msg['location'] is Map ? Map<String, dynamic>.from(msg['location']) : null,
        reaction: msg['reaction']?.toString(),
        replyTo: msg['replyTo'] is Map ? Map<String, dynamic>.from(msg['replyTo']) : null,
        isPinned: isPinned,
        messageId: msgId,
        msg: msg,
      ),
      onReactionSelected: (reactionId) => _toggleMessageReaction(msg, reactionId),
      onReply: () => _triggerReply(msg, isMe),
      onCopy: () {
        Clipboard.setData(ClipboardData(text: text));
        AppToast.success(context, l10n.messageCopied);
      },
      onForward: () {
        AppToast.info(context, l10n.forwardFeature);
      },
      onTogglePin: () async {
        setState(() {
          if (isPinned) {
            _pinnedMessages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == msgId);
            if (_pinnedMessages.isEmpty) _isPinnedExpanded = false;
          } else {
            _pinnedMessages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == msgId);
            _pinnedMessages.add(msg);
          }
        });
        AppToast.info(context, isPinned ? l10n.messageUnpinned : l10n.messagePinned);

        final targetConvId = _effectiveConversationId;
        if (isPinned) {
          await MessageService.unPinMessage(
            conversationId: targetConvId,
            messageId: msgId,
          );
        } else if (msgId != null) {
          await MessageService.pinMessage(
            messageId: msgId,
            conversationId: targetConvId,
          );
        }
      },
      onRecall: () async {
        final recalledId = msgId;
        setState(() {
          msg['text'] = l10n.messageHasBeenRecalled;
          msg['isRecalled'] = true;
          _pinnedMessages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == recalledId);
          if (_pinnedMessages.isEmpty) _isPinnedExpanded = false;
        });
        AppToast.info(context, l10n.messageRecalled);

        if (recalledId != null) {
          await MessageService.recallMessage(messageId: recalledId);
        }
      },
      onDelete: () async {
        final deletedId = (msg['id'] ?? msg['_id'])?.toString();
        bool removed = _messages.remove(msg);
        if (!removed && deletedId != null && deletedId.isNotEmpty) {
          final beforeLen = _messages.length;
          _messages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == deletedId);
          removed = _messages.length != beforeLen;
        }
        if (!removed && !_isBlocked && index >= 0 && index < _messages.length) {
          _messages.removeAt(index);
        }
        setState(() {
          _pinnedMessages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == deletedId);
          if (_pinnedMessages.isEmpty) _isPinnedExpanded = false;
          if (deletedId != null && deletedId.isNotEmpty) {
            _messageKeys.remove(deletedId);
          }
        });
        AppToast.info(context, l10n.messageDeleted);

        if (deletedId != null) {
          await MessageService.deleteMessage(messageId: deletedId);
        }
      },
    );
  }
}

class _SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool isMe;

  const _SwipeToReplyWrapper({
    required this.child,
    required this.onReply,
    required this.isMe,
  });

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  static const double _triggerThreshold = 46.0;
  bool _hasHapticTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.isMe) {

      final newOffset = _dragOffset + details.delta.dx;
      if (newOffset >= 0) {
        setState(() {
          if (newOffset > _triggerThreshold) {
            _dragOffset = _triggerThreshold + (newOffset - _triggerThreshold) * 0.25;
          } else {
            _dragOffset = newOffset;
          }
        });

        if (_dragOffset >= _triggerThreshold && !_hasHapticTriggered) {
          HapticFeedback.lightImpact();
          _hasHapticTriggered = true;
        } else if (_dragOffset < _triggerThreshold) {
          _hasHapticTriggered = false;
        }
      }
    } else {

      final newOffset = _dragOffset + details.delta.dx;
      if (newOffset <= 0) {
        setState(() {
          if (newOffset.abs() > _triggerThreshold) {
            _dragOffset = -(_triggerThreshold + (newOffset.abs() - _triggerThreshold) * 0.25);
          } else {
            _dragOffset = newOffset;
          }
        });

        if (_dragOffset.abs() >= _triggerThreshold && !_hasHapticTriggered) {
          HapticFeedback.lightImpact();
          _hasHapticTriggered = true;
        } else if (_dragOffset.abs() < _triggerThreshold) {
          _hasHapticTriggered = false;
        }
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() >= _triggerThreshold) {
      widget.onReply();
    }
    _reset();
  }

  void _onHorizontalDragCancel() {
    _reset();
  }

  void _reset() {
    _hasHapticTriggered = false;
    _animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      });
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset.abs() / _triggerThreshold).clamp(0.0, 1.0);
    final Color iconColor = context.isDark
        ? (_hasHapticTriggered ? Colors.white : Colors.white.withValues(alpha: 0.75))
        : (_hasHapticTriggered ? Colors.black87 : Colors.black54);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          if (_dragOffset.abs() > 2)
            Positioned(
              left: widget.isMe ? null : 4.w,
              right: widget.isMe ? 4.w : null,
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.7 + (0.3 * progress),
                  child: Transform.flip(
                    flipX: !widget.isMe,
                    child: Icon(
                      Icons.reply_rounded,
                      color: iconColor,
                      size: 22.r,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
