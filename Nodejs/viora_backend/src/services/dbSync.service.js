const mongoose = require('mongoose');

let secondaryConnection = null;
let changeStream = null;

const initDbSync = async () => {
  const secondaryUri = process.env.MONGODB_URI_SECONDARY;

  if (!secondaryUri) {
    console.log('ℹ️ [DB SYNC] Bỏ qua đồng bộ vì không tìm thấy MONGODB_URI_SECONDARY trong .env');
    return;
  }

  if (mongoose.connection.readyState !== 1) {
    console.warn('⚠️ [DB SYNC] MongoDB chính chưa sẵn sàng, hủy kích hoạt đồng bộ.');
    return;
  }

  try {
    console.log('🔄 [DB SYNC] Đang mở kết nối ngầm tới MongoDB Secondary để sao lưu thời gian thực...');

    secondaryConnection = mongoose.createConnection(secondaryUri, {
      dbName: 'Viora',
      serverSelectionTimeoutMS: 8000
    });

    secondaryConnection.on('error', (err) => {
      console.warn('⚠️ [DB SYNC] Lỗi kết nối Secondary:', err.message);
    });

    await secondaryConnection.asPromise();
    console.log('✅ [DB SYNC] Đã kết nối thành công tới MongoDB Secondary!');

    const primaryDb = mongoose.connection.db;
    const secondaryDb = secondaryConnection.db;

    await initialSync(primaryDb, secondaryDb);

    startRealtimeSync(primaryDb, secondaryDb);

  } catch (error) {
    console.warn('⚠️ [DB SYNC] Không thể khởi tạo đồng bộ sang Secondary:', error.message);
  }
};

const initialSync = async (primaryDb, secondaryDb) => {
  try {
    const collections = await primaryDb.listCollections().toArray();

    for (const col of collections) {
      const colName = col.name;
      if (colName.startsWith('system.')) continue;

      const secondaryCount = await secondaryDb.collection(colName).countDocuments();

      if (secondaryCount === 0) {
        const primaryDocs = await primaryDb.collection(colName).find({}).toArray();
        if (primaryDocs.length > 0) {
          await secondaryDb.collection(colName).insertMany(primaryDocs);
          console.log(`📋 [DB SYNC INITIAL] Đã sao chép ban đầu ${primaryDocs.length} bản ghi của [${colName}] sang Secondary.`);
        }
      }
    }
  } catch (err) {
    console.warn('⚠️ [DB SYNC] Lỗi trong quá trình sao chép ban đầu:', err.message);
  }
};

const startRealtimeSync = (primaryDb, secondaryDb) => {
  try {
    console.log('🎧 [DB SYNC] Đang lắng nghe thay đổi thời gian thực từ Primary...');

    changeStream = primaryDb.watch([], { fullDocument: 'updateLookup' });

    changeStream.on('change', async (change) => {
      try {
        const collName = change.ns?.coll;
        if (!collName || collName.startsWith('system.')) return;

        const targetColl = secondaryDb.collection(collName);
        const docId = change.documentKey?._id;

        switch (change.operationType) {
          case 'insert':
          case 'update':
          case 'replace': {
            if (change.fullDocument) {

              await targetColl.replaceOne(
                { _id: docId },
                change.fullDocument,
                { upsert: true }
              );
              console.log(`⚡ [DB SYNC] [${change.operationType.toUpperCase()}] Đã copy sang Secondary -> Collection: ${collName} (_id: ${docId})`);
            }
            break;
          }

          case 'delete': {
            await targetColl.deleteOne({ _id: docId });
            console.log(`⚡ [DB SYNC] [DELETE] Đã xóa bản ghi ở Secondary -> Collection: ${collName} (_id: ${docId})`);
            break;
          }

          case 'drop': {
            await targetColl.drop().catch(() => {});
            console.log(`⚡ [DB SYNC] [DROP] Đã xóa toàn bộ collection [${collName}] ở Secondary`);
            break;
          }

          default:
            break;
        }
      } catch (syncErr) {
        console.error('⚠️ [DB SYNC] Lỗi khi đồng bộ sự kiện sang Secondary:', syncErr.message);
      }
    });

    changeStream.on('error', (err) => {
      console.warn('⚠️ [DB SYNC] Change Stream bị lỗi hoặc gián đoạn:', err.message);
    });

  } catch (err) {
    console.warn('⚠️ [DB SYNC] Không thể kích hoạt Change Stream:', err.message);
  }
};

module.exports = { initDbSync };
