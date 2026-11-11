const bcrypt = require('bcrypt');
const Account = require('../models/account.model');
const OTP = require('../models/otp.model');
const { sendOTP, signUpSuccessful, signInSuccessful, changePasswordSuccessful } = require('../services/email.service');
const { generateToken, generateTwoFactorToken, verifyTwoFactorToken } = require('../config/jwt.config');
const { generateUserQRCode } = require('../services/qrcode.service');
const { getLocale } = require('../locales');

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const OTP_TTL_MS = 5 * 60 * 1000;
const SIGNUP_FLOW_TTL_MS = 30 * 60 * 1000;
const OTP_RESEND_MS = 60 * 1000;
const SALT_ROUNDS = 10;

const normalizeEmail = (email) => String(email || '').trim().toLowerCase();

const isValidEmail = (email) => EMAIL_REGEX.test(email);

const publicAccount = (account) => {
  const obj = account.toObject({ virtuals: true });
  delete obj.password;
  obj.showActiveStatus = obj.privacy?.showActiveStatus !== false;
  return obj;
};

const findActiveAccountByEmail = (email) =>
  Account.findOne({ email, isDeleted: false });

const resolveOtpPurpose = (rawPurpose) => {
  if (rawPurpose === 'delete_account') return 'delete_account';
  if (rawPurpose === 'reset' || rawPurpose === 'reset_password') return 'reset';
  if (rawPurpose === 'login_2fa') return 'login_2fa';
  return 'signup';
};

const issueAndSendOtp = async (email, purpose, language = 'en') => {
  let attempts = 1;
  const latestOtp = await OTP.findOne({ email, purpose }).sort({ otpTime: -1 });

  if (latestOtp) {
    if (latestOtp.attempts >= 5) {
      if (Date.now() - latestOtp.otpTime.getTime() < OTP_RESEND_MS) {
        const retryAfter = Math.ceil(
          (OTP_RESEND_MS - (Date.now() - latestOtp.otpTime.getTime())) / 1000
        );
        return { rateLimited: true, retryAfter };
      }
      attempts = 1;
    } else {
      attempts = latestOtp.attempts + 1;
    }
  }

  const otp = String(Math.floor(100000 + Math.random() * 900000));
  const hashedOtp = await bcrypt.hash(otp, SALT_ROUNDS);

  await OTP.deleteMany({ email, purpose });
  await OTP.create({
    email,
    otp: hashedOtp,
    purpose,
    isVerified: false,
    attempts,
    otpTime: new Date(),
  });

  sendOTP(email, otp, language).catch(err => console.error('Failed to send email:', err));
  return { rateLimited: false };
};

const completeSignIn = async (account, { deviceId = '', deviceName = 'Mobile Device', language = 'en' } = {}) => {
  if (deviceId) {
    try {
      const { getIO } = require('../socket');
      const io = getIO();
      if (io) {
        io.to(account._id.toString()).emit('account_conflict', {
          deviceName: deviceName || 'Mobile Device',
          deviceId,
        });
        console.log(`[AUTH] Emitted account_conflict for user ${account._id} on device ${deviceName} (${deviceId})`);
      }
    } catch (sErr) {
      console.error('[AUTH] Failed to emit account_conflict:', sErr);
    }

    account.currentDeviceId = deviceId;
    account.currentDeviceName = deviceName;
  }

  const showActiveStatus = account.privacy?.showActiveStatus !== false;
  if (showActiveStatus) {
    account.isOnline = true;
    account.lastSeen = new Date();
  } else {
    account.isOnline = false;
  }

  if (!account.qrCode) {
    try {
      const qrCodeUrl = await generateUserQRCode(account._id.toString(), account.username);
      account.qrCode = qrCodeUrl;
    } catch (qrErr) {
      console.error('Failed to generate QR code on sign in:', qrErr);
    }
  }

  await account.save();

  const token = generateToken({
    id: account._id,
    email: account.email,
    role: account.role,
  });

  console.log('🔑 [SIGN IN SUCCESS]:', account.email);

  signInSuccessful(account.email, language).catch(err => console.error('Failed to send sign-in email:', err));

  return {
    token,
    account: publicAccount(account),
  };
};

const initiateTwoFactorLogin = async (account, language = 'en') => {
  const otpResult = await issueAndSendOtp(account.email, 'login_2fa', language);
  if (otpResult.rateLimited) {
    return { rateLimited: true, retryAfter: otpResult.retryAfter };
  }

  const twoFactorToken = generateTwoFactorToken({
    pendingAccountId: account._id.toString(),
    email: account.email,
  });

  console.log('🔐 [2FA OTP SENT]:', account.email);

  return {
    rateLimited: false,
    twoFactorToken,
  };
};

const checkEmail = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    if (!isValidEmail(email)) {
      return res.status(400).json({ 
        code: 'INVALID_EMAIL',
        message: 'Invalid email'
      });
    }

    const account = await findActiveAccountByEmail(email);
    return res.status(200).json({
      exists: !!account,
      email,
    });
  } catch (error) {
    return res.status(500).json({ 
      code: 'CHECK_EMAIL_FAILED',
      message: 'Failed to check email'
    });
  }
};

const sendOtp = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const purpose = resolveOtpPurpose(req.body.purpose);
    const language = req.body.language || req.headers['accept-language'] || 'en';

    if (!isValidEmail(email)) {
      return res.status(400).json({ 
        code: 'INVALID_EMAIL',
        message: 'Invalid email' 
      });
    }

    const account = await findActiveAccountByEmail(email);
    if (purpose === 'signup' && account) {
      return res.status(409).json({ 
        code: 'EMAIL_ALREADY_SIGNED_UP',
        message: 'Email is already signed up' 
      });
    }
    if ((purpose === 'reset' || purpose === 'delete_account') && !account) {
      return res.status(404).json({ 
        code: 'EMAIL_NOT_SIGNED_UP',
        message: 'Email is not signed up' 
      });
    }

    if (purpose === 'login_2fa') {
      const twoFactorToken = String(req.body.twoFactorToken || '').trim();
      if (!twoFactorToken) {
        return res.status(401).json({
          code: 'TWO_FACTOR_SESSION_EXPIRED',
          message: 'Two-factor verification session expired, please sign in again',
        });
      }
      try {
        const decoded = verifyTwoFactorToken(twoFactorToken);
        if (normalizeEmail(decoded.email) !== email) {
          return res.status(401).json({
            code: 'TWO_FACTOR_SESSION_EXPIRED',
            message: 'Two-factor verification session expired, please sign in again',
          });
        }
      } catch (_) {
        return res.status(401).json({
          code: 'TWO_FACTOR_SESSION_EXPIRED',
          message: 'Two-factor verification session expired, please sign in again',
        });
      }
      if (!account) {
        return res.status(404).json({
          code: 'EMAIL_NOT_SIGNED_UP',
          message: 'Email is not signed up',
        });
      }
      if (!account.twoFactorEnabled) {
        return res.status(400).json({
          code: 'TWO_FACTOR_NOT_ENABLED',
          message: 'Two-factor authentication is not enabled for this account',
        });
      }
    }

    const otpResult = await issueAndSendOtp(email, purpose, language);
    if (otpResult.rateLimited) {
      return res.status(429).json({
        code: 'TOO_MANY_REQUESTS',
        message: 'Please wait before requesting another code',
        retryAfter: otpResult.retryAfter,
      });
    }

    return res.status(200).json({
      message: 'OTP sent',
      email,
      purpose,
      expiresIn: 60,
    });
  } catch (error) {
    return res.status(500).json({ 
      code: 'SEND_OTP_FAILED',
      message: 'Failed to send OTP' 
    });
  }
};

const verifyOtp = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const otp = String(req.body.otp || '').trim();
    const purpose = resolveOtpPurpose(req.body.purpose);

    if (!isValidEmail(email)) {
      return res.status(400).json({ code: 'INVALID_EMAIL', message: 'Invalid email' });
    }
    if (!/^\d{6}$/.test(otp)) {
      return res.status(400).json({ code: 'INVALID_OTP_FORMAT', message: 'OTP must be 6 digits' });
    }

    let decodedTwoFactor = null;
    if (purpose === 'login_2fa') {
      const twoFactorToken = String(req.body.twoFactorToken || '').trim();
      if (!twoFactorToken) {
        return res.status(401).json({
          code: 'TWO_FACTOR_SESSION_EXPIRED',
          message: 'Two-factor verification session expired, please sign in again',
        });
      }
      try {
        decodedTwoFactor = verifyTwoFactorToken(twoFactorToken);
        if (normalizeEmail(decodedTwoFactor.email) !== email) {
          return res.status(401).json({
            code: 'TWO_FACTOR_SESSION_EXPIRED',
            message: 'Two-factor verification session expired, please sign in again',
          });
        }
      } catch (_) {
        return res.status(401).json({
          code: 'TWO_FACTOR_SESSION_EXPIRED',
          message: 'Two-factor verification session expired, please sign in again',
        });
      }
    }

    const record = await OTP.findOne({ email, purpose }).sort({ otpTime: -1 });
    if (!record) {
      return res.status(400).json({ code: 'OTP_NOT_FOUND', message: 'OTP not found or expired' });
    }
    if (Date.now() - record.otpTime.getTime() > OTP_TTL_MS) {
      await OTP.deleteMany({ email, purpose });
      return res.status(400).json({ code: 'OTP_EXPIRED', message: 'OTP expired' });
    }

    const matched = await bcrypt.compare(otp, record.otp);
    if (!matched) {
      return res.status(400).json({ code: 'INVALID_OTP', message: 'Incorrect OTP' });
    }

    if (purpose === 'login_2fa') {
      const account = await Account.findOne({
        _id: decodedTwoFactor.pendingAccountId,
        email,
        isDeleted: false,
      });
      if (!account) {
        return res.status(404).json({
          code: 'ACCOUNT_NOT_FOUND',
          message: 'Account not found',
        });
      }

      await OTP.deleteMany({ email, purpose: 'login_2fa' });

      const language = req.body.language || req.headers['accept-language'] || 'en';
      const deviceName = String(req.body.deviceName || 'Mobile Device').trim();
      const deviceId = String(req.body.deviceId || '').trim();

      const { token, account: sanitizedAccount } = await completeSignIn(account, {
        deviceId,
        deviceName,
        language,
      });

      return res.status(200).json({
        success: true,
        message: 'Sign in successful',
        token,
        account: sanitizedAccount,
      });
    }

    record.isVerified = true;
    await record.save();

    return res.status(200).json({
      message: 'OTP verified',
      email,
      purpose,
    });
  } catch (error) {
    return res.status(500).json({ code: 'VERIFY_OTP_FAILED', message: 'Failed to verify OTP' });
  }
};

const signUp = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const username = String(req.body.username || '').trim();
    const password = String(req.body.password || '');
    const { birthday, gender } = req.body;
    const language = req.body.language || req.headers['accept-language'] || 'en';

    if (!isValidEmail(email)) {
      return res.status(400).json({ code: 'INVALID_EMAIL', message: 'Invalid email' });
    }
    if (username.length < 2) {
      return res.status(400).json({ code: 'USERNAME_REQUIRED', message: 'Username is required' });
    }
    if (password.length < 6) {
      return res.status(400).json({ code: 'INVALID_PASSWORD', message: 'Password must be at least 6 characters' });
    }
    if (!birthday) {
      return res.status(400).json({ code: 'BIRTHDAY_REQUIRED', message: 'Birthday is required' });
    }
    if (!['male', 'female', 'other'].includes(gender)) {
      return res.status(400).json({ code: 'INVALID_GENDER', message: 'Gender is invalid' });
    }

    const birthdayDate = new Date(birthday);
    if (Number.isNaN(birthdayDate.getTime())) {
      return res.status(400).json({ code: 'INVALID_BIRTHDAY', message: 'Birthday is invalid' });
    }

    const existingEmail = await findActiveAccountByEmail(email);
    if (existingEmail) {
      return res.status(409).json({ 
        code: 'EMAIL_ALREADY_SIGNED_UP',
        message: 'Email is already registered' 
      });
    }

    const verifiedOtp = await OTP.findOne({
      email,
      purpose: 'signup',
      isVerified: true,
    }).sort({ otpTime: -1 });

    if (!verifiedOtp) {
      console.warn('⚠️ [SIGN UP] Email not verified via OTP:', email);
      return res.status(400).json({ code: 'EMAIL_NOT_VERIFIED', message: 'Email has not been verified, please try again!' });
    }
    if (Date.now() - verifiedOtp.otpTime.getTime() > SIGNUP_FLOW_TTL_MS) {
      console.warn('⚠️ [SIGN UP] Registration session expired (>30m):', email);
      await OTP.deleteMany({ email, purpose: 'signup' });
      return res.status(400).json({ code: 'SESSION_EXPIRED', message: 'Registration session expired (exceeded 30 minutes), please verify email again!' });
    }

    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);
    const account = await Account.create({
      email,
      username,
      password: hashedPassword,
      birthday: birthdayDate,
      gender,
      isVerified: true,
    });

    await OTP.deleteMany({ email, purpose: 'signup' });

    try {
      const qrCodeUrl = await generateUserQRCode(account._id.toString(), account.username);
      account.qrCode = qrCodeUrl;
      await account.save();
    } catch (qrError) {
      console.error('Failed to generate QR code:', qrError);
    }

    const token = generateToken({
      id: account._id,
      email: account.email,
      role: account.role,
    });

    console.log('🎉 [SIGN UP SUCCESS] Account created successfully:', account.email);

    signUpSuccessful(account.email, language).catch(err => console.error('Failed to send welcome email:', err));

    return res.status(201).json({
      message: 'Sign up successful',
      token,
      account: publicAccount(account),
    });
  } catch (error) {
    console.error('❌ [SIGN UP ERROR]:', error);
    if (error && error.code === 11000) {
      return res.status(409).json({ 
        code: 'EMAIL_ALREADY_SIGNED_UP',
        message: 'Email is already signed up' 
      });
    }
    return res.status(500).json({ 
      code: 'SIGN_UP_FAILED',
      message: error.message || 'Failed to sign up' 
    });
  }
};

const signIn = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const password = String(req.body.password || '');
    const language = req.body.language || req.headers['accept-language'] || 'en';

    const deviceName = String(req.body.deviceName || 'Mobile Device').trim();
    const deviceId = String(req.body.deviceId || '').trim();

    if (!isValidEmail(email) || !password) {
      return res.status(400).json({ 
        code: 'INVALID_FIELDS',
        message: 'Email and password are required' 
      });
    }

    const account = await Account.findOne({ email });
    if (!account || account.isDeleted) {
      return res.status(401).json({ 
        code: 'INVALID_CREDENTIALS',
        message: 'Invalid email or password' 
      });
    }
    if (!account.password) {
      return res.status(400).json({ 
        code: 'GOOGLE_ACCOUNT',
        message: 'This account uses Google sign-in' 
      });
    }

    const matched = await bcrypt.compare(password, account.password);
    if (!matched) {
      return res.status(401).json({ 
        code: 'INVALID_CREDENTIALS',
        message: 'Invalid email or password' 
      });
    }

    if (account.twoFactorEnabled) {
      const twoFactorResult = await initiateTwoFactorLogin(account, language);
      if (twoFactorResult.rateLimited) {
        return res.status(429).json({
          code: 'TOO_MANY_REQUESTS',
          message: 'Please wait before requesting another code',
          retryAfter: twoFactorResult.retryAfter,
        });
      }

      return res.status(200).json({
        success: true,
        requiresTwoFactor: true,
        email: account.email,
        purpose: 'login_2fa',
        twoFactorToken: twoFactorResult.twoFactorToken,
        expiresIn: 60,
        message: 'Two-factor verification code sent to your email.',
      });
    }

    const { token, account: sanitizedAccount } = await completeSignIn(account, {
      deviceId,
      deviceName,
      language,
    });

    return res.status(200).json({
      success: true,
      message: 'Sign in successful',
      token,
      account: sanitizedAccount,
    });
  } catch (error) {
    console.error('❌ [SIGN IN ERROR]:', error);
    return res.status(500).json({ 
      code: 'SIGN_IN_FAILED',
      message: error.message || 'Failed to sign in' 
    });
  }
};

const googleSignIn = async (req, res) => {
  try {
    let email = normalizeEmail(req.body.email);
    const idToken = req.body.idToken;
    const language = req.body.language || req.headers['accept-language'] || 'en';
    const deviceName = String(req.body.deviceName || 'Mobile Device').trim();
    const deviceId = String(req.body.deviceId || '').trim();

    if (idToken) {
      try {
        let admin;
        try {
          admin = require('firebase-admin');
        } catch (_) {}
        if (admin && admin.apps && admin.apps.length > 0) {
          const decoded = await admin.auth().verifyIdToken(idToken);
          if (decoded && decoded.email) {
            email = normalizeEmail(decoded.email);
          }
        }
      } catch (tErr) {
        console.warn('⚠️ [GOOGLE SIGN IN] Failed to verify idToken, falling back to req.body.email:', tErr.message);
      }
    }

    if (!isValidEmail(email)) {
      return res.status(400).json({ 
        code: 'INVALID_EMAIL',
        message: 'Invalid email' 
      });
    }

    const account = await findActiveAccountByEmail(email);

    if (account) {
      if (account.twoFactorEnabled) {
        const twoFactorResult = await initiateTwoFactorLogin(account, language);
        if (twoFactorResult.rateLimited) {
          return res.status(429).json({
            code: 'TOO_MANY_REQUESTS',
            message: 'Please wait before requesting another code',
            retryAfter: twoFactorResult.retryAfter,
          });
        }

        return res.status(200).json({
          success: true,
          isNewUser: false,
          requiresTwoFactor: true,
          email: account.email,
          purpose: 'login_2fa',
          twoFactorToken: twoFactorResult.twoFactorToken,
          expiresIn: 60,
          message: 'Two-factor verification code sent to your email.',
        });
      }

      const { token, account: sanitizedAccount } = await completeSignIn(account, {
        deviceId,
        deviceName,
        language,
      });

      return res.status(200).json({
        success: true,
        isNewUser: false,
        message: 'Sign in successful',
        token,
        account: sanitizedAccount,
      });
    }

    const purpose = 'signup';
    const otpResult = await issueAndSendOtp(email, purpose, language);
    if (otpResult.rateLimited) {
      return res.status(429).json({
        code: 'TOO_MANY_REQUESTS',
        message: 'Please wait before requesting another code',
        retryAfter: otpResult.retryAfter,
      });
    }

    console.log('📧 [GOOGLE SIGN IN -> NEW USER OTP SENT]:', email);

    return res.status(200).json({
      success: true,
      isNewUser: true,
      email,
      purpose,
      expiresIn: 60,
      message: 'OTP verification code has been sent to your email.',
    });
  } catch (error) {
    console.error('❌ [GOOGLE SIGN IN ERROR]:', error);
    return res.status(500).json({ 
      code: 'GOOGLE_SIGN_IN_FAILED',
      message: error.message || 'Failed to sign in with Google' 
    });
  }
};

const resetPassword = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const password = String(req.body.password || req.body.newPassword || '').trim();
    const language = req.body.language || req.headers['accept-language'] || 'en';

    if (!isValidEmail(email)) {
      return res.status(400).json({ 
        code: 'INVALID_EMAIL',
        message: 'Invalid email' 
      });
    }

    if (!password || password.length < 6) {
      return res.status(400).json({ 
        code: 'INVALID_PASSWORD',
        message: 'Password must be at least 6 characters' 
      });
    }

    const account = await findActiveAccountByEmail(email);
    if (!account) {
      return res.status(404).json({ 
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Account not found' 
      });
    }

    const verifiedOtp = await OTP.findOne({
      email,
      purpose: 'reset',
      isVerified: true,
    }).sort({ otpTime: -1 });

    if (!verifiedOtp) {
      return res.status(400).json({ 
        code: 'OTP_NOT_VERIFIED',
        message: 'Email has not been verified with OTP, please verify again!' 
      });
    }

    if (Date.now() - verifiedOtp.otpTime.getTime() > SIGNUP_FLOW_TTL_MS) {
      await OTP.deleteMany({ email, purpose: 'reset' });
      return res.status(400).json({ 
        code: 'SESSION_EXPIRED',
        message: 'Password reset session expired (exceeded 30 minutes), please try again!' 
      });
    }

    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);
    account.password = hashedPassword;
    await account.save();

    await OTP.deleteMany({ email, purpose: 'reset' });

    console.log('🔒 [RESET PASSWORD SUCCESS]:', account.email);

    changePasswordSuccessful(account.email, language).catch(err => 
      console.error('Failed to send change password email:', err)
    );

    return res.status(200).json({
      success: true,
      message: 'Password reset successfully',
    });
  } catch (error) {
    console.error('❌ [RESET PASSWORD ERROR]:', error);
    return res.status(500).json({ 
      code: 'RESET_PASSWORD_FAILED',
      message: error.message || 'Failed to reset password' 
    });
  }
};

module.exports = {
  checkEmail,
  sendOtp,
  verifyOtp,
  signUp,
  signIn,
  googleSignIn,
  resetPassword
};
