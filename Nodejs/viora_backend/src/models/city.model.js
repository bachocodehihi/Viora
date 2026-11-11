const mongoose = require('mongoose');

const citySchema = new mongoose.Schema({
  nameCity: { 
    type: String, 
    required: true, 
    trim: true 
  },
  nationId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Nation', 
    required: true 
  },
}, { 
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

citySchema.index({ nationId: 1 });

citySchema.virtual('wards', {
  ref: 'Ward',
  localField: '_id',
  foreignField: 'cityId',
});

const City = mongoose.model('City', citySchema);
module.exports = City;
