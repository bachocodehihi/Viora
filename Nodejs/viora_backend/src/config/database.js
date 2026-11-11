const mongoose = require('mongoose');

const connectDB = async () => {
    const options = {
        serverSelectionTimeoutMS: 5000,
        dbName: 'Viora'
    };

    try {
        console.log('🔄 Đang thử kết nối MongoDB chính (Primary)...');
        await mongoose.connect(process.env.MONGODB_URI, options);
        console.log('✅ Đã kết nối MongoDB chính thành công!');
        return { isSecondary: false };
    } catch (errPrimary) {
        console.warn('⚠️ MongoDB chính gặp sự cố:', errPrimary.message);

        if (!process.env.MONGODB_URI_SECONDARY) {
            console.error('❌ Không tìm thấy biến MONGODB_URI_SECONDARY trong file .env');
            process.exit(1);
        }

        try {
            console.log('🔄 Đang chuyển hướng sang kết nối MongoDB dự phòng (Secondary)...');
            await mongoose.connect(process.env.MONGODB_URI_SECONDARY, options);
            console.log('✅ Đã kết nối MongoDB dự phòng thành công!');
            return { isSecondary: true };
        } catch (errSecondary) {
            console.error('❌ Cả 2 Database (Chính và Dự phòng) đều không thể kết nối!', errSecondary.message);
            process.exit(1);
        }
    }
};

mongoose.connection.on('disconnected', () => {
    console.warn('⚠️ Mất kết nối với MongoDB!');
});

module.exports = connectDB;

