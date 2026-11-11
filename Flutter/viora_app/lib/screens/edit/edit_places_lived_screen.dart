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

class EditPlacesLivedScreen extends StatefulWidget {
  final List<dynamic>? initialPlacesLived;

  const EditPlacesLivedScreen({
    super.key,
    this.initialPlacesLived,
  });

  @override
  State<EditPlacesLivedScreen> createState() => _EditPlacesLivedScreenState();
}

class _EditPlacesLivedScreenState extends State<EditPlacesLivedScreen> {
  late List<Map<String, dynamic>> _placesLived;
  bool _isSaving = false;
  bool _isAddingNew = false;

  String _selectedNation = '';
  String _selectedNationId = '';
  String _selectedContinent = 'ALL';

  String _selectedCity = '';
  String _selectedCityId = '';

  String _selectedWard = '';
  String _selectedWardId = '';

  List<String> _continents = ['ALL'];
  List<Map<String, dynamic>> _allNationsRaw = [];
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
    _placesLived = [];
    if (widget.initialPlacesLived != null) {
      for (final item in widget.initialPlacesLived!) {
        if (item is Map) {
          _placesLived.add(Map<String, dynamic>.from(item));
        }
      }
    }
    _fetchNations();
  }

  String get _formattedNewAddress {
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
          final List<Map<String, dynamic>> rawList = [];
          final Set<String> contSet = {'ALL'};

          for (final item in body['data']) {
            final name = (item['nameNation'] ?? '').toString().trim();
            final cont = (item['continent'] ?? '').toString().trim();
            if (name.isNotEmpty) {
              rawList.add({
                'id': (item['_id'] ?? '').toString(),
                'name': name,
                'continent': cont.isNotEmpty ? cont : 'Other',
              });
              if (cont.isNotEmpty) contSet.add(cont);
            }
          }

          if (mounted) {
            setState(() {
              _allNationsRaw = rawList;
              _continents = contSet.toList();
              _filterNationsByContinent('ALL');
              _isLoadingNations = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[EditPlacesLivedScreen] Error fetching nations: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingNations = false;
      });
    }
  }

  void _filterNationsByContinent(String continent) {
    _selectedContinent = continent;
    if (continent == 'ALL') {
      _nations = _allNationsRaw
          .map((e) => _LocationModel(id: e['id'] as String, name: e['name'] as String))
          .toList();
    } else {
      _nations = _allNationsRaw
          .where((e) => (e['continent'] as String).toLowerCase() == continent.toLowerCase())
          .map((e) => _LocationModel(id: e['id'] as String, name: e['name'] as String))
          .toList();
    }
  }

  Future<void> _fetchCities({required String nationId, required String nationName}) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _selectedCity = '';
      _selectedCityId = '';
      _wards = [];
      _selectedWard = '';
      _selectedWardId = '';
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
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[EditPlacesLivedScreen] Error fetching cities: $e');
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
      _selectedWard = '';
      _selectedWardId = '';
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
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[EditPlacesLivedScreen] Error fetching wards: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingWards = false;
      });
    }
  }

  Future<void> _addPlace() async {
    final addr = _formattedNewAddress.trim();
    if (addr.isEmpty) {
      AppToast.error(context, l10n.selectCountryOrCityWarning);
      return;
    }

    final isDuplicate = _placesLived.any((p) =>
        (p['address'] ?? '').toString().toLowerCase().trim() == addr.toLowerCase());
    if (isDuplicate) {
      AppToast.info(context, l10n.placeAlreadyInList);
      return;
    }

    final newPlace = <String, dynamic>{
      'address': addr,
      'nationality': _selectedNation,
      if (_selectedNationId.isNotEmpty) 'nationId': _selectedNationId,
      if (_selectedCityId.isNotEmpty) 'cityId': _selectedCityId,
      if (_selectedWardId.isNotEmpty) 'wardId': _selectedWardId,
      'createdAt': DateTime.now().toIso8601String(),
    };

    final updatedList = List<Map<String, dynamic>>.from(_placesLived)..add(newPlace);

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await ProfileService.updateFields({
        'placesLived': updatedList,
      });

      if (mounted) {
        if (success) {
          setState(() {
            _placesLived = updatedList;
            _isAddingNew = false;
            _selectedWard = '';
            _selectedWardId = '';
            _selectedCity = '';
            _selectedCityId = '';
            _activeDropdown = _ActiveDropdown.none;
          });
          AppToast.success(context, l10n.addPlaceLivedSuccess);
        } else {
          AppToast.error(context, l10n.saveDataFailed);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.errorAddingPlace);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deletePlace(int index) async {
    final updatedList = List<Map<String, dynamic>>.from(_placesLived)..removeAt(index);

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await ProfileService.updateFields({
        'placesLived': updatedList,
      });

      if (mounted) {
        if (success) {
          setState(() {
            _placesLived = updatedList;
          });
          AppToast.success(context, l10n.deletedPlaceLivedSuccess);
        } else {
          AppToast.error(context, l10n.deleteFailed);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.errorDeletingPlace);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _placesLived);
      },
      child: GestureDetector(
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
              onPressed: () => Navigator.pop(context, _placesLived),
            ),
            title: Text(
              l10n.placesLived,
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
                  _buildHeaderCard(),
                  SizedBox(height: 18.h),

                  if (!_isAddingNew)
                    _buildAddButton()
                  else
                    _buildAddLocationForm(),

                  SizedBox(height: 24.h),
                  _buildSectionTitle('${l10n.placesLivedListHeader} (${_placesLived.length})'),
                  SizedBox(height: 10.h),

                  if (_placesLived.isEmpty)
                    _buildEmptyState()
                  else
                    ...List.generate(_placesLived.length, (idx) {
                      return _buildPlaceItem(idx, _placesLived[idx]);
                    }),

                  SizedBox(height: 30.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: context.borderTheme.withValues(alpha: 0.3),
        ),
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
            child: Icon(Icons.home_work_outlined, size: 24.r, color: AppColors.blue),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.placesLived,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  l10n.placesLivedDesc,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: () {
        setState(() {
          _isAddingNew = true;
          _activeDropdown = _selectedNation.isEmpty ? _ActiveDropdown.nation : _ActiveDropdown.city;
        });
      },
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_location_alt_outlined, color: AppColors.blue, size: 20.r),
            SizedBox(width: 8.w),
            Text(
              l10n.addPlacesLived,
              style: TextStyle(
                fontSize: 14.5.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddLocationForm() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.addNewLocationHeader,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue,
                  letterSpacing: 1.1,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isAddingNew = false;
                    _activeDropdown = _ActiveDropdown.none;
                  });
                },
                borderRadius: BorderRadius.circular(8.r),
                child: Padding(
                  padding: EdgeInsets.all(4.r),
                  child: Icon(Icons.close_rounded, size: 20.r, color: context.textMuted),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          _buildSelectorRow(
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
          if (_activeDropdown == _ActiveDropdown.nation) ...[
            _buildContinentChips(),
            _buildDropdownList(
              items: _nations,
              selectedValue: _selectedNation,
              isLoading: _isLoadingNations,
              emptyMsg: l10n.noCountryFound,
              onSelect: (item) {
                setState(() {
                  _selectedNation = item.name;
                  _selectedNationId = item.id;
                  _activeDropdown = _ActiveDropdown.city;
                });
                _fetchCities(nationId: item.id, nationName: item.name);
              },
            ),
          ],

          SizedBox(height: 12.h),

          _buildSelectorRow(
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
            _buildDropdownList(
              items: _cities,
              selectedValue: _selectedCity,
              isLoading: _isLoadingCities,
              emptyMsg: l10n.noCityData,
              onSelect: (item) {
                setState(() {
                  _selectedCity = item.name;
                  _selectedCityId = item.id;
                  _activeDropdown = _ActiveDropdown.ward;
                });
                _fetchWards(cityId: item.id, cityName: item.name);
              },
            ),

          SizedBox(height: 12.h),

          _buildSelectorRow(
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
            _buildDropdownList(
              items: _wards,
              selectedValue: _selectedWard,
              isLoading: _isLoadingWards,
              emptyMsg: l10n.noWardDataForCity,
              onSelect: (item) {
                setState(() {
                  _selectedWard = item.name;
                  _selectedWardId = item.id;
                  _activeDropdown = _ActiveDropdown.none;
                });
              },
            ),

          SizedBox(height: 16.h),

          if (_formattedNewAddress.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: AppColors.blue, size: 18.r),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      '${l10n.addressToSave} $_formattedNewAddress',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
          ],

          SizedBox(
            width: double.infinity,
            height: 46.h,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _addPlace,
              icon: _isSaving
                  ? SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.add_rounded, color: Colors.white, size: 20.r),
              label: Text(
                _isSaving ? l10n.savingEllipsis : l10n.saveThisLocation,
                style: TextStyle(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinentChips() {
    return Container(
      margin: EdgeInsets.only(top: 8.h),
      height: 36.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _continents.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (ctx, i) {
          final c = _continents[i];
          final isSelected = _selectedContinent.toLowerCase() == c.toLowerCase();
          return InkWell(
            onTap: () {
              setState(() {
                _filterNationsByContinent(c);
              });
            },
            borderRadius: BorderRadius.circular(18.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.blue : context.cardBg,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: isSelected ? AppColors.blue : context.borderTheme.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                c == 'ALL' ? l10n.all : c,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : context.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectorRow({
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
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1B1B26) : const Color(0xFFF6F8FB),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isOpen
                ? AppColors.blue
                : context.borderTheme.withValues(alpha: isDisabled ? 0.2 : 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20.r,
              color: isDisabled
                  ? context.textMuted.withValues(alpha: 0.4)
                  : (hasVal ? AppColors.blue : context.textMuted),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: context.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    hasVal ? value : hint,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isDisabled
                          ? context.textMuted.withValues(alpha: 0.4)
                          : (hasVal ? context.textPrimary : context.textMuted),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              size: 20.r,
              color: isDisabled ? context.textMuted.withValues(alpha: 0.3) : context.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownList({
    required List<_LocationModel> items,
    required String selectedValue,
    required bool isLoading,
    required String emptyMsg,
    required void Function(_LocationModel) onSelect,
  }) {
    if (isLoading) {
      return Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.symmetric(vertical: 24.h),
        decoration: _dropdownBoxDecoration(),
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
        padding: EdgeInsets.all(16.r),
        decoration: _dropdownBoxDecoration(),
        child: Center(
          child: Text(
            emptyMsg,
            style: TextStyle(fontSize: 13.sp, color: context.textMuted),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(top: 8.h),
      constraints: BoxConstraints(maxHeight: 220.h),
      decoration: _dropdownBoxDecoration(),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 0.5,
          color: context.borderTheme.withValues(alpha: 0.25),
        ),
        itemBuilder: (ctx, i) {
          final item = items[i];
          final isSelected = item.name.toLowerCase() == selectedValue.toLowerCase();
          return InkWell(
            onTap: () => onSelect(item),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 13.5.sp,
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
    );
  }

  BoxDecoration _dropdownBoxDecoration() {
    return BoxDecoration(
      color: context.isDark ? const Color(0xFF1E1E2C) : Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(
        color: context.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: context.borderTheme.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 56.r,
            height: 56.r,
            decoration: BoxDecoration(
              color: context.textMuted.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_off_outlined, size: 28.r, color: context.textMuted),
          ),
          SizedBox(height: 12.h),
          Text(
            l10n.noPlacesLivedYet,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            l10n.addPlacesLivedPrompt,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceItem(int index, Map<String, dynamic> place) {
    final address = (place['address'] ?? '').toString();
    final nationality = (place['nationality'] ?? '').toString();

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: context.borderTheme.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.location_on_rounded, color: AppColors.blue, size: 20.r),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.isNotEmpty ? address : l10n.locationLabel,
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                if (nationality.isNotEmpty && nationality != address) ...[
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 12.r, color: context.textMuted),
                      SizedBox(width: 4.w),
                      Text(
                        nationality,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: context.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20.r),
            onPressed: _isSaving ? null : () => _showDeleteConfirmDialog(index, address),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(int index, String address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
        title: Text(
          l10n.deletePlaceLivedTitle,
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '${l10n.deletePlaceLivedConfirm} "$address"',
          style: TextStyle(fontSize: 13.5.sp, color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: TextStyle(color: context.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deletePlace(index);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w800,
        color: context.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}
