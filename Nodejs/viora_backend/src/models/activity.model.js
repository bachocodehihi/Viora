const mongoose = require('mongoose');

const activitySchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'Account', required: true },
  date: { type: String, required: true },
  totalSeconds: { type: Number, default: 0 },
  hourlySeconds: { type: [Number], default: () => Array(24).fill(0) },
}, { timestamps: true });

activitySchema.index({ userId: 1, date: 1 }, { unique: true });

const Activity = mongoose.model('Activity', activitySchema);
module.exports = Activity;