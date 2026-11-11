const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const Account = require('../models/account.model');

let isInitialized = false;

try {
  let serviceAccount = null;

  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT.replace(/^\uFEFF/, ''));
  } else {
    const candidatePaths = [
      '/etc/secrets/firebase-service-account.json',
      path.join(__dirname, '../../firebase-service-account.json'),
      path.join(__dirname, '../firebase-service-account.json'),
    ];
    const foundPath = candidatePaths.find((p) => fs.existsSync(p));
    if (foundPath) {
      serviceAccount = JSON.parse(fs.readFileSync(foundPath, 'utf8').replace(/^\uFEFF/, ''));
    }
  }

  if (!serviceAccount) {
    throw new Error('Firebase service account not found in /etc/secrets, root, src, or FIREBASE_SERVICE_ACCOUNT');
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  }
  isInitialized = true;
  console.log('✅ Firebase Admin SDK initialized successfully!');
} catch (err) {
  console.error('⚠️ Failed to initialize Firebase Admin SDK:', err.message);
}

const sendPushNotification = async ({
  recipientId,
  title,
  body,
  data = {},
  imageUrl = null
}) => {
  if (!isInitialized || !recipientId) return false;

  try {
    const user = await Account.findById(recipientId).select('fcmToken fcmTokens').lean();
    if (!user) return false;

    const tokens = new Set();
    if (user.fcmToken && user.fcmToken.trim().length > 0) {
      tokens.add(user.fcmToken.trim());
    }
    if (Array.isArray(user.fcmTokens)) {
      user.fcmTokens.forEach(t => {
        if (t && t.trim().length > 0) tokens.add(t.trim());
      });
    }

    const tokenList = Array.from(tokens);
    if (tokenList.length === 0) {
      return false;
    }

    const stringData = {};
    for (const [k, v] of Object.entries(data)) {
      if (v !== undefined && v !== null) {
        stringData[k] = typeof v === 'object' ? JSON.stringify(v) : String(v);
      }
    }

    const messagePayload = {
      tokens: tokenList,
      notification: {
        title: title || 'Viora',
        body: body || '',
        ...(imageUrl ? { imageUrl } : {})
      },
      data: stringData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'viora_notification_channel',
          sound: 'default',
          priority: 'high',
          defaultVibrateTimings: true,
          defaultSound: true,
          ...(imageUrl ? { imageUrl } : {})
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };

    const response = await admin.messaging().sendEachForMulticast(messagePayload);

    if (response.failureCount > 0) {
      const tokensToRemove = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          if (
            errorCode === 'messaging/invalid-registration-token' ||
            errorCode === 'messaging/registration-token-not-registered'
          ) {
            tokensToRemove.push(tokenList[idx]);
          }
        }
      });

      if (tokensToRemove.length > 0) {
        await Account.findByIdAndUpdate(recipientId, {
          $pull: { fcmTokens: { $in: tokensToRemove } }
        });
      }
    }

    return true;
  } catch (error) {
    console.error('sendPushNotification error:', error.message || error);
    return false;
  }
};

const sendDataPushNotification = async ({
  recipientId,
  data = {},
  ttlSeconds = 35
}) => {
  if (!isInitialized || !recipientId) return false;

  try {
    const user = await Account.findById(recipientId).select('fcmToken fcmTokens').lean();
    if (!user) return false;

    const tokens = new Set();
    if (user.fcmToken && user.fcmToken.trim().length > 0) {
      tokens.add(user.fcmToken.trim());
    }
    if (Array.isArray(user.fcmTokens)) {
      user.fcmTokens.forEach(t => {
        if (t && t.trim().length > 0) tokens.add(t.trim());
      });
    }

    const tokenList = Array.from(tokens);
    if (tokenList.length === 0) {
      return false;
    }

    const stringData = {};
    for (const [k, v] of Object.entries(data)) {
      if (v !== undefined && v !== null) {
        stringData[k] = typeof v === 'object' ? JSON.stringify(v) : String(v);
      }
    }

    const messagePayload = {
      tokens: tokenList,
      data: stringData,
      android: {
        priority: 'high',
        ttl: Math.max(1000, Number(ttlSeconds || 35) * 1000),
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'background',
        },
        payload: {
          aps: {
            'content-available': 1,
          }
        }
      }
    };

    const response = await admin.messaging().sendEachForMulticast(messagePayload);

    if (response.failureCount > 0) {
      const tokensToRemove = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          if (
            errorCode === 'messaging/invalid-registration-token' ||
            errorCode === 'messaging/registration-token-not-registered'
          ) {
            tokensToRemove.push(tokenList[idx]);
          }
        }
      });

      if (tokensToRemove.length > 0) {
        await Account.findByIdAndUpdate(recipientId, {
          $pull: { fcmTokens: { $in: tokensToRemove } }
        });
      }
    }

    return true;
  } catch (error) {
    console.error('sendDataPushNotification error:', error.message || error);
    return false;
  }
};

module.exports = {
  sendPushNotification,
  sendDataPushNotification,
  admin
};
