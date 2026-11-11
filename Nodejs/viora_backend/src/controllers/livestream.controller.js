const mongoose = require('mongoose');
const LiveStream = require('../models/livestream.model');
const Post = require('../models/post.model');
const Account = require('../models/account.model');
const { verifyToken } = require('../config/jwt.config');
const jwt = require('jsonwebtoken');
const { RtcTokenBuilder, RtcRole } = require('agora-token');
const { isUserOnline } = require('../socket');
const { createNotification } = require('./notification.controller');

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

  const candidateId = (req.body && (req.body.userId || req.body.myUserId || req.body.hostId)) ||
                      (req.query && (req.query.userId || req.query.myUserId || req.query.hostId));
  if (candidateId) {
    const trimmed = candidateId.toString().trim();
    if (mongoose.Types.ObjectId.isValid(trimmed)) {
      return trimmed;
    }
  }

  return null;
};

const generateAgoraToken = (channelName, uid, role = RtcRole.PUBLISHER) => {
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

const createLive = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in to start live stream' });
    }

    const { title, mode, thumbnail } = req.body;
    const channelName = `viora_live_${userId}_${Date.now()}`;
    const liveMode = mode === 'screen' ? 'screen' : 'camera';

    const liveStream = new LiveStream({
      host: userId,
      title: title && title.trim() ? title.trim() : 'Live Stream',
      channelName,
      mode: liveMode,
      status: 'live',
      thumbnail: thumbnail || null,
      startedAt: new Date(),
    });

    await liveStream.save();
    await liveStream.populate('host', 'username avatar email isOnline');

    const hostUid = 0;
    const token = generateAgoraToken(channelName, hostUid, RtcRole.PUBLISHER);

    try {
      const { getIO } = require('../socket');
      const io = getIO ? getIO() : null;
      if (io) {
        io.emit('new_live_started', {
          liveId: liveStream._id.toString(),
          title: liveStream.title,
          channelName,
          mode: liveStream.mode,
          host: {
            id: liveStream.host._id.toString(),
            name: liveStream.host.username || 'User',
            avatar: liveStream.host.avatar,
          },
          startedAt: liveStream.startedAt
        });
      }
    } catch (sockErr) {
      console.warn('Socket emit new_live_started error:', sockErr.message);
    }

    (async () => {
      try {
        const hostUser = await Account.findById(userId).select('username avatar friends followers').lean();
        const hostName = hostUser?.username || 'User';
        const recipientSet = new Set();

        if (Array.isArray(hostUser?.friends)) {
          for (const f of hostUser.friends) {
            recipientSet.add(f.toString());
          }
        }
        if (Array.isArray(hostUser?.followers)) {
          for (const fol of hostUser.followers) {
            recipientSet.add(fol.toString());
          }
        }

        recipientSet.delete(userId.toString());

        for (const recipientId of recipientSet) {
          await createNotification({
            recipient: recipientId,
            sender: userId,
            livestream: liveStream._id,
            type: 'friend_live',
            content: liveStream.title || 'Live Stream'
          });
        }
      } catch (notifErr) {
        console.error('createLive notification error:', notifErr);
      }
    })();

    return res.status(201).json({
      success: true,
      message: 'Live stream created successfully',
      appId: process.env.AGORA_APP_ID,
      token,
      channelName,
      hostUid,
      liveStream: {
        id: liveStream._id.toString(),
        title: liveStream.title,
        channelName: liveStream.channelName,
        mode: liveStream.mode,
        status: liveStream.status,
        startedAt: liveStream.startedAt,
        host: {
          id: liveStream.host._id.toString(),
          name: liveStream.host.username,
          avatar: liveStream.host.avatar,
        }
      }
    });
  } catch (error) {
    console.error('createLive error:', error);
    return res.status(500).json({ success: false, code: 'CREATE_LIVESTREAM_FAILED', message: error.message || 'Failed to initialize live stream' });
  }
};

const getActiveLives = async (req, res) => {
  try {
    const lives = await LiveStream.find({ status: 'live' })
      .sort({ createdAt: -1 })
      .populate('host', 'username avatar email isOnline privacy')
      .lean();

    const formatted = lives.map(l => {
      const hostShowActive = l.host?.privacy?.showActiveStatus !== false;
      return {
        id: l._id.toString(),
        title: l.title,
        channelName: l.channelName,
        mode: l.mode,
        status: l.status,
        viewersCount: l.viewersCount || 0,
        likesCount: l.likesCount || 0,
        startedAt: l.startedAt,
        thumbnail: l.thumbnail,
        host: {
          id: l.host?._id ? l.host._id.toString() : '',
          name: l.host?.username || 'User',
          avatar: l.host?.avatar || null,
          isOnline: hostShowActive ? isUserOnline(l.host?._id?.toString()) : false,
        }
      };
    });

    return res.status(200).json({
      success: true,
      lives: formatted
    });
  } catch (error) {
    console.error('getActiveLives error:', error);
    return res.status(500).json({ success: false, code: 'GET_LIVESTREAMS_FAILED', message: 'Failed to get live streams' });
  }
};

const getLiveDetail = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = await getUserIdFromReq(req);

    const live = await LiveStream.findById(id)
      .populate('host', 'username avatar email isOnline')
      .lean();

    if (!live) {
      return res.status(404).json({ success: false, code: 'LIVESTREAM_NOT_FOUND', message: 'Live stream not found' });
    }

    if (live.status === 'ended') {
      return res.status(200).json({
        success: true,
        isEnded: true,
        liveStream: {
          id: live._id.toString(),
          title: live.title,
          status: 'ended',
          duration: live.duration || 0,
          maxViewers: live.maxViewers || 0,
          likesCount: live.likesCount || 0,
          endedAt: live.endedAt,
          savedPostId: live.savedPost ? live.savedPost.toString() : null,
          host: {
            id: live.host?._id?.toString(),
            name: live.host?.username || 'User',
            avatar: live.host?.avatar,
          }
        }
      });
    }

    const viewerUid = 0;
    const token = generateAgoraToken(live.channelName, viewerUid, RtcRole.PUBLISHER);

    return res.status(200).json({
      success: true,
      isEnded: false,
      appId: process.env.AGORA_APP_ID,
      token,
      channelName: live.channelName,
      viewerUid,
      liveStream: {
        id: live._id.toString(),
        title: live.title,
        channelName: live.channelName,
        mode: live.mode,
        status: live.status,
        viewersCount: live.viewersCount || 0,
        likesCount: live.likesCount || 0,
        reactionsCount: live.reactionsCount || {},
        startedAt: live.startedAt,
        host: {
          id: live.host?._id?.toString(),
          name: live.host?.username || 'User',
          avatar: live.host?.avatar,
        }
      }
    });
  } catch (error) {
    console.error('getLiveDetail error:', error);
    return res.status(500).json({ success: false, code: 'GET_LIVESTREAM_FAILED', message: 'Failed to get live stream info' });
  }
};

const endLive = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = await getUserIdFromReq(req);
    const { saveAsPost, caption, privacy } = req.body;

    const live = await LiveStream.findById(id);
    if (!live) {
      return res.status(404).json({ success: false, code: 'LIVESTREAM_NOT_FOUND', message: 'Live stream not found' });
    }

    if (live.host.toString() !== userId) {
      return res.status(403).json({ success: false, code: 'FORBIDDEN', message: 'You do not have permission to end this live stream' });
    }

    const now = new Date();
    const durationSeconds = Math.max(1, Math.floor((now - new Date(live.startedAt)) / 1000));

    live.status = 'ended';
    live.endedAt = now;
    live.duration = durationSeconds;

    let savedPost = null;

    if (saveAsPost) {
      const minutes = Math.floor(durationSeconds / 60);
      const seconds = durationSeconds % 60;
      const durationStr = minutes > 0 ? `${minutes}m ${seconds}s` : `${seconds}s`;

      const postContent = caption && caption.trim()
        ? `${caption.trim()}\n\n🔴 Live stream: "${live.title}" (${durationStr})`
        : `🔴 Live stream: "${live.title}"\n⏱ Duration: ${durationStr}\n👥 Peak viewers: ${live.maxViewers || live.viewersCount || 1}`;

      const newPost = new Post({
        author: userId,
        content: postContent,
        images: live.thumbnail ? [live.thumbnail] : [],
        videos: [],
        postType: 'user',
        privacy: privacy || 'public',
        status: 'approved'
      });

      await newPost.save();
      savedPost = newPost;
      live.savedPost = newPost._id;
      live.isSavedAsPost = true;
    }

    await live.save();

    try {
      const { getIO } = require('../socket');
      const io = getIO ? getIO() : null;
      if (io) {
        io.to(`live_${live._id.toString()}`).emit('live_ended', {
          liveId: live._id.toString(),
          duration: durationSeconds,
          maxViewers: live.maxViewers || live.viewersCount || 0,
          likesCount: live.likesCount || 0,
          savedPostId: savedPost ? savedPost._id.toString() : null
        });
      }
    } catch (sockErr) {
      console.warn('Socket emit live_ended error:', sockErr.message);
    }

    return res.status(200).json({
      success: true,
      message: 'Live stream ended successfully',
      duration: durationSeconds,
      savedPostId: savedPost ? savedPost._id.toString() : null,
      maxViewers: live.maxViewers || live.viewersCount || 0,
      likesCount: live.likesCount || 0
    });
  } catch (error) {
    console.error('endLive error:', error);
    return res.status(500).json({ success: false, code: 'END_LIVESTREAM_FAILED', message: 'Failed to end live stream' });
  }
};

module.exports = {
  createLive,
  getActiveLives,
  getLiveDetail,
  endLive
};
