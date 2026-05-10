import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/services/vietnam_regions_service.dart';
import '../../../../../di/injector.dart';
import '../../../address/domain/entities/shipping_address.dart';
import '../../../address/domain/entities/shipping_address_draft.dart';
import '../../../address/presentation/bloc/address_bloc.dart';
import '../../../address/presentation/bloc/address_event.dart';
import '../../../address/presentation/bloc/address_state.dart';
import '../../../cart/domain/entities/cart.dart';
import '../../../cart/presentation/bloc/cart_bloc.dart';
import '../../../cart/presentation/bloc/cart_event.dart';
import '../../../cart/presentation/bloc/cart_state.dart';
import '../../domain/entities/checkout_address.dart';
import '../../domain/entities/direct_order_args.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';
import '../bloc/checkout_state.dart';

class CheckoutScreen extends StatefulWidget {
  final DirectOrderArgs? directOrderArgs;

  const CheckoutScreen({
    super.key,
    this.directOrderArgs,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final CartBloc _cartBloc;
  late final CheckoutBloc _checkoutBloc;
  late final AddressBloc _addressBloc;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  ShippingAddress? _selectedAddress;
  String? _appliedVoucherCode;
  double _discountAmount = 0.0;
  final _voucherCodeCtrl = TextEditingController();
  String _paymentMethod = 'cod'; // 'cod', 'card', 'qr'
  final _cardNumberCtrl = TextEditingController();
  final _cardNameCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();
  final _cardFormKey = GlobalKey<FormState>();

  bool _manualProvince = false;
  bool _manualDistrict = false;
  bool _manualWard = false;

  int _selectedProvinceCode = -1;
  int _selectedDistrictCode = -1;
  bool _saveAddressForNextTime = true;

  @override
  void initState() {
    super.initState();
    _cartBloc = sl<CartBloc>()..add(const CartRequested());
    _checkoutBloc = sl<CheckoutBloc>();
    _addressBloc = sl<AddressBloc>()..add(const AddressListRequested());
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
    _cartBloc.close();
    _checkoutBloc.close();
    _addressBloc.close();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _provinceCtrl.dispose();
    _districtCtrl.dispose();
    _wardCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _voucherCodeCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardNameCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    super.dispose();
  }

  void _submit(Cart? cart) {
    final isDirect = widget.directOrderArgs != null;
    if (!isDirect && (cart == null || cart.isEmpty)) return;

    final selectedAddress = _selectedAddress;
    late final CheckoutAddress address;
    if (selectedAddress != null) {
      address = selectedAddress.toCheckoutAddress(paymentMethod: _paymentMethod);
    } else {
      if (!_formKey.currentState!.validate()) return;
      address = CheckoutAddress(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        province: _emptyToNull(_provinceCtrl.text),
        district: _emptyToNull(_districtCtrl.text),
        ward: _emptyToNull(_wardCtrl.text),
        addressLine: _addressCtrl.text.trim(),
        paymentMethod: _paymentMethod,
      );
      
      // Auto save manually typed address to address book if checkbox is active
      if (_saveAddressForNextTime) {
        _addressBloc.add(
          AddressSaved(
            ShippingAddressDraft(
              fullName: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              province: _provinceCtrl.text.trim(),
              district: _districtCtrl.text.trim(),
              ward: _wardCtrl.text.trim(),
              addressLine: _addressCtrl.text.trim(),
              isDefault: true,
            ),
          ),
        );
      }
    }

    // Validate credit card info if Card is selected
    if (_paymentMethod == 'card') {
      if (!_cardFormKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng điền đầy đủ và đúng thông tin thẻ thanh toán!'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (_paymentMethod == 'cod') {
      _executeOrderPlacement(address);
    } else {
      _showPaymentProcessingDialog(address);
    }
  }

  void _executeOrderPlacement(CheckoutAddress address) {
    final isDirect = widget.directOrderArgs != null;
    final paymentLabel = _paymentMethod == 'cod'
        ? 'Tiền mặt (COD)'
        : (_paymentMethod == 'card' ? 'Thẻ Visa/Mastercard' : 'QR Chuyển khoản');

    final rawNote = _noteCtrl.text.trim();
    final customNote = rawNote.isEmpty
        ? '[Thanh toán: $paymentLabel]'
        : '[Thanh toán: $paymentLabel] $rawNote';

    if (isDirect) {
      _checkoutBloc.add(
        CheckoutDirectOrderRequested(
          address: address,
          productId: widget.directOrderArgs!.product.id,
          variantId: widget.directOrderArgs!.selectedVariant?.id,
          qty: widget.directOrderArgs!.qty,
          note: customNote,
          discountAmount: _discountAmount,
        ),
      );
    } else {
      _checkoutBloc.add(
        CheckoutPlaceOrderRequested(
          address: address,
          note: customNote,
          discountAmount: _discountAmount,
        ),
      );
    }
  }

  void _showPaymentProcessingDialog(CheckoutAddress address) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SimulatedPaymentDialog(
        paymentMethod: _paymentMethod,
        onSuccess: () => _executeOrderPlacement(address),
      ),
    );
  }

  Future<void> _openAddressManager() async {
    await context.push('/addresses');
    if (mounted) {
      _addressBloc.add(const AddressListRequested());
    }
  }

  void _syncSelectedAddress(List<ShippingAddress> addresses) {
    if (addresses.isEmpty) {
      if (_selectedAddress != null) {
        setState(() => _selectedAddress = null);
      }
      return;
    }

    final current = _selectedAddress;
    final next = current != null && addresses.any((item) => item.id == current.id)
        ? addresses.firstWhere((item) => item.id == current.id)
        : addresses.firstWhere(
            (item) => item.isDefault,
            orElse: () => addresses.first,
          );

    if (_selectedAddress?.id != next.id ||
        _selectedAddress?.isDefault != next.isDefault) {
      setState(() => _selectedAddress = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cartBloc),
        BlocProvider.value(value: _checkoutBloc),
        BlocProvider.value(value: _addressBloc),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<CheckoutBloc, CheckoutState>(
            listener: (context, state) {
              if (state is CheckoutFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              }

              if (state is CheckoutSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đặt hàng thành công: ${state.result.orderCodes.join(', ')}',
                    ),
                  ),
                );
                context.go('/orders');
              }
            },
          ),
          BlocListener<AddressBloc, AddressState>(
            listener: (context, state) {
              if (state is AddressLoaded) {
                _syncSelectedAddress(state.addresses);
              } else if (state is AddressSaveSuccess) {
                _addressBloc.add(const AddressListRequested());
              }
            },
          ),
        ],
        child: BlocBuilder<CartBloc, CartState>(
          builder: (context, cartState) {
            final cart = cartState is CartLoaded ? cartState.cart : null;
            return Scaffold(
              backgroundColor: const Color(0xFFF5F5F5),
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0,
                title: const Text(
                  'Thanh toán',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              body: widget.directOrderArgs != null 
                  ? _buildDirectBody(widget.directOrderArgs!)
                  : _buildBody(cartState),
              bottomNavigationBar: widget.directOrderArgs != null
                  ? BlocBuilder<CheckoutBloc, CheckoutState>(
                      builder: (context, checkoutState) {
                        return _CheckoutBar(
                          totalAmount: (_calculateDirectSubtotal(widget.directOrderArgs!) - _discountAmount).clamp(0.0, double.infinity),
                          currency: widget.directOrderArgs!.product.currency,
                          isSubmitting: checkoutState is CheckoutSubmitting,
                          onSubmit: () => _submit(cart),
                        );
                      },
                    )
                  : cart == null
                      ? null
                      : BlocBuilder<CheckoutBloc, CheckoutState>(
                          builder: (context, checkoutState) {
                            return _CheckoutBar(
                              totalAmount: (cart.subtotal - _discountAmount).clamp(0.0, double.infinity),
                              currency: cart.currency,
                              isSubmitting: checkoutState is CheckoutSubmitting,
                              onSubmit: () => _submit(cart),
                            );
                          },
                        ),
            );
          },
        ),
      ),
    );
  }

  double _calculateDirectSubtotal(DirectOrderArgs args) {
    final unitPrice = args.selectedVariant != null
        ? args.selectedVariant!.price
        : args.product.priceMin;
    return args.qty * unitPrice;
  }

  Widget _buildDirectBody(DirectOrderArgs args) {
    return BlocBuilder<AddressBloc, AddressState>(
      builder: (context, addressState) {
        final unitPrice = args.selectedVariant != null
            ? args.selectedVariant!.price
            : args.product.priceMin;
        final subtotal = args.qty * unitPrice;

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md,
              AppSizes.md,
              AppSizes.md,
              120,
            ),
            children: [
              _ShippingAddressSection(
                addressState: addressState,
                selectedAddress: _selectedAddress,
                onManage: _openAddressManager,
                manualForm: _ManualAddressForm(
                  nameCtrl: _nameCtrl,
                  phoneCtrl: _phoneCtrl,
                  provinceCtrl: _provinceCtrl,
                  districtCtrl: _districtCtrl,
                  wardCtrl: _wardCtrl,
                  addressCtrl: _addressCtrl,
                  requiredValidator: _required,
                  manualProvince: _manualProvince,
                  manualDistrict: _manualDistrict,
                  manualWard: _manualWard,
                  onProvinceTap: _onProvinceTap,
                  onDistrictTap: _onDistrictTap,
                  onWardTap: _onWardTap,
                  saveAddress: _saveAddressForNextTime,
                  onSaveAddressChanged: (val) {
                    setState(() {
                      _saveAddressForNextTime = val ?? true;
                    });
                  },
                ),
              ),
              const SizedBox(height: AppSizes.md),
              _SectionCard(
                title: 'Sản phẩm',
                child: _CheckoutItemRow(
                  title: args.product.title,
                  variant: args.selectedVariant?.variantName ?? args.selectedVariant?.sku,
                  qty: args.qty,
                  amount: subtotal,
                  currency: args.product.currency,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              _buildVoucherSection(subtotal),
              const SizedBox(height: AppSizes.md),
              _buildPaymentMethodSection(subtotal - _discountAmount),
              const SizedBox(height: AppSizes.md),
              _buildPriceBreakdownSection(subtotal, args.product.currency),
              const SizedBox(height: AppSizes.md),
              _SectionCard(
                title: 'Ghi chú',
                child: _CheckoutField(
                  controller: _noteCtrl,
                  label: 'Tin nhắn cho người bán',
                  maxLines: 3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(CartState state) {
    if (state is CartInitial || state is CartLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is CartFailure) {
      return _StateMessage(
        icon: Icons.error_outline_rounded,
        title: state.message,
        actionLabel: 'Thử lại',
        onAction: () => _cartBloc.add(const CartRequested()),
      );
    }

    if (state is! CartLoaded) return const SizedBox.shrink();

    if (state.cart.isEmpty) {
      return _StateMessage(
        icon: Icons.shopping_cart_outlined,
        title: 'Giỏ hàng của bạn đang trống',
        actionLabel: 'Tiếp tục mua sắm',
        onAction: () => context.go('/ecommerce'),
      );
    }

    final subtotal = state.cart.subtotal;

    return BlocBuilder<AddressBloc, AddressState>(
      builder: (context, addressState) {
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md,
              AppSizes.md,
              AppSizes.md,
              120,
            ),
            children: [
              _ShippingAddressSection(
                addressState: addressState,
                selectedAddress: _selectedAddress,
                onManage: _openAddressManager,
                manualForm: _ManualAddressForm(
                  nameCtrl: _nameCtrl,
                  phoneCtrl: _phoneCtrl,
                  provinceCtrl: _provinceCtrl,
                  districtCtrl: _districtCtrl,
                  wardCtrl: _wardCtrl,
                  addressCtrl: _addressCtrl,
                  requiredValidator: _required,
                  manualProvince: _manualProvince,
                  manualDistrict: _manualDistrict,
                  manualWard: _manualWard,
                  onProvinceTap: _onProvinceTap,
                  onDistrictTap: _onDistrictTap,
                  onWardTap: _onWardTap,
                  saveAddress: _saveAddressForNextTime,
                  onSaveAddressChanged: (val) {
                    setState(() {
                      _saveAddressForNextTime = val ?? true;
                    });
                  },
                ),
              ),
              const SizedBox(height: AppSizes.md),
              _SectionCard(
                title: 'Sản phẩm',
                child: Column(
                  children: state.cart.items.map((item) {
                    return _CheckoutItemRow(
                      title: item.title,
                      variant: item.variantName,
                      qty: item.qty,
                      amount: item.subtotal,
                      currency: item.currency,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              _buildVoucherSection(subtotal),
              const SizedBox(height: AppSizes.md),
              _buildPaymentMethodSection(subtotal - _discountAmount),
              const SizedBox(height: AppSizes.md),
              _buildPriceBreakdownSection(subtotal, state.cart.currency),
              const SizedBox(height: AppSizes.md),
              _SectionCard(
                title: 'Ghi chú',
                child: _CheckoutField(
                  controller: _noteCtrl,
                  label: 'Tin nhắn cho người bán',
                  maxLines: 3,
                ),
              ),
            ],
          ),
        );
      },
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

  void _applyVoucher(String code, double currentSubtotal) {
    final cleanCode = code.trim().toUpperCase();
    double discount = 0.0;
    String message = '';

    if (cleanCode == 'SHARECOSALE10') {
      discount = (currentSubtotal * 0.1);
      message = 'Đã áp dụng mã giảm giá 10%!';
    } else if (cleanCode == 'SHARECOVIP') {
      discount = 50000.0;
      message = 'Đã áp dụng mã giảm giá 50.000đ!';
    } else if (cleanCode == 'DEALKHUNG') {
      if (currentSubtotal < 200000.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã DEALKHUNG chỉ áp dụng cho đơn hàng từ 200.0k trở lên!'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      discount = 100000.0;
      message = 'Đã áp dụng mã giảm giá 100.000đ!';
    } else if (cleanCode == 'FREESHIP') {
      discount = 30000.0;
      message = 'Đã áp dụng mã miễn phí vận chuyển 30.000đ!';
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã giảm giá không tồn tại hoặc đã hết hạn!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _appliedVoucherCode = cleanCode;
      _discountAmount = discount.clamp(0.0, currentSubtotal);
      _voucherCodeCtrl.text = cleanCode;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _removeVoucher() {
    setState(() {
      _appliedVoucherCode = null;
      _discountAmount = 0.0;
      _voucherCodeCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã hủy áp dụng mã giảm giá'),
      ),
    );
  }

  void _showVoucherListBottomSheet(double currentSubtotal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final availableVouchers = [
              {
                'code': 'SHARECOSALE10',
                'title': 'Giảm 10% đơn hàng',
                'desc': 'Áp dụng cho mọi giá trị đơn hàng',
                'icon': Icons.percent_rounded,
                'color': Colors.amber,
              },
              {
                'code': 'SHARECOVIP',
                'title': 'Giảm ngay 50.000đ',
                'desc': 'Voucher tri ân đặc biệt cho thành viên VIP',
                'icon': Icons.stars_rounded,
                'color': Colors.red,
              },
              {
                'code': 'DEALKHUNG',
                'title': 'Siêu ưu đãi giảm 100.000đ',
                'desc': 'Áp dụng cho hóa đơn từ 200.0k trở lên',
                'icon': Icons.bolt_rounded,
                'color': Colors.purple,
                'minSubtotal': 200000.0,
              },
              {
                'code': 'FREESHIP',
                'title': 'Freeship tối đa 30.000đ',
                'desc': 'Áp dụng cho mọi đơn vận chuyển',
                'icon': Icons.local_shipping_rounded,
                'color': Colors.teal,
              },
            ];

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSizes.md),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chọn Voucher ưu đãi 🎟️',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _voucherCodeCtrl,
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Nhập mã giảm giá khác...',
                              prefixIcon: const Icon(Icons.confirmation_num_outlined, color: AppColors.primary),
                              filled: true,
                              fillColor: const Color(0xFFF6F6F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        ElevatedButton(
                          onPressed: () {
                            if (_voucherCodeCtrl.text.trim().isEmpty) return;
                            Navigator.pop(context);
                            _applyVoucher(_voucherCodeCtrl.text, currentSubtotal);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                            ),
                            minimumSize: const Size(90, 48),
                          ),
                          child: const Text('Áp dụng', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    const Text(
                      'MÃ GIẢM GIÁ KHUYẾN NGHỊ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.black45,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Expanded(
                      child: ListView.builder(
                        itemCount: availableVouchers.length,
                        itemBuilder: (context, index) {
                          final v = availableVouchers[index];
                          final code = v['code'] as String;
                          final isSelected = _appliedVoucherCode == code;

                          return _VoucherCouponCard(
                            code: code,
                            title: v['title'] as String,
                            subtitle: v['desc'] as String,
                            icon: v['icon'] as IconData,
                            color: v['color'] as Color,
                            minSubtotal: v['minSubtotal'] as double?,
                            currentSubtotal: currentSubtotal,
                            isSelected: isSelected,
                            onTap: () {
                              setModalState(() {});
                              Navigator.pop(context);
                              _applyVoucher(code, currentSubtotal);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVoucherSection(double currentSubtotal) {
    return _SectionCard(
      title: 'Khuyến mãi & Voucher',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showVoucherListBottomSheet(currentSubtotal),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(
                  color: _appliedVoucherCode != null ? AppColors.primary.withOpacity(0.5) : Colors.black12,
                  width: _appliedVoucherCode != null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.confirmation_num_outlined,
                    color: _appliedVoucherCode != null ? AppColors.primary : Colors.black54,
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _appliedVoucherCode != null
                            ? Text(
                                'Đang áp dụng: $_appliedVoucherCode',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  fontSize: 14,
                                ),
                              )
                            : const Text(
                                'Chọn hoặc nhập mã giảm giá',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                        const SizedBox(height: 2),
                        Text(
                          _appliedVoucherCode != null
                              ? 'Bạn đã được giảm -${_formatAmount(_discountAmount, "VND")}'
                              : 'Nhận ưu đãi tối đa lên tới 100K',
                          style: TextStyle(
                            color: _appliedVoucherCode != null ? AppColors.success : Colors.black45,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Chọn',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_appliedVoucherCode != null) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                  const SizedBox(width: AppSizes.xs),
                  Expanded(
                    child: Text(
                      'Đang giảm: -${_formatAmount(_discountAmount, "VND")}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _removeVoucher,
                    child: const Icon(Icons.cancel, color: Colors.black45, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownSection(double subtotal, String currency) {
    final finalTotal = (subtotal - _discountAmount).clamp(0.0, double.infinity);
    return _SectionCard(
      title: 'Chi tiết thanh toán',
      child: Column(
        children: [
          _buildPriceRow('Tổng tiền hàng', _formatAmount(subtotal, currency)),
          if (_discountAmount > 0) ...[
            const SizedBox(height: AppSizes.sm),
            _buildPriceRow(
              'Giảm giá Voucher',
              '- ${_formatAmount(_discountAmount, currency)}',
              valueColor: AppColors.success,
              valueWeight: FontWeight.bold,
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          _buildPriceRow('Phí vận chuyển', 'Miễn phí', valueColor: AppColors.success),
          const Divider(height: 24),
          _buildPriceRow(
            'Tổng thanh toán',
            _formatAmount(finalTotal, currency),
            isTotal: true,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.black87 : Colors.black54,
            fontSize: isTotal ? AppSizes.fontXl : AppSizes.fontMd,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? (isTotal ? AppColors.primary : Colors.black87),
            fontSize: isTotal ? AppSizes.fontXl : AppSizes.fontMd,
            fontWeight: valueWeight ?? (isTotal ? FontWeight.w900 : FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection(double currentTotal) {
    return _SectionCard(
      title: 'Phương thức thanh toán',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaymentOptionTile(
            method: 'cod',
            icon: Icons.local_shipping_outlined,
            title: 'Thanh toán khi nhận hàng (COD)',
            subtitle: 'Thanh toán bằng tiền mặt khi shipper giao hàng',
          ),
          const Divider(height: 16),
          _buildPaymentOptionTile(
            method: 'card',
            icon: Icons.credit_card,
            title: 'Thẻ Tín dụng / ATM nội địa',
            subtitle: 'Hỗ trợ Visa, MasterCard, JCB và thẻ ngân hàng',
          ),
          if (_paymentMethod == 'card') ...[
            const SizedBox(height: AppSizes.md),
            _buildVirtualCreditCard(),
            const SizedBox(height: AppSizes.md),
            _buildCreditCardForm(),
          ],
          const Divider(height: 16),
          _buildPaymentOptionTile(
            method: 'qr',
            icon: Icons.qr_code_scanner,
            title: 'Chuyển khoản / Quét mã QR',
            subtitle: 'Tạo mã VietQR động để quét bằng ví & app ngân hàng',
          ),
          if (_paymentMethod == 'qr') ...[
            const SizedBox(height: AppSizes.md),
            _buildVietQrSection(currentTotal),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentOptionTile({
    required String method,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _paymentMethod == method;
    return InkWell(
      onTap: () {
        setState(() {
          _paymentMethod = method;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.black45,
              size: 28,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? Colors.black87 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: method,
              groupValue: _paymentMethod,
              activeColor: AppColors.primary,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _paymentMethod = val;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualCreditCard() {
    return Container(
      width: double.infinity,
      height: 195,
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PREMIUM PLATINUM',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              Icon(
                Icons.credit_card,
                color: Colors.white.withOpacity(0.9),
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          const Icon(
            Icons.nfc_outlined,
            color: Colors.white70,
            size: 32,
          ),
          const Spacer(),
          Text(
            _cardNumberCtrl.text.isEmpty ? '•••• •••• •••• ••••' : _formatCardNumber(_cardNumberCtrl.text),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CARDHOLDER',
                    style: TextStyle(color: Colors.white38, fontSize: 8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cardNameCtrl.text.isEmpty ? 'HỌ VÀ TÊN CHỦ THẺ' : _cardNameCtrl.text.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(color: Colors.white38, fontSize: 8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cardExpiryCtrl.text.isEmpty ? 'MM/YY' : _cardExpiryCtrl.text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCardNumber(String value) {
    var v = value.replaceAll(' ', '');
    var buffer = StringBuffer();
    for (int i = 0; i < v.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(v[i]);
    }
    return buffer.toString();
  }

  Widget _buildCreditCardForm() {
    return Form(
      key: _cardFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _cardNumberCtrl,
            keyboardType: TextInputType.number,
            maxLength: 19,
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              labelText: 'Số thẻ',
              hintText: '4242 4242 4242 4242',
              prefixIcon: Icon(Icons.credit_card),
              counterText: '',
            ),
            validator: (v) => (v == null || v.trim().length < 15) ? 'Số thẻ không hợp lệ' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSizes.sm),
          TextFormField(
            controller: _cardNameCtrl,
            keyboardType: TextInputType.name,
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              labelText: 'Tên chủ thẻ',
              hintText: 'NGUYEN VAN A',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cardExpiryCtrl,
                  keyboardType: TextInputType.datetime,
                  maxLength: 5,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(
                    labelText: 'Hết hạn (MM/YY)',
                    hintText: '12/28',
                    prefixIcon: Icon(Icons.date_range_outlined),
                    counterText: '',
                  ),
                  validator: (v) => (v == null || !v.contains('/')) ? 'Sai định dạng' : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: TextFormField(
                  controller: _cardCvvCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                    prefixIcon: Icon(Icons.lock_outline),
                    counterText: '',
                  ),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Sai CVV' : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVietQrSection(double currentTotal) {
    final formatTotal = _formatAmount(currentTotal, 'VND');
    final mockOrderCode = 'DH${DateFormat('yyMMddHHmm').format(DateTime.now())}';

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          const Text(
            'QUÉT MÃ VIETQR ĐỂ CHUYỂN KHOẢN',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Container(
                  width: 170,
                  height: 170,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Opacity(
                        opacity: 0.85,
                        child: Icon(
                          Icons.qr_code_2,
                          size: 155,
                          color: Color(0xFF1F1C2C),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.qr_code_scanner, color: AppColors.success, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Tự động đồng bộ trạng thái thanh toán',
                      style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          _buildInfoRow('Ngân hàng thụ hưởng', 'MB Bank (Ngân hàng Quân Đội)'),
          _buildInfoRow('Tên chủ tài khoản', 'SHARECO CORPORATION'),
          _buildInfoRow('Số tài khoản', '0395 123 4567'),
          _buildInfoRow('Số tiền chuyển', formatTotal, isHighlighted: true),
          _buildInfoRow('Nội dung chuyển khoản', mockOrderCode, isHighlighted: true),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Hệ thống sẽ tự động phê duyệt ngay khi nhận được giao dịch.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.black38, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? AppColors.primary : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimulatedPaymentDialog extends StatefulWidget {
  final String paymentMethod;
  final VoidCallback onSuccess;

  const _SimulatedPaymentDialog({
    required this.paymentMethod,
    required this.onSuccess,
  });

  @override
  State<_SimulatedPaymentDialog> createState() => _SimulatedPaymentDialogState();
}

class _SimulatedPaymentDialogState extends State<_SimulatedPaymentDialog> {
  int _step = 0; // 0: connecting, 1: processing, 2: success

  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  void _startSimulation() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _step = 1);
      }
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _step = 2);
        }
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            widget.onSuccess();
          }
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = '';
    Widget content = const SizedBox.shrink();

    if (_step == 0) {
      title = 'Đang kết nối...';
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSizes.md),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppSizes.md),
          Text(
            widget.paymentMethod == 'card'
                ? 'Đang kết nối cổng thanh toán an toàn 3D Secure...'
                : 'Đang kết nối ngân hàng để lấy mã VietQR bảo mật...',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      );
    } else if (_step == 1) {
      title = widget.paymentMethod == 'card' ? 'Đang xác thực...' : 'Đang xử lý giao dịch...';
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSizes.md),
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.success,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            widget.paymentMethod == 'card'
                ? 'Đang kiểm tra số dư và mã hóa thông tin thẻ...'
                : 'Đang xác nhận thông tin chuyển khoản từ ngân hàng...',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      );
    } else {
      title = 'Thanh toán thành công!';
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSizes.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xE8D1F2D9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 56,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Giao dịch được phê duyệt thành công!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
          ),
          const SizedBox(height: 4),
          const Text(
            'Đơn hàng đang được khởi tạo...',
            style: TextStyle(color: Colors.black45, fontSize: 12),
          ),
        ],
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: content,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: AppSizes.fontXl,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}

class _CheckoutField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;

  const _CheckoutField({
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

class _CheckoutItemRow extends StatelessWidget {
  final String title;
  final String? variant;
  final int qty;
  final double amount;
  final String currency;

  const _CheckoutItemRow({
    required this.title,
    this.variant,
    required this.qty,
    required this.amount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (variant != null && variant!.isNotEmpty)
                  Text(
                    variant!,
                    style: const TextStyle(color: Colors.black45),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Text(
            'x$qty',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(width: AppSizes.md),
          Text(
            _formatAmount(amount, currency),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final double totalAmount;
  final String currency;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _CheckoutBar({
    required this.totalAmount,
    required this.currency,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng thanh toán',
                    style: TextStyle(
                      color: Colors.black45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _formatAmount(totalAmount, currency),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(132, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Đặt hàng',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textMuted, size: 48),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: AppSizes.fontXl,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatAmount(double amount, String currency) {
  final formatter = NumberFormat.decimalPattern('vi_VN');
  return '${formatter.format(amount)} $currency';
}

class _ManualAddressForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController provinceCtrl;
  final TextEditingController districtCtrl;
  final TextEditingController wardCtrl;
  final TextEditingController addressCtrl;
  final String? Function(String?) requiredValidator;
  final bool manualProvince;
  final bool manualDistrict;
  final bool manualWard;
  final VoidCallback onProvinceTap;
  final VoidCallback onDistrictTap;
  final VoidCallback onWardTap;
  final bool saveAddress;
  final ValueChanged<bool?> onSaveAddressChanged;

  const _ManualAddressForm({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.provinceCtrl,
    required this.districtCtrl,
    required this.wardCtrl,
    required this.addressCtrl,
    required this.requiredValidator,
    required this.manualProvince,
    required this.manualDistrict,
    required this.manualWard,
    required this.onProvinceTap,
    required this.onDistrictTap,
    required this.onWardTap,
    required this.saveAddress,
    required this.onSaveAddressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CheckoutField(controller: nameCtrl, label: 'Họ và tên', validator: requiredValidator),
        const SizedBox(height: AppSizes.sm),
        _CheckoutField(controller: phoneCtrl, label: 'Số điện thoại', keyboardType: TextInputType.phone, validator: requiredValidator),
        const SizedBox(height: AppSizes.sm),
        Row(
          children: [
            Expanded(
              child: _CheckoutField(
                controller: provinceCtrl,
                label: 'Tỉnh/Thành phố',
                validator: requiredValidator,
                readOnly: !manualProvince,
                onTap: onProvinceTap,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: _CheckoutField(
                controller: districtCtrl,
                label: 'Quận/Huyện',
                validator: requiredValidator,
                readOnly: !manualDistrict,
                onTap: onDistrictTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        _CheckoutField(
          controller: wardCtrl,
          label: 'Phường/Xã',
          validator: requiredValidator,
          readOnly: !manualWard,
          onTap: onWardTap,
        ),
        const SizedBox(height: AppSizes.sm),
        _CheckoutField(controller: addressCtrl, label: 'Địa chỉ cụ thể', validator: requiredValidator),
        const SizedBox(height: AppSizes.md),
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: saveAddress,
                onChanged: onSaveAddressChanged,
                activeColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            const Expanded(
              child: Text(
                'Lưu địa chỉ này để dùng cho lần sau',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShippingAddressSection extends StatelessWidget {
  final AddressState addressState;
  final ShippingAddress? selectedAddress;
  final VoidCallback onManage;
  final Widget manualForm;

  const _ShippingAddressSection({
    required this.addressState,
    required this.selectedAddress,
    required this.onManage,
    required this.manualForm,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Địa chỉ giao hàng',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (addressState is AddressLoading)
            const Center(child: CircularProgressIndicator())
          else if (addressState is AddressLoaded && (addressState as AddressLoaded).addresses.isNotEmpty)
            ...[
              if (selectedAddress != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${selectedAddress!.fullName} | ${selectedAddress!.phone}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${selectedAddress!.addressLine}, ${selectedAddress!.ward ?? ''}, ${selectedAddress!.district ?? ''}, ${selectedAddress!.province ?? ''}'),
                  ],
                ),
              const SizedBox(height: AppSizes.sm),
              OutlinedButton(
                onPressed: onManage,
                child: const Text('Thay đổi địa chỉ'),
              ),
            ]
          else
            manualForm,
        ],
      ),
    );
  }
}

class _VoucherCouponCard extends StatelessWidget {
  final String code;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double? minSubtotal;
  final double currentSubtotal;
  final bool isSelected;
  final VoidCallback onTap;

  const _VoucherCouponCard({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.minSubtotal,
    required this.currentSubtotal,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEligible = minSubtotal == null || currentSubtotal >= minSubtotal!;
    final double opacity = isEligible ? 1.0 : 0.55;

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 104,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isSelected ? color : Colors.black12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              // Left part with icon and color gradient
              Container(
                width: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      code.length > 9 ? code.substring(0, 9) : code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Dashed line or separator
              CustomPaint(
                size: const Size(1, double.infinity),
                painter: _TicketSeparatorPainter(color: isSelected ? color : Colors.black12),
              ),
              // Right part with details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isEligible && minSubtotal != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Mua thêm ${_formatAmount(minSubtotal! - currentSubtotal, "VND")} để dùng',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Action area
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check, color: color, size: 16),
                            )
                          else
                            ElevatedButton(
                              onPressed: isEligible ? onTap : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isEligible ? color : Colors.grey[300],
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: const Size(64, 28),
                              ),
                              child: Text(
                                isEligible ? 'Dùng' : 'Khóa',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketSeparatorPainter extends CustomPainter {
  final Color color;
  _TicketSeparatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const double dashHeight = 4;
    const double dashSpace = 3;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
