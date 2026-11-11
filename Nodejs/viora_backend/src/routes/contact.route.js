const express = require('express');
const router = express.Router();

const { 
  getContacts,
  sendFriendRequest,
  cancelSendFriendRequest,
  acceptFriendRequest,
  rejectFriendRequest,
  acceptGroupInvite,
  rejectGroupInvite,
  removeFriend,
  followAccount,
  unfollowAccount,
  acceptFollowRequest,
  rejectFollowRequest
} = require('../controllers/contact.controller');

router.post('/get-contacts', getContacts);
router.get('/get-contacts', getContacts);
router.post('/send-friend-request', sendFriendRequest);
router.post('/cancel-send-friend-request', cancelSendFriendRequest);
router.post('/accept-friend-request', acceptFriendRequest);
router.post('/reject-friend-request', rejectFriendRequest);
router.post('/accept-group-invite', acceptGroupInvite);
router.post('/reject-group-invite', rejectGroupInvite);
router.post('/remove-friend', removeFriend);
router.post('/follow-account', followAccount);
router.post('/unfollow-account', unfollowAccount);
router.post('/accept-follow-request', acceptFollowRequest);
router.post('/reject-follow-request', rejectFollowRequest);

module.exports = router;
