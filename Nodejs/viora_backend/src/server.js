require('dotenv').config({ path: __dirname + '/../.env' });
const http = require('http');
const app = require('./app');
const { initSocket } = require('./socket');
const connectDB = require('./config/database');
const { initDbSync } = require('./services/dbSync.service');
const { getJwtSecret } = require('./config/jwt.config');

getJwtSecret();

const PORT = process.env.PORT || 5000;

const server = http.createServer(app);

initSocket(server);

connectDB().then(async (dbStatus) => {
  server.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
  });

  try {
    const Account = require('./models/account.model');
    await Account.updateMany({}, { $set: { isOnline: false } });
    console.log('[PRESENCE] Reset isOnline: false for all accounts on startup');
  } catch (presenceErr) {
    console.error('[PRESENCE] Failed to reset isOnline on startup:', presenceErr);
  }

  if (!dbStatus || !dbStatus.isSecondary) {
    initDbSync();
  }

  setInterval(async () => {
    try {
      const Account = require('./models/account.model');
      const now = new Date();

      const expiredAccounts = await Account.find({
        deletionRequested: true,
        deletionScheduledAt: { $lte: now },
        isDeleted: false
      }).select('_id');

      if (expiredAccounts.length > 0) {
        const { getIO } = require('./socket');
        const ioInstance = getIO();
        for (const acc of expiredAccounts) {
          if (ioInstance) {
            ioInstance.to(acc._id.toString()).emit('account_deleted', {
              message: 'Tài khoản của bạn đã bị xóa khỏi hệ thống.'
            });
          }
        }

        await Account.updateMany(
          { _id: { $in: expiredAccounts.map(a => a._id) } },
          { $set: { isDeleted: true, deletionRequested: false, deleteAt: now } }
        );
      }

      const result = await Account.deleteMany({
        isDeleted: true,
        deleteAt: { $lte: now }
      });
      if (result.deletedCount > 0) {
        console.log(`[CLEANUP] Automatically permanently deleted ${result.deletedCount} expired accounts.`);
      }
    } catch (err) {
      console.error("[CLEANUP ERROR] Failed to clean up expired accounts:", err);
    }
  }, 10000);
}).catch(err => {
  console.error("Database connection failed:", err);
});
