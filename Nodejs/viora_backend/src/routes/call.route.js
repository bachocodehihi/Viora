const express = require('express');
const router = express.Router();
const {
  startCall,
  acceptCall,
  joinCall,
  declineCall,
  endCall,
  missedCall,
  getCallDetail,
} = require('../controllers/call.controller');

router.post('/start', startCall);
router.post('/accept', acceptCall);
router.post('/join', joinCall);
router.post('/decline', declineCall);
router.post('/end', endCall);
router.post('/missed', missedCall);
router.get('/:callId', getCallDetail);

module.exports = router;
