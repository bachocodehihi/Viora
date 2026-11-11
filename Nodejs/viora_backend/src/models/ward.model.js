const mongoose = require('mongoose');

const wardSchema = new mongoose.Schema({
  nameWard: { 
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

wardSchema.index({ cityId: 1 });

const Ward = mongoose.model('Ward', wardSchema);
module.exports = Ward;