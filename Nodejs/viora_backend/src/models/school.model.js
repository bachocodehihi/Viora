const mongoose = require('mongoose');

const schoolSchema = new mongoose.Schema({
  nameSchool: { 
    type: String, 
    required: true, 
    trim: true 
  },
  cityId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'City', 
    required: true 
  },
}, { 
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

schoolSchema.index({ cityId: 1 });

const School = mongoose.model('School', schoolSchema);
module.exports = School;