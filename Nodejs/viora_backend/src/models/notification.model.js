const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  recipient: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  sender: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', default: null },
  type: {
    type: String,
    enum: [
      'like',
      'comment',
      'reply',
      'share',
      'mention',
      'follow',
      'friend_request',
      'friend_accept',
      'group_invite',
      'group_join',
      'group_post',
      'friend_post',
      'friend_story',
      'friend_live',
      'livestream',
      'message',
      'call',
      'system'
    ],
    required: true
  },
  post: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', default: null },
  group: { type: mongoose.Schema.Types.ObjectId, ref: 'Group', default: null },
  comment: { type: mongoose.Schema.Types.ObjectId, ref: 'Comment', default: null },
  conversation: { type: mongoose.Schema.Types.ObjectId, ref: 'Conversation', default: null },
  request: { type: mongoose.Schema.Types.ObjectId, ref: 'Request', default: null },
  livestream: { type: mongoose.Schema.Types.ObjectId, ref: 'LiveStream', default: null },
  status: { type: String, enum: ['pending', 'accepted', 'declined', 'none'], default: 'none' },
  reaction: { type: String, default: null },
  content: { type: String, default: '' },
  isRead: { type: Boolean, default: false }
}, { timestamps: true });

notificationSchema.index({ recipient: 1, createdAt: -1 });
notificationSchema.index({ recipient: 1, isRead: 1 });

const Notification = mongoose.model('Notification', notificationSchema);
module.exports = Notification;
