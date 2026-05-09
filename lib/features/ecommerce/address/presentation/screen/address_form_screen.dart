import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/constants/vietnam_regions.dart';
import '../../../../../core/services/vietnam_regions_service.dart';
import '../../../../../di/injector.dart';
import '../../domain/entities/shipping_address.dart';
import '../../domain/entities/shipping_address_draft.dart';
import '../bloc/address_bloc.dart';
import '../bloc/address_event.dart';
import '../bloc/address_state.dart';

class AddressFormScreen extends StatefulWidget {
  final ShippingAddress? address;

  const AddressFormScreen({
    super.key,
    this.address,
  });

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  late final AddressBloc _bloc;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  bool _isDefault = false;

  bool _manualProvince = false;
  bool _manualDistrict = false;
  bool _manualWard = false;

  int _selectedProvinceCode = -1;
  int _selectedDistrictCode = -1;

  bool get _isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    _bloc = sl<AddressBloc>();
    final address = widget.address;
    if (address != null) {
      _nameCtrl.text = address.fullName;
      _phoneCtrl.text = address.phone;
      _provinceCtrl.text = address.province ?? '';
      _districtCtrl.text = address.district ?? '';
      _wardCtrl.text = address.ward ?? '';
      _addressCtrl.text = address.addressLine;
      _postalCtrl.text = address.postalCode ?? '';
      _isDefault = address.isDefault;

      if (_provinceCtrl.text.isNotEmpty) {
        _manualProvince = !vietnamRegions.containsKey(_provinceCtrl.text);
      }
      if (_districtCtrl.text.isNotEmpty && !_manualProvince) {
        final dists = vietnamRegions[_provinceCtrl.text];
        _manualDistrict = dists == null || !dists.containsKey(_districtCtrl.text);
      }
      if (_wardCtrl.text.isNotEmpty && !_manualDistrict) {
        final dists = vietnamRegions[_provinceCtrl.text];
        final wards = dists?[_districtCtrl.text];
        _manualWard = wards == null || !wards.contains(_wardCtrl.text);
      }
    }
  }

  void _showAsyncRegionPicker({
    required String title,
    required Future<List<Map<String, dynamic>>> Function() fetcher,
    required void Function(String name, int code) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: fetcher(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSizes.lg),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSizes.lg),
                          child: Text(
                            'Không tải được dữ liệu, vui lòng thử lại!',
                            style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }

                    final items = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final name = item['name'] as String;
                        final code = item['code'] as int;
                        return ListTile(
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onSelected(name, code);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onProvinceTap() {
    if (_manualProvince) return;
    _showAsyncRegionPicker(
      title: 'Chọn Tỉnh / Thành phố',
      fetcher: () => VietnamRegionsService.getProvinces(),
      onSelected: (name, code) {
        if (name == 'Khác (Nhập thủ công)') {
          setState(() {
            _manualProvince = true;
            _manualDistrict = true;
            _manualWard = true;
            _provinceCtrl.clear();
            _districtCtrl.clear();
            _wardCtrl.clear();
            _selectedProvinceCode = -1;
            _selectedDistrictCode = -1;
          });
        } else {
          setState(() {
            _provinceCtrl.text = name;
            _districtCtrl.clear();
            _wardCtrl.clear();
            _manualProvince = false;
            _manualDistrict = false;
            _manualWard = false;
            _selectedProvinceCode = code;
            _selectedDistrictCode = -1;
          });
          _onDistrictTap();
        }
      },
    );
  }

  void _onDistrictTap() {
    if (_manualDistrict) return;
    if (_provinceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Tỉnh / Thành phố trước!')),
      );
      return;
    }
    _showAsyncRegionPicker(
      title: 'Chọn Quận / Huyện',
      fetcher: () => VietnamRegionsService.getDistricts(_provinceCtrl.text, _selectedProvinceCode),
      onSelected: (name, code) {
        setState(() {
          _districtCtrl.text = name;
          _wardCtrl.clear();
          _manualDistrict = false;
          _manualWard = false;
          _selectedDistrictCode = code;
        });
        _onWardTap();
      },
    );
  }

  void _onWardTap() {
    if (_manualWard) return;
    if (_districtCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Quận / Huyện trước!')),
      );
      return;
    }
    _showAsyncRegionPicker(
      title: 'Chọn Phường / Xã',
      fetcher: () => VietnamRegionsService.getWards(_provinceCtrl.text, _districtCtrl.text, _selectedDistrictCode),
      onSelected: (name, code) {
        setState(() {
          _wardCtrl.text = name;
          _manualWard = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _bloc.close();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _provinceCtrl.dispose();
    _districtCtrl.dispose();
    _wardCtrl.dispose();
    _addressCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    _bloc.add(
      AddressSaved(
        ShippingAddressDraft(
          id: widget.address?.id,
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          province: _emptyToNull(_provinceCtrl.text),
          district: _emptyToNull(_districtCtrl.text),
          ward: _emptyToNull(_wardCtrl.text),
          addressLine: _addressCtrl.text.trim(),
          postalCode: _emptyToNull(_postalCtrl.text),
          isDefault: _isDefault,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<AddressBloc, AddressState>(
        listener: (context, state) {
          if (state is AddressFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          if (state is AddressSaveSuccess) {
            context.pop(true);
          }
        },
        builder: (context, state) {
          final isSaving = state is AddressSaving;
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              title: Text(
                _isEditing ? 'Sửa địa chỉ' : 'Thêm địa chỉ',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.md),
                children: [
                  _FormCard(
                    child: Column(
                      children: [
                        _AddressField(
                          controller: _nameCtrl,
                          label: 'Họ và tên',
                          validator: _required,
                        ),
                        const SizedBox(height: AppSizes.md),
                        _AddressField(
                          controller: _phoneCtrl,
                          label: 'Số điện thoại',
                          keyboardType: TextInputType.phone,
                          validator: _required,
                        ),
                        const SizedBox(height: AppSizes.md),
                        _AddressField(
                          controller: _provinceCtrl,
                          label: 'Tỉnh / Thành phố',
                          readOnly: !_manualProvince,
                          onTap: _onProvinceTap,
                          validator: _required,
                        ),
                        const SizedBox(height: AppSizes.md),
                        Row(
                          children: [
                            Expanded(
                              child: _AddressField(
                                controller: _districtCtrl,
                                label: 'Quận / Huyện',
                                readOnly: !_manualDistrict,
                                onTap: _onDistrictTap,
                                validator: _required,
                              ),
                            ),
                            const SizedBox(width: AppSizes.md),
                            Expanded(
                              child: _AddressField(
                                controller: _wardCtrl,
                                label: 'Phường / Xã',
                                readOnly: !_manualWard,
                                onTap: _onWardTap,
                                validator: _required,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.md),
                        _AddressField(
                          controller: _addressCtrl,
                          label: 'Địa chỉ cụ thể',
                          maxLines: 2,
                          validator: _required,
                        ),
                        const SizedBox(height: AppSizes.md),
                        _AddressField(
                          controller: _postalCtrl,
                          label: 'Mã bưu chính',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSizes.sm),
                        SwitchListTile(
                          value: _isDefault,
                          onChanged: (value) {
                            setState(() => _isDefault = value);
                          },
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primary,
                          title: const Text(
                            'Đặt làm địa chỉ mặc định',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
                ),
                child: ElevatedButton(
                  onPressed: isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Lưu địa chỉ',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Bắt buộc';
    return null;
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: child,
    );
  }
}

class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;

  const _AddressField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF6F6F6),
        suffixIcon: readOnly ? const Icon(Icons.arrow_drop_down, color: Colors.black54) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}
