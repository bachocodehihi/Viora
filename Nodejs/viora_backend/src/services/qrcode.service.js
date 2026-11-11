const QRCode = require('qrcode');
const { cloudinary } = require('../config/cloudinary');

const generateUserQRCode = async (userId, username) => {
  try {
    const qrData = JSON.stringify({
      type: 'user_profile',
      userId: userId,
      username: username,
      timestamp: Date.now()
    });

    const qrCodeBuffer = await QRCode.toBuffer(qrData, {
      errorCorrectionLevel: 'H',
      type: 'png',
      quality: 0.95,
      margin: 1,
      color: {
        dark: '#000000',
        light: '#FFFFFF'
      },
      width: 512
    });

    return new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        {
          folder: 'viora_qrcodes',
          public_id: `qr_${userId}`,
          overwrite: true,
          resource_type: 'image'
        },
        (error, result) => {
          if (error) {
            reject(error);
          } else {
            resolve(result.secure_url);
          }
        }
      );

      uploadStream.end(qrCodeBuffer);
    });
  } catch (error) {
    console.error('Error generating QR code:', error);
    throw error;
  }
};

const regenerateUserQRCode = async (userId, username) => {
  return generateUserQRCode(userId, username);
};

const generateGroupQRCode = async (groupId, groupName) => {
  try {
    const qrData = JSON.stringify({
      type: 'group',
      groupId: groupId.toString(),
      name: groupName,
      timestamp: Date.now()
    });

    const qrCodeBuffer = await QRCode.toBuffer(qrData, {
      errorCorrectionLevel: 'H',
      type: 'png',
      quality: 0.95,
      margin: 1,
      color: {
        dark: '#000000',
        light: '#FFFFFF'
      },
      width: 512
    });

    try {
      const cloudinaryUrl = await new Promise((resolve, reject) => {
        const uploadStream = cloudinary.uploader.upload_stream(
          {
            folder: 'viora_group_qrcodes',
            public_id: `qr_group_${groupId}`,
            overwrite: true,
            resource_type: 'image'
          },
          (error, result) => {
            if (error) {
              reject(error);
            } else {
              resolve(result.secure_url);
            }
          }
        );

        uploadStream.end(qrCodeBuffer);
      });
      return cloudinaryUrl;
    } catch (cloudErr) {
      console.warn('Cloudinary upload failed for group QR, fallback to data URL:', cloudErr.message);
      return await QRCode.toDataURL(qrData);
    }
  } catch (error) {
    console.error('Error generating group QR code:', error);
    try {
      return await QRCode.toDataURL(JSON.stringify({ type: 'group', groupId: groupId.toString(), name: groupName }));
    } catch (_) {
      return '';
    }
  }
};

module.exports = {
  generateUserQRCode,
  regenerateUserQRCode,
  generateGroupQRCode,
};
