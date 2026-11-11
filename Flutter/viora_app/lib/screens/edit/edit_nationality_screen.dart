import '../../l10n/language.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/profile_service.dart';
import '../../widgets/toast/app_toast.dart';

class _NationItem {
  final String id;
  final String name;
  final String continent;

  const _NationItem({
    required this.id,
    required this.name,
    required this.continent,
  });
}

class EditNationalityScreen extends StatefulWidget {
  final String? initialNationality;

  const EditNationalityScreen({
    super.key,
    this.initialNationality,
  });

  @override
  State<EditNationalityScreen> createState() => _EditNationalityScreenState();
}

class _EditNationalityScreenState extends State<EditNationalityScreen> {
  String _selectedNationality = '';
  bool _isSaving = false;
  bool _isLoadingNations = false;
  bool _hasErrorLoadingNations = false;
  bool _isDropdownOpen = false;

  List<String> _continents = ['ALL'];
  String _selectedContinent = 'ALL';
  List<_NationItem> _allNations = [];

  List<_NationItem> get _filteredNations {
    if (_selectedContinent == 'ALL') {
      return _allNations;
    }
    return _allNations
        .where((n) => n.continent.toLowerCase() == _selectedContinent.toLowerCase())
        .toList();
  }

  String _formatContinentName(String continent) {
    switch (continent.toLowerCase()) {
      case 'all':
        return l10n.all;
      case 'asia':
        return l10n.continentAsia;
      case 'europe':
        return l10n.continentEurope;
      case 'america':
        return l10n.continentAmerica;
      case 'australia':
        return l10n.continentAustralia;
      case 'africa':
        return l10n.continentAfrica;
      default:
        return continent;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedNationality = widget.initialNationality ?? '';
    _fetchNations();
  }

  Future<void> _fetchNations() async {
    setState(() {
      _isLoadingNations = true;
      _hasErrorLoadingNations = false;
    });

    try {
      final response = await http
          .get(Uri.parse(ApiConfig.getNations))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<String> rawContinents = [];
          if (body['continents'] is List) {
            for (final c in body['continents']) {
              final name = c.toString().trim();
              if (name.isNotEmpty && !rawContinents.contains(name)) {
                rawContinents.add(name);
              }
            }
          }

          final List<_NationItem> nationsList = [];
          if (body['data'] is List) {
            for (final item in body['data']) {
              final name = (item['nameNation'] ?? '').toString().trim();
              if (name.isNotEmpty) {
                nationsList.add(_NationItem(
                  id: (item['_id'] ?? '').toString(),
                  name: name,
                  continent: (item['continent'] ?? '').toString().trim(),
                ));
              }
            }
          }

          const priorityOrder = ['asia', 'europe', 'america', 'australia', 'africa'];
          rawContinents.sort((a, b) {
            final indexA = priorityOrder.indexOf(a.toLowerCase());
            final indexB = priorityOrder.indexOf(b.toLowerCase());
            if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
            if (indexA != -1) return -1;
            if (indexB != -1) return 1;
            return a.compareTo(b);
          });

          if (mounted) {
            setState(() {
              _continents = ['ALL', ...rawContinents];
              _allNations = nationsList;
              _isLoadingNations = false;
              _hasErrorLoadingNations = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[EditNationalityScreen] Error fetching nations: $e');
    }

    if (mounted) {
      setState(() {
        _continents = ['ALL'];
        _allNations = [];
        _isLoadingNations = false;
        _hasErrorLoadingNations = true;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final nationality = _selectedNationality.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await ProfileService.updateSingleField(
        fieldKey: 'nationality',
        value: nationality,
      );

      if (mounted) {
        if (success) {
          AppToast.success(context, l10n.updateNationalitySuccess);
        } else {
          AppToast.info(context, l10n.nationalitySaved);
        }
        Navigator.pop(context, nationality);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.errorSavingNationality);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  BoxDecoration _dropdownDecoration() {
    return BoxDecoration(
      color: context.isDark ? const Color(0xFF1E1E2C) : Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(
        color: context.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.14),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _buildDropdownList() {
    if (_isLoadingNations) {
      return Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.symmetric(vertical: 24.h),
        decoration: _dropdownDecoration(),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
          ),
        ),
      );
    }

    if (_hasErrorLoadingNations && _allNations.isEmpty) {
      return Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
        decoration: _dropdownDecoration(),
        child: Center(
          child: InkWell(
            onTap: _fetchNations,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
              child: Text(
                l10n.errorLoadingCountries,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  color: AppColors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final list = _filteredNations;
    if (list.isEmpty) {
      return Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
        decoration: _dropdownDecoration(),
        child: Center(
          child: Text(
            l10n.noCountriesInRegion,
            style: TextStyle(
              fontSize: 13.5.sp,
              color: context.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(top: 8.h),
      constraints: BoxConstraints(maxHeight: 250.h),
      decoration: _dropdownDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
          itemBuilder: (context, index) {
            final nation = list[index];
            final isSelected =
                _selectedNationality.trim().toLowerCase() == nation.name.toLowerCase();

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedNationality = nation.name;
                    _isDropdownOpen = false;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 13.h),
                  color: isSelected ? AppColors.blue.withValues(alpha: 0.12) : Colors.transparent,
                  child: Text(
                    nation.name,
                    style: TextStyle(
                      fontSize: 14.5.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.blue : context.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: () {
        if (_isDropdownOpen) {
          setState(() {
            _isDropdownOpen = false;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20.r),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            l10n.nationality,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 72.r,
                    height: 72.r,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.flag_outlined, size: 36.r, color: AppColors.blue),
                  ),
                ),
                SizedBox(height: 20.h),
                Center(
                  child: Text(
                    l10n.yourNationality,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Center(
                  child: Text(
                    l10n.nationalityDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: context.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                Text(
                  l10n.continentsHeader,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: context.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  height: 38.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(left: 2.w, right: 16.w),
                    itemCount: _continents.length,
                    itemBuilder: (context, index) {
                      final continent = _continents[index];
                      final isSelected =
                          _selectedContinent.toLowerCase() == continent.toLowerCase();
                      final displayName = _formatContinentName(continent);

                      return Builder(
                        builder: (itemContext) {
                          return Padding(
                            padding: EdgeInsets.only(right: 8.w),
                            child: GestureDetector(
                              onTap: () {
                                Scrollable.ensureVisible(
                                  itemContext,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  alignment: 0.5,
                                );
                                setState(() {
                                  _selectedContinent = continent;
                                  _isDropdownOpen = true;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.blue
                                      : (context.isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.black.withValues(alpha: 0.04)),
                                  borderRadius: BorderRadius.circular(19.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.blue
                                        : (context.isDark
                                            ? Colors.white12
                                            : Colors.black.withValues(alpha: 0.08)),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? Colors.white : context.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: 20.h),

                Text(
                  l10n.nationalityHeader,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: context.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDropdownOpen = !_isDropdownOpen;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: _isDropdownOpen
                            ? AppColors.blue
                            : context.borderTheme.withValues(alpha: 0.4),
                        width: _isDropdownOpen ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.public_rounded, color: AppColors.blue, size: 20.r),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            _selectedNationality.isNotEmpty
                                ? _selectedNationality
                                : l10n.selectNationalityHint,
                            style: TextStyle(
                              fontSize: 15.5.sp,
                              fontWeight: _selectedNationality.isNotEmpty
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _selectedNationality.isNotEmpty
                                  ? context.textPrimary
                                  : context.textMuted.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        if (_selectedNationality.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedNationality = '';
                              });
                            },
                            child: Padding(
                              padding: EdgeInsets.only(right: 6.w),
                              child: Icon(Icons.cancel_rounded,
                                  color: context.textMuted, size: 18.r),
                            ),
                          ),
                        Icon(
                          _isDropdownOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: _isDropdownOpen ? AppColors.blue : context.textMuted,
                          size: 24.r,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isDropdownOpen) _buildDropdownList(),

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
                            child:
                                const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            l10n.saveNationality,
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
      ),
    );
  }
}
