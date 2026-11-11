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

class EditAddressScreen extends StatefulWidget {
  final String? initialAddress;
  final String? initialNationality;

  const EditAddressScreen({
    super.key,
    this.initialAddress,
    this.initialNationality,
  });

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
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

    final initialAddr = (widget.initialAddress ?? '').trim();
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

  String get _formattedAddress {
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
      debugPrint('[EditAddressScreen] Error fetching nations: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingNations = false;
      });
    }
  }

  Future<void> _fetchCities({String? nationId, String? nationName}) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
    });

    try {
      final queryParam = (nationId != null && nationId.isNotEmpty)
          ? 'nationId=$nationId'
          : 'nationName=${Uri.encodeComponent(nationName ?? _selectedNation)}';

      final response = await http
          .get(Uri.parse('${ApiConfig.getCities}?$queryParam'))
          .timeout(const Duration(seconds: 8));

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
      debugPrint('[EditAddressScreen] Error fetching cities: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingCities = false;
      });
    }
  }

  Future<void> _fetchWards({String? cityId, String? cityName}) async {
    setState(() {
      _isLoadingWards = true;
      _wards = [];
    });

    try {
      final queryParam = (cityId != null && cityId.isNotEmpty)
          ? 'cityId=$cityId'
          : 'cityName=${Uri.encodeComponent(cityName ?? _selectedCity)}';

      final response = await http
          .get(Uri.parse('${ApiConfig.getWards}?$queryParam'))
          .timeout(const Duration(seconds: 8));

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
      debugPrint('[EditAddressScreen] Error fetching wards: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingWards = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final finalAddress = _formattedAddress;
    final finalNation = _selectedNation.trim();

    if (finalAddress.isEmpty && finalNation.isEmpty) {
      AppToast.error(context, l10n.selectAddressOrCountryWarning);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updateData = <String, dynamic>{
        'address': finalAddress,
        if (finalNation.isNotEmpty) 'nationality': finalNation,
        if (_selectedNationId.isNotEmpty) 'nationId': _selectedNationId,
        if (_selectedCityId.isNotEmpty) 'cityId': _selectedCityId,
        if (_selectedWardId.isNotEmpty) 'wardId': _selectedWardId,
      };

      final success = await ProfileService.updateFields(updateData);

      if (mounted) {
        if (success) {
          AppToast.success(context, l10n.updateAddressSuccess);
        } else {
          AppToast.info(context, l10n.addressSaved);
        }
        Navigator.pop(context, {
          'address': finalAddress,
          'nationality': finalNation,
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.errorSavingAddress);
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
      constraints: BoxConstraints(maxHeight: 220.h),
      decoration: _dropdownDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected =
                selectedValue.trim().toLowerCase() == item.name.toLowerCase();

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(item),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 13.h),
                  color: isSelected ? AppColors.blue.withValues(alpha: 0.12) : Colors.transparent,
                  child: Text(
                    item.name,
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

  Widget _buildSelectBox({
    required String label,
    required String value,
    required String hint,
    required IconData prefixIcon,
    required bool isOpen,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final hasValue = value.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: context.textMuted,
            letterSpacing: 1.1,
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isOpen
                    ? AppColors.blue
                    : context.borderTheme.withValues(alpha: 0.4),
                width: isOpen ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(prefixIcon, color: AppColors.blue, size: 20.r),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    hasValue ? value : hint,
                    style: TextStyle(
                      fontSize: 15.5.sp,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                      color: hasValue
                          ? context.textPrimary
                          : context.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                if (hasValue && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Padding(
                      padding: EdgeInsets.only(right: 6.w),
                      child: Icon(Icons.cancel_rounded, color: context.textMuted, size: 18.r),
                    ),
                  ),
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: isOpen ? AppColors.blue : context.textMuted,
                  size: 24.r,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyNationalityNotice() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.flag_outlined, size: 32.r, color: context.textMuted.withValues(alpha: 0.6)),
          SizedBox(height: 10.h),
          Text(
            l10n.notSelectedNationality,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            l10n.selectNationalityFirstDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: context.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBox() {
    final addr = _formattedAddress;
    if (addr.isEmpty && _selectedNation.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 20.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: Icon(Icons.check_circle_rounded, color: AppColors.blue, size: 20.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.addressToSave,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blue,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  addr.isNotEmpty ? addr : _selectedNation,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                if (_selectedNation.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '${l10n.nationalityLabel}: $_selectedNation',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
            l10n.address,
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
                    child: Icon(Icons.location_on_outlined, size: 36.r, color: AppColors.blue),
                  ),
                ),
                SizedBox(height: 20.h),
                Center(
                  child: Text(
                    l10n.yourAddress,
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
                    l10n.selectAddressDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: context.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 26.h),

                _buildSelectBox(
                  label: l10n.nationalityHeader,
                  value: _selectedNation,
                  hint: l10n.selectNationalityHint,
                  prefixIcon: Icons.public_rounded,
                  isOpen: _activeDropdown == _ActiveDropdown.nation,
                  onTap: () {
                    setState(() {
                      _activeDropdown = _activeDropdown == _ActiveDropdown.nation
                          ? _ActiveDropdown.none
                          : _ActiveDropdown.nation;
                    });
                  },
                  onClear: () {
                    setState(() {
                      _selectedNation = '';
                      _selectedNationId = '';
                      _selectedCity = '';
                      _selectedCityId = '';
                      _selectedWard = '';
                      _selectedWardId = '';
                      _cities = [];
                      _wards = [];
                      _activeDropdown = _ActiveDropdown.none;
                    });
                  },
                ),
                if (_activeDropdown == _ActiveDropdown.nation)
                  _buildDropdownContainer(
                    isLoading: _isLoadingNations,
                    items: _nations,
                    selectedValue: _selectedNation,
                    emptyMessage: l10n.noCountryData,
                    onSelect: (item) {
                      setState(() {
                        _selectedNation = item.name;
                        _selectedNationId = item.id;
                        _selectedCity = '';
                        _selectedCityId = '';
                        _selectedWard = '';
                        _selectedWardId = '';
                        _activeDropdown = _ActiveDropdown.none;
                      });
                      _fetchCities(nationId: item.id, nationName: item.name);
                    },
                  ),

                SizedBox(height: 18.h),

                if (_selectedNation.isEmpty)
                  _buildEmptyNationalityNotice()
                else ...[
                  _buildSelectBox(
                    label: l10n.provinceCityHeader,
                    value: _selectedCity,
                    hint: l10n.selectCityHint,
                    prefixIcon: Icons.location_city_rounded,
                    isOpen: _activeDropdown == _ActiveDropdown.city,
                    onTap: () {
                      setState(() {
                        _activeDropdown = _activeDropdown == _ActiveDropdown.city
                            ? _ActiveDropdown.none
                            : _ActiveDropdown.city;
                      });
                    },
                    onClear: () {
                      setState(() {
                        _selectedCity = '';
                        _selectedCityId = '';
                        _selectedWard = '';
                        _selectedWardId = '';
                        _wards = [];
                        _activeDropdown = _ActiveDropdown.none;
                      });
                    },
                  ),
                  if (_activeDropdown == _ActiveDropdown.city)
                    _buildDropdownContainer(
                      isLoading: _isLoadingCities,
                      items: _cities,
                      selectedValue: _selectedCity,
                      emptyMessage: l10n.noCityData,
                      onSelect: (item) {
                        setState(() {
                          _selectedCity = item.name;
                          _selectedCityId = item.id;
                          _selectedWard = '';
                          _selectedWardId = '';
                          _activeDropdown = _ActiveDropdown.none;
                        });
                        _fetchWards(cityId: item.id, cityName: item.name);
                      },
                    ),

                  if (_selectedCity.isNotEmpty) ...[
                    SizedBox(height: 18.h),
                    _buildSelectBox(
                      label: l10n.wardOptionalHeader,
                      value: _selectedWard,
                      hint: l10n.selectWardHint,
                      prefixIcon: Icons.holiday_village_outlined,
                      isOpen: _activeDropdown == _ActiveDropdown.ward,
                      onTap: () {
                        setState(() {
                          _activeDropdown = _activeDropdown == _ActiveDropdown.ward
                              ? _ActiveDropdown.none
                              : _ActiveDropdown.ward;
                        });
                      },
                      onClear: () {
                        setState(() {
                          _selectedWard = '';
                          _selectedWardId = '';
                          _activeDropdown = _ActiveDropdown.none;
                        });
                      },
                    ),
                    if (_activeDropdown == _ActiveDropdown.ward)
                      _buildDropdownContainer(
                        isLoading: _isLoadingWards,
                        items: _wards,
                        selectedValue: _selectedWard,
                        emptyMessage: l10n.noWardDataForCity,
                        onSelect: (item) {
                          setState(() {
                            _selectedWard = item.name;
                            _selectedWardId = item.id;
                            _activeDropdown = _ActiveDropdown.none;
                          });
                        },
                      ),
                  ],
                ],

                _buildPreviewBox(),

                SizedBox(height: 32.h),

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
                            l10n.saveAddress,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
