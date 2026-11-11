const { Server } = require('socket.io');

let io;
const activeUserSockets = new Map(); // userId (string) -> Set<socketId>
const hiddenActiveStatusUsers = new Set(); // userId (string) who disabled active status visibility

const liveViewersMap = new Map(); // liveId -> Map<socketId, { socketId, userId, userName, userAvatar }>
const liveBlockedCommentsMap = new Map(); // liveId -> Set<userId>

const getLiveUniqueViewers = (liveId, hostId) => {
  const viewersMap = liveViewersMap.get(liveId);
  if (!viewersMap) return [];
  const blockedSet = liveBlockedCommentsMap.get(liveId) || new Set();
  const unique = [];
  const seen = new Set();
  for (const v of viewersMap.values()) {
    if (!v.userId) continue;
    const uIdStr = v.userId.toString();
    if (hostId && uIdStr === hostId.toString()) continue; // Không đưa chủ phòng vào danh sách người xem
    if (!seen.has(uIdStr)) {
      seen.add(uIdStr);
      unique.push({
        userId: uIdStr,
        userName: v.userName || 'Người xem',
        userAvatar: v.userAvatar || null,
        isCommentBlocked: blockedSet.has(uIdStr)
      });
    }
  }
  return unique;
};

const hasActiveSocket = (userId) => {
  if (!userId) return false;
  const uid = userId.toString().trim();
  const sockets = activeUserSockets.get(uid);
  return !!(sockets && sockets.size > 0);
};

const isActiveStatusVisible = (userId) => {
  if (!userId) return false;
  return !hiddenActiveStatusUsers.has(userId.toString().trim());
};

const setActiveStatusPreference = (userId, showActiveStatus) => {
  if (!userId) return;
  const uid = userId.toString().trim();
  if (showActiveStatus === false) {
    hiddenActiveStatusUsers.add(uid);
  } else {
    hiddenActiveStatusUsers.delete(uid);
  }
};

const isUserOnline = (userId) => {
  if (!userId) return false;
  const uid = userId.toString().trim();
  if (hiddenActiveStatusUsers.has(uid)) return false;
  return hasActiveSocket(uid);
};

const initSocket = (server) => {
  io = new Server(server, {
    cors: { origin: '*' },
    transports: ['websocket', 'polling'],
  });

  io.on('connection', (socket) => {
    socket.on('join_user', async (data) => {
      let uId = '';
      let devId = '';
      let devName = '';

      if (data && typeof data === 'object') {
        uId = data.userId ? data.userId.toString().trim() : '';
        devId = data.deviceId ? data.deviceId.toString().trim() : '';
        devName = data.deviceName ? data.deviceName.toString().trim() : '';
        socket.deviceId = devId;
        socket.deviceName = devName;
      } else if (data) {
        uId = data.toString().trim();
      }

      if (uId) {
        // If this socket was already associated with a different user (e.g. account switch on same device)
        if (socket.userId && socket.userId !== uId) {
          const oldUid = socket.userId;
          const oldSockets = activeUserSockets.get(oldUid);
          if (oldSockets) {
            oldSockets.delete(socket.id);
            if (oldSockets.size === 0) {
              activeUserSockets.delete(oldUid);
              let oldShowActive = isActiveStatusVisible(oldUid);
              try {
                const Account = require('./models/account.model');
                const oldAcc = await Account.findById(oldUid).select('privacy').lean();
                oldShowActive = oldAcc?.privacy?.showActiveStatus !== false;
                setActiveStatusPreference(oldUid, oldShowActive);
                const updateDoc = oldShowActive
                  ? { isOnline: false, lastSeen: new Date() }
                  : { isOnline: false };
                await Account.findByIdAndUpdate(oldUid, updateDoc);
              } catch (_) {}
              if (oldShowActive) {
                io.emit('user_offline', { userId: oldUid });
              }
            }
          }
          socket.leave(oldUid);
        }

        socket.userId = uId;
        socket.join(uId);

        if (!activeUserSockets.has(uId)) {
          activeUserSockets.set(uId, new Set());
        }
        activeUserSockets.get(uId).add(socket.id);

        try {
          const Conversation = require('./models/conversation.model');
          const userConvs = await Conversation.find({ 'members.user': uId }).select('_id').lean();
          for (const c of userConvs) {
            socket.join(c._id.toString());
          }
          const Group = require('./models/group.model');
          const userGroups = await Group.find({ $or: [{ 'members.user': uId }, { owner: uId }] }).select('chatConversation').lean();
          for (const g of userGroups) {
            if (g.chatConversation) socket.join(g.chatConversation.toString());
          }
        } catch (_) {}

        try {
          const Account = require('./models/account.model');
          const acc = await Account.findById(uId).select('currentDeviceId currentDeviceName isDeleted deletionRequested deletionScheduledAt privacy');
          
          if (!acc || acc.isDeleted) {
            socket.emit('account_deleted', { message: 'Tài khoản này đã bị xóa hoặc không còn tồn tại trên hệ thống.' });
            return;
          }

          if (acc.deletionRequested && acc.deletionScheduledAt && new Date() >= new Date(acc.deletionScheduledAt)) {
            acc.isDeleted = true;
            acc.deletionRequested = false;
            acc.deleteAt = new Date();
            await acc.save();
            socket.emit('account_deleted', { message: 'Tài khoản này đã bị xóa hoàn toàn khỏi hệ thống.' });
            return;
          }

          const showActiveStatus = acc.privacy?.showActiveStatus !== false;
          setActiveStatusPreference(uId, showActiveStatus);
          if (showActiveStatus) {
            await Account.findByIdAndUpdate(uId, { isOnline: true, lastSeen: new Date() });
            io.emit('user_online', { userId: uId });
          } else {
            await Account.findByIdAndUpdate(uId, { isOnline: false });
          }

          if (devId && acc.currentDeviceId && acc.currentDeviceId !== devId) {
            socket.emit('account_conflict', {
              deviceId: acc.currentDeviceId,
              deviceName: acc.currentDeviceName || 'Thiết bị khác',
            });
          }
        } catch (err) {
          console.error('[Socket] Check account status error:', err);
        }
      }
    });

    socket.on('leave_user', async (userId) => {
      const uId = (userId || socket.userId)?.toString().trim();
      if (!uId) return;

      const userSockets = activeUserSockets.get(uId);
      if (userSockets) {
        userSockets.delete(socket.id);
        if (userSockets.size === 0) {
          activeUserSockets.delete(uId);
          let showActive = isActiveStatusVisible(uId);
          try {
            const Account = require('./models/account.model');
            const acc = await Account.findById(uId).select('privacy').lean();
            showActive = acc?.privacy?.showActiveStatus !== false;
            setActiveStatusPreference(uId, showActive);
            const updateDoc = showActive
              ? { isOnline: false, lastSeen: new Date() }
              : { isOnline: false };
            await Account.findByIdAndUpdate(uId, updateDoc);
          } catch (_) {}
          if (showActive) {
            io.emit('user_offline', { userId: uId });
          }
        }
      }
      socket.leave(uId);
      if (socket.userId === uId) {
        delete socket.userId;
      }
    });

    socket.on('join_conversation', (conversationId) => {
      if (conversationId) {
        socket.join(conversationId.toString().trim());
      }
    });

    socket.on('leave_conversation', (conversationId) => {
      // Keep conversation room membership active so messages_screen receives instant push
    });

    socket.on('join_post', (postId) => {
      if (postId) {
        const room = `post_${postId.toString().trim()}`;
        socket.join(room);
        console.log(`[Socket] Socket ${socket.id} joined room ${room}`);
      }
    });

    socket.on('leave_post', (postId) => {
      if (postId) {
        const room = `post_${postId.toString().trim()}`;
        socket.leave(room);
        console.log(`[Socket] Socket ${socket.id} left room ${room}`);
      }
    });

    socket.on('mark_read', async (data) => {
      try {
        if (data && data.conversationId && data.userId) {
          const convId = data.conversationId.toString();
          const uId = data.userId.toString();
          const Message = require('./models/message.model');
          const Account = require('./models/account.model');

          await Message.updateMany(
            {
              conversationId: convId,
              sender: { $ne: uId },
              readBy: { $ne: uId },
            },
            {
              $addToSet: { readBy: uId }
            }
          );
          const userAccount = await Account.findById(uId).select('username avatar');
          io.to(convId).emit('messages_read', {
            conversationId: convId,
            readerId: uId,
            readerName: userAccount?.username || '',
            readerAvatar: userAccount?.avatar || '',
          });
          io.to(uId).emit('conversation_updated', {
            conversationId: convId,
            unread: 0,
          });
        }
      } catch (err) {
        console.error('Socket mark_read error:', err);
      }
    });

    socket.on('typing_start', (data) => {
      if (data && data.conversationId) {
        socket.to(data.conversationId.toString()).emit('user_typing', {
          conversationId: data.conversationId,
          userId: data.userId,
          userName: data.userName,
          isTyping: true,
        });
      }
    });

    socket.on('typing_stop', (data) => {
      if (data && data.conversationId) {
        socket.to(data.conversationId.toString()).emit('user_typing', {
          conversationId: data.conversationId,
          userId: data.userId,
          isTyping: false,
        });
      }
    });

    socket.on('stop_share_location', (data) => {
      try {
        if (!data || !data.conversationId) return;
        const convId = data.conversationId.toString().trim();
        const uId = (socket.userId || data.userId || '').toString();
        io.to(convId).emit('location_stopped', {
          conversationId: convId,
          messageId: data.messageId ? data.messageId.toString() : '',
          userId: uId,
          location: { isLive: false, status: 'stopped' },
        });
      } catch (err) {
        console.error('Socket stop_share_location error:', err);
      }
    });

    socket.on('update_note', async (data) => {
      try {
        const uId = data?.userId?.toString() || socket.userId;
        if (uId) {
          const cleanNote = (data?.note || '').toString().trim();
          const expiresAt = cleanNote ? new Date(Date.now() + 24 * 60 * 60 * 1000) : null;
          const Account = require('./models/account.model');
          const account = await Account.findByIdAndUpdate(
            uId,
            { note: cleanNote, noteExpiresAt: expiresAt },
            { new: true }
          ).select('friends note username avatar');

          if (account) {
            const payload = {
              userId: uId,
              username: account.username,
              avatar: account.avatar,
              note: account.note,
            };
            io.to(uId).emit('user_note_updated', payload);
            (account.friends || []).forEach(fId => {
              const friendIdStr = (fId._id || fId).toString();
              io.to(friendIdStr).emit('user_note_updated', payload);
            });
          }
        }
      } catch (err) {
        console.error('Socket update_note error:', err);
      }
    });

    socket.on('react_message', async (data) => {
      try {
        if (!data || !data.messageId) return;
        const uId = data.userId || socket.userId;
        if (!uId) return;
        const Message = require('./models/message.model');
        const message = await Message.findById(data.messageId);
        if (!message) return;

        if (!Array.isArray(message.reactions)) {
          message.reactions = [];
        }

        const cleanReaction = typeof data.reaction === 'string' ? data.reaction.trim() : '';
        const existingIndex = message.reactions.findIndex(
          (r) => r.user && (r.user._id ? r.user._id.toString() : r.user.toString()) === uId.toString()
        );

        let finalReaction = null;
        if (existingIndex !== -1) {
          if (!cleanReaction || message.reactions[existingIndex].reaction === cleanReaction) {
            message.reactions.splice(existingIndex, 1);
            finalReaction = null;
          } else {
            message.reactions[existingIndex].reaction = cleanReaction;
            message.reactions[existingIndex].createdAt = new Date();
            finalReaction = cleanReaction;
          }
        } else if (cleanReaction) {
          message.reactions.push({
            user: uId,
            reaction: cleanReaction,
            createdAt: new Date(),
          });
          finalReaction = cleanReaction;
        }

        await message.save();
        await message.populate('reactions.user', 'username avatar');

        const formattedReactions = (message.reactions || []).map((r) => ({
          userId: r.user?._id ? r.user._id.toString() : (r.user ? r.user.toString() : ''),
          userName: r.user?.username || '',
          userAvatar: r.user?.avatar || '',
          reaction: r.reaction,
          createdAt: r.createdAt,
        }));

        const lastReactionObj = formattedReactions.length > 0 ? formattedReactions[formattedReactions.length - 1] : null;
        const displayReaction = finalReaction || (lastReactionObj ? lastReactionObj.reaction : null);

        const payload = {
          messageId: message._id.toString(),
          conversationId: message.conversationId ? message.conversationId.toString() : null,
          userId: uId.toString(),
          reaction: finalReaction,
          displayReaction,
          reactions: formattedReactions,
        };

        if (message.conversationId) {
          io.to(message.conversationId.toString()).emit('message_reaction_updated', payload);
        }
      } catch (err) {
        console.error('Socket react_message error:', err);
      }
    });

    socket.on('like_post', async (data) => {
      try {
        if (!data || !data.postId) return;
        const uId = data.userId || socket.userId;
        if (!uId) return;

        const postId = data.postId.toString().trim();
        const reaction = data.reaction || 'like';

        const Post = require('./models/post.model');
        const Like = require('./models/like.model');
        const Account = require('./models/account.model');
        const { createNotification } = require('./controllers/notification.controller');

        const post = await Post.findById(postId);
        if (!post) return;

        const validReactions = ['like', 'love', 'haha', 'wow', 'sad', 'angry'];
        const requestedReaction = validReactions.includes(reaction) ? reaction : 'like';

        const existingLike = await Like.findOne({
          user: uId,
          target: post._id,
          targetType: 'Post'
        });

        let isLiked = false;
        let currentReaction = null;

        if (existingLike) {
          if (!data.reaction || existingLike.type === requestedReaction) {
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
            user: uId,
            target: post._id,
            targetType: 'Post',
            type: requestedReaction
          });
          await newLike.save();
          post.likesCount = (post.likesCount || 0) + 1;
          isLiked = true;
          currentReaction = requestedReaction;

          if (post.author.toString() !== uId.toString()) {
            createNotification({
              recipient: post.author,
              sender: uId,
              post: post._id,
              type: 'like',
              reaction: currentReaction || 'like',
              content: currentReaction || 'like'
            }).catch(() => {});
          }
        }

        const actualLikesCount = await Like.countDocuments({
          target: post._id,
          targetType: 'Post'
        });
        post.likesCount = actualLikesCount;
        await post.save();

        const payload = {
          postId: post._id.toString(),
          userId: uId.toString(),
          isLiked,
          reaction: currentReaction,
          likesCount: post.likesCount
        };

        io.emit('post_liked', payload);
      } catch (err) {
        console.error('Socket like_post error:', err);
      }
    });

    socket.on('join_live', async (data) => {
      try {
        if (!data || !data.liveId) return;
        const liveId = data.liveId.toString().trim();
        const uIdStr = data.userId ? data.userId.toString().trim() : (socket.userId ? socket.userId.toString().trim() : '');

        const room = `live_${liveId}`;
        socket.join(room);
        socket.liveId = liveId;
        socket.liveUserId = uIdStr;

        if (!liveViewersMap.has(liveId)) {
          liveViewersMap.set(liveId, new Map());
        }

        liveViewersMap.get(liveId).set(socket.id, {
          socketId: socket.id,
          userId: uIdStr,
          userName: data.userName || 'Người xem',
          userAvatar: data.userAvatar || null
        });

        const LiveStream = require('./models/livestream.model');
        const live = await LiveStream.findById(liveId);
        if (live && live.status === 'live') {
          const hostId = live.host?.toString();
          const uniqueViewers = getLiveUniqueViewers(liveId, hostId);
          live.viewersCount = uniqueViewers.length;
          if (live.viewersCount > (live.maxViewers || 0)) {
            live.maxViewers = live.viewersCount;
          }
          await live.save();

          io.to(room).emit('live_viewers_updated', {
            liveId,
            viewersCount: live.viewersCount,
            viewers: uniqueViewers,
            user: {
              userId: uIdStr,
              userName: data.userName,
              userAvatar: data.userAvatar
            }
          });

          // Gửi trạng thái chặn bình luận nếu người này đã bị chặn từ trước
          if (uIdStr && liveBlockedCommentsMap.get(liveId)?.has(uIdStr)) {
            socket.emit('live_comment_blocked', {
              liveId,
              userId: uIdStr,
              isBlocked: true,
              message: 'Bạn đã bị chủ phòng chặn bình luận.'
            });
          }
        }
      } catch (err) {
        console.error('Socket join_live error:', err);
      }
    });

    socket.on('leave_live', async (data) => {
      try {
        if (!data || !data.liveId) return;
        const liveId = data.liveId.toString().trim();
        const room = `live_${liveId}`;
        socket.leave(room);
        socket.liveId = null;

        const vMap = liveViewersMap.get(liveId);
        if (vMap) {
          vMap.delete(socket.id);
        }

        const LiveStream = require('./models/livestream.model');
        const live = await LiveStream.findById(liveId);
        if (live && live.status === 'live') {
          const hostId = live.host?.toString();
          const uniqueViewers = getLiveUniqueViewers(liveId, hostId);
          live.viewersCount = uniqueViewers.length;
          await live.save();

          io.to(room).emit('live_viewers_updated', {
            liveId,
            viewersCount: live.viewersCount,
            viewers: uniqueViewers
          });
        }
      } catch (err) {
        console.error('Socket leave_live error:', err);
      }
    });

    socket.on('get_live_viewers', async (data) => {
      try {
        if (!data || !data.liveId) return;
        const liveId = data.liveId.toString().trim();
        const LiveStream = require('./models/livestream.model');
        const live = await LiveStream.findById(liveId).lean();
        const hostId = live?.host?.toString();
        const uniqueViewers = getLiveUniqueViewers(liveId, hostId);

        socket.emit('live_viewers_list', {
          liveId,
          viewersCount: uniqueViewers.length,
          viewers: uniqueViewers
        });
      } catch (err) {
        console.error('Socket get_live_viewers error:', err);
      }
    });

    socket.on('block_live_comment', async (data) => {
      try {
        if (!data || !data.liveId || !data.userId) return;
        const liveId = data.liveId.toString().trim();
        const targetUserId = data.userId.toString().trim();
        const isBlocked = (data.isBlocked === true || data.isBlocked === 'true');
        const room = `live_${liveId}`;

        if (!liveBlockedCommentsMap.has(liveId)) {
          liveBlockedCommentsMap.set(liveId, new Set());
        }

        if (isBlocked) {
          liveBlockedCommentsMap.get(liveId).add(targetUserId);
        } else {
          liveBlockedCommentsMap.get(liveId).delete(targetUserId);
        }

        // Báo cho các socket của người dùng bị chặn
        const vMap = liveViewersMap.get(liveId);
        if (vMap) {
          for (const [sId, v] of vMap.entries()) {
            if (v.userId && v.userId.toString() === targetUserId) {
              io.to(sId).emit('live_comment_blocked', {
                liveId,
                userId: targetUserId,
                isBlocked,
                message: isBlocked ? 'Bạn đã bị chủ phòng chặn bình luận.' : 'Bạn đã được chủ phòng mở lại bình luận.'
              });
            }
          }
        }

        // Cập nhật lại danh sách người xem cho chủ phòng
        const LiveStream = require('./models/livestream.model');
        const live = await LiveStream.findById(liveId).lean();
        const hostId = live?.host?.toString();
        const uniqueViewers = getLiveUniqueViewers(liveId, hostId);

        io.to(room).emit('live_viewers_updated', {
          liveId,
          viewersCount: uniqueViewers.length,
          viewers: uniqueViewers
        });
      } catch (err) {
        console.error('Socket block_live_comment error:', err);
      }
    });

    socket.on('kick_live_viewer', async (data) => {
      try {
        if (!data || !data.liveId || !data.userId) return;
        const liveId = data.liveId.toString().trim();
        const targetUserId = data.userId.toString().trim();
        const room = `live_${liveId}`;

        // Báo cho người bị đuổi và kick socket khỏi room lúc này (người xem vẫn có thể vào lại được nếu muốn)
        const vMap = liveViewersMap.get(liveId);
        if (vMap) {
          const toDelete = [];
          for (const [sId, v] of vMap.entries()) {
            if (v.userId && v.userId.toString() === targetUserId) {
              io.to(sId).emit('kicked_from_live', {
                liveId,
                userId: targetUserId,
                message: 'Bạn đã bị chủ phòng mời ra khỏi buổi phát trực tiếp.'
              });
              const targetSocket = io.sockets.sockets.get(sId);
              if (targetSocket) {
                targetSocket.leave(room);
                targetSocket.liveId = null;
              }
              toDelete.push(sId);
            }
          }
          toDelete.forEach(id => vMap.delete(id));
        }

        const LiveStream = require('./models/livestream.model');
        const live = await LiveStream.findById(liveId);
        if (live && live.status === 'live') {
          const hostId = live.host?.toString();
          const uniqueViewers = getLiveUniqueViewers(liveId, hostId);
          live.viewersCount = uniqueViewers.length;
          await live.save();

          io.to(room).emit('live_viewers_updated', {
            liveId,
            viewersCount: uniqueViewers.length,
            viewers: uniqueViewers
          });
        }
      } catch (err) {
        console.error('Socket kick_live_viewer error:', err);
      }
    });

    socket.on('send_live_comment', (data) => {
      try {
        if (!data || !data.liveId || !data.comment) return;
        const liveId = data.liveId.toString().trim();
        const userId = data.userId ? data.userId.toString().trim() : '';

        // Kiểm tra xem người này có bị chặn bình luận không
        if (userId && liveBlockedCommentsMap.get(liveId)?.has(userId)) {
          socket.emit('live_comment_blocked', {
            liveId,
            userId,
            isBlocked: true,
            message: 'Bạn đã bị chủ phòng chặn bình luận.'
          });
          return; // Chặn không phát tin nhắn này đi
        }

        const room = `live_${liveId}`;

        const payload = {
          id: `comment_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
          liveId,
          userId: data.userId,
          userName: data.userName || 'Người dùng',
          userAvatar: data.userAvatar || null,
          comment: data.comment.toString().trim(),
          createdAt: new Date()
        };

        io.to(room).emit('new_live_comment', payload);
      } catch (err) {
        console.error('Socket send_live_comment error:', err);
      }
    });

    socket.on('send_live_reaction', async (data) => {
      try {
        if (!data || !data.liveId) return;
        const liveId = data.liveId.toString().trim();
        const room = `live_${liveId}`;
        let reaction = (data.reaction || 'like').toString().trim().toLowerCase();
        if (reaction === 'heart') reaction = 'love';
        if (reaction === 'cry') reaction = 'sad';

        const LiveStream = require('./models/livestream.model');
        const live = await LiveStream.findById(liveId);
        let reactionsCount = {};
        if (live) {
          live.likesCount = (live.likesCount || 0) + 1;
          if (!live.reactionsCount) {
            live.reactionsCount = { love: 0, like: 0, care: 0, haha: 0, wow: 0, sad: 0, angry: 0 };
          }
          live.reactionsCount[reaction] = (live.reactionsCount[reaction] || 0) + 1;
          live.markModified('reactionsCount');
          await live.save();
          reactionsCount = live.reactionsCount;
        }

        io.to(room).emit('new_live_reaction', {
          liveId,
          userId: data.userId,
          reaction,
          likesCount: live ? live.likesCount : 1,
          reactionsCount: live ? live.reactionsCount : { [reaction]: 1 }
        });
      } catch (err) {
        console.error('Socket send_live_reaction error:', err);
      }
    });

    socket.on('call_ringing', (data) => {
      try {
        if (!data || !data.callId || !data.callerId) return;
        const callerId = data.callerId.toString().trim();
        if (!callerId) return;
        io.to(callerId).emit('call_ringing', {
          callId: data.callId.toString(),
          userId: (data.userId || socket.userId || '').toString(),
        });
      } catch (err) {
        console.error('Socket call_ringing error:', err);
      }
    });

    socket.on('call_accept', async (data) => {
      try {
        if (!data || (!data.callId && !data.callDocId)) return;
        const userId = (data.userId || socket.userId || '').toString().trim();
        if (!userId) return;
        const { processAcceptCall } = require('./controllers/call.controller');
        await processAcceptCall({
          userId,
          callId: data.callId ? data.callId.toString() : undefined,
          callDocId: data.callDocId ? data.callDocId.toString() : undefined,
        });
      } catch (err) {
        console.error('Socket call_accept error:', err);
      }
    });

    socket.on('call_decline', async (data) => {
      try {
        if (!data || (!data.callId && !data.callDocId)) return;
        const userId = (data.userId || socket.userId || '').toString().trim();
        const { processDeclineCall } = require('./controllers/call.controller');
        await processDeclineCall({
          userId,
          callId: data.callId ? data.callId.toString() : undefined,
          callDocId: data.callDocId ? data.callDocId.toString() : undefined,
        });
      } catch (err) {
        console.error('Socket call_decline error:', err);
      }
    });

    socket.on('call_cancel', async (data) => {
      try {
        if (!data || (!data.callId && !data.callDocId)) return;
        const userId = (data.userId || socket.userId || '').toString().trim();
        const { processEndCall } = require('./controllers/call.controller');
        await processEndCall({
          userId,
          callId: data.callId ? data.callId.toString() : undefined,
          callDocId: data.callDocId ? data.callDocId.toString() : undefined,
          endForAll: true,
        });
      } catch (err) {
        console.error('Socket call_cancel error:', err);
      }
    });

    socket.on('call_end', async (data) => {
      try {
        if (!data || (!data.callId && !data.callDocId)) return;
        const userId = (data.userId || socket.userId || '').toString().trim();
        const { processEndCall } = require('./controllers/call.controller');
        await processEndCall({
          userId,
          callId: data.callId ? data.callId.toString() : undefined,
          callDocId: data.callDocId ? data.callDocId.toString() : undefined,
          endForAll: data.endForAll === true,
        });
      } catch (err) {
        console.error('Socket call_end error:', err);
      }
    });

    socket.on('call_heartbeat', async (data) => {
      try {
        if (!data || (!data.callId && !data.callDocId)) return;
        const userId = (data.userId || socket.userId || '').toString().trim();
        if (!userId) return;
        const { recordCallHeartbeat } = require('./controllers/call.controller');
        await recordCallHeartbeat({
          userId,
          callId: data.callId ? data.callId.toString() : undefined,
          callDocId: data.callDocId ? data.callDocId.toString() : undefined,
        });
      } catch (err) {
        console.error('Socket call_heartbeat error:', err);
      }
    });

    socket.on('call_media_state', (data) => {
      try {
        if (!data || !data.callId) return;
        const senderId = (data.userId || socket.userId || '').toString();
        const targets = Array.isArray(data.targetUserIds) ? data.targetUserIds : [];
        const payload = {
          callId: data.callId.toString(),
          userId: senderId,
          isVideoOn: data.isVideoOn === true,
          isAudioMuted: data.isAudioMuted === true,
        };
        for (const tId of targets) {
          if (tId && tId.toString() !== senderId) {
            io.to(tId.toString()).emit('call_media_state', payload);
          }
        }
      } catch (err) {
        console.error('Socket call_media_state error:', err);
      }
    });

    socket.on('disconnect', async () => {
      if (socket.liveId) {
        const lId = socket.liveId;
        const vMap = liveViewersMap.get(lId);
        if (vMap) {
          vMap.delete(socket.id);
          try {
            const LiveStream = require('./models/livestream.model');
            LiveStream.findById(lId).then(live => {
              if (live && live.status === 'live') {
                const hostId = live.host?.toString();
                const uniqueViewers = getLiveUniqueViewers(lId, hostId);
                live.viewersCount = uniqueViewers.length;
                live.save().catch(e => console.error(e));
                io.to(`live_${lId}`).emit('live_viewers_updated', {
                  liveId: lId,
                  viewersCount: uniqueViewers.length,
                  viewers: uniqueViewers
                });
              }
            }).catch(e => console.error(e));
          } catch (e) {
            console.error(e);
          }
        }
      }

      const uId = socket.userId;
      if (uId) {
        const userSockets = activeUserSockets.get(uId);
        if (userSockets) {
          userSockets.delete(socket.id);
          if (userSockets.size === 0) {
            activeUserSockets.delete(uId);
            let showActive = isActiveStatusVisible(uId);
            try {
              const Account = require('./models/account.model');
              const acc = await Account.findById(uId).select('privacy').lean();
              showActive = acc?.privacy?.showActiveStatus !== false;
              setActiveStatusPreference(uId, showActive);
              const updateDoc = showActive
                ? { isOnline: false, lastSeen: new Date() }
                : { isOnline: false };
              await Account.findByIdAndUpdate(uId, updateDoc);
            } catch (err) {
              console.error('[Socket] Disconnect update isOnline error:', err);
            }
            if (showActive) {
              io.emit('user_offline', { userId: uId });
            }
          }
        }
      }
    });
  });

  return io;
};

const getIO = () => io;

module.exports = {
  initSocket,
  getIO,
  isUserOnline,
  hasActiveSocket,
  setActiveStatusPreference,
  isActiveStatusVisible,
  activeUserSockets,
};
