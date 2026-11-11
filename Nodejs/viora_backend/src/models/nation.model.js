const mongoose = require('mongoose');

const nationSchema = new mongoose.Schema({
  nameNation: { 
    type: String, 
    required: true, 
    unique: true,
    trim: true 
  },
  numberNation: { 
    type: String, 
    default: '',
    trim: true 
  },
  code: { 
    type: String, 
    default: '',
    trim: true 
  },
  continentId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Continent', 
    default: null 
  },
}, { 
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

nationSchema.index({ continentId: 1 });

nationSchema.virtual('cities', {
  ref: 'City',
  localField: '_id',
  foreignField: 'nationId',
});

const Nation = mongoose.model('Nation', nationSchema);
module.exports = Nation;