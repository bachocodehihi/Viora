const mongoose = require('mongoose');
const Account = require('../models/account.model');
const Activity = require('../models/activity.model');
const Post = require('../models/post.model');
const Group = require('../models/group.model');
const Search = require('../models/search.model');
const Request = require('../models/request.model');
const OTP = require('../models/otp.model');
const Report = require('../models/report.model');
const Like = require('../models/like.model');
const Comment = require('../models/comment.model');
const Conversation = require('../models/conversation.model');
const Message = require('../models/message.model');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { generateUserQRCode } = require('../services/qrcode.service');
const { verifyToken } = require('../config/jwt.config');
const { getIO, isUserOnline, hasActiveSocket, setActiveStatusPreference } = require('../socket');

const getViewerIdFromReq = (req) => {
  if (req.body && (req.body.myUserId || req.body.currentUserId)) {
    return (req.body.myUserId || req.body.currentUserId).toString();
  }
  if (req.query && (req.query.myUserId || req.query.currentUserId)) {
    return (req.query.myUserId || req.query.currentUserId).toString();
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
      if (decoded && (decoded.id || decoded.userId || decoded._id)) {
        return (decoded.id || decoded.userId || decoded._id).toString();
      }
    } catch (_) {}
  }
  return null;
};

const getViewerRelationship = async (viewerId, targetUserId) => {
  if (!viewerId || !targetUserId || viewerId.toString() === targetUserId.toString()) {
    return {
      isFriend: false,
      hasFriendRequest: false,
      hasSentRequest: false,
      isFollowing: false,
      requestId: null,
    };
  }

  try {
    const [viewerAccount, targetAccount, pendingReq, pendingFollowReq] = await Promise.all([
      Account.findById(viewerId).select('friends following blockedUsers').lean(),
      Account.findById(targetUserId).select('friends isPrivate blockedUsers').lean(),
      Request.findOne({
        $or: [
          { sender: viewerId, receiver: targetUserId, type: 'friend', status: 'pending' },
          { sender: targetUserId, receiver: viewerId, type: 'friend', status: 'pending' },
        ],
      }).lean(),
      Request.findOne({
        sender: viewerId,
        receiver: targetUserId,
        type: 'follow',
        status: 'pending'
      }).lean(),
    ]);

    const isBlockedByViewer = Array.isArray(viewerAccount?.blockedUsers) &&
      viewerAccount.blockedUsers.some((b) => (b._id || b).toString() === targetUserId.toString());
    const isBlockedByTarget = Array.isArray(targetAccount?.blockedUsers) &&
      targetAccount.blockedUsers.some((b) => (b._id || b).toString() === viewerId.toString());
    const isBlocked = isBlockedByViewer || isBlockedByTarget;

    let isFriend = false;
    let isFollowing = false;
    if (viewerAccount && !isBlocked) {
      if (Array.isArray(viewerAccount.friends)) {
        isFriend = viewerAccount.friends.some(
          (f) => (f._id || f).toString() === targetUserId.toString()
        );
      }
      if (Array.isArray(viewerAccount.following)) {
        isFollowing = viewerAccount.following.some(
          (f) => (f._id || f).toString() === targetUserId.toString()
        );
      }
    }

    if (!isFriend && targetAccount && Array.isArray(targetAccount.friends) && !isBlocked) {
      isFriend = targetAccount.friends.some(
        (f) => (f._id || f).toString() === viewerId.toString()
      );
    }

    let hasFriendRequest = false;
    let hasSentRequest = false;
    let requestId = null;

    if (pendingReq && !isBlocked) {
      requestId = pendingReq._id.toString();
      if (pendingReq.sender.toString() === viewerId.toString()) {
        hasSentRequest = true;
      } else {
        hasFriendRequest = true;
      }
    }

    const hasSentFollowRequest = isBlocked ? false : !!pendingFollowReq;
    const isTargetPrivate = targetAccount?.isPrivate === true;
    const canViewProfilePosts = !isBlocked && (!isTargetPrivate || isFriend || isFollowing || (viewerId && viewerId.toString() === targetUserId.toString()));

    return {
      isFriend,
      hasFriendRequest,
      hasSentRequest,
      isFollowing,
      hasSentFollowRequest,
      isPrivate: isTargetPrivate,
      isBlocked,
      isBlockedByViewer,
      isBlockedByTarget,
      canViewProfilePosts,
      requestId,
    };
  } catch (err) {
    console.error('getViewerRelationship error:', err);
    return {
      isFriend: false,
      hasFriendRequest: false,
      hasSentRequest: false,
      isFollowing: false,
      hasSentFollowRequest: false,
      isPrivate: false,
      isBlocked: false,
      isBlockedByViewer: false,
      isBlockedByTarget: false,
      canViewProfilePosts: true,
      requestId: null,
    };
  }
};

const loadProfile = async (req, res) => {
  try {
    const { userId, email, username } = req.body;
    let query = {};

    if (userId) {
      query._id = userId;
    } else if (email) {
      query.email = String(email).trim().toLowerCase();
    } else if (username) {
      query.username = new RegExp(`^${String(username).trim()}$`, 'i');
    } else if (req.headers.authorization) {
      try {
        const token = req.headers.authorization.replace('Bearer ', '').trim();
        const decoded = verifyToken(token);
        if (decoded && decoded.id) {
          query._id = decoded.id;
        }
      } catch (_) {}
    }

    if (!query._id && !query.email && !query.username) {
      return res.status(400).json({
        success: false,
        code: 'USER_IDENTIFIER_REQUIRED',
        message: 'userId, email or username is required',
      });
    }

    const account = await Account.findOne({ ...query, isDeleted: false });
    if (!account) {
      return res.status(404).json({
        success: false,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Account not found',
      });
    }

    if (account.deletionRequested && account.deletionScheduledAt && new Date() >= new Date(account.deletionScheduledAt)) {
      account.isDeleted = true;
      account.deletionRequested = false;
      account.deleteAt = new Date();
      await account.save();
      return res.status(404).json({
        success: false,
        code: 'ACCOUNT_DELETED',
        message: 'This account has been permanently deleted.',
      });
    }

    if (!account.qrCode) {
      try {
        const qrCodeUrl = await generateUserQRCode(account._id.toString(), account.username);
        account.qrCode = qrCodeUrl;
        await account.save();
      } catch (qrErr) {
        console.error('Failed to generate QR in loadProfile:', qrErr);
      }
    }

    const accountData = account.toObject();
    delete accountData.password;
    accountData.twoFactorEnabled = !!account.twoFactorEnabled;
    accountData.showActiveStatus = account.privacy?.showActiveStatus !== false;

    try {
      accountData.followingCount = account.followingCount || (Array.isArray(account.following) ? account.following.length : 0);
      accountData.followersCount = account.followersCount || (Array.isArray(account.followers) ? account.followers.length : 0);
      accountData.friendsCount = account.friendsCount || (Array.isArray(account.friends) ? account.friends.length : 0);

      const [groupsCount, postsCount] = await Promise.all([
        Group.countDocuments({
          $or: [{ owner: account._id }, { 'members.user': account._id }]
        }),
        Post.countDocuments({
          author: account._id,
          isDeleted: false
        })
      ]);
      accountData.groupsCount = groupsCount;
      accountData.postsCount = postsCount;
    } catch (countErr) {
      console.error('Count stats error in loadProfile:', countErr);
    }

    const viewerId = getViewerIdFromReq(req);
    const relationship = await getViewerRelationship(viewerId, account._id);
    Object.assign(accountData, relationship);

    const isSelf = !!(viewerId && viewerId.toString() === account._id.toString());
    const targetShowActiveStatus = account.privacy?.showActiveStatus !== false;
    if (isSelf) {
      accountData.showActiveStatus = targetShowActiveStatus;
      accountData.privacy = {
        ...(accountData.privacy || {}),
        showActiveStatus: targetShowActiveStatus,
      };
      accountData.isOnline = targetShowActiveStatus ? isUserOnline(account._id.toString()) : false;
    } else {
      const canSeeActiveStatus = !relationship.isBlocked && relationship.isFriend && targetShowActiveStatus;
      accountData.showActiveStatus = canSeeActiveStatus;
      accountData.isOnline = canSeeActiveStatus ? isUserOnline(account._id.toString()) : false;
      if (!canSeeActiveStatus) {
        delete accountData.lastSeen;
      }
      if (accountData.privacy && typeof accountData.privacy === 'object') {
        accountData.privacy.showActiveStatus = canSeeActiveStatus;
      }
    }

    return res.status(200).json({
      success: true,
      account: accountData,
    });
  } catch (error) {
    console.error('loadProfile error:', error);
    return res.status(500).json({
      success: false,
      code: 'LOAD_PROFILE_FAILED',
      message: error.message || 'Failed to load profile',
    });
  }
};

const getUserIdFromReq = (req) => {
  if (req.body && req.body.userId) return req.body.userId;
  if (req.headers && req.headers.authorization) {
    try {
      const token = req.headers.authorization.replace('Bearer ', '').trim();
      const decoded = verifyToken(token);
      if (decoded && decoded.id) return decoded.id;
    } catch (_) {}
  }
  return null;
};

const formatTimeAgo = (date) => {
  if (!date) return '';
  const now = new Date();
  const diffMs = now - new Date(date);
  const diffSec = Math.floor(diffMs / 1000);
  if (diffSec < 60) return 'Just now';
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHour = Math.floor(diffMin / 60);
  if (diffHour < 24) return `${diffHour}h ago`;
  const diffDay = Math.floor(diffHour / 24);
  if (diffDay < 30) return `${diffDay}d ago`;
  const diffMonth = Math.floor(diffDay / 30);
  return `${diffMonth}mo ago`;
};

const loadSearchHistory = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'userId is required' });
    }

    const historyDocs = await Search.find({ user: userId })
      .sort({ updatedAt: -1 })
      .limit(15);

    const history = historyDocs.map((doc) => doc.query);

    let trending = [];
    try {
      const topAgg = await Search.aggregate([
        { $group: { _id: '$query', count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $limit: 6 }
      ]);
      trending = topAgg.map(t => t._id).filter(q => q && q.trim().length > 0);
    } catch (_) {}

    const defaultTrending = [
      '#VioraApp',
      'Alex Carter',
      'Da Lat Trip',
      'Sarah Jenkins',
      'UI Update',
      'Flutter Dev',
    ];

    for (const def of defaultTrending) {
      if (!trending.includes(def) && trending.length < 6) {
        trending.push(def);
      }
    }

    return res.status(200).json({
      success: true,
      history,
      trending,
    });
  } catch (error) {
    console.error('loadSearchHistory error:', error);
    return res.status(500).json({ success: false, code: 'LOAD_SEARCH_HISTORY_FAILED', message: error.message });
  }
};

const deleteSearchHistory = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { query, searchId } = req.body;
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'userId is required' });
    }

    const deleteFilter = { user: userId };
    if (searchId) {
      deleteFilter._id = searchId;
    } else if (query) {
      deleteFilter.query = String(query).trim();
    } else {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'searchId or query is required' });
    }

    await Search.deleteMany(deleteFilter);
    return res.status(200).json({ success: true, message: 'Deleted search query' });
  } catch (error) {
    console.error('deleteSearchHistory error:', error);
    return res.status(500).json({ success: false, code: 'DELETE_SEARCH_HISTORY_FAILED', message: error.message });
  }
};

const clearSearchHistory = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'userId is required' });
    }

    await Search.deleteMany({ user: userId });
    return res.status(200).json({ success: true, message: 'Cleared all search history' });
  } catch (error) {
    console.error('clearSearchHistory error:', error);
    return res.status(500).json({ success: false, code: 'CLEAR_SEARCH_HISTORY_FAILED', message: error.message });
  }
};

const search = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { query, type = 'all', sort = 'latest', saveHistory = true } = req.body;

    const trimmedQuery = String(query || '').trim();
    if (!trimmedQuery) {
      return res.status(200).json({
        success: true,
        users: [],
        groups: [],
        posts: [],
      });
    }

    if (saveHistory && userId) {
      try {
        await Search.findOneAndUpdate(
          { user: userId, query: trimmedQuery },
          { $set: { updatedAt: new Date() } },
          { upsert: true, new: true, setDefaultsOnInsert: true }
        );
      } catch (_) {}
    }

    let currentUser = null;
    let friendIds = [];
    if (userId) {
      try {
        if (mongoose.Types.ObjectId.isValid(userId)) {
          currentUser = await Account.findById(userId);
        } else {
          currentUser = await Account.findOne({ email: userId });
        }
        if (currentUser && currentUser.friends) {
          friendIds = currentUser.friends;
        }
      } catch (_) {}
    }

    const regex = new RegExp(trimmedQuery, 'i');
    const results = {
      users: [],
      groups: [],
      posts: [],
    };

    if (type === 'all' || type === 'users') {
      const userQuery = {
        isDeleted: false,
        $or: [
          { username: regex },
          { email: regex },
          { bio: regex },
          { job: regex },
        ],
      };

      if (currentUser && currentUser.blockedUsers && currentUser.blockedUsers.length > 0) {
        userQuery._id = { $nin: currentUser.blockedUsers };
      }

      let userSort = { createdAt: -1 };
      if (sort === 'popular') {
        userSort = { followersCount: -1, friendsCount: -1 };
      }

      const foundUsers = await Account.find(userQuery)
        .select('_id username email avatar bio job isOnline friends followers following privacy')
        .sort(userSort)
        .limit(20);

      let sentFriendReqs = [];
      let receivedFriendReqs = [];
      if (currentUser) {
        const foundUserIds = foundUsers.map(u => u._id);
        const pendingReqs = await Request.find({
          status: 'pending',
          type: 'friend',
          $or: [
            { sender: currentUser._id, receiver: { $in: foundUserIds } },
            { sender: { $in: foundUserIds }, receiver: currentUser._id }
          ]
        });
        sentFriendReqs = pendingReqs
          .filter(r => r.sender && r.sender.toString() === currentUser._id.toString())
          .map(r => r.receiver.toString());
        receivedFriendReqs = pendingReqs
          .filter(r => r.receiver && r.receiver.toString() === currentUser._id.toString())
          .map(r => r.sender.toString());
      }

      results.users = foundUsers.map((acc) => {
        const accIdStr = acc._id.toString();
        const currentUserIdStr = currentUser ? currentUser._id.toString() : '';
        const isMe = currentUserIdStr === accIdStr;
        const isFriend = currentUser && Array.isArray(currentUser.friends)
          ? currentUser.friends.some(f => (f && f.toString() === accIdStr))
          : false;
        const hasSentFriendRequest = sentFriendReqs.includes(accIdStr);
        const hasReceivedFriendRequest = receivedFriendReqs.includes(accIdStr);
        const isFollowing = currentUser && Array.isArray(currentUser.following)
          ? currentUser.following.some(f => (f && f.toString() === accIdStr))
          : false;
        const targetShowActiveStatus = acc.privacy?.showActiveStatus !== false;
        const canShowActiveStatus = !isMe && isFriend && targetShowActiveStatus;

        return {
          id: accIdStr,
          userId: accIdStr,
          name: acc.username,
          username: `@${acc.username.replace(/\s+/g, '_').toLowerCase()}`,
          email: acc.email,
          avatar: acc.avatar || '',
          bio: acc.bio || '',
          job: acc.job || '',
          showActiveStatus: canShowActiveStatus,
          isOnline: canShowActiveStatus ? isUserOnline(accIdStr) : false,
          friendsCount: acc.friends ? acc.friends.length : 0,
          isMe,
          isFriend,
          hasSentFriendRequest,
          hasReceivedFriendRequest,
          isFollowing,
        };
      });
    }

    if (type === 'all' || type === 'groups') {
      const matchText = {
        $or: [
          { name: regex },
          { description: regex },
        ],
      };

      const groupPrivacyConditions = [
        {
          privacy: { $in: ['public', 'private'] },
        },
      ];

      if (userId) {
        groupPrivacyConditions.push({
          privacy: 'secret',
          $or: [
            { owner: userId },
            { 'members.user': userId },
          ],
        });
      }

      const groupQuery = {
        $and: [
          matchText,
          { $or: groupPrivacyConditions },
        ],
      };

      let groupSort = { createdAt: -1 };
      if (sort === 'popular') {
        groupSort = { membersCount: -1 };
      }

      const foundGroups = await Group.find(groupQuery)
        .populate('owner', 'username avatar')
        .sort(groupSort)
        .limit(20);

      results.groups = foundGroups.map((grp) => {
        const isMember = currentUser && grp.members
          ? grp.members.some(m => m.user && m.user.equals(currentUser._id))
          : (currentUser && grp.owner ? grp.owner.equals(currentUser._id) : false);

        const hasRequested = currentUser && grp.joinRequests
          ? grp.joinRequests.some(r => r.user && r.user.equals(currentUser._id))
          : false;

        const gPrivacy = grp.privacy || grp.settings?.privacy || 'public';

        return {
          id: grp._id.toString(),
          name: grp.name,
          avatar: grp.avatar || '',
          coverImage: grp.coverImage || '',
          description: grp.description || '',
          members: grp.membersCount || (grp.members ? grp.members.length : 0),
          privacy: gPrivacy,
          isMember,
          hasRequested,
          qrCode: grp.qrCode || '',
        };
      });
    }

    if (type === 'all' || type === 'posts') {
      const postPrivacyConditions = [

        ...(userId ? [{ author: userId }] : []),

        { privacy: 'public' },

        ...(friendIds.length > 0 ? [{ privacy: 'friends', author: { $in: friendIds } }] : []),

        ...(userId ? [{ privacy: 'specific_friends', allowedFriends: userId }] : []),

        ...(friendIds.length > 0 && userId
          ? [{ privacy: 'friends_except', author: { $in: friendIds }, exceptedFriends: { $nin: [userId] } }]
          : []),
      ];

      const postQuery = {
        isDeleted: false,
        content: regex,
        $or: postPrivacyConditions,
      };

      let postSort = { createdAt: -1 };
      if (sort === 'popular') {
        postSort = { likesCount: -1, commentsCount: -1 };
      }

      const foundPosts = await Post.find(postQuery)
        .populate('author', 'username avatar email')
        .populate('group', 'name avatar settings')
        .sort(postSort)
        .limit(20);

      const accessiblePosts = foundPosts.filter((post) => {
        if (!post.group) return true;
        const grp = post.group;
        if (grp.settings && grp.settings.privacy === 'private') {

          return false;
        }
        return true;
      });

      results.posts = accessiblePosts.map((post) => ({
        id: post._id.toString(),
        userName: post.author?.username || 'Viora User',
        userUsername: post.author?.username ? `@${post.author.username.replace(/\s+/g, '_').toLowerCase()}` : '',
        avatar: post.author?.avatar || '',
        authorId: post.author?._id?.toString(),
        time: formatTimeAgo(post.createdAt),
        createdAt: post.createdAt,
        content: post.content || '',
        images: post.images || [],
        videos: post.videos || [],
        likes: post.likesCount || 0,
        comments: post.commentsCount || 0,
        shares: post.sharesCount || 0,
        privacy: post.privacy || 'public',
        group: post.group ? { id: post.group._id.toString(), name: post.group.name, avatar: post.group.avatar } : null,
      }));
    }

    return res.status(200).json({
      success: true,
      query: trimmedQuery,
      users: results.users,
      groups: results.groups,
      posts: results.posts,
    });
  } catch (error) {
    console.error('search error:', error);
    return res.status(500).json({ success: false, code: 'SEARCH_FAILED', message: error.message });
  }
};


const reportAccount = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { targetUserId, reason = 'Other', details = '' } = req.body;

    if (!userId || !targetUserId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and targetUserId are required' });
    }

    if (userId.toString() === targetUserId.toString()) {
      return res.status(400).json({ success: false, code: 'CANNOT_REPORT_SELF', message: 'Cannot report yourself' });
    }

    await Report.create({
      reporter: userId,
      targetType: 'user',
      targetId: targetUserId,
      reason: details ? `${reason}: ${details}` : reason,
      status: 'pending'
    });

    return res.status(200).json({
      success: true,
      message: 'Thank you for your report. Our moderation team will review it shortly.'
    });
  } catch (error) {
    console.error('reportAccount error:', error);
    return res.status(500).json({ success: false, code: 'REPORT_FAILED', message: error.message || 'Failed to submit report' });
  }
};

const blockAccount = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { targetUserId } = req.body;

    if (!userId || !targetUserId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and targetUserId are required' });
    }

    if (userId.toString() === targetUserId.toString()) {
      return res.status(400).json({ success: false, code: 'CANNOT_BLOCK_SELF', message: 'Cannot block yourself' });
    }

    const currentAcc = await Account.findById(userId);
    const isFriend = Array.isArray(currentAcc?.friends) &&
      currentAcc.friends.some(f => (f._id || f).toString() === targetUserId.toString());

    let wasFriend = isFriend;
    if (!wasFriend) {
      const conv = await Conversation.findOne({
        type: 'direct',
        $and: [
          { 'members.user': userId },
          { 'members.user': targetUserId }
        ]
      });
      if (conv) wasFriend = true;
    }

    const meUpdate = {
      $addToSet: { blockedUsers: targetUserId },
      $pull: { friends: targetUserId, following: targetUserId, followers: targetUserId }
    };
    if (wasFriend) {
      meUpdate.$addToSet.blockedFriends = targetUserId;
    }

    await Account.findByIdAndUpdate(userId, meUpdate);

    await Account.findByIdAndUpdate(targetUserId, {
      $pull: { friends: userId, following: userId, followers: userId }
    });

    const [updatedMe, updatedTarget] = await Promise.all([
      Account.findById(userId),
      Account.findById(targetUserId)
    ]);
    if (updatedMe) {
      updatedMe.friendsCount = (updatedMe.friends || []).length;
      updatedMe.followersCount = (updatedMe.followers || []).length;
      updatedMe.followingCount = (updatedMe.following || []).length;
      await updatedMe.save();
    }

    if (updatedTarget) {
      updatedTarget.friendsCount = (updatedTarget.friends || []).length;
      updatedTarget.followersCount = (updatedTarget.followers || []).length;
      updatedTarget.followingCount = (updatedTarget.following || []).length;
      await updatedTarget.save();
    }

    await Request.deleteMany({
      $or: [
        { sender: userId, receiver: targetUserId },
        { sender: targetUserId, receiver: userId }
      ]
    });

    return res.status(200).json({
      success: true,
      message: 'User blocked successfully'
    });
  } catch (error) {
    console.error('blockAccount error:', error);
    return res.status(500).json({ success: false, code: 'BLOCK_USER_FAILED', message: error.message || 'Failed to block user' });
  }
};

const unBlockAccount = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { targetUserId } = req.body;

    if (!userId || !targetUserId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and targetUserId are required' });
    }

    const currentAcc = await Account.findById(userId).select('blockedUsers blockedFriends friends');
    const wasBlockedFriend = Array.isArray(currentAcc?.blockedFriends) &&
      currentAcc.blockedFriends.some(b => (b._id || b).toString() === targetUserId.toString());

    let shouldRestoreFriend = wasBlockedFriend;
    if (!shouldRestoreFriend) {
      const conv = await Conversation.findOne({
        type: 'direct',
        $and: [
          { 'members.user': userId },
          { 'members.user': targetUserId }
        ]
      });
      if (conv) {
        shouldRestoreFriend = true;
      }
    }

    await Account.findByIdAndUpdate(userId, {
      $pull: { blockedUsers: targetUserId, blockedFriends: targetUserId }
    });

    if (shouldRestoreFriend) {
      await Account.findByIdAndUpdate(userId, {
        $addToSet: { friends: targetUserId }
      });
      await Account.findByIdAndUpdate(targetUserId, {
        $addToSet: { friends: userId }
      });

      const [updatedMe, updatedTarget] = await Promise.all([
        Account.findById(userId),
        Account.findById(targetUserId)
      ]);
      if (updatedMe) {
        updatedMe.friendsCount = (updatedMe.friends || []).length;
        await updatedMe.save();
      }
      if (updatedTarget) {
        updatedTarget.friendsCount = (updatedTarget.friends || []).length;
        await updatedTarget.save();
      }
    }

    // Restore all hidden messages sent while blocked
    await Message.updateMany(
      {
        sender: targetUserId,
        hiddenFrom: userId
      },
      {
        $pull: { hiddenFrom: userId }
      }
    );

    return res.status(200).json({
      success: true,
      message: 'User unblocked successfully'
    });
  } catch (error) {
    console.error('unBlockAccount error:', error);
    return res.status(500).json({ success: false, code: 'UNBLOCK_USER_FAILED', message: error.message || 'Failed to unblock user' });
  }
};

const loadBlock = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User identifier required' });
    }

    const account = await Account.findById(userId)
      .populate('blockedUsers', '_id username email avatar bio job');

    if (!account) {
      return res.status(404).json({ success: false, code: 'ACCOUNT_NOT_FOUND', message: 'Account not found' });
    }

    const blockedList = (account.blockedUsers || []).map(u => ({
      id: u._id.toString(),
      userId: u._id.toString(),
      name: u.username || 'User',
      username: `@${(u.username || '').toLowerCase().replace(/\s+/g, '_')}`,
      email: u.email || '',
      avatar: u.avatar || '',
      bio: u.bio || '',
      job: u.job || '',
    }));

    return res.status(200).json({
      success: true,
      blockedUsers: blockedList
    });
  } catch (error) {
    console.error('loadBlock error:', error);
    return res.status(500).json({ success: false, code: 'LOAD_BLOCK_FAILED', message: error.message || 'Failed to load block list' });
  }
};

const getLikeHistory = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User identifier required' });
    }

    const { page = 1, limit = 20 } = req.body || req.query || {};
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const likes = await Like.find({
      user: userId,
      targetType: 'Post'
    })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    const postIds = likes.map(l => l.target);
    const posts = await Post.find({
      _id: { $in: postIds },
      isDeleted: false
    })
      .populate('author', '_id username email avatar bio')
      .populate('group', '_id name avatar')
      .lean();

    const postMap = new Map();
    posts.forEach(p => postMap.set(p._id.toString(), p));

    const historyItems = [];
    for (const like of likes) {
      const post = postMap.get(like.target.toString());
      if (post) {
        historyItems.push({
          id: like._id.toString(),
          likeId: like._id.toString(),
          reactionType: like.type || 'like',
          likedAt: like.createdAt,
          post: {
            id: post._id.toString(),
            postId: post._id.toString(),
            content: post.content || '',
            images: post.images || [],
            videos: post.videos || [],
            likesCount: post.likesCount || 0,
            commentsCount: post.commentsCount || 0,
            sharesCount: post.sharesCount || 0,
            authorName: post.author?.username || 'Viora User',
            authorAvatar: post.author?.avatar || '',
            authorId: post.author?._id?.toString(),
            groupName: post.group?.name,
            createdAt: post.createdAt,
            timeAgo: formatTimeAgo(post.createdAt),
          }
        });
      }
    }

    return res.status(200).json({
      success: true,
      likes: historyItems,
      total: historyItems.length
    });
  } catch (error) {
    console.error('getLikeHistory error:', error);
    return res.status(500).json({ success: false, code: 'GET_LIKE_HISTORY_FAILED', message: error.message || 'Failed to load like history' });
  }
};

const getCommentHistory = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User identifier required' });
    }

    const { page = 1, limit = 20 } = req.body || req.query || {};
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const comments = await Comment.find({
      author: userId,
      isDeleted: false
    })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .populate({
        path: 'post',
        match: { isDeleted: false },
        select: '_id content images author createdAt',
        populate: {
          path: 'author',
          select: '_id username avatar'
        }
      })
      .lean();

    const historyItems = comments
      .filter(c => c.post)
      .map(c => ({
        id: c._id.toString(),
        commentId: c._id.toString(),
        content: c.content,
        createdAt: c.createdAt,
        timeAgo: formatTimeAgo(c.createdAt),
        likesCount: c.likesCount || 0,
        post: {
          id: c.post._id.toString(),
          postId: c.post._id.toString(),
          content: c.post.content || '',
          images: c.post.images || [],
          authorName: c.post.author?.username || 'Viora User',
          authorAvatar: c.post.author?.avatar || '',
          authorId: c.post.author?._id?.toString(),
          createdAt: c.post.createdAt,
          timeAgo: formatTimeAgo(c.post.createdAt),
        }
      }));

    return res.status(200).json({
      success: true,
      comments: historyItems,
      total: historyItems.length
    });
  } catch (error) {
    console.error('getCommentHistory error:', error);
    return res.status(500).json({ success: false, code: 'GET_COMMENT_HISTORY_FAILED', message: error.message || 'Failed to load comment history' });
  }
};

const deleteAccount = async (req, res) => {
  return requestDeleteAccount(req, res);
};

const editUsername = async (req, res) => {
  
};

const editBirthday = async (req, res) => {
  
};

const editGender = async (req, res) => {
  
};

const editAvatar = async (req, res) => {
  
};

const editCoverImage = async (req, res) => {
  
};

const editPhone = async (req, res) => {
  
};

const editAddress = async (req, res) => {
  
};

const editJob = async (req, res) => {
  
};

const editNationality = async (req, res) => {

}

const editHobby = async (req, res) => {

};

const editHomeTown = async (req, res) => {

}

const editIntroduction = async (req, res) => {

}

const editEducation = async (req, res) => {

}

const updateProfile = async (req, res) => {
  try {
    const { userId, email, username, bio, phone, address, homeTown, job, nationality, hobby, gender, birthday, avatar, coverImage, nationId, cityId, wardId, homeTownNationId, homeTownCityId, homeTownWardId, placesLived } = req.body;
    let query = {};

    if (userId) {
      query._id = userId;
    } else if (email) {
      query.email = String(email).trim().toLowerCase();
    } else if (req.headers.authorization) {
      try {
        const token = req.headers.authorization.replace('Bearer ', '').trim();
        const decoded = verifyToken(token);
        if (decoded && decoded.id) query._id = decoded.id;
      } catch (_) {}
    }

    if (!query._id && !query.email) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User identifier required' });
    }

    const updateFields = {};
    if (username !== undefined) updateFields.username = username;
    if (bio !== undefined) updateFields.bio = bio;
    if (phone !== undefined) updateFields.phone = phone;
    if (address !== undefined) updateFields.address = address;
    if (homeTown !== undefined) updateFields.homeTown = homeTown;
    if (job !== undefined) updateFields.job = job;
    if (nationality !== undefined) updateFields.nationality = nationality;
    if (hobby !== undefined) updateFields.hobby = hobby;
    if (gender !== undefined) updateFields.gender = gender;
    if (nationId !== undefined) updateFields.nationId = nationId || null;
    if (cityId !== undefined) updateFields.cityId = cityId || null;
    if (wardId !== undefined) updateFields.wardId = wardId || null;
    if (homeTownNationId !== undefined) updateFields.homeTownNationId = homeTownNationId || null;
    if (homeTownCityId !== undefined) updateFields.homeTownCityId = homeTownCityId || null;
    if (homeTownWardId !== undefined) updateFields.homeTownWardId = homeTownWardId || null;
    if (placesLived !== undefined && Array.isArray(placesLived)) updateFields.placesLived = placesLived;
    if (birthday !== undefined) {
      const bDate = new Date(birthday);
      if (!isNaN(bDate.getTime())) updateFields.birthday = bDate;
    }
    if (avatar !== undefined) updateFields.avatar = avatar;
    if (coverImage !== undefined) updateFields.coverImage = coverImage;
    if (req.body.isPrivate !== undefined) {
      updateFields.isPrivate = !!req.body.isPrivate;
      updateFields['privacy.isPrivate'] = !!req.body.isPrivate;
    }

    const account = await Account.findOneAndUpdate(
      { ...query, isDeleted: false },
      { $set: updateFields },
      { new: true }
    );

    if (!account) {
      return res.status(404).json({ success: false, code: 'ACCOUNT_NOT_FOUND', message: 'Account not found' });
    }

    const accountData = account.toObject();
    delete accountData.password;
    accountData.twoFactorEnabled = !!account.twoFactorEnabled;
    accountData.showActiveStatus = account.privacy?.showActiveStatus !== false;

    return res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      account: accountData,
    });
  } catch (error) {
    console.error('updateProfile error:', error);
    return res.status(500).json({ success: false, code: 'UPDATE_PROFILE_FAILED', message: error.message || 'Failed to update profile' });
  }
};

const recordActivity = async (req, res) => {
  try {
    const { userId, date, totalSeconds, hourlySeconds } = req.body;
    if (!userId || !date) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and date are required' });
    }

    const updateData = {};
    if (typeof totalSeconds === 'number') updateData.totalSeconds = totalSeconds;
    if (Array.isArray(hourlySeconds)) updateData.hourlySeconds = hourlySeconds;

    const activity = await Activity.findOneAndUpdate(
      { userId, date },
      { $set: updateData },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    return res.status(200).json({ success: true, activity });
  } catch (error) {
    console.error('recordActivity error:', error);
    return res.status(500).json({ success: false, code: 'RECORD_ACTIVITY_FAILED', message: error.message });
  }
};

const getActivity = async (req, res) => {
  try {
    const { userId, date, startDate, endDate } = req.body;
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'userId is required' });
    }

    if (date) {
      const activity = await Activity.findOne({ userId, date });
      return res.status(200).json({ success: true, activity: activity || null });
    }

    let query = { userId };
    if (startDate && endDate) {
      query.date = { $gte: startDate, $lte: endDate };
    }

    const activities = await Activity.find(query).sort({ date: 1 });
    return res.status(200).json({ success: true, activities });
  } catch (error) {
    console.error('getActivity error:', error);
    return res.status(500).json({ success: false, code: 'GET_ACTIVITY_FAILED', message: error.message });
  }
};

const updateNote = async (req, res) => {
  try {
    let userId = req.body?.userId;
    if (!userId && req.headers.authorization) {
      try {
        const token = req.headers.authorization.replace('Bearer ', '').trim();
        const decoded = verifyToken(token);
        if (decoded && decoded.id) {
          userId = decoded.id;
        }
      } catch (_) {}
    }

    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User ID is required' });
    }

    const { note } = req.body;
    const cleanNote = typeof note === 'string' ? note.trim() : '';
    const expiresAt = cleanNote ? new Date(Date.now() + 24 * 60 * 60 * 1000) : null;

    const account = await Account.findByIdAndUpdate(
      userId,
      {
        note: cleanNote,
        noteExpiresAt: expiresAt,
      },
      { new: true }
    ).select('friends note noteExpiresAt username avatar');

    if (!account) {
      return res.status(404).json({ success: false, code: 'ACCOUNT_NOT_FOUND', message: 'Account not found' });
    }

    try {
      const io = getIO ? getIO() : null;
      if (io) {
        const payload = {
          userId: account._id.toString(),
          username: account.username,
          avatar: account.avatar,
          note: account.note,
        };

        io.to(account._id.toString()).emit('user_note_updated', payload);

        if (Array.isArray(account.friends)) {
          account.friends.forEach(fId => {
            const friendIdStr = (fId._id || fId).toString();
            io.to(friendIdStr).emit('user_note_updated', payload);
          });
        }
      }
    } catch (socketErr) {
      console.error('Socket broadcast user_note_updated error:', socketErr);
    }

    return res.status(200).json({
      success: true,
      note: account.note,
      message: 'Note updated successfully',
    });
  } catch (error) {
    console.error('updateNote error:', error);
    return res.status(500).json({ success: false, code: 'UPDATE_NOTE_FAILED', message: error.message });
  }
};

const scanUserQr = async (req, res) => {
  try {
    const { qrData } = req.body;
    if (!qrData || typeof qrData !== 'string') {
      return res.status(400).json({ success: false, code: 'QR_DATA_REQUIRED', message: 'QR data is required' });
    }

    const clean = qrData.trim();
    let targetUserId = null;
    let targetUsername = null;
    let targetEmail = null;
    let targetGroupId = null;
    let isGroupQr = false;

    try {
      const parsed = JSON.parse(clean);
      if (parsed && typeof parsed === 'object') {
        if (parsed.type === 'group' || parsed.groupId) {
          isGroupQr = true;
          targetGroupId = parsed.groupId ? String(parsed.groupId).trim() : null;
        } else {
          if (parsed.userId) targetUserId = String(parsed.userId).trim();
          if (parsed.username) targetUsername = String(parsed.username).trim();
          if (parsed.email) targetEmail = String(parsed.email).trim().toLowerCase();
        }
      }
    } catch (_) {}

    if (!targetGroupId) {
      const groupMatch = clean.match(/qr_group_([a-fA-F0-9]{24})/);
      if (groupMatch && groupMatch[1]) {
        targetGroupId = groupMatch[1];
        isGroupQr = true;
      }
    }

    if (isGroupQr || targetGroupId) {
      let group = null;
      if (targetGroupId && mongoose.Types.ObjectId.isValid(targetGroupId)) {
        group = await Group.findById(targetGroupId);
      }
      if (!group) {
        group = await Group.findOne({ qrCode: clean });
      }

      if (group) {
        const viewerId = getViewerIdFromReq(req);
        const isMember = viewerId ? (
          group.owner?.toString() === viewerId.toString() ||
          group.members?.some((m) => m.user?.toString() === viewerId.toString())
        ) : false;
        const hasRequested = viewerId ? (
          group.joinRequests?.some((r) => r.user?.toString() === viewerId.toString())
        ) : false;

        return res.status(200).json({
          success: true,
          type: 'group',
          data: {
            id: group._id.toString(),
            groupId: group._id.toString(),
            name: group.name,
            avatar: group.avatar || '',
            privacy: group.privacy || 'public',
            description: group.description || '',
            membersCount: group.membersCount || (group.members ? group.members.length : 1),
            isMember,
            hasRequested,
            qrCode: group.qrCode || '',
            conversationId: group.chatConversation ? group.chatConversation.toString() : null,
          },
        });
      }
    }

    if (!targetUserId) {
      const match = clean.match(/qr_([a-fA-F0-9]{24})/);
      if (match && match[1]) {
        targetUserId = match[1];
      }
    }

    if (!targetUserId && /^[a-fA-F0-9]{24}$/.test(clean)) {
      targetUserId = clean;
    }

    if (!targetUserId && clean.includes('/profile/')) {
      const parts = clean.split('/profile/');
      if (parts.length > 1) {
        const seg = parts[1].split(/[/?#]/)[0].trim();
        if (/^[a-fA-F0-9]{24}$/.test(seg)) {
          targetUserId = seg;
        } else if (seg) {
          targetUsername = seg;
        }
      }
    }

    let account = null;
    if (targetUserId) {
      account = await Account.findOne({ _id: targetUserId, isDeleted: false });
    }
    if (!account && targetEmail) {
      account = await Account.findOne({ email: targetEmail, isDeleted: false });
    }
    if (!account && targetUsername) {
      account = await Account.findOne({ username: new RegExp(`^${targetUsername}$`, 'i'), isDeleted: false });
    }
    if (!account) {
      account = await Account.findOne({ qrCode: clean, isDeleted: false });
    }

    if (!account) {
      return res.status(404).json({
        success: false,
        code: 'USER_NOT_FOUND',
        message: 'No user found from this QR code',
      });
    }

    const accountObj = account.toObject();
    delete accountObj.password;

    const viewerId = getViewerIdFromReq(req);
    const relationship = await getViewerRelationship(viewerId, account._id);
    Object.assign(accountObj, relationship);

    const isSelf = !!(viewerId && viewerId.toString() === account._id.toString());
    const targetShowActiveStatus = account.privacy?.showActiveStatus !== false;
    if (isSelf) {
      accountObj.showActiveStatus = targetShowActiveStatus;
      accountObj.isOnline = targetShowActiveStatus ? isUserOnline(account._id.toString()) : false;
    } else {
      const canSeeActiveStatus = !relationship.isBlocked && relationship.isFriend && targetShowActiveStatus;
      accountObj.showActiveStatus = canSeeActiveStatus;
      accountObj.isOnline = canSeeActiveStatus ? isUserOnline(account._id.toString()) : false;
      if (!canSeeActiveStatus) {
        delete accountObj.lastSeen;
      }
      if (accountObj.privacy && typeof accountObj.privacy === 'object') {
        accountObj.privacy.showActiveStatus = canSeeActiveStatus;
      }
    }

    return res.status(200).json({
      success: true,
      data: accountObj,
    });
  } catch (error) {
    console.error('scanUserQr error:', error);
    return res.status(500).json({ success: false, code: 'SCAN_QR_FAILED', message: error.message });
  }
};

const requestDeleteAccount = async (req, res) => {
  try {
    const { email, password, reason } = req.body;
    let userId = req.body?.userId;

    if (!userId && req.headers.authorization) {
      try {
        const token = req.headers.authorization.replace('Bearer ', '').trim();
        const decoded = verifyToken(token);
        if (decoded && (decoded.id || decoded.userId || decoded._id)) {
          userId = decoded.id || decoded.userId || decoded._id;
        }
      } catch (_) {}
    }

    let account = null;
    if (userId) {
      account = await Account.findOne({ _id: userId, isDeleted: false });
    }
    if (!account && email) {
      account = await Account.findOne({ email: String(email).trim().toLowerCase(), isDeleted: false });
    }

    if (!account) {
      return res.status(404).json({ success: false, code: 'ACCOUNT_NOT_FOUND', message: 'Account not found' });
    }

    if (account.password) {
      if (!password) {
        return res.status(400).json({ success: false, code: 'PASSWORD_REQUIRED', message: 'Please enter your password to confirm' });
      }
      const isMatch = await bcrypt.compare(password, account.password);
      if (!isMatch) {
        return res.status(400).json({ success: false, code: 'INCORRECT_PASSWORD', message: 'Incorrect password' });
      }
    }

    const now = new Date();

    const scheduled = new Date(now.getTime() + 2 * 60 * 1000); 

    account.deletionRequested = true;
    account.deletionRequestedAt = now;
    account.deletionScheduledAt = scheduled;
    account.deletionReason = typeof reason === 'string' ? reason.trim() : '';
    await account.save();

    await OTP.deleteMany({ email: account.email, purpose: 'delete_account' }).catch(() => {});

    return res.status(200).json({
      success: true,
      message: 'Account deletion request received. You have 2 minutes to review before the account is permanently deleted.',
      deletionRequested: true,
      deletionRequestedAt: now,
      deletionScheduledAt: scheduled,
    });
  } catch (error) {
    console.error('requestDeleteAccount error:', error);
    return res.status(500).json({ success: false, code: 'REQUEST_DELETE_FAILED', message: error.message || 'Failed to process account deletion request' });
  }
};

const cancelDeleteAccount = async (req, res) => {
  try {
    const { email } = req.body;
    let userId = req.body?.userId;

    if (!userId && req.headers.authorization) {
      try {
        const token = req.headers.authorization.replace('Bearer ', '').trim();
        const decoded = verifyToken(token);
        if (decoded && (decoded.id || decoded.userId || decoded._id)) {
          userId = decoded.id || decoded.userId || decoded._id;
        }
      } catch (_) {}
    }

    let account = null;
    if (userId) {
      account = await Account.findOne({ _id: userId, isDeleted: false });
    }
    if (!account && email) {
      account = await Account.findOne({ email: String(email).trim().toLowerCase(), isDeleted: false });
    }

    if (!account) {
      return res.status(404).json({ success: false, code: 'ACCOUNT_NOT_FOUND', message: 'Account not found' });
    }

    account.deletionRequested = false;
    account.deletionRequestedAt = null;
    account.deletionScheduledAt = null;
    account.deletionReason = '';
    await account.save();

    return res.status(200).json({
      success: true,
      message: 'Account deletion request canceled successfully. Your account remains active.',
      deletionRequested: false,
    });
  } catch (error) {
    console.error('cancelDeleteAccount error:', error);
    return res.status(500).json({ success: false, code: 'CANCEL_DELETE_FAILED', message: error.message || 'Failed to cancel account deletion' });
  }
};

const getDeletionStatus = async (req, res) => {
  try {
    const { email } = req.body;
    let userId = req.body?.userId;

    if (!userId && req.headers.authorization) {
      try {
        const token = req.headers.authorization.replace('Bearer ', '').trim();
        const decoded = verifyToken(token);
        if (decoded && (decoded.id || decoded.userId || decoded._id)) {
          userId = decoded.id || decoded.userId || decoded._id;
        }
      } catch (_) {}
    }

    let account = null;
    if (userId) {
      account = await Account.findOne({ _id: userId });
    }
    if (!account && email) {
      account = await Account.findOne({ email: String(email).trim().toLowerCase() });
    }

    if (!account) {
      return res.status(404).json({ success: false, code: 'ACCOUNT_NOT_FOUND', message: 'Account not found' });
    }

    if (account.isDeleted) {
      return res.status(200).json({
        success: true,
        isDeleted: true,
        isExpired: true,
        deletionRequested: false,
        message: 'Account has been permanently deleted.',
      });
    }

    let isExpired = false;
    if (account.deletionRequested && account.deletionScheduledAt) {
      if (new Date() >= new Date(account.deletionScheduledAt)) {
        isExpired = true;

        account.isDeleted = true;
        account.deletionRequested = false;
        account.deleteAt = new Date();
        await account.save();
      }
    }

    return res.status(200).json({
      success: true,
      isDeleted: !!account.isDeleted,
      deletionRequested: !!account.deletionRequested,
      deletionRequestedAt: account.deletionRequestedAt,
      deletionScheduledAt: account.deletionScheduledAt,
      deletionReason: account.deletionReason || '',
      isExpired,
    });
  } catch (error) {
    console.error('getDeletionStatus error:', error);
    return res.status(500).json({ success: false, code: 'GET_DELETION_STATUS_FAILED', message: error.message || 'Failed to get deletion status' });
  }
};

const togglePrivateAccount = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Unauthorized' });
    }

    const { isPrivate } = req.body;
    const account = await Account.findById(userId);
    if (!account) {
      return res.status(404).json({ success: false, code: 'ACCOUNT_NOT_FOUND', message: 'Account not found' });
    }

    const nextState = isPrivate !== undefined ? !!isPrivate : !account.isPrivate;
    account.isPrivate = nextState;
    if (!account.privacy) account.privacy = {};
    account.privacy.isPrivate = nextState;
    await account.save();

    return res.status(200).json({
      success: true,
      isPrivate: account.isPrivate,
      message: account.isPrivate ? 'Private account mode enabled' : 'Public account mode enabled'
    });
  } catch (error) {
    console.error('togglePrivateAccount error:', error);
    return res.status(500).json({ success: false, code: 'TOGGLE_PRIVATE_FAILED', message: error.message || 'Failed to toggle private account mode' });
  }
};

const updatePrivacy = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Unauthorized' });
    }

    const { whoCanMessage, isPrivate, showActiveStatus } = req.body;
    const account = await Account.findById(userId);
    if (!account) {
      return res.status(404).json({ success: false, code: 'ACCOUNT_NOT_FOUND', message: 'Account not found' });
    }

    if (!account.privacy) account.privacy = {};

    if (whoCanMessage && ['everyone', 'friends', 'nobody'].includes(whoCanMessage)) {
      account.privacy.whoCanMessage = whoCanMessage;
    }
    if (isPrivate !== undefined) {
      account.isPrivate = !!isPrivate;
      account.privacy.isPrivate = !!isPrivate;
    }
    if (showActiveStatus !== undefined) {
      const nextShowActiveStatus = showActiveStatus === true || showActiveStatus === 'true';
      account.privacy.showActiveStatus = nextShowActiveStatus;
      setActiveStatusPreference(userId, nextShowActiveStatus);
      const currentlyConnected = hasActiveSocket(userId);
      if (!nextShowActiveStatus) {
        account.isOnline = false;
      } else {
        account.isOnline = currentlyConnected;
        if (currentlyConnected) {
          account.lastSeen = new Date();
        }
      }
    }

    await account.save();

    const effectiveShowActiveStatus = account.privacy.showActiveStatus !== false;
    if (showActiveStatus !== undefined) {
      const io = getIO ? getIO() : null;
      if (io) {
        const uidStr = userId.toString();
        const currentlyConnected = hasActiveSocket(uidStr);
        const effectiveOnline = effectiveShowActiveStatus && currentlyConnected;
        io.emit('user_active_status_changed', {
          userId: uidStr,
          showActiveStatus: effectiveShowActiveStatus,
          isOnline: effectiveOnline,
          online: effectiveOnline,
        });
        if (effectiveShowActiveStatus && currentlyConnected) {
          io.emit('user_online', { userId: uidStr });
        } else {
          io.emit('user_offline', { userId: uidStr });
        }
      }
    }

    return res.status(200).json({
      success: true,
      privacy: account.privacy,
      whoCanMessage: account.privacy.whoCanMessage,
      isPrivate: account.isPrivate,
      showActiveStatus: effectiveShowActiveStatus,
      message: 'Privacy settings updated successfully',
    });
  } catch (error) {
    console.error('updatePrivacy error:', error);
    return res.status(500).json({ success: false, message: error.message || 'Failed to update privacy' });
  }
};

const toggleTwoFactor = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Unauthorized' });
    }

    const { twoFactorEnabled } = req.body;
    const account = await Account.findOne({ _id: userId, isDeleted: false });
    if (!account) {
      return res.status(404).json({ success: false, code: 'ACCOUNT_NOT_FOUND', message: 'Account not found' });
    }

    const nextState = twoFactorEnabled !== undefined ? !!twoFactorEnabled : !account.twoFactorEnabled;
    account.twoFactorEnabled = nextState;
    await account.save();

    return res.status(200).json({
      success: true,
      twoFactorEnabled: account.twoFactorEnabled,
      message: account.twoFactorEnabled
        ? 'Two-factor authentication enabled'
        : 'Two-factor authentication disabled',
    });
  } catch (error) {
    console.error('toggleTwoFactor error:', error);
    return res.status(500).json({
      success: false,
      code: 'TOGGLE_TWO_FACTOR_FAILED',
      message: error.message || 'Failed to update two-factor authentication',
    });
  }
};

module.exports = { 
  loadProfile,
  updateProfile,
  togglePrivateAccount,
  updatePrivacy,
  toggleTwoFactor,
  editUsername,
  editBirthday,
  editGender,
  editAvatar,
  editCoverImage,
  editPhone,
  editAddress,
  editJob,
  editNationality,
  search,
  loadSearchHistory,
  deleteSearchHistory,
  clearSearchHistory,
  reportAccount,
  blockAccount,
  unBlockAccount,
  loadBlock,
  deleteAccount,
  requestDeleteAccount,
  cancelDeleteAccount,
  getDeletionStatus,
  editHobby,
  editHomeTown,
  editIntroduction,
  editEducation,
  recordActivity,
  getActivity,
  getLikeHistory,
  getCommentHistory,
  updateNote,
  scanUserQr,
};

