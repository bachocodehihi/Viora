const express = require('express');
const router = express.Router();
const {
  createLive,
  getActiveLives,
  getLiveDetail,
  endLive
} = require('../controllers/livestream.controller');

router.post('/create', createLive);
router.get('/active', getActiveLives);
router.get('/:id', getLiveDetail);
router.post('/:id/end', endLive);

module.exports = router;
