const mongoose = require('mongoose');

const statusSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  content: { type: String, default: '' },
  mediaUrl: { type: String, default: '' },
  mediaType: { type: String, enum: ['image', 'video', 'text'], default: 'image' },
  backgroundColor: { type: String, default: '#000000' },
  
  viewers: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'Account' },
    viewedAt: { type: Date, default: Date.now }
  }],
  
  privacy: { type: String, enum: ['public', 'friends', 'private'], default: 'friends' },
  
  expiresAt: { 
    type: Date, 
    default: () => new Date(Date.now() + 24 * 60 * 60 * 1000),
    index: { expires: 0 }
  }
}, { timestamps: true });

statusSchema.index({ user: 1, createdAt: -1 });

const Status = mongoose.model('Status', statusSchema);
module.exports = Status;