const mongoose = require('mongoose');

const searchSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true, index: true },
  query: { type: String, required: true, trim: true },
  targetType: { type: String, enum: ['keyword', 'user', 'group', 'post'], default: 'keyword' },
  targetId: { type: mongoose.Schema.Types.ObjectId, default: null },
  targetData: { type: mongoose.Schema.Types.Mixed, default: null },
}, { timestamps: true });

searchSchema.index({ user: 1, query: 1 });
searchSchema.index({ user: 1, updatedAt: -1 });

const Search = mongoose.model('Search', searchSchema);
module.exports = Search;