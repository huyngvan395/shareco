import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/services/supabase/index.dart';
import '../../../../../core/utils/storage_image.dart';
import '../../../../../di/injector.dart';
import '../../../../chat/domain/usecases/chat_usecases.dart';
import '../../../order/domain/entities/ecommerce_order.dart';
import '../../../order/presentation/widgets/order_formatters.dart';
import '../../../order/presentation/widgets/order_status_badge.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/shop_repository.dart';
import '../widgets/seller_ui_kit.dart';
import 'seller_product_form_screen.dart';
import 'seller_registration_screen.dart';

/// Kênh Người Bán: tổng quan, xử lý đơn & vận chuyển, sản phẩm, cài đặt shop/kho.
class SellerCenterScreen extends StatefulWidget {
  final String? initialShopId;
  final int initialTabIndex;

  const SellerCenterScreen({
    super.key,
    this.initialShopId,
    this.initialTabIndex = 0,
  });

  @override
  State<SellerCenterScreen> createState() => _SellerCenterScreenState();
}

class _SellerCenterScreenState extends State<SellerCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  ShopRepository get _repo => sl<ShopRepository>();

  bool _loadingShops = true;
  List<Shop> _shops = const [];
  Shop? _shop;

  bool _loadingOrders = false;
  List<EcommerceOrder> _orders = const [];
  String? _orderFilter;

  bool _loadingProducts = false;
  List<Product> _products = const [];
  String _productFilter = 'all';
  String _productQuery = '';

  final Set<String> _busyOrders = {};
  RealtimeChannel? _ordersChannel;
  Timer? _realtimeDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _loadShops();
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  // ───────────────────────── DATA ─────────────────────────

  Future<void> _loadShops({String? preferId}) async {
    setState(() => _loadingShops = true);
    final res = await _repo.getMyShops();
    if (!mounted) return;
    res.fold(
      (f) => _toast(f.message, error: true),
      (shops) => _shops = shops,
    );
    final targetId = preferId ?? _shop?.id ?? widget.initialShopId;
    Shop? selected;
    if (_shops.isNotEmpty) {
      selected = _shops.firstWhere(
        (s) => s.id == targetId,
        orElse: () => _shops.first,
      );
    }
    setState(() {
      _loadingShops = false;
      _shop = selected;
    });
    if (selected != null) {
      _subscribe(selected.id);
      await Future.wait([_loadOrders(), _loadProducts()]);
    }
  }

  Future<void> _loadOrders({bool silent = false}) async {
    final shop = _shop;
    if (shop == null) return;
    if (!silent) setState(() => _loadingOrders = true);
    final res = await _repo.getShopOrders(shopId: shop.id);
    if (!mounted) return;
    res.fold(
      (f) => _toast('Không tải được đơn hàng: ${f.message}', error: true),
      (list) => _orders = list,
    );
    setState(() => _loadingOrders = false);
  }

  Future<void> _loadProducts() async {
    final shop = _shop;
    if (shop == null) return;
    setState(() => _loadingProducts = true);
    final res = await _repo.getSellerCatalog(shop.id);
    if (!mounted) return;
    res.fold(
      (f) => _toast('Không tải được sản phẩm: ${f.message}', error: true),
      (list) => _products = list,
    );
    setState(() => _loadingProducts = false);
  }

  void _subscribe(String shopId) {
    _unsubscribe();
    try {
      _ordersChannel = SupabaseService.client
          .channel('seller_orders_$shopId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'shop_id',
              value: shopId,
            ),
            callback: (_) {
              _realtimeDebounce?.cancel();
              _realtimeDebounce = Timer(
                const Duration(milliseconds: 600),
                () {
                  if (mounted) _loadOrders(silent: true);
                },
              );
            },
          )
          .subscribe();
    } catch (_) {}
  }

  void _unsubscribe() {
    if (_ordersChannel != null) {
      SupabaseService.client.removeChannel(_ordersChannel!);
      _ordersChannel = null;
    }
  }

  void _switchShop(Shop shop) {
    if (shop.id == _shop?.id) return;
    setState(() {
      _shop = shop;
      _orders = const [];
      _products = const [];
    });
    _subscribe(shop.id);
    _loadOrders();
    _loadProducts();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _runOrderAction(
    String orderId,
    Future<String?> Function() action, {
    required String successMsg,
  }) async {
    setState(() => _busyOrders.add(orderId));
    final err = await action();
    if (!mounted) return;
    setState(() => _busyOrders.remove(orderId));
    if (err != null) {
      _toast(err, error: true);
    } else {
      _toast(successMsg);
      await _loadOrders(silent: true);
    }
  }

  // ───────────────────────── ORDER ACTIONS ─────────────────────────

  Future<void> _packOrder(EcommerceOrder order) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Xác nhận & đóng gói đơn',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: SellerPalette.textMain,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Đơn #${order.orderCode} • ${order.totalItems} sản phẩm. Khách hàng sẽ nhận thông báo "Người bán đang chuẩn bị hàng".',
              style: const TextStyle(color: SellerPalette.textSub, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: kSellerFieldText,
              decoration: sellerInputDecoration(
                'Ghi chú cho khách (tuỳ chọn)',
                hint: 'VD: Đã kèm quà tặng mini size',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SellerPalette.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (ok != true) return;

    await _runOrderAction(
      order.id,
      () async {
        final r = await _repo.confirmAndPackOrder(orderId: order.id, note: note);
        return r.fold((f) => f.message, (_) => null);
      },
      successMsg: 'Đã xác nhận & đóng gói đơn #${order.orderCode}',
    );
  }

  String _defaultPickupHub(Shop shop) {
    final district = (shop.pickupDistrict ?? '').trim();
    final province = (shop.pickupProvince ?? '').trim();
    if (district.isEmpty && province.isEmpty) return 'Bưu cục lấy hàng';
    return 'Bưu cục ${[district, province].where((e) => e.isNotEmpty).join(', ')}';
  }

  Future<void> _handover(EcommerceOrder order) async {
    final shop = _shop;
    if (shop == null) return;
    String carrier = kSellerCarriers.firstWhere(
      (c) =>
          c.toLowerCase().contains(
                (order.shippingCarrier ?? shop.defaultCarrier)
                    .toLowerCase()
                    .split(' ')
                    .first,
              ),
      orElse: () => kSellerCarriers.first,
    );
    final trackingCtrl = TextEditingController(text: order.trackingCode ?? '');
    final hubCtrl = TextEditingController(text: _defaultPickupHub(shop));

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const Text(
                'Bàn giao cho đơn vị vận chuyển',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: SellerPalette.textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Đơn #${order.orderCode} sẽ chuyển sang "Đang giao" và khách nhận được mã vận đơn để theo dõi.',
                style: const TextStyle(color: SellerPalette.textSub, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: carrier,
                dropdownColor: Colors.white,
                style: kSellerFieldText,
                decoration: sellerInputDecoration(
                  'Đơn vị vận chuyển',
                  icon: Icons.local_shipping_outlined,
                ),
                items: kSellerCarriers
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setSheet(() => carrier = v ?? carrier),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: trackingCtrl,
                style: kSellerFieldText,
                textCapitalization: TextCapitalization.characters,
                decoration: sellerInputDecoration(
                  'Mã vận đơn (để trống để tự tạo)',
                  icon: Icons.qr_code_2_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hubCtrl,
                style: kSellerFieldText,
                decoration: sellerInputDecoration(
                  'Bưu cục nhận hàng',
                  icon: Icons.location_city_outlined,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'Xác nhận đã giao cho ĐVVC',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SellerPalette.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final tracking = trackingCtrl.text.trim();
    final hub = hubCtrl.text.trim();
    trackingCtrl.dispose();
    hubCtrl.dispose();
    if (ok != true) return;

    await _runOrderAction(
      order.id,
      () async {
        final r = await _repo.handoverToCarrier(
          orderId: order.id,
          carrier: carrier,
          trackingCode: tracking,
          pickupHub: hub,
        );
        return r.fold((f) => f.message, (_) => null);
      },
      successMsg: 'Đã bàn giao đơn #${order.orderCode} cho $carrier',
    );
  }

  Future<void> _updateLocation(EcommerceOrder order) async {
    final shop = _shop;
    if (shop == null) return;
    final addr = order.addressSnapshot;
    String a(String k) => addr[k]?.toString().trim() ?? '';
    final destProvince = a('province');
    final destDistrict = a('district');
    final destWard = a('ward');
    final carrier = (order.shippingCarrier ?? shop.defaultCarrier).trim();
    final originProvince = (shop.pickupProvince ?? '').trim().isNotEmpty
        ? shop.pickupProvince!.trim()
        : 'kho người bán';
    final destFull = [destWard, destDistrict, destProvince]
        .where((e) => e.isNotEmpty)
        .join(', ');

    final presets = <_LocationPreset>[
      _LocationPreset(
        status: 'arrived_hub',
        title: 'Đã đến kho phân loại',
        location: 'Kho phân loại $carrier - $originProvince',
        description: 'Kiện hàng đã được quét nhập kho và đang chờ phân loại tuyến.',
        icon: Icons.warehouse_rounded,
      ),
      _LocationPreset(
        status: 'in_transit',
        title: 'Đang trung chuyển liên tỉnh',
        location:
            'Trên đường từ $originProvince đến ${destProvince.isEmpty ? 'tỉnh nhận' : destProvince}',
        description: 'Xe tải liên tỉnh đang vận chuyển kiện hàng tới khu vực của bạn.',
        icon: Icons.alt_route_rounded,
      ),
      _LocationPreset(
        status: 'arrived_hub',
        title: 'Đã đến bưu cục giao hàng',
        location:
            'Bưu cục ${[destDistrict, destProvince].where((e) => e.isNotEmpty).join(', ')}',
        description: 'Kiện hàng đã tới bưu cục gần bạn, sẽ được giao trong hôm nay hoặc ngày mai.',
        icon: Icons.markunread_mailbox_rounded,
      ),
      _LocationPreset(
        status: 'out_for_delivery',
        title: 'Shipper đang giao hàng',
        location: destFull.isEmpty ? 'Đang giao đến người nhận' : destFull,
        description: 'Shipper đang trên đường giao đến bạn, vui lòng chú ý điện thoại.',
        icon: Icons.delivery_dining_rounded,
      ),
      _LocationPreset(
        status: 'completed',
        title: 'Giao hàng thành công',
        location: destFull.isEmpty ? 'Địa chỉ người nhận' : destFull,
        description: 'Đơn hàng đã được giao thành công đến người nhận.',
        icon: Icons.verified_rounded,
      ),
    ];

    final titleCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String customStatus = 'in_transit';

    final chosen = await showModalBottomSheet<_LocationPreset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (ctx, scroll) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                _sheetHandle(),
                const Text(
                  'Cập nhật vị trí đơn hàng',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: SellerPalette.textMain,
                  ),
                ),
                const SizedBox(height: 10),
                _RouteSummary(
                  origin: order.pickupLocation ?? shop.pickupHubLabel,
                  current: order.currentLocation ?? 'Chưa cập nhật',
                  destination: destFull.isEmpty ? 'Người nhận' : destFull,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Mốc nhanh',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: SellerPalette.textSub,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                ...presets.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, p),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.status == 'completed'
                              ? const Color(0xFFECFDF5)
                              : SellerPalette.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SellerPalette.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              p.icon,
                              color: p.status == 'completed'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF009688),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: SellerPalette.textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.location,
                                    style: const TextStyle(
                                      color: SellerPalette.textSub,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: Colors.black38),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Hoặc nhập vị trí tuỳ chỉnh',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: SellerPalette.textSub,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: customStatus,
                  dropdownColor: Colors.white,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration('Loại mốc'),
                  items: const [
                    DropdownMenuItem(
                      value: 'in_transit',
                      child: Text('Đang vận chuyển'),
                    ),
                    DropdownMenuItem(
                      value: 'arrived_hub',
                      child: Text('Đến kho / bưu cục'),
                    ),
                    DropdownMenuItem(
                      value: 'out_for_delivery',
                      child: Text('Đang giao hàng'),
                    ),
                    DropdownMenuItem(
                      value: 'delivery_failed',
                      child: Text('Giao không thành công'),
                    ),
                  ],
                  onChanged: (v) =>
                      setSheet(() => customStatus = v ?? 'in_transit'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Tiêu đề',
                    hint: 'VD: Đã rời kho Tân Bình',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locCtrl,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Vị trí hiện tại *',
                    icon: Icons.place_outlined,
                    hint: 'VD: Hub Củ Chi, TP.HCM',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration('Mô tả thêm'),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    if (locCtrl.text.trim().isEmpty) return;
                    Navigator.pop(
                      ctx,
                      _LocationPreset(
                        status: customStatus,
                        title: titleCtrl.text.trim().isEmpty
                            ? 'Cập nhật vị trí vận chuyển'
                            : titleCtrl.text.trim(),
                        location: locCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        icon: Icons.place,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cập nhật vị trí tuỳ chỉnh',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    titleCtrl.dispose();
    locCtrl.dispose();
    descCtrl.dispose();
    if (chosen == null) return;

    await _runOrderAction(
      order.id,
      () async {
        final r = await _repo.advanceOrderLocation(
          orderId: order.id,
          stepStatus: chosen.status,
          title: chosen.title,
          location: chosen.location,
          description: chosen.description,
        );
        return r.fold((f) => f.message, (_) => null);
      },
      successMsg: chosen.status == 'completed'
          ? 'Đơn #${order.orderCode} đã giao thành công 🎉'
          : 'Đã cập nhật vị trí: ${chosen.location}',
    );
  }

  Future<void> _cancelOrder(EcommerceOrder order) async {
    const reasons = [
      'Hết hàng / không đủ tồn kho',
      'Không liên hệ được người mua',
      'Địa chỉ giao hàng không hợp lệ',
      'Người mua yêu cầu hủy qua chat',
    ];
    String selected = reasons.first;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Hủy đơn #${order.orderCode}?',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: SellerPalette.textMain,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map((r) => RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: SellerPalette.primary,
                      value: r,
                      groupValue: selected,
                      onChanged: (v) => setD(() => selected = v ?? selected),
                      title: Text(
                        r,
                        style: const TextStyle(
                          color: SellerPalette.textMain,
                          fontSize: 13,
                        ),
                      ),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Không'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hủy đơn'),
            ),
          ],
        ),
      ),
    );
    if (reason == null) return;

    await _runOrderAction(
      order.id,
      () async {
        final r = await _repo.sellerCancelOrder(orderId: order.id, reason: reason);
        return r.fold((f) => f.message, (_) => null);
      },
      successMsg: 'Đã hủy đơn & hoàn tồn kho',
    );
  }

  Future<void> _chatBuyer(EcommerceOrder order) async {
    final res = await sl<GetOrCreateConversationUseCase>()(order.buyerId);
    if (!mounted) return;
    res.fold(
      (f) => _toast(f.message, error: true),
      (conv) => context.push('/messages', extra: conv),
    );
  }

  // ───────────────────────── PRODUCT ACTIONS ─────────────────────────

  Future<void> _openProductForm([Product? product]) async {
    final shop = _shop;
    if (shop == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SellerProductFormScreen(
          shopId: shop.id,
          shopName: shop.shopName,
          product: product,
        ),
      ),
    );
    if (saved == true) {
      await _loadProducts();
      await _loadShops(preferId: shop.id);
    }
  }

  Future<void> _toggleProduct(Product p, bool active) async {
    final status = active ? 'active' : 'inactive';
    final res = await _repo.toggleSellerProductStatus(
      productId: p.id,
      status: status,
    );
    if (!mounted) return;
    res.fold(
      (f) => _toast(f.message, error: true),
      (_) {
        _toast(active ? 'Đã mở bán "${p.title}"' : 'Đã ẩn "${p.title}"');
        _loadProducts();
      },
    );
  }

  // ───────────────────────── BUILD ─────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingShops && _shop == null) {
      return const Scaffold(
        backgroundColor: SellerPalette.bg,
        body: Center(
          child: CircularProgressIndicator(color: SellerPalette.primary),
        ),
      );
    }

    if (_shop == null) return _buildOnboarding();
    final shop = _shop!;

    return Scaffold(
      backgroundColor: SellerPalette.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: SellerPalette.textMain,
        elevation: 0,
        titleSpacing: 0,
        title: _shops.length > 1
            ? PopupMenuButton<Shop>(
                color: Colors.white,
                onSelected: _switchShop,
                itemBuilder: (_) => _shops
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Text(
                            s.shopName,
                            style: TextStyle(
                              color: SellerPalette.textMain,
                              fontWeight: s.id == shop.id
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
                child: _appBarTitle(shop, showArrow: true),
              )
            : _appBarTitle(shop),
        actions: [
          IconButton(
            tooltip: 'Xem gian hàng',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push('/shop/${shop.id}'),
          ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadShops(preferId: shop.id),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: SellerPalette.primary,
          unselectedLabelColor: SellerPalette.textSub,
          indicatorColor: SellerPalette.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
          tabs: [
            const Tab(text: 'Tổng quan'),
            Tab(text: 'Đơn hàng (${_countWhere(['pending', 'paid', 'packed'])})'),
            Tab(text: 'Sản phẩm (${_products.length})'),
            const Tab(text: 'Cài đặt'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) => _tabController.index == 2
            ? FloatingActionButton.extended(
                onPressed: () => _openProductForm(),
                backgroundColor: SellerPalette.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Thêm sản phẩm',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            : const SizedBox.shrink(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverview(shop),
          _buildOrdersTab(),
          _buildProductsTab(),
          _ShopSettingsTab(
            key: ValueKey('settings_${shop.id}'),
            shop: shop,
            onSaved: (updated) => _loadShops(preferId: updated.id),
          ),
        ],
      ),
    );
  }

  Widget _appBarTitle(Shop shop, {bool showArrow = false}) {
    final logo = StorageImage.publicUrl(shop.logoPath, bucket: 'avatars');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 16,
          backgroundColor: SellerPalette.field,
          backgroundImage: logo != null ? NetworkImage(logo) : null,
          child: logo == null
              ? const Icon(Icons.storefront, size: 16, color: SellerPalette.textSub)
              : null,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kênh Người Bán',
                style: TextStyle(
                  fontSize: 11,
                  color: SellerPalette.textSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                shop.shopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: SellerPalette.textMain,
                ),
              ),
            ],
          ),
        ),
        if (showArrow)
          const Icon(Icons.expand_more_rounded, color: SellerPalette.textSub),
      ],
    );
  }

  Widget _buildOnboarding() {
    return Scaffold(
      backgroundColor: SellerPalette.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: SellerPalette.textMain,
        elevation: 0,
        title: const Text(
          'Kênh Người Bán',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: SellerPalette.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_business_rounded,
                    size: 44, color: SellerPalette.primary),
              ),
              const SizedBox(height: 18),
              const Text(
                'Bạn chưa có cửa hàng',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: SellerPalette.textMain,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mở shop miễn phí để bán hàng qua video, livestream và quản lý vận đơn ngay trên ShareCo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SellerPalette.textSub, height: 1.4),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SellerRegistrationScreen(),
                    ),
                  );
                  if (mounted) _loadShops();
                },
                icon: const Icon(Icons.storefront_rounded),
                label: const Text(
                  'Đăng ký bán hàng',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SellerPalette.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(220, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _countWhere(List<String> statuses) =>
      _orders.where((o) => statuses.contains(o.status)).length;

  // ─── TAB 1: OVERVIEW ───
  Widget _buildOverview(Shop shop) {
    final gmv = _orders
        .where((o) => o.status != 'cancelled' && o.status != 'refunded')
        .fold<double>(0, (s, o) => s + o.totalAmount);
    final completedRevenue = _orders
        .where((o) => o.status == 'completed')
        .fold<double>(0, (s, o) => s + o.totalAmount);
    final settled =
        shop.settledRevenue > 0 ? shop.settledRevenue : completedRevenue;
    final lowStock = _products
        .where((p) => p.status == 'active' && p.stockTotal <= 5)
        .toList();

    final kpis = [
      _Kpi('Chờ xác nhận', '${_countWhere(['pending', 'paid'])}',
          Icons.pending_actions_rounded, const Color(0xFFF59E0B), 'pending'),
      _Kpi('Chờ lấy hàng', '${_countWhere(['packed'])}',
          Icons.inventory_2_rounded, const Color(0xFF8B5CF6), 'packed'),
      _Kpi('Đang giao', '${_countWhere(['shipping'])}',
          Icons.local_shipping_rounded, const Color(0xFF009688), 'shipping'),
      _Kpi('Hoàn thành', '${_countWhere(['completed'])}',
          Icons.task_alt_rounded, const Color(0xFF10B981), 'completed'),
      _Kpi('Tổng GMV', formatVndShort(gmv), Icons.trending_up_rounded,
          SellerPalette.primary, null),
      _Kpi('Đã quyết toán', formatVndShort(settled),
          Icons.account_balance_wallet_rounded, const Color(0xFF3B82F6), null),
    ];

    return RefreshIndicator(
      onRefresh: () => _loadShops(preferId: shop.id),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (!shop.isActive)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.pause_circle_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shop đang tạm nghỉ — khách không thể đặt hàng mới. Bật lại trong tab Cài đặt.',
                      style: TextStyle(color: Color(0xFF9A3412), fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.75,
            children: kpis
                .map((k) => _KpiCard(
                      kpi: k,
                      onTap: k.filter == null
                          ? null
                          : () {
                              setState(() => _orderFilter = k.filter);
                              _tabController.animateTo(1);
                            },
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          SellerSectionCard(
            title: 'Lối tắt',
            icon: Icons.bolt_rounded,
            child: Row(
              children: [
                _Shortcut(
                  icon: Icons.add_box_rounded,
                  label: 'Thêm SP',
                  color: SellerPalette.primary,
                  onTap: () => _openProductForm(),
                ),
                _Shortcut(
                  icon: Icons.local_shipping_rounded,
                  label: 'Xử lý đơn',
                  color: const Color(0xFF009688),
                  onTap: () => _tabController.animateTo(1),
                ),
                _Shortcut(
                  icon: Icons.sensors_rounded,
                  label: 'Live bán hàng',
                  color: const Color(0xFFEF4444),
                  onTap: () => context.push('/livestream'),
                ),
                _Shortcut(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Ví & Rút tiền',
                  color: const Color(0xFF3B82F6),
                  onTap: () => context.push('/wallet'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SellerSectionCard(
            title: 'Cảnh báo sắp hết hàng (${lowStock.length})',
            icon: Icons.warning_amber_rounded,
            child: lowStock.isEmpty
                ? const Text(
                    'Tồn kho ổn định 👍',
                    style: TextStyle(color: SellerPalette.textSub),
                  )
                : Column(
                    children: lowStock
                        .take(5)
                        .map((p) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: _ProductThumb(path: p.displayImagePath, size: 40),
                              title: Text(
                                p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SellerPalette.textMain,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Còn ${p.stockTotal} sản phẩm',
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                              trailing: TextButton(
                                onPressed: () => _openProductForm(p),
                                child: const Text('Nhập thêm'),
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 14),
          SellerSectionCard(
            title: 'Kho lấy hàng',
            icon: Icons.warehouse_outlined,
            trailing: TextButton(
              onPressed: () => _tabController.animateTo(3),
              child: const Text('Sửa'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.fullPickupLocation,
                  style: const TextStyle(
                    color: SellerPalette.textMain,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ĐVVC mặc định: ${shop.defaultCarrier}'
                  '${(shop.contactPhone ?? '').isNotEmpty ? ' • SĐT: ${shop.contactPhone}' : ''}',
                  style: const TextStyle(color: SellerPalette.textSub, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: ORDERS ───
  Widget _buildOrdersTab() {
    const filters = <(String, String?)>[
      ('Tất cả', null),
      ('Chờ xác nhận', 'pending'),
      ('Chờ lấy hàng', 'packed'),
      ('Đang giao', 'shipping'),
      ('Hoàn thành', 'completed'),
      ('Đã hủy', 'cancelled'),
    ];

    final visible = _orders.where((o) {
      if (_orderFilter == null) return true;
      if (_orderFilter == 'pending') {
        return o.status == 'pending' || o.status == 'paid';
      }
      if (_orderFilter == 'cancelled') {
        return o.status == 'cancelled' || o.status == 'refunded';
      }
      return o.status == _orderFilter;
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final (label, value) = filters[i];
              final selected = _orderFilter == value;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _orderFilter = value),
                selectedColor: SellerPalette.primary,
                backgroundColor: SellerPalette.field,
                showCheckmark: false,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : SellerPalette.textMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _loadingOrders && _orders.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: SellerPalette.primary),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadOrders(),
                  child: visible.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.receipt_long_outlined,
                                size: 52, color: Colors.black26),
                            SizedBox(height: 10),
                            Center(
                              child: Text(
                                'Chưa có đơn hàng nào',
                                style: TextStyle(
                                  color: SellerPalette.textSub,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final o = visible[i];
                            return _SellerOrderCard(
                              order: o,
                              busy: _busyOrders.contains(o.id),
                              onPack: () => _packOrder(o),
                              onHandover: () => _handover(o),
                              onUpdateLocation: () => _updateLocation(o),
                              onCancel: () => _cancelOrder(o),
                              onChat: () => _chatBuyer(o),
                              onOpenDetail: () async {
                                await context.push('/orders/${o.id}');
                                if (mounted) _loadOrders(silent: true);
                              },
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  // ─── TAB 3: PRODUCTS ───
  Widget _buildProductsTab() {
    final q = _productQuery.trim().toLowerCase();
    final visible = _products.where((p) {
      if (q.isNotEmpty && !p.title.toLowerCase().contains(q)) return false;
      switch (_productFilter) {
        case 'active':
          return p.status == 'active';
        case 'inactive':
          return p.status != 'active';
        case 'low':
          return p.stockTotal <= 5;
        default:
          return true;
      }
    }).toList();

    const filters = [
      ('Tất cả', 'all'),
      ('Đang bán', 'active'),
      ('Đang ẩn', 'inactive'),
      ('Sắp hết', 'low'),
    ];

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            children: [
              TextField(
                style: kSellerFieldText,
                onChanged: (v) => setState(() => _productQuery = v),
                decoration: sellerInputDecoration(
                  'Tìm sản phẩm trong shop',
                  icon: Icons.search_rounded,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (label, value) = filters[i];
                    final selected = _productFilter == value;
                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _productFilter = value),
                      selectedColor: SellerPalette.primary,
                      backgroundColor: SellerPalette.field,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : SellerPalette.textMain,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingProducts && _products.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: SellerPalette.primary),
                )
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: visible.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            const Icon(Icons.inventory_2_outlined,
                                size: 52, color: Colors.black26),
                            const SizedBox(height: 10),
                            const Center(
                              child: Text(
                                'Chưa có sản phẩm phù hợp',
                                style: TextStyle(
                                  color: SellerPalette.textSub,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: TextButton.icon(
                                onPressed: () => _openProductForm(),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Đăng sản phẩm đầu tiên'),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final p = visible[i];
                            return _SellerProductTile(
                              product: p,
                              onEdit: () => _openProductForm(p),
                              onToggle: (v) => _toggleProduct(p, v),
                              onView: () => context.push('/products/${p.id}'),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _sheetHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}

// ═══════════════════════════ SUB WIDGETS ═══════════════════════════

class _LocationPreset {
  final String status;
  final String title;
  final String location;
  final String? description;
  final IconData icon;

  const _LocationPreset({
    required this.status,
    required this.title,
    required this.location,
    this.description,
    required this.icon,
  });
}

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? filter;

  const _Kpi(this.label, this.value, this.icon, this.color, this.filter);
}

class _KpiCard extends StatelessWidget {
  final _Kpi kpi;
  final VoidCallback? onTap;

  const _KpiCard({required this.kpi, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SellerPalette.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kpi.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(kpi.icon, color: kpi.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        kpi.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: SellerPalette.textMain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kpi.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SellerPalette.textSub,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SellerPalette.textMain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  final String origin;
  final String current;
  final String destination;

  const _RouteSummary({
    required this.origin,
    required this.current,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, Color color, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            SizedBox(
              width: 76,
              child: Text(
                label,
                style: const TextStyle(
                  color: SellerPalette.textSub,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: SellerPalette.textMain,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        children: [
          row(Icons.warehouse_outlined, SellerPalette.textSub, 'Kho đi', origin),
          row(Icons.my_location_rounded, const Color(0xFF009688), 'Hiện tại', current),
          row(Icons.flag_rounded, SellerPalette.primary, 'Khách nhận', destination),
        ],
      ),
    );
  }
}

class _SellerOrderCard extends StatelessWidget {
  final EcommerceOrder order;
  final bool busy;
  final VoidCallback onPack;
  final VoidCallback onHandover;
  final VoidCallback onUpdateLocation;
  final VoidCallback onCancel;
  final VoidCallback onChat;
  final VoidCallback onOpenDetail;

  const _SellerOrderCard({
    required this.order,
    required this.busy,
    required this.onPack,
    required this.onHandover,
    required this.onUpdateLocation,
    required this.onCancel,
    required this.onChat,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final addr = order.addressSnapshot;
    final buyerName = (addr['full_name'] ?? addr['recipient_name'] ?? 'Khách hàng').toString();
    final phone = (addr['phone'] ?? '').toString();
    final dest = [addr['district'], addr['province']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(', ');
    final first = order.items.isEmpty ? null : order.items.first;

    final actions = <Widget>[];
    switch (order.status) {
      case 'pending':
      case 'paid':
        actions.addAll([
          _primaryBtn('Xác nhận & Đóng gói', Icons.inventory_2_outlined, onPack),
          _outlineBtn('Giao ĐVVC', Icons.local_shipping_outlined, onHandover),
          _outlineBtn('Hủy', Icons.close_rounded, onCancel, danger: true),
        ]);
        break;
      case 'packed':
        actions.addAll([
          _primaryBtn('Giao cho ĐVVC', Icons.local_shipping_rounded, onHandover),
          _outlineBtn('Hủy', Icons.close_rounded, onCancel, danger: true),
        ]);
        break;
      case 'shipping':
        actions.addAll([
          _primaryBtn(
            'Cập nhật vị trí',
            Icons.edit_location_alt_rounded,
            onUpdateLocation,
            color: const Color(0xFF009688),
          ),
          _outlineBtn('Hành trình', Icons.route_rounded, onOpenDetail),
        ]);
        break;
      default:
        actions.add(_outlineBtn('Xem hành trình', Icons.route_rounded, onOpenDetail));
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SellerPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.orderCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: SellerPalette.textMain,
                      ),
                    ),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${formatOrderDate(order.placedAt)} • $buyerName${phone.isNotEmpty ? ' • $phone' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: SellerPalette.textSub, fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (first != null)
                Row(
                  children: [
                    _ProductThumb(path: first.imagePath, size: 52),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            first.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SellerPalette.textMain,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${first.variantName ?? 'Tiêu chuẩn'} • x${first.qty}'
                            '${order.items.length > 1 ? '  (+${order.items.length - 1} SP khác)' : ''}',
                            style: const TextStyle(
                              color: SellerPalette.textSub,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatVndShort(order.totalAmount),
                      style: const TextStyle(
                        color: SellerPalette.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              if ((order.currentLocation ?? '').isNotEmpty ||
                  (order.trackingCode ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    [
                      if ((order.shippingCarrier ?? '').isNotEmpty)
                        '🚚 ${order.shippingCarrier}',
                      if ((order.trackingCode ?? '').isNotEmpty)
                        order.trackingCode!,
                      if ((order.currentLocation ?? '').isNotEmpty)
                        '📍 ${order.currentLocation}',
                    ].join('  •  '),
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (dest.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Giao đến: $dest',
                  style: const TextStyle(color: SellerPalette.textSub, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              if (busy)
                const LinearProgressIndicator(color: SellerPalette.primary)
              else
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Chat với khách',
                      onPressed: onChat,
                      style: IconButton.styleFrom(
                        backgroundColor: SellerPalette.field,
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 19, color: SellerPalette.textMain),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 6,
                        children: actions,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryBtn(String label, IconData icon, VoidCallback onTap,
      {Color color = SellerPalette.primary}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        minimumSize: const Size(0, 38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _outlineBtn(String label, IconData icon, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? Colors.redAccent : SellerPalette.textMain;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: danger ? Colors.redAccent : SellerPalette.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        minimumSize: const Size(0, 38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _SellerProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onView;

  const _SellerProductTile({
    required this.product,
    required this.onEdit,
    required this.onToggle,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final low = product.stockTotal <= 5;
    final active = product.status == 'active';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SellerPalette.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onView,
            child: Opacity(
              opacity: active ? 1 : 0.5,
              child: _ProductThumb(path: product.displayImagePath, size: 68),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SellerPalette.textMain,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.hasPriceRange
                      ? '${formatVndShort(product.priceMin)} - ${formatVndShort(product.priceMax)}'
                      : formatVndShort(product.priceMin),
                  style: const TextStyle(
                    color: SellerPalette.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kho: ${product.stockTotal}  •  Đã bán: ${product.soldCount}'
                  '${product.variants.length > 1 ? '  •  ${product.variants.length} phân loại' : ''}',
                  style: TextStyle(
                    color: low ? Colors.redAccent : SellerPalette.textSub,
                    fontSize: 12,
                    fontWeight: low ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: active,
                activeColor: SellerPalette.primary,
                onChanged: onToggle,
              ),
              IconButton(
                tooltip: 'Sửa',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    color: SellerPalette.textSub, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String? path;
  final double size;

  const _ProductThumb({required this.path, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = StorageImage.publicUrl(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: SellerPalette.field,
        child: url == null
            ? const Icon(Icons.shopping_bag_outlined, color: Colors.black26)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.shopping_bag_outlined, color: Colors.black26),
              ),
      ),
    );
  }
}

// ─── TAB 4: SETTINGS ───
class _ShopSettingsTab extends StatefulWidget {
  final Shop shop;
  final ValueChanged<Shop> onSaved;

  const _ShopSettingsTab({super.key, required this.shop, required this.onSaved});

  @override
  State<_ShopSettingsTab> createState() => _ShopSettingsTabState();
}

class _ShopSettingsTabState extends State<_ShopSettingsTab>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _province;
  late final TextEditingController _district;
  late final TextEditingController _ward;
  late final TextEditingController _address;
  int _provinceCode = -1;
  int _districtCode = -1;
  late String _carrier;
  late String _businessType;
  late bool _active;
  File? _logo;
  File? _cover;
  bool _saving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final s = widget.shop;
    _name = TextEditingController(text: s.shopName);
    _desc = TextEditingController(text: s.description ?? '');
    _phone = TextEditingController(text: s.contactPhone ?? '');
    _email = TextEditingController(text: s.contactEmail ?? '');
    _province = TextEditingController(text: s.pickupProvince ?? '');
    _district = TextEditingController(text: s.pickupDistrict ?? '');
    _ward = TextEditingController(text: s.pickupWard ?? '');
    _address = TextEditingController(text: s.pickupAddress ?? '');
    _carrier = kSellerCarriers.contains(s.defaultCarrier)
        ? s.defaultCarrier
        : kSellerCarriers.first;
    _businessType =
        kBusinessTypes.containsKey(s.businessType) ? s.businessType : 'individual';
    _active = s.isActive;
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _phone, _email, _province, _district, _ward, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickProvince() async {
    final r = await SellerRegionPicker.pickProvince(context);
    if (r == null) return;
    setState(() {
      _province.text = r['name'].toString();
      _provinceCode = (r['code'] as int?) ?? -1;
      _district.clear();
      _ward.clear();
    });
    if (mounted) _pickDistrict();
  }

  Future<void> _pickDistrict() async {
    if (_province.text.isEmpty) return _pickProvince();
    final r = await SellerRegionPicker.pickDistrict(context, _province.text, _provinceCode);
    if (r == null) return;
    setState(() {
      _district.text = r['name'].toString();
      _districtCode = (r['code'] as int?) ?? -1;
      _ward.clear();
    });
    if (mounted) _pickWard();
  }

  Future<void> _pickWard() async {
    if (_district.text.isEmpty) return _pickDistrict();
    final r = await SellerRegionPicker.pickWard(
      context,
      _province.text,
      _district.text,
      _districtCode,
    );
    if (r == null) return;
    setState(() => _ward.text = r['name'].toString());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? logoUrl;
      String? coverUrl;
      if (_logo != null) logoUrl = await SellerMediaHelper.upload(_logo!, 'shops');
      if (_cover != null) coverUrl = await SellerMediaHelper.upload(_cover!, 'shops');

      final res = await sl<ShopRepository>().updateShopSettings(
        shopId: widget.shop.id,
        shopName: _name.text,
        description: _desc.text,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
        contactPhone: _phone.text,
        contactEmail: _email.text,
        businessType: _businessType,
        pickupProvince: _province.text,
        pickupDistrict: _district.text,
        pickupWard: _ward.text,
        pickupAddress: _address.text,
        defaultCarrier: _carrier,
        status: _active ? 'active' : 'inactive',
      );
      if (!mounted) return;
      res.fold(
        (f) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message), backgroundColor: Colors.red),
        ),
        (shop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã lưu cài đặt shop & kho hàng')),
          );
          setState(() {
            _logo = null;
            _cover = null;
          });
          widget.onSaved(shop);
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final logoUrl = StorageImage.publicUrl(widget.shop.logoPath, bucket: 'avatars');
    final coverUrl = StorageImage.publicUrl(widget.shop.coverPath, bucket: 'avatars');

    ImageProvider? coverImg = _cover != null
        ? FileImage(_cover!)
        : (coverUrl != null ? NetworkImage(coverUrl) : null);
    ImageProvider? logoImg = _logo != null
        ? FileImage(_logo!)
        : (logoUrl != null ? NetworkImage(logoUrl) : null);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          SellerSectionCard(
            title: 'Nhận diện thương hiệu',
            icon: Icons.palette_outlined,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () async {
                    final f = await SellerMediaHelper.pickImage(context, title: 'Ảnh bìa shop');
                    if (f != null && mounted) setState(() => _cover = f);
                  },
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: SellerPalette.field,
                      borderRadius: BorderRadius.circular(12),
                      image: coverImg != null
                          ? DecorationImage(image: coverImg, fit: BoxFit.cover)
                          : null,
                    ),
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.all(8),
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.edit, size: 14, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final f = await SellerMediaHelper.pickImage(context, title: 'Logo shop');
                        if (f != null && mounted) setState(() => _logo = f);
                      },
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: SellerPalette.field,
                        backgroundImage: logoImg,
                        child: logoImg == null
                            ? const Icon(Icons.add_a_photo_outlined, color: SellerPalette.textSub)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _name,
                        style: kSellerFieldText,
                        decoration: sellerInputDecoration('Tên shop'),
                        validator: (v) =>
                            (v == null || v.trim().length < 3) ? 'Tối thiểu 3 ký tự' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration('Mô tả shop'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SellerSectionCard(
            title: 'Liên hệ & Kinh doanh',
            icon: Icons.contact_phone_outlined,
            child: Column(
              children: [
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration('SĐT kho / CSKH', icon: Icons.phone_outlined),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration('Email', icon: Icons.alternate_email_rounded),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _businessType,
                  dropdownColor: Colors.white,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration('Loại hình kinh doanh'),
                  items: kBusinessTypes.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _businessType = v ?? _businessType),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SellerSectionCard(
            title: 'Kho lấy hàng & Vận chuyển',
            icon: Icons.warehouse_outlined,
            child: Column(
              children: [
                TextFormField(
                  controller: _province,
                  readOnly: true,
                  onTap: _pickProvince,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'Tỉnh / Thành phố',
                    icon: Icons.map_outlined,
                    suffix: const Icon(Icons.arrow_drop_down, color: SellerPalette.textSub),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _district,
                        readOnly: true,
                        onTap: _pickDistrict,
                        style: kSellerFieldText,
                        decoration: sellerInputDecoration('Quận / Huyện'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _ward,
                        readOnly: true,
                        onTap: _pickWard,
                        style: kSellerFieldText,
                        decoration: sellerInputDecoration('Phường / Xã'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration('Số nhà, tên đường', icon: Icons.home_work_outlined),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _carrier,
                  dropdownColor: Colors.white,
                  style: kSellerFieldText,
                  decoration: sellerInputDecoration(
                    'ĐVVC mặc định',
                    icon: Icons.local_shipping_outlined,
                  ),
                  items: kSellerCarriers
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _carrier = v ?? _carrier),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SellerSectionCard(
            child: SwitchListTile(
              value: _active,
              onChanged: widget.shop.status == 'blocked'
                  ? null
                  : (v) => setState(() => _active = v),
              activeColor: SellerPalette.primary,
              contentPadding: EdgeInsets.zero,
              title: Text(
                widget.shop.status == 'blocked'
                    ? 'Shop đang bị khóa bởi quản trị viên'
                    : (_active ? 'Shop đang mở bán' : 'Shop đang tạm nghỉ'),
                style: const TextStyle(
                  color: SellerPalette.textMain,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'Khi tạm nghỉ, khách không thể đặt đơn mới nhưng đơn cũ vẫn xử lý bình thường.',
                style: TextStyle(color: SellerPalette.textSub, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: SellerPalette.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Lưu cài đặt',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                  ),
          ),
        ],
      ),
    );
  }
}

