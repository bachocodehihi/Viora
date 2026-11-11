const express = require('express');
const router = express.Router();
const { uploadImages } = require('../middlewares/upload.middleware');
const { 
  getConversations,
  loadMessage,
  sendMessage,
  deleteMessage,
  recallMessage,
  pinMessage,
  unPinMessage,
  likeMessage,
  reactMessage,
  editMessage,
  stopShareLocation,
  updateLiveLocation,
  votePoll,
} = require('../controllers/message.controller');

router.get('/conversations', getConversations);
router.post('/conversations', getConversations);
router.post('/send-message', uploadImages('images', 10), sendMessage);
router.post('/load-message', loadMessage);
router.post('/delete-message', deleteMessage);
router.post('/recall-message', recallMessage);
router.post('/pin-message', pinMessage);
router.post('/unpin-message', unPinMessage);
router.post('/like-message', likeMessage);
router.post('/react-message', reactMessage);
router.post('/edit-message', editMessage);
router.post('/stop-share-location', stopShareLocation);
router.post('/update-live-location', updateLiveLocation);
router.post('/vote-poll', votePoll);

module.exports = router;
