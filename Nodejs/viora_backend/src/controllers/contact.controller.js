const mongoose = require('mongoose');
const Request = require('../models/request.model');
const Account = require('../models/account.model');
const Group = require('../models/group.model');
const Conversation = require('../models/conversation.model');
const Notification = require('../models/notification.model');
const { createNotification } = require('./notification.controller');
const { verifyToken } = require('../config/jwt.config');
const { getIO, isUserOnline } = require('../socket');

const formatRelativeTime = (date) => {
  if (!date) return '';
  const now = new Date();
  const diffMs = now - new Date(date);
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHours = Math.floor(diffMin / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffSec < 60) return 'Just now';
  if (diffMin < 60) return `${diffMin}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) return `${diffDays}d ago`;
  return new Date(date).toLocaleDateString('en-US');
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

const getContacts = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User ID is required' });
    }

    const account = await Account.findById(userId)
      .populate('friends', 'username avatar bio isOnline lastSeen privacy blockedUsers note noteExpiresAt')
      .populate('following', 'username avatar bio')
      .populate('followers', 'username avatar bio');

    if (!account) {
      return res.status(404).json({ success: false, code: 'USER_NOT_FOUND', message: 'User not found' });
    }

    const [pendingFriendReqs, pendingFollowReqs, sentFriendReqs, pendingGroupInvites, groups] = await Promise.all([
      Request.find({
        receiver: userId,
        type: 'friend',
        status: 'pending'
      }).populate('sender', 'username avatar bio isOnline lastSeen').sort({ createdAt: -1 }),
      Request.find({
        receiver: userId,
        type: 'follow',
        status: 'pending'
      }).populate('sender', 'username avatar bio isOnline lastSeen').sort({ createdAt: -1 }),
      Request.find({
        sender: userId,
        type: 'friend',
        status: 'pending'
      }).populate('receiver', 'username avatar').lean(),
      Request.find({
        receiver: userId,
        type: { $in: ['group', 'group_invite'] },
        status: 'pending'
      }).populate('sender', 'username avatar')
        .populate('group', 'name avatar membersCount members description')
        .sort({ createdAt: -1 }),
      Group.find({
        $or: [{ owner: userId }, { 'members.user': userId }]
      }).sort({ updatedAt: -1 })
    ]);

    const sentFriendRequests = sentFriendReqs.map(r => ({
      requestId: r._id.toString(),
      receiverId: r.receiver?._id ? r.receiver._id.toString() : (r.receiver?.toString() || ''),
      receiverName: r.receiver?.username || '',
      avatar: r.receiver?.avatar || ''
    }));
    const sentFriendRequestIds = sentFriendRequests.map(r => r.receiverId).filter(Boolean);

    const getAvatarInitials = (name) => {
      if (!name) return 'U';
      const parts = name.trim().split(' ');
      if (parts.length >= 2) {
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
      }
      return name.substring(0, 1).toUpperCase();
    };

    const formattedRequests = [
      ...pendingFriendReqs.map(r => ({
        id: r._id.toString(),
        type: 'friend',
        senderId: r.sender?._id?.toString(),
        name: r.sender?.username || 'User',
        avatar: (r.sender?.avatar && r.sender.avatar.startsWith('http'))
          ? r.sender.avatar
          : getAvatarInitials(r.sender?.username),
        color: '#2563EB',
        mutualFriends: Math.floor(Math.random() * 6) + 2,
        time: formatRelativeTime(r.createdAt),
        createdAt: r.createdAt
      })),
      ...pendingFollowReqs.map(r => ({
        id: r._id.toString(),
        type: 'follow',
        senderId: r.sender?._id?.toString(),
        name: r.sender?.username || 'User',
        avatar: (r.sender?.avatar && r.sender.avatar.startsWith('http'))
          ? r.sender.avatar
          : getAvatarInitials(r.sender?.username),
        color: '#8B5CF6',
        time: formatRelativeTime(r.createdAt),
        createdAt: r.createdAt
      })),
      ...pendingGroupInvites.filter(r => r.group).map(r => ({
        id: r._id.toString(),
        type: 'group',
        groupId: r.group?._id?.toString(),
        name: r.group?.name || 'Group',
        inviter: r.sender?.username || 'Member',
        avatar: (r.group?.avatar && r.group.avatar.startsWith('http'))
          ? r.group.avatar
          : getAvatarInitials(r.group?.name),
        color: '#3B82F6',
        membersCount: r.group?.membersCount || (r.group?.members ? r.group.members.length : 1),
        time: formatRelativeTime(r.createdAt),
        createdAt: r.createdAt
      }))
    ];

    const myBlockedSet = new Set(
      (account.blockedUsers || []).map(b => (b._id || b).toString())
    );
    const now = new Date();
    const formattedFriends = (account.friends || []).map(f => {
      const fIdStr = f._id.toString();
      const isNoteActive = f.note && (!f.noteExpiresAt || new Date(f.noteExpiresAt) > now);
      const isBlockedByViewer = myBlockedSet.has(fIdStr);
      const isBlockedByFriend = Array.isArray(f.blockedUsers) &&
        f.blockedUsers.some(b => (b._id || b).toString() === userId.toString());
      const showActiveStatus = !isBlockedByViewer && !isBlockedByFriend && (f.privacy?.showActiveStatus !== false);
      return {
        id: fIdStr,
        name: f.username,
        avatar: (f.avatar && f.avatar.startsWith('http')) ? f.avatar : getAvatarInitials(f.username),
        color: '#3B82F6',
        status: f.bio && f.bio.trim().length > 0 ? f.bio : 'Friend',
        note: isNoteActive ? f.note : '',
        showActiveStatus,
        online: showActiveStatus ? isUserOnline(fIdStr) : false,
        lastSeen: showActiveStatus ? f.lastSeen : null,
        messages: []
      };
    });

    const formattedFollowing = (account.following || []).map(u => ({
      id: u._id.toString(),
      name: u.username,
      avatar: (u.avatar && u.avatar.startsWith('http')) ? u.avatar : getAvatarInitials(u.username),
      color: '#8B5CF6',
      handle: `@${(u.username || '').toLowerCase().replace(/\s+/g, '_')}`,
      bio: u.bio || '',
      isFollowing: true
    }));

    const followingIds = new Set((account.following || []).map(f => f._id.toString()));
    const formattedFollowers = (account.followers || []).map(u => ({
      id: u._id.toString(),
      name: u.username,
      avatar: (u.avatar && u.avatar.startsWith('http')) ? u.avatar : getAvatarInitials(u.username),
      color: '#06B6D4',
      handle: `@${(u.username || '').toLowerCase().replace(/\s+/g, '_')}`,
      bio: u.bio || '',
      isFollowing: followingIds.has(u._id.toString())
    }));

    const formattedGroups = [];
    for (const g of groups) {
      let convId = g.chatConversation ? g.chatConversation.toString() : null;
      if (!convId) {
        let existingConv = await Conversation.findOne({ communityGroup: g._id });
        if (!existingConv) {
          const convMembers = (g.members || []).map(m => ({
            user: m.user,
            role: m.role === 'owner' ? 'admin' : 'member',
            joinedAt: m.joinedAt || new Date()
          }));
          if (!convMembers.some(m => m.user?.toString() === userId.toString())) {
            convMembers.push({ user: userId, role: 'member', joinedAt: new Date() });
          }
          existingConv = await Conversation.create({
            type: 'group_chat',
            name: g.name,
            avatar: g.avatar || '',
            members: convMembers,
            communityGroup: g._id
          });
        }
        g.chatConversation = existingConv._id;
        await g.save();
        convId = existingConv._id.toString();
      }

      formattedGroups.push({
        id: g._id.toString(),
        conversationId: convId,
        name: g.name,
        avatar: (g.avatar && g.avatar.startsWith('http')) ? g.avatar : getAvatarInitials(g.name),
        color: '#3B82F6',
        membersCount: g.membersCount || (g.members ? g.members.length : 1),
        lastMessage: g.description || 'Welcome to the group!',
        time: formatRelativeTime(g.updatedAt || g.createdAt)
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        friendRequests: formattedRequests,
        sentFriendRequests: sentFriendRequests,
        sentFriendRequestIds: sentFriendRequestIds,
        friends: formattedFriends,
        following: formattedFollowing,
        followers: formattedFollowers,
        groups: formattedGroups
      }
    });
  } catch (error) {
    console.error('getContacts error:', error);
    return res.status(500).json({ success: false, code: 'FETCH_CONTACTS_FAILED', message: error.message || 'Failed to fetch contacts' });
  }
};

const sendFriendRequest = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { receiverId } = req.body;

    if (!userId || !receiverId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and receiverId are required' });
    }

    let targetReceiverId = receiverId;
    if (mongoose.Types.ObjectId.isValid(receiverId)) {
      targetReceiverId = receiverId;
    } else {
      const foundAccount = await Account.findOne({
        $or: [{ username: receiverId }, { email: receiverId }]
      });
      if (foundAccount) {
        targetReceiverId = foundAccount._id.toString();
      }
    }

    if (userId.toString() === targetReceiverId.toString()) {
      return res.status(400).json({ success: false, code: 'CANNOT_FRIEND_SELF', message: 'Cannot send friend request to yourself' });
    }

    const currentUser = await Account.findById(userId).select('friends');
    if (currentUser?.friends?.some(f => f.toString() === targetReceiverId.toString())) {
      return res.status(200).json({
        success: true,
        message: 'You are already friends',
        alreadyFriends: true,
      });
    }

    const reverseReq = await Request.findOne({
      sender: targetReceiverId,
      receiver: userId,
      type: 'friend',
      status: 'pending'
    });

    if (reverseReq) {
      reverseReq.status = 'accepted';
      await reverseReq.save();

      await Account.findByIdAndUpdate(userId, { $addToSet: { friends: targetReceiverId } });
      await Account.findByIdAndUpdate(targetReceiverId, { $addToSet: { friends: userId } });

      const [u1, u2] = await Promise.all([
        Account.findById(userId),
        Account.findById(targetReceiverId)
      ]);
      if (u1) {
        u1.friendsCount = u1.friends.length;
        await u1.save();
      }
      if (u2) {
        u2.friendsCount = u2.friends.length;
        await u2.save();
      }

      await createNotification({
        recipient: targetReceiverId,
        sender: userId,
        type: 'friend_accept',
        content: 'accepted your friend request'
      });

      const u1ShowActive = u1?.privacy?.showActiveStatus !== false;
      const u2ShowActive = u2?.privacy?.showActiveStatus !== false;

      const io = getIO ? getIO() : null;
      if (io) {
        io.to(targetReceiverId.toString()).emit('friend_request_accepted', {
          userId: userId.toString(),
          name: u1?.username || '',
          avatar: u1?.avatar || '',
          bio: u1?.bio || '',
          showActiveStatus: u1ShowActive,
          online: u1ShowActive ? isUserOnline(userId.toString()) : false,
          requestId: reverseReq._id.toString(),
          friendsCount: u2?.friendsCount || 0,
        });
        io.to(userId.toString()).emit('friend_request_accepted', {
          userId: targetReceiverId.toString(),
          name: u2?.username || '',
          avatar: u2?.avatar || '',
          bio: u2?.bio || '',
          showActiveStatus: u2ShowActive,
          online: u2ShowActive ? isUserOnline(targetReceiverId.toString()) : false,
          requestId: reverseReq._id.toString(),
          friendsCount: u1?.friendsCount || 0,
        });
        io.to(targetReceiverId.toString()).emit('stats_updated', {
          friendsCount: u2?.friendsCount || 0,
        });
        io.to(userId.toString()).emit('stats_updated', {
          friendsCount: u1?.friendsCount || 0,
        });
      }

      return res.status(200).json({
        success: true,
        message: 'Friend request accepted and now friends',
        isFriend: true,
      });
    }

    const senderAcc = await Account.findById(userId).select('username avatar bio');

    let existingReq = await Request.findOne({
      sender: userId,
      receiver: targetReceiverId,
      type: 'friend',
      group: null,
    });

    if (existingReq) {
      if (existingReq.status === 'pending') {
        return res.status(200).json({
          success: true,
          message: 'Friend request already sent',
          alreadySent: true,
          requestId: existingReq._id.toString()
        });
      }

      existingReq.status = 'pending';
      await existingReq.save();

      await createNotification({
        recipient: targetReceiverId,
        sender: userId,
        type: 'friend_request',
        request: existingReq._id,
        status: 'pending',
        content: 'sent you a friend request'
      });

      const io = getIO ? getIO() : null;
      if (io) {
        io.to(targetReceiverId.toString()).emit('friend_request_received', {
          id: existingReq._id.toString(),
          senderId: userId.toString(),
          name: senderAcc?.username || '',
          avatar: senderAcc?.avatar || '',
          bio: senderAcc?.bio || '',
          type: 'friend',
          mutualFriends: 0,
          time: 'Just now',
        });
      }

      return res.status(200).json({
        success: true,
        message: 'Friend request sent',
        request: existingReq
      });
    }

    const request = new Request({
      sender: userId,
      receiver: targetReceiverId,
      type: 'friend',
      status: 'pending',
      group: null,
    });

    await request.save();

    await createNotification({
      recipient: targetReceiverId,
      sender: userId,
      type: 'friend_request',
      request: request._id,
      status: 'pending',
      content: 'sent you a friend request'
    });

    const io = getIO ? getIO() : null;
    if (io) {
      io.to(targetReceiverId.toString()).emit('friend_request_received', {
        id: request._id.toString(),
        senderId: userId.toString(),
        name: senderAcc?.username || '',
        avatar: senderAcc?.avatar || '',
        bio: senderAcc?.bio || '',
        type: 'friend',
        mutualFriends: 0,
        time: 'Just now',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Friend request sent',
      request
    });
  } catch (error) {
    console.error('sendFriendRequest error:', error);
    return res.status(500).json({ success: false, code: 'SEND_FRIEND_REQUEST_FAILED', message: error.message || 'Failed to send friend request' });
  }
};

const cancelSendFriendRequest = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { receiverId, requestId } = req.body;

    let query = { sender: userId, type: 'friend', status: 'pending' };
    if (requestId) {
      query._id = requestId;
    } else if (receiverId) {
      query.receiver = receiverId;
    }

    let targetRecId = receiverId;
    if (!targetRecId && requestId) {
      const found = await Request.findById(requestId);
      if (found) targetRecId = found.receiver?.toString();
    }

    await Request.deleteMany(query);

    if (targetRecId) {
      await Notification.deleteMany({
        recipient: targetRecId,
        sender: userId,
        type: 'friend_request'
      });
    }

    const io = getIO ? getIO() : null;
    if (io && targetRecId) {
      io.to(targetRecId.toString()).emit('friend_request_cancelled', {
        senderId: userId.toString(),
        requestId: requestId || '',
      });
    }

    return res.status(200).json({ success: true, message: 'Friend request cancelled' });
  } catch (error) {
    console.error('cancelSendFriendRequest error:', error);
    return res.status(500).json({ success: false, code: 'CANCEL_REQUEST_FAILED', message: error.message || 'Failed to cancel request' });
  }
};

const acceptFriendRequest = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { requestId, senderId } = req.body;

    let request;
    if (requestId) {
      request = await Request.findById(requestId);
    } else if (senderId && userId) {
      request = await Request.findOne({ sender: senderId, receiver: userId, type: 'friend', status: 'pending' });
    }

    if (!request) {
      return res.status(404).json({ success: false, code: 'REQUEST_NOT_FOUND', message: 'Request not found' });
    }

    request.status = 'accepted';
    await request.save();

    await Account.findByIdAndUpdate(request.receiver, {
      $addToSet: { friends: request.sender }
    });
    const receiverAcc = await Account.findById(request.receiver);
    receiverAcc.friendsCount = receiverAcc.friends.length;
    await receiverAcc.save();

    await Account.findByIdAndUpdate(request.sender, {
      $addToSet: { friends: request.receiver }
    });
    const senderAcc = await Account.findById(request.sender);
    senderAcc.friendsCount = senderAcc.friends.length;
    await senderAcc.save();

    await Notification.updateMany(
      {
        recipient: request.receiver,
        $or: [
          { request: request._id },
          { sender: request.sender, type: 'friend_request' }
        ]
      },
      { status: 'accepted', isRead: true }
    );

    await createNotification({
      recipient: request.sender,
      sender: request.receiver,
      type: 'friend_accept',
      content: 'accepted your friend request'
    });

    const receiverShowActive = receiverAcc?.privacy?.showActiveStatus !== false;
    const senderShowActive = senderAcc?.privacy?.showActiveStatus !== false;
    const senderOnline = senderShowActive ? isUserOnline(request.sender.toString()) : false;
    const receiverOnline = receiverShowActive ? isUserOnline(request.receiver.toString()) : false;

    const io = getIO ? getIO() : null;
    if (io) {
      io.to(request.sender.toString()).emit('friend_request_accepted', {
        userId: request.receiver.toString(),
        name: receiverAcc?.username || '',
        avatar: receiverAcc?.avatar || '',
        bio: receiverAcc?.bio || '',
        showActiveStatus: receiverShowActive,
        online: receiverOnline,
        requestId: request._id.toString(),
        friendsCount: senderAcc.friendsCount,
      });
      io.to(request.receiver.toString()).emit('friend_request_accepted', {
        userId: request.sender.toString(),
        name: senderAcc?.username || '',
        avatar: senderAcc?.avatar || '',
        bio: senderAcc?.bio || '',
        showActiveStatus: senderShowActive,
        online: senderOnline,
        requestId: request._id.toString(),
        friendsCount: receiverAcc.friendsCount,
      });
      io.to(request.sender.toString()).emit('stats_updated', {
        friendsCount: senderAcc.friendsCount,
      });
      io.to(request.receiver.toString()).emit('stats_updated', {
        friendsCount: receiverAcc.friendsCount,
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Friend request accepted successfully',
      requestId: request._id,
      friend: {
        id: request.sender.toString(),
        showActiveStatus: senderShowActive,
        online: senderOnline,
      },
    });
  } catch (error) {
    console.error('acceptFriendRequest error:', error);
    return res.status(500).json({ success: false, code: 'ACCEPT_FRIEND_FAILED', message: error.message || 'Failed to accept friend request' });
  }
};

const rejectFriendRequest = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { requestId, senderId } = req.body;

    let request;
    if (requestId) {
      request = await Request.findById(requestId);
    } else if (senderId && userId) {
      request = await Request.findOne({ sender: senderId, receiver: userId, type: 'friend' });
    }

    if (!request) {
      return res.status(404).json({ success: false, code: 'REQUEST_NOT_FOUND', message: 'Request not found' });
    }

    const actualSenderId = request.sender.toString();
    const reqId = request._id.toString();

    await Request.findByIdAndDelete(request._id);

    await Notification.updateMany(
      {
        recipient: userId,
        $or: [
          { request: reqId },
          { sender: actualSenderId, type: 'friend_request' }
        ]
      },
      { status: 'declined', isRead: true }
    );

    const io = getIO ? getIO() : null;
    if (io) {
      io.to(actualSenderId).emit('friend_request_rejected', {
        receiverId: userId.toString(),
        requestId: reqId,
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Friend request declined',
      requestId: reqId
    });
  } catch (error) {
    console.error('rejectFriendRequest error:', error);
    return res.status(500).json({ success: false, code: 'REJECT_FRIEND_FAILED', message: error.message || 'Failed to reject friend request' });
  }
};

const acceptGroupInvite = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { requestId, groupId } = req.body;

    let request;
    if (requestId) {
      request = await Request.findById(requestId).populate('group');
    } else if (groupId && userId) {
      request = await Request.findOne({ group: groupId, receiver: userId, status: 'pending' }).populate('group');
    }

    if (!request || !request.group) {
      return res.status(404).json({ success: false, code: 'INVITE_NOT_FOUND', message: 'Group invite not found' });
    }

    request.status = 'accepted';
    await request.save();

    await Group.findByIdAndUpdate(request.group._id, {
      $addToSet: { members: { user: userId, role: 'member', joinedAt: new Date() } }
    });
    const updatedGrp = await Group.findById(request.group._id);
    updatedGrp.membersCount = updatedGrp.members.length;
    await updatedGrp.save();

    return res.status(200).json({
      success: true,
      message: 'Joined group successfully',
      group: updatedGrp
    });
  } catch (error) {
    console.error('acceptGroupInvite error:', error);
    return res.status(500).json({ success: false, code: 'JOIN_GROUP_FAILED', message: error.message || 'Failed to join group' });
  }
};

const rejectGroupInvite = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { requestId, groupId } = req.body;

    let request;
    if (requestId) {
      request = await Request.findById(requestId);
    } else if (groupId && userId) {
      request = await Request.findOne({ group: groupId, receiver: userId, status: 'pending' });
    }

    if (!request) {
      return res.status(404).json({ success: false, code: 'INVITE_NOT_FOUND', message: 'Invite not found' });
    }

    await Request.findByIdAndDelete(request._id);

    return res.status(200).json({
      success: true,
      message: 'Group invitation declined',
      requestId: request._id
    });
  } catch (error) {
    console.error('rejectGroupInvite error:', error);
    return res.status(500).json({ success: false, code: 'REJECT_INVITE_FAILED', message: error.message || 'Failed to reject group invite' });
  }
};

const removeFriend = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { friendId } = req.body;

    if (!userId || !friendId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and friendId are required' });
    }

    await Account.findByIdAndUpdate(userId, {
      $pull: { friends: friendId }
    });
    const acc1 = await Account.findById(userId);
    acc1.friendsCount = acc1.friends.length;
    await acc1.save();

    await Account.findByIdAndUpdate(friendId, {
      $pull: { friends: userId }
    });
    const acc2 = await Account.findById(friendId);
    acc2.friendsCount = acc2.friends.length;
    await acc2.save();

    await Request.deleteMany({
      $or: [
        { sender: userId, receiver: friendId, type: 'friend' },
        { sender: friendId, receiver: userId, type: 'friend' }
      ]
    });

    const io = getIO ? getIO() : null;
    if (io) {
      io.to(friendId.toString()).emit('friend_removed', {
        userId: userId.toString(),
        friendsCount: acc2.friendsCount,
      });
      io.to(userId.toString()).emit('friend_removed', {
        userId: friendId.toString(),
        friendsCount: acc1.friendsCount,
      });
      io.to(friendId.toString()).emit('stats_updated', {
        friendsCount: acc2.friendsCount,
      });
      io.to(userId.toString()).emit('stats_updated', {
        friendsCount: acc1.friendsCount,
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Friend removed successfully'
    });
  } catch (error) {
    console.error('removeFriend error:', error);
    return res.status(500).json({ success: false, code: 'REMOVE_FRIEND_FAILED', message: error.message || 'Failed to remove friend' });
  }
};

const followAccount = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { targetUserId } = req.body;

    if (!userId || !targetUserId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and targetUserId are required' });
    }

    if (userId.toString() === targetUserId.toString()) {
      return res.status(400).json({ success: false, code: 'CANNOT_FOLLOW_SELF', message: 'Cannot follow yourself' });
    }

    const targetAcc = await Account.findById(targetUserId);
    if (!targetAcc) {
      return res.status(404).json({ success: false, code: 'USER_NOT_FOUND', message: 'Target user not found' });
    }

    const currentAcc = await Account.findById(userId);

    if (targetAcc.isPrivate) {
      const isAlreadyFollowing = Array.isArray(targetAcc.followers) &&
        targetAcc.followers.some(f => f.toString() === userId.toString());
      if (isAlreadyFollowing) {
        return res.status(200).json({
          success: true,
          isFollowing: true,
          message: 'You are already following this user'
        });
      }

      const existingRequest = await Request.findOne({
        sender: userId,
        receiver: targetUserId,
        type: 'follow',
        status: 'pending'
      });

      if (existingRequest) {
        return res.status(200).json({
          success: true,
          isPending: true,
          message: 'Follow request already sent',
          requestId: existingRequest._id.toString()
        });
      }

      const newReq = await Request.create({
        sender: userId,
        receiver: targetUserId,
        type: 'follow',
        status: 'pending'
      });

      await createNotification({
        recipient: targetUserId,
        sender: userId,
        type: 'follow',
        content: 'sent you a follow request'
      });

      const io = getIO ? getIO() : null;
      if (io) {
        io.to(targetUserId.toString()).emit('follow_request_received', {
          requestId: newReq._id.toString(),
          sender: {
            id: currentAcc._id.toString(),
            name: currentAcc.username,
            avatar: currentAcc.avatar,
          }
        });
      }

      return res.status(200).json({
        success: true,
        isPending: true,
        message: 'Follow request sent',
        requestId: newReq._id.toString()
      });
    }

    const updatedCurrentAcc = await Account.findByIdAndUpdate(
      userId,
      { $addToSet: { following: targetUserId } },
      { new: true }
    );
    if (updatedCurrentAcc) {
      updatedCurrentAcc.followingCount = (updatedCurrentAcc.following || []).length;
      await updatedCurrentAcc.save();
    }

    const updatedTargetAcc = await Account.findByIdAndUpdate(
      targetUserId,
      { $addToSet: { followers: userId } },
      { new: true }
    );
    if (updatedTargetAcc) {
      updatedTargetAcc.followersCount = (updatedTargetAcc.followers || []).length;
      await updatedTargetAcc.save();
    }

    await createNotification({
      recipient: targetUserId,
      sender: userId,
      type: 'follow',
      content: 'started following you'
    });

    const io = getIO ? getIO() : null;
    if (io && updatedCurrentAcc && updatedTargetAcc) {
      // 1. Gửi socket cho người được theo dõi (targetUserId)
      io.to(targetUserId.toString()).emit('follower_added', {
        user: {
          id: updatedCurrentAcc._id.toString(),
          name: updatedCurrentAcc.username,
          avatar: updatedCurrentAcc.avatar,
          handle: `@${(updatedCurrentAcc.username || '').toLowerCase().replace(/\s+/g, '_')}`,
          bio: updatedCurrentAcc.bio || '',
          isFollowing: updatedTargetAcc?.following?.some(f => f.toString() === userId.toString()) || false,
        },
        followersCount: updatedTargetAcc.followersCount,
      });

      // 2. Gửi socket cho chính người bấm theo dõi (userId) để cập nhật ngay tab Đã theo dõi
      io.to(userId.toString()).emit('following_added', {
        user: {
          id: updatedTargetAcc._id.toString(),
          name: updatedTargetAcc.username,
          avatar: updatedTargetAcc.avatar,
          handle: `@${(updatedTargetAcc.username || '').toLowerCase().replace(/\s+/g, '_')}`,
          bio: updatedTargetAcc.bio || '',
          isFollowing: true,
        },
        followingCount: updatedCurrentAcc.followingCount,
      });

      io.to(targetUserId.toString()).emit('stats_updated', {
        followersCount: updatedTargetAcc.followersCount,
      });
      io.to(userId.toString()).emit('stats_updated', {
        followingCount: updatedCurrentAcc.followingCount,
      });
    }

    return res.status(200).json({
      success: true,
      isFollowing: true,
      message: 'Followed successfully'
    });
  } catch (error) {
    console.error('followAccount error:', error);
    return res.status(500).json({ success: false, code: 'FOLLOW_FAILED', message: error.message || 'Failed to follow user' });
  }
};

const unfollowAccount = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { targetUserId } = req.body;

    if (!userId || !targetUserId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and targetUserId are required' });
    }

    await Request.deleteMany({
      sender: userId,
      receiver: targetUserId,
      type: 'follow',
      status: 'pending'
    });

    await Account.findByIdAndUpdate(userId, {
      $pull: { following: targetUserId }
    });
    const currentAcc = await Account.findById(userId);
    if (currentAcc) {
      currentAcc.followingCount = (currentAcc.following || []).length;
      await currentAcc.save();
    }

    await Account.findByIdAndUpdate(targetUserId, {
      $pull: { followers: userId }
    });
    const targetAcc = await Account.findById(targetUserId);
    if (targetAcc) {
      targetAcc.followersCount = (targetAcc.followers || []).length;
      await targetAcc.save();
    }

    const io = getIO ? getIO() : null;
    if (io && targetAcc) {
      io.to(targetUserId.toString()).emit('follower_removed', {
        userId: userId.toString(),
        followersCount: targetAcc.followersCount,
      });
      io.to(userId.toString()).emit('following_removed', {
        userId: targetUserId.toString(),
        followingCount: currentAcc ? currentAcc.followingCount : 0,
      });
      io.to(targetUserId.toString()).emit('stats_updated', {
        followersCount: targetAcc.followersCount,
      });
      if (currentAcc) {
        io.to(userId.toString()).emit('stats_updated', {
          followingCount: currentAcc.followingCount,
        });
      }
    }

    return res.status(200).json({
      success: true,
      isFollowing: false,
      isPending: false,
      message: 'Unfollowed successfully'
    });
  } catch (error) {
    console.error('unfollowAccount error:', error);
    return res.status(500).json({ success: false, code: 'UNFOLLOW_FAILED', message: error.message || 'Failed to unfollow user' });
  }
};

const acceptFollowRequest = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { requestId } = req.body;

    if (!userId || !requestId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and requestId are required' });
    }

    const request = await Request.findOne({
      _id: requestId,
      receiver: userId,
      type: 'follow',
      status: 'pending'
    });

    if (!request) {
      return res.status(404).json({ success: false, code: 'REQUEST_NOT_FOUND', message: 'Follow request not found or already processed' });
    }

    const senderId = request.sender;

    await Account.findByIdAndUpdate(userId, {
      $addToSet: { followers: senderId }
    });
    const receiverAcc = await Account.findById(userId);
    receiverAcc.followersCount = (receiverAcc.followers || []).length;
    await receiverAcc.save();

    await Account.findByIdAndUpdate(senderId, {
      $addToSet: { following: userId }
    });
    const senderAcc = await Account.findById(senderId);
    if (senderAcc) {
      senderAcc.followingCount = (senderAcc.following || []).length;
      await senderAcc.save();
    }

    request.status = 'accepted';
    await request.save();

    await createNotification({
      recipient: senderId,
      sender: userId,
      type: 'follow',
      content: 'accepted your follow request'
    });

    const io = getIO ? getIO() : null;
    if (io) {
      io.to(senderId.toString()).emit('follow_request_accepted', {
        user: {
          id: receiverAcc._id.toString(),
          name: receiverAcc.username,
          avatar: receiverAcc.avatar,
        }
      });
      io.to(senderId.toString()).emit('following_added', {
        user: {
          id: receiverAcc._id.toString(),
          name: receiverAcc.username,
          avatar: receiverAcc.avatar,
          handle: `@${(receiverAcc.username || '').toLowerCase().replace(/\s+/g, '_')}`,
          bio: receiverAcc.bio || '',
          isFollowing: true,
        },
        followingCount: senderAcc ? senderAcc.followingCount : 1,
      });
      if (senderAcc) {
        io.to(userId.toString()).emit('follower_added', {
          user: {
            id: senderAcc._id.toString(),
            name: senderAcc.username,
            avatar: senderAcc.avatar,
            handle: `@${(senderAcc.username || '').toLowerCase().replace(/\s+/g, '_')}`,
            bio: senderAcc.bio || '',
            isFollowing: receiverAcc?.following?.some(f => f.toString() === senderId.toString()) || false,
          },
          followersCount: receiverAcc.followersCount,
        });
      }
      io.to(userId.toString()).emit('stats_updated', {
        followersCount: receiverAcc.followersCount,
      });
      if (senderAcc) {
        io.to(senderId.toString()).emit('stats_updated', {
          followingCount: senderAcc.followingCount,
        });
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Follow request accepted'
    });
  } catch (error) {
    console.error('acceptFollowRequest error:', error);
    return res.status(500).json({ success: false, code: 'ACCEPT_FOLLOW_FAILED', message: error.message || 'Failed to accept follow request' });
  }
};

const rejectFollowRequest = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { requestId } = req.body;

    if (!userId || !requestId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and requestId are required' });
    }

    const request = await Request.findOne({
      _id: requestId,
      receiver: userId,
      type: 'follow',
      status: 'pending'
    });

    if (!request) {
      return res.status(404).json({ success: false, code: 'REQUEST_NOT_FOUND', message: 'Follow request not found' });
    }

    request.status = 'rejected';
    await request.save();

    return res.status(200).json({
      success: true,
      message: 'Follow request declined'
    });
  } catch (error) {
    console.error('rejectFollowRequest error:', error);
    return res.status(500).json({ success: false, code: 'REJECT_FOLLOW_FAILED', message: error.message || 'Failed to decline follow request' });
  }
};

module.exports = { 
  getContacts,
  sendFriendRequest,
  cancelSendFriendRequest,
  acceptFriendRequest,
  rejectFriendRequest,
  acceptGroupInvite,
  rejectGroupInvite,
  removeFriend,
  followAccount,
  unfollowAccount,
  acceptFollowRequest,
  rejectFollowRequest,
};