const express = require('express');
const router = express.Router();

const { 
  checkEmail,
  sendOtp,
  verifyOtp,
  signUp,
  signIn,
  googleSignIn,
  resetPassword
} = require('../controllers/auth.controller');

router.post('/check-email', checkEmail);
router.post('/send-otp', sendOtp);
router.post('/verify-otp', verifyOtp);
router.post('/sign-up', signUp);
router.post('/sign-in', signIn);
router.post('/google-sign-in', googleSignIn);
router.post('/reset-password', resetPassword);

module.exports = router;