import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/app_colors.dart';
import '../../services/livestream_service.dart';
import '../../screens/live/livestream_broadcaster_screen.dart';
import '../../l10n/language.dart';
class AppLivestreamSetupBottomSheet extends StatefulWidget {
  final String? userAvatar;
  final String? userName;

  const AppLivestreamSetupBottomSheet({
    super.key,
    this.userAvatar,
    this.userName,
  });

  static Future<void> show(
    BuildContext context, {
    String? userAvatar,
    String? userName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppLivestreamSetupBottomSheet(
        userAvatar: userAvatar,
        userName: userName,
      ),
    );
  }

  @override
  State<AppLivestreamSetupBottomSheet> createState() => _AppLivestreamSetupBottomSheetState();
}

class _AppLivestreamSetupBottomSheetState extends State<AppLivestreamSetupBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  String _selectedMode = 'camera';
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startLive() async {
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : l10n.liveStreamTitleDefault;

    if (_selectedMode == 'camera') {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.cameraAndMicPermissionRequired),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } else {

      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.micPermissionRequired),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _isCreating = true);

    final res = await LivestreamService.createLive(
      title: title,
      mode: _selectedMode,
    );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (res != null && res['success'] == true) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LivestreamBroadcasterScreen(
            liveData: res,
            initialMode: _selectedMode,
            hostName: widget.userName,
            hostAvatar: widget.userAvatar,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cannotInitLiveStream),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Colors.redAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.liveStreamTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: l10n.enterLiveTitleHint,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.edit_note_rounded, color: AppColors.blue),
              ),
              style: TextStyle(color: textColor, fontSize: 14.5),
            ),
            const SizedBox(height: 22),

            Text(
              l10n.chooseLiveMode,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [

                Expanded(
                  child: _buildModeCard(
                    id: 'camera',
                    title: l10n.cameraModeTitle,
                    subtitle: l10n.cameraModeSubtitle,
                    icon: Icons.camera_alt_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: _buildModeCard(
                    id: 'screen',
                    title: l10n.screenModeTitle,
                    subtitle: l10n.screenModeSubtitle,
                    icon: Icons.phone_android_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _startLive,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.redAccent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sensors_rounded, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            l10n.startLiveStream,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedMode == id;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedMode = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.redAccent.withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? Colors.redAccent : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.redAccent
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.redAccent : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
