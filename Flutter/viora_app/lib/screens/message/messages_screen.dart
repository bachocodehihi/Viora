import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/call_service.dart';
import '../../services/contact_service.dart';
import '../../services/message_service.dart';
import '../../services/profile_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../utils/time_formatter.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';
import '../chat/chat_detail_screen.dart';
import '../chat/chat_info_screen.dart';
import '../chat/widgets/chat_call_bubble.dart';
import '../post/status_screen.dart';
import 'friend_note_viewer_screen.dart';

class MessagesScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const MessagesScreen({super.key, this.onMenuPressed});

  static VoidCallback? _globalRefreshCallback;
  static void triggerRefresh() {
    try {
      _globalRefreshCallback?.call();
    } catch (_) {}
  }

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const int _maxCachedMessages = 15;
  Language get l10n => context.l10n;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  List<Map<String, dynamic>> _trimCachedMessages(List<Map<String, dynamic>> msgs) {
    if (msgs.length <= _maxCachedMessages) {
      return List<Map<String, dynamic>>.from(msgs);
    }
    return List<Map<String, dynamic>>.from(
      msgs.sublist(msgs.length - _maxCachedMessages),
    );
  }

  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _onlineFriends = [];
  final Set<String> _friendIds = {};
  final Set<String> _hiddenActiveStatusUserIds = {};
  bool _isLoading = true;
  Timer? _onlinePollTimer;
  Function(Map<String, dynamic>)? _socketConvUpdatedCb;
  Function(Map<String, dynamic>)? _socketConversationMuteCb;
  Function(Map<String, dynamic>)? _socketConversationDeletedCb;
  Function(Map<String, dynamic>)? _socketPollUpdatedCb;
  Function(Map<String, dynamic>)? _socketNewMsgCb;
  Function(Map<String, dynamic>)? _socketCallMsgUpdatedCb;
  Function(String)? _socketUserOnlineCb;
  Function(String)? _socketUserOfflineCb;
  Function(Map<String, dynamic>)? _socketActiveStatusChangedCb;
  Function(Map<String, dynamic>)? _socketFriendAcceptedCb;
  Function(Map<String, dynamic>)? _socketFriendRemovedCb;
  StreamSubscription<String?>? _callLogSyncSub;

  String? _currentUserAvatar;
  String? _currentUserName;
  String? _currentUserEmail;
  String? _currentUserNote;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    MessagesScreen._globalRefreshCallback = () {
      if (mounted) _fetchDataFromBackend();
    };
    _loadInitialData();
    _initSocketListeners();
    _callLogSyncSub = CallService.callLogSyncStream.listen((_) {
      if (mounted) _pollDataSilently();
    });

    _onlinePollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _pollDataSilently();
    });
  }

  String _formatMessagePreview({
    required Map<String, dynamic> msg,
    required bool isGroup,
    String? fallbackSenderName,
  }) {
    if (msg['isRecalled'] == true) {
      return l10n.messageHasBeenRecalled;
    }

    final type = msg['type']?.toString() ?? 'text';
    final int rawCount = int.tryParse(msg['attachmentsCount']?.toString() ?? '') ?? 0;
    final attachments = msg['attachments'];
    final int imgCount = rawCount > 0
        ? rawCount
        : ((attachments is List && attachments.isNotEmpty)
            ? attachments.length
            : (msg['imageUrl'] != null ? 1 : 0));

    final rawText = (msg['text'] ?? msg['content'] ?? '').toString().trim();

    String? pollVoterId;
    String? pollVoterName;

    String body = '';
    if (type == 'location') {
      final loc = msg['location'];
      final locName = (loc is Map) ? (loc['name'] ?? loc['address'] ?? '') : '';
      body = '${l10n.locationPrefix} ${locName.isNotEmpty ? locName : (rawText.isNotEmpty ? rawText : l10n.sharedLocation)}';
    } else if (type == 'image' || imgCount > 0) {
      final count = imgCount > 0 ? imgCount : 1;
      final cleanText = rawText.trim();
      final bool hasCaption = cleanText.isNotEmpty && !Language.isImagePlaceholder(cleanText);
      if (count > 1) {
        body = hasCaption ? '${l10n.sentCountImages} $count ${l10n.photosCount}: $rawText' : '${l10n.sentCountImages} $count ${l10n.photosCount}';
      } else {
        body = hasCaption ? '${l10n.sentCountImages} ${l10n.onePhotoCount}: $rawText' : '${l10n.sentCountImages} ${l10n.onePhotoCount}';
      }
    } else if (type == 'poll') {
      final poll = msg['poll'] is Map ? (msg['poll'] as Map) : null;
      final lastVote = (poll != null && poll['lastVote'] is Map) ? (poll['lastVote'] as Map) : null;
      if (lastVote != null) {
        pollVoterId = lastVote['voterId']?.toString();
        pollVoterName = lastVote['voterName']?.toString();
        final action = lastVote['action']?.toString() ?? 'voted';
        String optionText = (lastVote['optionText'] ?? '').toString().trim();

        if (optionText.isEmpty && poll != null && poll['options'] is List) {
          final optList = poll['options'] as List;
          final targetOptId = lastVote['optionId']?.toString();
          for (var opt in optList) {
            if (opt is Map) {
              if (targetOptId != null && targetOptId.isNotEmpty && opt['id']?.toString() == targetOptId) {
                optionText = (opt['text'] ?? '').toString().trim();
                break;
              }
              if (pollVoterId != null && pollVoterId.isNotEmpty) {
                final vIds = opt['voterIds'];
                if (vIds is List && vIds.map((e) => e.toString()).contains(pollVoterId)) {
                  optionText = (opt['text'] ?? '').toString().trim();
                  break;
                }
              }
            }
          }
        }

        if (action == 'unvoted') {
          body = l10n.unvotedPoll;
        } else if (optionText.isNotEmpty) {
          body = '${l10n.pollSelected} "$optionText"';
        } else {
          body = l10n.votedInPoll;
        }
      } else {
        final question = (poll != null ? poll['question'] : null) ?? rawText;
        body = '[${l10n.poll}] $question';
      }
    } else if (type == 'call' || msg['call'] != null) {
      final senderId = msg['senderId']?.toString();
      final bool isFromMe = msg['isMe'] == true ||
          (senderId != null && _currentUserId != null && senderId == _currentUserId);
      final senderName = (msg['senderName'] ?? fallbackSenderName ?? '').toString().trim();
      return ChatCallBubble.formatListPreview(
        context,
        msg,
        isMe: isFromMe,
        isGroup: isGroup,
        senderName: senderName,
      );
    } else if (type == 'system') {
      final senderId = msg['senderId']?.toString();
      final bool isFromMe = msg['isMe'] == true ||
          (senderId != null && _currentUserId != null && senderId == _currentUserId);
      if (isFromMe) {
        if (rawText.contains('đã bình chọn') || rawText.contains('voted in the poll')) {
          return l10n.youVotedPoll;
        } else if (rawText.contains('thay đổi bình chọn') || rawText.contains('changed')) {
          return l10n.youChangedVotePoll;
        } else if (rawText.contains('huỷ bình chọn') || rawText.contains('unvoted') || rawText.contains('removed')) {
          return l10n.youUnvotedPoll;
        }
      }
      return rawText;
    } else if (type == 'audio') {
      final dur = (msg['text'] ?? msg['content'] ?? '').toString().trim();
      body = dur.isNotEmpty ? '🎤 $dur' : '🎤 ${LanguageManager.isEnglish() ? 'Voice message' : 'Tin nhắn thoại'}';
    } else if (type == 'emoji' || ChatInfoScreen.getReactionAsset(rawText) != null) {
      body = ChatInfoScreen.getEmojiSymbol(rawText);
    } else {
      body = rawText;
    }

    if (body.isEmpty) return '';

    String? senderId = msg['senderId']?.toString();
    String senderName = (msg['senderName'] ?? fallbackSenderName ?? '').toString().trim();
    bool isFromMe = msg['isMe'] == true ||
        (senderId != null && _currentUserId != null && senderId == _currentUserId);

    if (type == 'poll' && pollVoterId != null && pollVoterId.isNotEmpty) {
      senderId = pollVoterId;
      isFromMe = (_currentUserId != null && pollVoterId == _currentUserId);
      if (pollVoterName != null && pollVoterName.isNotEmpty) {
        senderName = pollVoterName;
      }
    }

    final bool isAi = msg['isAi'] == true || senderId == 'viora_ai';
    if (isGroup) {
      final prefix = isFromMe
          ? '${l10n.you}: '
          : (isAi ? 'VioraAI: ' : (senderName.isNotEmpty ? '$senderName: ' : ''));
      return '$prefix$body';
    } else {
      final prefix = isFromMe ? '${l10n.you}: ' : (isAi ? 'VioraAI: ' : '');
      return '$prefix$body';
    }
  }

  String _formatChatSubtitle(Map<String, dynamic> chat) {

    if (chat['lastMessageData'] is Map) {
      final data = Map<String, dynamic>.from(chat['lastMessageData'] as Map);
      final formatted = _formatMessagePreview(
        msg: data,
        isGroup: chat['isGroup'] == true,
        fallbackSenderName: chat['name']?.toString(),
      );
      if (formatted.isNotEmpty) return formatted;
    }

    if (chat['messages'] is List && (chat['messages'] as List).isNotEmpty) {
      final messagesList = chat['messages'] as List;
      final lastMsg = messagesList.last;
      if (lastMsg is Map<String, dynamic>) {
        final formatted = _formatMessagePreview(
          msg: lastMsg,
          isGroup: chat['isGroup'] == true,
          fallbackSenderName: chat['name']?.toString(),
        );
        if (formatted.isNotEmpty) return formatted;
      }
    }

    return (chat['lastMessage'] ?? '').toString().trim();
  }

  bool _isMissedCallSubtitle(Map<String, dynamic> chat) {
    final rawData = chat['lastMessageData'];
    if (rawData is! Map) return false;
    final data = Map<String, dynamic>.from(rawData);
    if (data['type'] != 'call' && data['call'] == null) return false;
    final call = data['call'] is Map ? (data['call'] as Map) : null;
    final status = call?['status']?.toString();
    if (status != 'missed' && status != 'cancelled') return false;
    final senderId = data['senderId']?.toString();
    final isFromMe = data['isMe'] == true ||
        (senderId != null && _currentUserId != null && senderId == _currentUserId);
    return !isFromMe;
  }

  String _formatChatTime(Map<String, dynamic> chat) {
    return TimeFormatter.formatChatTime(
      context,
      date: chat['lastMessageDate'],
      fallbackTime: chat['time']?.toString(),
    );
  }

  DateTime? _tryParseChatDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final asInt = int.tryParse(trimmed);
      if (asInt != null && trimmed.length >= 10) {
        return DateTime.fromMillisecondsSinceEpoch(
          trimmed.length == 10 ? asInt * 1000 : asInt,
          isUtc: true,
        );
      }
      return DateTime.tryParse(trimmed)?.toUtc();
    }
    return null;
  }

  void _sortChatsByLatest([List<Map<String, dynamic>>? list]) {
    final target = list ?? _chats;
    target.sort((a, b) {
      final da = _tryParseChatDate(a['lastMessageDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final db = _tryParseChatDate(b['lastMessageDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return db.compareTo(da);
    });
  }

  void _initSocketListeners() {
    SocketService.init();

    SocketService.onConversationUpdated(_socketConvUpdatedCb = (data) {
      if (!mounted) return;
      final convId = data['conversationId']?.toString();
      final lastMsg = data['lastMessage']?.toString() ?? '';
      final timeStr = data['time']?.toString() ?? '';
      final rawUnread = data['unread'];
      final senderId = data['senderId']?.toString();
      final lastMsgDate = data['lastMessageDate'];
      final bool hasMessagePayload =
          data['lastMessageData'] is Map || lastMsg.isNotEmpty || lastMsgDate != null;

      if (convId == null || convId.isEmpty) return;

      final existingIndex = _chats.indexWhere((c) => c['id']?.toString() == convId);
      if (existingIndex != -1) {
        setState(() {
          final chat = _chats[existingIndex];
          if (data['lastMessageData'] is Map) {
            chat['lastMessageData'] = Map<String, dynamic>.from(data['lastMessageData'] as Map);
          }
          if (lastMsg.isNotEmpty) chat['lastMessage'] = lastMsg;
          if (timeStr.isNotEmpty) chat['time'] = timeStr;
          if (lastMsgDate != null) {
            chat['lastMessageDate'] = lastMsgDate;
          } else if (hasMessagePayload && data['updatedAt'] != null) {
            chat['lastMessageDate'] = data['updatedAt'];
          }
          if (rawUnread != null) {
            chat['unread'] = int.tryParse(rawUnread.toString()) ?? 0;
          } else if (senderId != null && _currentUserId != null && senderId != _currentUserId) {
            final cur = int.tryParse(chat['unread']?.toString() ?? '0') ?? 0;
            chat['unread'] = cur + 1;
          }

          if (hasMessagePayload) {
            _sortChatsByLatest();
          }
        });
      } else if (hasMessagePayload) {
        _fetchDataFromBackend();
      }
    });

    SocketService.onPollUpdated(_socketPollUpdatedCb = (data) {
      if (!mounted) return;
      final convId = data['conversationId']?.toString();
      final msgId = data['messageId']?.toString();
      final poll = data['poll'];
      if (convId == null || convId.isEmpty) return;

      final existingIndex = _chats.indexWhere((c) => c['id']?.toString() == convId);
      if (existingIndex != -1) {
        setState(() {
          final chat = _chats[existingIndex];
          if (poll is Map) {
            final voterId = data['voterId']?.toString();
            final voterName = data['voterName']?.toString();
            final isFromMe = voterId != null && _currentUserId != null && voterId == _currentUserId;

            final pollData = Map<String, dynamic>.from(poll);
            chat['lastMessageData'] = {
              'id': msgId,
              'type': 'poll',
              'poll': pollData,
              'senderId': voterId,
              'senderName': voterName,
              'isMe': isFromMe,
              'createdAt': data['createdAt'],
            };

            final formatted = _formatMessagePreview(
              msg: chat['lastMessageData'],
              isGroup: chat['isGroup'] == true,
              fallbackSenderName: voterName ?? chat['name']?.toString(),
            );
            chat['lastMessage'] = formatted.isNotEmpty ? formatted : (data['text']?.toString() ?? '');

            if (data['createdAt'] != null) {
              chat['lastMessageDate'] = data['createdAt'];
            }
            if (data['time'] != null) {
              chat['time'] = data['time'];
            }
            if (chat['messages'] is List) {
              final msgs = List<Map<String, dynamic>>.from(chat['messages'] as List);
              final mIdx = msgs.indexWhere((m) => (m['id'] ?? m['_id'])?.toString() == msgId);
              if (mIdx != -1) {
                final pollMsg = Map<String, dynamic>.from(msgs[mIdx]);
                pollMsg['poll'] = pollData;
                if (data['createdAt'] != null) {
                  pollMsg['createdAt'] = data['createdAt'];
                }
                if (data['time'] != null) {
                  pollMsg['time'] = data['time'];
                }
                msgs.removeAt(mIdx);
                msgs.add(pollMsg);
                chat['messages'] = msgs;
              }
            }
            _sortChatsByLatest();
          }
        });
      }
    });

    SocketService.onConversationMuteUpdated(_socketConversationMuteCb = (data) {
      if (!mounted) return;
      final convId = data['conversationId']?.toString();
      if (convId != null) {
        final existingIndex = _chats.indexWhere((c) => c['id']?.toString() == convId);
        if (existingIndex != -1) {
          setState(() {
            _chats[existingIndex]['isMuted'] = data['isMuted'] == true;
            _chats[existingIndex]['mutedUntil'] = data['mutedUntil'];
          });
        }
      }
    });

    SocketService.onConversationDeleted(_socketConversationDeletedCb = (data) {
      if (!mounted) return;
      final convId = data['conversationId']?.toString();
      if (convId != null) {
        setState(() {
          _chats.removeWhere((c) => c['id']?.toString() == convId);
        });
      }
    });

    SocketService.onNewMessage(_socketNewMsgCb = (newMsgData) {
      if (!mounted) return;
      final convId = newMsgData['conversationId']?.toString();
      final senderId = newMsgData['senderId']?.toString();
      final isFromMe = (senderId != null && _currentUserId != null && senderId == _currentUserId);
      final isCallMsg = newMsgData['type'] == 'call' || newMsgData['call'] != null;

      if (convId != null && (!isFromMe || isCallMsg)) {
        final existingIndex = _chats.indexWhere((c) => c['id']?.toString() == convId);
        if (existingIndex != -1) {
          setState(() {
            final chat = _chats[existingIndex];
            final isGroup = chat['isGroup'] == true;
            final normalizedMsg = Map<String, dynamic>.from(newMsgData)
              ..['isMe'] = isFromMe;
            final formatted = _formatMessagePreview(
              msg: normalizedMsg,
              isGroup: isGroup,
              fallbackSenderName: normalizedMsg['senderName']?.toString() ?? chat['name']?.toString(),
            );
            chat['lastMessage'] = formatted.isNotEmpty ? formatted : (normalizedMsg['text']?.toString() ?? '');
            chat['lastMessageData'] = normalizedMsg;
            if (normalizedMsg['time'] != null) chat['time'] = normalizedMsg['time'].toString();
            if (normalizedMsg['createdAt'] != null) chat['lastMessageDate'] = normalizedMsg['createdAt'];

            if (chat['messages'] is List) {
              final msgs = List<Map<String, dynamic>>.from(
                (chat['messages'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
              );
              final msgId = (normalizedMsg['id'] ?? normalizedMsg['_id'])?.toString();
              if (msgId != null &&
                  msgId.isNotEmpty &&
                  !msgs.any((m) => (m['id'] ?? m['_id'])?.toString() == msgId)) {
                msgs.add(normalizedMsg);
                chat['messages'] = _trimCachedMessages(msgs);
              }
            }

            final callStatus = (normalizedMsg['call'] is Map)
                ? normalizedMsg['call']['status']?.toString()
                : null;
            final bool isCallNoUnread = isFromMe ||
                (isCallMsg &&
                    (callStatus == 'completed' ||
                        callStatus == 'declined' ||
                        callStatus == 'ringing' ||
                        callStatus == 'ongoing'));
            if (!isCallNoUnread) {
              final cur = int.tryParse(chat['unread']?.toString() ?? '0') ?? 0;
              chat['unread'] = cur + 1;
            }
            _sortChatsByLatest();
          });
        } else {
          _fetchDataFromBackend();
        }
      }
    });

    SocketService.onCallMessageUpdated(_socketCallMsgUpdatedCb = (updatedMsgData) {
      if (!mounted) return;
      final convId = updatedMsgData['conversationId']?.toString();
      if (convId == null || convId.isEmpty) return;

      final existingIndex = _chats.indexWhere((c) => c['id']?.toString() == convId);
      if (existingIndex == -1) return;

      final senderId = updatedMsgData['senderId']?.toString();
      final isFromMe = senderId != null && _currentUserId != null && senderId == _currentUserId;
      final normalizedMsg = Map<String, dynamic>.from(updatedMsgData)..['isMe'] = isFromMe;
      final updatedMsgId = (normalizedMsg['id'] ?? normalizedMsg['_id'])?.toString();
      final updatedCallId = (normalizedMsg['call'] is Map)
          ? normalizedMsg['call']['callId']?.toString()
          : null;

      setState(() {
        final chat = _chats[existingIndex];
        final isGroup = chat['isGroup'] == true;

        if (chat['messages'] is List) {
          final msgs = List<Map<String, dynamic>>.from(
            (chat['messages'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          );
          final mIdx = msgs.indexWhere((m) {
            final mId = (m['id'] ?? m['_id'])?.toString();
            if (updatedMsgId != null && updatedMsgId.isNotEmpty && mId == updatedMsgId) return true;
            if (updatedCallId != null && updatedCallId.isNotEmpty && m['call'] is Map) {
              return (m['call'] as Map)['callId']?.toString() == updatedCallId;
            }
            return false;
          });
          if (mIdx != -1) {
            msgs[mIdx] = {...msgs[mIdx], ...normalizedMsg};
            chat['messages'] = msgs;
          }
        }

        final curLast = chat['lastMessageData'];
        if (curLast is Map) {
          final curLastId = (curLast['id'] ?? curLast['_id'])?.toString();
          final curLastCallId = (curLast['call'] is Map)
              ? (curLast['call'] as Map)['callId']?.toString()
              : null;
          final bool matchesLast =
              (updatedMsgId != null && updatedMsgId.isNotEmpty && curLastId == updatedMsgId) ||
                  (updatedCallId != null && updatedCallId.isNotEmpty && curLastCallId == updatedCallId);
          if (matchesLast) {
            chat['lastMessageData'] = {...Map<String, dynamic>.from(curLast), ...normalizedMsg};
            final formatted = _formatMessagePreview(
              msg: Map<String, dynamic>.from(chat['lastMessageData'] as Map),
              isGroup: isGroup,
              fallbackSenderName: normalizedMsg['senderName']?.toString() ?? chat['name']?.toString(),
            );
            if (formatted.isNotEmpty) {
              chat['lastMessage'] = formatted;
            }
          }
        }
      });
    });

    SocketService.onUserOnline(_socketUserOnlineCb = (userId) {
      if (!mounted || userId.isEmpty) return;

      if (!_friendIds.contains(userId) || _hiddenActiveStatusUserIds.contains(userId)) {
        return;
      }

      setState(() {
        for (var c in _chats) {
          if (c['otherUserId']?.toString() == userId &&
              c['isGroup'] != true &&
              c['isBlocked'] != true &&
              c['showActiveStatus'] != false) {
            c['online'] = true;
          }
        }
        final matchChat = _chats.firstWhere(
          (c) => c['otherUserId']?.toString() == userId,
          orElse: () => {},
        );
        if (matchChat.isNotEmpty &&
            matchChat['isGroup'] != true &&
            matchChat['isBlocked'] != true &&
            matchChat['showActiveStatus'] != false) {
          final alreadyOnline = _onlineFriends.any((f) =>
              (f['otherUserId']?.toString() == userId || f['id']?.toString() == userId));
          if (!alreadyOnline) {
            _onlineFriends.add({
              'id': userId,
              'otherUserId': userId,
              'conversationId': matchChat['id'],
              'name': matchChat['name'],
              'avatar': matchChat['avatar'],
              'color': matchChat['color'],
              'online': true,
              'showActiveStatus': true,
              'isFriend': true,
            });
          }
        }
      });
    });

    SocketService.onUserOffline(_socketUserOfflineCb = (userId) {
      if (!mounted || userId.isEmpty) return;
      setState(() {
        for (var c in _chats) {
          if (c['otherUserId']?.toString() == userId) {
            c['online'] = false;
          }
        }
        _onlineFriends.removeWhere((f) =>
            f['otherUserId']?.toString() == userId || f['id']?.toString() == userId);
      });
    });

    SocketService.onUserActiveStatusChanged(_socketActiveStatusChangedCb = (data) {
      if (!mounted) return;
      final userId = data['userId']?.toString() ?? '';
      if (userId.isEmpty) return;
      final bool showActiveStatus = data['showActiveStatus'] != false;
      final bool isOnlineNow =
          showActiveStatus && (data['isOnline'] == true || data['online'] == true);

      setState(() {
        if (!showActiveStatus) {
          _hiddenActiveStatusUserIds.add(userId);
          for (var c in _chats) {
            if (c['otherUserId']?.toString() == userId) {
              c['showActiveStatus'] = false;
              c['online'] = false;
            }
          }
          _onlineFriends.removeWhere((f) =>
              f['otherUserId']?.toString() == userId || f['id']?.toString() == userId);
        } else {
          _hiddenActiveStatusUserIds.remove(userId);
          if (_friendIds.contains(userId)) {
            for (var c in _chats) {
              if (c['otherUserId']?.toString() == userId &&
                  c['isGroup'] != true &&
                  c['isBlocked'] != true) {
                c['showActiveStatus'] = true;
                c['online'] = isOnlineNow;
              }
            }
            if (isOnlineNow) {
              final matchChat = _chats.firstWhere(
                (c) =>
                    c['otherUserId']?.toString() == userId &&
                    c['isGroup'] != true &&
                    c['isBlocked'] != true,
                orElse: () => {},
              );
              if (matchChat.isNotEmpty) {
                final alreadyOnline = _onlineFriends.any((f) =>
                    (f['otherUserId']?.toString() == userId ||
                        f['id']?.toString() == userId));
                if (!alreadyOnline) {
                  _onlineFriends.add({
                    'id': userId,
                    'otherUserId': userId,
                    'conversationId': matchChat['id'],
                    'name': matchChat['name'],
                    'avatar': matchChat['avatar'],
                    'color': matchChat['color'],
                    'online': true,
                    'showActiveStatus': true,
                    'isFriend': true,
                  });
                }
              }
            } else {
              _onlineFriends.removeWhere((f) =>
                  f['otherUserId']?.toString() == userId || f['id']?.toString() == userId);
            }
          }
        }
      });
    });

    SocketService.onUserNoteUpdated((data) {
      if (!mounted) return;
      final userId = data['userId']?.toString();
      final note = (data['note'] ?? '').toString().trim();
      if (userId == null || userId.isEmpty) return;

      setState(() {
        if (userId == _currentUserId) {
          _currentUserNote = note.isNotEmpty ? note : null;
        }

        for (var f in _onlineFriends) {
          if (f['otherUserId']?.toString() == userId || f['id']?.toString() == userId) {
            f['note'] = note;
          }
        }
      });
    });

    SocketService.onFriendRequestAccepted(_socketFriendAcceptedCb = (data) {
      if (!mounted) return;
      final uid = data['userId']?.toString() ?? '';
      if (uid.isEmpty) return;
      final bool show = data['showActiveStatus'] == true;
      final bool online = show && (data['online'] == true);
      setState(() {
        _friendIds.add(uid);
        if (!show) {
          _hiddenActiveStatusUserIds.add(uid);
        } else {
          _hiddenActiveStatusUserIds.remove(uid);
        }
        for (var c in _chats) {
          if (c['otherUserId']?.toString() == uid && c['isGroup'] != true) {
            c['isFriend'] = true;
            c['showActiveStatus'] = show && c['isBlocked'] != true;
            c['online'] = (c['showActiveStatus'] == true) && online;
          }
        }
      });
    });

    SocketService.onFriendRemoved(_socketFriendRemovedCb = (data) {
      if (!mounted) return;
      final uid = data['userId']?.toString() ?? '';
      if (uid.isEmpty) return;
      setState(() {
        _friendIds.remove(uid);
        for (var c in _chats) {
          if (c['otherUserId']?.toString() == uid && c['isGroup'] != true) {
            c['isFriend'] = false;
            c['showActiveStatus'] = false;
            c['online'] = false;
          }
        }
        _onlineFriends.removeWhere((f) =>
            f['otherUserId']?.toString() == uid || f['id']?.toString() == uid);
      });
    });
  }

  @override
  void dispose() {
    _onlinePollTimer?.cancel();
    _callLogSyncSub?.cancel();
    _searchController.dispose();
    MessagesScreen._globalRefreshCallback = null;
    if (_socketConvUpdatedCb != null) SocketService.offConversationUpdated(_socketConvUpdatedCb);
    if (_socketConversationMuteCb != null) SocketService.offConversationMuteUpdated(_socketConversationMuteCb);
    if (_socketConversationDeletedCb != null) SocketService.offConversationDeleted(_socketConversationDeletedCb);
    if (_socketPollUpdatedCb != null) SocketService.offPollUpdated(_socketPollUpdatedCb);
    if (_socketNewMsgCb != null) SocketService.offNewMessage(_socketNewMsgCb);
    if (_socketCallMsgUpdatedCb != null) SocketService.offCallMessageUpdated(_socketCallMsgUpdatedCb);
    if (_socketUserOnlineCb != null) SocketService.offUserOnline(_socketUserOnlineCb);
    if (_socketUserOfflineCb != null) SocketService.offUserOffline(_socketUserOfflineCb);
    if (_socketActiveStatusChangedCb != null) {
      SocketService.offUserActiveStatusChanged(_socketActiveStatusChangedCb);
    }
    if (_socketFriendAcceptedCb != null) {
      SocketService.offFriendRequestAccepted(_socketFriendAcceptedCb!);
    }
    if (_socketFriendRemovedCb != null) {
      SocketService.offFriendRemoved(_socketFriendRemovedCb!);
    }
    super.dispose();
  }

  Color _parseColor(dynamic c, String? name) {
    if (c is Color) return c;
    if (c is String && c.startsWith('#')) {
      try {
        return Color(int.parse(c.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return AppAvatar.getColorForName(name);
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    final cachedAvatar = await SessionService.getAvatar();
    final cachedUsername = await SessionService.getUsername();
    final cachedEmail = await SessionService.getUserEmail();
    final cachedNote = await SessionService.getUserNote();
    final cachedUserId = await SessionService.getUserId();
    if (mounted) {
      setState(() {
        _currentUserAvatar = cachedAvatar;
        _currentUserName = cachedUsername;
        _currentUserEmail = cachedEmail;
        _currentUserNote = cachedNote;
        _currentUserId = cachedUserId;
      });
    }

    await _fetchDataFromBackend();

    final profile = await ProfileService.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _currentUserAvatar = profile['avatar']?.toString() ?? _currentUserAvatar;
        _currentUserName = profile['username']?.toString() ?? _currentUserName;
        if (profile['note'] != null) {
          final pNote = profile['note'].toString().trim();
          _currentUserNote = pNote.isNotEmpty ? pNote : null;
        }
      });
      if (_currentUserNote != null && _currentUserNote!.isNotEmpty) {
        await SessionService.saveUserNote(_currentUserNote!);
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pollDataSilently() async {
    final note = await SessionService.getUserNote();
    if (note != _currentUserNote && mounted) {
      setState(() {
        _currentUserNote = note;
      });
    }
    await _fetchDataFromBackend();
  }

  Future<void> _fetchDataFromBackend() async {
    try {

      final conversations = await MessageService.fetchConversations();
      final contactsData = await ContactService.fetchContacts();
      if (!mounted) return;
      final userLabel = l10n.user;
      final friendLabel = l10n.friend;

      final List<Map<String, dynamic>> chatsList = [];
      final Map<String, Map<String, dynamic>> onlineMap = {};

      void addOrUpdateOnlineFriend({
        String? userId,
        String? conversationId,
        required String name,
        dynamic avatar,
        required Color color,
        String? note,
      }) {
        final cleanName = name.trim();
        final cleanUserId = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : null;

        String? targetKey;
        for (var entry in onlineMap.entries) {
          final existingUserId = entry.value['otherUserId']?.toString() ?? entry.value['id']?.toString();
          final existingName = (entry.value['name'] ?? '').toString().trim().toLowerCase();

          if ((cleanUserId != null && existingUserId == cleanUserId) ||
              (cleanName.isNotEmpty && existingName == cleanName.toLowerCase())) {
            targetKey = entry.key;
            break;
          }
        }

        targetKey ??= cleanUserId ?? cleanName.toLowerCase();
        final existing = onlineMap[targetKey];

        onlineMap[targetKey] = {
          'id': cleanUserId ?? existing?['id'] ?? conversationId,
          'conversationId': conversationId ?? existing?['conversationId'],
          'otherUserId': cleanUserId ?? existing?['otherUserId'],
          'name': cleanName,
          'avatar': (avatar != null && avatar.toString().isNotEmpty) ? avatar : existing?['avatar'],
          'color': color,
          'note': note ?? existing?['note'],
          'online': true,
        };
      }

      void removeOnlineFriend({String? userId, required String name}) {
        final cleanName = name.trim().toLowerCase();
        final cleanUserId = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : null;

        onlineMap.removeWhere((key, val) {
          final existingUserId = val['otherUserId']?.toString() ?? val['id']?.toString();
          final existingName = (val['name'] ?? '').toString().trim().toLowerCase();
          return (cleanUserId != null && existingUserId == cleanUserId) ||
              (cleanName.isNotEmpty && existingName == cleanName);
        });
      }

      final Set<String> friendIdSet = {};
      final Set<String> friendNameSet = {};
      if (contactsData != null && contactsData['friends'] is List) {
        final friends = contactsData['friends'] as List;
        for (var f in friends) {
          if (f is Map<String, dynamic>) {
            final fid = f['id']?.toString();
            if (fid != null && fid.isNotEmpty) friendIdSet.add(fid);
            final fname = (f['name'] ?? '').toString().trim().toLowerCase();
            if (fname.isNotEmpty) friendNameSet.add(fname);
          }
        }
      }

      final Set<String> hiddenIds = {};

      if (conversations != null && conversations.isNotEmpty) {
        for (var c in conversations) {
          final color = _parseColor(c['color'], c['name']?.toString());
          final otherUserId = c['otherUserId']?.toString();
          final chatName = (c['name'] ?? '').toString().trim().toLowerCase();
          final bool isGroup = c['isGroup'] == true;
          final bool isBlocked = c['isBlocked'] == true;
          final bool isFriend = c['isFriend'] == true ||
              (otherUserId != null && friendIdSet.contains(otherUserId)) ||
              (chatName.isNotEmpty && friendNameSet.contains(chatName));

          final bool serverShowActive = c['showActiveStatus'] != false;
          if (!isGroup && otherUserId != null && otherUserId.isNotEmpty && c['showActiveStatus'] == false) {
            hiddenIds.add(otherUserId);
          }
          final bool showActiveStatus = !isGroup && !isBlocked && isFriend && serverShowActive;
          final isOnline = showActiveStatus && (c['online'] == true);

          List<Map<String, dynamic>> finalMessages = _trimCachedMessages(
            c['messages'] is List
                ? List<Map<String, dynamic>>.from(c['messages'])
                : <Map<String, dynamic>>[],
          );
          final bool hasMoreMessages = c['hasMoreMessages'] == true ||
              (c['messages'] is List && (c['messages'] as List).length > _maxCachedMessages);

          final existingChat = _chats.firstWhere(
            (cItem) => cItem['id']?.toString() == (c['id']?.toString() ?? ''),
            orElse: () => <String, dynamic>{},
          );

          dynamic lastMsgData = c['lastMessageData'] is Map
              ? Map<String, dynamic>.from(c['lastMessageData'] as Map)
              : null;
          String lastMsgText = c['lastMessage']?.toString() ?? '';
          dynamic lastMsgDate = c['lastMessageDate'] ?? c['updatedAt'] ?? c['createdAt'];
          String lastTime = c['time']?.toString() ?? '';

          if (existingChat.isNotEmpty && existingChat['messages'] is List) {
            final localMsgs = List<Map<String, dynamic>>.from(existingChat['messages'] as List);
            if (localMsgs.isNotEmpty) {
 
              if (false) {
              } else {

                for (var localMsg in localMsgs) {
                  if (localMsg['type'] == 'poll' && localMsg['poll'] is Map) {
                    final pId = (localMsg['id'] ?? localMsg['_id'])?.toString();
                    final sIdx = finalMessages.indexWhere((sm) => (sm['id'] ?? sm['_id'])?.toString() == pId);
                    if (sIdx != -1) {
                      final sPoll = finalMessages[sIdx]['poll'];
                      if (sPoll is Map) {
                        final localPoll = localMsg['poll'];
                        final Map? localLastVote = (localPoll is Map && localPoll['lastVote'] is Map) ? (localPoll['lastVote'] as Map) : null;
                        final Map? serverLastVote = sPoll['lastVote'] is Map ? (sPoll['lastVote'] as Map) : null;
                        final localVoteTime = DateTime.tryParse(localLastVote?['updatedAt']?.toString() ?? '');
                        final serverVoteTime = DateTime.tryParse(serverLastVote?['updatedAt']?.toString() ?? '');
                        if (localVoteTime != null && (serverVoteTime == null || localVoteTime.isAfter(serverVoteTime))) {
                          finalMessages[sIdx]['poll'] = localMsg['poll'];
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          chatsList.add({
            'id': c['id']?.toString() ?? '',
            'name': c['name']?.toString() ?? userLabel,
            'avatar': c['avatar'],
            'color': color,
            'lastMessage': lastMsgText,
            'lastMessageData': lastMsgData,
            'lastMessageDate': lastMsgDate,
            'time': lastTime,
            'unread': int.tryParse(c['unread']?.toString() ?? '0') ?? (c['unread'] is int ? c['unread'] as int : 0),
            'online': isOnline,
            'showActiveStatus': showActiveStatus,
            'isFriend': isFriend,
            'isGroup': isGroup,
            'isBlocked': isBlocked,
            'otherUserId': otherUserId,
            'messages': finalMessages,
            'hasMoreMessages': hasMoreMessages,
          });
        }
      }

      if (contactsData != null && contactsData['friends'] is List) {
        final friends = contactsData['friends'] as List;
        for (var f in friends) {
          if (f is Map<String, dynamic>) {
            final bool friendShowActive = f['showActiveStatus'] != false;
            final friendId = f['id']?.toString();
            if (friendId != null && friendId.isNotEmpty) {
              if (!friendShowActive) {
                hiddenIds.add(friendId);
              } else {
                hiddenIds.remove(friendId);
              }
            }
            final isOnline = friendShowActive && (f['online'] == true || f['isOnline'] == true);
            final friendName = f['name']?.toString() ?? friendLabel;
            final friendAvatar = f['avatar'];
            final friendColor = _parseColor(f['color'], friendName);

            for (var chat in chatsList) {
              if ((friendId != null && chat['otherUserId'] == friendId) ||
                  chat['name']?.toString().toLowerCase() == friendName.toLowerCase()) {
                chat['isFriend'] = true;
                final bool canShow = friendShowActive && chat['isBlocked'] != true;
                chat['showActiveStatus'] = canShow;
                chat['online'] = canShow && isOnline;
              }
            }

            final friendNote = f['note']?.toString();
            if (isOnline) {
              addOrUpdateOnlineFriend(
                userId: friendId,
                name: friendName,
                avatar: friendAvatar,
                color: friendColor,
                note: friendNote,
              );
            } else {
              removeOnlineFriend(
                userId: friendId,
                name: friendName,
              );
            }
          }
        }
      }

      final newOnlineList = onlineMap.values.toList();
      _sortChatsByLatest(chatsList);

      if (mounted) {
        setState(() {
          _friendIds.clear();
          _friendIds.addAll(friendIdSet);
          _hiddenActiveStatusUserIds
            ..clear()
            ..addAll(hiddenIds);
          _chats = chatsList;
          _onlineFriends = newOnlineList;
        });
        final convIds = chatsList.map((c) => c['id']?.toString()).whereType<String>();
        SocketService.joinConversations(convIds);
      }
    } catch (e) {
      debugPrint('Error fetching messaging data from backend: $e');
    }
  }

  void _openChatWithFriend(Map<String, dynamic> friend) async {
    final friendName = (friend['name'] ?? '').toString();
    final friendId = (friend['id'] ?? friend['otherUserId'] ?? '').toString();
    final convId = friend['conversationId']?.toString();

    Map<String, dynamic>? existingChat;
    try {
      existingChat = _chats.firstWhere(
        (c) =>
            (convId != null && convId.isNotEmpty && c['id'] == convId) ||
            (friendId.isNotEmpty && (c['id'] == friendId || c['otherUserId'] == friendId)) ||
            (c['name'] != null && c['name'].toString().toLowerCase() == friendName.toLowerCase()),
      );
    } catch (_) {
      existingChat = null;
    }

    if (existingChat != null) {
      setState(() {
        existingChat!['unread'] = 0;
      });
    }

    final initialMessages = existingChat != null
        ? List<Map<String, dynamic>>.from(existingChat['messages'] ?? [])
        : <Map<String, dynamic>>[];
    final bool? hasMoreMessages = existingChat != null
        ? (existingChat['hasMoreMessages'] as bool?)
        : null;

    final List<Map<String, dynamic>> initialVisibleMessages = initialMessages
        .where((m) => m['type']?.toString() != 'system')
        .toList();

    final Set<String> prevMessageIds = {};
    for (final m in initialVisibleMessages) {
      final mId = (m['id'] ?? m['_id'])?.toString();
      if (mId != null && mId.isNotEmpty) {
        prevMessageIds.add(mId);
      }
    }

    String? prevLastId;
    DateTime? prevLastDate = _tryParseChatDate(existingChat?['lastMessageDate']);
    if (existingChat != null) {
      final rawLastData = existingChat['lastMessageData'];
      if (rawLastData is Map) {
        final dId = (rawLastData['id'] ?? rawLastData['_id'])?.toString();
        if (dId != null && dId.isNotEmpty) {
          prevLastId = dId;
          prevMessageIds.add(dId);
        }
        prevLastDate ??= _tryParseChatDate(rawLastData['createdAt']);
      }
    }
    if (initialVisibleMessages.isNotEmpty) {
      final existingLast = initialVisibleMessages.last;
      final eId = (existingLast['id'] ?? existingLast['_id'])?.toString();
      if (eId != null && eId.isNotEmpty) {
        prevLastId ??= eId;
      }
      prevLastDate ??= _tryParseChatDate(existingLast['createdAt']);
    }

    final isGroup = friend['isGroup'] == true || (existingChat != null && existingChat['isGroup'] == true);
    final conversationId = existingChat != null ? existingChat['id']?.toString() : convId;
    final receiverId = isGroup ? null : (friend['otherUserId']?.toString() ?? (friendId != conversationId ? friendId : null));
    final bool isFriend = friend['isFriend'] == true ||
        (existingChat != null && existingChat['isFriend'] == true) ||
        (receiverId != null && _friendIds.contains(receiverId));
    final bool isBlocked = friend['isBlocked'] == true || (existingChat != null && existingChat['isBlocked'] == true);
    final bool rawShowActive =
        (friend['showActiveStatus'] ?? existingChat?['showActiveStatus'] ?? true) != false;
    final bool showActiveStatus = !isGroup &&
        !isBlocked &&
        isFriend &&
        rawShowActive &&
        (receiverId == null || !_hiddenActiveStatusUserIds.contains(receiverId));
    final bool isOnline = showActiveStatus &&
        (friend['online'] == true || (existingChat != null && existingChat['online'] == true));

    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          name: friendName,
          avatar: (friend['avatar'] ?? '').toString(),
          color: _parseColor(friend['color'], friendName),
          initialMessages: initialMessages,
          hasMoreMessages: hasMoreMessages,
          conversationId: conversationId,
          receiverId: receiverId,
          isGroup: isGroup,
          isFriend: isFriend,
          isOnline: isOnline,
          showActiveStatus: showActiveStatus,
          isBlocked: isBlocked,
          currentUserId: _currentUserId,
          currentUsername: _currentUserName,
          currentUserAvatar: _currentUserAvatar,
        ),
      ),
    );

    if (result != null && mounted) {
      final List<Map<String, dynamic>> visibleResult = result
          .where((m) => m['type']?.toString() != 'system')
          .toList();

      setState(() {
        final targetId = conversationId ?? existingChat?['id']?.toString();
        final trimmedResult = _trimCachedMessages(result);

        if (visibleResult.isEmpty) {
          final currentIdx = (targetId != null && targetId.isNotEmpty)
              ? _chats.indexWhere((c) => c['id']?.toString() == targetId)
              : -1;
          final targetChat = currentIdx != -1 ? _chats[currentIdx] : existingChat;
          if (targetChat != null) {
            targetChat['messages'] = trimmedResult;
            targetChat['hasMoreMessages'] =
                result.length > _maxCachedMessages || (targetChat['hasMoreMessages'] == true);
            targetChat['unread'] = 0;
          }
          return;
        }

        final lastMsg = visibleResult.last;
        final String? nextLastId = (lastMsg['id'] ?? lastMsg['_id'])?.toString();
        final DateTime? nextLastDate = _tryParseChatDate(lastMsg['createdAt']);

        final bool isSameMessageId = nextLastId != null &&
            nextLastId.isNotEmpty &&
            prevLastId != null &&
            prevLastId.isNotEmpty &&
            nextLastId == prevLastId;

        final bool isOptimisticNew = nextLastId == null ||
            nextLastId.isEmpty ||
            nextLastId.startsWith('temp_');

        final bool isStrictlyNewerDate = nextLastDate != null &&
            (prevLastDate == null || nextLastDate.isAfter(prevLastDate));

        final bool isUnseenNewId = nextLastId != null &&
            nextLastId.isNotEmpty &&
            !prevMessageIds.contains(nextLastId) &&
            (nextLastDate == null || prevLastDate == null || !nextLastDate.isBefore(prevLastDate));

        final bool isPollNewVote = lastMsg['type'] == 'poll' && isStrictlyNewerDate;

        final bool hasNewActivity = isOptimisticNew ||
            isPollNewVote ||
            (!isSameMessageId && (isStrictlyNewerDate || isUnseenNewId));

        final preview = _formatMessagePreview(
          msg: lastMsg,
          isGroup: isGroup,
          fallbackSenderName: _currentUserName ?? l10n.you,
        );
        final displayLastMsg = preview.isNotEmpty ? preview : (lastMsg['text']?.toString() ?? '');

        final String? resolvedId = (targetId != null && targetId.isNotEmpty)
            ? targetId
            : lastMsg['conversationId']?.toString();
        final currentIdx = _chats.indexWhere((c) {
          final cid = c['id']?.toString();
          if (resolvedId != null && resolvedId.isNotEmpty && cid == resolvedId) {
            return true;
          }
          if (!isGroup &&
              receiverId != null &&
              receiverId.isNotEmpty &&
              c['otherUserId']?.toString() == receiverId) {
            return true;
          }
          return false;
        });
        final targetChat = currentIdx != -1 ? _chats[currentIdx] : existingChat;

        if (targetChat != null) {
          targetChat['messages'] = trimmedResult;
          targetChat['hasMoreMessages'] =
              result.length > _maxCachedMessages || (targetChat['hasMoreMessages'] == true);
          targetChat['unread'] = 0;

          final DateTime? currentChatDate = _tryParseChatDate(targetChat['lastMessageDate']);
          final bool updatedInBackgroundWithNewer = currentChatDate != null &&
              prevLastDate != null &&
              currentChatDate.isAfter(prevLastDate) &&
              (nextLastDate == null || nextLastDate.isBefore(currentChatDate));

          if (!updatedInBackgroundWithNewer) {
            targetChat['lastMessage'] = displayLastMsg;
            targetChat['lastMessageData'] = lastMsg;
            if (lastMsg['createdAt'] != null) {
              targetChat['lastMessageDate'] = lastMsg['createdAt'];
            }
            final lastTimeStr = lastMsg['time']?.toString() ?? '';
            if (lastTimeStr.isNotEmpty) {
              targetChat['time'] = lastTimeStr;
            }
          }

          if (hasNewActivity) {
            _sortChatsByLatest();
          }
        } else {
          _chats.add({
            'id': resolvedId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'name': friendName,
            'avatar': friend['avatar'],
            'color': _parseColor(friend['color'], friendName),
            'lastMessage': displayLastMsg,
            'lastMessageData': lastMsg,
            'lastMessageDate': lastMsg['createdAt'],
            'time': lastMsg['time']?.toString() ?? '',
            'unread': 0,
            'online': isOnline,
            'showActiveStatus': showActiveStatus,
            'isFriend': isFriend,
            'isBlocked': isBlocked,
            'isGroup': isGroup,
            if (!isGroup && receiverId != null) 'otherUserId': receiverId,
            'messages': trimmedResult,
            'hasMoreMessages': result.length > _maxCachedMessages,
          });
          _sortChatsByLatest();
        }
      });
    }
  }

  Future<void> _openStatusScreen() async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => StatusScreen(
          currentNote: _currentUserNote,
          userAvatar: _currentUserAvatar,
          userName: _currentUserName ?? _currentUserEmail?.split('@')[0] ?? l10n.you,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentUserNote = result.trim().isEmpty ? null : result.trim();
      });
      if (_currentUserNote != null) {
        await SessionService.saveUserNote(_currentUserNote!);
      } else {
        await SessionService.clearUserNote();
      }
    }
  }

  void _onTapCurrentUserNote() {
    final hasNote = _currentUserNote != null && _currentUserNote!.trim().isNotEmpty;
    if (hasNote) {
      UserNoteOptionsSheet.show(
        context: context,
        note: _currentUserNote!,
        userAvatar: _currentUserAvatar,
        userName: _currentUserName ?? _currentUserEmail?.split('@')[0] ?? l10n.you,
        onEditNote: _openStatusScreen,
        onDeleteNote: _deleteCurrentUserNote,
      );
    } else {
      _openStatusScreen();
    }
  }

  Future<void> _deleteCurrentUserNote() async {
    final userId = await SessionService.getUserId();
    await ProfileService.updateNote('');
    if (userId != null && userId.isNotEmpty) {
      SocketService.sendUpdateNote(userId: userId, note: '');
    }
    await SessionService.clearUserNote();
    if (mounted) {
      setState(() {
        _currentUserNote = null;
      });
      AppToast.success(context, l10n.noteDeletedToast);
    }
  }

  void _showFriendNoteViewer(Map<String, dynamic> friend) {
    FriendNoteViewerScreen.open(
      context: context,
      friend: friend,
      onOpenChat: () => _openChatWithFriend(friend),
      onSendReply: (replyText) async {
        return await _sendReplyToFriend(friend, replyText);
      },
    );
  }

  Future<bool> _sendReplyToFriend(Map<String, dynamic> friend, String text) async {
    final friendName = (friend['name'] ?? '').toString();
    final friendId = (friend['id'] ?? friend['otherUserId'] ?? '').toString();
    final convId = friend['conversationId']?.toString();

    Map<String, dynamic>? existingChat;
    try {
      existingChat = _chats.firstWhere(
        (c) =>
            (convId != null && convId.isNotEmpty && c['id'] == convId) ||
            (friendId.isNotEmpty && (c['id'] == friendId || c['otherUserId'] == friendId)) ||
            (c['name'] != null && c['name'].toString().toLowerCase() == friendName.toLowerCase()),
      );
    } catch (_) {
      existingChat = null;
    }

    final isGroup = friend['isGroup'] == true || (existingChat != null && existingChat['isGroup'] == true);
    final conversationId = existingChat != null ? existingChat['id']?.toString() : convId;
    final receiverId = isGroup ? null : (friend['otherUserId']?.toString() ?? (friendId != conversationId ? friendId : null));

    final res = await MessageService.sendMessage(
      content: text,
      conversationId: conversationId,
      receiverId: conversationId != null ? null : receiverId,
    );

    if (res != null) {
      MessagesScreen.triggerRefresh();
      _fetchDataFromBackend();
      return true;
    }
    return false;
  }

  Widget _buildOnlineFriendsBar(BuildContext context) {
    final hasNote = _currentUserNote != null && _currentUserNote!.trim().isNotEmpty;

    return Container(
      height: 116.h,
      margin: EdgeInsets.only(bottom: 6.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        itemCount: 1 + _onlineFriends.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _onTapCurrentUserNote,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.only(right: 14.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 7.h),
                          child: Container(
                            constraints: BoxConstraints(maxWidth: 84.w, minHeight: 28.h),
                            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: hasNote
                                    ? AppColors.blue.withValues(alpha: 0.6)
                                    : context.borderTheme,
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              hasNote ? _currentUserNote! : l10n.whatAreYouThinking,
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                fontWeight: hasNote ? FontWeight.bold : FontWeight.w500,
                                color: hasNote ? context.textPrimary : context.textMuted,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 3.5.h,
                          child: Container(
                            width: 5.5.r,
                            height: 5.5.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.cardBg,
                              border: Border.all(
                                color: hasNote
                                    ? AppColors.blue.withValues(alpha: 0.6)
                                    : context.borderTheme,
                                width: 0.9,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0.5.h,
                          child: Container(
                            width: 3.5.r,
                            height: 3.5.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.cardBg,
                              border: Border.all(
                                color: hasNote
                                    ? AppColors.blue.withValues(alpha: 0.6)
                                    : context.borderTheme,
                                width: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),

                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AppAvatar(
                          avatar: _currentUserAvatar,
                          name: _currentUserName ?? _currentUserEmail ?? l10n.you,
                          radius: 26.r,
                          fontSize: 16.sp,
                          onTap: _onTapCurrentUserNote,
                        ),
                        if (!hasNote)
                          Positioned(
                            right: -1.w,
                            bottom: -1.h,
                            child: Container(
                              width: 17.r,
                              height: 17.r,
                              decoration: BoxDecoration(
                                color: AppColors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: context.scaffoldBg, width: 2),
                              ),
                              child: Icon(
                                Icons.add,
                                size: 10.r,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    SizedBox(
                      width: 76.w,
                      child: Text(
                        l10n.yourNote,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final friend = _onlineFriends[index - 1];
          final fullName = (friend['name'] ?? '').toString();
          final displayName = fullName.isNotEmpty ? fullName.split(' ')[0] : l10n.you;
          final friendNote = (friend['note'] ?? '').toString().trim();
          final hasFriendNote = friendNote.isNotEmpty;

          return GestureDetector(
            onTap: () {
              if (hasFriendNote) {
                _showFriendNoteViewer(friend);
              } else {
                _openChatWithFriend(friend);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: EdgeInsets.only(right: 14.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasFriendNote)
                    GestureDetector(
                      onTap: () => _showFriendNoteViewer(friend),
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 7.h),
                            child: Container(
                              constraints: BoxConstraints(maxWidth: 84.w, minHeight: 28.h),
                              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: context.cardBg,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: AppColors.blue.withValues(alpha: 0.6),
                                  width: 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                friendNote,
                                style: TextStyle(
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 3.5.h,
                            child: Container(
                              width: 5.5.r,
                              height: 5.5.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.cardBg,
                                border: Border.all(
                                  color: AppColors.blue.withValues(alpha: 0.6),
                                  width: 0.9,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0.5.h,
                            child: Container(
                              width: 3.5.r,
                              height: 3.5.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.cardBg,
                                border: Border.all(
                                  color: AppColors.blue.withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(height: 37.h),
                  SizedBox(height: 2.h),
                  AppAvatar(
                    avatar: friend['avatar'],
                    name: fullName,
                    color: friend['color'] as Color?,
                    radius: 26.r,
                    fontSize: 16.sp,
                    isOnline: true,
                    enableViewer: false,
                    onTap: () {
                      if (hasFriendNote) {
                        _showFriendNoteViewer(friend);
                      } else {
                        _openChatWithFriend(friend);
                      }
                    },
                  ),
                  SizedBox(height: 4.h),
                  SizedBox(
                    width: 56.w,
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final filteredChats = _chats.where((chat) {
      final name = chat['name'].toString().toLowerCase();
      final msg = _formatChatSubtitle(chat).toLowerCase();
      final rawMsg = chat['lastMessage'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase().trim();
      return query.isEmpty || name.contains(query) || msg.contains(query) || rawMsg.contains(query);
    }).toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            l10n.messages,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24.sp,
              color: context.textPrimary,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.blue,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadInitialData,
                color: AppColors.blue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: l10n.searchChats,
                          hintStyle: TextStyle(color: context.textMuted, fontSize: 14.sp),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey, size: 22.r),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded, color: Colors.grey, size: 20.r),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = "";
                                    });
                                  },
                                )
                              : null,
                          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                          fillColor: context.isDark
                              ? const Color(0xFF1E1E2C)
                              : Colors.grey.withValues(alpha: 0.1),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide(
                              color: context.isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide(
                              color: context.isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _buildOnlineFriendsBar(context),
                    ),

                    Expanded(
                      child: filteredChats.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 54.r, color: Colors.grey),
                                  SizedBox(height: 12.h),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? l10n.noMessagesFound
                                        : l10n.noMessagesYetChatFriend,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.textMuted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.only(left: 14.w, right: 14.w, top: 4.h, bottom: 110.h),
                              itemCount: filteredChats.length,
                              itemBuilder: (context, index) {
                                final chat = filteredChats[index];
                                final int unreadCount = (chat['unread'] is int)
                                    ? chat['unread'] as int
                                    : (int.tryParse(chat['unread']?.toString() ?? '') ?? 0);
                                final bool isUnread = unreadCount > 0;
                                final bool isFriend = chat['isFriend'] == true;
                                final bool isBlocked = chat['isBlocked'] == true;
                                final bool showActiveStatus = chat['showActiveStatus'] != false;
                                final bool isOnline = chat['online'] == true;
                                final bool isDark = Theme.of(context).brightness == Brightness.dark;

                                return Container(
                                  margin: EdgeInsets.only(bottom: 8.h),
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: context.cardBg,
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: ListTile(
                                    onTap: () => _openChatWithFriend(chat),
                                    onLongPress: () => _showChatOptionsBottomSheet(chat),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                    leading: AppAvatar(
                                      avatar: chat['avatar'],
                                      name: chat['name'],
                                      color: chat['color'] as Color?,
                                      radius: 24.r,
                                      isOnline: (chat['isGroup'] == true || !isFriend || isBlocked || !showActiveStatus)
                                          ? null
                                          : isOnline,
                                      onTap: () => _openChatWithFriend(chat),
                                    ),
                                    title: Text(
                                      chat['name'],
                                      style: TextStyle(
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 15.sp,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _formatChatSubtitle(chat),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _isMissedCallSubtitle(chat)
                                            ? AppColors.red
                                            : (isUnread
                                                ? (isDark ? Colors.white : Colors.black87)
                                                : context.textMuted),
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13.sp,
                                      ),
                                    ),
                                    trailing: SizedBox(
                                      width: 72.w,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (chat['isMuted'] == true) ...[
                                                Icon(
                                                  Icons.notifications_off_rounded,
                                                  size: 13.r,
                                                  color: context.textMuted,
                                                ),
                                                SizedBox(width: 3.w),
                                              ],
                                              Text(
                                                _formatChatTime(chat),
                                                style: TextStyle(
                                                  color: isUnread ? AppColors.blue : context.textMuted,
                                                  fontSize: 11.sp,
                                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (isUnread) ...[
                                            SizedBox(height: 4.h),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                              constraints: BoxConstraints(minWidth: 18.r, minHeight: 18.r),
                                              decoration: BoxDecoration(
                                                color: AppColors.blue,
                                                borderRadius: BorderRadius.circular(10.r),
                                              ),
                                              child: Text(
                                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
  void _showChatOptionsBottomSheet(Map<String, dynamic> chat) {
    HapticFeedback.mediumImpact();
    final l10n = context.l10n;
    final isEn = LanguageManager.isEnglish();
    final isMuted = chat['isMuted'] == true;
    final String chatName = (chat['name'] ?? '').toString();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: context.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  child: Row(
                    children: [
                      AppAvatar(
                        avatar: chat['avatar'],
                        name: chatName,
                        color: chat['color'] as Color?,
                        radius: 22.r,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          chatName,
                          style: TextStyle(
                            fontSize: 16.sp,
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
                SizedBox(height: 12.h),
                Divider(color: context.textMuted.withValues(alpha: 0.15), height: 1),
                SizedBox(height: 8.h),
                _buildBottomSheetActionTile(
                  icon: isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                  title: isMuted ? (isEn ? 'Unmute' : 'Bật thông báo') : l10n.muteNotifications,
                  iconColor: isMuted ? Colors.orangeAccent : null,
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _toggleChatMuteStatus(chat);
                  },
                ),
                _buildBottomSheetActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: isEn ? 'Delete conversation' : 'Xóa cuộc trò chuyện',
                  iconColor: AppColors.red,
                  textColor: AppColors.red,
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _confirmDeleteConversation(chat);
                  },
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22.r,
                color: iconColor ?? context.textPrimary,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w500,
                    color: textColor ?? context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteConversation(Map<String, dynamic> chat) {
    final l10n = context.l10n;
    final isEn = LanguageManager.isEnglish();
    final String chatName = (chat['name'] ?? '').toString();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 22.r),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                isEn ? 'Delete conversation?' : 'Xóa cuộc trò chuyện?',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isEn
              ? 'Are you sure you want to delete the conversation with  This will delete the entire chat history on your side.'
              : 'Bạn có chắc chắn muốn xóa cuộc trò chuyện với  Hành động này sẽ xóa toàn bộ nội dung cuộc trò chuyện ở phía bạn.',
          style: TextStyle(
            fontSize: 13.5.sp,
            color: context.textMuted,
            height: 1.4,
          ),
        ),
        actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                fontSize: 14.5.sp,
                fontWeight: FontWeight.w600,
                color: context.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              await _deleteConversation(chat);
            },
            child: Text(
              l10n.delete,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteConversation(Map<String, dynamic> chat) async {
    final convId = chat['id']?.toString() ?? '';
    final receiverId = chat['receiverId']?.toString() ?? chat['otherUserId']?.toString();
    if (convId.isEmpty && (receiverId == null || receiverId.isEmpty)) return;

    setState(() {
      _chats.removeWhere((c) => c['id']?.toString() == convId);
    });

    try {
      final res = await MessageService.deleteConversation(
        conversationId: convId.isNotEmpty ? convId : null,
        receiverId: receiverId,
      );
      if (res != null && res['success'] == true) {
        if (mounted) {
          AppToast.success(context, context.l10n.chatHistoryClearedToast);
        }
      }
    } catch (e) {
      debugPrint('Error deleting conversation: ');
    }
  }

  void _toggleChatMuteStatus(Map<String, dynamic> chat) {
    final convId = chat['id']?.toString() ?? '';
    final receiverId = chat['receiverId']?.toString() ?? chat['otherUserId']?.toString();
    final bool isMuted = chat['isMuted'] == true;

    if (isMuted) {
      setState(() {
        chat['isMuted'] = false;
        chat['mutedUntil'] = null;
      });
      MessageService.unmuteConversation(
        conversationId: convId.isNotEmpty ? convId : null,
        receiverId: receiverId,
      );
      AppToast.success(context, context.l10n.unmutedToast);
    } else {
      _showMuteDialogForChat(chat);
    }
  }

  void _showMuteDialogForChat(Map<String, dynamic> chat) {
    final l10n = context.l10n;
    final convId = chat['id']?.toString() ?? '';
    final receiverId = chat['receiverId']?.toString() ?? chat['otherUserId']?.toString();
    int selectedDuration = 15;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final options = [
            {'title': l10n.in15Minutes, 'duration': 15},
            {'title': l10n.in1Hour, 'duration': 60},
            {'title': l10n.in8Hours, 'duration': 480},
            {'title': l10n.in24Hours, 'duration': 1440},
            {'title': l10n.untilITurnBackOn, 'duration': -1},
          ];

          return AlertDialog(
            backgroundColor: context.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
            titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
            contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_off_rounded, color: Colors.orangeAccent, size: 20.r),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    l10n.muteNotifications,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((opt) {
                final duration = opt['duration'] as int;
                final isSelected = selectedDuration == duration;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: () {
                      setDialogState(() {
                        selectedDuration = duration;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? AppColors.blue : context.textMuted,
                            size: 20.r,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              opt['title'] as String,
                              style: TextStyle(
                                fontSize: 14.5.sp,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? context.textPrimary : context.textPrimary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                onPressed: () async {
                  Navigator.pop(dlgCtx);
                  setState(() {
                    chat['isMuted'] = true;
                  });
                  final res = await MessageService.muteConversation(
                    conversationId: convId.isNotEmpty ? convId : null,
                    receiverId: receiverId,
                    durationMinutes: selectedDuration,
                  );
                  if (res != null && res['success'] == true && mounted) {
                    setState(() {
                      chat['isMuted'] = true;
                      chat['mutedUntil'] = res['mutedUntil'];
                    });
                    AppToast.success(context, l10n.mutedToast);
                  }
                },
                child: Text(
                  l10n.muteBtn,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
