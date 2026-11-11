const express = require('express');
const router = express.Router();
const { uploadImages } = require('../middlewares/upload.middleware');

const { 
  publishPost,
  getFeed,
  getUserPosts,
  getGroupPosts,
  getComments,
  likePost,
  commentPost,
  likeCommentPost,
  replyCommentPost,
  likeReplyCommentPost,
  deletePost,
  reportPost,
  notInterestedPost,
  toggleComments,
  updateCommentSettings,
  blockCommenter,
  unblockCommenter,
  deleteComment
} = require('../controllers/post.controller');


router.post('/publish-post', uploadImages('images', 10), publishPost);

router.get('/feed', getFeed);
router.post('/feed', getFeed);

router.get('/user-posts', getUserPosts);
router.post('/user-posts', getUserPosts);

router.get('/group-posts', getGroupPosts);
router.post('/group-posts', getGroupPosts);

router.get('/comments', getComments);
router.get('/comments/:postId', getComments);
router.post('/get-comments', getComments);

router.post('/like-post', likePost);
router.post('/comment-post', commentPost);
router.post('/like-comment-post', likeCommentPost);
router.post('/reply-comment-post', replyCommentPost);
router.post('/like-reply-comment-post', likeReplyCommentPost);
router.post('/delete-post', deletePost);
router.post('/report-post', reportPost);
router.post('/not-interested', notInterestedPost);
router.post('/toggle-comments', toggleComments);
router.post('/comment-settings', updateCommentSettings);
router.post('/block-commenter', blockCommenter);
router.post('/unblock-commenter', unblockCommenter);
router.post('/delete-comment', deleteComment);

module.exports = router;