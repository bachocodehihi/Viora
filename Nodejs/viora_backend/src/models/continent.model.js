const mongoose = require('mongoose');

const continentSchema = new mongoose.Schema({
  nameContinent: { 
    type: String, 
    required: true, 
    unique: true,
    trim: true 
  },
}, { 
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

continentSchema.virtual('nations', {
  ref: 'Nation',
  localField: '_id',
  foreignField: 'continentId',
});

const Continent = mongoose.model('Continent', continentSchema);
module.exports = Continent;

