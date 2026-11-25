class StoryItem {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final String mediaUrl;
  final String mediaType;
  final String backgroundColor;
  final String privacy;
  final DateTime createdAt;
  final DateTime expiresAt;
  bool isViewed;
  int viewersCount;
  final List<Map<String, dynamic>> viewers;
  final List<Map<String, dynamic>> reactions;

  StoryItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.content = '',
    this.mediaUrl = '',
    this.mediaType = 'image',
    this.backgroundColor = '#1A1A24',
    this.privacy = 'friends',
    required this.createdAt,
    required this.expiresAt,
    this.isViewed = false,
    this.viewersCount = 0,
    this.viewers = const [],
    this.reactions = const [],
  });

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    String uId = '';
    String uName = '';
    String? uAvatar;

    if (user is Map) {
      uId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
      uName = user['username']?.toString() ?? '';
      uAvatar = user['avatar']?.toString();
    } else if (user != null) {
      uId = user.toString();
    }

    final viewersRaw = json['viewers'];
    final List<Map<String, dynamic>> viewersList = [];
    if (viewersRaw is List) {
      for (final v in viewersRaw) {
        if (v is Map) {
          viewersList.add(Map<String, dynamic>.from(v));
        }
      }
    }

    final reactionsRaw = json['reactions'];
    final List<Map<String, dynamic>> reactionsList = [];
    if (reactionsRaw is List) {
      for (final r in reactionsRaw) {
        if (r is Map) {
          reactionsList.add(Map<String, dynamic>.from(r));
        }
      }
    }

    DateTime created = DateTime.now();
    if (json['createdAt'] != null) {
      try {
        created = DateTime.parse(json['createdAt'].toString());
      } catch (_) {}
    }

    DateTime expires = DateTime.now().add(const Duration(hours: 24));
    if (json['expiresAt'] != null) {
      try {
        expires = DateTime.parse(json['expiresAt'].toString());
      } catch (_) {}
    }

    return StoryItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: uId,
      userName: uName,
      userAvatar: uAvatar,
      content: json['content']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? 'image',
      backgroundColor: json['backgroundColor']?.toString() ?? '#1A1A24',
      privacy: json['privacy']?.toString() ?? 'friends',
      createdAt: created,
      expiresAt: expires,
      isViewed: json['isViewed'] == true,
      viewersCount: (json['viewersCount'] as num?)?.toInt() ?? viewersList.length,
      viewers: viewersList,
      reactions: reactionsList,
    );
  }
}

class UserStoryGroup {
  final String userId;
  final String userName;
  final String? userAvatar;
  final bool isOnline;
  final List<StoryItem> stories;
  bool hasUnseen;
  final bool isMe;

  UserStoryGroup({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.isOnline = false,
    required this.stories,
    this.hasUnseen = false,
    this.isMe = false,
  });

  factory UserStoryGroup.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    String uId = '';
    String uName = '';
    String? uAvatar;
    bool online = false;

    if (user is Map) {
      uId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
      uName = user['username']?.toString() ?? '';
      uAvatar = user['avatar']?.toString();
      online = user['isOnline'] == true;
    }

    final storiesRaw = json['stories'];
    final List<StoryItem> storyList = [];
    if (storiesRaw is List) {
      for (final s in storiesRaw) {
        if (s is Map) {
          storyList.add(StoryItem.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }

    return UserStoryGroup(
      userId: uId,
      userName: uName,
      userAvatar: uAvatar,
      isOnline: online,
      stories: storyList,
      hasUnseen: json['hasUnseen'] == true,
      isMe: json['isMe'] == true,
    );
  }
}
