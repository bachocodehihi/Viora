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

class _LocationModel {
  final String id;
  final String name;

  const _LocationModel({required this.id, required this.name});
}

enum _ActiveDropdown { none, nation, city, ward }

class EditHomeTownScreen extends StatefulWidget {
  final String? initialHomeTown;
  final String? initialNationality;

  const EditHomeTownScreen({
    super.key,
    this.initialHomeTown,
    this.initialNationality,
  });

  @override
  State<EditHomeTownScreen> createState() => _EditHomeTownScreenState();
}

class _EditHomeTownScreenState extends State<EditHomeTownScreen> {
  bool _isSaving = false;

  String _selectedNation = '';
  String _selectedNationId = '';

  String _selectedCity = '';
  String _selectedCityId = '';

  String _selectedWard = '';
  String _selectedWardId = '';

  List<_LocationModel> _nations = [];
  List<_LocationModel> _cities = [];
  List<_LocationModel> _wards = [];

  bool _isLoadingNations = false;
  bool _isLoadingCities = false;
  bool _isLoadingWards = false;

  _ActiveDropdown _activeDropdown = _ActiveDropdown.none;

  @override
  void initState() {
    super.initState();
    _parseInitialData();
    _fetchNations();
  }

  void _parseInitialData() {
    if (widget.initialNationality != null && widget.initialNationality!.trim().isNotEmpty) {
      _selectedNation = widget.initialNationality!.trim();
    }

    final initialAddr = (widget.initialHomeTown ?? '').trim();
    if (initialAddr.isNotEmpty) {
      if (initialAddr.contains(',')) {
        final parts = initialAddr.split(',').map((p) => p.trim()).toList();
        if (parts.length >= 2) {
          _selectedWard = parts[0];
          _selectedCity = parts[1];
        } else {
          _selectedCity = parts[0];
        }
      } else {
        _selectedCity = initialAddr;
      }
    }
  }

  String get _formattedHomeTown {
    if (_selectedWard.isNotEmpty && _selectedCity.isNotEmpty) {
      return '$_selectedWard, $_selectedCity';
    }
    if (_selectedCity.isNotEmpty) {
      return _selectedCity;
    }
    if (_selectedNation.isNotEmpty) {
      return _selectedNation;
    }
    return '';
  }

  Future<void> _fetchNations() async {
    setState(() {
      _isLoadingNations = true;
    });

    try {
      final response = await http
          .get(Uri.parse(ApiConfig.getNations))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          final list = (body['data'] as List).map((item) {
            return _LocationModel(
              id: (item['_id'] ?? '').toString(),
              name: (item['nameNation'] ?? '').toString().trim(),
            );
          }).where((m) => m.name.isNotEmpty).toList();

          if (mounted) {
            setState(() {
              _nations = list;
              _isLoadingNations = false;

              if (_selectedNation.isNotEmpty) {
                final match = list.firstWhere(
                  (n) => n.name.toLowerCase() == _selectedNation.toLowerCase(),
                  orElse: () => _LocationModel(id: '', name: _selectedNation),
                );
                _selectedNationId = match.id;
              }
            });

            if (_selectedNation.isNotEmpty) {
              _fetchCities(nationId: _selectedNationId, nationName: _selectedNation);
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[EditHomeTownScreen] Error fetching nations: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingNations = false;
      });
    }
  }

  Future<void> _fetchCities({required String nationId, required String nationName}) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
    });

    try {
      final uri = Uri.parse(ApiConfig.getCities).replace(queryParameters: {
        if (nationId.isNotEmpty) 'nationId': nationId,
        'nationName': nationName,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          final list = (body['data'] as List).map((item) {
            return _LocationModel(
              id: (item['_id'] ?? '').toString(),
              name: (item['nameCity'] ?? '').toString().trim(),
            );
          }).where((m) => m.name.isNotEmpty).toList();

          if (mounted) {
            setState(() {
              _cities = list;
              _isLoadingCities = false;

              if (_selectedCity.isNotEmpty) {
                final match = list.firstWhere(
                  (c) => c.name.toLowerCase() == _selectedCity.toLowerCase(),
                  orElse: () => _LocationModel(id: '', name: _selectedCity),
                );
                _selectedCityId = match.id;
              }
            });

            if (_selectedCityId.isNotEmpty || _selectedCity.isNotEmpty) {
              _fetchWards(cityId: _selectedCityId, cityName: _selectedCity);
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[EditHomeTownScreen] Error fetching cities: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingCities = false;
      });
    }
  }

  Future<void> _fetchWards({required String cityId, required String cityName}) async {
    setState(() {
      _isLoadingWards = true;
      _wards = [];
    });

    try {
      final uri = Uri.parse(ApiConfig.getWards).replace(queryParameters: {
        if (cityId.isNotEmpty) 'cityId': cityId,
        'cityName': cityName,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          final list = (body['data'] as List).map((item) {
            return _LocationModel(
              id: (item['_id'] ?? '').toString(),
              name: (item['nameWard'] ?? '').toString().trim(),
            );
          }).where((m) => m.name.isNotEmpty).toList();

          if (mounted) {
            setState(() {
              _wards = list;
              _isLoadingWards = false;

              if (_selectedWard.isNotEmpty) {
                final match = list.firstWhere(
                  (w) => w.name.toLowerCase() == _selectedWard.toLowerCase(),
                  orElse: () => _LocationModel(id: '', name: _selectedWard),
                );
                _selectedWardId = match.id;
              }
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[EditHomeTownScreen] Error fetching wards: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingWards = false;
      });
    }
  }

  void _onSelectNation(_LocationModel nation) {
    setState(() {
      _selectedNation = nation.name;
      _selectedNationId = nation.id;

      _selectedCity = '';
      _selectedCityId = '';
      _selectedWard = '';
      _selectedWardId = '';
      _cities = [];
      _wards = [];

      _activeDropdown = _ActiveDropdown.city;
    });

    _fetchCities(nationId: nation.id, nationName: nation.name);
  }

  void _onSelectCity(_LocationModel city) {
    setState(() {
      _selectedCity = city.name;
      _selectedCityId = city.id;

      _selectedWard = '';
      _selectedWardId = '';
      _wards = [];

      _activeDropdown = _ActiveDropdown.ward;
    });

    _fetchWards(cityId: city.id, cityName: city.name);
  }

  void _onSelectWard(_LocationModel ward) {
    setState(() {
      _selectedWard = ward.name;
      _selectedWardId = ward.id;
      _activeDropdown = _ActiveDropdown.none;
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final finalTown = _formattedHomeTown;
    final finalNation = _selectedNation.trim();

    if (finalTown.isEmpty && finalNation.isEmpty) {
      AppToast.error(context, l10n.selectHometownWarning);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updateData = <String, dynamic>{
        'homeTown': finalTown,
        if (_selectedNationId.isNotEmpty) 'homeTownNationId': _selectedNationId,
        if (_selectedCityId.isNotEmpty) 'homeTownCityId': _selectedCityId,
        if (_selectedWardId.isNotEmpty) 'homeTownWardId': _selectedWardId,
      };

      final success = await ProfileService.updateFields(updateData);

      if (mounted) {
        if (success) {
          AppToast.success(context, l10n.updateHometownSuccess);
        } else {
          AppToast.info(context, l10n.hometownSaved);
        }
        Navigator.pop(context, finalTown);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.errorSavingHometown);
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

  Widget _buildDropdownContainer({
    required bool isLoading,
    required List<_LocationModel> items,
    required String selectedValue,
    required String emptyMessage,
    required void Function(_LocationModel) onSelect,
  }) {
    if (isLoading) {
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

    if (items.isEmpty) {
      return Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
        decoration: _dropdownDecoration(),
        child: Center(
          child: Text(
            emptyMessage,
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
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: context.borderTheme.withValues(alpha: 0.25),
          ),
          itemBuilder: (ctx, idx) {
            final item = items[idx];
            final isSelected = item.name.toLowerCase() == selectedValue.toLowerCase();
            return InkWell(
              onTap: () => onSelect(item),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
                color: isSelected
                    ? AppColors.blue.withValues(alpha: context.isDark ? 0.25 : 0.1)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.blue : context.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_rounded, color: AppColors.blue, size: 18.r),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFieldSelector({
    required String label,
    required String value,
    required String hint,
    required IconData icon,
    required bool isOpen,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    final hasVal = value.trim().isNotEmpty;
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isOpen
                ? AppColors.blue
                : context.borderTheme.withValues(alpha: isDisabled ? 0.2 : 0.6),
            width: isOpen ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                color: (isDisabled ? context.textMuted : AppColors.blue).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                icon,
                color: isDisabled ? context.textMuted.withValues(alpha: 0.4) : AppColors.blue,
                size: 20.r,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: context.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    hasVal ? value : hint,
                    style: TextStyle(
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w600,
                      color: isDisabled
                          ? context.textMuted.withValues(alpha: 0.4)
                          : (hasVal ? context.textPrimary : context.textMuted.withValues(alpha: 0.5)),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: isDisabled ? context.textMuted.withValues(alpha: 0.3) : context.textMuted,
              size: 22.r,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final previewText = _formattedHomeTown;

    return GestureDetector(
      onTap: () {
        if (_activeDropdown != _ActiveDropdown.none) {
          setState(() {
            _activeDropdown = _ActiveDropdown.none;
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
            l10n.hometown,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: context.borderTheme.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44.r,
                        height: 44.r,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.cottage_outlined, size: 24.r, color: AppColors.blue),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.yourHometown,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              l10n.hometownDesc,
                              style: TextStyle(fontSize: 11.5.sp, color: context.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                _buildFieldSelector(
                  label: l10n.countryOrNationLabel,
                  value: _selectedNation,
                  hint: l10n.selectCountryHint,
                  icon: Icons.flag_outlined,
                  isOpen: _activeDropdown == _ActiveDropdown.nation,
                  onTap: () {
                    setState(() {
                      _activeDropdown = _activeDropdown == _ActiveDropdown.nation
                          ? _ActiveDropdown.none
                          : _ActiveDropdown.nation;
                    });
                  },
                ),
                if (_activeDropdown == _ActiveDropdown.nation)
                  _buildDropdownContainer(
                    isLoading: _isLoadingNations,
                    items: _nations,
                    selectedValue: _selectedNation,
                    emptyMessage: l10n.noCountryFound,
                    onSelect: _onSelectNation,
                  ),

                SizedBox(height: 12.h),

                _buildFieldSelector(
                  label: l10n.provinceCity,
                  value: _selectedCity,
                  hint: _selectedNation.isEmpty ? l10n.pleaseSelectCountryFirst : l10n.selectCityHint,
                  icon: Icons.location_city_outlined,
                  isOpen: _activeDropdown == _ActiveDropdown.city,
                  isDisabled: _selectedNation.isEmpty,
                  onTap: () {
                    if (_selectedNation.isEmpty) return;
                    setState(() {
                      _activeDropdown = _activeDropdown == _ActiveDropdown.city
                          ? _ActiveDropdown.none
                          : _ActiveDropdown.city;
                    });
                  },
                ),
                if (_activeDropdown == _ActiveDropdown.city)
                  _buildDropdownContainer(
                    isLoading: _isLoadingCities,
                    items: _cities,
                    selectedValue: _selectedCity,
                    emptyMessage: l10n.noProvinceDataForCountry,
                    onSelect: _onSelectCity,
                  ),

                SizedBox(height: 12.h),

                _buildFieldSelector(
                  label: l10n.wardOptionalHeader,
                  value: _selectedWard,
                  hint: _selectedCity.isEmpty ? l10n.pleaseSelectCountryFirst : l10n.selectWardHint,
                  icon: Icons.place_outlined,
                  isOpen: _activeDropdown == _ActiveDropdown.ward,
                  isDisabled: _selectedCity.isEmpty,
                  onTap: () {
                    if (_selectedCity.isEmpty) return;
                    setState(() {
                      _activeDropdown = _activeDropdown == _ActiveDropdown.ward
                          ? _ActiveDropdown.none
                          : _ActiveDropdown.ward;
                    });
                  },
                ),
                if (_activeDropdown == _ActiveDropdown.ward)
                  _buildDropdownContainer(
                    isLoading: _isLoadingWards,
                    items: _wards,
                    selectedValue: _selectedWard,
                    emptyMessage: l10n.noWardDataForCity,
                    onSelect: _onSelectWard,
                  ),

                SizedBox(height: 24.h),

                if (previewText.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: AppColors.blue, size: 20.r),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.hometown,
                                style: TextStyle(fontSize: 11.sp, color: AppColors.blue, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                previewText,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],

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
                            l10n.saveHometown,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 30.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
