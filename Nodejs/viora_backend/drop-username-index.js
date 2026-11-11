// Script để xóa unique index của username
require('dotenv').config();
const mongoose = require('mongoose');

const dropUsernameIndex = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    const db = mongoose.connection.db;
    const collection = db.collection('accounts');

    // Xóa index unique của username
    try {
      await collection.dropIndex('username_1');
      console.log('✅ Dropped username unique index successfully');
    } catch (err) {
      if (err.code === 27) {
        console.log('ℹ️  Username index does not exist (already dropped or never created)');
      } else {
        throw err;
      }
    }

    await mongoose.connection.close();
    console.log('Done!');
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
};

dropUsernameIndex();
