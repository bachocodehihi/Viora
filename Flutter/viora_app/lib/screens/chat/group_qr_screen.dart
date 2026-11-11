import '../../l10n/language.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';

class GroupQrScreen extends StatelessWidget {
  final String groupName;
  final String? groupAvatar;
  final Color? groupColor;
  final String? groupId;
  final String? conversationId;
  final String? qrCode;

  const GroupQrScreen({
    super.key,
    required this.groupName,
    this.groupAvatar,
    this.groupColor,
    this.groupId,
    this.conversationId,
    this.qrCode,
  });

  String get _qrPayload {
    if (qrCode != null && qrCode!.trim().isNotEmpty) {
      return qrCode!.trim();
    }
    return jsonEncode({
      'type': 'group',
      'groupId': groupId ?? conversationId ?? '',
      'name': groupName,
    });
  }

  Color _parseColor(dynamic c, String? name) {
    if (c is Color) return c;
    if (c is String && c.startsWith('#')) {
      try {
        return Color(int.parse(c.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return AppAvatar.getColorForName(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final effectiveColor = groupColor ?? _parseColor(null, groupName);
    final payload = _qrPayload;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.groupQrCode,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: context.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [

                    AppAvatar(
                      avatar: groupAvatar,
                      name: groupName,
                      color: effectiveColor,
                      radius: 36.r,
                      fontSize: 24.sp,
                      enableViewer: true,
                    ),
                    SizedBox(height: 12.h),

                    Text(
                      groupName,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),

                    Text(
                      l10n.groupQrViora,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: context.textMuted,
                      ),
                    ),
                    SizedBox(height: 24.h),

                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: payload,
                        version: QrVersions.auto,
                        size: 210.r,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF1E293B),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    SizedBox(height: 22.h),

                    Text(
                      '${l10n.scanQrGroupDesc} "$groupName".',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: context.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: payload));
                        AppToast.success(context, l10n.qrCopiedToast);
                      },
                      icon: Icon(Icons.copy_rounded, size: 18.r),
                      label: Text(l10n.copyCode, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                        foregroundColor: context.textPrimary,
                        side: BorderSide(
                          color: context.isDark ? Colors.white24 : Colors.black12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AppToast.info(context, l10n.qrSavedToast);
                      },
                      icon: Icon(Icons.download_rounded, size: 18.r),
                      label: Text(l10n.saveQr, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
