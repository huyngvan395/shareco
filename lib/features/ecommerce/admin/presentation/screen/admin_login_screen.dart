import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shareco/routes/admin_router.dart';
import '../bloc/admin_bloc.dart';
import '../widgets/admin_ui_helpers.dart';

class AdminSession {
  static String? loggedInRole; // 'admin' or 'shop'
  static String? loggedInUserId;
  static String? loggedInShopId;
  static String? loggedInShopName;
  static String? loggedInShopLogo;
  static String? loggedInShopSlug;
  static String? loggedInShopStatus;
  static String? loggedInEmail;
  static String? loggedInUsername;
  static List<Map<String, dynamic>> userShops = [];
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController(text: 'admin@shareco.vn');
  final _passwordCtrl = TextEditingController(text: '123456');

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRoleType = 'admin'; // 'admin' | 'shop'

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _applyQuickDemo({
    required String role,
    required String account,
  }) {
    setState(() {
      _selectedRoleType = role;
      _emailCtrl.text = account;
      _passwordCtrl.text = '123456';
    });
  }

  Future<void> _handleLogin() async {
    final input = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ Tài khoản/Email và Mật khẩu.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Super Admin login
      if (input.contains('admin') || _selectedRoleType == 'admin') {
        AdminSession.loggedInRole = 'admin';
        AdminSession.loggedInEmail = input;
        AdminSession.loggedInShopId = null;
        AdminSession.loggedInShopName = 'ShareCo Super Admin';
        AdminSession.loggedInUserId = null;
        AdminSession.userShops = [];

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập Platform Super Admin thành công! 👑'),
            backgroundColor: AdminPalette.success,
          ),
        );
        context.go(AdminRouter.shops);
        return;
      }

      // 2. Seller Portal Login (Người dùng có Shop)
      final supabase = Supabase.instance.client;
      String? matchedUserId;
      String? matchedUsername;
      String? matchedEmail = input;

      // Thử đăng nhập Supabase Auth nếu input là email
      try {
        if (input.contains('@')) {
          final res = await supabase.auth.signInWithPassword(
            email: input,
            password: password,
          );
          matchedUserId = res.user?.id;
          matchedEmail = res.user?.email ?? input;
        }
      } catch (e) {
        debugPrint('Supabase direct auth login note: $e');
      }

      // Nếu chưa có userId, tìm qua bảng profiles (hỗ trợ nhập username như huy123, chungngo)
      if (matchedUserId == null) {
        try {
          final cleanInput = input.replaceAll('@', '').toLowerCase();
          final profileRes = await supabase
              .from('profiles')
              .select('id, username, display_name')
              .or('username.eq.$cleanInput,id.eq.$cleanInput')
              .limit(1);

          if (profileRes.isNotEmpty) {
            matchedUserId = profileRes.first['id'] as String;
            matchedUsername = profileRes.first['username'] as String?;
          }
        } catch (e) {
          debugPrint('Error searching user profile: $e');
        }
      }

      // Fallback tìm userId theo demo username nếu offline
      if (matchedUserId == null) {
        final cleanInput = input.replaceAll('@', '').toLowerCase();
        if (cleanInput.contains('huy')) {
          matchedUserId = '3543c70c-7dba-4843-88a7-80f2d721d653';
          matchedUsername = 'huy123';
        } else if (cleanInput.contains('chung')) {
          matchedUserId = '23263932-5a16-45d7-b31f-8680d988e2fc';
          matchedUsername = 'chungngo';
        }
      }

      // 3. Tìm các gian hàng mà người dùng này sở hữu
      List<Map<String, dynamic>> shopsResult = [];
      try {
        if (matchedUserId != null) {
          final res = await supabase
              .from('shops')
              .select('*')
              .eq('owner_id', matchedUserId)
              .order('created_at', ascending: false);
          shopsResult = List<Map<String, dynamic>>.from(res);
        }
      } catch (e) {
        debugPrint('Error querying user shops: $e');
      }

      // Fallback offline store nếu không kết nối được
      if (shopsResult.isEmpty && matchedUserId != null) {
        shopsResult = AdminFallbackStore.shops.where((s) {
          return s['owner_id'] == matchedUserId;
        }).toList();
      }

      // Nếu vẫn rỗng nhưng user nhập tên shop (ví dụ "apple", "lorean")
      if (shopsResult.isEmpty) {
        final slugKey = input.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
        try {
          final res = await supabase
              .from('shops')
              .select('*')
              .or('shop_slug.ilike.%$slugKey%,shop_name.ilike.%$input%');
          shopsResult = List<Map<String, dynamic>>.from(res);
        } catch (_) {
          shopsResult = AdminFallbackStore.shops.where((s) {
            final slug = (s['shop_slug'] ?? '').toString().toLowerCase();
            final name = (s['shop_name'] ?? '').toString().toLowerCase();
            return slug.contains(slugKey) || name.contains(slugKey);
          }).toList();
        }
      }

      // 4. Xử lý kết quả theo tình huống thực tế
      if (shopsResult.isEmpty) {
        // Tình huống: Người dùng chưa có gian hàng
        if (!mounted) return;
        _showNoShopDialog(matchedUsername ?? input);
        return;
      }

      if (shopsResult.length == 1) {
        // Tình huống: Có đúng 1 gian hàng -> Đăng nhập ngay
        final shop = shopsResult.first;
        _enterShopPortal(shop, matchedEmail ?? input, allShops: shopsResult);
      } else {
        // Tình huống: Người dùng sở hữu NHIỀU GIAN HÀNG -> Mở popup chọn gian hàng
        if (!mounted) return;
        _showShopPickerModal(
          ownerName: matchedUsername ?? input,
          email: matchedEmail ?? input,
          shops: shopsResult,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng nhập thất bại: $e'),
          backgroundColor: AdminPalette.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _enterShopPortal(
    Map<String, dynamic> shop,
    String email, {
    required List<Map<String, dynamic>> allShops,
  }) {
    final status = shop['status'] ?? 'active';
    final shopName = shop['shop_name'] ?? 'Gian hàng';

    AdminSession.loggedInRole = 'shop';
    AdminSession.loggedInUserId = shop['owner_id'];
    AdminSession.loggedInShopId = shop['id'];
    AdminSession.loggedInShopName = shopName;
    AdminSession.loggedInShopLogo = shop['logo_path'];
    AdminSession.loggedInShopSlug = shop['shop_slug'];
    AdminSession.loggedInShopStatus = status;
    AdminSession.loggedInEmail = email;
    AdminSession.userShops = allShops;

    if (!mounted) return;

    if (status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gian hàng [$shopName] đang chờ phê duyệt. Bạn có thể vào thiết lập sản phẩm trước! ⏳'),
          backgroundColor: const Color(0xFFF97316),
        ),
      );
    } else if (status == 'rejected') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gian hàng [$shopName] đã bị từ chối: ${shop['rejection_reason'] ?? "Chưa rõ lý do"} ❌'),
          backgroundColor: AdminPalette.danger,
        ),
      );
    } else if (status == 'blocked') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gian hàng [$shopName] đang bị tạm khóa do vi phạm chính sách! 🔒'),
          backgroundColor: AdminPalette.danger,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng nhập Kênh Người Bán [$shopName] thành công! 🏪'),
          backgroundColor: AdminPalette.success,
        ),
      );
    }

    context.go(AdminRouter.products);
  }

  void _showNoShopDialog(String identifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_outlined, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(width: 12),
            const Text('Chưa Có Gian Hàng', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tài khoản [@$identifier] hiện chưa đăng ký gian hàng nào trên ShareCo.',
                style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminPalette.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.phone_android_rounded, color: AdminPalette.primary, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Để mở shop bán hàng: Mở app ShareCo trên điện thoại -> Vào mục "Hồ Sơ" -> Chọn "Đăng Ký Bán Hàng" để gửi hồ sơ xét duyệt.',
                        style: TextStyle(fontSize: 12.5, height: 1.4, color: AdminPalette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminPalette.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  void _showShopPickerModal({
    required String ownerName,
    required String email,
    required List<Map<String, dynamic>> shops,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminPalette.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded, color: AdminPalette.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chọn Gian Hàng Quản Lý', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  Text(
                    'Tài khoản @$ownerName sở hữu ${shops.length} gian hàng. Chọn shop để làm việc:',
                    style: const TextStyle(fontSize: 12.5, color: AdminPalette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: shops.map((s) {
                final status = s['status'] ?? 'active';
                final isPending = status == 'pending';
                final isVerified = s['is_verified'] == true;
                final logoUrl = s['logo_path'];
                final shopName = s['shop_name'] ?? 'Gian hàng';
                final province = s['pickup_province'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminPalette.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                        border: Border.all(color: AdminPalette.border),
                        image: logoUrl != null
                            ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: logoUrl == null
                          ? const Icon(Icons.store_rounded, color: AdminPalette.textSecondary)
                          : null,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            shopName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 15, color: AdminPalette.info),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${s['shop_slug'] ?? 'shop'}${province.isNotEmpty ? ' • 📍 $province' : ''}',
                          style: const TextStyle(fontSize: 12, color: AdminPalette.textSecondary),
                        ),
                        const SizedBox(height: 3),
                        if (isPending)
                          const Text('⏳ Đang chờ duyệt', style: TextStyle(fontSize: 11, color: Color(0xFFF97316), fontWeight: FontWeight.w600))
                        else
                          const Text('✅ Đang hoạt động', style: TextStyle(fontSize: 11, color: AdminPalette.success, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _enterShopPortal(s, email, allShops: shops);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminPalette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Vào Shop', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirectShopPicker() async {
    // Lấy toàn bộ shops từ Supabase để người dùng demo bấm 1-click vào bất kỳ shop nào
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> allShops = [];
    try {
      final res = await Supabase.instance.client
          .from('shops')
          .select('*, profiles:owner_id(username, display_name)')
          .order('shop_name', ascending: true);
      allShops = List<Map<String, dynamic>>.from(res);
    } catch (_) {
      allShops = List<Map<String, dynamic>>.from(AdminFallbackStore.shops);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: AdminPalette.primary),
            SizedBox(width: 10),
            Text('Chọn Gian Hàng Trực Tiếp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: allShops.map((s) {
                final logoUrl = s['logo_path'];
                final shopName = s['shop_name'] ?? 'Gian hàng';
                final owner = s['profiles'] is Map ? (s['profiles']['display_name'] ?? s['profiles']['username']) : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminPalette.border),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminPalette.border),
                        image: logoUrl != null
                            ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: logoUrl == null
                          ? const Icon(Icons.store_rounded, color: AdminPalette.textSecondary)
                          : null,
                    ),
                    title: Text(shopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: Text(
                      'Chủ shop: ${owner ?? s['owner_name'] ?? "Seller"} • @${s['shop_slug'] ?? "shop"}',
                      style: const TextStyle(fontSize: 11.5, color: AdminPalette.textSecondary),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _enterShopPortal(s, 'seller@shareco.vn', allShops: allShops);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminPalette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Quản Lý', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -100,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AdminPalette.primary.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -80,
            child: Container(
              width: 460,
              height: 460,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AdminPalette.accent.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1060),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 820;
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: isWide
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 11, child: _buildHeroBanner(isWide: true)),
                                  Expanded(
                                    flex: 12,
                                    child: Center(
                                      child: SingleChildScrollView(
                                        physics: const ClampingScrollPhysics(),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 36,
                                          vertical: 28,
                                        ),
                                        child: _buildLoginForm(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                _buildHeroBanner(isWide: false),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 24,
                                  ),
                                  child: _buildLoginForm(),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner({required bool isWide}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4338CA), Color(0xFF6D28D9), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: isWide
            ? const BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 36 : 24,
        vertical: isWide ? 32 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SHARECO COMMERCE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'TikTok-Style Commerce Portal',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Cổng Quản Trị Hệ Thống\n& Kênh Người Bán',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Đăng nhập với vai trò Quản Trị Viên Sàn hoặc Nhà Bán Hàng (Người dùng đã đăng ký gian hàng) để quản lý kho hàng, sản phẩm và theo dõi đơn giao.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _buildFeatureRow(
                Icons.admin_panel_settings_rounded,
                'Super Admin: Phê duyệt gian hàng, kiểm duyệt người dùng, cấm live, ban vi phạm',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.storefront_rounded,
                'Kênh Người Bán: Dành cho người dùng đã đăng ký shop, quản lý sản phẩm & đơn hàng',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.swap_horiz_rounded,
                'Hỗ trợ Đa Gian Hàng: Tự động nhận diện và chuyển đổi nhanh giữa các shop sở hữu',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.tips_and_updates_rounded, color: Color(0xFFFBBF24), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lưu ý: Gian hàng được khởi tạo khi người dùng nộp đơn "Đăng ký bán hàng" trên ứng dụng ShareCo.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFC4B5FD), size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    final isShopRole = _selectedRoleType == 'shop';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isShopRole ? 'Kênh Người Bán (Seller Portal)' : 'Cổng Quản Trị Super Admin',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isShopRole
              ? 'Đăng nhập bằng tài khoản ShareCo (Email hoặc Username) đã mở shop.'
              : 'Dành cho quản trị viên sàn ShareCo phê duyệt & kiểm duyệt hệ thống.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.35),
        ),
        const SizedBox(height: 16),

        // Role Selector Tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildRoleTab(
                  role: 'admin',
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Super Admin',
                  defaultAccount: 'admin@shareco.vn',
                ),
              ),
              Expanded(
                child: _buildRoleTab(
                  role: 'shop',
                  icon: Icons.storefront_rounded,
                  label: 'Người Bán / Shop',
                  defaultAccount: 'huy123',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Account Input Field
        Text(
          isShopRole ? 'EMAIL HOẶC USERNAME' : 'EMAIL SUPER ADMIN',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            hintText: isShopRole ? 'VD: huy123 hoặc chungngo' : 'admin@shareco.vn',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            prefixIcon: Icon(
              isShopRole ? Icons.person_outline_rounded : Icons.alternate_email_rounded,
              color: const Color(0xFF94A3B8),
              size: 19,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminPalette.primaryLight, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Password Field
        const Text(
          'MẬT KHẨU',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onSubmitted: (_) => _handleLogin(),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            hintText: '••••••••',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 19),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF94A3B8),
                size: 19,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminPalette.primaryLight, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminPalette.primaryLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isShopRole ? 'Vào Kênh Người Bán' : 'Vào Cổng Super Admin',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // 1-Click Demo Quick Access
        const Text(
          'ĐĂNG NHẬP NHANH TÀI KHOẢN HỆ THỐNG (1-CLICK):',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildDemoChip(
              label: '👑 Super Admin',
              role: 'admin',
              account: 'admin@shareco.vn',
            ),
            _buildDemoChip(
              label: '🏪 Huy IT (5 Shop: Đồ Nam, Apple...)',
              role: 'shop',
              account: 'huy123',
            ),
            _buildDemoChip(
              label: "💄 Chung Ngô (Shop L'orean)",
              role: 'shop',
              account: 'chungngo',
            ),
            // Nút mở chọn nhanh bất kỳ gian hàng nào trên hệ thống
            InkWell(
              onTap: _openDirectShopPicker,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AdminPalette.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AdminPalette.accent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, size: 13, color: AdminPalette.accent),
                    SizedBox(width: 4),
                    Text(
                      'Tất cả Shop trên sàn ↗',
                      style: TextStyle(
                        color: AdminPalette.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleTab({
    required String role,
    required IconData icon,
    required String label,
    required String defaultAccount,
  }) {
    final isSelected = _selectedRoleType == role;
    return InkWell(
      onTap: () => _applyQuickDemo(role: role, account: defaultAccount),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AdminPalette.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoChip({
    required String label,
    required String role,
    required String account,
  }) {
    final isCurrent = _emailCtrl.text.trim() == account && _selectedRoleType == role;
    return InkWell(
      onTap: () => _applyQuickDemo(role: role, account: account),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isCurrent
              ? AdminPalette.primaryLight.withValues(alpha: 0.22)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isCurrent ? AdminPalette.primaryLight : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isCurrent ? Colors.white : const Color(0xFFCBD5E1),
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
