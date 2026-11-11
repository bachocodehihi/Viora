import 'package:flutter/material.dart';
import '../../config/theme_helper.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../l10n/language.dart';
import 'package:provider/provider.dart';
import '../../providers/signup_provider.dart';
import '../../widgets/dialog/birthday_dialog.dart';

class SetupBirthdayScreen extends StatefulWidget {
  final String email;
  const SetupBirthdayScreen({
    super.key,
    required this.email,
  });

  @override
  State<SetupBirthdayScreen> createState() => _SetupBirthdayScreenState();
}

class _SetupBirthdayScreenState extends State<SetupBirthdayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _birthdayController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final savedDate = context.read<SignUpProvider>().birthday;
    if (savedDate != null) {
      _selectedDate = savedDate;
      _birthdayController.text =
          '${savedDate.day.toString().padLeft(2, '0')} - ${savedDate.month.toString().padLeft(2, '0')} - ${savedDate.year}';
    }
  }

  @override
  void dispose() {
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final today = DateTime.now();
    final DateTime initialDate = _selectedDate ?? DateTime(today.year - 14, today.month, today.day);
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return BirthdayDialog(
          initialDate: initialDate,
          onConfirm: (DateTime picked) {
            setState(() {
              _selectedDate = picked;
              _birthdayController.text =
                  '${picked.day.toString().padLeft(2, '0')} - ${picked.month.toString().padLeft(2, '0')} - ${picked.year}';
            });
          },
        );
      },
    );
  }

  String? _birthdayError;

  void _submit() {
    final l10n = context.l10n;
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) return;

      final DateTime today = DateTime.now();
      int age = today.year - _selectedDate!.year;
      if (today.month < _selectedDate!.month ||
          (today.month == _selectedDate!.month && today.day < _selectedDate!.day)) {
        age--;
      }

      if (age < 14) {
        setState(() {
          _birthdayError = l10n.errorUnderage;
        });
        return;
      }

      context.read<SignUpProvider>().setBirthday(_selectedDate!);

      Navigator.pushNamed(
        context,
        AppRoutes.setupGender,
        arguments: widget.email,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20.r),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 24.w,
                        right: 24.w,
                        top: 12.h,
                        bottom: 24.h,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                padding: EdgeInsets.all(24.r),
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.cake_outlined,
                                  size: 72.r,
                                  color: AppColors.blue,
                                ),
                              ),
                            ),
                            SizedBox(height: 28.h),
                            Text(
                              l10n.birthday,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              l10n.setupBirthdayDescription,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: context.textMuted,
                              ),
                            ),
                            SizedBox(height: 32.h),
                            Text(
                              l10n.birthday,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            TextFormField(
                              controller: _birthdayController,
                              readOnly: true,
                              onTap: () {
                                if (_birthdayError != null) {
                                  setState(() {
                                    _birthdayError = null;
                                  });
                                }
                                _selectDate(context);
                              },
                              decoration: InputDecoration(
                                hintText: l10n.selectBirthday,
                                errorText: _birthdayError,
                                prefixIcon: Icon(Icons.calendar_today_outlined, size: 22.r),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return l10n.pleaseSelectBirthday;
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 32.h),
                            ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                minimumSize: Size.fromHeight(56.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                              ),
                              child: Text(
                                l10n.continuee,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

