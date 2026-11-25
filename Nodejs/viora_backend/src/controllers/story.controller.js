const mongoose = require('mongoose');
const Story = require('../models/story.model');
const Account = require('../models/account.model');
const Notification = require('../models/notification.model');
const { verifyToken } = require('../config/jwt.config');
const jwt = require('jsonwebtoken');
const { getIO } = require('../socket');

const getUserIdFromReq = async (req) => {
  if (req.user && (req.user.id || req.user._id || req.user.userId)) {
    return (req.user.id || req.user._id || req.user.userId).toString();
  }
  if (req.body && (req.body.userId || req.body.myUserId)) {
    return (req.body.userId || req.body.myUserId).toString();
  }
  if (req.query && (req.query.userId || req.query.myUserId)) {
    return (req.query.userId || req.query.myUserId).toString();
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
  return null;
};

const createStory = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in to post a story' });
    }

    let { content, mediaUrl, mediaType, backgroundColor, privacy } = req.body;

    if (req.file) {
      mediaUrl = req.file.path || req.file.secure_url || req.file.url;
      if (req.file.mimetype && req.file.mimetype.startsWith('video')) {
        mediaType = 'video';
      } else {
        mediaType = mediaType || 'image';
      }
    }

    if (!mediaUrl && (!content || !content.trim())) {
      return res.status(400).json({
        success: false,
        code: 'CONTENT_REQUIRED',
        message: 'Story must have media (image/video) or text content',
      });
    }

    if (!mediaUrl && content) {
      mediaType = 'text';
    }

    const story = await Story.create({
      user: userId,
      content: content ? content.trim() : '',
      mediaUrl: mediaUrl || '',
      mediaType: mediaType || 'image',
      backgroundColor: backgroundColor || '#1A1A24',
      privacy: privacy || 'friends',
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
    });

    const populatedStory = await Story.findById(story._id)
      .populate('user', 'username avatar isOnline')
      .lean();

    const io = getIO ? getIO() : null;
    if (io) {
      io.emit('new_story', {
        story: populatedStory,
        userId: userId.toString(),
      });
    }

    return res.status(201).json({
      success: true,
      message: 'Story created successfully',
      story: populatedStory,
    });
  } catch (error) {
    console.error('createStory error:', error);
    return res.status(500).json({
      success: false,
      code: 'CREATE_STORY_FAILED',
      message: error.message || 'Failed to create story',
    });
  }
};

const getFeed = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const now = new Date();

    let query = {
      expiresAt: { $gt: now },
    };

    if (userId) {
      const currentUser = await Account.findById(userId).select('friends blockedUsers').lean();
      const friendIds = (currentUser?.friends || []).map(f => (f._id || f).toString());
      const blockedIds = (currentUser?.blockedUsers || []).map(b => (b._id || b).toString());

      query.$and = [
        { user: { $nin: blockedIds } },
        {
          $or: [
            { user: userId },
            { user: { $in: friendIds }, privacy: { $in: ['public', 'friends'] } },
            { privacy: 'public' },
          ],
        },
      ];
    } else {
      query.privacy = 'public';
    }

    const stories = await Story.find(query)
      .populate('user', 'username avatar isOnline')
      .populate('viewers.user', 'username avatar')
      .sort({ createdAt: -1 })
      .lean();

    const groupMap = new Map();

    for (const story of stories) {
      if (!story.user) continue;
      const uId = story.user._id.toString();

      if (!groupMap.has(uId)) {
        groupMap.set(uId, {
          user: story.user,
          stories: [],
          hasUnseen: false,
          latestCreatedAt: story.createdAt,
          isMe: !!(userId && uId === userId.toString()),
        });
      }

      const isViewed = userId
        ? Array.isArray(story.viewers) && story.viewers.some(v => (v.user?._id || v.user)?.toString() === userId.toString())
        : false;

      story.isViewed = isViewed;
      story.viewersCount = Array.isArray(story.viewers) ? story.viewers.length : 0;

      const group = groupMap.get(uId);
      group.stories.push(story);

      if (!isViewed && !group.isMe) {
        group.hasUnseen = true;
      }
    }

    const groups = Array.from(groupMap.values());

    groups.sort((a, b) => {
      if (a.isMe) return -1;
      if (b.isMe) return 1;
      if (a.hasUnseen && !b.hasUnseen) return -1;
      if (!a.hasUnseen && b.hasUnseen) return 1;
      return new Date(b.latestCreatedAt) - new Date(a.latestCreatedAt);
    });

    let myStories = [];
    if (userId && groupMap.has(userId.toString())) {
      myStories = groupMap.get(userId.toString()).stories;
    }

    return res.status(200).json({
      success: true,
      feed: groups,
      myStories,
    });
  } catch (error) {
    console.error('getStoriesFeed error:', error);
    return res.status(500).json({
      success: false,
      code: 'GET_STORIES_FAILED',
      message: error.message || 'Failed to load stories',
    });
  }
};

const getUserStories = async (req, res) => {
  try {
    const targetUserId = req.params.userId || req.query.userId || req.body.userId;
    const currentUserId = await getUserIdFromReq(req);

    if (!targetUserId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User ID is required' });
    }

    const stories = await Story.find({
      user: targetUserId,
      expiresAt: { $gt: new Date() },
    })
      .populate('user', 'username avatar isOnline')
      .populate('viewers.user', 'username avatar')
      .sort({ createdAt: 1 })
      .lean();

    const mappedStories = stories.map(s => {
      s.isViewed = currentUserId
        ? Array.isArray(s.viewers) && s.viewers.some(v => (v.user?._id || v.user)?.toString() === currentUserId.toString())
        : false;
      s.viewersCount = Array.isArray(s.viewers) ? s.viewers.length : 0;
      return s;
    });

    return res.status(200).json({
      success: true,
      stories: mappedStories,
    });
  } catch (error) {
    console.error('getUserStories error:', error);
    return res.status(500).json({
      success: false,
      code: 'GET_USER_STORIES_FAILED',
      message: error.message || 'Failed to load user stories',
    });
  }
};

const viewStory = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const storyId = req.params.storyId || req.body.storyId;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }
    if (!storyId) {
      return res.status(400).json({ success: false, code: 'STORY_ID_REQUIRED', message: 'storyId is required' });
    }

    const story = await Story.findById(storyId);
    if (!story) {
      return res.status(404).json({ success: false, code: 'STORY_NOT_FOUND', message: 'Story not found or expired' });
    }

    const alreadyViewed = story.viewers.some(v => v.user?.toString() === userId.toString());
    if (!alreadyViewed) {
      story.viewers.push({
        user: userId,
        viewedAt: new Date(),
      });
      await story.save();

      const io = getIO ? getIO() : null;
      if (io) {
        io.to(story.user.toString()).emit('story_viewed', {
          storyId: story._id.toString(),
          viewerId: userId.toString(),
          viewersCount: story.viewers.length,
        });
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Story marked as viewed',
      viewersCount: story.viewers.length,
    });
  } catch (error) {
    console.error('viewStory error:', error);
    return res.status(500).json({
      success: false,
      code: 'VIEW_STORY_FAILED',
      message: error.message || 'Failed to record story view',
    });
  }
};

const deleteStory = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const storyId = req.params.storyId || req.body.storyId;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }
    if (!storyId) {
      return res.status(400).json({ success: false, code: 'STORY_ID_REQUIRED', message: 'storyId is required' });
    }

    const story = await Story.findById(storyId);
    if (!story) {
      return res.status(404).json({ success: false, code: 'STORY_NOT_FOUND', message: 'Story not found' });
    }

    if (story.user.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, code: 'FORBIDDEN', message: 'You can only delete your own stories' });
    }

    await Story.findByIdAndDelete(storyId);

    const io = getIO ? getIO() : null;
    if (io) {
      io.emit('story_deleted', {
        storyId: storyId.toString(),
        userId: userId.toString(),
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Story deleted successfully',
    });
  } catch (error) {
    console.error('deleteStory error:', error);
    return res.status(500).json({
      success: false,
      code: 'DELETE_STORY_FAILED',
      message: error.message || 'Failed to delete story',
    });
  }
};

const reactStory = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { storyId, reaction = 'heart' } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }
    if (!storyId) {
      return res.status(400).json({ success: false, code: 'STORY_ID_REQUIRED', message: 'storyId is required' });
    }

    const story = await Story.findById(storyId);
    if (!story) {
      return res.status(404).json({ success: false, code: 'STORY_NOT_FOUND', message: 'Story not found' });
    }

    story.reactions.push({
      user: userId,
      reaction,
      createdAt: new Date(),
    });
    await story.save();

    if (story.user.toString() !== userId.toString()) {
      await Notification.create({
        recipient: story.user,
        sender: userId,
        type: 'friend_story',
        reaction,
        content: `reacted to your story`,
      });

      const io = getIO ? getIO() : null;
      if (io) {
        io.to(story.user.toString()).emit('story_reaction', {
          storyId: story._id.toString(),
          senderId: userId.toString(),
          reaction,
        });
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Reaction sent successfully',
    });
  } catch (error) {
    console.error('reactStory error:', error);
    return res.status(500).json({
      success: false,
      code: 'REACT_STORY_FAILED',
      message: error.message || 'Failed to react to story',
    });
  }
};

module.exports = {
  createStory,
  getFeed,
  getUserStories,
  viewStory,
  deleteStory,
  reactStory,
};
