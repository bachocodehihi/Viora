import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/profile_service.dart';
import '../../widgets/toast/app_toast.dart';

class EditRelationshipScreen extends StatefulWidget {
  final String? initialStatus;

  const EditRelationshipScreen({super.key, this.initialStatus});

  @override
  State<EditRelationshipScreen> createState() => _EditRelationshipScreenState();
}

class _EditRelationshipScreenState extends State<EditRelationshipScreen> {
  String? _selectedStatus;
  bool _isSaving = false;

  final List<String> _statusKeys = const [
    'single',
    'dating',
    'engaged',
    'married',
    'complicated',
    'exploring',
  ];

  String _getStatusLabel(BuildContext context, String key) {
    switch (key.toLowerCase()) {
      case 'single':
        return l10n.singleStatus;
      case 'dating':
        return l10n.datingStatus;
      case 'engaged':
        return l10n.engagedStatus;
      case 'married':
        return l10n.marriedStatus;
      case 'complicated':
        return l10n.complicatedStatus;
      case 'exploring':
        return l10n.exploringStatus;
      default:
        return key;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ProfileService.updateSingleField(fieldKey: 'relationship', value: _selectedStatus);
      if (mounted) {
        AppToast.success(context, l10n.updateRelationshipSuccess);
        Navigator.pop(context, _selectedStatus);
      }
    } catch (_) {
      if (mounted) Navigator.pop(context, _selectedStatus);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20.r),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.relationship, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 20.sp)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            children: [
              ..._statusKeys.map((key) {
                final isSelected = _selectedStatus == key;
                return Container(
                  margin: EdgeInsets.only(bottom: 10.h),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.blue.withValues(alpha: 0.1) : context.cardBg,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: isSelected ? AppColors.blue : context.borderTheme.withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    title: Text(_getStatusLabel(context, key), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: context.textPrimary)),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.blue) : null,
                    onTap: () => setState(() => _selectedStatus = key),
                  ),
                );
              }),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          l10n.saveRelationship,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}
