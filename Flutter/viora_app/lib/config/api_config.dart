class ApiConfig {

  static const String socketUrl = 'http://192.168.1.7:5000';
  static const String baseUrl = '$socketUrl/api'; 

  static const String sendOtp = '$baseUrl/auth/send-otp';
  static const String verifyOtp = '$baseUrl/auth/verify-otp';
  static const String register = '$baseUrl/auth/sign-up';
  static const String login = '$baseUrl/auth/sign-in';
  static const String googleSignIn = '$baseUrl/auth/google-sign-in';
  static const String resetPassword = '$baseUrl/auth/reset-password';
  static const String loadProfile = '$baseUrl/account/load-profile';
  static const String updateProfile = '$baseUrl/account/update-profile';
  static const String updateNote = '$baseUrl/account/update-note';
  static const String requestDeleteAccount = '$baseUrl/account/request-delete-account';
  static const String cancelDeleteAccount = '$baseUrl/account/cancel-delete-account';
  static const String getDeletionStatus = '$baseUrl/account/deletion-status';
  static const String togglePrivateAccount = '$baseUrl/account/toggle-private';
  static const String updatePrivacy = '$baseUrl/account/update-privacy';
  static const String toggleTwoFactor = '$baseUrl/account/toggle-two-factor';

  static const String getContacts = '$baseUrl/contact/get-contacts';
  static const String sendFriendRequest = '$baseUrl/contact/send-friend-request';
  static const String cancelFriendRequest = '$baseUrl/contact/cancel-send-friend-request';
  static const String acceptFriendRequest = '$baseUrl/contact/accept-friend-request';
  static const String rejectFriendRequest = '$baseUrl/contact/reject-friend-request';
  static const String acceptFollowRequest = '$baseUrl/contact/accept-follow-request';
  static const String rejectFollowRequest = '$baseUrl/contact/reject-follow-request';
  static const String acceptGroupInvite = '$baseUrl/contact/accept-group-invite';
  static const String rejectGroupInvite = '$baseUrl/contact/reject-group-invite';
  static const String removeFriend = '$baseUrl/contact/remove-friend';
  static const String followAccount = '$baseUrl/contact/follow-account';
  static const String unfollowAccount = '$baseUrl/contact/unfollow-account';

  static const String createGroup = '$baseUrl/group/create-group';
  static const String getMyGroups = '$baseUrl/group/my-groups';
  static const String getDiscoverGroups = '$baseUrl/group/discover';
  static const String searchGroups = '$baseUrl/group/search';
  static String getGroupDetail(String id) => '$baseUrl/group/$id';
  static String joinGroup(String id) => '$baseUrl/group/$id/join';
  static String requestJoinGroup(String id) => '$baseUrl/group/$id/request-join';
  static String cancelJoinRequest(String id) => '$baseUrl/group/$id/cancel-request';
  static String getJoinRequests(String id) => '$baseUrl/group/$id/join-requests';
  static String handleJoinRequest(String id) => '$baseUrl/group/$id/handle-request';
  static String inviteGroupMembers(String id) => '$baseUrl/group/$id/invite';
  static String respondGroupInvite(String id) => '$baseUrl/group/$id/respond-invite';
  static String leaveGroup(String id) => '$baseUrl/group/$id/leave';
  static String deleteGroup(String id) => '$baseUrl/group/$id/delete';

  static const String getConversations = '$baseUrl/message/conversations';
  static const String sendMessage = '$baseUrl/message/send-message';
  static const String loadMessages = '$baseUrl/message/load-message';
  static const String deleteMessage = '$baseUrl/message/delete-message';
  static const String recallMessage = '$baseUrl/message/recall-message';
  static const String pinMessage = '$baseUrl/message/pin-message';
  static const String unPinMessage = '$baseUrl/message/unpin-message';
  static const String reactMessage = '$baseUrl/message/react-message';
  static const String stopShareLocation = '$baseUrl/message/stop-share-location';
  static const String updateLiveLocation = '$baseUrl/message/update-live-location';
  static const String votePoll = '$baseUrl/message/vote-poll';
  static const String updateFcmToken = '$baseUrl/notification/update-fcm-token';
  static const String getNotifications = '$baseUrl/notification/get-notifications';
  static const String markNotificationRead = '$baseUrl/notification/mark-read';
  static const String markAllNotificationsRead = '$baseUrl/notification/mark-all-read';
  static const String clearNotifications = '$baseUrl/notification/clear-all';
  static const String updateNotificationStatus = '$baseUrl/notification/update-status';
  static const String recordActivity = '$baseUrl/account/record-activity';
  static const String getActivity = '$baseUrl/account/get-activity';
  static const String search = '$baseUrl/account/search';
  static const String loadSearchHistory = '$baseUrl/account/load-search-history';
  static const String deleteSearchHistory = '$baseUrl/account/delete-search-history';
  static const String clearSearchHistory = '$baseUrl/account/clear-search-history';
  static const String scanQr = '$baseUrl/account/scan-qr';
  static const String publishPost = '$baseUrl/post/publish-post';
  static const String getFeed = '$baseUrl/post/feed';
  static const String getUserPosts = '$baseUrl/post/user-posts';
  static const String getGroupPosts = '$baseUrl/post/group-posts';
  static const String likePost = '$baseUrl/post/like-post';
  static const String commentPost = '$baseUrl/post/comment-post';
  static const String getComments = '$baseUrl/post/comments';
  static const String likeComment = '$baseUrl/post/like-comment-post';
  static const String deletePost = '$baseUrl/post/delete-post';
  static const String reportPost = '$baseUrl/post/report-post';
  static const String notInterestedPost = '$baseUrl/post/not-interested';
  static const String toggleComments = '$baseUrl/post/toggle-comments';
  static const String commentSettings = '$baseUrl/post/comment-settings';
  static const String blockCommenter = '$baseUrl/post/block-commenter';
  static const String unblockCommenter = '$baseUrl/post/unblock-commenter';
  static const String deleteComment = '$baseUrl/post/delete-comment';
  
  static const String blockAccount = '$baseUrl/account/block-account';
  static const String unblockAccount = '$baseUrl/account/unblock-account';
  static const String loadBlock = '$baseUrl/account/load-block';
  static const String reportAccount = '$baseUrl/account/report-account';
  static const String getLikeHistory = '$baseUrl/account/like-history';
  static const String getCommentHistory = '$baseUrl/account/comment-history';

  static const String getNations = '$baseUrl/location/nations';
  static const String getCities = '$baseUrl/location/cities';
  static const String getWards = '$baseUrl/location/wards';

  static const String createLive = '$baseUrl/live/create';
  static const String getActiveLives = '$baseUrl/live/active';
  static String getLiveDetail(String id) => '$baseUrl/live/$id';
  static String endLive(String id) => '$baseUrl/live/$id/end';

  static const String startCall = '$baseUrl/call/start';
  static const String joinCall = '$baseUrl/call/join';
  static const String acceptCall = '$baseUrl/call/accept';
  static const String declineCall = '$baseUrl/call/decline';
  static const String endCall = '$baseUrl/call/end';
  static const String missedCall = '$baseUrl/call/missed';
  static String getCallDetail(String callId) => '$baseUrl/call/$callId';
}
