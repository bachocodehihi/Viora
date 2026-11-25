const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

const storage = new CloudinaryStorage({
    cloudinary: cloudinary,
    params: async (req, file) => {
        const isAudio = file.mimetype?.startsWith('audio') || (file.originalname && /\.(m4a|mp3|aac|wav|ogg|opus)$/i.test(file.originalname));
        const isVideo = file.mimetype?.startsWith('video') || (file.originalname && /\.(mp4|mov|avi|mkv)$/i.test(file.originalname));
        return {
            folder: 'Viora',
            resource_type: (isAudio || isVideo) ? 'auto' : 'image',
        };
    },
});

const upload = multer({ storage: storage });

module.exports = { cloudinary, upload };
