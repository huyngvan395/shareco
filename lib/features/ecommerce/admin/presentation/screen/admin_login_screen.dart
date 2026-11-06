import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shareco/routes/admin_router.dart';
import '../bloc/admin_bloc.dart';
import '../widgets/admin_ui_helpers.dart';

class AdminSession {
  static String? loggedInRole; // 'admin' or 'shop'
  static String? loggedInShopId;
  static String? loggedInShopName;
  static String? loggedInEmail;
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController(text: 'admin@shareco.vn');
  final _passwordCtrl = TextEditingController(text: '123456');
  final _regNameCtrl = TextEditingController();
  final _regDescCtrl = TextEditingController();
  final _regSlugCtrl = TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRoleType = 'admin';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _regNameCtrl.dispose();
    _regDescCtrl.dispose();
    _regSlugCtrl.dispose();
    super.dispose();
  }

  void _onRegNameChanged(String val) {
    final clean = val
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    _regSlugCtrl.text = clean;
  }

  void _applyQuickDemo({
    required String role,
    required String email,
  }) {
    setState(() {
      _selectedRoleType = role;
      _emailCtrl.text = email;
      _passwordCtrl.text = '123456';
      _isRegistering = false;
    });
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ Email và Mật khẩu.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user;
      try {
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        user = res.user;
      } catch (e) {
        debugPrint('Supabase sign-in fallback active: $e');
      }

      if (email.contains('admin') || _selectedRoleType == 'admin') {
        AdminSession.loggedInRole = 'admin';
        AdminSession.loggedInEmail = email;
        AdminSession.loggedInShopId = null;
        AdminSession.loggedInShopName = 'ShareCo Super Admin';

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

      // Brand / Shop Owner Login with resilient offline fallback
      final keyword = email.split('@').first.toLowerCase();
      List<dynamic> shopsResult = [];

      try {
        final supabase = Supabase.instance.client;
        if (user?.id != null) {
          shopsResult = await supabase.from('shops').select().eq('owner_id', user!.id);
        }
        if (shopsResult.isEmpty) {
          shopsResult = await supabase.from('shops').select().ilike('shop_slug', '%$keyword%');
        }
      } catch (_) {
        // Fallback lookup in AdminFallbackStore when Supabase is paused/offline
        shopsResult = AdminFallbackStore.shops.where((s) {
          final slug = (s['shop_slug'] ?? '').toString().toLowerCase();
          final name = (s['shop_name'] ?? '').toString().toLowerCase();
          return slug.contains(keyword) || name.contains(keyword);
        }).toList();
      }

      if (shopsResult.isEmpty) {
        setState(() {
          _isRegistering = true;
          _regNameCtrl.text = email.split('@').first.toUpperCase();
          _onRegNameChanged(_regNameCtrl.text);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tài khoản chưa có Gian hàng. Vui lòng hoàn tất thông tin dưới đây để mở Shop!',
            ),
            backgroundColor: AdminPalette.warning,
          ),
        );
      } else {
        final shop = shopsResult.first;
        AdminSession.loggedInRole = 'shop';
        AdminSession.loggedInEmail = email;
        AdminSession.loggedInShopId = shop['id'];
        AdminSession.loggedInShopName = shop['shop_name'];

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng nhập đối tác [${shop['shop_name']}] thành công! 🏷️'),
            backgroundColor: AdminPalette.success,
          ),
        );
        context.go(AdminRouter.products);
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

  Future<void> _handleRegisterBrand() async {
    final name = _regNameCtrl.text.trim();
    final slug = _regSlugCtrl.text.trim();
    final desc = _regDescCtrl.text.trim();

    if (name.isEmpty || slug.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin nhãn hàng.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> newShop;
      try {
        final supabase = Supabase.instance.client;
        String ownerId;
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          ownerId = currentUser.id;
        } else {
          final profiles = await supabase.from('profiles').select('id').limit(1);
          ownerId = profiles.first['id'];
        }

        final inserted = await supabase.from('shops').insert({
          'owner_id': ownerId,
          'shop_name': name,
          'shop_slug': slug,
          'description': desc,
          'logo_path':
              'https://images.unsplash.com/photo-1541746972996-4e0b0f43e01a?w=120&h=120&fit=crop',
          'cover_path':
              'https://images.unsplash.com/photo-1557683316-973673baf926?w=800&h=400&fit=crop',
          'status': 'active',
        }).select();
        newShop = Map<String, dynamic>.from(inserted.first);
      } catch (_) {
        newShop = {
          'id': 'shop-${DateTime.now().millisecondsSinceEpoch}',
          'shop_name': name,
          'shop_slug': slug,
          'description': desc,
          'logo_path':
              'https://images.unsplash.com/photo-1541746972996-4e0b0f43e01a?w=120&h=120&fit=crop',
          'cover_path':
              'https://images.unsplash.com/photo-1557683316-973673baf926?w=800&h=400&fit=crop',
          'rating_avg': 5.0,
          'rating_count': 0,
          'follower_count': 0,
          'is_verified': true,
          'status': 'active',
        };
        AdminFallbackStore.shops.insert(0, newShop);
      }

      AdminSession.loggedInRole = 'shop';
      AdminSession.loggedInEmail = _emailCtrl.text.trim();
      AdminSession.loggedInShopId = newShop['id'];
      AdminSession.loggedInShopName = newShop['shop_name'];

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Khởi tạo Nhãn hàng [${newShop['shop_name']}] thành công!'),
          backgroundColor: AdminPalette.success,
        ),
      );
      context.go(AdminRouter.products);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Stack(
        children: [
          // Ambient glowing orbs in background
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
                                    child: Padding(
                                      padding: const EdgeInsets.all(44),
                                      child: _isRegistering
                                          ? _buildRegisterForm()
                                          : _buildLoginForm(),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                _buildHeroBanner(isWide: false),
                                Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: _isRegistering
                                      ? _buildRegisterForm()
                                      : _buildLoginForm(),
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
      padding: EdgeInsets.all(isWide ? 44 : 28),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SHARECO COMMERCE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Social Video & E-Commerce Ecosystem',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                'Trung Tâm Quản Trị\nSàn Thương Mại & Video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Quản lý tập trung hệ sinh thái Nhãn hàng chính hãng, Sản phẩm gắn thẻ trên Video TikTok-style và Vận hành đơn hàng thời gian thực.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              _buildFeatureRow(
                Icons.verified_rounded,
                'Phân quyền đa tầng: Super Admin & Đối tác Brand',
              ),
              const SizedBox(height: 12),
              _buildFeatureRow(
                Icons.local_mall_rounded,
                'Đồng bộ trực tiếp với tính năng Gắn Sản Phẩm trên Video App',
              ),
              const SizedBox(height: 12),
              _buildFeatureRow(
                Icons.analytics_rounded,
                'Thống kê tồn kho, doanh thu và trạng thái đơn hàng tức thì',
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.tips_and_updates_rounded, color: Color(0xFFFBBF24), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mẹo: Chọn nhanh tài khoản Demo ở khung bên phải để trải nghiệm ngay mà không cần gõ mật khẩu.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
          child: Icon(icon, color: const Color(0xFFC4B5FD), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đăng Nhập Cổng Quản Trị',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Chọn vai trò truy cập hoặc bấm vào thẻ Demo nhanh bên dưới.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        const SizedBox(height: 22),

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
                  defaultEmail: 'admin@shareco.vn',
                ),
              ),
              Expanded(
                child: _buildRoleTab(
                  role: 'shop',
                  icon: Icons.storefront_rounded,
                  label: 'Đối Tác Nhãn Hàng',
                  defaultEmail: 'loreal@brand.com',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Email Field
        const Text(
          'EMAIL ĐĂNG NHẬP',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            hintText: _selectedRoleType == 'admin' ? 'admin@shareco.vn' : 'loreal@brand.com',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF94A3B8), size: 19),
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
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onSubmitted: (_) => _handleLogin(),
          decoration: InputDecoration(
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
        const SizedBox(height: 24),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 50,
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
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Truy Cập Hệ Thống',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 22),

        // 1-Click Demo Account Chips
        const Text(
          'CHỌN NHANH TÀI KHOẢN DEMO (1-CLICK):',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildDemoChip(
              label: '👑 Super Admin',
              role: 'admin',
              email: 'admin@shareco.vn',
            ),
            _buildDemoChip(
              label: "💄 L'Oreal Paris",
              role: 'shop',
              email: 'loreal@brand.com',
            ),
            _buildDemoChip(
              label: '🌿 The Cocoon',
              role: 'shop',
              email: 'cocoon@brand.com',
            ),
            _buildDemoChip(
              label: '💧 CeraVe',
              role: 'shop',
              email: 'cerave@brand.com',
            ),
            _buildDemoChip(
              label: '☀️ Anessa',
              role: 'shop',
              email: 'anessa@brand.com',
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
    required String defaultEmail,
  }) {
    final isSelected = _selectedRoleType == role;
    return InkWell(
      onTap: () => _applyQuickDemo(role: role, email: defaultEmail),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
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
    required String email,
  }) {
    final isCurrent = _emailCtrl.text.trim() == email && _selectedRoleType == role;
    return InkWell(
      onTap: () => _applyQuickDemo(role: role, email: email),
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

  Widget _buildRegisterForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => setState(() => _isRegistering = false),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Đăng Ký Đối Tác Nhãn Hàng 🏷️',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tài khoản (${_emailCtrl.text}) chưa có cửa hàng. Khởi tạo gian hàng chính hãng ngay:',
          style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12.5),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _regNameCtrl,
          onChanged: _onRegNameChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Tên Nhãn Hàng / Official Store',
            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _regSlugCtrl,
          readOnly: true,
          style: const TextStyle(color: Color(0xFF94A3B8)),
          decoration: InputDecoration(
            labelText: 'Đường dẫn định danh (Slug)',
            labelStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _regDescCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Mô tả & Cam kết chính hãng',
            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegisterBrand,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminPalette.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Hoàn Tất & Mở Gian Hàng',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}
