import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/app_colors.dart';
import '../../services/livestream_service.dart';
import '../../services/contact_service.dart';
import '../../screens/live/livestream_broadcaster_screen.dart';
import '../../l10n/language.dart';

class AppLivestreamSetupBottomSheet extends StatefulWidget {
  final String? userAvatar;
  final String? userName;
  final String? groupId;
  final String? groupName;

  const AppLivestreamSetupBottomSheet({
    super.key,
    this.userAvatar,
    this.userName,
    this.groupId,
    this.groupName,
  });

  static Future<void> show(
    BuildContext context, {
    String? userAvatar,
    String? userName,
    String? groupId,
    String? groupName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppLivestreamSetupBottomSheet(
        userAvatar: userAvatar,
        userName: userName,
        groupId: groupId,
        groupName: groupName,
      ),
    );
  }

  @override
  State<AppLivestreamSetupBottomSheet> createState() => _AppLivestreamSetupBottomSheetState();
}

class _AppLivestreamSetupBottomSheetState extends State<AppLivestreamSetupBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  String _selectedMode = 'camera';
  String _privacy = 'public'; // 'public', 'friends', 'custom', 'group'
  List<String> _allowedViewers = [];
  List<Map<String, dynamic>> _selectedFriendsList = [];
  bool _isCreating = false;

  bool get _isGroupLive => widget.groupId != null && widget.groupId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isGroupLive) {
      _privacy = 'group';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startLive() async {
    final isEn = LanguageManager.isEnglish();
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : context.l10n.liveStreamTitleDefault;

    if (!_isGroupLive && _privacy == 'custom' && _allowedViewers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Please select at least one friend' : 'Vui lòng chọn ít nhất một người bạn được xem'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_selectedMode == 'camera') {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.cameraAndMicPermissionRequired),
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
            content: Text(context.l10n.micPermissionRequired),
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
      privacy: _isGroupLive ? 'group' : _privacy,
      groupId: widget.groupId,
      allowedViewers: (!_isGroupLive && _privacy == 'custom') ? _allowedViewers : null,
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
          content: Text(context.l10n.cannotInitLiveStream),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showPrivacyPicker() {
    if (_isGroupLive) return;

    final isEn = LanguageManager.isEnglish();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEn ? 'Who can watch this live stream?' : 'Ai có thể xem buổi trực tiếp?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildPrivacyOption(
                    title: isEn ? 'Public' : 'Công khai',
                    subtitle: isEn ? 'Anyone on Viora can watch' : 'Bất kỳ ai trên Viora cũng có thể xem',
                    icon: Icons.public_rounded,
                    isSelected: _privacy == 'public',
                    onTap: () {
                      setState(() => _privacy = 'public');
                      Navigator.pop(ctx);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),

                  _buildPrivacyOption(
                    title: isEn ? 'Friends only' : 'Chỉ bạn bè',
                    subtitle: isEn ? 'Only your friends can watch' : 'Chỉ những người là bạn bè của bạn mới xem được',
                    icon: Icons.people_alt_rounded,
                    isSelected: _privacy == 'friends',
                    onTap: () {
                      setState(() => _privacy = 'friends');
                      Navigator.pop(ctx);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),

                  _buildPrivacyOption(
                    title: isEn ? 'Specific friends' : 'Chỉ định người xem',
                    subtitle: _allowedViewers.isEmpty
                        ? (isEn ? 'Only selected friends can watch' : 'Chỉ những người bạn được chọn mới xem được')
                        : (isEn ? '${_allowedViewers.length} friends selected' : '${_allowedViewers.length} người bạn đã được chọn'),
                    icon: Icons.person_pin_circle_rounded,
                    isSelected: _privacy == 'custom',
                    trailing: _privacy == 'custom'
                        ? TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openFriendPicker();
                            },
                            child: Text(isEn ? 'Change' : 'Thay đổi', style: const TextStyle(color: AppColors.blue)),
                          )
                        : null,
                    onTap: () {
                      setState(() => _privacy = 'custom');
                      Navigator.pop(ctx);
                      if (_allowedViewers.isEmpty) {
                        _openFriendPicker();
                      }
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrivacyOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white10 : const Color(0xFFF1F5F9))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.blue : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.blue.withValues(alpha: 0.15) : (isDark ? Colors.white10 : Colors.black12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: isSelected ? AppColors.blue : (isDark ? Colors.white70 : Colors.black54)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (isSelected && trailing == null)
              const Icon(Icons.check_circle_rounded, color: AppColors.blue, size: 22),
          ],
        ),
      ),
    );
  }

  void _openFriendPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _FriendPickerModal(
          initialSelected: List<String>.from(_allowedViewers),
          isDark: isDark,
          bgColor: bgColor,
          textColor: textColor,
          onConfirmed: (selectedIds, selectedObjs) {
            setState(() {
              _allowedViewers = selectedIds;
              _selectedFriendsList = selectedObjs;
              _privacy = 'custom';
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEn = LanguageManager.isEnglish();
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
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sensors_rounded, color: Colors.redAccent, size: 22),
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
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.black45),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Profile info & scope / privacy chip
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isDark ? Colors.white12 : Colors.grey[300],
                  backgroundImage: widget.userAvatar != null && widget.userAvatar!.isNotEmpty
                      ? NetworkImage(widget.userAvatar!)
                      : null,
                  child: widget.userAvatar == null || widget.userAvatar!.isEmpty
                      ? Icon(Icons.person, color: isDark ? Colors.white70 : Colors.black54, size: 22)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName ?? (isEn ? 'You' : 'Bạn'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (_isGroupLive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.groups_rounded, size: 14, color: AppColors.blue),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  widget.groupName ?? (isEn ? 'Group' : 'Nhóm'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.blue,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        InkWell(
                          onTap: _showPrivacyPicker,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _privacy == 'public'
                                      ? Icons.public_rounded
                                      : (_privacy == 'friends'
                                          ? Icons.people_alt_rounded
                                          : Icons.person_pin_circle_rounded),
                                  size: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _privacy == 'public'
                                      ? (isEn ? 'Public' : 'Công khai')
                                      : (_privacy == 'friends'
                                          ? (isEn ? 'Friends only' : 'Bạn bè')
                                          : (isEn ? 'Specific (${_allowedViewers.length})' : 'Chỉ định (${_allowedViewers.length})')),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 16,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isGroupLive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: isDark ? Colors.white38 : Colors.black45),
                  const SizedBox(width: 6),
                  Text(
                    isEn
                        ? 'Only group members can watch this live stream'
                        : 'Chỉ thành viên trong nhóm mới có thể xem buổi trực tiếp này',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),

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
                prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.blue),
              ),
              style: TextStyle(color: textColor, fontSize: 14.5),
            ),
            const SizedBox(height: 20),

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
            const SizedBox(height: 24),

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

class _FriendPickerModal extends StatefulWidget {
  final List<String> initialSelected;
  final bool isDark;
  final Color bgColor;
  final Color textColor;
  final void Function(List<String> ids, List<Map<String, dynamic>> objects) onConfirmed;

  const _FriendPickerModal({
    required this.initialSelected,
    required this.isDark,
    required this.bgColor,
    required this.textColor,
    required this.onConfirmed,
  });

  @override
  State<_FriendPickerModal> createState() => _FriendPickerModalState();
}

class _FriendPickerModalState extends State<_FriendPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allFriends = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelected);
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final isEn = LanguageManager.isEnglish();
    try {
      final data = await ContactService.fetchContacts();
      if (data != null && data['friends'] is List) {
        final raw = data['friends'] as List;
        final list = raw.map((f) {
          final id = f['id']?.toString() ?? f['_id']?.toString() ?? '';
          final name = f['name']?.toString() ?? f['username']?.toString() ?? (isEn ? 'User' : 'Người dùng');
          final avatar = f['avatar']?.toString() ?? '';
          return {
            'id': id,
            'name': name,
            'avatar': avatar,
          };
        }).where((f) => (f['id'] as String).isNotEmpty).toList();

        if (mounted) {
          setState(() {
            _allFriends = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LanguageManager.isEnglish();
    final filtered = _allFriends.where((f) {
      if (_keyword.isEmpty) return true;
      final name = (f['name'] as String).toLowerCase();
      return name.contains(_keyword.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                isEn ? 'Select friends to watch' : 'Chọn bạn bè được xem',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor,
                ),
              ),
              const Spacer(),
              Text(
                isEn ? 'Selected: ${_selectedIds.length}' : 'Đã chọn: ${_selectedIds.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _keyword = val.trim()),
            decoration: InputDecoration(
              hintText: isEn ? 'Search friends...' : 'Tìm kiếm bạn bè...',
              hintStyle: TextStyle(
                color: widget.isDark ? Colors.white38 : Colors.black38,
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.search_rounded, color: widget.isDark ? Colors.white54 : Colors.black45),
              filled: true,
              fillColor: widget.isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            style: TextStyle(color: widget.textColor, fontSize: 14),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _allFriends.isEmpty
                              ? (isEn ? 'No friends found' : 'Không có bạn bè nào')
                              : (isEn ? 'No matching results found' : 'Không tìm thấy kết quả phù hợp'),
                          style: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black38),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final f = filtered[idx];
                          final id = f['id'] as String;
                          final name = f['name'] as String;
                          final avatar = f['avatar'] as String;
                          final isChecked = _selectedIds.contains(id);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isChecked) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: widget.isDark ? Colors.white12 : Colors.grey[300],
                                    backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                    child: avatar.isEmpty
                                        ? Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: widget.textColor,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        color: widget.textColor,
                                      ),
                                    ),
                                  ),
                                  Checkbox(
                                    value: isChecked,
                                    activeColor: AppColors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedIds.add(id);
                                        } else {
                                          _selectedIds.remove(id);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final selectedList = _allFriends
                    .where((f) => _selectedIds.contains(f['id']))
                    .toList();
                widget.onConfirmed(_selectedIds.toList(), selectedList);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isEn ? 'Confirm (${_selectedIds.length})' : 'Xác nhận (${_selectedIds.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
