const mongoose = require('mongoose');

const otpSchema = new mongoose.Schema({
  email: { type: String, required: true, lowercase: true, trim: true },
  otp: { type: String, required: true },
  purpose: { type: String, enum: ['signup', 'reset', 'delete_account', 'login_2fa'], default: 'signup' },
  isVerified: { type: Boolean, default: false },
  attempts: { type: Number, default: 1 },
  otpTime: { type: Date, default: Date.now }
});

otpSchema.index({ email: 1, purpose: 1 });
otpSchema.index({ otpTime: 1 }, { expireAfterSeconds: 300 });

const OTP = mongoose.model('OTP', otpSchema);
module.exports = OTP;
