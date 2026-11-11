const crypto = require('crypto');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { RtcTokenBuilder, RtcRole } = require('agora-token');
const Call = require('../models/call.model');
const Account = require('../models/account.model');
const Conversation = require('../models/conversation.model');
const Message = require('../models/message.model');
const Group = require('../models/group.model');
const { verifyToken } = require('../config/jwt.config');
const socketModule = require('../socket');
const { getIO } = socketModule;
const { sendDataPushNotification } = require('../services/fcm.service');

const hasActiveUserSocket = (userId) => {
  try {
    if (typeof socketModule.hasActiveSocket === 'function') {
      return socketModule.hasActiveSocket(userId);
    }
  } catch (_) {}
  return false;
};

const callMsgMutexMap = new Map();
const withCallMessageLock = async (callKey, fn) => {
  const key = (callKey || '').toString();
  const prev = callMsgMutexMap.get(key) || Promise.resolve();
  let resolveRelease;
  const gate = new Promise((r) => {
    resolveRelease = r;
  });
  const chained = prev.then(() => gate, () => gate);
  callMsgMutexMap.set(key, chained);
  try {
    await prev;
    return await fn();
  } finally {
    resolveRelease();
    if (callMsgMutexMap.get(key) === chained) {
      callMsgMutexMap.delete(key);
    }
  }
};

const getUserIdFromReq = async (req) => {
  if (req.user && (req.user.id || req.user._id || req.user.userId)) {
    return (req.user.id || req.user._id || req.user.userId).toString();
  }

  if (req.headers && req.headers.authorization) {
    try {
      const token = req.headers.authorization.replace('Bearer ', '').trim();
      let decoded = null;
      try {
        decoded = verifyToken(token);
      } catch (_) {
        decoded = jwt.decode(token);
      }
      if (decoded) {
        if (decoded.id || decoded.userId || decoded._id) {
          return (decoded.id || decoded.userId || decoded._id).toString();
        }
        if (decoded.email) {
          const acc = await Account.findOne({ email: decoded.email, isDeleted: false }).select('_id').lean();
          if (acc) return acc._id.toString();
        }
      }
    } catch (_) {}
  }

  const candidateId =
    (req.body && (req.body.userId || req.body.myUserId)) ||
    (req.query && (req.query.userId || req.query.myUserId));
  if (candidateId) {
    const trimmed = candidateId.toString().trim();
    if (mongoose.Types.ObjectId.isValid(trimmed)) {
      return trimmed;
    }
  }

  return null;
};

const generateAgoraToken = (channelName, uid = 0, role = RtcRole.PUBLISHER) => {
  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;
  if (!appId || !appCertificate) {
    throw new Error('AGORA_APP_ID or AGORA_APP_CERTIFICATE not configured');
  }
  const expirationTimeInSeconds = 3600 * 6;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  return RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    uid,
    role,
    privilegeExpiredTs,
    privilegeExpiredTs
  );
};

const userIdToAgoraUid = (userId) => {
  if (!userId) return 0;
  const hex = userId.toString().replace(/[^0-9a-fA-F]/g, '');
  if (hex.length < 8) return 0;
  const tail = hex.slice(-8);
  const parsed = parseInt(tail, 16) & 0x7fffffff;
  return parsed > 0 ? parsed : 1;
};

const computeGroupInitials = (name) => {
  const clean = (name || '').toString().trim();
  if (!clean) return 'GR';
  const parts = clean.split(/\s+/);
  if (parts.length >= 2 && parts[0][0] && parts[parts.length - 1][0]) {
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
  return clean.length >= 2 ? clean.substring(0, 2).toUpperCase() : clean.toUpperCase();
};

const resolveGroupDisplayInfo = async (conversationDoc) => {
  if (!conversationDoc) {
    return { groupName: '', groupAvatar: '' };
  }
  let communityGroupDoc = null;
  if (conversationDoc.communityGroup) {
    if (typeof conversationDoc.communityGroup === 'object' && conversationDoc.communityGroup.name) {
      communityGroupDoc = conversationDoc.communityGroup;
    } else if (mongoose.Types.ObjectId.isValid(conversationDoc.communityGroup)) {
      communityGroupDoc = await Group.findById(conversationDoc.communityGroup)
        .select('name avatar')
        .lean()
        .catch(() => null);
    }
  }
  const groupName = (conversationDoc.name || communityGroupDoc?.name || 'Chat Group').toString().trim();
  const rawAvatar = (conversationDoc.avatar || communityGroupDoc?.avatar || '').toString().trim();
  const groupAvatar = rawAvatar || computeGroupInitials(groupName);
  return { groupName, groupAvatar };
};

const formatParticipantProfiles = (userDocs) => {
  if (!Array.isArray(userDocs)) return [];
  const seen = new Set();
  const result = [];
  for (const doc of userDocs) {
    if (!doc) continue;
    const id = (doc._id || doc.id || doc).toString();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    result.push({
      userId: id,
      name: (doc.username || doc.name || 'Viora User').toString(),
      avatar: (doc.avatar || '').toString(),
      agoraUid: userIdToAgoraUid(id),
    });
  }
  return result;
};

const hasId = (arr, id) => {
  if (!Array.isArray(arr) || !id) return false;
  const str = id.toString();
  return arr.some((item) => item && item.toString() === str);
};

const isBlockedBetween = (userA, userB) => {
  if (!userA || !userB) return false;
  const aId = userA._id.toString();
  const bId = userB._id.toString();
  return (
    hasId(userA.blockedUsers, bId) ||
    hasId(userA.blockedFriends, bId) ||
    hasId(userB.blockedUsers, aId) ||
    hasId(userB.blockedFriends, aId)
  );
};

const findCallRecord = async (callId, callDocId) => {
  if (callId && typeof callId === 'string' && callId.trim().length > 0) {
    const found = await Call.findOne({ callId: callId.trim() });
    if (found) return found;
  }
  if (callDocId && mongoose.Types.ObjectId.isValid(callDocId)) {
    const found = await Call.findById(callDocId);
    if (found) return found;
  }
  if (callId && mongoose.Types.ObjectId.isValid(callId)) {
    const found = await Call.findById(callId);
    if (found) return found;
  }
  return null;
};

const emitCancelToTargets = async (call, targetIds, reason = 'cancelled') => {
  const io = getIO ? getIO() : null;
  const payload = {
    type: 'call_cancelled',
    callId: call.callId,
    callDocId: call._id.toString(),
    channelName: call.channelName,
    reason,
  };

  for (const targetId of targetIds) {
    if (!targetId) continue;
    const tid = targetId.toString();
    if (io) {
      io.to(tid).emit('call_cancelled', payload);
    }
    sendDataPushNotification({
      recipientId: tid,
      data: payload,
      ttlSeconds: 30,
    }).catch(() => {});
  }
};

const emitDeclinedToCaller = async (call, declinerId = '') => {
  const callerIdStr = call.caller ? call.caller.toString() : '';
  if (!callerIdStr || callerIdStr === declinerId.toString()) return;

  const io = getIO ? getIO() : null;
  const payload = {
    type: 'call_declined',
    callId: call.callId,
    callDocId: call._id.toString(),
    channelName: call.channelName,
    declinedBy: declinerId.toString(),
  };

  if (io) {
    io.to(callerIdStr).emit('call_declined', payload);
  }
  sendDataPushNotification({
    recipientId: callerIdStr,
    data: payload,
    ttlSeconds: 30,
  }).catch(() => {});
};

const emitEndedToTargets = async (call, targetIds, endedById = '', duration = 0) => {
  const io = getIO ? getIO() : null;
  const payload = {
    type: 'call_ended',
    callId: call.callId,
    callDocId: call._id.toString(),
    channelName: call.channelName,
    endedBy: endedById.toString(),
    duration,
  };

  for (const targetId of targetIds) {
    if (!targetId) continue;
    const tid = targetId.toString();
    if (io) {
      io.to(tid).emit('call_ended', payload);
    }
    sendDataPushNotification({
      recipientId: tid,
      data: payload,
      ttlSeconds: 30,
    }).catch(() => {});
  }
};

const formatMsgTime = (date) => {
  if (!date) return '';
  const d = new Date(date);
  const now = new Date();
  const isToday = d.toDateString() === now.toDateString();

  if (isToday) {
    const hours = d.getHours();
    const minutes = d.getMinutes() < 10 ? '0' + d.getMinutes() : d.getMinutes();
    const ampm = hours >= 12 ? 'PM' : 'AM';
    const hour12 = hours % 12 || 12;
    return `${hour12}:${minutes} ${ampm}`;
  }

  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  if (d.toDateString() === yesterday.toDateString()) {
    return 'Yesterday';
  }

  const diffDays = Math.floor((now - d) / (1000 * 60 * 60 * 24));
  if (diffDays < 7) {
    const daysEn = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return daysEn[d.getDay()];
  }

  return `${d.getDate()}/${d.getMonth() + 1}`;
};

const buildCallFallbackText = (callType, status) => {
  const isVideo = callType === 'video';
  if (status === 'ringing' || status === 'ongoing') {
    return isVideo ? 'Cuộc gọi video đang diễn ra' : 'Cuộc gọi thoại đang diễn ra';
  }
  if (status === 'completed') {
    return isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
  }
  if (status === 'declined') {
    return isVideo ? 'Cuộc gọi video đã bị từ chối' : 'Cuộc gọi thoại đã bị từ chối';
  }
  return isVideo ? 'Cuộc gọi video nhỡ' : 'Cuộc gọi nhỡ';
};

const upsertCallLogMessage = async (callDoc) => {
  if (!callDoc || !callDoc._id) return null;
  const lockKey = callDoc._id.toString();

  return await withCallMessageLock(lockKey, async () => {
    let savedMessage = null;
    try {
      const freshCall = await Call.findById(callDoc._id);
      if (!freshCall) return null;

      const isTerminal = ['completed', 'missed', 'declined', 'cancelled'].includes(freshCall.status);
      const isActiveGroup = freshCall.isGroup === true && ['ringing', 'ongoing'].includes(freshCall.status);
      if (!isTerminal && !isActiveGroup) {
        return null;
      }

      let targetConvId = freshCall.conversationId;
      let conv = null;

      if (targetConvId) {
        conv = await Conversation.findById(targetConvId);
      }

      if (!conv && !freshCall.isGroup && freshCall.caller && freshCall.receiver) {
        conv = await Conversation.findOne({
          type: 'direct',
          $and: [
            { 'members.user': freshCall.caller },
            { 'members.user': freshCall.receiver },
          ],
        });
        if (!conv) {
          conv = await Conversation.create({
            type: 'direct',
            members: [
              { user: freshCall.caller },
              { user: freshCall.receiver },
            ],
          });
        }
        targetConvId = conv._id;
      }

      if (!targetConvId || !conv) {
        return null;
      }

      const durationSec = Math.max(0, Number(freshCall.duration) || 0);
      const callType = freshCall.type === 'video' ? 'video' : 'audio';
      const fallbackText = buildCallFallbackText(callType, freshCall.status);

      const readBySet = new Set();
      if (freshCall.caller) readBySet.add(freshCall.caller.toString());
      if (freshCall.status === 'completed' || freshCall.status === 'ongoing') {
        if (freshCall.receiver) readBySet.add(freshCall.receiver.toString());
        for (const p of (freshCall.activeParticipants || [])) {
          if (p) readBySet.add(p.toString());
        }
        if (freshCall.status === 'completed') {
          for (const p of (freshCall.participants || [])) {
            if (p) readBySet.add(p.toString());
          }
        }
      } else if (freshCall.status === 'declined' && freshCall.endedBy) {
        readBySet.add(freshCall.endedBy.toString());
      }

      const readByIds = Array.from(readBySet)
        .filter((id) => mongoose.Types.ObjectId.isValid(id))
        .map((id) => new mongoose.Types.ObjectId(id));

      let existingMsg = null;
      if (freshCall.messageId && mongoose.Types.ObjectId.isValid(freshCall.messageId)) {
        existingMsg = await Message.findById(freshCall.messageId);
      }
      if (!existingMsg) {
        existingMsg = await Message.findOne({
          conversationId: targetConvId,
          type: 'call',
          $or: [
            { 'call.callDocId': freshCall._id },
            { 'call.callId': freshCall.callId },
          ],
        });
      }

      const isUpdatingExisting = !!existingMsg;

      if (existingMsg) {
        savedMessage = await Message.findByIdAndUpdate(
          existingMsg._id,
          {
            $set: {
              content: fallbackText,
              'call.callType': callType,
              'call.status': freshCall.status,
              'call.duration': durationSec,
              'call.endedBy': freshCall.endedBy || null,
            },
            ...(readByIds.length > 0 ? { $addToSet: { readBy: { $each: readByIds } } } : {}),
          },
          { new: true }
        );
      } else {
        savedMessage = await Message.create({
          conversationId: targetConvId,
          sender: freshCall.caller,
          content: fallbackText,
          type: 'call',
          call: {
            callId: freshCall.callId,
            callDocId: freshCall._id,
            callType,
            status: freshCall.status,
            duration: durationSec,
            caller: freshCall.caller,
            endedBy: freshCall.endedBy || null,
          },
          readBy: readByIds,
        });
      }

      if (!savedMessage) return null;

      await Call.findByIdAndUpdate(freshCall._id, {
        $set: {
          conversationId: targetConvId,
          messageId: savedMessage._id,
          messageCreated: true,
        },
      }).catch(() => {});

      const shouldUpdateConvLastMessage = !isUpdatingExisting ||
        !conv.lastMessage ||
        conv.lastMessage.toString() === savedMessage._id.toString();

      if (shouldUpdateConvLastMessage) {
        await Conversation.findByIdAndUpdate(targetConvId, {
          lastMessage: savedMessage._id,
          updatedAt: new Date(),
        }).catch(() => {});
      }

      await savedMessage.populate([
        { path: 'sender', select: 'username avatar' },
        { path: 'readBy', select: 'username avatar' },
      ]);

      const senderObj = savedMessage.sender && typeof savedMessage.sender === 'object' ? savedMessage.sender : null;
      const callerIdStr = senderObj ? senderObj._id.toString() : (freshCall.caller ? freshCall.caller.toString() : '');
      const senderUsername = senderObj?.username || '';

      const callData = {
        callId: freshCall.callId,
        callDocId: freshCall._id.toString(),
        callType,
        status: freshCall.status,
        duration: durationSec,
        callerId: callerIdStr,
        endedBy: freshCall.endedBy ? freshCall.endedBy.toString() : '',
      };

      const memberIdsSet = new Set(
        (conv.members || []).map((m) => (m.user?._id || m.user || '').toString()).filter(Boolean)
      );
      if (conv.communityGroup) {
        try {
          const grpFound = await Group.findById(conv.communityGroup).select('members owner').lean();
          if (grpFound) {
            if (grpFound.owner) memberIdsSet.add(grpFound.owner.toString());
            for (const gm of (grpFound.members || [])) {
              const gUid = (gm.user?._id || gm.user || '').toString();
              if (gUid) memberIdsSet.add(gUid);
            }
          }
        } catch (_) {}
      }

      const participantIds = Array.from(memberIdsSet);
      const readByStrIds = (savedMessage.readBy || []).map((r) => (r?._id || r || '').toString()).filter(Boolean);
      const seenByList = (savedMessage.readBy || [])
        .map((r) => {
          const rObj = r && typeof r === 'object' && r._id ? r : null;
          const rId = rObj ? rObj._id.toString() : (r ? r.toString() : '');
          if (!rId) return null;
          return {
            id: rId,
            name: rObj?.username || 'Member',
            avatar: rObj?.avatar || '',
          };
        })
        .filter(Boolean);
      const timeStr = formatMsgTime(savedMessage.createdAt);

      const baseMessagePayload = {
        id: savedMessage._id.toString(),
        conversationId: targetConvId.toString(),
        senderId: callerIdStr,
        senderName: senderUsername,
        senderAvatar: senderObj?.avatar || '',
        text: fallbackText,
        type: 'call',
        attachments: [],
        imageUrl: null,
        location: null,
        poll: null,
        call: callData,
        isRecalled: false,
        recipientOnlyFriends: false,
        time: timeStr,
        createdAt: savedMessage.createdAt,
        replyTo: null,
        reactions: [],
        reaction: null,
        myReaction: null,
        readBy: readByStrIds,
        seenBy: seenByList,
        participantIds,
      };

      const io = getIO ? getIO() : null;
      if (io) {
        const eventToEmit = isUpdatingExisting ? 'call_message_updated' : 'new_message';
        for (const memberId of participantIds) {
          if (!memberId) continue;
          const isMemberCaller = memberId === callerIdStr;
          io.to(memberId).emit(eventToEmit, {
            ...baseMessagePayload,
            seenBy: seenByList.filter((s) => s.id !== memberId),
            isMe: isMemberCaller,
          });
        }

        io.to(targetConvId.toString()).emit(eventToEmit, {
          ...baseMessagePayload,
          seenBy: seenByList,
          isMe: false,
        });

        if (shouldUpdateConvLastMessage) {
          const isGroupChat = conv.type === 'group_chat';
          await Promise.all(
            participantIds.map(async (memberId) => {
              if (!memberId) return;
              const isMemberMe = memberId === callerIdStr;
              const memberUnread = await Message.countDocuments({
                conversationId: targetConvId,
                sender: { $ne: memberId },
                readBy: { $ne: memberId },
                deletedBy: { $ne: memberId },
                hiddenFrom: { $ne: memberId },
              });

              const lastMessageData = {
                id: savedMessage._id.toString(),
                type: 'call',
                text: fallbackText,
                attachmentsCount: 0,
                isRecalled: false,
                location: null,
                poll: null,
                call: callData,
                isMe: isMemberMe,
                senderId: callerIdStr,
                senderName: senderUsername,
                createdAt: savedMessage.createdAt,
              };

              io.to(memberId).emit('conversation_updated', {
                conversationId: targetConvId.toString(),
                lastMessage: fallbackText,
                lastMessageData,
                lastMessageDate: savedMessage.createdAt,
                time: timeStr,
                updatedAt: new Date(),
                unread: memberUnread,
                senderId: callerIdStr,
                senderName: senderUsername,
                isGroup: isGroupChat,
              });
            })
          ).catch(() => {});
        }
      }

      return savedMessage;
    } catch (err) {
      console.error('upsertCallLogMessage error:', err);
      return null;
    }
  });
};

const createCallLogMessage = upsertCallLogMessage;

const cleanupStaleCallIfNeeded = async (call) => {
  if (!call || !call._id) return call;
  if (!['ringing', 'ongoing'].includes(call.status)) return call;

  const now = Date.now();
  const io = getIO ? getIO() : null;

  if (call.status === 'ringing') {
    const startMs = new Date(call.startedAt || call.createdAt || now).getTime();
    if (now - startMs > 45000) {
      const missedAt = new Date(startMs + 35000);
      const updated = await Call.findOneAndUpdate(
        { _id: call._id, status: 'ringing' },
        {
          $set: {
            status: 'missed',
            endedAt: missedAt,
            activeParticipants: [],
            lastActivityAt: missedAt,
          },
        },
        { new: true }
      );
      if (updated) {
        const targets = (updated.participants || [])
          .map((p) => p?.toString())
          .filter((id) => id && id !== updated.caller?.toString());
        if (io) {
          for (const tId of targets) {
            io.to(tId).emit('call_missed', {
              type: 'call_missed',
              callId: updated.callId,
              callDocId: updated._id.toString(),
            });
          }
          if (updated.caller) {
            io.to(updated.caller.toString()).emit('call_missed', {
              type: 'call_missed',
              callId: updated.callId,
              callDocId: updated._id.toString(),
            });
          }
        }
        await emitCancelToTargets(updated, targets, 'missed');
        await upsertCallLogMessage(updated);
        return updated;
      }
      return (await Call.findById(call._id)) || call;
    }
    return call;
  }

  // status === 'ongoing'
  const activeIds = (call.activeParticipants || [])
    .map((p) => p?.toString())
    .filter(Boolean);

  const lastActivityMs = new Date(
    call.lastActivityAt || call.updatedAt || call.answeredAt || call.startedAt || now
  ).getTime();

  let shouldFinalize = false;
  if (activeIds.length === 0) {
    // Only finalize when genuinely left empty (> 5s grace for legacy/migration safety)
    if (now - lastActivityMs > 5000) {
      shouldFinalize = true;
    }
  } else {
    const hasAnyOnlineSocket = activeIds.some((uid) => hasActiveUserSocket(uid));
    let hasRecentHeartbeat = (now - lastActivityMs) <= 120000;
    if (!hasRecentHeartbeat && call.participantHeartbeats && typeof call.participantHeartbeats.get === 'function') {
      for (const uid of activeIds) {
        const hb = call.participantHeartbeats.get(uid);
        if (hb && (now - new Date(hb).getTime()) <= 120000) {
          hasRecentHeartbeat = true;
          break;
        }
      }
    }
    if (!hasAnyOnlineSocket && !hasRecentHeartbeat) {
      shouldFinalize = true;
    }
  }

  if (shouldFinalize) {
    const endMs = Math.max(
      call.answeredAt ? new Date(call.answeredAt).getTime() : lastActivityMs,
      lastActivityMs
    );
    const answeredMs = call.answeredAt ? new Date(call.answeredAt).getTime() : endMs;
    const duration = Math.max(0, Math.round((endMs - answeredMs) / 1000));
    const updated = await Call.findOneAndUpdate(
      { _id: call._id, status: 'ongoing' },
      {
        $set: {
          status: 'completed',
          endedAt: new Date(endMs),
          duration,
          activeParticipants: [],
          lastActivityAt: new Date(endMs),
        },
      },
      { new: true }
    );
    if (updated) {
      const targets = (updated.participants || []).map((p) => p?.toString()).filter(Boolean);
      await emitEndedToTargets(updated, targets, '', duration);
      await upsertCallLogMessage(updated);
      return updated;
    }
    return (await Call.findById(call._id)) || call;
  }

  return call;
};

const findAndValidateActiveGroupCall = async (conversationId) => {
  if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) {
    return null;
  }
  const candidates = await Call.find({
    conversationId,
    isGroup: true,
    status: { $in: ['ringing', 'ongoing'] },
  })
    .sort({ createdAt: -1 })
    .limit(5);

  for (const c of candidates) {
    const checked = await cleanupStaleCallIfNeeded(c);
    if (checked && ['ringing', 'ongoing'].includes(checked.status)) {
      return checked;
    }
  }
  return null;
};

const startCall = async (req, res) => {
  try {
    const callerId = await getUserIdFromReq(req);
    if (!callerId) {
      return res.status(401).json({
        success: false,
        code: 'UNAUTHORIZED',
        message: 'Please sign in to place a call',
      });
    }

    const {
      receiverId: rawReceiverId,
      conversationId: rawConversationId,
      callType: rawCallType,
      isGroup: rawIsGroup,
    } = req.body || {};

    const callType = rawCallType === 'video' ? 'video' : 'audio';

    const callerDoc = await Account.findOne({ _id: callerId, isDeleted: false })
      .select('username avatar friends blockedUsers blockedFriends')
      .lean();

    if (!callerDoc) {
      return res.status(404).json({
        success: false,
        code: 'CALLER_NOT_FOUND',
        message: 'Account not found',
      });
    }

    let conversationDoc = null;
    if (rawConversationId && mongoose.Types.ObjectId.isValid(rawConversationId)) {
      conversationDoc = await Conversation.findById(rawConversationId).lean();
    }

    const isGroup = rawIsGroup === true || conversationDoc?.type === 'group_chat';
    let targetIds = [];
    let resolvedReceiverId = null;
    let participantDocs = [callerDoc];

    if (isGroup) {
      if (!conversationDoc) {
        return res.status(400).json({
          success: false,
          code: 'CONVERSATION_REQUIRED',
          message: 'Group conversation is required for group calls',
        });
      }

      const memberIds = (conversationDoc.members || [])
        .map((m) => m?.user?.toString())
        .filter((id) => id && id !== callerId);

      if (memberIds.length === 0) {
        return res.status(400).json({
          success: false,
          code: 'NO_RECIPIENTS',
          message: 'No recipients in group',
        });
      }

      const activeMembers = await Account.find({
        _id: { $in: memberIds },
        isDeleted: false,
      })
        .select('_id username avatar blockedUsers blockedFriends')
        .lean();

      const allowedMembers = activeMembers.filter((m) => !isBlockedBetween(callerDoc, m));
      targetIds = allowedMembers.map((m) => m._id.toString());
      participantDocs = [callerDoc, ...allowedMembers];

      if (targetIds.length === 0) {
        return res.status(400).json({
          success: false,
          code: 'NO_AVAILABLE_RECIPIENTS',
          message: 'No available recipients to call',
        });
      }

      const existingActiveCall = await findAndValidateActiveGroupCall(conversationDoc._id);
      if (existingActiveCall) {
        const joinResult = await processJoinCall({
          userId: callerId,
          callId: existingActiveCall.callId,
          callDocId: existingActiveCall._id.toString(),
        });
        if (joinResult.statusCode === 200) {
          return res.status(200).json({
            ...joinResult.body,
            joinedExisting: true,
          });
        }
      }
    } else {
      let receiverId = rawReceiverId ? rawReceiverId.toString().trim() : '';
      if (!receiverId && conversationDoc && Array.isArray(conversationDoc.members)) {
        const other = conversationDoc.members.find(
          (m) => m?.user && m.user.toString() !== callerId
        );
        if (other) receiverId = other.user.toString();
      }

      if (!receiverId || !mongoose.Types.ObjectId.isValid(receiverId)) {
        return res.status(400).json({
          success: false,
          code: 'INVALID_RECEIVER',
          message: 'Valid receiver is required',
        });
      }

      if (receiverId === callerId) {
        return res.status(400).json({
          success: false,
          code: 'CANNOT_CALL_SELF',
          message: 'Cannot call yourself',
        });
      }

      const receiverDoc = await Account.findOne({ _id: receiverId, isDeleted: false })
        .select('username avatar friends blockedUsers blockedFriends')
        .lean();

      if (!receiverDoc) {
        return res.status(404).json({
          success: false,
          code: 'RECEIVER_NOT_FOUND',
          message: 'Recipient account not found',
        });
      }

      if (isBlockedBetween(callerDoc, receiverDoc)) {
        return res.status(403).json({
          success: false,
          code: 'USER_BLOCKED',
          message: 'Cannot place call due to block settings',
        });
      }

      const isFriends =
        hasId(callerDoc.friends, receiverId) || hasId(receiverDoc.friends, callerId);
      if (!isFriends) {
        return res.status(403).json({
          success: false,
          code: 'FRIENDS_ONLY',
          message: 'Only friends can call each other',
        });
      }

      resolvedReceiverId = receiverId;
      targetIds = [receiverId];
      participantDocs = [callerDoc, receiverDoc];

      if (!conversationDoc) {
        conversationDoc = await Conversation.findOne({
          type: 'direct',
          $and: [
            { 'members.user': callerId },
            { 'members.user': resolvedReceiverId },
          ],
        }).lean();
      }
    }

    const callId = crypto.randomUUID();
    const shortRand = crypto.randomBytes(4).toString('hex');
    const channelName = `viora_call_${Date.now()}_${shortRand}`;
    const startedAt = new Date();

    const callDoc = new Call({
      callId,
      caller: callerId,
      receiver: resolvedReceiverId,
      conversationId: conversationDoc ? conversationDoc._id : null,
      isGroup,
      participants: [callerId, ...targetIds],
      activeParticipants: [callerId],
      declinedBy: [],
      channelName,
      type: callType,
      status: 'ringing',
      startedAt,
      lastActivityAt: startedAt,
      participantHeartbeats: { [callerId.toString()]: startedAt },
    });

    await callDoc.save();

    if (isGroup && conversationDoc) {
      await upsertCallLogMessage(callDoc);
    }

    const appId = process.env.AGORA_APP_ID;
    const token = generateAgoraToken(channelName, 0, RtcRole.PUBLISHER);
    const groupInfo = isGroup
      ? await resolveGroupDisplayInfo(conversationDoc)
      : { groupName: '', groupAvatar: '' };
    const participantsList = formatParticipantProfiles(participantDocs);

    const payload = {
      type: 'incoming_call',
      callId,
      callDocId: callDoc._id.toString(),
      channelName,
      callType,
      callerId,
      callerName: callerDoc.username || 'Viora User',
      callerAvatar: callerDoc.avatar || '',
      receiverId: resolvedReceiverId || '',
      conversationId: conversationDoc ? conversationDoc._id.toString() : '',
      isGroup: isGroup ? 'true' : 'false',
      groupName: groupInfo.groupName,
      groupAvatar: groupInfo.groupAvatar,
      createdAt: Date.now().toString(),
    };

    const socketPayload = {
      ...payload,
      isGroup,
      targetUserIds: targetIds,
      participants: participantsList,
    };

    const io = getIO ? getIO() : null;
    for (const tId of targetIds) {
      if (io) {
        io.to(tId).emit('incoming_call', socketPayload);
      }
      sendDataPushNotification({
        recipientId: tId,
        data: payload,
        ttlSeconds: 35,
      }).catch((err) => {
        console.warn('FCM incoming_call push warning:', err?.message || err);
      });
    }

    return res.status(200).json({
      success: true,
      joinedExisting: false,
      appId,
      token,
      channelName,
      callId,
      callDocId: callDoc._id.toString(),
      callType,
      isGroup,
      groupName: groupInfo.groupName,
      groupAvatar: groupInfo.groupAvatar,
      conversationId: conversationDoc ? conversationDoc._id.toString() : null,
      targetUserIds: targetIds,
      participants: participantsList,
      answeredAt: null,
      call: socketPayload,
    });
  } catch (error) {
    console.error('startCall error:', error);
    return res.status(500).json({
      success: false,
      code: 'SERVER_ERROR',
      message: error.message || 'Failed to start call',
    });
  }
};

const isUserMemberOfConversation = async (conv, userIdStr) => {
  if (!conv || !userIdStr) return false;
  if ((conv.members || []).some((m) => (m?.user?._id || m?.user || '').toString() === userIdStr)) {
    return true;
  }
  if (conv.communityGroup) {
    try {
      const grp = await Group.findById(conv.communityGroup).select('owner members').lean();
      if (grp) {
        if (grp.owner && grp.owner.toString() === userIdStr) return true;
        if ((grp.members || []).some((gm) => (gm?.user?._id || gm?.user || '').toString() === userIdStr)) {
          return true;
        }
      }
    } catch (_) {}
  }
  return false;
};

const processJoinCall = async ({ userId, callId, callDocId }) => {
  const userIdStr = (userId || '').toString().trim();
  if (!userIdStr || !mongoose.Types.ObjectId.isValid(userIdStr)) {
    return { statusCode: 401, body: { success: false, code: 'UNAUTHORIZED', message: 'Unauthorized' } };
  }

  let call = await findCallRecord(callId, callDocId);
  if (!call) {
    return { statusCode: 404, body: { success: false, code: 'CALL_NOT_FOUND', message: 'Call not found' } };
  }

  call = await cleanupStaleCallIfNeeded(call);

  if (!call.isGroup) {
    return {
      statusCode: 400,
      body: { success: false, code: 'GROUP_CALL_ONLY', message: 'Only group calls support late join' },
    };
  }

  const userAcc = await Account.findOne({ _id: userIdStr, isDeleted: false }).select('_id username avatar').lean();
  if (!userAcc) {
    return { statusCode: 404, body: { success: false, code: 'USER_NOT_FOUND', message: 'Account not found' } };
  }

  const isParticipant = (call.participants || []).some((p) => p && p.toString() === userIdStr);
  let isConvMember = isParticipant;
  if (!isConvMember && call.conversationId) {
    const conv = await Conversation.findById(call.conversationId).select('members communityGroup type').lean();
    isConvMember = await isUserMemberOfConversation(conv, userIdStr);
  }
  if (!isConvMember) {
    return {
      statusCode: 403,
      body: { success: false, code: 'NOT_CONVERSATION_MEMBER', message: 'You are not a member of this group' },
    };
  }

  if (['cancelled', 'completed', 'missed', 'declined'].includes(call.status)) {
    await upsertCallLogMessage(call).catch(() => {});
    return {
      statusCode: 409,
      body: {
        success: false,
        code: 'CALL_ALREADY_ENDED',
        status: call.status,
        message: 'Call has already ended',
      },
    };
  }

  const now = new Date();
  const uidObj = new mongoose.Types.ObjectId(userIdStr);
  let activeCall = call;
  let updated = null;

  if (call.status === 'ringing') {
    updated = await Call.findOneAndUpdate(
      { _id: call._id, status: 'ringing' },
      {
        $set: {
          status: 'ongoing',
          answeredAt: call.answeredAt || now,
          lastActivityAt: now,
          [`participantHeartbeats.${userIdStr}`]: now,
        },
        $addToSet: {
          participants: uidObj,
          activeParticipants: uidObj,
        },
        $pull: {
          declinedBy: uidObj,
        },
      },
      { new: true }
    );
  }

  if (!updated) {
    updated = await Call.findOneAndUpdate(
      { _id: call._id, status: 'ongoing' },
      {
        $set: {
          lastActivityAt: now,
          [`participantHeartbeats.${userIdStr}`]: now,
        },
        $addToSet: {
          participants: uidObj,
          activeParticipants: uidObj,
        },
        $pull: {
          declinedBy: uidObj,
        },
      },
      { new: true }
    );
  }

  if (!updated) {
    const latest = await Call.findById(call._id);
    if (latest) {
      await upsertCallLogMessage(latest).catch(() => {});
    }
    return {
      statusCode: 409,
      body: {
        success: false,
        code: 'CALL_ALREADY_ENDED',
        status: latest?.status || 'completed',
        message: 'Call has already ended',
      },
    };
  }

  activeCall = updated;
  await upsertCallLogMessage(activeCall);

  await activeCall.populate('participants', 'username avatar');
  await activeCall.populate('conversationId', 'name avatar type communityGroup');

  const groupInfo = await resolveGroupDisplayInfo(activeCall.conversationId);
  const participantsList = formatParticipantProfiles(activeCall.participants);
  const allParticipantIds = participantsList
    .map((p) => p.userId)
    .filter((id) => id && id !== userIdStr);

  const io = getIO ? getIO() : null;
  if (io) {
    const recipients = new Set([
      activeCall.caller?.toString(),
      ...(activeCall.activeParticipants || []).map((p) => p?.toString()).filter(Boolean),
      ...allParticipantIds,
    ]);
    recipients.delete(userIdStr);

    const eventPayload = {
      callId: activeCall.callId,
      callDocId: activeCall._id.toString(),
      channelName: activeCall.channelName,
      callType: activeCall.type,
      acceptedBy: userIdStr,
      accepterName: userAcc.username || '',
      accepterAvatar: userAcc.avatar || '',
      agoraUid: userIdToAgoraUid(userIdStr),
      answeredAt: activeCall.answeredAt,
      participants: participantsList,
      groupName: groupInfo.groupName,
      groupAvatar: groupInfo.groupAvatar,
    };

    for (const rId of recipients) {
      if (rId) io.to(rId).emit('call_accepted', eventPayload);
    }
  }

  const appId = process.env.AGORA_APP_ID;
  const token = generateAgoraToken(activeCall.channelName, 0, RtcRole.PUBLISHER);

  return {
    statusCode: 200,
    body: {
      success: true,
      joinedExisting: true,
      appId,
      token,
      channelName: activeCall.channelName,
      callId: activeCall.callId,
      callDocId: activeCall._id.toString(),
      callType: activeCall.type,
      isGroup: true,
      groupName: groupInfo.groupName,
      groupAvatar: groupInfo.groupAvatar,
      conversationId: activeCall.conversationId ? activeCall.conversationId._id.toString() : null,
      targetUserIds: allParticipantIds,
      participants: participantsList,
      answeredAt: activeCall.answeredAt,
    },
  };
};

const joinCall = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Unauthorized' });
    }
    const { callId, callDocId } = req.body || {};
    const result = await processJoinCall({ userId, callId, callDocId });
    return res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error('joinCall error:', error);
    return res.status(500).json({
      success: false,
      code: 'SERVER_ERROR',
      message: error.message || 'Failed to join call',
    });
  }
};

const recordCallHeartbeat = async ({ userId, callId, callDocId }) => {
  const userIdStr = (userId || '').toString().trim();
  if (!userIdStr || !mongoose.Types.ObjectId.isValid(userIdStr)) return null;
  const call = await findCallRecord(callId, callDocId);
  if (!call || !['ringing', 'ongoing'].includes(call.status)) return null;

  const now = new Date();
  const uidObj = new mongoose.Types.ObjectId(userIdStr);
  return await Call.findOneAndUpdate(
    { _id: call._id, status: { $in: ['ringing', 'ongoing'] } },
    {
      $set: {
        lastActivityAt: now,
        [`participantHeartbeats.${userIdStr}`]: now,
      },
      $addToSet: {
        activeParticipants: uidObj,
      },
    },
    { new: true }
  ).catch(() => null);
};

const processAcceptCall = async ({ userId, callId, callDocId }) => {
  let call = await findCallRecord(callId, callDocId);
  if (!call) {
    return { statusCode: 404, body: { success: false, code: 'CALL_NOT_FOUND', message: 'Call not found' } };
  }

  call = await cleanupStaleCallIfNeeded(call);

  if (['cancelled', 'completed', 'missed', 'declined'].includes(call.status)) {
    if (call.isGroup) {
      await upsertCallLogMessage(call).catch(() => {});
    }
    return {
      statusCode: 409,
      body: {
        success: false,
        code: 'CALL_ALREADY_ENDED',
        status: call.status,
        message: 'Call has already ended',
      },
    };
  }

  let activeCall = call;
  let transitioned = false;
  const now = new Date();
  const userIdStr = userId ? userId.toString().trim() : '';
  const uidObj = userIdStr && mongoose.Types.ObjectId.isValid(userIdStr)
    ? new mongoose.Types.ObjectId(userIdStr)
    : null;

  const heartbeatSet = userIdStr ? { [`participantHeartbeats.${userIdStr}`]: now } : {};
  const activeAdd = [];
  if (uidObj) activeAdd.push(uidObj);
  if (call.caller && mongoose.Types.ObjectId.isValid(call.caller)) activeAdd.push(call.caller);

  if (call.status === 'ringing') {
    const updated = await Call.findOneAndUpdate(
      { _id: call._id, status: 'ringing' },
      {
        $set: {
          status: 'ongoing',
          answeredAt: call.answeredAt || now,
          lastActivityAt: now,
          ...heartbeatSet,
        },
        ...(activeAdd.length > 0
          ? {
              $addToSet: {
                participants: { $each: activeAdd },
                activeParticipants: { $each: activeAdd },
              },
            }
          : {}),
        ...(uidObj ? { $pull: { declinedBy: uidObj } } : {}),
      },
      { new: true }
    );
    if (updated) {
      activeCall = updated;
      transitioned = true;
    } else {
      activeCall = (await Call.findById(call._id)) || call;
      if (['cancelled', 'completed', 'missed', 'declined'].includes(activeCall.status)) {
        if (activeCall.isGroup) {
          await upsertCallLogMessage(activeCall).catch(() => {});
        }
        return {
          statusCode: 409,
          body: {
            success: false,
            code: 'CALL_ALREADY_ENDED',
            status: activeCall.status,
            message: 'Call has already ended',
          },
        };
      }
    }
  }

  if (!transitioned && activeCall.status === 'ongoing') {
    const updatedOngoing = await Call.findOneAndUpdate(
      { _id: activeCall._id, status: 'ongoing' },
      {
        $set: {
          lastActivityAt: now,
          ...heartbeatSet,
        },
        ...(uidObj
          ? {
              $addToSet: {
                participants: uidObj,
                activeParticipants: uidObj,
              },
              $pull: { declinedBy: uidObj },
            }
          : {}),
      },
      { new: true }
    );
    if (updatedOngoing) {
      activeCall = updatedOngoing;
    }
  }

  if (activeCall.isGroup) {
    await upsertCallLogMessage(activeCall);
  }

  const appId = process.env.AGORA_APP_ID;
  const token = generateAgoraToken(activeCall.channelName, 0, RtcRole.PUBLISHER);
  const io = getIO ? getIO() : null;

  await activeCall.populate('participants', 'username avatar');
  await activeCall.populate('conversationId', 'name avatar type communityGroup');

  const groupInfo = activeCall.isGroup
    ? await resolveGroupDisplayInfo(activeCall.conversationId)
    : { groupName: '', groupAvatar: '' };
  const participantsList = formatParticipantProfiles(activeCall.participants);
  const allParticipantIds = participantsList
    .map((p) => p.userId)
    .filter((id) => id && id !== userIdStr);

  if (io && userId && (transitioned || activeCall.isGroup)) {
    const accepter = await Account.findById(userId).select('username avatar').lean();
    const recipients = new Set([
      activeCall.caller?.toString(),
      ...allParticipantIds,
    ]);
    recipients.delete(userIdStr);

    const eventPayload = {
      callId: activeCall.callId,
      callDocId: activeCall._id.toString(),
      channelName: activeCall.channelName,
      callType: activeCall.type,
      acceptedBy: userIdStr,
      accepterName: accepter?.username || '',
      accepterAvatar: accepter?.avatar || '',
      agoraUid: userIdToAgoraUid(userIdStr),
      answeredAt: activeCall.answeredAt,
      participants: participantsList,
      groupName: groupInfo.groupName,
      groupAvatar: groupInfo.groupAvatar,
    };

    for (const rId of recipients) {
      if (rId) io.to(rId).emit('call_accepted', eventPayload);
    }
  }

  return {
    statusCode: 200,
    body: {
      success: true,
      appId,
      token,
      channelName: activeCall.channelName,
      callId: activeCall.callId,
      callDocId: activeCall._id.toString(),
      callType: activeCall.type,
      isGroup: activeCall.isGroup,
      groupName: groupInfo.groupName,
      groupAvatar: groupInfo.groupAvatar,
      conversationId: activeCall.conversationId ? activeCall.conversationId._id.toString() : null,
      targetUserIds: allParticipantIds,
      participants: participantsList,
      answeredAt: activeCall.answeredAt,
    },
  };
};

const acceptCall = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Unauthorized' });
    }

    const { callId, callDocId } = req.body || {};
    const result = await processAcceptCall({ userId, callId, callDocId });
    return res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error('acceptCall error:', error);
    return res.status(500).json({
      success: false,
      code: 'SERVER_ERROR',
      message: error.message || 'Failed to accept call',
    });
  }
};

const processDeclineCall = async ({ userId, callId, callDocId }) => {
  let call = await findCallRecord(callId, callDocId);
  if (!call) {
    return { statusCode: 404, body: { success: false, code: 'CALL_NOT_FOUND', message: 'Call not found' } };
  }

  call = await cleanupStaleCallIfNeeded(call);

  const io = getIO ? getIO() : null;
  const userIdStr = (userId || '').toString().trim();
  const targets = (call.participants || [])
    .map((p) => p?.toString())
    .filter((id) => id && id !== call.caller?.toString());

  if (['cancelled', 'completed', 'missed', 'declined'].includes(call.status)) {
    if (call.isGroup) {
      await upsertCallLogMessage(call).catch(() => {});
    }
    return { statusCode: 200, body: { success: true, callId: call.callId, status: call.status } };
  }

  if (!call.isGroup || targets.length <= 1) {
    const now = new Date();
    const updateFields = {
      status: 'declined',
      endedAt: now,
      lastActivityAt: now,
      activeParticipants: [],
    };
    if (userIdStr && mongoose.Types.ObjectId.isValid(userIdStr)) {
      updateFields.endedBy = userIdStr;
    }
    const updated = await Call.findOneAndUpdate(
      { _id: call._id, status: 'ringing' },
      { $set: updateFields },
      { new: true }
    );

    if (updated) {
      await emitDeclinedToCaller(updated, userIdStr);
      const otherTargets = targets.filter((id) => id !== userIdStr);
      if (otherTargets.length > 0) {
        await emitCancelToTargets(updated, otherTargets, 'declined');
      }
      await upsertCallLogMessage(updated);
      return { statusCode: 200, body: { success: true, callId: updated.callId, status: updated.status } };
    }

    return { statusCode: 200, body: { success: true, callId: call.callId, status: call.status } };
  }

  if (userIdStr && mongoose.Types.ObjectId.isValid(userIdStr)) {
    const uidObj = new mongoose.Types.ObjectId(userIdStr);
    const updatedGroup = await Call.findByIdAndUpdate(
      call._id,
      {
        $addToSet: { declinedBy: uidObj },
        $pull: { activeParticipants: uidObj },
      },
      { new: true }
    );

    if (updatedGroup && updatedGroup.status === 'ringing') {
      const declinedSet = new Set(
        (updatedGroup.declinedBy || []).map((d) => d?.toString()).filter(Boolean)
      );
      const allDeclined = targets.length > 0 && targets.every((t) => declinedSet.has(t));
      if (allDeclined) {
        const now = new Date();
        const closed = await Call.findOneAndUpdate(
          { _id: updatedGroup._id, status: 'ringing' },
          {
            $set: {
              status: 'declined',
              endedAt: now,
              lastActivityAt: now,
              activeParticipants: [],
              endedBy: uidObj,
            },
          },
          { new: true }
        );
        if (closed) {
          await emitDeclinedToCaller(closed, userIdStr);
          await emitCancelToTargets(closed, targets.filter((id) => id !== userIdStr), 'declined');
          await upsertCallLogMessage(closed);
          return { statusCode: 200, body: { success: true, callId: closed.callId, status: closed.status } };
        }
      }
    }
  }

  if (io && call.caller) {
    io.to(call.caller.toString()).emit('call_participant_declined', {
      callId: call.callId,
      callDocId: call._id.toString(),
      declinedBy: userIdStr,
    });
  }

  return { statusCode: 200, body: { success: true, callId: call.callId, status: call.status } };
};

const declineCall = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { callId, callDocId } = req.body || {};
    const result = await processDeclineCall({ userId, callId, callDocId });
    return res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error('declineCall error:', error);
    return res.status(500).json({
      success: false,
      code: 'SERVER_ERROR',
      message: error.message || 'Failed to decline call',
    });
  }
};

const processEndCall = async ({ userId, callId, callDocId, endForAll = false }) => {
  let currentCall = await findCallRecord(callId, callDocId);
  if (!currentCall) {
    return { statusCode: 404, body: { success: false, code: 'CALL_NOT_FOUND', message: 'Call not found' } };
  }

  currentCall = await cleanupStaleCallIfNeeded(currentCall);

  if (['cancelled', 'completed', 'missed', 'declined'].includes(currentCall.status)) {
    if (currentCall.isGroup && !currentCall.messageCreated) {
      await upsertCallLogMessage(currentCall).catch(() => {});
    }
    return {
      statusCode: 200,
      body: {
        success: true,
        callId: currentCall.callId,
        status: currentCall.status,
        duration: currentCall.duration || 0,
      },
    };
  }

  const io = getIO ? getIO() : null;
  const userIdStr = (userId || '').toString().trim();
  const uidObj = userIdStr && mongoose.Types.ObjectId.isValid(userIdStr)
    ? new mongoose.Types.ObjectId(userIdStr)
    : null;
  const allOthers = (currentCall.participants || [])
    .map((p) => p?.toString())
    .filter((id) => id && id !== userIdStr);

  const isCaller = userIdStr && currentCall.caller && currentCall.caller.toString() === userIdStr;

  if (currentCall.status === 'ringing') {
    if (!isCaller && userIdStr) {
      return await processDeclineCall({
        userId: userIdStr,
        callId: currentCall.callId,
        callDocId: currentCall._id.toString(),
      });
    }
    if (isCaller || !currentCall.isGroup) {
      const now = new Date();
      const updateFields = {
        status: 'cancelled',
        endedAt: now,
        lastActivityAt: now,
        activeParticipants: [],
      };
      if (uidObj) {
        updateFields.endedBy = uidObj;
      }
      const updated = await Call.findOneAndUpdate(
        { _id: currentCall._id, status: 'ringing' },
        { $set: updateFields },
        { new: true }
      );
      if (updated) {
        await emitCancelToTargets(updated, allOthers, 'cancelled');
        await upsertCallLogMessage(updated);
        return {
          statusCode: 200,
          body: { success: true, callId: updated.callId, status: updated.status, duration: 0 },
        };
      }
      currentCall = (await Call.findById(currentCall._id)) || currentCall;
    }
  }

  if (currentCall.status === 'ongoing') {
    const nowDate = new Date();
    const nowMs = nowDate.getTime();
    if (!currentCall.isGroup || endForAll === true) {
      const answeredMs = currentCall.answeredAt ? new Date(currentCall.answeredAt).getTime() : nowMs;
      const duration = Math.max(0, Math.round((nowMs - answeredMs) / 1000));
      const updateFields = {
        status: 'completed',
        endedAt: nowDate,
        lastActivityAt: nowDate,
        duration,
        activeParticipants: [],
      };
      if (uidObj) {
        updateFields.endedBy = uidObj;
      }
      const updated = await Call.findOneAndUpdate(
        { _id: currentCall._id, status: 'ongoing' },
        { $set: updateFields },
        { new: true }
      );
      if (updated) {
        await emitEndedToTargets(updated, allOthers, userIdStr, duration);
        await upsertCallLogMessage(updated);
        return {
          statusCode: 200,
          body: { success: true, callId: updated.callId, status: updated.status, duration },
        };
      }
    } else {
      const pulledDoc = await Call.findOneAndUpdate(
        { _id: currentCall._id, status: 'ongoing' },
        {
          ...(uidObj ? { $pull: { activeParticipants: uidObj } } : {}),
          $set: { lastActivityAt: nowDate },
        },
        { new: true }
      );

      if (pulledDoc) {
        const remainingIds = (pulledDoc.activeParticipants || [])
          .map((p) => p?.toString())
          .filter(Boolean);

        const trulyAliveIds = [];
        const ghostIds = [];
        for (const remId of remainingIds) {
          const hbDate =
            pulledDoc.participantHeartbeats && typeof pulledDoc.participantHeartbeats.get === 'function'
              ? pulledDoc.participantHeartbeats.get(remId)
              : null;
          const hbAgeMs = hbDate
            ? nowMs - new Date(hbDate).getTime()
            : nowMs - new Date(pulledDoc.answeredAt || pulledDoc.startedAt || nowMs).getTime();
          const online = hasActiveUserSocket(remId);
          if (online || hbAgeMs <= 90000) {
            trulyAliveIds.push(remId);
          } else if (mongoose.Types.ObjectId.isValid(remId)) {
            ghostIds.push(new mongoose.Types.ObjectId(remId));
          }
        }

        if (ghostIds.length > 0 && trulyAliveIds.length > 0) {
          await Call.findByIdAndUpdate(pulledDoc._id, {
            $pull: { activeParticipants: { $in: ghostIds } },
          }).catch(() => {});
        }

        if (trulyAliveIds.length === 0) {
          const answeredMs = pulledDoc.answeredAt ? new Date(pulledDoc.answeredAt).getTime() : nowMs;
          const duration = Math.max(0, Math.round((nowMs - answeredMs) / 1000));
          const updateFields = {
            status: 'completed',
            endedAt: nowDate,
            lastActivityAt: nowDate,
            duration,
            activeParticipants: [],
          };
          if (uidObj) {
            updateFields.endedBy = uidObj;
          }
          const completedDoc = await Call.findOneAndUpdate(
            { _id: pulledDoc._id, status: 'ongoing' },
            { $set: updateFields },
            { new: true }
          );
          if (completedDoc) {
            await emitEndedToTargets(completedDoc, allOthers, userIdStr, duration);
            await upsertCallLogMessage(completedDoc);
            return {
              statusCode: 200,
              body: { success: true, callId: completedDoc.callId, status: completedDoc.status, duration },
            };
          }
        } else {
          if (io) {
            for (const targetId of allOthers) {
              io.to(targetId).emit('call_participant_left', {
                callId: pulledDoc.callId,
                callDocId: pulledDoc._id.toString(),
                userId: userIdStr,
              });
            }
          }
          return {
            statusCode: 200,
            body: {
              success: true,
              callId: pulledDoc.callId,
              status: pulledDoc.status,
              duration: 0,
              remainingCount: trulyAliveIds.length,
            },
          };
        }
      }
    }
  }

  const latest = (await Call.findById(currentCall._id).lean()) || currentCall;
  return {
    statusCode: 200,
    body: {
      success: true,
      callId: latest.callId,
      status: latest.status,
      duration: latest.duration || 0,
    },
  };
};

const endCall = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { callId, callDocId, endForAll } = req.body || {};
    const result = await processEndCall({ userId, callId, callDocId, endForAll });
    return res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error('endCall error:', error);
    return res.status(500).json({
      success: false,
      code: 'SERVER_ERROR',
      message: error.message || 'Failed to end call',
    });
  }
};

const missedCall = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { callId, callDocId } = req.body || {};
    let call = await findCallRecord(callId, callDocId);

    if (!call) {
      return res.status(404).json({
        success: false,
        code: 'CALL_NOT_FOUND',
        message: 'Call not found',
      });
    }

    call = await cleanupStaleCallIfNeeded(call);

    if (call.status === 'ringing') {
      const now = new Date();
      const updateFields = {
        status: 'missed',
        endedAt: now,
        lastActivityAt: now,
        activeParticipants: [],
      };
      if (userId && mongoose.Types.ObjectId.isValid(userId)) {
        updateFields.endedBy = userId;
      }
      const updated = await Call.findOneAndUpdate(
        { _id: call._id, status: 'ringing' },
        { $set: updateFields },
        { new: true }
      );

      if (updated) {
        const targets = (updated.participants || [])
          .map((p) => p?.toString())
          .filter((id) => id && id !== updated.caller?.toString());

        const io = getIO ? getIO() : null;
        if (io) {
          for (const tId of targets) {
            io.to(tId).emit('call_missed', {
              type: 'call_missed',
              callId: updated.callId,
              callDocId: updated._id.toString(),
            });
          }
          if (updated.caller) {
            io.to(updated.caller.toString()).emit('call_missed', {
              type: 'call_missed',
              callId: updated.callId,
              callDocId: updated._id.toString(),
            });
          }
        }

        await emitCancelToTargets(updated, targets, 'missed');
        await upsertCallLogMessage(updated);
        return res.status(200).json({ success: true, callId: updated.callId, status: updated.status });
      }
    }

    return res.status(200).json({ success: true, callId: call.callId, status: call.status });
  } catch (error) {
    console.error('missedCall error:', error);
    return res.status(500).json({
      success: false,
      code: 'SERVER_ERROR',
      message: error.message || 'Failed to update missed call',
    });
  }
};

const getCallDetail = async (req, res) => {
  try {
    const { callId } = req.params;
    let call = await findCallRecord(callId, callId);

    if (!call) {
      return res.status(404).json({
        success: false,
        code: 'CALL_NOT_FOUND',
        message: 'Call not found',
      });
    }

    call = await cleanupStaleCallIfNeeded(call);

    if (req.query && req.query.ping === '1' && ['ringing', 'ongoing'].includes(call.status)) {
      const uid = await getUserIdFromReq(req);
      if (uid) {
        await recordCallHeartbeat({
          userId: uid,
          callId: call.callId,
          callDocId: call._id.toString(),
        });
      }
    }

    await call.populate('caller', 'username avatar');
    await call.populate('receiver', 'username avatar');
    await call.populate('participants', 'username avatar');
    await call.populate('conversationId', 'name avatar type communityGroup');

    const groupInfo = call.isGroup
      ? await resolveGroupDisplayInfo(call.conversationId)
      : { groupName: '', groupAvatar: '' };
    const participantsList = formatParticipantProfiles(call.participants);

    const isActive = call.status === 'ringing' || call.status === 'ongoing';
    const appId = isActive ? process.env.AGORA_APP_ID : null;
    const token = isActive ? generateAgoraToken(call.channelName, 0, RtcRole.PUBLISHER) : null;

    return res.status(200).json({
      success: true,
      appId,
      token,
      channelName: call.channelName,
      call: {
        callId: call.callId,
        callDocId: call._id.toString(),
        channelName: call.channelName,
        callType: call.type,
        status: call.status,
        isGroup: call.isGroup,
        groupName: groupInfo.groupName,
        groupAvatar: groupInfo.groupAvatar,
        duration: call.duration,
        startedAt: call.startedAt,
        answeredAt: call.answeredAt,
        endedAt: call.endedAt,
        caller: call.caller,
        receiver: call.receiver,
        participants: participantsList,
        activeParticipants: (call.activeParticipants || []).map((p) => p?.toString()).filter(Boolean),
        conversation: call.conversationId,
      },
    });
  } catch (error) {
    console.error('getCallDetail error:', error);
    return res.status(500).json({
      success: false,
      code: 'SERVER_ERROR',
      message: error.message || 'Failed to get call detail',
    });
  }
};

module.exports = {
  startCall,
  joinCall,
  acceptCall,
  declineCall,
  endCall,
  missedCall,
  getCallDetail,
  processJoinCall,
  processAcceptCall,
  processDeclineCall,
  processEndCall,
  recordCallHeartbeat,
  cleanupStaleCallIfNeeded,
  findAndValidateActiveGroupCall,
  upsertCallLogMessage,
};

