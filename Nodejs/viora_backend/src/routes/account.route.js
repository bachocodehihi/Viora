const express = require('express');
const router = express.Router();

const { 
  loadProfile,
  updateProfile,
  togglePrivateAccount,
  updatePrivacy,
  toggleTwoFactor,
  search,
  loadSearchHistory,
  deleteSearchHistory,
  clearSearchHistory,
  reportAccount,
  blockAccount,
  unBlockAccount,
  loadBlock,
  deleteAccount,
  requestDeleteAccount,
  cancelDeleteAccount,
  getDeletionStatus,
  recordActivity,
  getActivity,
  getLikeHistory,
  getCommentHistory,
  updateNote,
  scanUserQr,
} = require('../controllers/account.controller');

router.post('/load-profile', loadProfile);
router.post('/update-profile', updateProfile);
router.post('/toggle-private', togglePrivateAccount);
router.post('/update-privacy', updatePrivacy);
router.post('/toggle-two-factor', toggleTwoFactor);
router.post('/update-note', updateNote);
router.post('/scan-qr', scanUserQr);
router.post('/search', search);
router.post('/load-search-history', loadSearchHistory);
router.post('/delete-search-history', deleteSearchHistory);
router.post('/clear-search-history', clearSearchHistory);
router.post('/report-account', reportAccount);
router.post('/block-account', blockAccount);
router.post('/unblock-account', unBlockAccount);
router.post('/load-block', loadBlock);
router.post('/like-history', getLikeHistory);
router.get('/like-history', getLikeHistory);
router.post('/comment-history', getCommentHistory);
router.get('/comment-history', getCommentHistory);
router.post('/delete-account', deleteAccount);
router.post('/request-delete-account', requestDeleteAccount);
router.post('/cancel-delete-account', cancelDeleteAccount);
router.post('/deletion-status', getDeletionStatus);
router.post('/record-activity', recordActivity);
router.post('/get-activity', getActivity);

module.exports = router;