const Group = require('../models/group.model');
const Conversation = require('../models/conversation.model');
const Request = require('../models/request.model');
const Notification = require('../models/notification.model');
const Account = require('../models/account.model');
const mongoose = require('mongoose');
const crypto = require('crypto');
const { verifyToken } = require('../config/jwt.config');
const { getIO, isUserOnline } = require('../socket');
const { generateGroupQRCode } = require('../services/qrcode.service');

const getUserIdFromReq = (req) => {
  let userId = req.body?.userId || req.query?.userId || req.user?.id || req.user?._id;
  if (!userId && req.headers?.authorization) {
    try {
      const token = req.headers.authorization.replace('Bearer ', '').trim();
      const decoded = verifyToken(token);
      if (decoded && (decoded.id || decoded.userId || decoded._id)) {
        userId = decoded.id || decoded.userId || decoded._id;
      }
    } catch (_) {}
  }
  return userId ? userId.toString() : null;
};

const createGroup = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { name, avatar, coverImage, description, privacy, memberIds } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, code: 'GROUP_NAME_REQUIRED', message: 'Group name is required' });
    }

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in to create group' });
    }

    const validPrivacies = ['public', 'private', 'secret'];
    const groupPrivacy = validPrivacies.includes(privacy) ? privacy : 'public';

    let joinPolicy = 'open';
    if (groupPrivacy === 'private') {
      joinPolicy = 'approval';
    } else if (groupPrivacy === 'secret') {
      joinPolicy = 'invite_only';
    }

    const members = [{ user: userId, role: 'owner', joinedAt: new Date() }];
    if (Array.isArray(memberIds)) {
      memberIds.forEach((mId) => {
        if (mId && mId.toString() !== userId.toString()) {
          members.push({ user: mId, role: 'member', joinedAt: new Date() });
        }
      });
    }

    const inviteCode = crypto.randomBytes(6).toString('hex');

    const group = new Group({
      name: name.trim(),
      avatar: avatar || '',
      coverImage: coverImage || '',
      description: description || (
        groupPrivacy === 'public'
          ? 'Viora Public Group - Anyone can join'
          : groupPrivacy === 'private'
          ? 'Viora Private Group - Requires approval to join'
          : 'Viora Secret Group - Only for invited members'
      ),
      owner: userId,
      members,
      membersCount: members.length,
      privacy: groupPrivacy,
      inviteCode,
      inviteLink: `viora://group/join?code=${inviteCode}`,
      settings: {
        privacy: groupPrivacy,
        joinPolicy,
        postPolicy: 'open',
        allowMemberInvite: true,
        memberLimit: 0,
      },
    });

    await group.save();

    const convMembers = members.map((m) => ({
      user: m.user,
      role: m.role === 'owner' ? 'admin' : 'member',
      joinedAt: m.joinedAt || new Date(),
    }));

    const conversation = new Conversation({
      type: 'group_chat',
      name: group.name,
      avatar: group.avatar || '',
      members: convMembers,
      communityGroup: group._id,
    });
    await conversation.save();

    group.chatConversation = conversation._id;
    await group.save();

    try {
      const qrCodeUrl = await generateGroupQRCode(group._id.toString(), group.name);
      if (qrCodeUrl) {
        group.qrCode = qrCodeUrl;
        await group.save();
      }
    } catch (qrErr) {
      console.error('Failed to generate automatic QR for group:', qrErr);
    }

    if (Array.isArray(memberIds) && memberIds.length > 0) {
      const io = getIO ? getIO() : null;
      for (const mId of memberIds) {
        if (mId && mId.toString() !== userId.toString()) {
          try {
            await Notification.create({
              recipient: mId,
              sender: userId,
              type: 'group_invite',
              group: group._id,
              content: `added you to group "${group.name}"`,
            });
            if (io) {
              io.to(mId.toString()).emit('group_invite_received', {
                groupId: group._id.toString(),
                groupName: group.name,
                avatar: group.avatar,
                privacy: group.privacy,
                senderId: userId,
              });
            }
          } catch (_) {}
        }
      }
    }

    const getAvatarInitials = (gName) => {
      if (!gName) return 'GR';
      const parts = gName.trim().split(' ');
      if (parts.length >= 2) return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
      return gName.substring(0, 2).toUpperCase();
    };

    return res.status(201).json({
      success: true,
      message: 'Group created successfully',
      group: {
        id: group._id.toString(),
        conversationId: conversation._id.toString(),
        name: group.name,
        avatar: group.avatar || getAvatarInitials(group.name),
        color: '#2563EB',
        membersCount: group.membersCount,
        privacy: group.privacy,
        description: group.description,
        isMember: true,
        role: 'owner',
        qrCode: group.qrCode || '',
      },
    });
  } catch (error) {
    console.error('createGroup error:', error);
    return res.status(500).json({ success: false, code: 'CREATE_GROUP_FAILED', message: error.message || 'Failed to create group' });
  }
};

const getUserGroups = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User ID is required' });
    }

    const groups = await Group.find({
      $or: [{ owner: userId }, { 'members.user': userId }],
    })
      .sort({ updatedAt: -1 })
      .populate('owner', 'username avatar email');

    const getAvatarInitials = (gName) => {
      if (!gName) return 'GR';
      const parts = gName.trim().split(' ');
      if (parts.length >= 2) return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
      return gName.substring(0, 2).toUpperCase();
    };

    const formattedGroups = groups.map((g) => {
      const myMember = g.members?.find((m) => m.user?.toString() === userId.toString());
      const role = g.owner?._id?.toString() === userId.toString() ? 'owner' : (myMember?.role || 'member');

      return {
        id: g._id.toString(),
        conversationId: g.chatConversation ? g.chatConversation.toString() : null,
        name: g.name,
        avatar: (g.avatar && g.avatar.startsWith('http')) ? g.avatar : getAvatarInitials(g.name),
        coverImage: g.coverImage || '',
        color: '#2563EB',
        membersCount: g.membersCount || (g.members ? g.members.length : 1),
        privacy: g.privacy || g.settings?.privacy || 'public',
        description: g.description || '',
        role,
        isMember: true,
        pendingRequestsCount: role === 'owner' || role === 'admin' ? (g.joinRequests?.length || 0) : 0,
        lastMessage: g.description || 'Viora Chat Group',
        time: 'Recently',
        qrCode: g.qrCode || '',
      };
    });

    return res.status(200).json({
      success: true,
      groups: formattedGroups,
    });
  } catch (error) {
    console.error('getUserGroups error:', error);
    return res.status(500).json({ success: false, code: 'GET_GROUPS_FAILED', message: error.message || 'Failed to fetch groups' });
  }
};

const getDiscoverGroups = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);

    const query = {
      $or: [
        { privacy: { $in: ['public', 'private'] } },
        { 'settings.privacy': { $in: ['public', 'private'] } },
      ],
    };

    const groups = await Group.find(query)
      .sort({ membersCount: -1, createdAt: -1 })
      .limit(30)
      .populate('owner', 'username avatar');

    const getAvatarInitials = (gName) => {
      if (!gName) return 'GR';
      const parts = gName.trim().split(' ');
      if (parts.length >= 2) return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
      return gName.substring(0, 2).toUpperCase();
    };

    const formatted = groups.map((g) => {
      const isMember = userId ? (
        g.owner?._id?.toString() === userId.toString() ||
        g.members?.some((m) => m.user?.toString() === userId.toString())
      ) : false;

      const hasRequested = userId ? (
        g.joinRequests?.some((r) => r.user?.toString() === userId.toString())
      ) : false;

      return {
        id: g._id.toString(),
        name: g.name,
        avatar: (g.avatar && g.avatar.startsWith('http')) ? g.avatar : getAvatarInitials(g.name),
        coverImage: g.coverImage || '',
        description: g.description || '',
        privacy: g.privacy || g.settings?.privacy || 'public',
        membersCount: g.membersCount || (g.members ? g.members.length : 1),
        isMember,
        hasRequested,
        qrCode: g.qrCode || '',
        owner: {
          id: g.owner?._id?.toString(),
          name: g.owner?.username || 'User',
          avatar: g.owner?.avatar,
        },
      };
    });

    return res.status(200).json({
      success: true,
      groups: formatted,
    });
  } catch (error) {
    console.error('getDiscoverGroups error:', error);
    return res.status(500).json({ success: false, code: 'EXPLORE_GROUPS_FAILED', message: 'Failed to explore groups' });
  }
};

const searchGroups = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const search = (req.query.q || req.query.query || '').trim();

    if (!search) {
      return res.status(200).json({ success: true, groups: [] });
    }

    const regex = new RegExp(search, 'i');
    const matchText = {
      $or: [
        { name: regex },
        { description: regex },
      ],
    };

    const queryConditions = [
      {
        ...matchText,
        privacy: { $in: ['public', 'private'] },
      },
    ];

    if (userId) {
      queryConditions.push({
        ...matchText,
        privacy: 'secret',
        $or: [
          { owner: userId },
          { 'members.user': userId },
        ],
      });
    }

    const groups = await Group.find({ $or: queryConditions })
      .sort({ membersCount: -1 })
      .limit(20)
      .populate('owner', 'username avatar');

    const getAvatarInitials = (gName) => {
      if (!gName) return 'GR';
      const parts = gName.trim().split(' ');
      if (parts.length >= 2) return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
      return gName.substring(0, 2).toUpperCase();
    };

    const formatted = groups.map((g) => {
      const isMember = userId ? (
        g.owner?._id?.toString() === userId.toString() ||
        g.members?.some((m) => m.user?.toString() === userId.toString())
      ) : false;

      const hasRequested = userId ? (
        g.joinRequests?.some((r) => r.user?.toString() === userId.toString())
      ) : false;

      return {
        id: g._id.toString(),
        name: g.name,
        avatar: (g.avatar && g.avatar.startsWith('http')) ? g.avatar : getAvatarInitials(g.name),
        coverImage: g.coverImage || '',
        description: g.description || '',
        privacy: g.privacy || g.settings?.privacy || 'public',
        membersCount: g.membersCount || (g.members ? g.members.length : 1),
        isMember,
        hasRequested,
        qrCode: g.qrCode || '',
        conversationId: g.chatConversation ? g.chatConversation.toString() : null,
        owner: {
          id: g.owner?._id?.toString(),
          name: g.owner?.username || 'User',
          avatar: g.owner?.avatar,
        },
      };
    });

    return res.status(200).json({
      success: true,
      groups: formatted,
    });
  } catch (error) {
    console.error('searchGroups error:', error);
    return res.status(500).json({ success: false, code: 'SEARCH_GROUPS_FAILED', message: 'Failed to search groups' });
  }
};

const getGroupDetail = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserIdFromReq(req);

    let group = null;
    if (mongoose.Types.ObjectId.isValid(id)) {
      group = await Group.findOne({
        $or: [{ _id: id }, { chatConversation: id }]
      })
        .populate('owner', 'username avatar email bio isOnline')
        .populate('members.user', 'username avatar email bio isOnline')
        .populate('joinRequests.user', 'username avatar email');

      if (!group) {
        const conv = await Conversation.findById(id).select('communityGroup members name avatar type');
        if (conv?.communityGroup) {
          group = await Group.findById(conv.communityGroup)
            .populate('owner', 'username avatar email bio isOnline')
            .populate('members.user', 'username avatar email bio isOnline')
            .populate('joinRequests.user', 'username avatar email');
        } else if (conv && conv.type === 'group_chat') {
          await conv.populate('members.user', 'username avatar email bio isOnline privacy');
          const formattedMembers = (conv.members || []).map((m) => {
            const mId = m.user?._id?.toString() || m.user?.toString();
            const mShowActive = m.user?.privacy?.showActiveStatus !== false;
            return {
              id: mId,
              name: m.user?.username || 'Member',
              avatar: m.user?.avatar || '',
              role: m.role || 'member',
              showActiveStatus: mShowActive,
              isOnline: (mShowActive && mId) ? isUserOnline(mId) : false,
              joinedAt: m.joinedAt || new Date(),
            };
          });
          return res.status(200).json({
            success: true,
            group: {
              id: conv._id.toString(),
              name: conv.name || 'Chat Group',
              avatar: conv.avatar || '',
              membersCount: formattedMembers.length,
              members: formattedMembers,
              privacy: 'private',
              role: 'member',
              qrCode: JSON.stringify({
                type: 'group',
                groupId: conv._id.toString(),
                name: conv.name || 'Chat Group',
                privacy: 'private',
              }),
            },
          });
        }
      }
    }

    if (!group) {
      return res.status(404).json({ success: false, code: 'GROUP_NOT_FOUND', message: 'Group not found' });
    }

    if (!group.qrCode) {
      try {
        const qrCodeUrl = await generateGroupQRCode(group._id.toString(), group.name);
        if (qrCodeUrl) {
          group.qrCode = qrCodeUrl;
          await group.save();
        }
      } catch (qrErr) {
        console.error('Failed to auto-generate group QR code in getGroupDetail:', qrErr);
      }
    }

    const groupPrivacy = group.privacy || group.settings?.privacy || 'public';

    const isOwner = userId && group.owner?._id?.toString() === userId.toString();
    const myMember = userId && group.members?.find((m) => m.user?._id?.toString() === userId.toString());
    const isMember = !!(isOwner || myMember);
    const role = isOwner ? 'owner' : (myMember?.role || null);
    const isAdmin = isOwner || role === 'admin';

    if (groupPrivacy === 'secret' && !isMember) {

      const hasInvite = userId ? await Request.findOne({ group: group._id, receiver: userId, status: 'pending' }) : null;
      if (!hasInvite) {
        return res.status(403).json({
          success: false,
          code: 'SECRET_GROUP_FORBIDDEN',
          message: 'This is a secret group. Only invited members can view its details.',
          isSecret: true,
        });
      }
    }

    const hasRequested = userId ? group.joinRequests?.some((r) => r.user?._id?.toString() === userId.toString()) : false;

    const formattedMembers = isMember || groupPrivacy === 'public'
      ? (group.members || []).map((m) => ({
          id: m.user?._id?.toString(),
          name: m.user?.username || 'Member',
          avatar: m.user?.avatar,
          role: m.role,
          joinedAt: m.joinedAt,
        }))
      : [];

    const formattedRequests = isAdmin
      ? (group.joinRequests || []).map((r) => ({
          userId: r.user?._id?.toString(),
          name: r.user?.username || 'User',
          avatar: r.user?.avatar,
          message: r.message,
          requestedAt: r.requestedAt,
        }))
      : [];

    return res.status(200).json({
      success: true,
      group: {
        id: group._id.toString(),
        conversationId: group.chatConversation ? group.chatConversation.toString() : null,
        name: group.name,
        avatar: group.avatar,
        coverImage: group.coverImage,
        description: group.description,
        privacy: groupPrivacy,
        membersCount: group.membersCount || group.members?.length || 1,
        isMember,
        role,
        isAdmin,
        hasRequested,
        pendingRequestsCount: formattedRequests.length,
        members: formattedMembers,
        joinRequests: formattedRequests,
        qrCode: group.qrCode || '',
        owner: {
          id: group.owner?._id?.toString(),
          name: group.owner?.username || 'Owner',
          avatar: group.owner?.avatar,
        },
        createdAt: group.createdAt,
      },
    });
  } catch (error) {
    console.error('getGroupDetail error:', error);
    return res.status(500).json({ success: false, code: 'GET_GROUP_FAILED', message: 'Failed to get group information' });
  }
};

const joinGroup = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserIdFromReq(req);

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }

    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({ success: false, code: 'GROUP_NOT_FOUND', message: 'Group not found' });
    }

    const isMember = group.members.some((m) => m.user.toString() === userId.toString());
    if (isMember) {
      return res.status(400).json({ success: false, code: 'ALREADY_MEMBER', message: 'You are already a member of this group' });
    }

    const groupPrivacy = group.privacy || group.settings?.privacy || 'public';

    if (groupPrivacy === 'private') {
      return res.status(403).json({
        success: false,
        code: 'PRIVATE_GROUP_REQUEST_REQUIRED',
        needRequest: true,
        message: 'This group is private. Please send a join request for admin approval!',
      });
    }

    if (groupPrivacy === 'secret') {
      return res.status(403).json({
        success: false,
        code: 'SECRET_GROUP_INVITE_ONLY',
        isSecret: true,
        message: 'This group is secret. You can only join by invitation from an existing member!',
      });
    }

    group.members.push({ user: userId, role: 'member', joinedAt: new Date() });
    group.membersCount = group.members.length;
    await group.save();

    if (group.chatConversation) {
      await Conversation.findByIdAndUpdate(group.chatConversation, {
        $addToSet: {
          members: { user: userId, role: 'member', joinedAt: new Date() },
        },
      });
    }

    const io = getIO ? getIO() : null;
    if (io) {
      io.to(`group_${group._id}`).emit('member_joined', {
        groupId: group._id.toString(),
        userId,
        membersCount: group.membersCount,
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Welcome to the public group!',
      isMember: true,
      membersCount: group.membersCount,
    });
  } catch (error) {
    console.error('joinGroup error:', error);
    return res.status(500).json({ success: false, code: 'JOIN_GROUP_FAILED', message: 'Failed to join group' });
  }
};

const requestJoinGroup = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserIdFromReq(req);
    const { message } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }

    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({ success: false, code: 'GROUP_NOT_FOUND', message: 'Group not found' });
    }

    const isMember = group.members.some((m) => m.user.toString() === userId.toString());
    if (isMember) {
      return res.status(400).json({ success: false, code: 'ALREADY_MEMBER', message: 'You are already a member of this group' });
    }

    const groupPrivacy = group.privacy || group.settings?.privacy || 'public';
    if (groupPrivacy === 'secret') {
      return res.status(403).json({
        success: false,
        code: 'SECRET_GROUP_NO_REQUESTS',
        message: 'Secret groups do not accept join requests. You must be invited.',
      });
    }

    const alreadyRequested = group.joinRequests.some((r) => r.user.toString() === userId.toString());
    if (alreadyRequested) {
      return res.status(400).json({ success: false, code: 'REQUEST_ALREADY_SENT', message: 'Join request already sent, please wait for admin approval!' });
    }

    group.joinRequests.push({
      user: userId,
      message: message || 'Requesting to join group',
      requestedAt: new Date(),
    });
    await group.save();

    await Request.findOneAndUpdate(
      { sender: userId, receiver: group.owner, group: group._id, type: 'group_join' },
      { status: 'pending' },
      { upsert: true, new: true }
    );

    const userAcc = await Account.findById(userId).select('username avatar');
    await Notification.create({
      recipient: group.owner,
      sender: userId,
      type: 'group_join',
      group: group._id,
      content: `requested to join group "${group.name}"`,
    });

    const io = getIO ? getIO() : null;
    if (io) {
      io.to(group.owner.toString()).emit('group_join_request_received', {
        groupId: group._id.toString(),
        groupName: group.name,
        user: {
          id: userId,
          name: userAcc?.username || 'User',
          avatar: userAcc?.avatar,
        },
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Join request sent successfully! Please wait for admin approval.',
      hasRequested: true,
    });
  } catch (error) {
    console.error('requestJoinGroup error:', error);
    return res.status(500).json({ success: false, code: 'SEND_JOIN_REQUEST_FAILED', message: 'Failed to send join request' });
  }
};

const cancelJoinRequest = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserIdFromReq(req);

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }

    await Group.findByIdAndUpdate(id, {
      $pull: { joinRequests: { user: userId } },
    });

    await Request.findOneAndDelete({
      sender: userId,
      group: id,
      type: 'group_join',
    });

    return res.status(200).json({
      success: true,
      message: 'Join request cancelled',
      hasRequested: false,
    });
  } catch (error) {
    console.error('cancelJoinRequest error:', error);
    return res.status(500).json({ success: false, code: 'CANCEL_JOIN_REQUEST_FAILED', message: 'Failed to cancel join request' });
  }
};

const getJoinRequests = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserIdFromReq(req);

    const group = await Group.findById(id).populate('joinRequests.user', 'username avatar email bio');
    if (!group) {
      return res.status(404).json({ success: false, code: 'GROUP_NOT_FOUND', message: 'Group not found' });
    }

    const isOwner = group.owner.toString() === userId.toString();
    const isAdmin = isOwner || group.members.some((m) => m.user.toString() === userId.toString() && m.role === 'admin');

    if (!isAdmin) {
      return res.status(403).json({ success: false, code: 'ADMIN_ONLY', message: 'Only admins can view pending join requests' });
    }

    const requests = (group.joinRequests || []).map((r) => ({
      userId: r.user?._id?.toString(),
      name: r.user?.username || 'User',
      avatar: r.user?.avatar,
      email: r.user?.email,
      message: r.message,
      requestedAt: r.requestedAt,
    }));

    return res.status(200).json({
      success: true,
      requests,
    });
  } catch (error) {
    console.error('getJoinRequests error:', error);
    return res.status(500).json({ success: false, code: 'GET_JOIN_REQUESTS_FAILED', message: 'Failed to get join requests' });
  }
};

const handleJoinRequest = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserIdFromReq(req);
    const { targetUserId, action } = req.body;

    if (!targetUserId || !['approve', 'reject'].includes(action)) {
      return res.status(400).json({ success: false, code: 'INVALID_INPUT', message: 'Invalid input data' });
    }

    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({ success: false, code: 'GROUP_NOT_FOUND', message: 'Group not found' });
    }

    const isOwner = group.owner.toString() === userId.toString();
    const isAdmin = isOwner || group.members.some((m) => m.user.toString() === userId.toString() && m.role === 'admin');

    if (!isAdmin) {
      return res.status(403).json({ success: false, code: 'ADMIN_ONLY', message: 'Only admins can approve or reject join requests' });
    }

    group.joinRequests = group.joinRequests.filter((r) => r.user.toString() !== targetUserId.toString());

    if (action === 'approve') {

      const notInGroup = !group.members.some((m) => m.user.toString() === targetUserId.toString());
      if (notInGroup) {
        group.members.push({ user: targetUserId, role: 'member', joinedAt: new Date() });
        group.membersCount = group.members.length;
      }
      await group.save();

      if (group.chatConversation) {
        await Conversation.findByIdAndUpdate(group.chatConversation, {
          $addToSet: {
            members: { user: targetUserId, role: 'member', joinedAt: new Date() },
          },
        });
      }

      await Request.findOneAndUpdate(
        { sender: targetUserId, group: group._id, type: 'group_join' },
        { status: 'accepted' }
      );

      await Notification.create({
        recipient: targetUserId,
        sender: userId,
        type: 'group_post',
        group: group._id,
        content: `approved your request to join "${group.name}"`,
      });

      const io = getIO ? getIO() : null;
      if (io) {
        io.to(targetUserId.toString()).emit('group_join_approved', {
          groupId: group._id.toString(),
          groupName: group.name,
          avatar: group.avatar,
        });
      }

      return res.status(200).json({
        success: true,
        message: 'Member join request approved successfully',
        action: 'approved',
      });
    } else {

      await group.save();

      await Request.findOneAndUpdate(
        { sender: targetUserId, group: group._id, type: 'group_join' },
        { status: 'rejected' }
      );

      return res.status(200).json({
        success: true,
        message: 'Join request rejected',
        action: 'rejected',
      });
    }
  } catch (error) {
    console.error('handleJoinRequest error:', error);
    return res.status(500).json({ success: false, code: 'PROCESS_REQUEST_FAILED', message: 'Failed to process join request' });
  }
};

const inviteMembers = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserIdFromReq(req);
    const { userIds } = req.body;

    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ success: false, code: 'INVITE_LIST_REQUIRED', message: 'Invite list cannot be empty' });
    }

    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({ success: false, code: 'GROUP_NOT_FOUND', message: 'Group not found' });
    }

    const isMember = group.owner.toString() === userId.toString() ||
      group.members.some((m) => m.user.toString() === userId.toString());

    if (!isMember) {
      return res.status(403).json({ success: false, code: 'MEMBER_ONLY', message: 'Only group members can invite others' });
    }

    const senderAcc = await Account.findById(userId).select('username avatar');
    const io = getIO ? getIO() : null;

    let invitedCount = 0;
    for (const targetId of userIds) {
      if (targetId && targetId.toString() !== userId.toString()) {
        const alreadyInGroup = group.members.some((m) => m.user.toString() === targetId.toString());
        if (!alreadyInGroup) {

          await Request.findOneAndUpdate(
            { sender: userId, receiver: targetId, group: group._id, type: 'group_invite' },
            { status: 'pending' },
            { upsert: true, new: true }
          );

          await Notification.create({
            recipient: targetId,
            sender: userId,
            type: 'group_invite',
            group: group._id,
            content: `invited you to join group "${group.name}"`,
          });

          if (io) {
            io.to(targetId.toString()).emit('group_invite_received', {
              groupId: group._id.toString(),
              groupName: group.name,
              avatar: group.avatar,
              privacy: group.privacy,
              sender: {
                id: userId,
                name: senderAcc?.username || 'Friend',
                avatar: senderAcc?.avatar,
              },
            });
          }
          invitedCount++;
        }
      }
    }

    return res.status(200).json({
      success: true,
      message: `Successfully sent invitation to ${invitedCount} friends!`,
      invitedCount,
    });
  } catch (error) {
    console.error('inviteMembers error:', error);
    return res.status(500).json({ success: false, code: 'SEND_INVITE_FAILED', message: 'Failed to send group invitation' });
  }
};

const respondToInvitation = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserIdFromReq(req);
    const { action } = req.body;

    if (!['accept', 'decline'].includes(action)) {
      return res.status(400).json({ success: false, code: 'INVALID_ACTION', message: 'Invalid action' });
    }

    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({ success: false, code: 'GROUP_NOT_FOUND', message: 'Group not found' });
    }

    if (action === 'accept') {
      const alreadyIn = group.members.some((m) => m.user.toString() === userId.toString());
      if (!alreadyIn) {
        group.members.push({ user: userId, role: 'member', joinedAt: new Date() });
        group.membersCount = group.members.length;
        await group.save();

        if (group.chatConversation) {
          await Conversation.findByIdAndUpdate(group.chatConversation, {
            $addToSet: {
              members: { user: userId, role: 'member', joinedAt: new Date() },
            },
          });
        }
      }

      await Request.findOneAndUpdate(
        { receiver: userId, group: group._id, type: 'group_invite' },
        { status: 'accepted' }
      );

      return res.status(200).json({
        success: true,
        message: 'Group invite accepted and joined successfully!',
        isMember: true,
      });
    } else {
      await Request.findOneAndUpdate(
        { receiver: userId, group: group._id, type: 'group_invite' },
        { status: 'rejected' }
      );

      return res.status(200).json({
        success: true,
        message: 'Group invite declined',
      });
    }
  } catch (error) {
    console.error('respondToInvitation error:', error);
    return res.status(500).json({ success: false, code: 'RESPOND_INVITE_FAILED', message: 'Failed to respond to group invitation' });
  }
};

const leaveGroup = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserIdFromReq(req);

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }

    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({ success: false, code: 'GROUP_NOT_FOUND', message: 'Group not found' });
    }

    group.members = group.members.filter((m) => m.user.toString() !== userId.toString());
    group.membersCount = group.members.length;

    if (group.owner.toString() === userId.toString()) {
      if (group.members.length > 0) {
        group.owner = group.members[0].user;
        group.members[0].role = 'owner';
      } else {
        await Group.findByIdAndDelete(group._id);
        if (group.chatConversation) {
          await Conversation.findByIdAndDelete(group.chatConversation);
        }
        return res.status(200).json({ success: true, message: 'Group disbanded as no members remain' });
      }
    }

    await group.save();

    if (group.chatConversation) {
      await Conversation.findByIdAndUpdate(group.chatConversation, {
        $pull: { members: { user: userId } },
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Left group successfully',
    });
  } catch (error) {
    console.error('leaveGroup error:', error);
    return res.status(500).json({ success: false, code: 'LEAVE_GROUP_FAILED', message: 'Failed to leave group' });
  }
};

const deleteGroup = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserIdFromReq(req);

    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({ success: false, code: 'GROUP_NOT_FOUND', message: 'Group not found' });
    }

    if (group.owner.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, code: 'OWNER_ONLY', message: 'Only group owner can delete this group' });
    }

    if (group.chatConversation) {
      await Conversation.findByIdAndDelete(group.chatConversation);
    }
    await Group.findByIdAndDelete(id);

    return res.status(200).json({
      success: true,
      message: 'Group deleted successfully',
    });
  } catch (error) {
    console.error('deleteGroup error:', error);
    return res.status(500).json({ success: false, code: 'DELETE_GROUP_FAILED', message: 'Failed to delete group' });
  }
};

const removeAccount = async (req, res) => {};
const promoteAccount = async (req, res) => {};
const demotedAccount = async (req, res) => {};
const warningAccount = async (req, res) => {};
const pinPost = async (req, res) => {};
const unPinPost = async (req, res) => {};
const settingGroup = async (req, res) => {};

module.exports = {
  createGroup,
  getUserGroups,
  getDiscoverGroups,
  searchGroups,
  getGroupDetail,
  joinGroup,
  requestJoinGroup,
  cancelJoinRequest,
  getJoinRequests,
  handleJoinRequest,
  inviteMembers,
  respondToInvitation,
  leaveGroup,
  deleteGroup,
  removeAccount,
  promoteAccount,
  demotedAccount,
  warningAccount,
  pinPost,
  unPinPost,
  settingGroup,
};