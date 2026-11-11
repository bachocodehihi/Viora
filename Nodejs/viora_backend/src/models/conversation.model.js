const mongoose = require('mongoose');

const conversationMemberSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  role: { type: String, enum: ['admin', 'member'], default: 'member' },
  lastReadAt: { type: Date, default: null },
  isMuted: { type: Boolean, default: false },
  isPinned: { type: Boolean, default: false },
  joinedAt: { type: Date, default: Date.now }
}, { _id: false });

const conversationSchema = new mongoose.Schema({
  type: { type: String, enum: ['direct', 'group_chat'], default: 'direct' },
  name: { type: String, default: '' },
  avatar: { type: String, default: '' },
  members: [conversationMemberSchema],
  lastMessage: { type: mongoose.Schema.Types.ObjectId, ref: 'Message', default: null },
  pinnedMessage: { type: mongoose.Schema.Types.ObjectId, ref: 'Message', default: null },
  pinnedMessages: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Message' }],
  communityGroup: { type: mongoose.Schema.Types.ObjectId, ref: 'Group', default: null }
}, { timestamps: true });

conversationSchema.index({ 'members.user': 1, updatedAt: -1 });
conversationSchema.index({ communityGroup: 1 }, { sparse: true });

const Conversation = mongoose.model('Conversation', conversationSchema);
module.exports = Conversation;
