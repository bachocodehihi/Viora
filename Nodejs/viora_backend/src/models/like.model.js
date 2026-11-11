const mongoose = require('mongoose');

const likeSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  target: { type: mongoose.Schema.Types.ObjectId, required: true },
  targetType: { type: String, enum: ['Post', 'Comment', 'Status'], required: true },
  type: {
    type: String,
    enum: ['like', 'love', 'haha', 'wow', 'sad', 'angry'],
    default: 'like'
  }
}, { timestamps: true });

likeSchema.index({ user: 1, target: 1, targetType: 1 }, { unique: true });
likeSchema.index({ target: 1, targetType: 1 });

const Like = mongoose.model('Like', likeSchema);
module.exports = Like;
