const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');

const envPath = path.resolve(__dirname, '../../.env');
require('dotenv').config({ path: envPath });

function getJwtSecret() {
  let secret = process.env.JWT_SECRET;

  if (!secret || secret.trim().length < 16) {
    secret = crypto.randomBytes(32).toString('hex');
    process.env.JWT_SECRET = secret;

    try {
      if (fs.existsSync(envPath)) {
        let envContent = fs.readFileSync(envPath, 'utf8');
        if (envContent.includes('JWT_SECRET=')) {
          envContent = envContent.replace(/JWT_SECRET=.*/g, `JWT_SECRET=${secret}`);
        } else {
          envContent += `\nJWT_SECRET=${secret}\n`;
        }
        fs.writeFileSync(envPath, envContent, 'utf8');
        console.log('🔒 [AUTO-SECURITY] Generated new 256-bit JWT_SECRET and saved to .env file');
      }
    } catch (error) {
      console.warn('⚠️ [SECURITY WARNING] Could not write to .env, using generated key in memory:', error.message);
    }
  }

  return secret;
}

function getTwoFactorSecret() {
  return crypto
    .createHmac('sha256', getJwtSecret())
    .update('viora_2fa_pending_secret_v1')
    .digest('hex');
}

function generateToken(payload, expiresIn = '7d') {
  const secret = getJwtSecret();
  return jwt.sign(payload, secret, { expiresIn });
}

function verifyToken(token) {
  const secret = getJwtSecret();
  return jwt.verify(token, secret);
}

function generateTwoFactorToken(payload, expiresIn = '10m') {
  return jwt.sign({ ...payload, purpose: 'login_2fa' }, getTwoFactorSecret(), { expiresIn });
}

function verifyTwoFactorToken(token) {
  const decoded = jwt.verify(token, getTwoFactorSecret());
  if (!decoded || decoded.purpose !== 'login_2fa') {
    throw new Error('Invalid 2FA token');
  }
  return decoded;
}

module.exports = {
  getJwtSecret,
  generateToken,
  verifyToken,
  generateTwoFactorToken,
  verifyTwoFactorToken,
};
