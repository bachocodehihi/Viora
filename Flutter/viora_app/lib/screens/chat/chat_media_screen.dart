import '../../l10n/language.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/message_service.dart';
import '../../widgets/toast/app_toast.dart';
import '../post/post_image_viewer_screen.dart';

class ChatMediaScreen extends StatefulWidget {
  final String conversationName;
  final String? conversationAvatar;
  final Color? conversationColor;
  final String? conversationId;
  final List<Map<String, dynamic>> initialMessages;

  const ChatMediaScreen({
    super.key,
    required this.conversationName,
    this.conversationAvatar,
    this.conversationColor,
    this.conversationId,
    this.initialMessages = const [],
  });

  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen> {
  Language get l10n => context.l10n;
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  late List<Map<String, dynamic>> _allMessages;

  final List<Map<String, dynamic>> _imageItems = [];
  final List<Map<String, dynamic>> _fileItems = [];
  final List<Map<String, dynamic>> _linkItems = [];

  final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+|www\.[^\s]+)',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _allMessages = List.from(widget.initialMessages);
    _extractMediaAndLinks();
    _fetchFullMessages();
  }

  Future<void> _fetchFullMessages() async {
    final convId = widget.conversationId;
    if (convId == null || convId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final res = await MessageService.loadMessages(conversationId: convId);
      if (res != null && res['data'] != null && res['data']['messages'] is List) {
        final List<dynamic> serverMsgs = res['data']['messages'];
        if (mounted) {
          setState(() {
            _allMessages = serverMsgs
                .map((m) => Map<String, dynamic>.from(m as Map))
                .toList();
            _extractMediaAndLinks();
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _extractMediaAndLinks() {
    _imageItems.clear();
    _fileItems.clear();
    _linkItems.clear();

    for (final m in _allMessages) {
      if (m['isRecalled'] == true) continue;

      final type = m['type']?.toString() ?? 'text';
      final senderName = (m['senderName'] ?? (m['isMe'] == true ? l10n.you : widget.conversationName)).toString();
      final timeStr = (m['time'] ?? '').toString();
      final textContent = (m['text'] ?? m['content'] ?? '').toString();

      final attachments = m['attachments'];
      if (attachments is List && attachments.isNotEmpty) {
        for (final att in attachments) {
          final url = att.toString().trim();
          if (url.isNotEmpty) {
            final isImg = _isImageUrl(url);
            final item = {
              'url': url,
              'caption': textContent,
              'senderName': senderName,
              'time': timeStr,
              'createdAt': m['createdAt'],
              'type': type,
            };
            if (isImg) {
              _imageItems.add(item);
            } else {
              _fileItems.add(item);
            }
          }
        }
      } else if (m['imageUrl'] != null && m['imageUrl'].toString().isNotEmpty) {
        final url = m['imageUrl'].toString().trim();
        _imageItems.add({
          'url': url,
          'caption': textContent,
          'senderName': senderName,
          'time': timeStr,
          'createdAt': m['createdAt'],
          'type': type,
        });
      } else if (type == 'image' && (textContent.startsWith('http://') || textContent.startsWith('https://') || textContent.startsWith('/'))) {
        _imageItems.add({
          'url': textContent,
          'caption': '',
          'senderName': senderName,
          'time': timeStr,
          'createdAt': m['createdAt'],
          'type': type,
        });
      } else if (type == 'file' || type == 'document') {
        if (textContent.isNotEmpty) {
          _fileItems.add({
            'url': textContent,
            'caption': textContent,
            'senderName': senderName,
            'time': timeStr,
            'createdAt': m['createdAt'],
            'type': type,
          });
        }
      }

      if (textContent.isNotEmpty) {
        final matches = _urlRegex.allMatches(textContent);
        for (final match in matches) {
          final rawUrl = match.group(0)!;
          final cleanUrl = rawUrl.replaceAll(RegExp(r'[.,;!?\)]+$'), '');
          final domain = _extractDomain(cleanUrl);

          _linkItems.add({
            'url': cleanUrl,
            'domain': domain,
            'caption': textContent,
            'senderName': senderName,
            'time': timeStr,
            'createdAt': m['createdAt'],
          });
        }
      }
    }
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('res.cloudinary.com') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp')) {
      return true;
    }
    return !lower.endsWith('.pdf') &&
        !lower.endsWith('.docx') &&
        !lower.endsWith('.doc') &&
        !lower.endsWith('.xls') &&
        !lower.endsWith('.xlsx') &&
        !lower.endsWith('.zip') &&
        !lower.endsWith('.rar') &&
        !lower.endsWith('.apk') &&
        !lower.endsWith('.txt');
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
      if (uri != null && uri.host.isNotEmpty) {
        return uri.host.replaceFirst(RegExp(r'^www\.'), '');
      }
    } catch (_) {}
    return url;
  }

  Future<void> _openLink(String rawUrl) async {
    String url = rawUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          AppToast.error(context, l10n.cannotOpenLink);
        }
      } catch (_) {
        if (mounted) AppToast.error(context, l10n.cannotOpenLink);
      }
    }
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    AppToast.success(context, l10n.linkCopiedToast);
  }

  void _openImageViewer(int index) {
    if (_imageItems.isEmpty) return;

    final List<String> imageUrls = _imageItems.map((i) => i['url'] as String).toList();
    final clampedIndex = index.clamp(0, imageUrls.length - 1);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostImageViewerScreen(
          images: imageUrls,
          initialIndex: clampedIndex,
          authorName: widget.conversationName,
          authorAvatar: widget.conversationAvatar,
          postTime: _imageItems[clampedIndex]['time'] as String?,
          postContent: _imageItems[clampedIndex]['caption'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          l10n.mediaAndLinks,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildCapsuleTabBar(),
          Expanded(
            child: _isLoading && _imageItems.isEmpty && _fileItems.isEmpty && _linkItems.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildCurrentTab(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildImagesTab();
      case 1:
        return _buildFilesTab();
      case 2:
      default:
        return _buildLinksTab();
    }
  }

  Widget _buildCapsuleTabBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 12.h),
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF16181F) : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(index: 0, title: l10n.photos),
          _buildTabItem(index: 1, title: 'File'),
          _buildTabItem(index: 2, title: 'Link'),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String title,
  }) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTabIndex != index) {
            setState(() {
              _selectedTabIndex = index;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : context.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagesTab() {
    if (_imageItems.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72.r,
                height: 72.r,
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 36.r,
                  color: context.textMuted,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                l10n.noPhotosYet,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                l10n.noMediaDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4.w,
        mainAxisSpacing: 4.h,
        childAspectRatio: 1.0,
      ),
      itemCount: _imageItems.length,
      itemBuilder: (context, index) {
        final item = _imageItems[index];
        final url = item['url'] as String;
        final isLocal = !url.startsWith('http://') && !url.startsWith('https://');

        return GestureDetector(
          onTap: () => _openImageViewer(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              color: context.isDark ? const Color(0xFF22242D) : const Color(0xFFE9ECEF),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  isLocal
                      ? Image.file(
                          File(url),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildImageError(),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 20.r,
                                height: 20.r,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => _buildImageError(),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesTab() {
    if (_fileItems.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72.r,
                height: 72.r,
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  size: 36.r,
                  color: context.textMuted,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                l10n.noFilesYet,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                l10n.noFilesDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: _fileItems.length,
      itemBuilder: (context, index) {
        final file = _fileItems[index];
        final url = file['url'] as String;
        final fileName = url.split('/').last.split('?').first;

        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42.r,
                height: 42.r,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.insert_drive_file_rounded,
                  color: Colors.orange,
                  size: 24.r,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName.isNotEmpty ? fileName : l10n.attachedDoc,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${file['senderName']} • ${file['time']}',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download_rounded),
                color: AppColors.blue,
                onPressed: () => _openLink(url),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinksTab() {
    if (_linkItems.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72.r,
                height: 72.r,
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.link_rounded,
                  size: 36.r,
                  color: context.textMuted,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                l10n.noLinksYet,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                l10n.noLinksDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: _linkItems.length,
      itemBuilder: (context, index) {
        final link = _linkItems[index];
        final url = link['url'] as String;
        final domain = link['domain'] as String;
        final senderName = link['senderName'] as String;
        final time = link['time'] as String;

        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: InkWell(
            onTap: () => _openLink(url),
            borderRadius: BorderRadius.circular(14.r),
            child: Padding(
              padding: EdgeInsets.all(12.r),
              child: Row(
                children: [
                  Container(
                    width: 44.r,
                    height: 44.r,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.language_rounded,
                      color: AppColors.blue,
                      size: 24.r,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          domain,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          url,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.blue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '$senderName • $time',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: context.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 18.r),
                    color: context.textMuted,
                    onPressed: () => _copyLink(url),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageError() {
    return Center(
      child: Icon(
        Icons.broken_image_rounded,
        size: 24.r,
        color: context.textMuted,
      ),
    );
  }
}
