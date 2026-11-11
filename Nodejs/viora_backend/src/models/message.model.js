const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  conversationId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Conversation',
    required: true
  },
  sender: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Account',
    required: true
  },
  content: { type: String, default: '' },
  type: {
    type: String,
    enum: ['text', 'image', 'video', 'file', 'audio', 'location', 'system', 'poll', 'call'],
    default: 'text'
  },
  call: {
    type: new mongoose.Schema({
      callId: { type: String, default: '' },
      callDocId: { type: mongoose.Schema.Types.ObjectId, ref: 'Call', default: null },
      callType: { type: String, enum: ['audio', 'video'], default: 'audio' },
      status: {
        type: String,
        enum: ['ringing', 'ongoing', 'completed', 'missed', 'declined', 'cancelled'],
        default: 'completed'
      },
      duration: { type: Number, default: 0 },
      caller: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', default: null },
      endedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', default: null },
    }, { _id: false }),
    default: null
  },
  poll: {
    type: new mongoose.Schema({
      question: { type: String, required: true },
      options: [{
        id: { type: String, required: true },
        text: { type: String, required: true },
        voterIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }]
      }],
      multipleAnswers: { type: Boolean, default: false },
      isClosed: { type: Boolean, default: false },
      closedAt: { type: Date, default: null },
      lastVote: {
        voterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Account' },
        voterName: { type: String, default: '' },
        action: { type: String, default: '' },
        optionId: { type: String, default: '' },
        optionText: { type: String, default: '' },
        updatedAt: { type: Date, default: null }
      }
    }, { _id: false }),
    default: null
  },
  location: {
    type: new mongoose.Schema({
      latitude: { type: Number },
      longitude: { type: Number },
      address: { type: String, default: '' },
      name: { type: String, default: '' },
      isLive: { type: Boolean, default: true },
      status: { type: String, enum: ['active', 'stopped'], default: 'active' },
    }, { _id: false }),
    default: null
  },
  readBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  deletedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  hiddenFrom: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Account' }],
  recipientOnlyFriends: { type: Boolean, default: false },
  isRecalled: { type: Boolean, default: false },
  isEdited: { type: Boolean, default: false },
  repliedTo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null
  },
  attachments: [{ type: String }],
  reactions: [
    {
      user: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
      reaction: { type: String, required: true },
      createdAt: { type: Date, default: Date.now }
    }
  ],
  createdAt: { type: Date, default: Date.now, immutable: false }
}, { timestamps: { createdAt: false, updatedAt: true } });

messageSchema.index({ conversationId: 1, createdAt: -1 });

const Message = mongoose.model('Message', messageSchema);
module.exports = Message;
