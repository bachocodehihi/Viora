const mongoose = require('mongoose');

const callSchema = new mongoose.Schema({
  callId: { type: String, required: true, unique: true, index: true },
  caller: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  receiver: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', default: null },
  conversationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Conversation', default: null },
  isGroup: { type: Boolean, default: false },
  participants: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  activeParticipants: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  declinedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  channelName: { type: String, required: true },
  type: { type: String, enum: ['audio', 'video'], default: 'audio' },
  status: {
    type: String,
    enum: ['ringing', 'ongoing', 'completed', 'missed', 'declined', 'busy', 'cancelled'],
    default: 'ringing'
  },
  duration: { type: Number, default: 0 },
  startedAt: { type: Date, default: Date.now },
  answeredAt: { type: Date, default: null },
  endedAt: { type: Date, default: null },
  lastActivityAt: { type: Date, default: Date.now },
  participantHeartbeats: { type: Map, of: Date, default: {} },
  endedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', default: null },
  messageCreated: { type: Boolean, default: false },
  messageId: { type: mongoose.Schema.Types.ObjectId, ref: 'Message', default: null }
}, { timestamps: true });

callSchema.index({ caller: 1, createdAt: -1 });
callSchema.index({ receiver: 1, createdAt: -1 });
callSchema.index({ participants: 1, createdAt: -1 });
callSchema.index({ conversationId: 1, status: 1, createdAt: -1 });

const Call = mongoose.model('Call', callSchema);
module.exports = Call;
