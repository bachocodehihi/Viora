const path = require('path');
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use((req, res, next) => {

  if (req.path === '/' || req.path === '/logo.png') {
    return next();
  }

  if (mongoose.connection.readyState !== 1) {
    return res.status(503).json({
      success: false,
      code: 'DATABASE_DISCONNECTED',
      message: 'Hệ thống cơ sở dữ liệu tạm thời gián đoạn, vui lòng thử lại sau ít phút!'
    });
  }

  next();
});

const authRoute = require('./routes/auth.route');
const accountRoute = require('./routes/account.route');
const contactRoute = require('./routes/contact.route');
const postRoute = require('./routes/post.route');
const messageRoute = require('./routes/message.route');
const groupRoute = require('./routes/group.route');
const notificationRoute = require('./routes/notification.route');
const callRoute = require('./routes/call.route');
const locationRoute = require('./routes/location.route');
const livestreamRoute = require('./routes/livestream.route');

app.use('/api/auth', authRoute);
app.use('/api/account', accountRoute);
app.use('/api/contact', contactRoute);
app.use('/api/post', postRoute);
app.use('/api/message', messageRoute);
app.use('/api/group', groupRoute);
app.use('/api/notification', notificationRoute);
app.use('/api/call', callRoute);
app.use('/api/location', locationRoute);
app.use('/api/live', livestreamRoute);

app.get('/logo.png', (req, res) => {
  res.sendFile(path.join(__dirname, 'logo.png'));
});

app.get('/', (req, res) => {
  res.send('Viora api server is running');
});

app.get('/api/health', (req, res) => {
  const isConnected = mongoose.connection.readyState === 1;
  return res.status(isConnected ? 200 : 503).json({
    success: isConnected,
    code: isConnected ? 'HEALTHY' : 'DATABASE_DISCONNECTED',
    message: isConnected ? 'Hệ thống hoạt động bình thường' : 'Mất kết nối cơ sở dữ liệu',
    databaseState: isConnected ? 'CONNECTED' : 'DISCONNECTED'
  });
});

app.use((err, req, res, next) => {

  if (err.type === 'request.aborted' || err.code === 'ECONNABORTED' || req.destroyed) {
    return;
  }

  console.error('[UNHANDLED ERROR]', err);

  if (err.name === 'MongooseServerSelectionError' || err.name === 'MongoNetworkError') {
    return res.status(503).json({
      success: false,
      code: 'DATABASE_DISCONNECTED',
      message: 'Mất kết nối với cơ sở dữ liệu, vui lòng thử lại sau ít phút!'
    });
  }

  return res.status(err.status || 500).json({
    success: false,
    code: err.code || 'INTERNAL_SERVER_ERROR',
    message: err.message || 'Đã xảy ra lỗi trên máy chủ, vui lòng thử lại sau!'
  });
});

module.exports = app;