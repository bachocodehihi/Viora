import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/welcome/welcome_screen.dart';
import '../screens/auth/signin_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/auth/setup_name_screen.dart';
import '../screens/auth/setup_birthday_screen.dart';
import '../screens/auth/setup_gender_screen.dart';
import '../screens/auth/setup_avatar_screen.dart';
import '../screens/auth/setup_password_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/change_password_screen.dart';
import '../screens/main/main_screen.dart';
import '../screens/term/terms_of_service_screen.dart';
import '../screens/term/privacy_policy_screen.dart';
import '../screens/setting/settings_screen.dart';
import '../screens/setting/privacy_security_screen.dart';
import '../screens/setting/delete_account_screen.dart';
import '../screens/setting/enter_password.dart';
import '../screens/setting/activity_screen.dart';
import '../screens/post/post_account_screen.dart';
import '../screens/post/status_screen.dart';
import '../widgets/portrait_wrapper.dart';

import '../screens/search/search_screen.dart';
import '../screens/search/search_results_screen.dart';
import '../screens/scan/scan_qr_screen.dart';
import '../screens/profile/profile_account_screen.dart';
import '../screens/profile/profile_group_screen.dart';
import '../screens/profile/qr_code_screen.dart';
import '../screens/edit/edit_screen.dart';
import '../screens/share/share_screen.dart';
import '../screens/profile/avatar_viewer_screen.dart';
import '../screens/chat/chat_detail_screen.dart';
import '../screens/chat/chat_info_screen.dart';
import '../screens/chat/pin_message_screen.dart';
import '../screens/post/post_image_viewer_screen.dart';
import '../screens/post/post_detail_screen.dart';
import '../screens/block/block_screen.dart';
import '../screens/setting/like_history_screen.dart';
import '../screens/setting/comment_history_screen.dart';
import '../screens/live/livestream_broadcaster_screen.dart';
import '../screens/live/livestream_audience_screen.dart';
import '../l10n/language.dart';

class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String signIn = '/signin';
  static const String signUp = '/signup';
  static const String verifyEmail = '/verify-email';
  static const String setupPassword = '/setup-password';
  static const String setupName = '/setup-name';
  static const String setupBirthday = '/setup-birthday';
  static const String setupGender = '/setup-gender';
  static const String setupAvatar = '/setup-avatar';
  static const String forgotPassword = '/forgot-password';
  static const String changePassword = '/change-password';
  static const String main = '/main';
  static const String termsOfService = '/terms-of-service';
  static const String privacyPolicy = '/privacy-policy';
  static const String settings = '/settings';
  static const String privacySecurity = '/privacy-security';
  static const String deleteAccount = '/delete-account';
  static const String enterPassword = '/enter-password';
  static const String postAccount = '/post-account';
  static const String search = '/search';
  static const String searchResults = '/search-results';
  static const String scanQr = '/scan-qr';
  static const String qrCode = '/qr-code';
  static const String activity = '/activity';
  static const String profileAccount = '/profile-account';
  static const String profileGroup = '/profile-group';
  static const String editProfile = '/edit-profile';
  static const String chatDetail = '/chat-detail';
  static const String chatInfo = '/chat-info';
  static const String pinMessage = '/pin-message';
  static const String share = '/share';
  static const String avatarViewer = '/avatar-viewer';
  static const String postImageViewer = '/post-image-viewer';
  static const String postDetail = '/post-detail';
  static const String status = '/status';
  static const String block = '/block';
  static const String likeHistory = '/like-history';
  static const String commentHistory = '/comment-history';
  static const String liveBroadcaster = '/live-broadcaster';
  static const String liveAudience = '/live-audience';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case welcome:
        return MaterialPageRoute(
          builder: (_) => const WellcomeScreen(),
          settings: settings,
        );
      case signIn:
        return MaterialPageRoute(
          builder: (_) => const PortraitWrapper(child: SignInScreen()),
          settings: settings,
        );
      case signUp:
        return MaterialPageRoute(
          builder: (_) => const PortraitWrapper(child: SignUpScreen()),
          settings: settings,
        );
      case verifyEmail:
        String email = '';
        bool isForgotPassword = false;
        bool isDeleteAccount = false;
        bool isTwoFactorLogin = false;
        String? twoFactorToken;
        String? deviceName;
        String? deviceId;
        bool returnResultOnVerify = false;
        if (settings.arguments is String) {
          email = settings.arguments as String;
        } else if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          email = args['email'] as String? ?? '';
          isForgotPassword = args['isForgotPassword'] as bool? ?? false;
          isDeleteAccount = args['isDeleteAccount'] as bool? ?? false;
          isTwoFactorLogin = args['isTwoFactorLogin'] as bool? ?? false;
          twoFactorToken = args['twoFactorToken'] as String?;
          deviceName = args['deviceName'] as String?;
          deviceId = args['deviceId'] as String?;
          returnResultOnVerify = args['returnResultOnVerify'] as bool? ?? false;
        }
        return MaterialPageRoute(
          builder: (_) => PortraitWrapper(
            child: VerifyEmailScreen(
              email: email,
              isForgotPassword: isForgotPassword,
              isDeleteAccount: isDeleteAccount,
              isTwoFactorLogin: isTwoFactorLogin,
              twoFactorToken: twoFactorToken,
              deviceName: deviceName,
              deviceId: deviceId,
              returnResultOnVerify: returnResultOnVerify,
            ),
          ),
          settings: settings,
        );
      case setupPassword:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => PortraitWrapper(child: SetupPasswordScreen(email: email)),
          settings: settings,
        );
      case setupName:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => PortraitWrapper(child: SetupNameScreen(email: email)),
          settings: settings,
        );
      case setupBirthday:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => PortraitWrapper(child: SetupBirthdayScreen(email: email)),
          settings: settings,
        );
      case setupGender:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => PortraitWrapper(child: SetupGenderScreen(email: email)),
          settings: settings,
        );
      case setupAvatar:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => PortraitWrapper(child: SetupAvatarScreen(email: email)),
          settings: settings,
        );
      case forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const PortraitWrapper(child: ForgotPasswordScreen()),
          settings: settings,
        );
      case changePassword:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => PortraitWrapper(child: ChangePasswordScreen(email: email)),
          settings: settings,
        );
      case main:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => MainScreen(email: email),
          settings: settings,
        );
      case termsOfService:
        return MaterialPageRoute(
          builder: (_) => const TermsOfServiceScreen(),
          settings: settings,
        );
      case privacyPolicy:
        return MaterialPageRoute(
          builder: (_) => const PrivacyPolicyScreen(),
          settings: settings,
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      case privacySecurity:
        return MaterialPageRoute(
          builder: (_) => const PrivacySecurityScreen(),
          settings: settings,
        );
      case deleteAccount:
        return MaterialPageRoute(
          builder: (_) => const DeleteAccountScreen(),
          settings: settings,
        );
      case enterPassword:
        bool isDeleteAccount = false;
        String? reason;
        String? email;
        String? targetAccountEmail;
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          isDeleteAccount = args['isDeleteAccount'] as bool? ?? false;
          reason = args['reason'] as String?;
          email = args['email'] as String?;
          targetAccountEmail = args['targetAccountEmail'] as String?;
        }
        return MaterialPageRoute(
          builder: (_) => EnterPasswordScreen(
            isDeleteAccount: isDeleteAccount,
            reason: reason,
            email: email,
            targetAccountEmail: targetAccountEmail,
          ),
          settings: settings,
        );
      case postAccount:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => PostAccountScreen(email: email),
          settings: settings,
        );
      case search:
        return MaterialPageRoute(
          builder: (_) => const SearchScreen(),
          settings: settings,
        );
      case searchResults:
        final query = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => SearchResultsScreen(query: query),
          settings: settings,
        );
      case scanQr:
        return MaterialPageRoute(
          builder: (_) => const ScanQrScreen(),
          settings: settings,
        );
      case qrCode:
        String? name;
        String? email;
        String? avatar;
        String? code;
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          name = args['name'] as String? ?? args['username'] as String?;
          email = args['email'] as String?;
          avatar = args['avatar'] as String?;
          code = args['qrCode'] as String?;
        } else if (settings.arguments is String) {
          email = settings.arguments as String;
        }
        return MaterialPageRoute(
          builder: (_) => QrCodeScreen(
            name: name,
            email: email,
            avatar: avatar,
            qrCode: code,
          ),
          settings: settings,
        );
      case activity:
        return MaterialPageRoute(
          builder: (_) => const ActivityScreen(),
          settings: settings,
        );
      case profileAccount:
        String email = '';
        String? name;
        String? avatar;
        Color? color;
        String? status;
        int? mutualFriends;
        bool isMe = false;

        if (settings.arguments is String) {
          email = settings.arguments as String;
        } else if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          email = args['email'] as String? ?? '';
          name = args['name'] as String?;
          avatar = args['avatar'] as String?;
          if (args['color'] is Color) {
            color = args['color'] as Color;
          }
          status = args['status'] as String? ?? args['bio'] as String?;
          if (args['mutualFriends'] is int) {
            mutualFriends = args['mutualFriends'] as int;
          }
          isMe = args['isMe'] as bool? ?? false;
        }

        final String? userId = (settings.arguments is Map<String, dynamic>)
            ? ((settings.arguments as Map<String, dynamic>)['id']?.toString() ??
               (settings.arguments as Map<String, dynamic>)['userId']?.toString())
            : null;

        final bool hasFriendRequest = (settings.arguments is Map<String, dynamic>)
            ? ((settings.arguments as Map<String, dynamic>)['hasFriendRequest'] == true)
            : false;

        final String? requestId = (settings.arguments is Map<String, dynamic>)
            ? (settings.arguments as Map<String, dynamic>)['requestId']?.toString()
            : null;

        final bool isFriend = (settings.arguments is Map<String, dynamic>)
            ? ((settings.arguments as Map<String, dynamic>)['isFriend'] == true)
            : false;

        return MaterialPageRoute(
          builder: (_) => ProfileAccountScreen(
            userId: userId,
            requestId: requestId,
            hasFriendRequest: hasFriendRequest,
            isFriend: isFriend,
            email: email,
            name: name,
            avatar: avatar,
            color: color,
            status: status,
            mutualFriends: mutualFriends,
            isMe: isMe,
          ),
          settings: settings,
        );

      case share:
        String postAuthor = '';
        String postContent = '';
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          postAuthor = args['postAuthor'] as String? ?? '';
          postContent = args['postContent'] as String? ?? '';
        }
        return MaterialPageRoute(
          builder: (_) => ShareScreen(
            postAuthor: postAuthor,
            postContent: postContent,
          ),
          settings: settings,
        );

      case profileGroup:
        String name = '';
        String avatar = '';
        Color? color;
        int membersCount = 8;
        String? conversationId;
        String? groupId;
        String? description;

        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          name = args['name'] as String? ?? '';
          avatar = args['avatar'] as String? ?? '';
          if (args['color'] is Color) {
            color = args['color'] as Color;
          }
          if (args['membersCount'] is int) {
            membersCount = args['membersCount'] as int;
          }
          description = args['description'] as String?;
          conversationId = args['conversationId']?.toString();
          groupId = args['id']?.toString() ?? args['groupId']?.toString();
          final privacy = args['privacy']?.toString();
          return MaterialPageRoute(
            builder: (_) => ProfileGroupScreen(
              name: name,
              avatar: avatar,
              color: color,
              membersCount: membersCount,
              description: description,
              conversationId: conversationId,
              groupId: groupId,
              privacy: privacy,
            ),
            settings: settings,
          );
        }

        return MaterialPageRoute(
          builder: (_) => ProfileGroupScreen(
            name: name,
            avatar: avatar,
            color: color,
            membersCount: membersCount,
            description: description,
            conversationId: conversationId,
            groupId: groupId,
          ),
          settings: settings,
        );

      case editProfile:
        Map<String, dynamic> args = {};
        if (settings.arguments is Map<String, dynamic>) {
          args = settings.arguments as Map<String, dynamic>;
        }
        return MaterialPageRoute(
          builder: (_) => EditScreen(
            username: args['username'] as String?,
            bio: args['bio'] as String?,
            gender: args['gender'] as String?,
            birthday: args['birthday'] as String?,
            phone: args['phone'] as String?,
            address: args['address'] as String?,
            job: args['job'] as String?,
            nationality: args['nationality'] as String?,
            hobby: args['hobby'] as String?,
            avatar: args['avatar'] as String?,
            coverImage: args['coverImage'] as String?,
          ),
          settings: settings,
        );

      case chatDetail:
        String name = '';
        String avatar = '';
        Color color = const Color(0xFF2196F3);
        List<Map<String, dynamic>> initialMessages = const [];
        String? conversationId;
        String? receiverId;
        bool? isGroup;
        bool? isFriend;
        bool? isOnline;
        bool? showActiveStatus;

        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          name = args['name'] as String? ?? '';
          avatar = args['avatar'] as String? ?? '';
          if (args['color'] is Color) {
            color = args['color'] as Color;
          }
          if (args['initialMessages'] is List) {
            initialMessages = List<Map<String, dynamic>>.from(args['initialMessages'] as List);
          }
          conversationId = args['conversationId'] as String?;
          receiverId = args['receiverId'] as String?;
          isGroup = args['isGroup'] as bool?;
          isFriend = args['isFriend'] as bool?;
          isOnline = args['isOnline'] as bool?;
          showActiveStatus = args['showActiveStatus'] as bool?;
        }

        return MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            name: name,
            avatar: avatar,
            color: color,
            initialMessages: initialMessages,
            conversationId: conversationId,
            receiverId: receiverId,
            isGroup: isGroup,
            isFriend: isFriend,
            isOnline: isOnline,
            showActiveStatus: showActiveStatus,
          ),
          settings: settings,
        );

      case chatInfo:
        String name = '';
        String avatar = '';
        Color color = const Color(0xFF2196F3);
        String? conversationId;
        String? receiverId;
        List<Map<String, dynamic>> messages = const [];
        Map<String, dynamic>? pinnedMessage;
        List<Map<String, dynamic>> pinnedMessages = const [];

        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          name = args['name'] as String? ?? '';
          avatar = args['avatar'] as String? ?? '';
          if (args['color'] is Color) {
            color = args['color'] as Color;
          }
          conversationId = args['conversationId'] as String?;
          receiverId = args['receiverId'] as String?;
          if (args['messages'] is List) {
            messages = List<Map<String, dynamic>>.from(args['messages'] as List);
          }
          if (args['pinnedMessage'] is Map) {
            pinnedMessage = Map<String, dynamic>.from(args['pinnedMessage'] as Map);
          }
          if (args['pinnedMessages'] is List) {
            pinnedMessages = List<Map<String, dynamic>>.from(
              (args['pinnedMessages'] as List).whereType<Map<String, dynamic>>(),
            );
          }
        }

        return MaterialPageRoute(
          builder: (_) => ChatInfoScreen(
            name: name,
            avatar: avatar,
            color: color,
            conversationId: conversationId,
            receiverId: receiverId,
            messages: messages,
            pinnedMessage: pinnedMessage,
            pinnedMessages: pinnedMessages,
          ),
          settings: settings,
        );

      case pinMessage:
        String? conversationId;
        List<Map<String, dynamic>> pinnedMessages = const [];
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          conversationId = args['conversationId']?.toString();
          if (args['pinnedMessages'] is List) {
            pinnedMessages = List<Map<String, dynamic>>.from(
              (args['pinnedMessages'] as List).whereType<Map<String, dynamic>>(),
            );
          }
        }
        return MaterialPageRoute(
          builder: (_) => PinMessageScreen(
            conversationId: conversationId,
            initialPinnedMessages: pinnedMessages,
          ),
          settings: settings,
        );

      case avatarViewer:
        String? imageUrl;
        String? title;
        String? fallbackText;
        Color? fallbackColor;
        String? heroTag;
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          final rawImage = (args['imageUrl'] ?? args['avatarUrl'] ?? args['avatar']) as String?;
          if (rawImage != null &&
              (rawImage.startsWith('http://') ||
                  rawImage.startsWith('https://') ||
                  rawImage.startsWith('assets/'))) {
            imageUrl = rawImage;
          }
          title = (args['title'] ?? args['userName'] ?? args['name']) as String?;
          final rawFallback =
              (args['fallbackText'] ?? args['initial'] ?? args['userName'] ?? args['name']) as String?;
          if (rawFallback != null && !rawFallback.startsWith('http')) {
            fallbackText = rawFallback.length <= 3 ? rawFallback : rawFallback[0].toUpperCase();
          }
          fallbackColor = (args['fallbackColor'] ?? args['color']) as Color?;
          heroTag = args['heroTag'] as String?;
        } else if (settings.arguments is String) {
          imageUrl = settings.arguments as String;
        }
        return PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (_, animation, secondaryAnimation) => AvatarViewerScreen(
            imageUrl: imageUrl,
            title: title,
            fallbackText: fallbackText,
            fallbackColor: fallbackColor,
            heroTag: heroTag,
          ),
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
              child: child,
            );
          },
          settings: settings,
        );

      case status:
        String? currentNote;
        dynamic userAvatar;
        String? userName;
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          currentNote = args['currentNote'] as String?;
          userAvatar = args['userAvatar'];
          userName = args['userName'] as String?;
        }
        return MaterialPageRoute(
          builder: (_) => StatusScreen(
            currentNote: currentNote,
            userAvatar: userAvatar,
            userName: userName,
          ),
          settings: settings,
        );

      case postImageViewer:
        List<String> images = const [];
        int initialIndex = 0;
        String? authorName;
        String? authorAvatar;
        String? postTime;
        String? postContent;

        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          if (args['images'] is List) {
            images = (args['images'] as List).map((e) => e.toString()).toList();
          }
          if (args['initialIndex'] is int) {
            initialIndex = args['initialIndex'] as int;
          }
          authorName = args['authorName'] as String?;
          authorAvatar = args['authorAvatar'] as String?;
          postTime = args['postTime'] as String?;
          postContent = args['postContent'] as String?;
        }

        return PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black,
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, animation, secondaryAnimation) => PostImageViewerScreen(
            images: images,
            initialIndex: initialIndex,
            authorName: authorName,
            authorAvatar: authorAvatar,
            postTime: postTime,
            postContent: postContent,
          ),
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
              child: child,
            );
          },
          settings: settings,
        );

      case postDetail:
        Map<String, dynamic> post = const {};
        String? userEmail;
        String? userName;
        String? userAvatar;
        Function(Map<String, dynamic>)? onPostUpdated;

        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          if (args['post'] is Map<String, dynamic>) {
            post = args['post'] as Map<String, dynamic>;
          }
          userEmail = args['userEmail'] as String?;
          userName = args['userName'] as String?;
          userAvatar = args['userAvatar'] as String?;
          if (args['onPostUpdated'] is Function(Map<String, dynamic>)) {
            onPostUpdated = args['onPostUpdated'] as Function(Map<String, dynamic>);
          }
        }

        return MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            post: post,
            userEmail: userEmail,
            userName: userName,
            userAvatar: userAvatar,
            onPostUpdated: onPostUpdated,
          ),
          settings: settings,
        );

      case block:
        return MaterialPageRoute(
          builder: (_) => const BlockScreen(),
          settings: settings,
        );

      case likeHistory:
        return MaterialPageRoute(
          builder: (_) => const LikeHistoryScreen(),
          settings: settings,
        );

      case commentHistory:
        return MaterialPageRoute(
          builder: (_) => const CommentHistoryScreen(),
          settings: settings,
        );

      case liveBroadcaster:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => LivestreamBroadcasterScreen(
            liveData: args['liveData'] ?? {},
            initialMode: args['initialMode']?.toString() ?? 'camera',
            hostName: args['hostName']?.toString(),
            hostAvatar: args['hostAvatar']?.toString(),
          ),
          settings: settings,
        );

      case liveAudience:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => LivestreamAudienceScreen(
            liveId: args['liveId']?.toString() ?? '',
            initialTitle: args['initialTitle']?.toString(),
            hostName: args['hostName']?.toString(),
            hostAvatar: args['hostAvatar']?.toString(),
          ),
          settings: settings,
        );


      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: Text(
                context.l10n.noRouteDefined(settings.name ?? ''),
              ),
            ),
          ),
          settings: settings,
        );
    }
  }
}
