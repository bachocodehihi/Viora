import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../l10n/language.dart';
import '../../services/profile_service.dart';
import '../../services/session_service.dart';
import '../../widgets/toast/app_toast.dart';
import '../profile/profile_account_screen.dart';
import '../profile/qr_code_screen.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animationController;
  late final Animation<double> _scanAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      cameraResolution: const Size(1920, 1080),
      formats: const [BarcodeFormat.qrCode],
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateToProfile({
    required String targetUserId,
    required String email,
    String? name,
    String? avatar,
    required bool isMe,
    bool isFriend = false,
    bool hasFriendRequest = false,
    bool hasSentRequest = false,
    String? requestId,
  }) async {
    try {
      await _controller.stop();
    } catch (_) {}

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileAccountScreen(
          userId: targetUserId,
          email: email,
          name: name,
          avatar: avatar,
          isMe: isMe,
          isFriend: isFriend,
          hasFriendRequest: hasFriendRequest,
          hasSentRequest: hasSentRequest,
          requestId: requestId,
        ),
      ),
    );

    if (mounted) {
      try {
        await _controller.start();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleQrCode(String rawCode) async {
    if (_isProcessing || !mounted) return;
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      HapticFeedback.mediumImpact();

      final userAccount = await ProfileService.scanUserQr(trimmed);

      if (!mounted) return;

      if (userAccount != null) {

        if (userAccount['groupId'] != null || userAccount['privacy'] != null) {
          final gId = userAccount['groupId']?.toString() ?? userAccount['id']?.toString() ?? '';
          await Navigator.pushReplacementNamed(
            context,
            AppRoutes.profileGroup,
            arguments: {
              'id': gId,
              'groupId': gId,
              'name': userAccount['name']?.toString() ?? l10n.group,
              'avatar': userAccount['avatar']?.toString() ?? '',
              'privacy': userAccount['privacy']?.toString() ?? 'public',
              'description': userAccount['description']?.toString() ?? '',
              'membersCount': (userAccount['membersCount'] as num?)?.toInt() ?? 1,
              'conversationId': userAccount['conversationId']?.toString(),
            },
          );
          return;
        }

        final currentUserId = await SessionService.getUserId();
        final targetUserId = userAccount['id']?.toString() ?? userAccount['_id']?.toString() ?? '';
        final isMe = (currentUserId != null && targetUserId.isNotEmpty && currentUserId == targetUserId);

        final bool isFriend = userAccount['isFriend'] == true;
        final bool hasFriendRequest = userAccount['hasFriendRequest'] == true;
        final bool hasSentRequest = userAccount['hasSentRequest'] == true;
        final String? requestId = userAccount['requestId']?.toString();

        await _navigateToProfile(
          targetUserId: targetUserId,
          email: userAccount['email']?.toString() ?? '',
          name: userAccount['username']?.toString(),
          avatar: userAccount['avatar']?.toString(),
          isMe: isMe,
          isFriend: isFriend,
          hasFriendRequest: hasFriendRequest,
          hasSentRequest: hasSentRequest,
          requestId: requestId,
        );
        return;
      } else {

        Map<String, dynamic>? localParsed;
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) localParsed = decoded;
        } catch (_) {}

        if (localParsed != null && (localParsed['type'] == 'group' || localParsed['groupId'] != null)) {
          final gId = localParsed['groupId']?.toString() ?? '';
          await Navigator.pushReplacementNamed(
            context,
            AppRoutes.profileGroup,
            arguments: {
              'id': gId,
              'groupId': gId,
              'name': localParsed['name']?.toString() ?? l10n.group,
              'privacy': localParsed['privacy']?.toString() ?? 'public',
            },
          );
          return;
        }

        if (localParsed != null && (localParsed['userId'] != null || localParsed['type'] == 'user_profile')) {
          final targetUserId = localParsed['userId']?.toString() ?? '';
          final currentUserId = await SessionService.getUserId();
          final isMe = (currentUserId != null && targetUserId.isNotEmpty && currentUserId == targetUserId);

          await _navigateToProfile(
            targetUserId: targetUserId,
            email: localParsed['email']?.toString() ?? '',
            name: localParsed['username']?.toString(),
            isMe: isMe,
          );
          return;
        } else {
          AppToast.error(context, l10n.invalidQrOrNotFound);
        }
      }
    } catch (e) {
      debugPrint('QR Processing error: $e');
      if (mounted) {
        AppToast.error(context, l10n.cannotReadQr);
      }
    } finally {
      if (mounted && _isProcessing) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && _isProcessing) {
            setState(() {
              _isProcessing = false;
            });
          }
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isProcessing) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
        if (capture != null && capture.barcodes.isNotEmpty) {
          final code = capture.barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            await _handleQrCode(code);
            return;
          }
        }
        if (mounted) {
          AppToast.error(context, l10n.noQrFoundInImage);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        AppToast.error(context, l10n.errorScanningQrFromGallery);
      }
    }
  }

  void _openMyQrCode() async {
    try {
      await _controller.stop();
    } catch (_) {}
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const QrCodeScreen(),
      ),
    );
    if (mounted) {
      try {
        await _controller.start();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isProcessing) return;
              for (final barcode in capture.barcodes) {
                final String? raw = barcode.rawValue;
                if (raw != null && raw.trim().isNotEmpty) {
                  _handleQrCode(raw);
                  break;
                }
              }
            },
          ),

          const QrOverlayMask(),

          Center(
            child: SizedBox(
              width: 260.r,
              height: 260.r,
              child: AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(
                        top: _scanAnimation.value * (260.r - 4.h),
                        left: 12.w,
                        right: 12.w,
                        child: Container(
                          height: 3.h,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.blue,
                                AppColors.teal,
                                AppColors.blue,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.blue.withValues(alpha: 0.8),
                                blurRadius: 10.r,
                                spreadRadius: 2.r,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          Center(
            child: CustomPaint(
              size: Size(260.r, 260.r),
              painter: QrCornerPainter(
                color: AppColors.blue,
                cornerLength: 28.r,
                strokeWidth: 4.r,
              ),
            ),
          ),

          if (_isProcessing)
            Center(
              child: Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: SizedBox(
                  width: 28.r,
                  height: 28.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.8,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.4),
                          shape: const CircleBorder(),
                        ),
                        icon: Icon(Icons.arrow_back_ios_new, size: 20.r, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        l10n.scanQrCode,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16.h),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      l10n.alignQrInFrame,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 32.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: Icons.photo_library_outlined,
                      label: l10n.gallery,
                      onTap: _pickImageFromGallery,
                    ),
                    _buildControlButton(
                      icon: Icons.qr_code_rounded,
                      label: l10n.myQrCode,
                      onTap: _openMyQrCode,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52.r,
            height: 52.r,
            decoration: BoxDecoration(
              color: isActive ? AppColors.blue : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.blue : Colors.white24,
                width: 1.5.r,
              ),
            ),
            child: Icon(
              icon,
              size: 24.r,
              color: isActive ? Colors.white : Colors.white,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class QrOverlayMask extends StatelessWidget {
  const QrOverlayMask({super.key});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.6),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.transparent,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: 260.r,
              height: 260.r,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QrCornerPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  QrCornerPainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final radius = 20.r;

    final topLeft = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(cornerLength, 0);
    canvas.drawPath(topLeft, paint);

    final topRight = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(topRight, paint);

    final bottomLeft = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - radius)
      ..quadraticBezierTo(0, size.height, radius, size.height)
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(bottomLeft, paint);

    final bottomRight = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - radius, size.height)
      ..quadraticBezierTo(size.width, size.height, size.width, size.height - radius)
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(bottomRight, paint);
  }

  @override
  bool shouldRepaint(covariant QrCornerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
