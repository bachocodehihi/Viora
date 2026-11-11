const mongoose = require('mongoose');

const groupMemberSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  role: {
    type: String,
    enum: ['owner', 'admin', 'moderator', 'member'],
    default: 'member'
  },
  joinedAt: { type: Date, default: Date.now }
}, { _id: false });

const joinRequestSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  message: { type: String, default: '' },
  requestedAt: { type: Date, default: Date.now }
}, { _id: false });

const groupSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  avatar: { type: String, default: '' },
  coverImage: { type: String, default: '' },
  description: { type: String, default: '' },

  owner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Account',
    required: true
  },
  members: [groupMemberSchema],
  membersCount: { type: Number, default: 0 },

  privacy: {
    type: String,
    enum: ['public', 'private', 'secret'],
    default: 'public'
  },

  qrCode: { type: String, default: '' },

  joinRequests: [joinRequestSchema],

  inviteCode: { type: String, unique: true, sparse: true },
  inviteLink: { type: String, default: '' },

  chatConversation: { type: mongoose.Schema.Types.ObjectId, ref: 'Conversation', default: null },
  pinnedPosts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }],

  settings: {
    privacy: { type: String, enum: ['public', 'private', 'secret'], default: 'public' },
    joinPolicy: { type: String, enum: ['open', 'approval', 'invite_only'], default: 'open' },
    postPolicy: { type: String, enum: ['open', 'approval', 'admins_only'], default: 'open' },
    allowMemberInvite: { type: Boolean, default: true },
    memberLimit: { type: Number, default: 0 }
  }
}, { timestamps: true });

groupSchema.index({ 'members.user': 1 });
groupSchema.index({ owner: 1 });
groupSchema.index({ name: 'text' });
groupSchema.index({ privacy: 1 });
groupSchema.index({ 'joinRequests.user': 1 });

const Group = mongoose.model('Group', groupSchema);
module.exports = Group;
