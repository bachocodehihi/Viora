const mongoose = require('mongoose');
const Conversation = require('../models/conversation.model');
const Message = require('../models/message.model');
const Account = require('../models/account.model');
const Group = require('../models/group.model');
const Call = require('../models/call.model');
const { verifyToken } = require('../config/jwt.config');
const { getIO, isUserOnline } = require('../socket');
const { cloudinary } = require('../config/cloudinary');

const formatTime = (date) => {
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

const getUserIdFromReq = (req) => {
  let userId = req.body?.userId || req.query?.userId;
  if (!userId && req.headers?.authorization) {
    try {
      const token = req.headers.authorization.replace('Bearer ', '').trim();
      const decoded = verifyToken(token);
      if (decoded && decoded.id) {
        userId = decoded.id;
      }
    } catch (_) {}
  }
  return userId;
};

const formatReplyTo = (repliedTo, currentUserId) => {
  if (!repliedTo) return null;
  const rSender = repliedTo.sender;
  const rIsMe = rSender && rSender._id ? rSender._id.toString() === currentUserId?.toString() : false;
  const rName = rSender ? (rIsMe ? 'You' : rSender.username) : '';

  return {
    id: repliedTo._id.toString(),
    text: repliedTo.isRecalled ? 'Message has been unsent' : (repliedTo.content || ''),
    type: repliedTo.type || 'text',
    call: formatCall(repliedTo.call, repliedTo.type),
    name: rName,
    isMe: rIsMe,
  };
};

const formatPinnedMessage = (pinnedMsg, currentUserId) => {
  if (!pinnedMsg) return null;
  const pSender = pinnedMsg.sender;
  const pSenderId = pSender && pSender._id ? pSender._id.toString() : (pSender ? pSender.toString() : '');
  const pIsMe = currentUserId && pSenderId ? pSenderId === currentUserId.toString() : false;
  const senderName = pSender ? (pSender.username || '') : '';
  const senderAvatar = pSender ? (pSender.avatar || '') : '';
  const primaryImageUrl = (pinnedMsg.attachments && pinnedMsg.attachments.length > 0)
    ? pinnedMsg.attachments[0]
    : (pinnedMsg.type === 'image' && pinnedMsg.content && pinnedMsg.content.startsWith('http') ? pinnedMsg.content : null);

  return {
    id: pinnedMsg._id ? pinnedMsg._id.toString() : (pinnedMsg.id || '').toString(),
    text: pinnedMsg.isRecalled ? 'Message has been unsent' : (pinnedMsg.content || ''),
    type: pinnedMsg.type || 'text',
    attachments: pinnedMsg.attachments || [],
    imageUrl: primaryImageUrl,
    location: formatLocation(pinnedMsg.location, pinnedMsg.type),
    poll: formatPoll(pinnedMsg.poll),
    call: formatCall(pinnedMsg.call, pinnedMsg.type),
    isMe: pIsMe,
    isRecalled: pinnedMsg.isRecalled || false,
    senderId: pSenderId,
    senderName,
    senderAvatar,
    time: formatTime(pinnedMsg.createdAt),
    createdAt: pinnedMsg.createdAt,
  };
};


const formatPoll = (poll) => {
  if (!poll) return null;
  const rawOptions = poll.options || [];
  const options = rawOptions.map(opt => {
    const rawVoters = opt.voterIds || [];
    const voters = rawVoters.map(v => {
      if (v && typeof v === 'object' && v.username) {
        return {
          id: v._id ? v._id.toString() : '',
          username: v.username,
          avatar: v.avatar || '',
        };
      }
      return {
        id: v?._id ? v._id.toString() : (v ? v.toString() : ''),
        username: '',
        avatar: '',
      };
    });
    return {
      id: opt.id,
      text: opt.text,
      voterIds: voters.map(v => v.id).filter(Boolean),
      voters,
      voteCount: voters.length,
    };
  });
  const totalVotes = options.reduce((sum, opt) => sum + opt.voteCount, 0);
  const lastVote = poll.lastVote ? {
    voterId: poll.lastVote.voterId?._id ? poll.lastVote.voterId._id.toString() : (poll.lastVote.voterId?.toString() || ''),
    voterName: poll.lastVote.voterName || '',
    action: poll.lastVote.action || '',
    optionId: poll.lastVote.optionId || '',
    optionText: poll.lastVote.optionText || '',
    updatedAt: poll.lastVote.updatedAt || null,
  } : null;

  if (lastVote && !lastVote.optionText) {
    if (lastVote.optionId) {
      const matchOpt = rawOptions.find(o => o.id === lastVote.optionId);
      if (matchOpt) lastVote.optionText = matchOpt.text || '';
    }
    if (!lastVote.optionText && lastVote.voterId) {
      const vIdStr = lastVote.voterId.toString();
      const matchOpt = rawOptions.find(o => (o.voterIds || []).some(v => (v?._id ? v._id.toString() : v?.toString()) === vIdStr));
      if (matchOpt) lastVote.optionText = matchOpt.text || '';
    }
  }
  return {
    question: poll.question || '',
    multipleAnswers: !!poll.multipleAnswers,
    isClosed: !!poll.isClosed,
    closedAt: poll.closedAt || null,
    options,
    totalVotes,
    lastVote,
  };
};

const formatLocation = (loc, type) => {
  if (type !== 'location' || !loc) return null;
  if (loc.latitude == null && loc.longitude == null) return null;
  const isLive = loc.isLive !== false && loc.status !== 'stopped';
  return {
    latitude: loc.latitude,
    longitude: loc.longitude,
    address: loc.address || '',
    name: loc.name || '',
    isLive,
    status: isLive ? 'active' : 'stopped',
  };
};

const formatCall = (callObj, type) => {
  if (type !== 'call' || !callObj) return null;
  return {
    callId: callObj.callId || '',
    callDocId: callObj.callDocId ? callObj.callDocId.toString() : '',
    callType: callObj.callType === 'video' ? 'video' : 'audio',
    status: callObj.status || 'completed',
    duration: typeof callObj.duration === 'number' ? callObj.duration : (Number(callObj.duration) || 0),
    callerId: callObj.caller?._id
      ? callObj.caller._id.toString()
      : (callObj.caller ? callObj.caller.toString() : ''),
    endedBy: callObj.endedBy?._id
      ? callObj.endedBy._id.toString()
      : (callObj.endedBy ? callObj.endedBy.toString() : ''),
  };
};

const reconcileActiveCallMessages = async (messages) => {
  if (!Array.isArray(messages) || messages.length === 0) return;
  const activeCallMsgs = messages.filter(
    (m) => m.type === 'call' && m.call && ['ringing', 'ongoing'].includes(m.call.status)
  );
  if (activeCallMsgs.length === 0) return;

  const { cleanupStaleCallIfNeeded, upsertCallLogMessage } = require('./call.controller');

  for (const m of activeCallMsgs) {
    try {
      let callDoc = null;
      if (m.call.callDocId) {
        callDoc = await Call.findById(m.call.callDocId);
      }
      if (!callDoc && m.call.callId) {
        callDoc = await Call.findOne({ callId: m.call.callId });
      }
      if (!callDoc) continue;

      const checked = await cleanupStaleCallIfNeeded(callDoc);
      if (checked && checked.status !== m.call.status) {
        await upsertCallLogMessage(checked).catch(() => {});
        m.call.status = checked.status;
        m.call.duration = checked.duration || 0;
        const isVideo = checked.type === 'video';
        if (checked.status === 'completed') {
          m.content = isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
        } else if (checked.status === 'declined') {
          m.content = isVideo ? 'Cuộc gọi video đã bị từ chối' : 'Cuộc gọi thoại đã bị từ chối';
        } else if (checked.status === 'missed' || checked.status === 'cancelled') {
          m.content = isVideo ? 'Cuộc gọi video nhỡ' : 'Cuộc gọi nhỡ';
        }
      }
    } catch (_) {}
  }
};

const getConversations = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User ID is required' });
    }

    const [conversations, currentUser] = await Promise.all([
      Conversation.find({ 'members.user': userId })
        .populate('members.user', 'username avatar isOnline lastSeen bio privacy blockedUsers')
        .populate({
          path: 'lastMessage',
          populate: [
            { path: 'sender', select: 'username avatar' },
            { path: 'poll.options.voterIds', select: 'username avatar' },
          ],
        })
        .populate('communityGroup', 'name avatar membersCount description')
        .populate({
          path: 'pinnedMessage',
          select: 'content type attachments location poll call sender isRecalled createdAt',
          populate: { path: 'sender', select: 'username avatar' },
        })
        .populate({
          path: 'pinnedMessages',
          select: 'content type attachments location poll call sender isRecalled createdAt',
          populate: { path: 'sender', select: 'username avatar' },
        })
        .sort({ updatedAt: -1 }),
      Account.findById(userId).select('friends blockedUsers').lean(),
    ]);

    const friendIdSet = new Set(
      (currentUser?.friends || []).map(f => (f._id || f).toString())
    );
    const blockedUserIds = new Set(
      (currentUser?.blockedUsers || []).map(b => (b._id || b).toString())
    );

    const formatted = [];

    for (const conv of conversations) {
      const CONV_PREVIEW_MESSAGE_LIMIT = 15;
      let rawConvMessages = await Message.find({
        conversationId: conv._id,
        deletedBy: { $ne: userId },
        hiddenFrom: { $ne: userId },
        type: { $ne: 'system' },
      })
        .populate('sender', 'username avatar')
        .populate('readBy', 'username avatar')
        .populate('poll.options.voterIds', 'username avatar')
        .populate({
          path: 'repliedTo',
          select: 'content type call sender isRecalled createdAt',
          populate: { path: 'sender', select: 'username avatar' },
        })
        .sort({ createdAt: -1, _id: -1 })
        .limit(CONV_PREVIEW_MESSAGE_LIMIT + 1);

      const hasMoreMessages = rawConvMessages.length > CONV_PREVIEW_MESSAGE_LIMIT;
      let messages = hasMoreMessages
        ? rawConvMessages.slice(0, CONV_PREVIEW_MESSAGE_LIMIT)
        : rawConvMessages;
      messages.reverse();

      if (!messages || messages.length === 0) {
        continue;
      }

      for (const m of messages) {
        if (m.type === 'poll' && m.poll?.lastVote?.updatedAt) {
          const lastVoteTime = new Date(m.poll.lastVote.updatedAt).getTime();
          const createdTime = new Date(m.createdAt).getTime();
          if (lastVoteTime > createdTime) {
            m.createdAt = new Date(lastVoteTime);
            Message.collection.updateOne(
              { _id: m._id },
              { $set: { createdAt: new Date(lastVoteTime), updatedAt: new Date(lastVoteTime) } }
            ).catch(() => {});
          }
        }
      }
      messages.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

      const isGroup = conv.type === 'group_chat';
      await reconcileActiveCallMessages(messages);

      let name = '';
      let avatar = '';
      let online = false;
      let showActiveStatus = false;
      let otherUserId = null;
      let isFriend = false;

      if (isGroup) {
        name = conv.name || conv.communityGroup?.name || 'Chat Group';
        const parts = name.trim().split(/\s+/);
        const initials = parts.length >= 2 ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase() : (name.length >= 2 ? name.substring(0, 2).toUpperCase() : 'GR');
        avatar = conv.avatar || conv.communityGroup?.avatar || initials;
        online = false;
        showActiveStatus = false;
        isFriend = false;
      } else {
        const otherMember = (conv.members || []).find(
          m => m.user && m.user._id && m.user._id.toString() !== userId.toString()
        )?.user;

        if (otherMember) {
          name = otherMember.username;
          avatar = otherMember.avatar || (name ? name[0].toUpperCase() : 'U');
          otherUserId = otherMember._id.toString();
          isFriend = friendIdSet.has(otherUserId);
          const isBlockedByViewer = blockedUserIds.has(otherUserId);
          const isBlockedByOther = Array.isArray(otherMember.blockedUsers) &&
            otherMember.blockedUsers.some(b => (b._id || b).toString() === userId.toString());
          const targetShowActiveStatus = otherMember.privacy?.showActiveStatus !== false;
          showActiveStatus = isFriend && !isBlockedByViewer && !isBlockedByOther && targetShowActiveStatus;
          online = showActiveStatus ? isUserOnline(otherUserId) : false;
        } else {
          name = 'User';
          avatar = 'U';
          online = false;
          showActiveStatus = false;
          isFriend = false;
        }
      }

      const formattedMessages = messages.map(m => {
        const senderObj = m.sender && typeof m.sender === 'object' ? m.sender : null;
        const senderId = senderObj ? senderObj._id.toString() : (m.sender ? m.sender.toString() : '');
        const isMe = senderId === (userId ? userId.toString() : '');

        const primaryImageUrl = (m.attachments && m.attachments.length > 0)
          ? m.attachments[0]
          : (m.type === 'image' && m.content && m.content.startsWith('http') ? m.content : null);

        return {
          id: m._id.toString(),
          text: m.isRecalled ? 'Message has been unsent' : m.content,
          type: m.type || 'text',
          attachments: m.attachments || [],
          imageUrl: primaryImageUrl,
          location: formatLocation(m.location, m.type),
          poll: formatPoll(m.poll),
          call: formatCall(m.call, m.type),
          isRecalled: m.isRecalled || false,
          recipientOnlyFriends: !!m.recipientOnlyFriends,
          isMe,
          senderId,
          senderName: senderObj?.username || '',
          senderAvatar: senderObj?.avatar || '',
          time: formatTime(m.createdAt),
          createdAt: m.createdAt,
          replyTo: formatReplyTo(m.repliedTo, userId),
          seenBy: m.recipientOnlyFriends ? [] : (m.readBy || [])
            .filter(r => {
              const rId = r._id ? r._id.toString() : r.toString();
              return rId !== (userId ? userId.toString() : '');
            })
            .map(r => ({
              id: r._id ? r._id.toString() : r.toString(),
              name: r.username || 'Member',
              avatar: r.avatar,
            })),
        };
      });

      const lastMsg = (messages && messages.length > 0) ? messages[messages.length - 1] : conv.lastMessage;

      let lastMessageData = null;
      let lastMsgText = '';
      if (lastMsg) {
        let senderObj = null;
        if (lastMsg.sender && typeof lastMsg.sender === 'object') {
          senderObj = lastMsg.sender;
        } else if (lastMsg.sender) {
          const matchSender = (conv.members || []).find(m => m.user && m.user._id && m.user._id.toString() === lastMsg.sender.toString());
          if (matchSender) senderObj = matchSender.user;
        }

        if (!senderObj && lastMsg.sender) {
          try {
            const senderIdToFind = lastMsg.sender._id || lastMsg.sender;
            senderObj = await Account.findById(senderIdToFind).select('username avatar').lean();
          } catch (_) {}
        }

        let senderId = senderObj ? senderObj._id.toString() : (lastMsg.sender ? (lastMsg.sender._id || lastMsg.sender).toString() : '');
        let isMsgFromMe = senderId === (userId ? userId.toString() : '');
        let senderName = senderObj?.username || '';
        const imgCount = (lastMsg.attachments && lastMsg.attachments.length) || (lastMsg.type === 'image' ? 1 : 0);
        const content = (lastMsg.content || '').trim();
        const hasCaption = content && content.toLowerCase() !== 'image' && content !== '📷 [Image]' && content.toLowerCase() !== 'hình ảnh' && content !== '📷 [Hình ảnh]' && !content.startsWith('http');

        let formattedPollForLastMsg = null;
        if (lastMsg.type === 'poll' || lastMsg.poll) {
          formattedPollForLastMsg = formatPoll(lastMsg.poll);
          if (formattedPollForLastMsg?.lastVote?.voterId) {
            const vId = formattedPollForLastMsg.lastVote.voterId;
            senderId = vId;
            isMsgFromMe = (vId === (userId ? userId.toString() : ''));
            if (formattedPollForLastMsg.lastVote.voterName) {
              senderName = formattedPollForLastMsg.lastVote.voterName;
            }
          }
        }

        lastMessageData = {
          id: lastMsg._id ? lastMsg._id.toString() : '',
          type: lastMsg.type || 'text',
          text: hasCaption ? content : (lastMsg.type === 'image' ? '' : content),
          attachmentsCount: imgCount,
          isRecalled: lastMsg.isRecalled || false,
          location: formatLocation(lastMsg.location, lastMsg.type),
          poll: formattedPollForLastMsg || formatPoll(lastMsg.poll),
          call: formatCall(lastMsg.call, lastMsg.type),
          isMe: isMsgFromMe,
          senderId: senderId,
          senderName: senderName,
          createdAt: lastMsg.createdAt,
        };

        if (lastMsg.type === 'poll') {
          if (formattedPollForLastMsg?.lastVote) {
            const lv = formattedPollForLastMsg.lastVote;
            if (lv.action === 'unvoted') {
              lastMsgText = 'đã huỷ bình chọn';
            } else if (lv.optionText) {
              lastMsgText = `Đã chọn "${lv.optionText}"`;
            } else {
              lastMsgText = 'đã bình chọn';
            }
          } else {
            lastMsgText = `[Bình chọn] ${formattedPollForLastMsg?.question || lastMsg.content || ''}`;
          }
        } else if (lastMsg.type === 'call') {
          const isVid = lastMsg.call?.callType === 'video';
          const st = lastMsg.call?.status;
          if (st === 'ringing' || st === 'ongoing') {
            lastMsgText = isVid ? 'Cuộc gọi video đang diễn ra' : 'Cuộc gọi thoại đang diễn ra';
          } else if (st === 'missed' || (st === 'cancelled' && !isMsgFromMe)) {
            lastMsgText = isVid ? 'Cuộc gọi video nhỡ' : 'Cuộc gọi nhỡ';
          } else if (st === 'declined') {
            lastMsgText = isVid ? 'Cuộc gọi video đã bị từ chối' : 'Cuộc gọi thoại đã bị từ chối';
          } else {
            lastMsgText = isVid ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
          }
        } else {
          lastMsgText = hasCaption ? content : (lastMsg.type === 'image' ? '' : content);
        }
      }

      const lastMsgTime = lastMsg
        ? formatTime(lastMsg.createdAt)
        : formatTime(conv.updatedAt || conv.createdAt || new Date());

      const isThisBlocked = !isGroup && otherUserId && blockedUserIds.has(otherUserId.toString());

      const unreadCount = isThisBlocked ? 0 : await Message.countDocuments({
        conversationId: conv._id,
        sender: { $ne: userId },
        readBy: { $ne: userId },
        deletedBy: { $ne: userId },
      });

      const lastMsgDate = lastMsg?.createdAt || conv.updatedAt || conv.createdAt || new Date(0);

      formatted.push({
        id: conv._id.toString(),
        name,
        avatar,
        color: '#2196F3',
        lastMessage: lastMsgText,
        lastMessageData: lastMessageData,
        time: lastMsgTime,
        lastMessageDate: lastMsgDate,
        unread: unreadCount,
        online,
        showActiveStatus,
        isGroup,
        isFriend,
        isBlocked: !!isThisBlocked,
        otherUserId,
        pinnedMessage: formatPinnedMessage(conv.pinnedMessage, userId),
        pinnedMessages: (conv.pinnedMessages || []).map(m => formatPinnedMessage(m, userId)).filter(Boolean),
        hasMoreMessages,
        messages: formattedMessages,
      });
    }

    formatted.sort((a, b) => new Date(b.lastMessageDate) - new Date(a.lastMessageDate));

    return res.status(200).json({
      success: true,
      data: formatted,
    });
  } catch (error) {
    console.error('getConversations error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};

const sendMessage = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    let { conversationId, content, receiverId, replyToId, repliedToMessageId, type, location, images, attachments } = req.body;

    let imageUrls = [];

    // 1. Files uploaded via Multer Cloudinary storage
    if (req.files && Array.isArray(req.files) && req.files.length > 0) {
      for (const file of req.files) {
        if (file.path) {
          imageUrls.push(file.path);
        } else if (file.secure_url) {
          imageUrls.push(file.secure_url);
        }
      }
    }

    // 2. Base64 strings or URLs in body
    let rawImages = images || attachments;
    if (typeof rawImages === 'string') {
      try {
        rawImages = JSON.parse(rawImages);
      } catch (_) {
        if (rawImages.trim().startsWith('http') || rawImages.trim().startsWith('data:image')) {
          rawImages = [rawImages.trim()];
        }
      }
    }

    if (Array.isArray(rawImages) && rawImages.length > 0) {
      for (const img of rawImages) {
        if (typeof img === 'string') {
          if (img.startsWith('http')) {
            imageUrls.push(img);
          } else if (img.startsWith('data:image') || img.length > 100) {
            try {
              const uploadRes = await cloudinary.uploader.upload(img, {
                folder: 'Viora/chat',
                resource_type: 'image'
              });
              if (uploadRes && uploadRes.secure_url) {
                imageUrls.push(uploadRes.secure_url);
              }
            } catch (upErr) {
              console.error('Base64 image upload error:', upErr);
            }
          }
        }
      }
    }

    let pollData = null;
    if (type === 'poll' && req.body.poll) {
      let rawPoll = req.body.poll;
      if (typeof rawPoll === 'string') {
        try { rawPoll = JSON.parse(rawPoll); } catch (_) {}
      }
      if (rawPoll && rawPoll.question && Array.isArray(rawPoll.options) && rawPoll.options.length >= 2) {
        pollData = {
          question: rawPoll.question.trim(),
          options: rawPoll.options.map((opt, idx) => ({
            id: opt.id || String(idx + 1),
            text: (typeof opt === 'string' ? opt : (opt.text || '')).trim(),
            voterIds: []
          })).filter(o => o.text.length > 0),
          multipleAnswers: !!rawPoll.multipleAnswers,
          isClosed: false,
        };
        if (pollData.options.length < 2) pollData = null;
      }
    }
    const isPoll = type === 'poll' && pollData != null;
    const isImage = imageUrls.length > 0 || type === 'image';
    const isLocation = type === 'location' && location && (location.latitude != null || location.longitude != null);
    const finalContent = (content && content.trim()) || (isLocation ? (location?.name || location?.address || '') : (isPoll ? pollData.question : (isImage ? '' : '')));

    if (!finalContent && !isLocation && !isImage && !isPoll) {
      return res.status(400).json({ success: false, code: 'MESSAGE_CONTENT_REQUIRED', message: 'Message content cannot be empty' });
    }

    let targetConvId = conversationId;

    if (targetConvId) {
      let existing = await Conversation.findById(targetConvId);
      if (!existing) {

        let groupConv = await Conversation.findOne({ communityGroup: targetConvId });
        if (!groupConv) {
          const group = await Group.findById(targetConvId);
          if (group) {
            const membersList = (group.members || []).map(m => ({
              user: m.user,
              role: m.role || 'member'
            }));
            if (!membersList.some(m => m.user?.toString() === userId.toString())) {
              membersList.push({ user: userId, role: 'member' });
            }
            groupConv = await Conversation.create({
              type: 'group_chat',
              name: group.name,
              avatar: group.avatar || '',
              communityGroup: group._id,
              members: membersList
            });
          }
        }
        if (groupConv) {
          targetConvId = groupConv._id;
        }
      }
    }

    if (!targetConvId && receiverId) {
      let actualReceiverId = receiverId;
      if (!mongoose.Types.ObjectId.isValid(receiverId)) {
        const clean = receiverId.toString().replace(/^@/, '').trim();
        let found = await Account.findOne({
          $or: [
            { username: clean },
            { username: new RegExp(`^${clean}$`, 'i') },
            { email: clean }
          ]
        });
        if (!found) {
          try {
            const cleanEmail = clean.toLowerCase().replace(/\s+/g, '') + '@viora.com';
            found = await Account.create({
              username: clean,
              email: cleanEmail,
              password: 'default_password',
              avatar: '',
              isOnline: false,
            });
          } catch (_) {
            found = await Account.findOne({ username: clean });
          }
        }
        if (found) {
          actualReceiverId = found._id;
        }
      }

      if (mongoose.Types.ObjectId.isValid(actualReceiverId)) {
        let existingConv = await Conversation.findOne({
          type: 'direct',
          $and: [
            { 'members.user': userId },
            { 'members.user': actualReceiverId }
          ]
        });

        if (!existingConv) {
          existingConv = await Conversation.create({
            type: 'direct',
            members: [
              { user: userId, role: 'member' },
              { user: actualReceiverId, role: 'member' }
            ]
          });
        }
        targetConvId = existingConv._id;
      }
    }

    if (!targetConvId) {
      return res.status(400).json({ success: false, code: 'CONVERSATION_OR_RECEIVER_REQUIRED', message: 'Conversation ID or Receiver ID is required' });
    }

    let targetConv = await Conversation.findById(targetConvId).select('type members');
    let isBlockedByReceiver = false;
    let isRecipientOnlyFriends = false;
    let receiverIdForBlock = null;

    if (targetConv && targetConv.type === 'direct') {
      const otherMember = (targetConv.members || []).find(
        m => m.user && m.user.toString() !== userId.toString()
      );
      if (otherMember) {
        receiverIdForBlock = otherMember.user;
        const receiverAcc = await Account.findById(otherMember.user)
          .select('friends blockedUsers blockedFriends privacy username')
          .lean();

        if (receiverAcc) {
          const receiverWhoCanMessage = receiverAcc.privacy?.whoCanMessage || 'everyone';
          const isSenderFriend = Array.isArray(receiverAcc.friends) &&
            receiverAcc.friends.some(f => (f._id || f).toString() === userId.toString());
          const isSenderBlockedFriend = Array.isArray(receiverAcc.blockedFriends) &&
            receiverAcc.blockedFriends.some(b => (b._id || b).toString() === userId.toString());
          const isSenderBlocked = Array.isArray(receiverAcc.blockedUsers) &&
            receiverAcc.blockedUsers.some(b => (b._id || b).toString() === userId.toString());

          // Case 1: Friend who is blocked by receiver
          if (isSenderBlocked && (isSenderFriend || isSenderBlockedFriend)) {
            isBlockedByReceiver = true;
          }

          // Case 2: Stranger when receiver only allows friends to message, OR stranger who is blocked
          if ((receiverWhoCanMessage === 'friends' && !isSenderFriend && !isSenderBlockedFriend) ||
              (isSenderBlocked && !isSenderFriend && !isSenderBlockedFriend)) {
            isRecipientOnlyFriends = true;
            isBlockedByReceiver = true;
          }
        }
      }
    }

    const msgType = isLocation ? 'location' : (isImage ? 'image' : (isPoll ? 'poll' : (type || 'text')));

    if (isLocation && location && location.isLive !== false) {
      await Message.updateMany(
        {
          conversationId: targetConvId,
          sender: userId,
          type: 'location',
          'location.status': 'active',
        },
        {
          $set: {
            'location.isLive': false,
            'location.status': 'stopped',
            content: 'Location sharing stopped',
          },
        }
      );

      try {
        const io = getIO ? getIO() : null;
        if (io && targetConvId) {
          io.to(targetConvId.toString()).emit('location_stopped', {
            conversationId: targetConvId.toString(),
            userId: userId.toString(),
          });
        }
      } catch (_) {}
    }

    const messageData = {
      conversationId: targetConvId,
      sender: userId,
      content: finalContent,
      type: msgType,
      attachments: imageUrls,
      poll: isPoll ? pollData : null,
      location: isLocation ? {
        latitude: Number(location.latitude) || 0,
        longitude: Number(location.longitude) || 0,
        address: location.address || '',
        name: location.name || '',
        isLive: location.isLive !== false,
        status: location.status || 'active',
      } : null,
      recipientOnlyFriends: isRecipientOnlyFriends,
      deletedBy: (isRecipientOnlyFriends && receiverIdForBlock) ? [receiverIdForBlock] : [],
      hiddenFrom: (isBlockedByReceiver && !isRecipientOnlyFriends && receiverIdForBlock) ? [receiverIdForBlock] : [],
    };

    const actualReplyId = replyToId || repliedToMessageId;
    if (actualReplyId) {
      const parentMsg = await Message.findById(actualReplyId);
      if (parentMsg) {
        messageData.repliedTo = parentMsg._id;
      }
    }

    const message = await Message.create(messageData);

    await message.populate([
      {
        path: 'sender',
        select: 'username avatar',
      },
      {
        path: 'poll.options.voterIds',
        select: 'username avatar',
      },
      {
        path: 'repliedTo',
        select: 'content type call sender isRecalled createdAt',
        populate: { path: 'sender', select: 'username avatar' },
      },
    ]);

    await Conversation.findByIdAndUpdate(targetConvId, {
      lastMessage: message._id,
      updatedAt: new Date(),
    });

    const replyToData = formatReplyTo(message.repliedTo, userId);
    const senderObj = message.sender && typeof message.sender === 'object' ? message.sender : null;
    const senderIdStr = senderObj ? senderObj._id.toString() : (message.sender ? message.sender.toString() : (userId ? userId.toString() : ''));

    const primaryImageUrl = (message.attachments && message.attachments.length > 0)
      ? message.attachments[0]
      : (message.type === 'image' && message.content && message.content.startsWith('http') ? message.content : null);

    const resultData = {
      id: message._id.toString(),
      conversationId: targetConvId.toString(),
      senderId: senderIdStr,
      senderName: senderObj?.username || '',
      senderAvatar: senderObj?.avatar || '',
      text: message.content,
      type: message.type || 'text',
      attachments: message.attachments || [],
      imageUrl: primaryImageUrl,
      location: formatLocation(message.location, message.type),
      poll: formatPoll(message.poll),
      call: formatCall(message.call, message.type),
      isRecalled: false,
      recipientOnlyFriends: isRecipientOnlyFriends,
      isMe: true,
      time: formatTime(message.createdAt),
      createdAt: message.createdAt,
      replyTo: replyToData,
      reactions: [],
      reaction: null,
      myReaction: null,
    };

    try {
      const io = getIO ? getIO() : null;
      if (io) {
        if (!isBlockedByReceiver) {
          io.to(targetConvId.toString()).emit('new_message', resultData);
        } else {
          io.to(userId.toString()).emit('new_message', resultData);
        }

        const conv = await Conversation.findById(targetConvId).select('members type name avatar communityGroup');
        if (conv) {
          const isGroupChat = conv.type === 'group_chat';
          let senderUsername = senderObj?.username || '';
          if (!senderUsername) {
            try {
              const acc = await Account.findById(userId).select('username').lean();
              if (acc) senderUsername = acc.username || '';
            } catch (_) {}
          }
          const imgCount = (message.attachments && message.attachments.length) || (msgType === 'image' ? 1 : 0);
          const content = (finalContent || '').trim();
          const hasCaption = content && content.toLowerCase() !== 'image' && content !== '📷 [Image]' && content.toLowerCase() !== 'hình ảnh' && content !== '📷 [Hình ảnh]' && !content.startsWith('http');
          const cleanText = hasCaption ? content : (msgType === 'image' ? '' : content);

          const memberIdsSet = new Set((conv.members || []).map(m => (m.user?._id || m.user || '').toString()).filter(Boolean));
          let communityGroupId = conv.communityGroup;
          if (!communityGroupId) {
            try {
              const grpFound = await Group.findOne({ chatConversation: targetConvId }).select('_id members owner').lean();
              if (grpFound) {
                if (grpFound.owner) memberIdsSet.add(grpFound.owner.toString());
                if (grpFound.members) {
                  for (const gm of grpFound.members) {
                    const gUid = (gm.user?._id || gm.user || '').toString();
                    if (gUid) memberIdsSet.add(gUid);
                  }
                }
              }
            } catch (_) {}
          } else {
            try {
              const grpFound = await Group.findById(communityGroupId).select('members owner').lean();
              if (grpFound) {
                if (grpFound.owner) memberIdsSet.add(grpFound.owner.toString());
                if (grpFound.members) {
                  for (const gm of grpFound.members) {
                    const gUid = (gm.user?._id || gm.user || '').toString();
                    if (gUid) memberIdsSet.add(gUid);
                  }
                }
              }
            } catch (_) {}
          }

          // Emit new_message to all conversation members instantly (0ms)
          for (const memberId of memberIdsSet) {
            if (memberId && memberId !== userId.toString()) {
              if (isBlockedByReceiver) continue;
              io.to(memberId).emit('new_message', resultData);
            }
          }

          // Emit conversation_updated in parallel using Promise.all (non-blocking)
          Promise.all(Array.from(memberIdsSet).map(async (memberId) => {
            if (!memberId) return;
            if (isBlockedByReceiver && memberId.toString() !== userId.toString()) return;
            const memberUnread = memberId === userId.toString() ? 0 : await Message.countDocuments({
              conversationId: targetConvId,
              sender: { $ne: memberId },
              readBy: { $ne: memberId },
              deletedBy: { $ne: memberId },
              hiddenFrom: { $ne: memberId },
            });

            const isMemberMe = memberId === userId.toString();
            const lastMessageData = {
              id: message._id.toString(),
              type: msgType,
              text: cleanText,
              attachmentsCount: imgCount,
              isRecalled: false,
              location: locObj,
              isMe: isMemberMe,
              senderId: userId.toString(),
              senderName: senderUsername,
              createdAt: message.createdAt,
            };

            io.to(memberId).emit('conversation_updated', {
              conversationId: targetConvId.toString(),
              lastMessage: cleanText,
              lastMessageData: lastMessageData,
              lastMessageDate: message.createdAt,
              time: resultData.time,
              updatedAt: new Date(),
              unread: memberUnread,
              senderId: userId.toString(),
              senderName: senderUsername,
              isGroup: isGroupChat,
            });
          })).catch(() => {});
        }
      }
    } catch (_) {}

    return res.status(201).json({
      success: true,
      data: resultData,
      conversationId: targetConvId.toString(),
    });
  } catch (error) {
    console.error('sendMessage error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};

const loadMessage = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    let { conversationId, receiverId, limit, before, beforeId } = req.body;
    const hasLimitParam = limit !== undefined && limit !== null && limit !== '';
    const parsedLimit = hasLimitParam
      ? Math.min(Math.max(parseInt(limit, 10) || 15, 1), 100)
      : 100;
    const isLoadMore = Boolean(
      (before && String(before).trim()) || (beforeId && String(beforeId).trim())
    );

    let resolvedReceiverId = null;
    if (!conversationId && receiverId && userId) {
      let actualReceiverId = receiverId;
      if (!mongoose.Types.ObjectId.isValid(receiverId)) {
        const clean = receiverId.toString().replace(/^@/, '').trim();
        let found = await Account.findOne({
          $or: [
            { username: clean },
            { username: new RegExp(`^${clean}$`, 'i') },
            { email: clean }
          ]
        });
        if (found) {
          actualReceiverId = found._id;
        }
      }

      if (mongoose.Types.ObjectId.isValid(actualReceiverId)) {
        resolvedReceiverId = actualReceiverId.toString();
        let existingConv = await Conversation.findOne({
          type: 'direct',
          $and: [
            { 'members.user': userId },
            { 'members.user': actualReceiverId }
          ]
        });
        if (existingConv) {
          conversationId = existingConv._id.toString();
        }
      }
    }

    if (!conversationId) {
      let isBlocked = false;
      let isBlockedByOther = false;
      let otherUser = null;
      if (resolvedReceiverId && userId) {
        const [meAcc, otherAcc] = await Promise.all([
          Account.findById(userId).select('blockedUsers friends').lean(),
          Account.findById(resolvedReceiverId).select('blockedUsers friends username avatar privacy').lean()
        ]);
        if (meAcc) {
          isBlocked = Array.isArray(meAcc.blockedUsers) &&
            meAcc.blockedUsers.some(b => (b._id || b).toString() === resolvedReceiverId);
        }
        if (otherAcc) {
          isBlockedByOther = Array.isArray(otherAcc.blockedUsers) &&
            otherAcc.blockedUsers.some(b => (b._id || b).toString() === userId.toString());
          const isFriendRel = Array.isArray(meAcc?.friends) &&
            meAcc.friends.some(f => (f._id || f).toString() === resolvedReceiverId);
          const targetShowActiveStatus = otherAcc.privacy?.showActiveStatus !== false;
          const showActiveStatus = !isBlocked && !isBlockedByOther && isFriendRel && targetShowActiveStatus;
          otherUser = {
            id: otherAcc._id.toString(),
            name: otherAcc.username,
            avatar: otherAcc.avatar,
            whoCanMessage: otherAcc.privacy?.whoCanMessage || 'everyone',
            isFriend: isFriendRel,
            showActiveStatus,
            online: showActiveStatus ? isUserOnline(otherAcc._id.toString()) : false,
          };
        }
      }
      return res.status(200).json({
        success: true,
        data: [],
        hasMore: false,
        pinnedMessage: null,
        pinnedMessages: [],
        conversationId: null,
        type: 'direct',
        isGroup: false,
        isBlocked,
        isBlockedByOther,
        otherUser,
      });
    }

    let conv = await Conversation.findById(conversationId)
      .populate({
        path: 'pinnedMessage',
        select: 'content type attachments location poll call sender isRecalled createdAt',
        populate: { path: 'sender', select: 'username avatar' },
      })
      .populate({
        path: 'pinnedMessages',
        select: 'content type attachments location poll call sender isRecalled createdAt',
        populate: { path: 'sender', select: 'username avatar' },
      })
      .populate('members.user', 'username avatar');

    if (!conv) {
      let groupConv = await Conversation.findOne({ communityGroup: conversationId });
      if (!groupConv) {
        const group = await Group.findById(conversationId);
        if (group) {
          const membersList = (group.members || []).map(m => ({
            user: m.user,
            role: m.role || 'member'
          }));
          if (!membersList.some(m => m.user?.toString() === userId?.toString())) {
            membersList.push({ user: userId, role: 'member' });
          }
          groupConv = await Conversation.create({
            type: 'group_chat',
            name: group.name,
            avatar: group.avatar || '',
            communityGroup: group._id,
            members: membersList
          });
          group.chatConversation = groupConv._id;
          await group.save();
        }
      }
      if (groupConv) {
        conversationId = groupConv._id.toString();
        conv = groupConv;
      }
    }

    if (conv && conv.members && conv.members.length > 0 && (!conv.members[0].user || !conv.members[0].user.username)) {
      await conv.populate('members.user', 'username avatar');
    }

    const allMembers = (conv?.members || [])
      .map(m => {
        const u = m.user;
        if (!u || !u._id) return null;
        return {
          id: u._id.toString(),
          name: u.username || 'Member',
          avatar: u.avatar || '',
        };
      })
      .filter(Boolean);

    const isGroupConv = conv?.type === 'group_chat';

    if (!isLoadMore && userId && conversationId) {
      await Message.updateMany(
        {
          conversationId,
          sender: { $ne: userId },
          readBy: { $ne: userId },
          deletedBy: { $ne: userId },
          hiddenFrom: { $ne: userId },
          recipientOnlyFriends: { $ne: true },
        },
        {
          $addToSet: { readBy: userId }
        }
      );

      try {
        const io = getIO ? getIO() : null;
        if (io) {
          const userAccount = await Account.findById(userId).select('username avatar');
          io.to(conversationId.toString()).emit('messages_read', {
            conversationId: conversationId.toString(),
            readerId: userId.toString(),
            readerName: userAccount?.username || '',
            readerAvatar: userAccount?.avatar || '',
          });
          io.to(userId.toString()).emit('conversation_updated', {
            conversationId: conversationId.toString(),
            unread: 0,
          });
        }
      } catch (_) {}
    }

    const msgFilter = {
      conversationId,
      deletedBy: { $ne: userId },
      hiddenFrom: { $ne: userId },
      type: { $ne: 'system' },
    };
    if (before) {
      const beforeDate = new Date(before);
      if (!isNaN(beforeDate.getTime())) {
        if (beforeId && mongoose.Types.ObjectId.isValid(beforeId)) {
          msgFilter.$or = [
            { createdAt: { $lt: beforeDate } },
            { createdAt: beforeDate, _id: { $lt: new mongoose.Types.ObjectId(beforeId) } },
          ];
        } else {
          msgFilter.createdAt = { $lt: beforeDate };
        }
      }
    } else if (beforeId && mongoose.Types.ObjectId.isValid(beforeId)) {
      msgFilter._id = { $lt: new mongoose.Types.ObjectId(beforeId) };
    }

    let rawMessages = await Message.find(msgFilter)
      .populate('sender', 'username avatar')
      .populate('readBy', 'username avatar')
      .populate('reactions.user', 'username avatar')
      .populate('poll.options.voterIds', 'username avatar')
      .populate({
        path: 'repliedTo',
        select: 'content type call sender isRecalled createdAt',
        populate: { path: 'sender', select: 'username avatar' },
      })
      .sort({ createdAt: -1, _id: -1 })
      .limit(parsedLimit + 1);

    const hasMore = rawMessages.length > parsedLimit;
    let messages = hasMore ? rawMessages.slice(0, parsedLimit) : rawMessages;
    messages.reverse();

    await reconcileActiveCallMessages(messages);

    for (const m of messages) {
      if (m.type === 'poll' && m.poll?.lastVote?.updatedAt) {
        const lastVoteTime = new Date(m.poll.lastVote.updatedAt).getTime();
        const createdTime = new Date(m.createdAt).getTime();
        if (lastVoteTime > createdTime) {
          m.createdAt = new Date(lastVoteTime);
          Message.collection.updateOne(
            { _id: m._id },
            { $set: { createdAt: new Date(lastVoteTime), updatedAt: new Date(lastVoteTime) } }
          ).catch(() => {});
        }
      }
    }
    messages.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

    const liveLocMessages = messages.filter(
      m => m.type === 'location' && m.location && m.location.isLive !== false && m.location.status !== 'stopped'
    );
    if (liveLocMessages.length > 0) {
      const latestBySender = new Map();
      const idsToStop = [];
      for (const m of liveLocMessages) {
        const sId = m.sender?._id ? m.sender._id.toString() : (m.sender ? m.sender.toString() : '');
        if (latestBySender.has(sId)) {
          const olderMsg = latestBySender.get(sId);
          idsToStop.push(olderMsg._id);
          if (olderMsg.location) {
            olderMsg.location.isLive = false;
            olderMsg.location.status = 'stopped';
          }
          olderMsg.content = 'Location sharing stopped';
        }
        latestBySender.set(sId, m);
      }
      if (idsToStop.length > 0) {
        Message.updateMany(
          { _id: { $in: idsToStop } },
          {
            $set: {
              'location.isLive': false,
              'location.status': 'stopped',
              content: 'Location sharing stopped',
            },
          }
        ).exec().catch(() => {});
      }
    }

    const formatted = messages.map(m => {
      const senderObj = m.sender && typeof m.sender === 'object' ? m.sender : null;
      const senderId = senderObj ? senderObj._id.toString() : (m.sender ? m.sender.toString() : '');
      const isMe = senderId === (userId ? userId.toString() : '');

      const rawSeen = (m.readBy || [])
        .filter(r => {
          const rId = r._id ? r._id.toString() : r.toString();
          return rId !== (userId ? userId.toString() : '');
        })
        .map(r => ({
          id: r._id ? r._id.toString() : r.toString(),
          name: r.username || 'Member',
          avatar: r.avatar,
        }));

      const seenBy = m.recipientOnlyFriends ? [] : rawSeen;

      const myReactionObj = (m.reactions || []).find(r => {
        const rId = r.user?._id ? r.user._id.toString() : (r.user ? r.user.toString() : '');
        return rId === (userId ? userId.toString() : '');
      });
      const lastReactionObj = (m.reactions && m.reactions.length > 0) ? m.reactions[m.reactions.length - 1] : null;
      const displayReaction = myReactionObj ? myReactionObj.reaction : (lastReactionObj ? lastReactionObj.reaction : null);

      const formattedReactions = (m.reactions || []).map(r => ({
        userId: r.user?._id ? r.user._id.toString() : (r.user ? r.user.toString() : ''),
        userName: r.user?.username || '',
        userAvatar: r.user?.avatar || '',
        reaction: r.reaction,
        createdAt: r.createdAt,
      }));

      const primaryImageUrl = (m.attachments && m.attachments.length > 0)
        ? m.attachments[0]
        : (m.type === 'image' && m.content && m.content.startsWith('http') ? m.content : null);

      return {
        id: m._id.toString(),
        text: m.isRecalled ? 'Message has been unsent' : m.content,
        type: m.type || 'text',
        attachments: m.attachments || [],
        imageUrl: primaryImageUrl,
        location: formatLocation(m.location, m.type),
        poll: formatPoll(m.poll),
        call: formatCall(m.call, m.type),
        isRecalled: m.isRecalled || false,
        recipientOnlyFriends: !!m.recipientOnlyFriends,
        isMe,
        senderId,
        senderName: senderObj?.username || '',
        senderAvatar: senderObj?.avatar || '',
        time: formatTime(m.createdAt),
        createdAt: m.createdAt,
        replyTo: formatReplyTo(m.repliedTo, userId),
        seenBy,
        reactions: formattedReactions,
        reaction: displayReaction,
        myReaction: myReactionObj ? myReactionObj.reaction : null,
      };
    });

    if (isLoadMore) {
      return res.status(200).json({
        success: true,
        data: formatted,
        hasMore,
        conversationId: conv?._id?.toString(),
      });
    }

    const pinnedMsgData = formatPinnedMessage(conv?.pinnedMessage, userId);
    let pinnedMessagesData = (conv?.pinnedMessages || []).map(m => formatPinnedMessage(m, userId)).filter(Boolean);
    if (pinnedMessagesData.length === 0 && pinnedMsgData) {
      pinnedMessagesData = [pinnedMsgData];
    }

    let isBlocked = false;
    let isBlockedByOther = false;
    let otherUser = null;

    if (conv && !isGroupConv && userId) {
      const otherMember = (conv.members || []).find(
        m => m.user && (m.user._id || m.user).toString() !== userId.toString()
      );
      if (otherMember) {
        const otherUserId = otherMember.user?._id || otherMember.user;
        const [meAcc, otherAcc] = await Promise.all([
          Account.findById(userId).select('blockedUsers friends').lean(),
          Account.findById(otherUserId).select('blockedUsers friends username avatar privacy').lean()
        ]);
        if (meAcc) {
          isBlocked = Array.isArray(meAcc.blockedUsers) &&
            meAcc.blockedUsers.some(b => (b._id || b).toString() === otherUserId.toString());
        }
        if (otherAcc) {
          isBlockedByOther = Array.isArray(otherAcc.blockedUsers) &&
            otherAcc.blockedUsers.some(b => (b._id || b).toString() === userId.toString());
          const isFriendRel = Array.isArray(meAcc?.friends) &&
            meAcc.friends.some(f => (f._id || f).toString() === otherUserId.toString());
          const targetShowActiveStatus = otherAcc.privacy?.showActiveStatus !== false;
          const showActiveStatus = !isBlocked && !isBlockedByOther && isFriendRel && targetShowActiveStatus;
          otherUser = {
            id: otherAcc._id.toString(),
            name: otherAcc.username,
            avatar: otherAcc.avatar,
            whoCanMessage: otherAcc.privacy?.whoCanMessage || 'everyone',
            isFriend: isFriendRel,
            showActiveStatus,
            online: showActiveStatus ? isUserOnline(otherAcc._id.toString()) : false,
          };
        }
      }
    }

    let activeCallSummary = null;
    if (conv && isGroupConv) {
      try {
        const { findAndValidateActiveGroupCall } = require('./call.controller');
        const activeGroupCall = await findAndValidateActiveGroupCall(conv._id);
        if (activeGroupCall && ['ringing', 'ongoing'].includes(activeGroupCall.status)) {
          activeCallSummary = {
            callId: activeGroupCall.callId,
            callDocId: activeGroupCall._id.toString(),
            callType: activeGroupCall.type === 'video' ? 'video' : 'audio',
            status: activeGroupCall.status,
            startedAt: activeGroupCall.startedAt,
            answeredAt: activeGroupCall.answeredAt || null,
            callerId: activeGroupCall.caller ? activeGroupCall.caller.toString() : '',
            activeCount: Array.isArray(activeGroupCall.activeParticipants)
              ? activeGroupCall.activeParticipants.length
              : 0,
          };
        }
      } catch (_) {}
    }

    return res.status(200).json({
      success: true,
      data: formatted,
      hasMore,
      pinnedMessage: pinnedMsgData,
      pinnedMessages: pinnedMessagesData,
      conversationId: conv?._id?.toString(),
      type: conv?.type || 'direct',
      isGroup: isGroupConv,
      members: allMembers,
      isBlocked,
      isBlockedByOther,
      otherUser,
      activeCall: activeCallSummary,
    });
  } catch (error) {
    console.error('loadMessage error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};

const deleteMessage = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { messageId, deleteForEveryone } = req.body;

    if (!messageId) {
      return res.status(400).json({ success: false, code: 'MESSAGE_ID_REQUIRED', message: 'Message ID is required' });
    }

    if (deleteForEveryone) {
      await Message.findByIdAndDelete(messageId);
      await Conversation.updateMany(
        { $or: [{ pinnedMessage: messageId }, { pinnedMessages: messageId }] },
        {
          $pull: { pinnedMessages: messageId },
          $set: { pinnedMessage: null },
        }
      );
    } else if (userId) {
      await Message.findByIdAndUpdate(messageId, {
        $addToSet: { deletedBy: userId },
      });
    } else {
      await Message.findByIdAndDelete(messageId);
    }

    return res.status(200).json({
      success: true,
      message: 'Message deleted',
      data: { messageId },
    });
  } catch (error) {
    console.error('deleteMessage error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};

const recallMessage = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { messageId } = req.body;

    if (!messageId) {
      return res.status(400).json({ success: false, code: 'MESSAGE_ID_REQUIRED', message: 'Message ID is required' });
    }

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ success: false, code: 'MESSAGE_NOT_FOUND', message: 'Message not found' });
    }

    if (userId && message.sender.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, code: 'CANNOT_UNSEND_OTHER_MESSAGE', message: 'You can only unsend your own messages' });
    }

    message.isRecalled = true;
    message.content = 'Message has been unsent';
    await message.save();

    await Conversation.updateMany(
      { $or: [{ pinnedMessage: message._id }, { pinnedMessages: message._id }] },
      {
        $pull: { pinnedMessages: message._id },
        $set: { pinnedMessage: null },
      }
    );

    try {
      const io = getIO ? getIO() : null;
      if (io && message.conversationId) {
        io.to(message.conversationId.toString()).emit('message_recalled', {
          messageId: message._id.toString(),
          conversationId: message.conversationId.toString(),
        });
      }
    } catch (_) {}

    return res.status(200).json({
      success: true,
      message: 'Message unsent',
      data: {
        id: message._id.toString(),
        isRecalled: true,
        text: 'Message has been unsent',
      },
    });
  } catch (error) {
    console.error('recallMessage error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};

const pinMessage = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { messageId, conversationId } = req.body;

    if (!messageId) {
      return res.status(400).json({ success: false, code: 'MESSAGE_ID_REQUIRED', message: 'Message ID is required' });
    }

    const message = await Message.findById(messageId).populate('sender', 'username avatar');
    if (!message) {
      return res.status(404).json({ success: false, code: 'MESSAGE_NOT_FOUND', message: 'Message not found' });
    }

    const targetConvId = conversationId || message.conversationId;
    const updatedConv = await Conversation.findByIdAndUpdate(
      targetConvId,
      {
        $addToSet: { pinnedMessages: message._id },
        $set: { pinnedMessage: message._id },
      },
      { new: true }
    ).populate({
      path: 'pinnedMessages',
      select: 'content type attachments location poll call sender isRecalled createdAt',
      populate: { path: 'sender', select: 'username avatar' },
    }).populate({
      path: 'pinnedMessage',
      select: 'content type attachments location poll call sender isRecalled createdAt',
      populate: { path: 'sender', select: 'username avatar' },
    });

    const pinnedData = formatPinnedMessage(message, userId);
    const pinnedMessagesData = (updatedConv?.pinnedMessages || []).map(m => formatPinnedMessage(m, userId)).filter(Boolean);

    try {
      const io = getIO ? getIO() : null;
      if (io) {
        const payload = {
          conversationId: targetConvId.toString(),
          pinnedMessage: pinnedData,
          pinnedMessages: pinnedMessagesData,
        };
        // Emit to conversation room (for users active in chat)
        io.to(targetConvId.toString()).emit('message_pinned', payload);
        // Also emit directly to all member user rooms so anyone online receives it instantly
        for (const m of (updatedConv?.members || [])) {
          const mId = (m.user?._id || m.user || '').toString();
          if (mId) {
            io.to(mId).emit('message_pinned', payload);
          }
        }
      }
    } catch (_) {}

    return res.status(200).json({
      success: true,
      message: 'Message pinned',
      data: pinnedData,
      pinnedMessage: pinnedData,
      pinnedMessages: pinnedMessagesData,
    });
  } catch (error) {
    console.error('pinMessage error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};

const unPinMessage = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { conversationId, messageId } = req.body;

    if (!conversationId && !messageId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'Conversation ID or Message ID is required' });
    }

    let convId = conversationId;
    if (!convId && messageId) {
      const foundConv = await Conversation.findOne({
        $or: [{ pinnedMessages: messageId }, { pinnedMessage: messageId }]
      });
      if (foundConv) {
        convId = foundConv._id;
      } else {
        const m = await Message.findById(messageId);
        if (m) convId = m.conversationId;
      }
    }

    let updatedConv = null;
    if (convId) {
      if (messageId) {
        // Remove specific message from pinnedMessages
        updatedConv = await Conversation.findByIdAndUpdate(
          convId,
          { $pull: { pinnedMessages: messageId } },
          { new: true }
        ).populate({
          path: 'pinnedMessages',
          select: 'content type attachments location poll call sender isRecalled createdAt',
          populate: { path: 'sender', select: 'username avatar' },
        });

        const remaining = updatedConv?.pinnedMessages || [];
        const latestPinnedId = remaining.length > 0 ? remaining[remaining.length - 1]._id : null;
        await Conversation.findByIdAndUpdate(convId, { $set: { pinnedMessage: latestPinnedId } });
      } else {
        // Unpin all messages in conversation
        updatedConv = await Conversation.findByIdAndUpdate(
          convId,
          { $set: { pinnedMessage: null, pinnedMessages: [] } },
          { new: true }
        );
      }
    }

    const pinnedMessagesData = (updatedConv?.pinnedMessages || []).map(m => formatPinnedMessage(m, userId)).filter(Boolean);
    const latestPinned = pinnedMessagesData.length > 0 ? pinnedMessagesData[pinnedMessagesData.length - 1] : null;

    try {
      const io = getIO ? getIO() : null;
      if (io && convId) {
        const payload = {
          conversationId: convId.toString(),
          messageId: messageId ? messageId.toString() : null,
          pinnedMessage: latestPinned,
          pinnedMessages: pinnedMessagesData,
        };
        // Emit to conversation room (for users active in chat)
        io.to(convId.toString()).emit('message_unpinned', payload);
        // Also emit directly to all member user rooms so anyone online receives it instantly
        for (const m of (updatedConv?.members || [])) {
          const mId = (m.user?._id || m.user || '').toString();
          if (mId) {
            io.to(mId).emit('message_unpinned', payload);
          }
        }
      }
    } catch (_) {}

    return res.status(200).json({
      success: true,
      message: 'Message unpinned',
      pinnedMessage: latestPinned,
      pinnedMessages: pinnedMessagesData,
    });
  } catch (error) {
    console.error('unPinMessage error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};

const reactMessage = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Unauthorized' });
    }

    const { messageId, reaction } = req.body;
    if (!messageId) {
      return res.status(400).json({ success: false, code: 'MESSAGE_ID_REQUIRED', message: 'Message ID is required' });
    }

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ success: false, code: 'MESSAGE_NOT_FOUND', message: 'Message not found' });
    }

    if (!Array.isArray(message.reactions)) {
      message.reactions = [];
    }

    const cleanReaction = typeof reaction === 'string' ? reaction.trim() : '';
    const existingIndex = message.reactions.findIndex(
      (r) => r.user && (r.user._id ? r.user._id.toString() : r.user.toString()) === userId.toString()
    );

    let finalReaction = null;

    if (existingIndex !== -1) {
      if (!cleanReaction || message.reactions[existingIndex].reaction === cleanReaction) {

        message.reactions.splice(existingIndex, 1);
        finalReaction = null;
      } else {

        message.reactions[existingIndex].reaction = cleanReaction;
        message.reactions[existingIndex].createdAt = new Date();
        finalReaction = cleanReaction;
      }
    } else if (cleanReaction) {

      message.reactions.push({
        user: userId,
        reaction: cleanReaction,
        createdAt: new Date(),
      });
      finalReaction = cleanReaction;
    }

    await message.save();
    await message.populate('reactions.user', 'username avatar');

    const formattedReactions = (message.reactions || []).map((r) => ({
      userId: r.user?._id ? r.user._id.toString() : (r.user ? r.user.toString() : ''),
      userName: r.user?.username || '',
      userAvatar: r.user?.avatar || '',
      reaction: r.reaction,
      createdAt: r.createdAt,
    }));

    const lastReactionObj = formattedReactions.length > 0 ? formattedReactions[formattedReactions.length - 1] : null;
    const displayReaction = finalReaction || (lastReactionObj ? lastReactionObj.reaction : null);

    const payload = {
      messageId: message._id.toString(),
      conversationId: message.conversationId ? message.conversationId.toString() : null,
      userId: userId.toString(),
      reaction: finalReaction,
      displayReaction,
      reactions: formattedReactions,
    };

    try {
      const io = getIO ? getIO() : null;
      if (io && message.conversationId) {
        io.to(message.conversationId.toString()).emit('message_reaction_updated', payload);
      }
    } catch (_) {}

    return res.status(200).json({
      success: true,
      data: payload,
    });
  } catch (error) {
    console.error('reactMessage error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};

const likeMessage = reactMessage;

const editMessage = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { messageId, content } = req.body;

    if (!messageId || !content) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'Message ID and content are required' });
    }

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ success: false, code: 'MESSAGE_NOT_FOUND', message: 'Message not found' });
    }

    if (message.sender.toString() !== userId?.toString()) {
      return res.status(403).json({ success: false, code: 'CANNOT_EDIT_OTHER_MESSAGE', message: 'You do not have permission to edit this message' });
    }

    message.content = content;
    message.isEdited = true;
    await message.save();

    try {
      const io = getIO ? getIO() : null;
      if (io && message.conversationId) {
        io.to(message.conversationId.toString()).emit('message_edited', {
          messageId: message._id.toString(),
          conversationId: message.conversationId.toString(),
          content: message.content,
        });
      }
    } catch (_) {}

    return res.status(200).json({
      success: true,
      message: 'Message edited',
      data: {
        id: message._id.toString(),
        content: message.content,
        isEdited: true,
      },
    });
  } catch (error) {
    console.error('editMessage error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};

const stopShareLocation = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { messageId, conversationId } = req.body;
    let message;

    if (messageId && mongoose.Types.ObjectId.isValid(messageId)) {
      message = await Message.findById(messageId);
    }
    if (!message && conversationId) {
      message = await Message.findOne({
        conversationId,
        sender: userId,
        type: 'location',
        'location.status': 'active',
      }).sort({ createdAt: -1 });
    }
    if (!message) {
      message = await Message.findOne({
        sender: userId,
        type: 'location',
        'location.status': 'active',
      }).sort({ createdAt: -1 });
    }

    if (message && message.location) {
      message.location.isLive = false;
      message.location.status = 'stopped';
      message.content = 'Location sharing stopped';
      message.markModified('location');
      await message.save();
    }

    const convId = (message && message.conversationId) || conversationId;
    if (convId) {
      await Message.updateMany(
        {
          conversationId: convId,
          sender: userId,
          type: 'location',
          'location.status': 'active',
        },
        {
          $set: {
            'location.isLive': false,
            'location.status': 'stopped',
            content: 'Location sharing stopped',
          },
        }
      );
    }

    try {
      const io = getIO ? getIO() : null;
      if (io && convId) {
        io.to(convId.toString()).emit('location_stopped', {
          messageId: message ? message._id.toString() : (messageId || ''),
          conversationId: convId.toString(),
          userId: userId.toString(),
          location: message ? formatLocation(message.location, message.type) : { isLive: false, status: 'stopped' },
        });
      }
    } catch (_) {}

    return res.status(200).json({
      success: true,
      message: 'Location sharing stopped',
      data: {
        id: message ? message._id.toString() : (messageId || ''),
        type: 'location',
        text: 'Location sharing stopped',
        location: message ? formatLocation(message.location, message.type) : { isLive: false, status: 'stopped' },
      },
    });
  } catch (error) {
    console.error('stopShareLocation error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};

const updateLiveLocation = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { messageId, conversationId, latitude, longitude, address, name } = req.body;
    let message;

    if (messageId) {
      message = await Message.findById(messageId);
    } else if (conversationId) {
      message = await Message.findOne({
        conversationId,
        sender: userId,
        type: 'location',
        'location.status': 'active',
      }).sort({ createdAt: -1 });
    }

    if (!message || message.type !== 'location') {
      return res.status(404).json({ success: false, code: 'LOCATION_SESSION_NOT_FOUND', message: 'Location sharing session not found' });
    }

    if (message.location && message.location.status === 'active') {
      if (latitude != null) message.location.latitude = Number(latitude);
      if (longitude != null) message.location.longitude = Number(longitude);
      if (address) message.location.address = address;
      if (name) message.location.name = name;
      message.markModified('location');
      await message.save();

      try {
        const io = getIO ? getIO() : null;
        if (io && message.conversationId) {
          io.to(message.conversationId.toString()).emit('location_updated', {
            messageId: message._id.toString(),
            conversationId: message.conversationId.toString(),
            location: formatLocation(message.location, message.type),
          });
        }
      } catch (_) {}
    }

    return res.status(200).json({
      success: true,
      data: {
        id: message._id.toString(),
        location: formatLocation(message.location, message.type),
      },
    });
  } catch (error) {
    console.error('updateLiveLocation error:', error);
    return res.status(500).json({ success: false, code: 'MESSAGE_OPERATION_FAILED', message: error.message });
  }
};


const votePoll = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Unauthorized' });
    }

    const { messageId, optionId } = req.body;
    if (!messageId || !optionId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'messageId and optionId are required' });
    }

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ success: false, code: 'MESSAGE_NOT_FOUND', message: 'Message not found' });
    }

    if (message.type !== 'poll' || !message.poll) {
      return res.status(400).json({ success: false, code: 'NOT_A_POLL', message: 'Message is not a poll' });
    }

    const poll = message.poll;
    if (poll.isClosed) {
      return res.status(400).json({ success: false, code: 'POLL_CLOSED', message: 'Poll is closed' });
    }

    const targetOption = (poll.options || []).find(o => String(o.id) === String(optionId));
    if (!targetOption) {
      return res.status(404).json({ success: false, code: 'OPTION_NOT_FOUND', message: 'Option not found' });
    }

    const userStr = userId.toString();
    const voter = await Account.findById(userId).select('username avatar').lean();
    const voterName = voter?.username || 'Member';
    const hasVotedThis = (targetOption.voterIds || []).some(id => (id._id ? id._id.toString() : id.toString()) === userStr);
    const hadVotedBefore = poll.options.some(o => (o.voterIds || []).some(id => (id._id ? id._id.toString() : id.toString()) === userStr));

    let action = 'voted';
    if (hasVotedThis) {
      action = 'unvoted';
      // Toggle unvote
      targetOption.voterIds = targetOption.voterIds.filter(id => (id._id ? id._id.toString() : id.toString()) !== userStr);
    } else {
      if (hadVotedBefore) {
        action = 'changed';
      } else {
        action = 'voted';
      }
      if (!poll.multipleAnswers) {
        // Single choice: remove user from all other options
        for (const opt of poll.options) {
          opt.voterIds = (opt.voterIds || []).filter(id => (id._id ? id._id.toString() : id.toString()) !== userStr);
        }
      }
      targetOption.voterIds.push(new mongoose.Types.ObjectId(userId));
    }

    const now = new Date();
    message.poll.lastVote = {
      voterId: new mongoose.Types.ObjectId(userId),
      voterName,
      action,
      optionId: optionId,
      optionText: targetOption.text || '',
      updatedAt: now,
    };
    message.markModified('poll');
    message.markModified('poll.options');
    message.createdAt = now;
    message.markModified('createdAt');
    await message.save();

    // Guarantee that createdAt, updatedAt, and poll are updated in MongoDB collection directly
    await Message.collection.updateOne(
      { _id: message._id },
      {
        $set: {
          poll: message.poll,
          createdAt: now,
          updatedAt: now,
        }
      }
    );

    // Update conversation's lastMessage to this poll so it is at the bottom of the list
    if (message.conversationId) {
      await Conversation.findByIdAndUpdate(message.conversationId, {
        lastMessage: message._id,
        updatedAt: now,
      });
    }

    let pollToFormat = message.poll;
    try {
      const freshMsg = await Message.findById(message._id)
        .populate({ path: 'poll.options.voterIds', select: 'username avatar' });
      if (freshMsg && freshMsg.poll) {
        pollToFormat = freshMsg.poll;
      }
    } catch (_) {}

    const formattedPoll = formatPoll(pollToFormat);
    const chosenOptText = targetOption.text || '';
    const pollPreviewText = action === 'unvoted'
      ? 'đã huỷ bình chọn'
      : (chosenOptText ? `Đã chọn "${chosenOptText}"` : 'đã bình chọn');

    const payload = {
      messageId: message._id.toString(),
      conversationId: message.conversationId ? message.conversationId.toString() : null,
      poll: formattedPoll,
      voterId: userStr,
      voterName,
      action,
      optionId: optionId,
      optionText: chosenOptText,
      createdAt: now.toISOString(),
      time: formatTime(now),
    };

    try {
      const io = getIO ? getIO() : null;
      if (io && message.conversationId) {
        io.to(message.conversationId.toString()).emit('poll_updated', payload);

        const conv = await Conversation.findById(message.conversationId);
        if (conv) {
          const memberIdsSet = new Set((conv.members || []).map(m => (m.user?._id || m.user || '').toString()).filter(Boolean));
          let communityGroupId = conv.communityGroup;
          if (!communityGroupId) {
            try {
              const grpFound = await Group.findOne({ chatConversation: conv._id }).select('_id members owner').lean();
              if (grpFound) {
                if (grpFound.owner) memberIdsSet.add(grpFound.owner.toString());
                if (grpFound.members) {
                  for (const gm of grpFound.members) {
                    const gUid = (gm.user?._id || gm.user || '').toString();
                    if (gUid) memberIdsSet.add(gUid);
                  }
                }
              }
            } catch (_) {}
          } else {
            try {
              const grpFound = await Group.findById(communityGroupId).select('members owner').lean();
              if (grpFound) {
                if (grpFound.owner) memberIdsSet.add(grpFound.owner.toString());
                if (grpFound.members) {
                  for (const gm of grpFound.members) {
                    const gUid = (gm.user?._id || gm.user || '').toString();
                    if (gUid) memberIdsSet.add(gUid);
                  }
                }
              }
            } catch (_) {}
          }

          for (const memberId of memberIdsSet) {
            if (!memberId) continue;
            io.to(memberId).emit('poll_updated', payload);
            io.to(memberId).emit('conversation_updated', {
              conversationId: message.conversationId.toString(),
              lastMessage: pollPreviewText,
              lastMessageData: {
                id: message._id.toString(),
                type: 'poll',
                text: pollPreviewText,
                poll: formattedPoll,
                isMe: memberId === userStr,
                senderId: userStr,
                senderName: voterName,
                createdAt: now,
              },
              lastMessageDate: now,
              time: formatTime(now),
            });
          }
        }
      }
    } catch (_) {}

    return res.status(200).json({
      success: true,
      data: payload,
    });
  } catch (error) {
    console.error('votePoll error:', error);
    return res.status(500).json({ success: false, code: 'VOTE_POLL_FAILED', message: error.message || 'Failed to vote' });
  }
};

module.exports = {
  getConversations,
  sendMessage,
  loadMessage,
  deleteMessage,
  recallMessage,
  pinMessage,
  unPinMessage,
  likeMessage,
  reactMessage,
  editMessage,
  stopShareLocation,
  updateLiveLocation,
  votePoll,
};
