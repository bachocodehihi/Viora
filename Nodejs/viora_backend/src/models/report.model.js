const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  reporter: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  targetType: { type: String, enum: ['user', 'post', 'group', 'comment'], default: 'user' },
  targetId: { type: mongoose.Schema.Types.ObjectId, required: true },
  reason: { type: String, required: true },
  status: { type: String, enum: ['pending', 'resolved', 'dismissed'], default: 'pending' }
}, { timestamps: true });

reportSchema.index({ reporter: 1, targetId: 1 });

const Report = mongoose.model('Report', reportSchema);
module.exports = Report;