const { upload } = require('../config/cloudinary');

const uploadImages = (fieldName = 'images', maxCount = 10) => {
  return (req, res, next) => {
    const contentType = req.headers['content-type'] || '';
    if (contentType.includes('multipart/form-data')) {
      upload.array(fieldName, maxCount)(req, res, (err) => {
        if (err) {
          console.warn(`[UploadMiddleware] Warning while uploading ${fieldName}:`, err.message);
        }
        return next();
      });
    } else {
      return next();
    }
  };
};

const uploadSingle = (fieldName = 'image') => {
  return (req, res, next) => {
    const contentType = req.headers['content-type'] || '';
    if (contentType.includes('multipart/form-data')) {
      upload.single(fieldName)(req, res, (err) => {
        if (err) {
          console.warn(`[UploadMiddleware] Warning while uploading ${fieldName}:`, err.message);
        }
        return next();
      });
    } else {
      return next();
    }
  };
};

module.exports = {
  upload,
  uploadImages,
  uploadArray: uploadImages,
  uploadSingle,
};

