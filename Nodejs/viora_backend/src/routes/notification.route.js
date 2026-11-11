const express = require('express');
const router = express.Router();
const {
  getNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  clearAllNotifications,
  updateNotificationStatus,
  updateFcmToken
} = require('../controllers/notification.controller');

router.get('/', getNotifications);
router.post('/get-notifications', getNotifications);
router.post('/mark-read', markNotificationRead);
router.post('/mark-all-read', markAllNotificationsRead);
router.post('/clear-all', clearAllNotifications);
router.post('/update-status', updateNotificationStatus);
router.post('/update-fcm-token', updateFcmToken);

module.exports = router;
