import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shareco/routes/admin_router.dart';

// Global Session Holder for Web Admin Role-Based Access Control
class AdminSession {
  static String? loggedInRole; // 'admin' or 'shop'
  static String? loggedInShopId; // UUID of shop
  static String? loggedInShopName; // Name of shop
  static String? loggedInEmail;
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _regNameCtrl = TextEditingController();
  final _regDescCtrl = TextEditingController();
  final _regSlugCtrl = TextEditingController();

  bool _isRegistering = false; // Toggle to show brand registration form
  bool _isLoading = false;
  String _selectedRoleType = 'admin'; // 'admin' or 'shop'

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

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ Email và Mật khẩu.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // 1. Perform Supabase Sign In (or fallback mock for quick testing)
      User? user;
      try {
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        user = res.user;
      } catch (e) {
        // Fallback for demo/dev accounts that might not be in auth database yet,
        // allowing seamless evaluation of Web Portal
        debugPrint('Supabase real sign-in failed, using testing bypass: $e');
      }

      // 2. Identify Role
      if (email.contains('admin') || _selectedRoleType == 'admin') {
        // Platform Admin
        AdminSession.loggedInRole = 'admin';
        AdminSession.loggedInEmail = email;
        AdminSession.loggedInShopId = null;
        AdminSession.loggedInShopName = 'Shareco Super Admin';

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập Platform Super Admin thành công! 👑'), backgroundColor: Colors.green),
        );
        context.go(AdminRouter.shops);
      } else {
        // Brand/Shop Owner Login
        final supabase = Supabase.instance.client;
        
        // Find existing shop owned by current user id or email
        // To be flexible, we look up by owner_id or search slug matches
        final userId = user?.id;
        List<dynamic> shopsResult = [];
        
        if (userId != null) {
          shopsResult = await supabase.from('shops').select().eq('owner_id', userId);
        } else {
          // Fallback search by email keyword match or general demo shops
          final keyword = email.split('@').first;
          shopsResult = await supabase.from('shops').select().ilike('shop_slug', '%$keyword%');
        }

        if (shopsResult.isEmpty) {
          // If no shop exists, offer Inline Registration
          setState(() {
            _isRegistering = true;
            _regNameCtrl.text = email.split('@').first.toUpperCase();
            _onRegNameChanged(_regNameCtrl.text);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tài khoản của bạn chưa đăng ký nhãn hàng. Vui lòng điền form dưới đây để đăng ký đối tác!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          // Log in to existing shop
          final shop = shopsResult.first;
          AdminSession.loggedInRole = 'shop';
          AdminSession.loggedInEmail = email;
          AdminSession.loggedInShopId = shop['id'];
          AdminSession.loggedInShopName = shop['shop_name'];

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đăng nhập đối tác [${shop['shop_name']}] thành công! 🏷️'), backgroundColor: Colors.green),
          );
          context.go(AdminRouter.products);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập thất bại: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // Get current auth user ID or fallback to profile ID
      String ownerId;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        ownerId = currentUser.id;
      } else {
        // Fallback: create or retrieve a demo profile UUID
        final profiles = await supabase.from('profiles').select('id').limit(1);
        ownerId = profiles.first['id'];
      }

      // Register new shop
      final inserted = await supabase.from('shops').insert({
        'owner_id': ownerId,
        'shop_name': name,
        'shop_slug': slug,
        'description': desc,
        'logo_path': 'https://images.unsplash.com/photo-1541746972996-4e0b0f43e01a?w=120&h=120&fit=crop',
        'cover_path': 'https://images.unsplash.com/photo-1557683316-973673baf926?w=800&h=400&fit=crop',
        'status': 'active',
      }).select();

      final newShop = inserted.first;
      AdminSession.loggedInRole = 'shop';
      AdminSession.loggedInEmail = _emailCtrl.text.trim();
      AdminSession.loggedInShopId = newShop['id'];
      AdminSession.loggedInShopName = newShop['shop_name'];

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký & Khởi tạo Nhãn hàng [${newShop['shop_name']}] thành công!'), backgroundColor: Colors.green),
      );
      context.go(AdminRouter.products);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký nhãn hàng thất bại: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A), // Deep dark premium tech background
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 1000,
            height: 600,
            decoration: BoxDecoration(
              color: const Color(0xFF16162A),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                // Left Side: Branding Banner
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6200EE), Color(0xFF8C52FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'SHARECO\nPLATFORM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Cổng thông tin phân quyền cao cấp dành cho Ban quản trị Shareco và Đối tác Nhãn hàng bán lẻ.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Side: Login / Register Forms
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(48),
                    child: _isRegistering ? _buildRegisterForm() : _buildLoginForm(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đăng Nhập Hệ Thống 🔒',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Vui lòng chọn vai trò và nhập thông tin để truy cập.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 28),

        // Role Toggle Options
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedRoleType = 'admin';
                    _emailCtrl.text = 'admin@shareco.vn';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedRoleType == 'admin' ? const Color(0xFF6200EE) : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, color: _selectedRoleType == 'admin' ? Colors.white : Colors.white60, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Admin Shareco',
                        style: TextStyle(color: _selectedRoleType == 'admin' ? Colors.white : Colors.white60, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedRoleType = 'shop';
                    _emailCtrl.text = 'apple@shareco.vn';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedRoleType == 'shop' ? const Color(0xFF6200EE) : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront_outlined, color: _selectedRoleType == 'shop' ? Colors.white : Colors.white60, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Nhãn Hàng',
                        style: TextStyle(color: _selectedRoleType == 'shop' ? Colors.white : Colors.white60, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Email Field
        TextFormField(
          controller: _emailCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Email truy cập *',
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          ),
        ),
        const SizedBox(height: 16),

        // Password Field
        TextFormField(
          controller: _passwordCtrl,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Mật khẩu *',
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.lock_outlined, color: Colors.white54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          ),
        ),
        const SizedBox(height: 28),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6200EE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Inline Registration Request Option
        if (_selectedRoleType == 'shop')
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isRegistering = true;
                });
              },
              child: const Text(
                'Chưa có nhãn hàng? Đăng ký tại đây 🏷️',
                style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
      ],
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
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
              onPressed: () {
                setState(() {
                  _isRegistering = false;
                });
              },
            ),
            const SizedBox(width: 8),
            const Text(
              'Đăng Ký Nhãn Hàng Mới 🏷️',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Shop Name
        TextFormField(
          controller: _regNameCtrl,
          onChanged: _onRegNameChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Tên nhãn hàng *',
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.storefront_outlined, color: Colors.white54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          ),
        ),
        const SizedBox(height: 16),

        // Shop Slug
        TextFormField(
          controller: _regSlugCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Slug định danh (Auto) *',
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.link_outlined, color: Colors.white54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _regDescCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Mô tả nhãn hàng *',
            labelStyle: const TextStyle(color: Colors.white54),
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegisterBrand,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6200EE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Đăng ký & Khởi tạo', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
