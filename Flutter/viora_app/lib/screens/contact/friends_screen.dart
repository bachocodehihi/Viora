import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../chat/chat_detail_screen.dart';
import 'contact_screen.dart';
import '../../widgets/app_avatar.dart';

class FriendsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> contacts;
  final String searchQuery;

  const FriendsScreen({
    super.key,
    required this.contacts,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filteredContacts = contacts.where((contact) {
      final name = contact['name'].toString().toLowerCase();
      final status = contact['status'].toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      return name.contains(query) || status.contains(query);
    }).toList();

    if (filteredContacts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 80, bottom: 110),
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_search_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  l10n.noFriendsFound,
                  style: TextStyle(color: context.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final Map<String, List<Map<String, dynamic>>> groupedContacts = {};
    for (var contact in filteredContacts) {
      final name = (contact['name'] ?? '').toString();
      final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '#';
      if (!groupedContacts.containsKey(firstLetter)) {
        groupedContacts[firstLetter] = [];
      }
      groupedContacts[firstLetter]!.add(contact);
    }
    final sortedKeys = groupedContacts.keys.toList()..sort();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 0.0, bottom: 110.0),
      itemCount: sortedKeys.length,
      itemBuilder: (context, sectionIndex) {
        final key = sortedKeys[sectionIndex];
        final sectionContacts = groupedContacts[key]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 6.0, bottom: 6.0),
              child: Text(
                key,
                style: const TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ...sectionContacts.map((contact) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.contactCardShadow,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.profileAccount,
                      arguments: {
                        'id': contact['id']?.toString(),
                        'email': contact['email'],
                        'name': contact['name'],
                        'avatar': contact['avatar'],
                        'color': contact['color'],
                        'status': contact['status'],
                        'isFriend': true,
                      },
                    );
                    ContactScreen.triggerRefresh();
                  },
                  leading: AppAvatar(
                    avatar: contact['avatar'],
                    name: contact['name'],
                    color: contact['color'] as Color? ?? AppColors.blue,
                    radius: 22,
                    fontSize: 14,
                    isOnline: contact['showActiveStatus'] == false
                        ? null
                        : (contact['online'] == true),
                    enableViewer: true,
                  ),
                  title: Text(
                    contact['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    contact['status'] ?? '',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.blue, size: 20),
                        onPressed: () {
                          final bool showActive = contact['showActiveStatus'] != false;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                name: contact['name'] ?? '',
                                avatar: contact['avatar'] ?? '',
                                color: contact['color'] as Color? ?? AppColors.blue,
                                receiverId: contact['id']?.toString(),
                                isFriend: true,
                                showActiveStatus: showActive,
                                isOnline: showActive && (contact['online'] == true),
                                initialMessages: List<Map<String, dynamic>>.from(contact['messages'] ?? []),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.phone_outlined, color: context.textMuted, size: 20),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
