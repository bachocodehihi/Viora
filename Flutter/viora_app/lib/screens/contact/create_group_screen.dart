import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/contact_service.dart';
import '../../widgets/app_avatar.dart';

class CreateGroupScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? contacts;
  final Map<String, dynamic>? preselectedContact;
  final List<String>? initialSelectedUserIds;

  const CreateGroupScreen({
    super.key,
    this.contacts,
    this.preselectedContact,
    this.initialSelectedUserIds,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedPrivacy = 'public';
  final Set<String> _selectedContactIds = {};
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = false;

  static const List<Color> _avatarColors = [
    AppColors.blue,
    AppColors.purple,
    AppColors.pink,
    AppColors.orange,
    AppColors.teal,
  ];

  Color _getColor(dynamic id, int fallbackIndex) {
    if (id is String && id.isNotEmpty) {
      return _avatarColors[id.hashCode.abs() % _avatarColors.length];
    }
    return _avatarColors[fallbackIndex % _avatarColors.length];
  }

  @override
  void initState() {
    super.initState();
    _initContacts();
  }

  void _initContacts() {
    if (widget.contacts != null && widget.contacts!.isNotEmpty) {
      _contacts = List<Map<String, dynamic>>.from(widget.contacts!);
    }

    if (widget.preselectedContact != null) {
      final pre = widget.preselectedContact!;
      final preId = pre['id']?.toString() ?? pre['name']?.toString() ?? '';
      if (preId.isNotEmpty) {
        _selectedContactIds.add(preId);
      }
      final exists = _contacts.any((c) =>
          (c['id']?.toString().isNotEmpty == true && c['id']?.toString() == preId) ||
          (c['name'] != null && c['name'] == pre['name']));
      if (!exists) {
        _contacts.insert(0, pre);
      }
    }

    if (widget.initialSelectedUserIds != null) {
      _selectedContactIds.addAll(widget.initialSelectedUserIds!);
    }

    if (_contacts.length <= 1) {
      _loadContactsFromService();
    }
  }

  Future<void> _loadContactsFromService() async {
    setState(() => _isLoading = true);
    try {
      final data = await ContactService.fetchContacts();
      if (data != null && data['friends'] is List && mounted) {
        final rawFriends = data['friends'] as List;
        final friends = rawFriends.asMap().entries.map((entry) {
          final idx = entry.key;
          final f = entry.value as Map<String, dynamic>;
          return {
            'id': f['id']?.toString() ?? '',
            'name': f['name']?.toString() ?? '',
            'avatar': f['avatar']?.toString() ?? (f['name'] != null && f['name'].toString().isNotEmpty ? f['name'][0].toUpperCase() : 'U'),
            'color': _getColor(f['id'], idx),
            'status': f['status']?.toString() ?? 'friends',
            'online': f['online'] == true,
          };
        }).toList();

        setState(() {
          if (widget.preselectedContact != null) {
            final pre = widget.preselectedContact!;
            final preId = pre['id']?.toString() ?? pre['name']?.toString() ?? '';
            final matchIdx = friends.indexWhere((c) =>
                (c['id']?.toString().isNotEmpty == true && c['id']?.toString() == preId) ||
                (c['name'] != null && c['name'] == pre['name']));
            if (matchIdx != -1) {
              final actualId = friends[matchIdx]['id']?.toString() ?? preId;
              if (preId != actualId && _selectedContactIds.contains(preId)) {
                final currentList = _selectedContactIds.toList();
                final idx = currentList.indexOf(preId);
                if (idx != -1) currentList[idx] = actualId;
                _selectedContactIds.clear();
                _selectedContactIds.addAll(currentList);
              } else {
                _selectedContactIds.add(actualId);
              }
            } else {
              friends.insert(0, pre);
            }
          }
          _contacts = friends;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('CreateGroupScreen _loadContactsFromService error: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onCreateGroup() {
    final l10n = context.l10n;
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) return;

    final newGroup = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': groupName,
      'avatar': groupName[0].toUpperCase(),
      'color': _selectedPrivacy == 'public'
          ? AppColors.blue
          : _selectedPrivacy == 'private'
              ? Colors.orangeAccent
              : Colors.purpleAccent,
      'membersCount': _selectedContactIds.length + 1,
      'memberIds': _selectedContactIds.toList(),
      'privacy': _selectedPrivacy,
      'lastMessage': l10n.createGroup,
      'time': 'just_now',
    };

    Navigator.pop(context, newGroup);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isNameValid = _groupNameController.text.trim().isNotEmpty && _selectedContactIds.isNotEmpty;

    final filteredContacts = _contacts.where((contact) {
      final name = (contact['name']?.toString() ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            l10n.createNewGroup,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: false,
          titleSpacing: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
              child: ElevatedButton(
                onPressed: isNameValid ? _onCreateGroup : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: context.actionPillBg,
                  disabledForegroundColor: context.textSubtle,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  l10n.createGroup,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.contactCardShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [

                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.blue.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: AppColors.blue,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: TextField(
                        controller: _groupNameController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.createGroupSub,
                          hintStyle: TextStyle(
                            color: context.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          fillColor: context.isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: context.isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: context.isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _buildPrivacySection(),

              if (_selectedContactIds.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                  child: Text(
                    '${l10n.members} (${_selectedContactIds.length})',
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(
                  height: 72,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _selectedContactIds.map((selectedId) {
                      final contact = _contacts.firstWhere(
                        (c) => c['id']?.toString() == selectedId,
                        orElse: () => (widget.preselectedContact != null &&
                                (widget.preselectedContact!['id']?.toString() == selectedId ||
                                    widget.preselectedContact!['name']?.toString() == selectedId))
                            ? widget.preselectedContact!
                            : <String, dynamic>{},
                      );
                      if (contact.isEmpty) return const SizedBox.shrink();

                      final name = contact['name']?.toString() ?? '';
                      final firstName = name.isNotEmpty ? name.split(' ')[0] : '';
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12, top: 4),
                            child: Column(
                              children: [
                                AppAvatar(
                                  avatar: contact['avatar'],
                                  name: name,
                                  color: contact['color'] as Color?,
                                  radius: 20,
                                  fontSize: 14,
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    firstName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: context.textMuted,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedContactIds.remove(selectedId);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppColors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: l10n.searchFriends,
                    hintStyle: TextStyle(color: context.textMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = "";
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    fillColor: context.cardBg,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: context.isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: context.isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: _isLoading && _contacts.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.blue),
                      )
                    : filteredContacts.isEmpty
                        ? Center(
                            child: Text(
                              l10n.noFriendsFound,
                              style: TextStyle(color: context.textMuted),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: filteredContacts.length,
                            itemBuilder: (context, index) {
                              final contact = filteredContacts[index];
                              final id = contact['id']?.toString() ?? '';
                              final isSelected = _selectedContactIds.contains(id);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: context.cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedContactIds.remove(id);
                                      } else {
                                        _selectedContactIds.add(id);
                                      }
                                    });
                                  },
                                  leading: AppAvatar(
                                    avatar: contact['avatar'],
                                    name: contact['name']?.toString() ?? 'U',
                                    color: contact['color'] as Color?,
                                    radius: 20,
                                    fontSize: 14,
                                  ),
                                  title: Text(
                                    contact['name']?.toString() ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    (contact['status'] == null || contact['status'] == 'friends' || contact['status'] == '')
                                        ? l10n.friends
                                        : contact['status'].toString(),
                                    style: TextStyle(color: context.textMuted, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.red
                                          : context.actionPillBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.remove_rounded : Icons.add_rounded,
                                      color: isSelected ? Colors.white : context.textPrimary.withValues(alpha: 0.7),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, size: 16, color: AppColors.blue),
              const SizedBox(width: 6),
              Text(
                l10n.groupPrivacyTitle,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildPrivacyOption(
                  id: 'public',
                  title: l10n.public,
                  icon: Icons.public_rounded,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPrivacyOption(
                  id: 'private',
                  title: l10n.privateAccount,
                  icon: Icons.lock_outline_rounded,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPrivacyOption(
                  id: 'secret',
                  title: l10n.groupInternalSecret,
                  icon: Icons.visibility_off_outlined,
                  color: Colors.purpleAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: (_selectedPrivacy == 'public'
                      ? AppColors.blue
                      : _selectedPrivacy == 'private'
                          ? Colors.orangeAccent
                          : Colors.purpleAccent)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: _selectedPrivacy == 'public'
                      ? AppColors.blue
                      : _selectedPrivacy == 'private'
                          ? Colors.orangeAccent
                          : Colors.purpleAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedPrivacy == 'public'
                        ? l10n.groupPublicDesc
                        : _selectedPrivacy == 'private'
                            ? l10n.groupPrivateApprovalDesc
                            : l10n.groupSecretOnlyInviteDesc,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textMuted,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption({
    required String id,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedPrivacy == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPrivacy = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : context.actionPillBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? color : context.textMuted),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : context.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

