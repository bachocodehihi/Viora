const mongoose = require('mongoose');

const postSchema = new mongoose.Schema({
  author: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  content: { type: String, default: '' },
  images: [{ type: String }],
  videos: [{ type: String }],

  likesCount: { type: Number, default: 0 },
  commentsCount: { type: Number, default: 0 },
  sharesCount: { type: Number, default: 0 },
  sharedFrom: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', default: null },

  postType: { type: String, enum: ['user', 'group'], default: 'user' },
  privacy: {
    type: String,
    enum: ['public', 'friends', 'private', 'friends_except', 'specific_friends'],
    default: 'public'
  },
  allowedFriends: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  exceptedFriends: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],

  group: { type: mongoose.Schema.Types.ObjectId, ref: 'Group', default: null },
  isAnonymous: { type: Boolean, default: false },

  commentsDisabled: { type: Boolean, default: false },
  commentPermission: {
    type: String,
    enum: ['everyone', 'friends', 'selected'],
    default: 'everyone'
  },
  allowedCommenters: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  blockedCommenters: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'approved' },
  isDeleted: { type: Boolean, default: false }
}, { timestamps: true });

postSchema.pre('validate', function () {
  const hasContent = this.content && this.content.trim();
  const hasMedia = (this.images && this.images.length) || (this.videos && this.videos.length);
  if (!hasContent && !hasMedia && !this.sharedFrom) {
    throw new Error('Post must have content, media, or a shared post');
  }
});

postSchema.index({ author: 1, createdAt: -1 });
postSchema.index({ group: 1, createdAt: -1 });
postSchema.index({ createdAt: -1, privacy: 1 });

const Post = mongoose.model('Post', postSchema);
module.exports = Post;
