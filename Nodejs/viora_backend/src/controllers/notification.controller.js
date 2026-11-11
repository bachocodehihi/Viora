const Notification = require('../models/notification.model');
const Account = require('../models/account.model');
const { sendPushNotification } = require('../services/fcm.service');
const { getIO } = require('../socket');
const { verifyToken } = require('../config/jwt.config');

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

const createNotification = async ({
  recipient,
  sender,
  type,
  content,
  reaction,
  post,
  group,
  comment,
  conversation,
  request,
  livestream,
  status = 'none'
}) => {
  try {
    if (!recipient || recipient.toString() === sender?.toString()) return null;

    if (type === 'message') return null;

    const notif = new Notification({
      recipient,
      sender: sender || null,
      type,
      content: content || '',
      reaction: reaction || null,
      post: post || null,
      group: group || null,
      comment: comment || null,
      conversation: conversation || null,
      request: request || null,
      livestream: livestream || null,
      status: type === 'friend_request' ? 'pending' : status,
      isRead: false
    });

    const savedNotif = await notif.save();

    let senderName = 'Viora';
    let senderAvatar = null;

    if (sender) {
      const senderUser = await Account.findById(sender).select('username avatar bio').lean();
      if (senderUser) {
        senderName = senderUser.username || 'User';
        senderAvatar = (senderUser.avatar && senderUser.avatar.startsWith('http')) ? senderUser.avatar : null;
      }
    }

    let groupName = '';
    if (group) {
      const Group = require('../models/group.model');
      const g = await Group.findById(group).select('name avatar').lean();
      if (g) groupName = g.name || '';
    }

    let notifTitle = senderName;
    let notifBody = content || '';

    switch (type) {
      case 'friend_request':
        notifBody = `${senderName} sent you a friend request`;
        break;
      case 'friend_accept':
        notifBody = `${senderName} accepted your friend request`;
        break;
      case 'follow':
        notifBody = `${senderName} started following you`;
        break;
      case 'group_invite':
        notifBody = `${senderName} invited you to join ${groupName || ''}`.trim();
        break;
      case 'group_post':
        notifBody = `${senderName} posted in group ${groupName || ''}`.trim();
        break;
      case 'friend_live':
      case 'livestream':
        notifBody = `${senderName} is live: "${content || 'Live Stream'}" 🔴`;
        break;
      case 'friend_post':
        notifBody = content ? `${senderName} published a new post: "${content.length > 50 ? content.substring(0, 47) + '...' : content}"` : `${senderName} published a new post`;
        break;
      case 'friend_story':
        notifBody = `${senderName} shared a new story`;
        break;
      case 'like':
        notifBody = `${senderName} liked your story`;
        break;
      case 'comment':
        notifBody = `${senderName} commented on your post: "${(content || '').substring(0, 50)}"`;
        break;
      default:
        if (!notifBody) notifBody = 'You have a new notification on Viora';
        break;
    }

    const populatedNotif = await Notification.findById(savedNotif._id)
      .populate('sender', 'username avatar bio')
      .populate('group', 'name avatar')
      .populate('post', 'content images')
      .populate('request', 'sender receiver status type')
      .populate('livestream', 'title channelName mode status host thumbnail viewersCount startedAt')
      .lean();

    const io = getIO ? getIO() : null;
    if (io) {
      io.to(recipient.toString()).emit('new_notification', populatedNotif);
    }

    try {
      await sendPushNotification({
        recipientId: recipient,
        title: notifTitle,
        body: notifBody,
        data: {
          notificationId: savedNotif._id.toString(),
          type: type || 'general',
          reaction: reaction || '',
          senderId: sender ? sender.toString() : '',
          senderName: senderName,
          senderAvatar: senderAvatar || '',
          groupId: group ? group.toString() : '',
          groupName: groupName,
          postId: post ? post.toString() : '',
          liveId: livestream ? livestream.toString() : '',
          requestId: request ? request.toString() : '',
          status: savedNotif.status
        },
        imageUrl: senderAvatar
      });
    } catch (fcmErr) {
      console.error('Trigger push notification error:', fcmErr);
    }

    return populatedNotif;
  } catch (err) {
    console.error('createNotification error:', err);
    return null;
  }
};

const getNotifications = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User ID is required' });
    }

    const notifications = await Notification.find({
      recipient: userId,
      type: { $ne: 'message' }
    })
      .populate('sender', 'username avatar bio')
      .populate('group', 'name avatar')
      .populate('post', 'content images')
      .populate('request', 'sender receiver status type')
      .populate('livestream', 'title channelName mode status host thumbnail viewersCount startedAt')
      .sort({ createdAt: -1 })
      .limit(60)
      .lean();

    const unreadCount = await Notification.countDocuments({
      recipient: userId,
      type: { $ne: 'message' },
      isRead: false
    });

    return res.status(200).json({
      success: true,
      notifications,
      unreadCount
    });
  } catch (error) {
    console.error('getNotifications error:', error);
    return res.status(500).json({ success: false, code: 'FETCH_NOTIFICATIONS_FAILED', message: error.message || 'Failed to fetch notifications' });
  }
};

const markNotificationRead = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { notificationId } = req.body;

    if (!notificationId) {
      return res.status(400).json({ success: false, code: 'NOTIFICATION_ID_REQUIRED', message: 'notificationId is required' });
    }

    await Notification.findOneAndUpdate(
      { _id: notificationId, recipient: userId },
      { isRead: true }
    );

    return res.status(200).json({ success: true, message: 'Notification marked as read' });
  } catch (error) {
    console.error('markNotificationRead error:', error);
    return res.status(500).json({ success: false, code: 'SERVER_ERROR', message: error.message });
  }
};

const markAllNotificationsRead = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User ID is required' });
    }

    await Notification.updateMany(
      { recipient: userId, type: { $ne: 'message' } },
      { isRead: true }
    );

    return res.status(200).json({ success: true, message: 'All notifications marked as read' });
  } catch (error) {
    console.error('markAllNotificationsRead error:', error);
    return res.status(500).json({ success: false, code: 'SERVER_ERROR', message: error.message });
  }
};

const clearAllNotifications = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    if (!userId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User ID is required' });
    }

    await Notification.deleteMany({
      recipient: userId,
      type: { $ne: 'message' }
    });

    return res.status(200).json({ success: true, message: 'All notifications cleared' });
  } catch (error) {
    console.error('clearAllNotifications error:', error);
    return res.status(500).json({ success: false, code: 'SERVER_ERROR', message: error.message });
  }
};

const updateNotificationStatus = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { notificationId, status } = req.body;

    if (!notificationId || !status) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'notificationId and status are required' });
    }

    const updated = await Notification.findOneAndUpdate(
      { _id: notificationId, recipient: userId },
      { status, isRead: true },
      { new: true }
    );

    return res.status(200).json({ success: true, notification: updated });
  } catch (error) {
    console.error('updateNotificationStatus error:', error);
    return res.status(500).json({ success: false, code: 'SERVER_ERROR', message: error.message });
  }
};

const updateFcmToken = async (req, res) => {
  try {
    const userId = getUserIdFromReq(req);
    const { fcmToken } = req.body;

    if (!userId || !fcmToken) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and fcmToken are required' });
    }

    await Account.updateMany(
      { _id: { $ne: userId }, $or: [{ fcmToken }, { fcmTokens: fcmToken }] },
      { $pull: { fcmTokens: fcmToken } }
    );

    await Account.findByIdAndUpdate(userId, {
      fcmToken,
      $addToSet: { fcmTokens: fcmToken }
    });

    return res.status(200).json({ success: true, message: 'FCM Token updated successfully' });
  } catch (error) {
    console.error('updateFcmToken error:', error);
    return res.status(500).json({ success: false, code: 'UPDATE_FCM_TOKEN_FAILED', message: error.message || 'Failed to update FCM token' });
  }
};

module.exports = {
  createNotification,
  getNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  clearAllNotifications,
  updateNotificationStatus,
  updateFcmToken
};
