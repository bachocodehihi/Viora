const mongoose = require('mongoose');
const Post = require('../models/post.model');
const Comment = require('../models/comment.model');
const Like = require('../models/like.model');
const Account = require('../models/account.model');
const Group = require('../models/group.model');
const Report = require('../models/report.model');
const { createNotification } = require('./notification.controller');
const { verifyToken } = require('../config/jwt.config');
const { cloudinary } = require('../config/cloudinary');
const jwt = require('jsonwebtoken');

const getUserIdFromReq = async (req) => {

  if (req.user && (req.user.id || req.user._id || req.user.userId)) {
    return (req.user.id || req.user._id || req.user.userId).toString();
  }

  if (req.headers && req.headers.authorization) {
    try {
      const token = req.headers.authorization.replace('Bearer ', '').trim();
      let decoded = null;
      try {
        decoded = verifyToken(token);
      } catch (_) {
        decoded = jwt.decode(token);
      }
      if (decoded) {
        if (decoded.id || decoded.userId || decoded._id) {
          return (decoded.id || decoded.userId || decoded._id).toString();
        }
        if (decoded.email) {
          const acc = await Account.findOne({ email: decoded.email, isDeleted: false }).select('_id').lean();
          if (acc) return acc._id.toString();
        }
      }
    } catch (_) {}
  }

  const candidateId = (req.body && (req.body.userId || req.body.myUserId || req.body.authorId)) ||
                      (req.query && (req.query.userId || req.query.myUserId || req.query.authorId));
  if (candidateId) {
    const trimmed = candidateId.toString().trim();
    if (mongoose.Types.ObjectId.isValid(trimmed)) {
      return trimmed;
    }
    if (trimmed.includes('@')) {
      const acc = await Account.findOne({ email: trimmed, isDeleted: false }).select('_id').lean();
      if (acc) return acc._id.toString();
    }
  }

  const email = (req.body && (req.body.email || req.body.userEmail)) ||
                (req.query && (req.query.email || req.query.userEmail));
  if (email) {
    const acc = await Account.findOne({ email: email.toString().trim(), isDeleted: false }).select('_id').lean();
    if (acc) return acc._id.toString();
  }

  const username = (req.body && (req.body.username || req.body.userName)) ||
                   (req.query && (req.query.username || req.query.userName));
  if (username) {
    const acc = await Account.findOne({ username: username.toString().trim(), isDeleted: false }).select('_id').lean();
    if (acc) return acc._id.toString();
  }

  return null;
};

const publishPost = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in to create a post' });
    }

    let { content, images, videos, postType, privacy, group, allowedFriends, exceptedFriends, isAnonymous } = req.body;

    let imageUrls = [];

    if (req.files && Array.isArray(req.files) && req.files.length > 0) {
      for (const file of req.files) {
        if (file.path) {
          imageUrls.push(file.path);
        } else if (file.secure_url) {
          imageUrls.push(file.secure_url);
        }
      }
    }

    if (typeof images === 'string') {
      try {
        images = JSON.parse(images);
      } catch (_) {
        if (images.trim().startsWith('http') || images.trim().startsWith('data:image')) {
          images = [images.trim()];
        }
      }
    }

    if (Array.isArray(images) && images.length > 0) {
      for (const img of images) {
        if (typeof img === 'string') {
          if (img.startsWith('http')) {
            imageUrls.push(img);
          } else if (img.startsWith('data:image') || img.length > 100) {
            try {
              const uploadRes = await cloudinary.uploader.upload(img, {
                folder: 'Viora/posts',
                resource_type: 'image'
              });
              if (uploadRes && uploadRes.secure_url) {
                imageUrls.push(uploadRes.secure_url);
              }
            } catch (upErr) {
              console.error('Base64 image upload error:', upErr);
            }
          }
        }
      }
    }

    let normalizedPrivacy = 'public';
    if (privacy) {
      const p = privacy.toString().toLowerCase().trim();
      if (p === 'friends') normalizedPrivacy = 'friends';
      else if (p === 'friends_except' || p === 'friendsexcept') normalizedPrivacy = 'friends_except';
      else if (p === 'specific_friends' || p === 'specificfriends') normalizedPrivacy = 'specific_friends';
      else if (p === 'private' || p === 'only me' || p === 'onlyme') normalizedPrivacy = 'private';
      else normalizedPrivacy = 'public';
    }

    const parseIdList = (val) => {
      if (!val) return [];
      let list = [];
      if (typeof val === 'string') {
        try {
          const parsed = JSON.parse(val);
          if (Array.isArray(parsed)) list = parsed;
          else list = [val];
        } catch (_) {
          list = val.split(',').map(s => s.trim());
        }
      } else if (Array.isArray(val)) {
        list = val;
      }
      return list.map(item => (typeof item === 'object' && item && item._id) ? item._id.toString() : item.toString()).filter(id => mongoose.Types.ObjectId.isValid(id));
    };

    const parsedAllowed = parseIdList(allowedFriends);
    const parsedExcepted = parseIdList(exceptedFriends);

    const trimmedContent = (content || '').trim();
    if (!trimmedContent && imageUrls.length === 0) {
      return res.status(400).json({
        success: false,
        code: 'POST_CONTENT_REQUIRED',
        message: 'Post content or image is required'
      });
    }

    const isAnon = isAnonymous === true || isAnonymous === 'true';

    const post = new Post({
      author: userId,
      content: trimmedContent,
      images: imageUrls,
      videos: Array.isArray(videos) ? videos : [],
      postType: postType || (group ? 'group' : 'user'),
      privacy: normalizedPrivacy,
      allowedFriends: parsedAllowed,
      exceptedFriends: parsedExcepted,
      group: group || null,
      isAnonymous: isAnon,
      status: 'approved'
    });

    await post.save();

    const populatedPost = await Post.findById(post._id)
      .populate('author', 'username avatar email isOnline')
      .lean();

    (async () => {
      try {
        const author = await Account.findById(userId).select('username avatar friends followers').lean();
        const authorName = author?.username || 'User';
        const displayAuthorName = isAnon ? 'Anonymous Member' : authorName;

        const snippet = trimmedContent
          ? (trimmedContent.length > 50 ? trimmedContent.substring(0, 47) + '...' : trimmedContent)
          : '';
        const postNotifContent = snippet;

        if (group) {
          const targetGroup = await Group.findById(group).select('name members').lean();
          if (targetGroup && Array.isArray(targetGroup.members)) {
            for (const m of targetGroup.members) {
              const mId = m.user ? m.user.toString() : m.toString();
              if (mId !== userId.toString()) {
                await createNotification({
                  recipient: mId,
                  sender: isAnon ? null : userId,
                  group: targetGroup._id,
                  post: post._id,
                  type: 'group_post',
                  content: snippet
                });
              }
            }
          }
        } else if (normalizedPrivacy !== 'private') {
          const recipientSet = new Set();
          if (Array.isArray(author?.friends)) {
            for (const f of author.friends) {
              recipientSet.add(f.toString());
            }
          }
          if (normalizedPrivacy === 'public' && Array.isArray(author?.followers)) {
            for (const fol of author.followers) {
              recipientSet.add(fol.toString());
            }
          }

          if (normalizedPrivacy === 'friends_except') {
            for (const exc of parsedExcepted) {
              recipientSet.delete(exc.toString());
            }
          } else if (normalizedPrivacy === 'specific_friends') {
            recipientSet.clear();
            for (const allow of parsedAllowed) {
              recipientSet.add(allow.toString());
            }
          }

          recipientSet.delete(userId.toString());

          for (const friendId of recipientSet) {
            await createNotification({
              recipient: friendId,
              sender: userId,
              post: post._id,
              type: 'friend_post',
              content: postNotifContent
            });
          }
        }
      } catch (notifErr) {
        console.error('publishPost notification error:', notifErr);
      }
    })();

    return res.status(201).json({
      success: true,
      message: 'Post created successfully',
      post: populatedPost
    });
  } catch (error) {
    console.error('publishPost error:', error);
    return res.status(500).json({ success: false, code: 'CREATE_POST_FAILED', message: error.message || 'Failed to create post' });
  }
};

const getFeed = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const page = parseInt(req.query?.page || req.body?.page || 1);
    const limit = parseInt(req.query?.limit || req.body?.limit || 20);
    const skip = (page - 1) * limit;

    let query = { isDeleted: false, status: 'approved' };

    let friendIds = [];
    if (userId) {
      const currentUser = await Account.findById(userId).select('friends blockedUsers notInterestedPosts').lean();
      friendIds = (currentUser?.friends || []).map(f => f.toString());
      const blockedIds = (currentUser?.blockedUsers || []).map(b => b.toString());
      const notInterestedIds = (currentUser?.notInterestedPosts || []).map(p => p.toString());

      const lockedPrivateAccounts = await Account.find({
        isPrivate: true,
        _id: { $ne: userId },
        followers: { $ne: userId },
        friends: { $ne: userId }
      }).select('_id').lean();
      const lockedAuthorIds = lockedPrivateAccounts.map(a => a._id);

      // Find groups the user has joined
      const userGroups = await Group.find({ 'members.user': userId }).select('_id').lean();
      const myGroupIds = userGroups.map(g => g._id);

      const userPostsFilter = {
        $and: [
          {
            $or: [
              { group: null },
              { group: { $exists: false } }
            ]
          },
          {
            $or: [
              { author: userId },
              { privacy: 'public' },
              { privacy: 'friends', author: { $in: friendIds } },
              {
                privacy: 'friends_except',
                author: { $in: friendIds },
                exceptedFriends: { $nin: [userId] }
              },
              {
                privacy: 'specific_friends',
                allowedFriends: userId
              }
            ]
          }
        ]
      };

      const groupPostsFilter = (myGroupIds && myGroupIds.length > 0) ? {
        group: { $in: myGroupIds },
        status: 'approved'
      } : null;

      query.$and = [
        { author: { $nin: blockedIds } },
        ...(lockedAuthorIds.length > 0 ? [{ author: { $nin: lockedAuthorIds } }] : []),
        ...(notInterestedIds.length > 0 ? [{ _id: { $nin: notInterestedIds } }] : []),
        {
          $or: [
            userPostsFilter,
            ...(groupPostsFilter ? [groupPostsFilter] : [])
          ]
        }
      ];
    } else {
      const allPrivateAccounts = await Account.find({ isPrivate: true }).select('_id').lean();
      const privateAuthorIds = allPrivateAccounts.map(a => a._id);
      query.privacy = 'public';
      query.group = null; // No group posts for guests
      if (privateAuthorIds.length > 0) {
        query.author = { $nin: privateAuthorIds };
      }
    }

    const [posts, total] = await Promise.all([
      Post.find(query)
        .populate('author', 'username avatar email isOnline')
        .populate('group', 'name avatar')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Post.countDocuments(query)
    ]);

    let userLikesMap = new Map();
    if (userId && posts.length > 0) {
      const pIds = posts.map(p => p._id);
      const userLikes = await Like.find({
        user: userId,
        target: { $in: pIds },
        targetType: 'Post'
      }).select('target type').lean();
      userLikes.forEach(l => {
        userLikesMap.set(l.target.toString(), l.type || 'like');
      });
    }

    const formattedPosts = posts.map(p => {
      const author = p.author || {};
      const createdAt = p.createdAt ? new Date(p.createdAt) : new Date();
      const now = new Date();
      const diffSec = Math.max(0, Math.floor((now - createdAt) / 1000));
      let timeStr = 'Just now';
      if (diffSec < 60) {
        timeStr = 'Just now';
      } else if (diffSec < 3600) {
        timeStr = `${Math.floor(diffSec / 60)}m ago`;
      } else if (diffSec < 86400) {
        timeStr = `${Math.floor(diffSec / 3600)}h ago`;
      } else {
        timeStr = `${createdAt.getDate()}/${createdAt.getMonth() + 1}/${createdAt.getFullYear()}`;
      }

      const authorId = author._id ? author._id.toString() : (p.author ? p.author.toString() : '');
      const isOwner = userId ? (authorId === userId.toString()) : false;
      const isAnonymous = p.isAnonymous === true;

      const displayUsername = isAnonymous
        ? (isOwner ? 'Anonymous Member (You)' : 'Anonymous Member')
        : (author.username || author.name || 'User');
      const displayAvatar = isAnonymous ? null : (author.avatar || null);

      const groupData = p.group && typeof p.group === 'object' && p.group._id ? {
        id: p.group._id.toString(),
        _id: p.group._id.toString(),
        name: p.group.name || '',
        avatar: p.group.avatar || '',
      } : (p.group ? { id: p.group.toString(), _id: p.group.toString(), name: '', avatar: '' } : null);

      const commentsDisabled = p.commentsDisabled === true;
      const blockedCommenters = (p.blockedCommenters || []).map(b => b.toString());
      const allowedCommenters = (p.allowedCommenters || []).map(a => a.toString());
      const commentPermission = p.commentPermission || 'everyone';

      let canComment = true;
      let commentRestrictionReason = '';
      if (commentsDisabled) {
        canComment = false;
        commentRestrictionReason = 'comments_disabled';
      } else if (userId && blockedCommenters.includes(userId.toString())) {
        canComment = false;
        commentRestrictionReason = 'blocked';
      } else if (!isOwner && userId) {
        if (commentPermission === 'friends' && !friendIds.includes(authorId)) {
          canComment = false;
          commentRestrictionReason = 'friends_only';
        } else if (commentPermission === 'selected' && !allowedCommenters.includes(userId.toString())) {
          canComment = false;
          commentRestrictionReason = 'selected_only';
        }
      }

      return {
        ...p,
        id: p._id.toString(),
        userId: isAnonymous ? (isOwner ? authorId : '') : authorId,
        userEmail: isAnonymous ? '' : (author.email || ''),
        userName: displayUsername,
        avatar: displayAvatar,
        isAnonymous: isAnonymous,
        postType: p.postType || (groupData ? 'group' : 'user'),
        group: groupData,
        author: {
          _id: isAnonymous ? (isOwner ? authorId : '') : authorId,
          username: displayUsername,
          name: displayUsername,
          avatar: displayAvatar,
          email: isAnonymous ? '' : (author.email || ''),
        },
        time: p.createdAt ? new Date(p.createdAt).toISOString() : new Date().toISOString(),
        createdAt: p.createdAt,
        content: p.content || '',
        images: Array.isArray(p.images) ? p.images : [],
        videos: Array.isArray(p.videos) ? p.videos : [],
        likes: p.likesCount || 0,
        likesCount: p.likesCount || 0,
        comments: p.commentsCount || 0,
        isLiked: userLikesMap.has(p._id.toString()),
        reaction: userLikesMap.get(p._id.toString()) || null,
        privacy: p.privacy || 'public',
        isOwner,
        commentsDisabled,
        commentPermission,
        allowedCommenters,
        blockedCommenters,
        canComment,
        commentRestrictionReason
      };
    });

    return res.status(200).json({
      success: true,
      posts: formattedPosts,
      total,
      page,
      totalPages: Math.ceil(total / limit)
    });
  } catch (error) {
    console.error('getFeed error:', error);
    return res.status(500).json({ success: false, code: 'GET_FEED_FAILED', message: error.message || 'Failed to load feed' });
  }
};

const likePost = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { postId, reaction } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in to like post' });
    }

    if (!postId) {
      return res.status(400).json({ success: false, code: 'POST_ID_REQUIRED', message: 'postId is required' });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ success: false, code: 'POST_NOT_FOUND', message: 'Post not found' });
    }

    const validReactions = ['like', 'love', 'haha', 'wow', 'sad', 'angry'];
    const requestedReaction = (reaction && validReactions.includes(reaction))
      ? reaction
      : 'like';

    const existingLike = await Like.findOne({
      user: userId,
      target: post._id,
      targetType: 'Post'
    });

    let isLiked = false;
    let currentReaction = null;

    if (existingLike) {

      if (!reaction || existingLike.type === requestedReaction) {
        await Like.deleteOne({ _id: existingLike._id });
        post.likesCount = Math.max(0, (post.likesCount || 1) - 1);
        isLiked = false;
        currentReaction = null;
      } else {

        existingLike.type = requestedReaction;
        await existingLike.save();
        isLiked = true;
        currentReaction = requestedReaction;
      }
    } else {

      const newLike = new Like({
        user: userId,
        target: post._id,
        targetType: 'Post',
        type: requestedReaction
      });
      await newLike.save();
      post.likesCount = (post.likesCount || 0) + 1;
      isLiked = true;
      currentReaction = requestedReaction;

      if (post.author.toString() !== userId.toString()) {
        await createNotification({
          recipient: post.author,
          sender: userId,
          post: post._id,
          type: 'like',
          reaction: currentReaction || 'like',
          content: currentReaction || 'like'
        }).catch(err => console.warn('Create like notification error:', err));
      }
    }

    const actualLikesCount = await Like.countDocuments({
      target: post._id,
      targetType: 'Post'
    });
    post.likesCount = actualLikesCount;
    await post.save();

    try {
      const { getIO } = require('../socket');
      const io = getIO ? getIO() : null;
      if (io) {
        const payload = {
          postId: post._id.toString(),
          userId: userId.toString(),
          isLiked,
          reaction: currentReaction,
          likesCount: post.likesCount
        };
        io.emit('post_liked', payload);
      }
    } catch (sockErr) {
      console.warn('[Socket] Failed to emit post_liked:', sockErr.message);
    }

    return res.status(200).json({
      success: true,
      isLiked,
      reaction: currentReaction,
      likesCount: post.likesCount,
      postId: post._id.toString(),
      message: isLiked ? 'Post liked successfully' : 'Post unliked successfully'
    });
  } catch (error) {
    console.error('likePost error:', error);
    return res.status(500).json({ success: false, code: 'TOGGLE_LIKE_FAILED', message: error.message || 'Failed to process like action' });
  }
};

const getComments = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const postId = req.query.postId || req.params.postId || req.body.postId;

    if (!postId) {
      return res.status(400).json({ success: false, code: 'POST_ID_REQUIRED', message: 'postId is required' });
    }

    const [post, comments] = await Promise.all([
      Post.findById(postId).populate('author', 'username avatar email friends').lean(),
      Comment.find({ post: postId, isDeleted: false })
        .populate('author', 'username avatar email')
        .sort({ createdAt: -1 })
        .lean()
    ]);

    const postAuthor = post?.author || {};
    const postAuthorId = postAuthor._id ? postAuthor._id.toString() : (post?.author ? post.author.toString() : '');
    const isOwner = userId ? (postAuthorId === userId.toString()) : false;
    const commentsDisabled = post?.commentsDisabled === true;
    const blockedCommenters = (post?.blockedCommenters || []).map(b => b.toString());
    const allowedCommenters = (post?.allowedCommenters || []).map(a => a.toString());
    const commentPermission = post?.commentPermission || 'everyone';

    let canComment = true;
    let commentRestrictionReason = '';
    if (commentsDisabled) {
      canComment = false;
      commentRestrictionReason = 'comments_disabled';
    } else if (userId && blockedCommenters.includes(userId.toString())) {
      canComment = false;
      commentRestrictionReason = 'blocked';
    } else if (!isOwner && userId) {
      const authorFriends = (postAuthor.friends || []).map(f => f.toString());
      if (commentPermission === 'friends' && !authorFriends.includes(userId.toString())) {
        canComment = false;
        commentRestrictionReason = 'friends_only';
      } else if (commentPermission === 'selected' && !allowedCommenters.includes(userId.toString())) {
        canComment = false;
        commentRestrictionReason = 'selected_only';
      }
    }

    let likedCommentIds = new Set();
    if (userId && comments.length > 0) {
      const cIds = comments.map(c => c._id);
      const userLikes = await Like.find({
        user: userId,
        target: { $in: cIds },
        targetType: 'Comment'
      }).select('target').lean();
      likedCommentIds = new Set(userLikes.map(l => l.target.toString()));
    }

    const formattedComments = comments.map(c => {
      const author = c.author || {};
      const authorId = author._id ? author._id.toString() : '';
      const createdAt = c.createdAt ? new Date(c.createdAt) : new Date();
      const now = new Date();
      const diffSec = Math.max(0, Math.floor((now - createdAt) / 1000));
      let timeStr = 'Just now';
      if (diffSec < 60) {
        timeStr = 'Just now';
      } else if (diffSec < 3600) {
        timeStr = `${Math.floor(diffSec / 60)}m ago`;
      } else if (diffSec < 86400) {
        timeStr = `${Math.floor(diffSec / 3600)}h ago`;
      } else {
        timeStr = `${createdAt.getDate()}/${createdAt.getMonth() + 1}`;
      }

      const isMyComment = userId ? (authorId === userId.toString()) : false;
      const isAnonymous = c.isAnonymous === true;
      const displayUsername = isAnonymous
        ? (isMyComment ? 'Anonymous Member (You)' : 'Anonymous Member')
        : (author.username || 'User');
      const displayAvatar = isAnonymous ? null : (author.avatar || null);

      return {
        id: c._id.toString(),
        _id: c._id.toString(),
        name: displayUsername,
        userName: displayUsername,
        username: displayUsername,
        avatar: displayAvatar,
        userAvatar: displayAvatar,
        text: c.content || '',
        content: c.content || '',
        time: c.createdAt ? new Date(c.createdAt).toISOString() : new Date().toISOString(),
        likes: c.likesCount || 0,
        likesCount: c.likesCount || 0,
        isLiked: likedCommentIds.has(c._id.toString()),
        isAnonymous: isAnonymous,
        parentComment: c.parentComment ? c.parentComment.toString() : null,
        createdAt: c.createdAt,
        canDelete: isMyComment || isOwner,
        isPostAuthor: isAnonymous ? false : (postAuthorId === authorId),
        author: {
          _id: isAnonymous ? (isMyComment ? authorId : '') : authorId,
          username: displayUsername,
          avatar: displayAvatar,
          email: isAnonymous ? '' : (author.email || '')
        }
      };
    });

    const isGroupPost = !!(post?.group || post?.postType === 'group');

    return res.status(200).json({
      success: true,
      comments: formattedComments,
      total: formattedComments.length,
      commentsDisabled,
      commentPermission,
      allowedCommenters,
      blockedCommenters,
      canComment,
      commentRestrictionReason,
      isOwner,
      postAuthorId,
      isGroupPost
    });
  } catch (error) {
    console.error('getComments error:', error);
    return res.status(500).json({ success: false, code: 'GET_COMMENTS_FAILED', message: error.message || 'Failed to load comments' });
  }
};

const commentPost = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { postId, content, parentComment } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in to comment' });
    }

    if (!postId || !content || !content.trim()) {
      return res.status(400).json({ success: false, code: 'COMMENT_CONTENT_REQUIRED', message: 'Comment content cannot be empty' });
    }

    const post = await Post.findById(postId).populate('author', 'friends');
    if (!post) {
      return res.status(404).json({ success: false, code: 'POST_NOT_FOUND', message: 'Post not found' });
    }

    if (post.commentsDisabled) {
      return res.status(403).json({ success: false, code: 'COMMENTS_DISABLED', message: 'Comments are disabled for this post' });
    }

    const blockedList = (post.blockedCommenters || []).map(b => b.toString());
    if (blockedList.includes(userId.toString())) {
      return res.status(403).json({ success: false, code: 'COMMENT_NOT_ALLOWED', message: 'You are not allowed to comment on this post' });
    }

    const postAuthor = post.author || {};
    const postAuthorId = postAuthor._id ? postAuthor._id.toString() : (post.author ? post.author.toString() : '');
    const isAuthor = postAuthorId === userId.toString();

    if (!isAuthor) {
      if (post.commentPermission === 'friends') {
        const authorFriends = (postAuthor.friends || []).map(f => f.toString());
        if (!authorFriends.includes(userId.toString())) {
          return res.status(403).json({ success: false, code: 'FRIENDS_ONLY_COMMENT', message: 'Only friends of the author can comment' });
        }
      } else if (post.commentPermission === 'selected') {
        const allowed = (post.allowedCommenters || []).map(a => a.toString());
        if (!allowed.includes(userId.toString())) {
          return res.status(403).json({ success: false, code: 'ALLOWED_USERS_ONLY_COMMENT', message: 'Only users allowed by author can comment' });
        }
      }
    }

    const isAnon = req.body.isAnonymous === true || req.body.isAnonymous === 'true';

    const comment = new Comment({
      author: userId,
      post: postId,
      parentComment: parentComment || null,
      content: content.trim(),
      isAnonymous: isAnon
    });
    await comment.save();

    post.commentsCount = (post.commentsCount || 0) + 1;
    await post.save();

    const populatedComment = await Comment.findById(comment._id)
      .populate('author', 'username avatar email')
      .lean();

    if (post.author.toString() !== userId.toString()) {
      const sender = await Account.findById(userId).select('username avatar').lean();
      const commenterName = isAnon ? 'Anonymous Member' : (sender?.username || 'User');
      await createNotification({
        recipient: post.author,
        sender: isAnon ? null : userId,
        post: post._id,
        type: 'comment',
        content: `${commenterName} commented on your post: "${content.trim().substring(0, 40)}"`
      });
    }

    const authorObj = populatedComment?.author || {};
    const displayUsername = isAnon ? 'Anonymous Member' : (authorObj.username || 'User');
    const displayAvatar = isAnon ? null : (authorObj.avatar || null);
    const commentResponse = {
      id: comment._id.toString(),
      _id: comment._id.toString(),
      name: displayUsername,
      userName: displayUsername,
      username: displayUsername,
      avatar: displayAvatar,
      userAvatar: displayAvatar,
      text: comment.content,
      content: comment.content,
      time: 'Just now',
      likes: 0,
      likesCount: 0,
      isLiked: false,
      isAnonymous: isAnon,
      parentComment: comment.parentComment ? comment.parentComment.toString() : null,
      createdAt: comment.createdAt,
      author: {
        _id: isAnon ? '' : (authorObj._id ? authorObj._id.toString() : userId.toString()),
        username: displayUsername,
        avatar: displayAvatar,
        email: isAnon ? '' : (authorObj.email || '')
      }
    };

    try {
      const { getIO } = require('../socket');
      const io = getIO();
      if (io) {
        const postRoom = `post_${postId.toString().trim()}`;
        io.to(postRoom).emit('new_comment', {
          postId: postId.toString(),
          comment: commentResponse,
          commentsCount: post.commentsCount
        });

        io.emit('post_comments_count_updated', {
          postId: postId.toString(),
          commentsCount: post.commentsCount
        });
      }
    } catch (sockErr) {
      console.warn('[Socket] Failed to emit new_comment:', sockErr.message);
    }

    return res.status(201).json({
      success: true,
      message: 'Comment posted successfully',
      comment: commentResponse,
      commentsCount: post.commentsCount
    });
  } catch (error) {
    console.error('commentPost error:', error);
    return res.status(500).json({ success: false, code: 'SERVER_ERROR', message: error.message });
  }
};

const likeCommentPost = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { commentId } = req.body;

    if (!userId || !commentId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'userId and commentId are required' });
    }

    const comment = await Comment.findById(commentId);
    if (!comment) {
      return res.status(404).json({ success: false, code: 'COMMENT_NOT_FOUND', message: 'Comment not found' });
    }

    const existingLike = await Like.findOne({
      user: userId,
      target: commentId,
      targetType: 'Comment'
    });

    let isLiked = false;
    if (existingLike) {
      await Like.findByIdAndDelete(existingLike._id);
      comment.likesCount = Math.max(0, (comment.likesCount || 1) - 1);
      isLiked = false;
    } else {
      const newLike = new Like({
        user: userId,
        target: commentId,
        targetType: 'Comment',
        type: 'like'
      });
      await newLike.save();
      comment.likesCount = (comment.likesCount || 0) + 1;
      isLiked = true;

      if (comment.author.toString() !== userId.toString()) {
        await createNotification({
          recipient: comment.author,
          sender: userId,
          post: comment.post,
          comment: comment._id,
          type: 'like',
          reaction: 'like',
          content: 'like'
        }).catch(err => console.warn('Create comment like notification error:', err));
      }
    }

    await comment.save();

    try {
      const { getIO } = require('../socket');
      const io = getIO();
      if (io && comment.post) {
        const postRoom = `post_${comment.post.toString().trim()}`;
        io.to(postRoom).emit('comment_liked', {
          postId: comment.post.toString(),
          commentId: comment._id.toString(),
          likesCount: comment.likesCount,
          userId: userId.toString()
        });
      }
    } catch (sockErr) {
      console.warn('[Socket] Failed to emit comment_liked:', sockErr.message);
    }

    return res.status(200).json({
      success: true,
      isLiked,
      likesCount: comment.likesCount
    });
  } catch (error) {
    console.error('likeCommentPost error:', error);
    return res.status(500).json({ success: false, code: 'SERVER_ERROR', message: error.message });
  }
};

const replyCommentPost = async (req, res) => {
  return res.status(200).json({ success: true });
};

const likeReplyCommentPost = async (req, res) => {
  return res.status(200).json({ success: true });
};

const getUserPosts = async (req, res) => {
  try {
    const currentUserId = await getUserIdFromReq(req);
    const targetUserIdOrEmail = req.query?.userId || req.query?.targetUserId || req.query?.email || req.body?.userId || req.body?.email;

    let targetAccountId = null;
    if (targetUserIdOrEmail) {
      const cleanVal = targetUserIdOrEmail.toString().trim();
      if (mongoose.Types.ObjectId.isValid(cleanVal)) {
        targetAccountId = cleanVal;
      } else {
        const acc = await Account.findOne({ email: cleanVal, isDeleted: false }).select('_id').lean();
        if (acc) targetAccountId = acc._id.toString();
      }
    } else if (currentUserId) {
      targetAccountId = currentUserId;
    }

    if (!targetAccountId) {
      return res.status(400).json({ success: false, code: 'USER_ID_REQUIRED', message: 'User identifier is required' });
    }

    const query = { author: targetAccountId, isDeleted: false, status: 'approved' };

    const targetAcc = await Account.findById(targetAccountId).select('isPrivate followers friends').lean();
    const isPrivate = targetAcc?.isPrivate === true;

    const isOwner = currentUserId && currentUserId.toString() === targetAccountId.toString();
    if (!isOwner) {
      query.isAnonymous = { $ne: true };
      const isFollower = currentUserId && (targetAcc?.followers || []).map(f => f.toString()).includes(currentUserId.toString());
      const isFriend = currentUserId && (targetAcc?.friends || []).map(f => f.toString()).includes(currentUserId.toString());

      if (isPrivate && !isFollower && !isFriend) {
        return res.status(200).json({
          success: true,
          posts: [],
          isPrivateLocked: true,
          message: 'This account is private. Follow to see their posts.'
        });
      }

      if (isFriend) {
        query.$or = [
          { privacy: 'public' },
          { privacy: 'friends' },
          { privacy: 'friends_except', exceptedFriends: { $nin: [currentUserId] } },
          { privacy: 'specific_friends', allowedFriends: currentUserId }
        ];
      } else {
        query.$or = [
          { privacy: 'public' },
          { privacy: 'specific_friends', allowedFriends: currentUserId }
        ];
      }
    }

    const posts = await Post.find(query)
      .populate('author', 'username avatar email isOnline')
      .populate('group', 'name avatar')
      .sort({ createdAt: -1 })
      .lean();

    let userLikesMap = new Map();
    if (currentUserId && posts.length > 0) {
      const pIds = posts.map(p => p._id);
      const userLikes = await Like.find({
        user: currentUserId,
        target: { $in: pIds },
        targetType: 'Post'
      }).select('target type').lean();
      userLikes.forEach(l => {
        userLikesMap.set(l.target.toString(), l.type || 'like');
      });
    }

    const formattedPosts = posts.map(p => {
      const author = p.author || {};
      const createdAt = p.createdAt ? new Date(p.createdAt) : new Date();
      const now = new Date();
      const diffSec = Math.max(0, Math.floor((now - createdAt) / 1000));
      let timeStr = 'Just now';
      if (diffSec < 60) {
        timeStr = 'Just now';
      } else if (diffSec < 3600) {
        timeStr = `${Math.floor(diffSec / 60)}m ago`;
      } else if (diffSec < 86400) {
        timeStr = `${Math.floor(diffSec / 3600)}h ago`;
      } else {
        timeStr = `${createdAt.getDate()}/${createdAt.getMonth() + 1}/${createdAt.getFullYear()}`;
      }

      const authorId = author._id ? author._id.toString() : (p.author ? p.author.toString() : '');
      const isOwner = currentUserId ? (authorId === currentUserId.toString()) : false;
      const commentsDisabled = p.commentsDisabled === true;
      const blockedCommenters = (p.blockedCommenters || []).map(b => b.toString());
      const allowedCommenters = (p.allowedCommenters || []).map(a => a.toString());
      const commentPermission = p.commentPermission || 'everyone';

      let canComment = true;
      let commentRestrictionReason = '';
      if (commentsDisabled) {
        canComment = false;
        commentRestrictionReason = 'comments_disabled';
      } else if (currentUserId && blockedCommenters.includes(currentUserId.toString())) {
        canComment = false;
        commentRestrictionReason = 'blocked';
      }

      return {
        ...p,
        id: p._id.toString(),
        userId: authorId,
        userEmail: author.email || '',
        userName: author.username || 'User',
        avatar: author.avatar || null,
        time: p.createdAt ? new Date(p.createdAt).toISOString() : new Date().toISOString(),
        createdAt: p.createdAt,
        content: p.content || '',
        images: Array.isArray(p.images) ? p.images : [],
        videos: Array.isArray(p.videos) ? p.videos : [],
        likes: p.likesCount || 0,
        likesCount: p.likesCount || 0,
        comments: p.commentsCount || 0,
        isLiked: userLikesMap.has(p._id.toString()),
        reaction: userLikesMap.get(p._id.toString()) || null,
        privacy: p.privacy || 'public',
        isOwner,
        commentsDisabled,
        commentPermission,
        allowedCommenters,
        blockedCommenters,
        canComment,
        commentRestrictionReason
      };
    });

    return res.status(200).json({
      success: true,
      posts: formattedPosts,
      total: formattedPosts.length
    });
  } catch (error) {
    console.error('getUserPosts error:', error);
    return res.status(500).json({ success: false, code: 'GET_USER_POSTS_FAILED', message: error.message || 'Failed to load user posts' });
  }
};

const deletePost = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { postId } = req.body;
    if (!postId) {
      return res.status(400).json({ success: false, code: 'POST_ID_REQUIRED', message: 'postId is required' });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ success: false, code: 'POST_NOT_FOUND', message: 'Post not found' });
    }

    if (userId && post.author.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, code: 'FORBIDDEN', message: 'You do not have permission to delete this post' });
    }

    await Post.findByIdAndDelete(postId);
    await Comment.deleteMany({ post: postId });
    await Like.deleteMany({ post: postId });

    return res.status(200).json({ success: true, message: 'Post deleted successfully' });
  } catch (error) {
    return res.status(500).json({ success: false, code: 'SERVER_ERROR', message: error.message });
  }
};

const reportPost = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { postId, reason, details } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in to report post' });
    }
    if (!postId) {
      return res.status(400).json({ success: false, code: 'POST_ID_REQUIRED', message: 'postId is required' });
    }

    const report = new Report({
      reporter: userId,
      targetType: 'post',
      targetId: postId,
      reason: reason || 'Inappropriate content'
    });
    await report.save();

    return res.status(200).json({
      success: true,
      message: 'Thank you for your report. We will review this post shortly.'
    });
  } catch (error) {
    console.error('reportPost error:', error);
    return res.status(500).json({ success: false, code: 'REPORT_POST_FAILED', message: error.message || 'Failed to report post' });
  }
};

const notInterestedPost = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { postId } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }
    if (!postId) {
      return res.status(400).json({ success: false, code: 'POST_ID_REQUIRED', message: 'postId is required' });
    }

    await Account.findByIdAndUpdate(userId, {
      $addToSet: { notInterestedPosts: postId }
    });

    return res.status(200).json({
      success: true,
      message: 'Post hidden from your feed'
    });
  } catch (error) {
    console.error('notInterestedPost error:', error);
    return res.status(500).json({ success: false, code: 'HIDE_POST_FAILED', message: error.message || 'Failed to hide post' });
  }
};

const toggleComments = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { postId, commentsDisabled } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }
    if (!postId) {
      return res.status(400).json({ success: false, code: 'POST_ID_REQUIRED', message: 'postId is required' });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ success: false, code: 'POST_NOT_FOUND', message: 'Post not found' });
    }
    if (post.author.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, code: 'FORBIDDEN', message: 'You do not have permission to modify post settings' });
    }

    if (typeof commentsDisabled === 'boolean') {
      post.commentsDisabled = commentsDisabled;
    } else {
      post.commentsDisabled = !post.commentsDisabled;
    }
    await post.save();

    return res.status(200).json({
      success: true,
      message: post.commentsDisabled ? 'Comments disabled' : 'Comments enabled',
      commentsDisabled: post.commentsDisabled
    });
  } catch (error) {
    console.error('toggleComments error:', error);
    return res.status(500).json({ success: false, code: 'UPDATE_COMMENTS_FAILED', message: error.message || 'Failed to update comments setting' });
  }
};

const updateCommentSettings = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { postId, commentsDisabled, commentPermission, allowedCommenters, blockedCommenters } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }
    if (!postId) {
      return res.status(400).json({ success: false, code: 'POST_ID_REQUIRED', message: 'postId is required' });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ success: false, code: 'POST_NOT_FOUND', message: 'Post not found' });
    }
    if (post.author.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, code: 'FORBIDDEN', message: 'You are not the post author' });
    }

    if (typeof commentsDisabled === 'boolean') {
      post.commentsDisabled = commentsDisabled;
    }
    if (['everyone', 'friends', 'selected'].includes(commentPermission)) {
      post.commentPermission = commentPermission;
    }
    if (Array.isArray(allowedCommenters)) {
      post.allowedCommenters = allowedCommenters;
    }
    if (Array.isArray(blockedCommenters)) {
      post.blockedCommenters = blockedCommenters;
    }

    await post.save();

    return res.status(200).json({
      success: true,
      message: 'Comment settings updated successfully',
      post: {
        commentsDisabled: post.commentsDisabled,
        commentPermission: post.commentPermission,
        allowedCommenters: post.allowedCommenters,
        blockedCommenters: post.blockedCommenters
      }
    });
  } catch (error) {
    console.error('updateCommentSettings error:', error);
    return res.status(500).json({ success: false, code: 'UPDATE_COMMENT_SETTINGS_FAILED', message: error.message || 'Failed to update comment settings' });
  }
};

const blockCommenter = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { postId, targetUserId } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }
    if (!postId || !targetUserId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'postId and targetUserId are required' });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ success: false, code: 'POST_NOT_FOUND', message: 'Post not found' });
    }
    if (post.author.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, code: 'FORBIDDEN', message: 'You are not the post author' });
    }

    if (!post.blockedCommenters) {
      post.blockedCommenters = [];
    }
    if (!post.blockedCommenters.some(id => id.toString() === targetUserId.toString())) {
      post.blockedCommenters.push(targetUserId);
      await post.save();
    }

    return res.status(200).json({
      success: true,
      message: 'User blocked from commenting on this post',
      blockedCommenters: post.blockedCommenters
    });
  } catch (error) {
    console.error('blockCommenter error:', error);
    return res.status(500).json({ success: false, code: 'BLOCK_COMMENT_FAILED', message: error.message || 'Failed to block comment user' });
  }
};

const unblockCommenter = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { postId, targetUserId } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }
    if (!postId || !targetUserId) {
      return res.status(400).json({ success: false, code: 'REQUIRED_FIELDS_MISSING', message: 'postId and targetUserId are required' });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ success: false, code: 'POST_NOT_FOUND', message: 'Post not found' });
    }
    if (post.author.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, code: 'FORBIDDEN', message: 'You are not the post author' });
    }

    post.blockedCommenters = (post.blockedCommenters || []).filter(
      id => id.toString() !== targetUserId.toString()
    );
    await post.save();

    return res.status(200).json({
      success: true,
      message: 'User unblocked from commenting on this post',
      blockedCommenters: post.blockedCommenters
    });
  } catch (error) {
    console.error('unblockCommenter error:', error);
    return res.status(500).json({ success: false, code: 'UNBLOCK_COMMENT_FAILED', message: error.message || 'Failed to unblock comment user' });
  }
};

const deleteComment = async (req, res) => {
  try {
    const userId = await getUserIdFromReq(req);
    const { commentId } = req.body;

    if (!userId) {
      return res.status(401).json({ success: false, code: 'UNAUTHORIZED', message: 'Please sign in' });
    }
    if (!commentId) {
      return res.status(400).json({ success: false, code: 'COMMENT_ID_REQUIRED', message: 'commentId is required' });
    }

    const comment = await Comment.findById(commentId);
    if (!comment) {
      return res.status(404).json({ success: false, code: 'COMMENT_NOT_FOUND', message: 'Comment not found' });
    }

    const post = await Post.findById(comment.post);
    const isCommentAuthor = comment.author.toString() === userId.toString();
    const isPostAuthor = post && post.author.toString() === userId.toString();

    if (!isCommentAuthor && !isPostAuthor) {
      return res.status(403).json({ success: false, code: 'FORBIDDEN', message: 'You do not have permission to delete this comment' });
    }

    const repliesCount = await Comment.countDocuments({ parentComment: commentId });
    await Comment.deleteMany({ $or: [{ _id: commentId }, { parentComment: commentId }] });

    const totalDeleted = 1 + repliesCount;
    if (post) {
      post.commentsCount = Math.max(0, (post.commentsCount || 0) - totalDeleted);
      await post.save();
    }

    return res.status(200).json({
      success: true,
      message: 'Comment deleted successfully',
      commentId,
      deletedCount: totalDeleted,
      newCommentsCount: post ? post.commentsCount : 0
    });
  } catch (error) {
    console.error('deleteComment error:', error);
    return res.status(500).json({ success: false, code: 'DELETE_COMMENT_FAILED', message: error.message || 'Failed to delete comment' });
  }
};

const getGroupPosts = async (req, res) => {
  try {
    const currentUserId = await getUserIdFromReq(req);
    const groupId = req.query?.groupId || req.params?.groupId || req.body?.groupId;

    if (!groupId) {
      return res.status(400).json({ success: false, code: 'GROUP_ID_REQUIRED', message: 'groupId is required' });
    }

    const posts = await Post.find({
      group: groupId,
      isDeleted: false,
      status: 'approved'
    })
      .populate('author', 'username avatar email isOnline')
      .populate('group', 'name avatar')
      .sort({ createdAt: -1 })
      .lean();

    let userLikesMap = new Map();
    if (currentUserId && posts.length > 0) {
      const pIds = posts.map(p => p._id);
      const userLikes = await Like.find({
        user: currentUserId,
        target: { $in: pIds },
        targetType: 'Post'
      }).select('target type').lean();
      userLikes.forEach(l => {
        userLikesMap.set(l.target.toString(), l.type || 'like');
      });
    }

    const formattedPosts = posts.map(p => {
      const author = p.author || {};
      const authorId = author._id ? author._id.toString() : (p.author ? p.author.toString() : '');
      const isOwner = currentUserId ? (authorId === currentUserId.toString()) : false;
      const isAnonymous = p.isAnonymous === true;

      const createdAt = p.createdAt ? new Date(p.createdAt) : new Date();
      const now = new Date();
      const diffSec = Math.max(0, Math.floor((now - createdAt) / 1000));
      let timeStr = 'Just now';
      if (diffSec < 60) {
        timeStr = 'Just now';
      } else if (diffSec < 3600) {
        timeStr = `${Math.floor(diffSec / 60)}m ago`;
      } else if (diffSec < 86400) {
        timeStr = `${Math.floor(diffSec / 3600)}h ago`;
      } else {
        timeStr = `${createdAt.getDate()}/${createdAt.getMonth() + 1}/${createdAt.getFullYear()}`;
      }

      const displayUsername = isAnonymous
        ? (isOwner ? 'Anonymous Member (You)' : 'Anonymous Member')
        : (author.username || 'User');
      const displayAvatar = isAnonymous ? null : (author.avatar || null);

      return {
        ...p,
        id: p._id.toString(),
        userId: isAnonymous ? (isOwner ? authorId : '') : authorId,
        userEmail: isAnonymous ? '' : (author.email || ''),
        userName: displayUsername,
        avatar: displayAvatar,
        isAnonymous: isAnonymous,
        time: p.createdAt ? new Date(p.createdAt).toISOString() : new Date().toISOString(),
        createdAt: p.createdAt,
        content: p.content || '',
        images: Array.isArray(p.images) ? p.images : [],
        videos: Array.isArray(p.videos) ? p.videos : [],
        likes: p.likesCount || 0,
        likesCount: p.likesCount || 0,
        comments: p.commentsCount || 0,
        isLiked: userLikesMap.has(p._id.toString()),
        reaction: userLikesMap.get(p._id.toString()) || null,
        privacy: p.privacy || 'public',
        isOwner,
        canComment: true
      };
    });

    return res.status(200).json({
      success: true,
      posts: formattedPosts,
      total: formattedPosts.length
    });
  } catch (error) {
    console.error('getGroupPosts error:', error);
    return res.status(500).json({ success: false, code: 'GET_GROUP_POSTS_FAILED', message: error.message || 'Failed to load group posts' });
  }
};

module.exports = { 
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
};