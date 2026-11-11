const mongoose = require('mongoose');

const liveStreamSchema = new mongoose.Schema({
  host: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  title: { type: String, required: true, trim: true, default: 'Buổi phát trực tiếp' },
  channelName: { type: String, required: true, unique: true },
  mode: { type: String, enum: ['camera', 'screen'], default: 'camera' },
  status: { type: String, enum: ['live', 'ended'], default: 'live' },
  
  viewersCount: { type: Number, default: 0 },
  maxViewers: { type: Number, default: 0 },
  likesCount: { type: Number, default: 0 },
  reactionsCount: {
    love: { type: Number, default: 0 },
    like: { type: Number, default: 0 },
    care: { type: Number, default: 0 },
    haha: { type: Number, default: 0 },
    wow: { type: Number, default: 0 },
    sad: { type: Number, default: 0 },
    angry: { type: Number, default: 0 }
  },
  
  thumbnail: { type: String, default: null },
  duration: { type: Number, default: 0 },
  
  startedAt: { type: Date, default: Date.now },
  endedAt: { type: Date, default: null },
  
  savedPost: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', default: null },
  isSavedAsPost: { type: Boolean, default: false }
}, { timestamps: true });

liveStreamSchema.index({ status: 1, createdAt: -1 });
liveStreamSchema.index({ host: 1, status: 1 });

const LiveStream = mongoose.model('LiveStream', liveStreamSchema);
module.exports = LiveStream;
