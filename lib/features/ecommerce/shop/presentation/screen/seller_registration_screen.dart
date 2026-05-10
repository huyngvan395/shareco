import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  State<SellerRegistrationScreen> createState() => _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;

  File? _logoFile;
  File? _coverFile;

  bool _checkingExistingShop = true;
  Map<String, dynamic>? _existingShopData;

  @override
  void initState() {
    super.initState();
    _checkExistingShop();
  }

  Future<void> _checkExistingShop() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('shops')
            .select()
            .eq('owner_id', user.id)
            .maybeSingle();
        if (data != null) {
          setState(() {
            _existingShopData = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking existing shop: $e');
    } finally {
      if (mounted) {
        setState(() {
          _checkingExistingShop = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // Auto generate slug from name
  void _onNameChanged(String val) {
    final clean = val
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    _slugCtrl.text = clean;
  }

  Future<void> _pickImage(bool isLogo) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLogo ? 'Chọn Ảnh Đại Diện (Logo)' : 'Chọn Ảnh Bìa (Cover)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                    child: Column(
                      children: [
                        const Icon(Icons.camera_alt_rounded, color: Color(0xFFEE4D2D), size: 36),
                        const SizedBox(height: 8),
                        const Text('Chụp ảnh', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                    child: Column(
                      children: [
                        const Icon(Icons.image_search_rounded, color: Colors.blueAccent, size: 36),
                        const SizedBox(height: 8),
                        const Text('Thư viện', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          if (isLogo) {
            _logoFile = File(picked.path);
          } else {
            _coverFile = File(picked.path);
          }
        });
      }
    }
  }

  Future<String?> _uploadShopAsset(File file, String type, String userId) async {
    try {
      final fileExt = file.path.split('.').last.toLowerCase();
      final path = 'shops/$userId/${type}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));
          
      return Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('Upload shop asset error: $e');
      return null;
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Vui lòng đăng nhập trước khi đăng ký làm người bán.');
      }

      if (_logoFile == null) {
        throw Exception('Vui lòng chọn ảnh đại diện (Logo) cho nhãn hàng.');
      }
      if (_coverFile == null) {
        throw Exception('Vui lòng chọn ảnh bìa (Cover) cho nhãn hàng.');
      }

      final slug = _slugCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      final desc = _descCtrl.text.trim();

      // Upload logo
      final logoUrl = await _uploadShopAsset(_logoFile!, 'logo', user.id);
      if (logoUrl == null) {
        throw Exception('Không thể tải lên ảnh đại diện. Vui lòng thử lại.');
      }

      // Upload cover
      final coverUrl = await _uploadShopAsset(_coverFile!, 'cover', user.id);
      if (coverUrl == null) {
        throw Exception('Không thể tải lên ảnh bìa. Vui lòng thử lại.');
      }

      // Insert shop into public.shops table
      await Supabase.instance.client.from('shops').insert({
        'owner_id': user.id,
        'shop_name': name,
        'shop_slug': slug,
        'description': desc,
        'logo_path': logoUrl,
        'cover_path': coverUrl,
        'status': 'active',
      });

      if (!mounted) return;

      // Show stunning Success Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 64),
              SizedBox(height: 16),
              Text(
                'Đăng Ký Thành Công! 🎉',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: const Text(
            'Nhãn hàng của bạn đã được khởi tạo thành công trên hệ thống Shareco. Bạn có thể đăng nhập vào Web Admin để bắt đầu kinh doanh ngay!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // pop dialog
                  Navigator.pop(context); // pop register screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEE4D2D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Bắt đầu ngay', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng ký thất bại: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildExistingShopView() {
    final logoUrl = _existingShopData?['logo_path'] ?? '';
    final coverUrl = _existingShopData?['cover_path'] ?? '';
    final shopName = _existingShopData?['shop_name'] ?? 'Cửa hàng của bạn';
    final shopSlug = _existingShopData?['shop_slug'] ?? '';
    final description = _existingShopData?['description'] ?? 'Chưa có mô tả';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEE4D2D),
                          image: coverUrl.isNotEmpty
                              ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover)
                              : null,
                        ),
                      ),
                      Container(
                        height: 140,
                        width: double.infinity,
                        color: Colors.black.withOpacity(0.15),
                      ),
                      Positioned(
                        bottom: -45,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            image: logoUrl.isNotEmpty
                                ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 55),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              shopName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Colors.blue, size: 20),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$shopSlug',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withOpacity(0.15), width: 1.5),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Bạn đã đăng ký tài khoản người bán thành công! Nhãn hàng hiện đang hoạt động và sẵn sàng kinh doanh.',
                                  style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEE4D2D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text(
                  'Quay lại Trang chủ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Đăng Ký Người Bán / Brand 🏷️',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: _checkingExistingShop
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFEE4D2D)),
                  SizedBox(height: 16),
                  Text('Đang kiểm tra thông tin...', style: TextStyle(color: Colors.black54)),
                ],
              ),
            )
          : _existingShopData != null
              ? _buildExistingShopView()
              : _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFEE4D2D)),
                          SizedBox(height: 16),
                          Text('Đang tạo nhãn hàng của bạn...', style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Image
                    Container(
                      width: double.infinity,
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEE4D2D), Color(0xFFFF7337)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trở thành Đối tác Nhãn hàng',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tiếp cận hàng triệu khách hàng cùng Shareco!',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Brand Name input
                    TextFormField(
                      controller: _nameCtrl,
                      onChanged: _onNameChanged,
                      decoration: InputDecoration(
                        labelText: 'Tên nhãn hàng / Brand Name *',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEE4D2D), width: 2),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập tên nhãn hàng của bạn';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Shop Slug (automatic)
                    TextFormField(
                      controller: _slugCtrl,
                      decoration: InputDecoration(
                        labelText: 'Slug định danh (Auto) *',
                        prefixIcon: const Icon(Icons.link_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: 'e.g. apple-official',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng điền slug định danh';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Mô tả nhãn hàng / Description *',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                        hintText: 'Mô tả chi tiết về nhãn hàng của bạn...',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập mô tả thương hiệu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Logo Image Selector
                    const Text(
                      'Ảnh đại diện cửa hàng (Logo) *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: () => _pickImage(true),
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF5F5F5),
                                border: Border.all(color: const Color(0xFFEE4D2D), width: 2),
                                image: _logoFile != null
                                    ? DecorationImage(image: FileImage(_logoFile!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _logoFile == null
                                  ? const Icon(Icons.add_a_photo_outlined, size: 36, color: Color(0xFFEE4D2D))
                                  : null,
                            ),
                            if (_logoFile != null)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEE4D2D),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cover Image Selector
                    const Text(
                      'Ảnh bìa cửa hàng (Cover) *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _pickImage(false),
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFF5F5F5),
                          border: Border.all(color: Colors.grey[300]!, width: 1.5),
                          image: _coverFile != null
                              ? DecorationImage(image: FileImage(_coverFile!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _coverFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey[600]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Bấm để tải ảnh bìa lên',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              )
                            : Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEE4D2D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Đăng Ký Ngay',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
