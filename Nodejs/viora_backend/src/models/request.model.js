const mongoose = require('mongoose');

const requestSchema = new mongoose.Schema({
  sender: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  receiver: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  type: {
    type: String,
    enum: ['friend', 'follow', 'group_join', 'group_invite'],
    required: true,
    default: 'friend'
  },
  group: { type: mongoose.Schema.Types.ObjectId, ref: 'Group', default: null },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected', 'cancelled'],
    default: 'pending'
  }
}, { timestamps: true });

requestSchema.index(
  { sender: 1, receiver: 1, type: 1, group: 1 },
  { unique: true }
);
requestSchema.index({ receiver: 1, type: 1, status: 1 });
requestSchema.index({ group: 1, type: 1, status: 1 });

const Request = mongoose.model('Request', requestSchema);
module.exports = Request;
