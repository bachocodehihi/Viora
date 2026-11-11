import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import 'edit_name_screen.dart';
import 'edit_introduction_screen.dart';
import 'edit_phone_screen.dart';
import 'edit_address_screen.dart';
import 'edit_job_screen.dart';
import 'edit_nationality_screen.dart';
import 'edit_gender_screen.dart';
import 'edit_birthday_screen.dart';
import 'edit_hobby_screen.dart';
import 'edit_places_lived_screen.dart';
import 'edit_hometown_screen.dart';

class EditScreen extends StatefulWidget {
  final String? username;
  final String? bio;
  final String? gender;
  final String? birthday;
  final String? phone;
  final String? address;
  final String? homeTown;
  final String? job;
  final String? nationality;
  final String? hobby;
  final String? avatar;
  final String? coverImage;
  final List<dynamic>? placesLived;

  const EditScreen({
    super.key,
    this.username,
    this.bio,
    this.gender,
    this.birthday,
    this.phone,
    this.address,
    this.homeTown,
    this.job,
    this.nationality,
    this.hobby,
    this.avatar,
    this.coverImage,
    this.placesLived,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _homeTownController;
  late final TextEditingController _jobController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _hobbyController;

  String? _gender;
  DateTime? _birthday;
  String? _avatarUrl;
  String? _coverUrl;
  File? _avatarFile;
  File? _coverFile;
  List<Map<String, dynamic>> _placesLived = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.username ?? '');
    _bioController = TextEditingController(text: widget.bio ?? '');
    _phoneController = TextEditingController(text: widget.phone ?? '');
    _addressController = TextEditingController(text: widget.address ?? '');
    _homeTownController = TextEditingController(text: widget.homeTown ?? '');
    _jobController = TextEditingController(text: widget.job ?? '');
    _nationalityController = TextEditingController(text: widget.nationality ?? '');
    _hobbyController = TextEditingController(text: widget.hobby ?? '');
    _avatarUrl = widget.avatar;
    _coverUrl = widget.coverImage;

    if (widget.placesLived != null) {
      for (final p in widget.placesLived!) {
        if (p is Map) {
          _placesLived.add(Map<String, dynamic>.from(p));
        }
      }
    }

    if (widget.gender != null && widget.gender!.isNotEmpty) {
      final g = widget.gender!.toLowerCase().trim();
      if (g == 'male' || g == 'female' || g == 'other') {
        _gender = g;
      }
    }

    if (widget.birthday != null && widget.birthday!.isNotEmpty) {
      try {
        _birthday = DateTime.parse(widget.birthday!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _homeTownController.dispose();
    _jobController.dispose();
    _nationalityController.dispose();
    _hobbyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isAvatar}) async {
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: context.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  isAvatar ? l10n.chooseAvatar : l10n.chooseCoverPhoto,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.blue),
                  title: Text(l10n.chooseFromGallery, style: TextStyle(color: context.textPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (picked != null) {
                      setState(() {
                        if (isAvatar) {
                          _avatarFile = File(picked.path);
                        } else {
                          _coverFile = File(picked.path);
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.blue),
                  title: Text(l10n.takePhoto, style: TextStyle(color: context.textPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                    if (picked != null) {
                      setState(() {
                        if (isAvatar) {
                          _avatarFile = File(picked.path);
                        } else {
                          _coverFile = File(picked.path);
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editGender() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditGenderScreen(initialGender: _gender),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _gender = result;
      });
    }
  }

  Future<void> _editBirthday() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<DateTime?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditBirthdayScreen(initialBirthday: _birthday),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _birthday = result;
      });
    }
  }

  Future<void> _editHobby() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditHobbyScreen(initialHobby: _hobbyController.text),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _hobbyController.text = result;
      });
    }
  }

  Future<void> _editName() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditNameScreen(initialName: _nameController.text),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _nameController.text = result;
      });
    }
  }

  Future<void> _editBio() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditIntroductionScreen(initialBio: _bioController.text),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _bioController.text = result;
      });
    }
  }

  Future<void> _editPhone() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPhoneScreen(initialPhone: _phoneController.text),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _phoneController.text = result;
      });
    }
  }

  Future<void> _editAddress() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditAddressScreen(
          initialAddress: _addressController.text,
          initialNationality: _nationalityController.text,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (result is Map) {
          if (result['address'] != null) {
            _addressController.text = result['address'].toString();
          }
          if (result['nationality'] != null &&
              result['nationality'].toString().trim().isNotEmpty) {
            _nationalityController.text = result['nationality'].toString();
          }
        } else if (result is String) {
          _addressController.text = result;
        }
      });
    }
  }

  Future<void> _editHomeTown() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditHomeTownScreen(
          initialHomeTown: _homeTownController.text,
          initialNationality: _nationalityController.text,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _homeTownController.text = result;
      });
    }
  }

  Future<void> _editJob() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditJobScreen(initialJob: _jobController.text),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _jobController.text = result;
      });
    }
  }

  Future<void> _editNationality() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditNationalityScreen(initialNationality: _nationalityController.text),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _nationalityController.text = result;
      });
    }
  }

  String get _placesLivedSummary {
    if (_placesLived.isEmpty) return '';
    if (_placesLived.length == 1) {
      return _placesLived.first['address']?.toString() ?? '';
    }
    final first = _placesLived.first['address']?.toString() ?? '';
    return '$first (+${_placesLived.length - 1})';
  }

  Future<void> _editPlacesLived() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<List<dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPlacesLivedScreen(initialPlacesLived: _placesLived),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _placesLived = result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: context.scaffoldBg,
          appBar: AppBar(
            title: Text(
              l10n.editProfileTitle,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
            ),
            centerTitle: false,
            titleSpacing: 0,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20.r),
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context, true);
              },
            ),
          ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _buildSectionTitle(l10n.imagesSection),
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  children: [

                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14.r),
                          child: Container(
                            height: 110.h,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.blue, Color(0xFF1565C0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: _coverFile != null
                                ? Image.file(_coverFile!, fit: BoxFit.cover)
                                : (_coverUrl != null && _coverUrl!.isNotEmpty
                                    ? Image.network(_coverUrl!, fit: BoxFit.cover)
                                    : null),
                          ),
                        ),
                        Positioned(
                          bottom: 8.h,
                          right: 8.w,
                          child: InkWell(
                            onTap: () => _pickImage(isAvatar: false),
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14.r),
                                  SizedBox(width: 4.w),
                                  Text(
                                    l10n.changeCoverPhoto,
                                    style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    Row(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: EdgeInsets.all(3.r),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.blue.withValues(alpha: 0.3), width: 2.r),
                              ),
                              child: _avatarFile != null
                                  ? ClipOval(
                                      child: Image.file(_avatarFile!, width: 72.r, height: 72.r, fit: BoxFit.cover),
                                    )
                                  : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(_avatarUrl!, width: 72.r, height: 72.r, fit: BoxFit.cover),
                                        )
                                      : CircleAvatar(
                                          radius: 36.r,
                                          backgroundColor: AppColors.blue,
                                          child: Text(
                                            initial,
                                            style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        )),
                            ),
                            Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: const BoxDecoration(
                                color: AppColors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.camera_alt_rounded, size: 14.r, color: Colors.white),
                            ),
                          ],
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.avatar,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                l10n.avatarDesc,
                                style: TextStyle(fontSize: 11.sp, color: context.textMuted),
                              ),
                              SizedBox(height: 8.h),
                              OutlinedButton.icon(
                                onPressed: () => _pickImage(isAvatar: true),
                                icon: Icon(Icons.edit_outlined, size: 14.r, color: AppColors.blue),
                                label: Text(l10n.changeLabel, style: TextStyle(fontSize: 12.sp, color: AppColors.blue)),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                  side: BorderSide(color: AppColors.blue.withValues(alpha: 0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              _buildSectionTitle(l10n.basicInfoSection),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  children: [
                    _buildNavigationField(
                      label: l10n.displayName,
                      value: _nameController.text,
                      hint: l10n.enterNameHint,
                      icon: Icons.person_outline_rounded,
                      onTap: _editName,
                    ),
                    _buildDivider(),
                    _buildNavigationField(
                      label: l10n.bioBioLabel,
                      value: _bioController.text,
                      hint: l10n.addFewLinesIntroHint,
                      icon: Icons.info_outline_rounded,
                      onTap: _editBio,
                      alignTop: true,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              _buildSectionTitle(l10n.personalDetailsSection),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNavigationField(
                      label: l10n.gender,
                      value: _getGenderDisplayName(l10n),
                      hint: l10n.chooseGenderHint,
                      icon: _getGenderIcon(),
                      iconColor: _getGenderColor(),
                      onTap: _editGender,
                    ),
                    _buildDivider(),
                    _buildNavigationField(
                      label: l10n.birthday,
                      value: _birthday != null
                          ? '${_birthday!.day.toString().padLeft(2, '0')} - ${_birthday!.month.toString().padLeft(2, '0')} - ${_birthday!.year}'
                          : '',
                      hint: l10n.chooseBirthdayHint,
                      icon: Icons.cake_outlined,
                      onTap: _editBirthday,
                    ),
                    _buildDivider(),
                    _buildNavigationField(
                      label: l10n.phoneNumber,
                      value: _phoneController.text,
                      hint: l10n.enterPhoneShortHint,
                      icon: Icons.phone_outlined,
                      onTap: _editPhone,
                    ),
                    _buildDivider(),
                    _buildNavigationField(
                      label: l10n.address,
                      value: _addressController.text,
                      hint: l10n.enterAddressShortHint,
                      icon: Icons.location_on_outlined,
                      onTap: _editAddress,
                    ),
                    _buildDivider(),
                    _buildNavigationField(
                      label: l10n.placesLived,
                      value: _placesLivedSummary,
                      hint: l10n.addPlacesLivedHint,
                      icon: Icons.home_work_outlined,
                      onTap: _editPlacesLived,
                    ),
                    _buildDivider(),
                    _buildNavigationField(
                      label: l10n.hometown,
                      value: _homeTownController.text,
                      hint: l10n.chooseHometownHint,
                      icon: Icons.cottage_outlined,
                      onTap: _editHomeTown,
                    ),
                    _buildDivider(),
                    _buildNavigationField(
                      label: l10n.job,
                      value: _jobController.text,
                      hint: l10n.currentJobHint,
                      icon: Icons.work_outline_rounded,
                      onTap: _editJob,
                    ),
                    _buildDivider(),
                    _buildNavigationField(
                      label: l10n.nationality,
                      value: _nationalityController.text,
                      hint: l10n.nationalityShortHint,
                      icon: Icons.flag_outlined,
                      onTap: _editNationality,
                    ),
                    _buildDivider(),
                    _buildNavigationField(
                      label: l10n.hobbies,
                      value: _hobbyController.text,
                      hint: l10n.addHobbiesHint,
                      icon: Icons.palette_outlined,
                      onTap: _editHobby,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w800,
        color: context.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildFieldWrapper({
    required IconData icon,
    required String label,
    required Widget child,
    Widget? trailing,
    Color? iconColor,
    bool alignTop = false,
  }) {
    final effectiveColor = iconColor ?? AppColors.blue;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 38.r,
            height: 38.r,
            margin: EdgeInsets.only(top: alignTop ? 2.h : 0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: effectiveColor, size: 20.r),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
                SizedBox(height: 2.h),
                child,
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: 8.w),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationField({
    required String label,
    required String value,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    bool alignTop = false,
  }) {
    final hasValue = value.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: _buildFieldWrapper(
        icon: icon,
        iconColor: iconColor,
        label: label,
        alignTop: alignTop,
        trailing: Padding(
          padding: EdgeInsets.only(top: alignTop ? 4.h : 0, left: 4.w, right: 2.w, bottom: 4.h),
          child: Icon(
            Icons.edit_outlined,
            size: 18.r,
            color: AppColors.blue,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Text(
            hasValue ? value : hint,
            style: TextStyle(
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w600,
              color: hasValue ? context.textPrimary : context.textMuted.withValues(alpha: 0.45),
            ),
            maxLines: alignTop ? 3 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _getGenderDisplayName(Language l10n) {
    if (_gender == 'male') return l10n.male;
    if (_gender == 'female') return l10n.female;
    if (_gender == 'other') return l10n.other;
    return '';
  }

  IconData _getGenderIcon() {
    if (_gender == 'male') return Icons.man_rounded;
    if (_gender == 'female') return Icons.woman_rounded;
    if (_gender == 'other') return Icons.transgender_rounded;
    return Icons.wc_rounded;
  }

  Color _getGenderColor() {
    if (_gender == 'male') return AppColors.blue;
    if (_gender == 'female') return AppColors.pink;
    if (_gender == 'other') return AppColors.purple;
    return AppColors.blue;
  }

  Widget _buildDivider() {
    return Divider(
      height: 18.h,
      thickness: 0.7,
      color: context.borderTheme.withValues(alpha: 0.4),
    );
  }
}
