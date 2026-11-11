import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/session_service.dart';

class QrCodeScreen extends StatefulWidget {
  final String? name;
  final String? email;
  final String? avatar;
  final String? qrCode;

  const QrCodeScreen({
    super.key,
    this.name,
    this.email,
    this.avatar,
    this.qrCode,
  });

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  String? _username;
  String? _email;
  String? _avatar;
  String? _qrCode;
  String? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _username = widget.name;
    _email = widget.email;
    _avatar = widget.avatar;
    _qrCode = widget.qrCode;
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {

    final cachedEmail = widget.email ?? await SessionService.getUserEmail();
    final cachedUsername = widget.name ?? await SessionService.getUsername();
    final cachedAvatar = widget.avatar ?? await SessionService.getAvatar();
    final cachedQrCode = widget.qrCode ?? await SessionService.getQrCode();
    final cachedUserId = await SessionService.getUserId();

    if (mounted) {
      setState(() {
        _email = cachedEmail;
        _username = cachedUsername;
        _avatar = cachedAvatar;
        _qrCode = cachedQrCode;
        _userId = cachedUserId;
        _isLoading = false;
      });
    }

    try {
      final token = await SessionService.getToken();
      final body = <String, dynamic>{};
      if (_userId != null && _userId!.isNotEmpty) {
        body['userId'] = _userId;
      }
      if (_email != null && _email!.isNotEmpty) {
        body['email'] = _email;
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.loadProfile),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['account'] != null) {
          final account = data['account'] as Map<String, dynamic>;
          final serverUsername = account['username']?.toString();
          final serverAvatar = account['avatar']?.toString();
          final serverQrCode = account['qrCode']?.toString();
          final serverEmail = account['email']?.toString();
          final serverId = account['_id']?.toString() ?? account['id']?.toString();

          if (mounted) {
            setState(() {
              if (serverUsername != null && serverUsername.isNotEmpty) {
                _username = serverUsername;
              }
              if (serverAvatar != null && serverAvatar.isNotEmpty) {
                _avatar = serverAvatar;
              }
              if (serverQrCode != null && serverQrCode.isNotEmpty) {
                _qrCode = serverQrCode;
              }
              if (serverEmail != null && serverEmail.isNotEmpty) {
                _email = serverEmail;
              }
              if (serverId != null && serverId.isNotEmpty) {
                _userId = serverId;
              }
            });
          }

          await SessionService.updateProfile(
            username: serverUsername,
            avatar: serverAvatar,
            qrCode: serverQrCode,
          );
        }
      }
    } catch (e) {
      debugPrint('Profile refresh error for QR: $e');
    }
  }

  String _buildQrPayload() {
    if (_qrCode != null &&
        _qrCode!.isNotEmpty &&
        !_qrCode!.startsWith('http://') &&
        !_qrCode!.startsWith('https://')) {
      return _qrCode!;
    }

    final payload = {
      'type': 'user_profile',
      'userId': _userId ?? '',
      'username': _username ?? '',
      'email': _email ?? '',
    };
    return jsonEncode(payload);
  }

  Widget _buildAvatarWidget(String initial) {
    final avatarUrl = _avatar;
    final isNetwork = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.blue.withValues(alpha: 0.3),
          width: 2.r,
        ),
      ),
      child: isNetwork
          ? ClipOval(
              child: Image.network(
                avatarUrl,
                width: 72.r,
                height: 72.r,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _buildFallbackAvatar(initial);
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackAvatar(initial);
                },
              ),
            )
          : _buildFallbackAvatar(initial),
    );
  }

  Widget _buildFallbackAvatar(String initial) {
    return CircleAvatar(
      radius: 36.r,
      backgroundColor: AppColors.blue,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 28.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildQrWidget(String qrPayload) {
    final qrUrl = _qrCode;
    final isNetworkImage = qrUrl != null &&
        qrUrl.isNotEmpty &&
        (qrUrl.startsWith('http://') || qrUrl.startsWith('https://'));

    if (isNetworkImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Image.network(
          qrUrl,
          width: 200.r,
          height: 200.r,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: 200.r,
              height: 200.r,
              child: Center(
                child: SizedBox(
                  width: 32.r,
                  height: 32.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5.r,
                    color: AppColors.blue,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildVectorQr(qrPayload);
          },
        ),
      );
    }

    return _buildVectorQr(qrPayload);
  }

  Widget _buildVectorQr(String data) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: 200.r,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF1E1E2C),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.circle,
        color: Color(0xFF1E1E2C),
      ),
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final displayName = (_username != null && _username!.isNotEmpty)
        ? _username!
        : ((_email != null && _email!.isNotEmpty)
            ? _email!.split('@')[0]
            : 'Viora User');

    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'V';
    final qrPayload = _buildQrPayload();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          l10n.myQrCode,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20.r),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20.r,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: context.borderTheme,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      _buildAvatarWidget(initial),

                      SizedBox(height: 12.h),

                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      if (_email != null && _email!.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          _email!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: context.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      SizedBox(height: 24.h),

                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10.r,
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 200.r,
                                height: 200.r,
                                child: Center(
                                  child: SizedBox(
                                    width: 32.r,
                                    height: 32.r,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5.r,
                                      color: AppColors.blue,
                                    ),
                                  ),
                                ),
                              )
                            : _buildQrWidget(qrPayload),
                      ),

                      SizedBox(height: 20.h),

                      Text(
                        l10n.alignQrInFrame,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: context.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
