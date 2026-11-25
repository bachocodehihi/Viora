const express = require('express');
const router = express.Router();
const { uploadSingle } = require('../middlewares/upload.middleware');

const {
  createStory,
  getFeed,
  getUserStories,
  viewStory,
  deleteStory,
  reactStory,
} = require('../controllers/story.controller');

router.post('/create', uploadSingle('media'), createStory);
router.get('/feed', getFeed);
router.post('/feed', getFeed);
router.get('/user/:userId', getUserStories);
router.post('/user/:userId', getUserStories);
router.post('/view/:storyId', viewStory);
router.post('/view', viewStory);
router.delete('/:storyId', deleteStory);
router.post('/delete/:storyId', deleteStory);
router.post('/delete', deleteStory);
router.post('/react', reactStory);

module.exports = router;
