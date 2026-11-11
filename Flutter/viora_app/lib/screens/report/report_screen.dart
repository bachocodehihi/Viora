import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/profile_service.dart';
import '../../widgets/toast/app_toast.dart';
import '../../l10n/language.dart';

class ReportScreen extends StatefulWidget {
  final String targetUserId;
  final String targetName;

  const ReportScreen({
    super.key,
    required this.targetUserId,
    required this.targetName,
  });

  static Future<void> showReportModal(
    BuildContext context, {
    required String targetUserId,
    required String targetName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportScreen(
        targetUserId: targetUserId,
        targetName: targetName,
      ),
    );
  }

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController _detailsController = TextEditingController();
  int _selectedReasonIndex = 0;
  bool _isSubmitting = false;

  List<String> _getReasons(Language l10n) => [
    l10n.reportFakeAccount,
    l10n.reportHarassment,
    l10n.reportSpam,
    l10n.reportViolence,
    l10n.reportInappropriate,
    l10n.reportOther,
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final l10n = context.l10n;
    final reasons = _getReasons(l10n);
    final reason = reasons[_selectedReasonIndex];
    final details = _detailsController.text.trim();

    setState(() => _isSubmitting = true);

    final success = await ProfileService.reportAccount(
      widget.targetUserId,
      reason,
      details,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        AppToast.success(
          context,
          '${l10n.report} ${widget.targetName}. ${l10n.reportSubmittedToast}',
        );
      } else {
        AppToast.error(
          context,
          l10n.reportFailedToast,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reasons = _getReasons(l10n);

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: context.textSubtle.withValues(alpha: 0.3),
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
                    color: AppColors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag_rounded, color: AppColors.red, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.report} ${widget.targetName}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l10n.reportSelectReason,
                        style: TextStyle(fontSize: 12, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.reportReasonTitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(reasons.length, (index) {
              final isSelected = _selectedReasonIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedReasonIndex = index),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.red.withValues(alpha: 0.08)
                        : context.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.red : context.borderTheme,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          reasons[index],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.red : context.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: AppColors.red, size: 20)
                      else
                        Icon(Icons.radio_button_unchecked_rounded, color: context.textSubtle, size: 20),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Text(
              l10n.reportAdditionalInfo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              style: TextStyle(fontSize: 13.5, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: l10n.reportDetailsHint,
                hintStyle: TextStyle(fontSize: 13, color: context.textSubtle),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.borderTheme),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.borderTheme),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        l10n.submitReport,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
