import '../../../services/socket_service.dart';
import 'package:flutter/foundation.dart';
import '../../../services/message_service.dart';
import '../../../services/session_service.dart';

class ChatPollController {
  final List<Map<String, dynamic>> Function() getMessages;
  final String? Function() getCurrentUserId;
  final String? Function() getCurrentUsername;
  final String? Function() getCurrentUserAvatar;
  final String? Function() getActiveConversationId;
  final List<Map<String, dynamic>> Function() getGroupMembers;
  final String Function() getDefaultOtherName;
  final String Function() getDefaultOtherAvatar;
  final VoidCallback onStateChanged;
  final Function({bool animated}) onScrollToBottom;
  final VoidCallback onClearMessageKeys;

  ChatPollController({
    required this.getMessages,
    required this.getCurrentUserId,
    required this.getCurrentUsername,
    required this.getCurrentUserAvatar,
    required this.getActiveConversationId,
    required this.getGroupMembers,
    required this.getDefaultOtherName,
    required this.getDefaultOtherAvatar,
    required this.onStateChanged,
    required this.onScrollToBottom,
    required this.onClearMessageKeys,
  });

  Future<void> sendPoll(Map<String, dynamic> pollData) async {
    final messages = getMessages();
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final timeString = "$hour12:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
    final tempId = 'temp_${now.millisecondsSinceEpoch}';

    final rawOptions = pollData['options'] as List? ?? [];
    final formattedPoll = {
      'question': pollData['question'] ?? '',
      'multipleAnswers': pollData['multipleAnswers'] == true,
      'isClosed': false,
      'totalVotes': 0,
      'options': rawOptions.map((opt) {
        if (opt is Map) {
          return {
            'id': opt['id']?.toString() ?? '',
            'text': opt['text']?.toString() ?? '',
            'voterIds': <String>[],
            'voteCount': 0,
          };
        }
        return {
          'id': opt.toString(),
          'text': opt.toString(),
          'voterIds': <String>[],
          'voteCount': 0,
        };
      }).toList(),
    };

    final newMsg = <String, dynamic>{
      'id': tempId,
      'text': pollData['question'],
      'type': 'poll',
      'poll': formattedPoll,
      'isMe': true,
      'time': timeString,
      'createdAt': now.toIso8601String(),
      'seenBy': [],
    };

    messages.add(newMsg);
    onStateChanged();
    onScrollToBottom(animated: false);

    try {
      final currentConvId = getActiveConversationId();
      final res = await MessageService.sendMessage(
        content: pollData['question'] ?? '',
        conversationId: currentConvId,
        type: 'poll',
        poll: pollData,
      );

      if (res != null) {
        final idx = messages.indexWhere((m) => m['id'] == tempId);
        if (idx != -1) {
          messages[idx]['id'] = res['id'] ?? tempId;
          if (res['createdAt'] != null) {
            messages[idx]['createdAt'] = res['createdAt'];
          }
          if (res['time'] != null) {
            messages[idx]['time'] = res['time'];
          }
          if (res['poll'] != null) {
            messages[idx]['poll'] = res['poll'];
          }
          onStateChanged();
        }
      }
    } catch (e) {
      debugPrint('Error sending poll: $e');
    }
  }

  Future<void> votePoll(String messageId, String optionId) async {
    final messages = getMessages();
    String myId = getCurrentUserId() ?? '';
    if (myId.isEmpty) {
      myId = await SessionService.getUserId() ?? SocketService.currentUserId ?? '';
    }
    final idx = messages.indexWhere((m) => (m['id'] ?? m['_id'])?.toString() == messageId);

    if (idx != -1) {
      final poll = Map<String, dynamic>.from(messages[idx]['poll'] ?? {});
      final rawOptions = poll['options'] as List? ?? [];
      final options = rawOptions.map((o) => Map<String, dynamic>.from(o is Map ? o : {})).toList();
      final targetIdx = options.indexWhere((o) => o['id']?.toString() == optionId);

      if (targetIdx != -1) {
        final target = options[targetIdx];
        final Set<String> targetVoterIds = {};
        if (target['voterIds'] is List) {
          for (var v in target['voterIds']) {
            final id = (v is Map ? (v['id'] ?? v['_id']) : v)?.toString();
            if (id != null && id.isNotEmpty) targetVoterIds.add(id);
          }
        }
        if (target['voters'] is List) {
          for (var v in target['voters']) {
            final id = (v is Map ? (v['id'] ?? v['_id']) : v)?.toString();
            if (id != null && id.isNotEmpty) targetVoterIds.add(id);
          }
        }

        final bool alreadyVoted = myId.isNotEmpty && targetVoterIds.contains(myId);
        final bool hadVotedBefore = options.any((o) {
          final Set<String> optVoters = {};
          if (o['voterIds'] is List) {
            for (var v in o['voterIds']) {
              final id = (v is Map ? (v['id'] ?? v['_id']) : v)?.toString();
              if (id != null && id.isNotEmpty) optVoters.add(id);
            }
          }
          if (o['voters'] is List) {
            for (var v in o['voters']) {
              final id = (v is Map ? (v['id'] ?? v['_id']) : v)?.toString();
              if (id != null && id.isNotEmpty) optVoters.add(id);
            }
          }
          return myId.isNotEmpty && optVoters.contains(myId);
        });
        final bool isMultiple = poll['multipleAnswers'] == true;

        String action = 'voted';
        final rawVotersList = (target['voters'] is List)
            ? List<Map<String, dynamic>>.from((target['voters'] as List).map((e) => Map<String, dynamic>.from(e is Map ? e : {})))
            : <Map<String, dynamic>>[];

        if (alreadyVoted) {
          action = 'unvoted';
          targetVoterIds.remove(myId);
          target['voterIds'] = targetVoterIds.toList();
          target['voteCount'] = targetVoterIds.length;
          rawVotersList.removeWhere((v) => (v['id'] ?? v['_id'])?.toString() == myId);
        } else {
          action = hadVotedBefore ? 'changed' : 'voted';
          if (!isMultiple) {
            for (var opt in options) {
              final Set<String> vIds = {};
              if (opt['voterIds'] is List) {
                for (var v in opt['voterIds']) {
                  final id = (v is Map ? (v['id'] ?? v['_id']) : v)?.toString();
                  if (id != null && id.isNotEmpty) vIds.add(id);
                }
              }
              vIds.remove(myId);
              opt['voterIds'] = vIds.toList();
              opt['voteCount'] = vIds.length;
              if (opt['voters'] is List) {
                final vList = List<Map<String, dynamic>>.from((opt['voters'] as List).map((e) => Map<String, dynamic>.from(e is Map ? e : {})));
                vList.removeWhere((v) => (v['id'] ?? v['_id'])?.toString() == myId);
                opt['voters'] = vList;
              }
            }
          }
          if (myId.isNotEmpty) targetVoterIds.add(myId);
          target['voterIds'] = targetVoterIds.toList();
          target['voteCount'] = targetVoterIds.length;
          rawVotersList.removeWhere((v) => (v['id'] ?? v['_id'])?.toString() == myId);
          rawVotersList.add({
            'id': myId,
            'username': getCurrentUsername() ?? '',
            'avatar': getCurrentUserAvatar() ?? '',
          });
        }
        target['voters'] = rawVotersList;

        options[targetIdx] = target;
        poll['options'] = options;
        poll['totalVotes'] = options.fold<int>(0, (sum, o) => sum + ((o['voterIds'] as List?)?.length ?? (o['voteCount'] as int? ?? 0)));
        final now = DateTime.now();
        poll['lastVote'] = {
          'voterId': myId,
          'voterName': getCurrentUsername() ?? '',
          'voterAvatar': getCurrentUserAvatar() ?? '',
          'action': action,
          'optionId': optionId,
          'optionText': (target['text'] ?? '').toString().trim(),
          'updatedAt': now.toIso8601String(),
        };

        final pollMsg = Map<String, dynamic>.from(messages[idx]);
        pollMsg['poll'] = poll;
        pollMsg['createdAt'] = now.toIso8601String();
        messages[idx] = pollMsg;
        onStateChanged();
      }
    }

    try {
      final res = await MessageService.votePoll(messageId: messageId, optionId: optionId, userId: myId);
      if (res != null) {
        final mIdx = messages.indexWhere((m) => (m['id'] ?? m['_id'])?.toString() == messageId);
        if (mIdx != -1) {
          final pollMsg = Map<String, dynamic>.from(messages[mIdx]);
          if (res['poll'] != null) {
            pollMsg['poll'] = res['poll'];
          }
          if (res['createdAt'] != null) {
            pollMsg['createdAt'] = res['createdAt'];
          }
          if (res['time'] != null) {
            pollMsg['time'] = res['time'];
          }
          if (mIdx != messages.length - 1) {
            messages.removeAt(mIdx);
            messages.add(pollMsg);
            onClearMessageKeys();
            onScrollToBottom(animated: true);
          } else {
            messages[mIdx] = pollMsg;
          }
          onStateChanged();
        }
      }
    } catch (e) {
      debugPrint('Error voting poll: $e');
    }
  }

  void handlePollUpdated(Map<String, dynamic> data) {
    final msgId = data['messageId']?.toString();
    final convId = data['conversationId']?.toString();
    final activeId = getActiveConversationId();
    if (activeId != null && convId != null && convId != activeId) return;

    final poll = data['poll'];
    if (poll is Map) {
      final messages = getMessages();
      final idx = messages.indexWhere((m) => (m['id'] ?? m['_id'])?.toString() == msgId);
      if (idx != -1) {
        final pollMsg = Map<String, dynamic>.from(messages[idx]);
        pollMsg['poll'] = Map<String, dynamic>.from(poll);
        if (data['createdAt'] != null) {
          pollMsg['createdAt'] = data['createdAt'];
        }
        if (data['time'] != null) {
          pollMsg['time'] = data['time'];
        }
        if (idx != messages.length - 1) {
          messages.removeAt(idx);
          messages.add(pollMsg);
          onClearMessageKeys();
          onScrollToBottom(animated: true);
        } else {
          messages[idx] = pollMsg;
        }
        onStateChanged();
      }
    }
  }

  List<Map<String, dynamic>> resolveVotersForOption(Map<String, dynamic> opt) {
    final rawVoters = opt['voters'] as List? ?? [];
    final voterIds = (opt['voterIds'] is List)
        ? (opt['voterIds'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final Map<String, Map<String, dynamic>> voterMap = {};

    for (var v in rawVoters) {
      if (v is Map) {
        final id = (v['id'] ?? v['_id'])?.toString() ?? '';
        final username = (v['username'] ?? v['name'])?.toString() ?? '';
        final avatar = (v['avatar'] ?? '').toString();
        if (id.isNotEmpty) {
          voterMap[id] = {
            'id': id,
            'username': username,
            'avatar': avatar,
          };
        }
      }
    }

    for (var id in voterIds) {
      if (id.isEmpty) continue;
      if (!voterMap.containsKey(id)) {
        voterMap[id] = {
          'id': id,
          'username': '',
          'avatar': '',
        };
      }
    }

    final currentUserId = getCurrentUserId();
    final resolvedList = <Map<String, dynamic>>[];
    for (var entry in voterMap.entries) {
      final id = entry.key;
      String name = entry.value['username'] ?? '';
      String avatar = entry.value['avatar'] ?? '';

      if (id == currentUserId) {
        if (name.isEmpty) name = getCurrentUsername() ?? '';
        if (avatar.isEmpty) avatar = getCurrentUserAvatar() ?? '';
      }

      if (name.isEmpty || avatar.isEmpty) {
        for (var m in getGroupMembers()) {
          final mId = (m['id'] ?? m['_id'] ?? (m['user'] is Map ? m['user']['_id'] : m['user']))?.toString();
          if (mId == id) {
            if (name.isEmpty) name = (m['name'] ?? m['username'] ?? (m['user'] is Map ? m['user']['username'] : ''))?.toString() ?? '';
            if (avatar.isEmpty) avatar = (m['avatar'] ?? (m['user'] is Map ? m['user']['avatar'] : ''))?.toString() ?? '';
            break;
          }
        }
      }

      if (name.isEmpty && id != currentUserId) {
        name = getDefaultOtherName();
        if (avatar.isEmpty) avatar = getDefaultOtherAvatar();
      }

      if (name.isEmpty) {
        name = id == currentUserId ? 'Bạn' : 'Thành viên';
      }

      resolvedList.add({
        'id': id,
        'username': name,
        'avatar': avatar,
      });
    }

    return resolvedList;
  }
}

