const express = require('express');
const router = express.Router();

const {
  createGroup,
  getUserGroups,
  getDiscoverGroups,
  searchGroups,
  getGroupDetail,
  joinGroup,
  requestJoinGroup,
  cancelJoinRequest,
  getJoinRequests,
  handleJoinRequest,
  inviteMembers,
  respondToInvitation,
  leaveGroup,
  deleteGroup,
  removeAccount,
  promoteAccount,
  demotedAccount,
  warningAccount,
  pinPost,
  unPinPost,
} = require('../controllers/group.controller');

router.post('/create-group', createGroup);
router.post('/my-groups', getUserGroups);
router.get('/my-groups', getUserGroups);

router.get('/discover', getDiscoverGroups);
router.post('/discover', getDiscoverGroups);

router.get('/search', searchGroups);

router.get('/:id', getGroupDetail);

router.post('/:id/join', joinGroup);

router.post('/:id/request-join', requestJoinGroup);
router.post('/:id/cancel-request', cancelJoinRequest);

router.get('/:id/join-requests', getJoinRequests);
router.post('/:id/handle-request', handleJoinRequest);

router.post('/:id/invite', inviteMembers);
router.post('/:id/respond-invite', respondToInvitation);

router.post('/:id/leave', leaveGroup);
router.post('/:id/delete', deleteGroup);
router.delete('/:id', deleteGroup);

router.post('/remove-member', removeAccount);
router.post('/promote-account', promoteAccount);
router.post('/demoted-account', demotedAccount);
router.post('/warning-account', warningAccount);
router.post('/pin-post', pinPost);
router.post('/unpin-post', unPinPost);

module.exports = router;