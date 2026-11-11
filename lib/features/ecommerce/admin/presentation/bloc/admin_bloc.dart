import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shareco/features/ecommerce/product/domain/entities/product.dart';
import 'package:shareco/features/ecommerce/product/domain/entities/product_media.dart';
import 'package:shareco/features/ecommerce/product/domain/entities/product_variant.dart';
import 'package:shareco/features/ecommerce/order/domain/entities/ecommerce_order.dart';
import 'package:shareco/features/ecommerce/order/domain/entities/order_item.dart';
import 'package:shareco/features/ecommerce/order/domain/entities/order_tracking_event.dart';

import 'admin_event.dart';
import 'admin_state.dart';
import '../screen/admin_login_screen.dart';

/// Resilient fallback store used automatically when Supabase is paused or offline,
/// ensuring the Web Admin Portal always functions smoothly during demos/evaluations.
class AdminFallbackStore {
  static bool isOfflineMode = false;

  static final List<Map<String, dynamic>> shops = [
    {
      'id': 'shop-pending-01',
      'shop_name': 'Gia Dụng Thông Minh TechHouse',
      'shop_slug': 'gia-dung-thong-minh-techhouse',
      'description': 'Chuyên cung cấp các thiết bị gia dụng thông minh, phụ kiện đời sống tiện ích chính hãng.',
      'logo_path': 'https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=200&h=200&fit=crop',
      'cover_path': 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800&h=400&fit=crop',
      'rating_avg': 5.0,
      'rating_count': 0,
      'follower_count': 0,
      'is_verified': false,
      'status': 'pending',
      'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'pickup_address': 'Số 86 Đường Cầu Giấy',
      'pickup_ward': 'Phường Quan Hoa',
      'pickup_district': 'Quận Cầu Giấy',
      'pickup_province': 'Hà Nội',
      'profiles': {
        'id': 'user-owner-01',
        'display_name': 'Lê Hoàng Long',
        'username': 'hoanglong_tech',
        'avatar_url': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&h=150&fit=crop',
        'phone_number': '0988 123 456',
      },
    },
    {
      'id': 'shop-pending-02',
      'shop_name': 'Genz Daily Style Boutique',
      'shop_slug': 'genz-daily-style-boutique',
      'description': 'Thương hiệu thời trang thiết kế trẻ trung, bắt trend dành cho giới trẻ và học sinh sinh viên.',
      'logo_path': 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=200&h=200&fit=crop',
      'cover_path': 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&h=400&fit=crop',
      'rating_avg': 5.0,
      'rating_count': 0,
      'follower_count': 0,
      'is_verified': false,
      'status': 'pending',
      'created_at': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
      'pickup_address': 'Tầng 3, 45 Nguyễn Huệ',
      'pickup_ward': 'Phường Bến Nghé',
      'pickup_district': 'Quận 1',
      'pickup_province': 'TP. Hồ Chí Minh',
      'profiles': {
        'id': 'user-owner-02',
        'display_name': 'Trần Mai Anh',
        'username': 'maianh_style',
        'avatar_url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop',
        'phone_number': '0903 789 654',
      },
    },
    {
      'id': 'shop-loreal-01',
      'shop_name': "L'Oreal Paris Official",
      'shop_slug': 'loreal-paris-official',
      'description': 'Gian hàng chính hãng L\'Oreal Paris Việt Nam - Dược mỹ phẩm & Chăm sóc da hàng đầu từ Pháp.',
      'logo_path': 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=200&h=200&fit=crop',
      'cover_path': 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=800&h=400&fit=crop',
      'rating_avg': 4.9,
      'rating_count': 1240,
      'follower_count': 85400,
      'is_verified': true,
      'status': 'active',
      'created_at': '2024-01-10T10:00:00Z',
      'pickup_address': 'Tòa nhà Bitexco, Số 2 Hải Triều',
      'pickup_ward': 'Phường Bến Nghé',
      'pickup_district': 'Quận 1',
      'pickup_province': 'TP. Hồ Chí Minh',
      'profiles': {
        'id': 'user-loreal-admin',
        'display_name': 'Đại Diện L\'Oreal VN',
        'username': 'loreal_vietnam',
        'avatar_url': 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=150&h=150&fit=crop',
        'phone_number': '1900 1234',
      },
    },
    {
      'id': 'shop-cocoon-02',
      'shop_name': 'The Cocoon Original Vietnam',
      'shop_slug': 'the-cocoon-vietnam',
      'description': 'Mỹ phẩm thuần chay 100% sản xuất tại Việt Nam từ nguyên liệu thiên nhiên bản địa.',
      'logo_path': 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=200&h=200&fit=crop',
      'cover_path': 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800&h=400&fit=crop',
      'rating_avg': 4.95,
      'rating_count': 980,
      'follower_count': 62300,
      'is_verified': true,
      'status': 'active',
      'created_at': '2024-02-12T14:30:00Z',
      'pickup_address': 'Khu Công Nghiệp Tân Bình',
      'pickup_ward': 'Phường Tây Thạnh',
      'pickup_district': 'Quận Tân Phú',
      'pickup_province': 'TP. Hồ Chí Minh',
      'profiles': {
        'id': 'user-cocoon-admin',
        'display_name': 'Cocoon Nature Care',
        'username': 'cocoon_vietnam',
        'avatar_url': 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=150&h=150&fit=crop',
        'phone_number': '028 3812 3456',
      },
    },
    {
      'id': 'shop-cerave-03',
      'shop_name': 'CeraVe Official Store',
      'shop_slug': 'cerave-official',
      'description': 'Phát triển cùng chuyên gia da liễu Mỹ với 3 Ceramides thiết yếu phục hồi hàng rào bảo vệ da.',
      'logo_path': 'https://images.unsplash.com/photo-1608248597359-0e6d526a6828?w=200&h=200&fit=crop',
      'cover_path': 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=800&h=400&fit=crop',
      'rating_avg': 4.88,
      'rating_count': 750,
      'follower_count': 49100,
      'is_verified': true,
      'status': 'active',
      'created_at': '2024-03-01T09:15:00Z',
      'pickup_address': 'Kho Logistics Long Hậu',
      'pickup_ward': 'Xã Long Hậu',
      'pickup_district': 'Huyện Cần Giuộc',
      'pickup_province': 'Long An',
    },
    {
      'id': 'shop-anessa-04',
      'shop_name': 'Anessa Vietnam Flagship',
      'shop_slug': 'anessa-vietnam',
      'description': 'Thương hiệu chống nắng số 1 Nhật Bản suốt 22 năm liên tiếp thuộc tập đoàn Shiseido.',
      'logo_path': 'https://images.unsplash.com/photo-1526947425960-945c6e72858f?w=200&h=200&fit=crop',
      'cover_path': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&h=400&fit=crop',
      'rating_avg': 4.92,
      'rating_count': 630,
      'follower_count': 38900,
      'is_verified': true,
      'status': 'active',
      'created_at': '2024-03-10T11:00:00Z',
      'pickup_address': 'Shiseido Logistics Center',
      'pickup_ward': 'Phường Linh Trung',
      'pickup_district': 'TP. Thủ Đức',
      'pickup_province': 'TP. Hồ Chí Minh',
    },
    {
      'id': 'shop-rejected-05',
      'shop_name': 'Hàng Xách Tay Giá Sốc 99',
      'shop_slug': 'hang-xach-tay-gia-soc-99',
      'description': 'Cung cấp mỹ phẩm, nước hoa xách tay không giấy tờ giá rẻ nhất thị trường.',
      'logo_path': 'https://images.unsplash.com/photo-1612817288484-6f916006741a?w=200&h=200&fit=crop',
      'cover_path': 'https://images.unsplash.com/photo-1512290923902-8a9f81dc236c?w=800&h=400&fit=crop',
      'rating_avg': 3.0,
      'rating_count': 2,
      'follower_count': 15,
      'is_verified': false,
      'status': 'rejected',
      'rejection_reason': 'Hồ sơ không có hóa đơn chứng từ chứng minh xuất xứ nguồn gốc hàng hóa chính ngạch theo quy định kiểm duyệt của ShareCo.',
      'created_at': '2026-11-01T15:00:00Z',
      'pickup_address': 'Ngõ 12 Đường Giải Phóng',
      'pickup_ward': 'Phường Phương Mai',
      'pickup_district': 'Quận Đống Đa',
      'pickup_province': 'Hà Nội',
      'profiles': {
        'id': 'user-rejected-01',
        'display_name': 'Nguyễn Văn Nam',
        'username': 'nam_xachtay',
        'avatar_url': null,
        'phone_number': '0977 444 333',
      },
    },
  ];

  static final List<Product> products = [
    const Product(
      id: 'prod-loreal-01',
      shopId: 'shop-loreal-01',
      categoryId: '11111111-1111-1111-1111-111111111101',
      shopName: "L'Oreal Paris Official",
      title: "Nước Tẩy Trang L'Oreal Micellar Water 3-in-1 Làm Sạch Sâu 400ml",
      description: 'Công nghệ Micellar giúp làm sạch sâu lớp trang điểm, bụi bẩn và bã nhờn mà không gây khô da.',
      brand: "L'Oreal",
      status: 'active',
      priceMin: 169000,
      priceMax: 169000,
      originalPrice: 229000,
      currency: 'VND',
      stockTotal: 245,
      soldCount: 1840,
      ratingAvg: 4.9,
      ratingCount: 520,
      coverPath: 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=400&h=400&fit=crop',
      variants: [
        ProductVariant(
          id: 'var-01',
          productId: 'prod-loreal-01',
          sku: 'SKU-LOREAL-400ML',
          variantName: 'Da dầu / Hỗn hợp 400ml',
          price: 169000,
          stockQty: 145,
          status: 'active',
        ),
        ProductVariant(
          id: 'var-02',
          productId: 'prod-loreal-01',
          sku: 'SKU-LOREAL-SENSITIVE',
          variantName: 'Da nhạy cảm 400ml',
          price: 169000,
          stockQty: 100,
          status: 'active',
        ),
      ],
    ),
    const Product(
      id: 'prod-cocoon-02',
      shopId: 'shop-cocoon-02',
      categoryId: '11111111-1111-1111-1111-111111111101',
      shopName: 'The Cocoon Original Vietnam',
      title: 'Tẩy Da Chết Toàn Thân Cà Phê Đắk Lắk Cocoon 200ml',
      description: 'Hạt cà phê Đắk Lắk nguyên chất kết hợp bơ ca cao Tiền Giang giúp làn da mềm mịn, sáng khỏe.',
      brand: 'Cocoon',
      status: 'active',
      priceMin: 115000,
      priceMax: 115000,
      originalPrice: 125000,
      currency: 'VND',
      stockTotal: 320,
      soldCount: 3420,
      ratingAvg: 4.95,
      ratingCount: 910,
      coverPath: 'https://images.unsplash.com/photo-1608248597359-0e6d526a6828?w=400&h=400&fit=crop',
      variants: [
        ProductVariant(
          id: 'var-03',
          productId: 'prod-cocoon-02',
          sku: 'SKU-COCOON-200G',
          variantName: 'Hũ 200ml',
          price: 115000,
          stockQty: 320,
          status: 'active',
        ),
      ],
    ),
    const Product(
      id: 'prod-cerave-03',
      shopId: 'shop-cerave-03',
      categoryId: '11111111-1111-1111-1111-111111111101',
      shopName: 'CeraVe Official Store',
      title: 'Sữa Rửa Mặt CeraVe Foaming Cleanser Cho Da Dầu & Nhạy Cảm 473ml',
      description: 'Sữa rửa mặt tạo bọt dịu nhẹ chứa 3 Ceramides thiết yếu, Niacinamide và Hyaluronic Acid.',
      brand: 'CeraVe',
      status: 'active',
      priceMin: 345000,
      priceMax: 345000,
      originalPrice: 430000,
      currency: 'VND',
      stockTotal: 88,
      soldCount: 920,
      ratingAvg: 4.88,
      ratingCount: 310,
      coverPath: 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=400&h=400&fit=crop',
      variants: [
        ProductVariant(
          id: 'var-04',
          productId: 'prod-cerave-03',
          sku: 'SKU-CERAVE-473ML',
          variantName: 'Chai lớn 473ml',
          price: 345000,
          stockQty: 88,
          status: 'active',
        ),
      ],
    ),
    const Product(
      id: 'prod-anessa-04',
      shopId: 'shop-anessa-04',
      categoryId: '11111111-1111-1111-1111-111111111101',
      shopName: 'Anessa Vietnam Flagship',
      title: 'Sữa Chống Nắng Anessa Perfect UV Sunscreen Skincare Milk SPF50+ PA++++ 60ml',
      description: 'Chống nắng dạng sữa kiềm dầu vượt trội với công nghệ Auto Booster kháng nước & mồ hôi.',
      brand: 'Anessa',
      status: 'active',
      priceMin: 525000,
      priceMax: 525000,
      originalPrice: 715000,
      currency: 'VND',
      stockTotal: 64,
      soldCount: 670,
      ratingAvg: 4.92,
      ratingCount: 245,
      coverPath: 'https://images.unsplash.com/photo-1526947425960-945c6e72858f?w=400&h=400&fit=crop',
    ),
    const Product(
      id: 'prod-laroche-05',
      shopId: 'shop-laroche-05',
      categoryId: '11111111-1111-1111-1111-111111111101',
      shopName: 'La Roche-Posay Chính Hãng',
      title: 'Kem Dưỡng Phục Hồi Da La Roche-Posay Cicaplast Baume B5+ 100ml',
      description: 'Kem dưỡng làm dịu, phục hồi da tổn thương, giảm thâm đỏ với công thức Tribioma & Panthenol 5%.',
      brand: 'La Roche-Posay',
      status: 'active',
      priceMin: 385000,
      priceMax: 385000,
      originalPrice: 495000,
      currency: 'VND',
      stockTotal: 9,
      soldCount: 1510,
      ratingAvg: 4.94,
      ratingCount: 640,
      coverPath: 'https://images.unsplash.com/photo-1612817288484-6f916006741a?w=400&h=400&fit=crop',
    ),
  ];

  static final List<EcommerceOrder> orders = [
    EcommerceOrder(
      id: 'ord-demo-1001',
      buyerId: 'buyer-01',
      shopId: 'shop-loreal-01',
      shopName: "L'Oreal Paris Official",
      orderCode: 'SHC-882419',
      status: 'pending',
      subtotalAmount: 338000,
      discountAmount: 20000,
      shippingAmount: 15000,
      totalAmount: 333000,
      currency: 'VND',
      addressSnapshot: const {
        'recipient_name': 'Nguyễn Minh Anh',
        'phone': '0908 234 567',
        'line1': '128 Nguyễn Thị Minh Khai',
        'ward': 'Phường Võ Thị Sáu',
        'district': 'Quận 3',
        'province': 'TP. Hồ Chí Minh',
      },
      note: 'Giao giờ hành chính giúp mình nhé shop!',
      placedAt: DateTime.now().subtract(const Duration(hours: 2)),
      items: const [
        OrderItem(
          id: 'item-01',
          orderId: 'ord-demo-1001',
          productId: 'prod-loreal-01',
          shopId: 'shop-loreal-01',
          title: "Nước Tẩy Trang L'Oreal Micellar Water 3-in-1 Làm Sạch Sâu 400ml",
          variantName: 'Da dầu / Hỗn hợp 400ml',
          imagePath: 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=400&h=400&fit=crop',
          unitPrice: 169000,
          qty: 2,
          lineTotal: 338000,
        ),
      ],
    ),
    EcommerceOrder(
      id: 'ord-demo-1002',
      buyerId: 'buyer-02',
      shopId: 'shop-cocoon-02',
      shopName: 'The Cocoon Original Vietnam',
      orderCode: 'SHC-882390',
      status: 'shipping',
      subtotalAmount: 230000,
      discountAmount: 0,
      shippingAmount: 15000,
      totalAmount: 245000,
      currency: 'VND',
      shippingCarrier: 'SPX Express',
      trackingCode: 'SPXVN08239088',
      pickupLocation: 'Bưu cục Tây Thạnh, Tân Phú, TP.HCM',
      currentLocation: 'Hub trung chuyển Tân Bình, TP.HCM',
      addressSnapshot: const {
        'recipient_name': 'Trần Hoàng Bảo Ngọc',
        'phone': '0987 654 321',
        'line1': '45 Lê Lợi',
        'ward': 'Phường Bến Nghé',
        'district': 'Quận 1',
        'province': 'TP. Hồ Chí Minh',
      },
      placedAt: DateTime.now().subtract(const Duration(hours: 9)),
      confirmedAt: DateTime.now().subtract(const Duration(hours: 8)),
      shippedAt: DateTime.now().subtract(const Duration(hours: 5)),
      items: const [
        OrderItem(
          id: 'item-02',
          orderId: 'ord-demo-1002',
          productId: 'prod-cocoon-02',
          shopId: 'shop-cocoon-02',
          title: 'Tẩy Da Chết Toàn Thân Cà Phê Đắk Lắk Cocoon 200ml',
          variantName: 'Hũ 200ml',
          imagePath: 'https://images.unsplash.com/photo-1608248597359-0e6d526a6828?w=400&h=400&fit=crop',
          unitPrice: 115000,
          qty: 2,
          lineTotal: 230000,
        ),
      ],
      trackingEvents: [
        OrderTrackingEvent(
          id: 'trk-03',
          orderId: 'ord-demo-1002',
          status: 'in_transit',
          title: 'Đang trung chuyển qua Hub Tân Bình',
          location: 'Hub trung chuyển Tân Bình, TP.HCM',
          description: 'Kiện hàng đang được phân loại và chuyển tiếp về bưu cục phát Quận 1.',
          carrierName: 'SPX Express',
          actorRole: 'carrier',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        OrderTrackingEvent(
          id: 'trk-02',
          orderId: 'ord-demo-1002',
          status: 'shipping',
          title: 'Đã bàn giao cho SPX Express',
          location: 'Bưu cục Tây Thạnh, Tân Phú, TP.HCM',
          description: 'Shipper SPX đã lấy hàng từ kho của người bán.',
          carrierName: 'SPX Express',
          actorRole: 'carrier',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        OrderTrackingEvent(
          id: 'trk-01',
          orderId: 'ord-demo-1002',
          status: 'packed',
          title: 'Người bán đã đóng gói hàng',
          description: 'Kiện hàng đã sẵn sàng giao cho đơn vị vận chuyển.',
          actorRole: 'seller',
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        ),
      ],
    ),
    EcommerceOrder(
      id: 'ord-demo-1003',
      buyerId: 'buyer-03',
      shopId: 'shop-anessa-04',
      shopName: 'Anessa Vietnam Flagship',
      orderCode: 'SHC-882105',
      status: 'completed',
      subtotalAmount: 525000,
      discountAmount: 35000,
      shippingAmount: 0,
      totalAmount: 490000,
      currency: 'VND',
      shippingCarrier: 'Giao Hàng Nhanh (GHN)',
      trackingCode: 'GHNVN9832104',
      pickupLocation: 'Shiseido Logistics Center, Thủ Đức',
      currentLocation: 'Khu đô thị Đại học Quốc Gia, TP. Thủ Đức',
      addressSnapshot: const {
        'recipient_name': 'Lê Quang Chung',
        'phone': '0912 888 999',
        'line1': 'Khu đô thị Đại học Quốc Gia',
        'ward': 'Phường Linh Trung',
        'district': 'TP. Thủ Đức',
        'province': 'TP. Hồ Chí Minh',
      },
      placedAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      confirmedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      shippedAt: DateTime.now().subtract(const Duration(hours: 18)),
      deliveredAt: DateTime.now().subtract(const Duration(hours: 2)),
      items: const [
        OrderItem(
          id: 'item-03',
          orderId: 'ord-demo-1003',
          productId: 'prod-anessa-04',
          shopId: 'shop-anessa-04',
          title: 'Sữa Chống Nắng Anessa Perfect UV Sunscreen Skincare Milk SPF50+ PA++++ 60ml',
          variantName: 'Tiêu chuẩn 60ml',
          imagePath: 'https://images.unsplash.com/photo-1526947425960-945c6e72858f?w=400&h=400&fit=crop',
          unitPrice: 525000,
          qty: 1,
          lineTotal: 525000,
        ),
      ],
      trackingEvents: [
        OrderTrackingEvent(
          id: 'trk-06',
          orderId: 'ord-demo-1003',
          status: 'completed',
          title: 'Giao hàng thành công',
          location: 'Khu đô thị Đại học Quốc Gia, TP. Thủ Đức',
          description: 'Người nhận đã nhận hàng và hoàn tất thanh toán.',
          carrierName: 'Giao Hàng Nhanh (GHN)',
          actorRole: 'carrier',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        OrderTrackingEvent(
          id: 'trk-05',
          orderId: 'ord-demo-1003',
          status: 'out_for_delivery',
          title: 'Shipper đang giao hàng',
          location: 'Bưu cục Linh Trung, TP. Thủ Đức',
          description: 'Shipper Nguyễn Tuấn đang liên hệ giao hàng.',
          carrierName: 'Giao Hàng Nhanh (GHN)',
          actorRole: 'carrier',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        OrderTrackingEvent(
          id: 'trk-04',
          orderId: 'ord-demo-1003',
          status: 'shipping',
          title: 'Đã bàn giao cho GHN',
          location: 'Shiseido Logistics Center, Thủ Đức',
          description: 'Kiện hàng đã rời kho người bán.',
          carrierName: 'Giao Hàng Nhanh (GHN)',
          actorRole: 'carrier',
          createdAt: DateTime.now().subtract(const Duration(hours: 18)),
        ),
      ],
    ),
  ];

  static final List<Map<String, dynamic>> videos = [
    {
      'id': 'vid-demo-01',
      'author_id': 'user-linh-01',
      'caption':
          'Chu trình skincare tối giản mỗi tối giúp da căng bóng sạch sâu với nước tẩy trang L\'Oreal hồng ✨ #skincare #loreal #shareco',
      'status': 'draft',
      'visibility': 'public',
      'video_path': 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      'thumbnail_path':
          'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=400&h=700&fit=crop',
      'duration_ms': 28000,
      'view_count': 0,
      'like_count': 0,
      'comment_count': 0,
      'share_count': 0,
      'created_at': DateTime.now().subtract(const Duration(minutes: 18)).toIso8601String(),
      'profiles': {
        'id': 'user-linh-01',
        'username': 'linhbeauty.vn',
        'display_name': 'Khánh Linh Beauty',
        'avatar_url':
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop',
        'is_verified': true,
      },
      'video_product_tags': [
        {
          'sort_order': 0,
          'products': {
            'id': 'prod-loreal-01',
            'title': "Nước Tẩy Trang L'Oreal Micellar Water 3-in-1 Làm Sạch Sâu 400ml",
            'price_min': 169000,
            'cover_path':
                'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=400&h=400&fit=crop',
            'brand': "L'Oreal",
          },
        },
      ],
    },
    {
      'id': 'vid-demo-02',
      'author_id': 'user-minh-02',
      'caption':
          'Review thực tế tẩy da chết cà phê Đắk Lắk Cocoon sau 1 tháng sử dụng! Thơm mùi cà phê cực mê 🌿☕ #cocoon #reviewlamdep',
      'status': 'draft',
      'visibility': 'public',
      'video_path': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'thumbnail_path':
          'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=400&h=700&fit=crop',
      'duration_ms': 42000,
      'view_count': 0,
      'like_count': 0,
      'comment_count': 0,
      'share_count': 0,
      'created_at': DateTime.now().subtract(const Duration(hours: 1, minutes: 12)).toIso8601String(),
      'profiles': {
        'id': 'user-minh-02',
        'username': 'minhskincare',
        'display_name': 'Minh Anh Review',
        'avatar_url':
            'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&h=150&fit=crop',
        'is_verified': false,
      },
      'video_product_tags': [
        {
          'sort_order': 0,
          'products': {
            'id': 'prod-cocoon-02',
            'title': 'Tẩy Da Chết Toàn Thân Cà Phê Đắk Lắk Cocoon 200ml',
            'price_min': 115000,
            'cover_path':
                'https://images.unsplash.com/photo-1608248597359-0e6d526a6828?w=400&h=400&fit=crop',
            'brand': 'Cocoon',
          },
        },
      ],
    },
    {
      'id': 'vid-demo-03',
      'author_id': 'user-chung-03',
      'caption':
          'Đi biển mùa hè không lo cháy nắng nhờ em kem chống nắng quốc dân Anessa kết hợp phục hồi da B5 La Roche-Posay ☀️🌊 #anessa #summer',
      'status': 'published',
      'visibility': 'public',
      'video_path': 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      'thumbnail_path':
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&h=700&fit=crop',
      'duration_ms': 35000,
      'view_count': 14820,
      'like_count': 2390,
      'comment_count': 184,
      'share_count': 96,
      'created_at': DateTime.now().subtract(const Duration(days: 1, hours: 3)).toIso8601String(),
      'published_at': DateTime.now().subtract(const Duration(days: 1, hours: 2)).toIso8601String(),
      'profiles': {
        'id': 'user-chung-03',
        'username': 'quangchung.official',
        'display_name': 'Quang Chung Creator',
        'avatar_url':
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&h=150&fit=crop',
        'is_verified': true,
      },
      'video_product_tags': [
        {
          'sort_order': 0,
          'products': {
            'id': 'prod-anessa-04',
            'title': 'Sữa Chống Nắng Anessa Perfect UV Sunscreen Skincare Milk SPF50+ PA++++ 60ml',
            'price_min': 525000,
            'cover_path':
                'https://images.unsplash.com/photo-1526947425960-945c6e72858f?w=400&h=400&fit=crop',
            'brand': 'Anessa',
          },
        },
        {
          'sort_order': 1,
          'products': {
            'id': 'prod-laroche-05',
            'title': 'Kem Dưỡng Phục Hồi Da La Roche-Posay Cicaplast Baume B5+ 100ml',
            'price_min': 385000,
            'cover_path':
                'https://images.unsplash.com/photo-1612817288484-6f916006741a?w=400&h=400&fit=crop',
            'brand': 'La Roche-Posay',
          },
        },
      ],
    },
    {
      'id': 'vid-demo-04',
      'author_id': 'user-spam-04',
      'caption':
          'Video quảng cáo hàng giả không rõ nguồn gốc xuất xứ vi phạm chính sách cộng đồng ShareCo ⚠️',
      'status': 'blocked',
      'visibility': 'public',
      'video_path': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'thumbnail_path':
          'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=400&h=700&fit=crop',
      'duration_ms': 15000,
      'view_count': 42,
      'like_count': 1,
      'comment_count': 0,
      'share_count': 0,
      'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'profiles': {
        'id': 'user-spam-04',
        'username': 'shop_gia_re_99',
        'display_name': 'Tài Khoản Vi Phạm',
        'avatar_url': null,
        'is_verified': false,
      },
      'video_product_tags': [],
    },
  ];

  static final List<Map<String, dynamic>> users = [
    {
      'id': 'user-linh-01',
      'username': 'linhbeauty.vn',
      'display_name': 'Khánh Linh Beauty',
      'avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop',
      'bio': 'Chuyên gia review skincare & mỹ phẩm thuần chay 🌿',
      'phone_number': '0912 345 678',
      'is_verified': true,
      'is_banned': false,
      'ban_reason': null,
      'banned_at': null,
      'banned_until': null,
      'can_live': true,
      'can_comment': true,
      'can_post_video': true,
      'strike_count': 0,
      'followers_count': 128500,
      'video_count': 42,
      'created_at': '2024-01-15T08:00:00Z',
    },
    {
      'id': 'user-chung-03',
      'username': 'quangchung.official',
      'display_name': 'Quang Chung Creator',
      'avatar_url': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&h=150&fit=crop',
      'bio': 'Kênh trải nghiệm du lịch, lifestyle & đồ gia dụng',
      'phone_number': '0988 777 666',
      'is_verified': true,
      'is_banned': false,
      'ban_reason': null,
      'banned_at': null,
      'banned_until': null,
      'can_live': true,
      'can_comment': true,
      'can_post_video': true,
      'strike_count': 0,
      'followers_count': 84200,
      'video_count': 35,
      'created_at': '2024-02-20T10:30:00Z',
    },
    {
      'id': 'user-owner-01',
      'username': 'hoanglong_tech',
      'display_name': 'Lê Hoàng Long',
      'avatar_url': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150&h=150&fit=crop',
      'bio': 'Chủ shop Gia Dụng Thông Minh TechHouse - Đang chờ duyệt gian hàng',
      'phone_number': '0988 123 456',
      'is_verified': false,
      'is_banned': false,
      'ban_reason': null,
      'banned_at': null,
      'banned_until': null,
      'can_live': true,
      'can_comment': true,
      'can_post_video': true,
      'strike_count': 0,
      'followers_count': 3400,
      'video_count': 8,
      'created_at': '2026-10-12T14:20:00Z',
    },
    {
      'id': 'user-minh-02',
      'username': 'minhskincare',
      'display_name': 'Minh Anh Review',
      'avatar_url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&h=150&fit=crop',
      'bio': 'Đam mê làm đẹp và trải nghiệm đồ tốt giá rẻ',
      'phone_number': '0933 555 444',
      'is_verified': false,
      'is_banned': false,
      'ban_reason': 'Tạm khóa quyền Livestream do phát nhạc vi phạm bản quyền quốc tế trong phiên live',
      'banned_at': null,
      'banned_until': null,
      'can_live': false,
      'can_comment': true,
      'can_post_video': true,
      'strike_count': 1,
      'followers_count': 15300,
      'video_count': 18,
      'created_at': '2024-04-05T09:00:00Z',
    },
    {
      'id': 'user-buyer-05',
      'username': 'phuongthao_98',
      'display_name': 'Phương Thảo',
      'avatar_url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop',
      'bio': 'Tín đồ mua sắm ShareCo Mall 🛍️',
      'phone_number': '0908 999 111',
      'is_verified': false,
      'is_banned': false,
      'ban_reason': null,
      'banned_at': null,
      'banned_until': null,
      'can_live': true,
      'can_comment': true,
      'can_post_video': true,
      'strike_count': 0,
      'followers_count': 560,
      'video_count': 4,
      'created_at': '2024-05-18T16:45:00Z',
    },
    {
      'id': 'user-spam-04',
      'username': 'shop_gia_re_99',
      'display_name': 'Tài Khoản Gian Lận Spam',
      'avatar_url': null,
      'bio': 'Bán hàng giả nhái, phát tán liên kết độc hại',
      'phone_number': '0977 444 333',
      'is_verified': false,
      'is_banned': true,
      'ban_reason': 'Phát tán hàng giả, đăng nội dung lừa đảo vi phạm nghiêm trọng Tiêu chuẩn Cộng đồng',
      'banned_at': '2026-11-05T10:00:00Z',
      'banned_until': '2027-11-05T10:00:00Z',
      'can_live': false,
      'can_comment': false,
      'can_post_video': false,
      'strike_count': 3,
      'followers_count': 420,
      'video_count': 3,
      'created_at': '2026-11-01T15:00:00Z',
    },
  ];
}

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc() : super(const AdminState()) {
    on<AdminFetchShops>(_onFetchShops);
    on<AdminCreateShop>(_onCreateShop);
    on<AdminUpdateShop>(_onUpdateShop);
    on<AdminToggleShopVerified>(_onToggleShopVerified);
    on<AdminToggleShopStatus>(_onToggleShopStatus);
    on<AdminApproveShop>(_onApproveShop);
    on<AdminRejectShop>(_onRejectShop);
    on<AdminFetchUsers>(_onFetchUsers);
    on<AdminToggleUserVerified>(_onToggleUserVerified);
    on<AdminBanUser>(_onBanUser);
    on<AdminToggleUserCanLive>(_onToggleUserCanLive);
    on<AdminToggleUserCanComment>(_onToggleUserCanComment);
    on<AdminIssueUserWarning>(_onIssueUserWarning);
    on<AdminFetchProducts>(_onFetchProducts);
    on<AdminCreateProduct>(_onCreateProduct);
    on<AdminUpdateProduct>(_onUpdateProduct);
    on<AdminDeleteProduct>(_onDeleteProduct);
    on<AdminToggleProductStatus>(_onToggleProductStatus);
    on<AdminFetchOrders>(_onFetchOrders);
    on<AdminUpdateOrderStatus>(_onUpdateOrderStatus);
    on<AdminConfirmAndPackOrder>(_onConfirmAndPackOrder);
    on<AdminHandoverOrderToCarrier>(_onHandoverOrderToCarrier);
    on<AdminAdvanceOrderLocation>(_onAdvanceOrderLocation);
    on<AdminSellerCancelOrder>(_onSellerCancelOrder);
    on<AdminFetchVideos>(_onFetchVideos);
    on<AdminUpdateVideoStatus>(_onUpdateVideoStatus);
    on<AdminApproveAllPendingVideos>(_onApproveAllPendingVideos);
  }

  Future<void> _onFetchShops(AdminFetchShops event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      dynamic response;
      try {
        response = await Supabase.instance.client
            .from('shops')
            .select('*, profiles:owner_id(id, username, display_name, avatar_url)')
            .order('created_at', ascending: false);
      } catch (_) {
        response = await Supabase.instance.client
            .from('shops')
            .select('*')
            .order('shop_name', ascending: true);
      }

      AdminFallbackStore.isOfflineMode = false;
      emit(state.copyWith(
        status: AdminStatus.success,
        shops: List<Map<String, dynamic>>.from(response),
      ));
    } catch (_) {
      AdminFallbackStore.isOfflineMode = true;
      emit(state.copyWith(
        status: AdminStatus.success,
        shops: List<Map<String, dynamic>>.from(AdminFallbackStore.shops),
      ));
    }
  }

  Future<void> _onCreateShop(AdminCreateShop event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    final slug = event.shopName.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    final logo = event.logoPath ??
        'https://images.unsplash.com/photo-1541963463532-d68292c34b19?w=150&h=150&fit=crop';
    final cover = event.coverPath ??
        'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?w=800&h=400&fit=crop';

    try {
      final profiles = await Supabase.instance.client.from('profiles').select('id').limit(1);
      if (profiles.isEmpty) {
        throw Exception('Vui lòng tạo ít nhất một tài khoản người dùng trước khi tạo shop.');
      }
      final ownerId = profiles.first['id'];

      await Supabase.instance.client.from('shops').insert({
        'owner_id': ownerId,
        'shop_name': event.shopName,
        'shop_slug': slug,
        'description': event.description,
        'logo_path': logo,
        'cover_path': cover,
        'rating_avg': 5.0,
        'rating_count': 0,
        'follower_count': 0,
        'status': 'active',
      });

      add(AdminFetchShops());
    } catch (_) {
      AdminFallbackStore.shops.insert(0, {
        'id': 'shop-${DateTime.now().millisecondsSinceEpoch}',
        'shop_name': event.shopName,
        'shop_slug': slug,
        'description': event.description,
        'logo_path': logo,
        'cover_path': cover,
        'rating_avg': 5.0,
        'rating_count': 0,
        'follower_count': 0,
        'is_verified': true,
        'status': 'active',
      });
      add(AdminFetchShops());
    }
  }

  Future<void> _onUpdateShop(AdminUpdateShop event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      await Supabase.instance.client.from('shops').update({
        'shop_name': event.shopName,
        'description': event.description,
        if (event.logoPath != null) 'logo_path': event.logoPath,
        if (event.coverPath != null) 'cover_path': event.coverPath,
      }).eq('id', event.id);

      add(AdminFetchShops());
    } catch (_) {
      final index = AdminFallbackStore.shops.indexWhere((s) => s['id'] == event.id);
      if (index != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.shops[index]);
        updated['shop_name'] = event.shopName;
        updated['description'] = event.description;
        if (event.logoPath != null) updated['logo_path'] = event.logoPath;
        if (event.coverPath != null) updated['cover_path'] = event.coverPath;
        AdminFallbackStore.shops[index] = updated;
      }
      add(AdminFetchShops());
    }
  }

  Future<void> _onToggleShopVerified(
    AdminToggleShopVerified event,
    Emitter<AdminState> emit,
  ) async {
    try {
      await Supabase.instance.client
          .from('shops')
          .update({'is_verified': event.isVerified}).eq('id', event.shopId);
    } catch (_) {
      final index = AdminFallbackStore.shops.indexWhere((s) => s['id'] == event.shopId);
      if (index != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.shops[index]);
        updated['is_verified'] = event.isVerified;
        AdminFallbackStore.shops[index] = updated;
      }
    }
    add(AdminFetchShops());
  }

  Future<void> _onToggleShopStatus(
    AdminToggleShopStatus event,
    Emitter<AdminState> emit,
  ) async {
    try {
      await Supabase.instance.client
          .from('shops')
          .update({'status': event.status}).eq('id', event.shopId);
    } catch (_) {
      final index = AdminFallbackStore.shops.indexWhere((s) => s['id'] == event.shopId);
      if (index != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.shops[index]);
        updated['status'] = event.status;
        AdminFallbackStore.shops[index] = updated;
      }
    }
    add(AdminFetchShops());
  }

  Future<void> _onApproveShop(
    AdminApproveShop event,
    Emitter<AdminState> emit,
  ) async {
    try {
      await Supabase.instance.client.from('shops').update({
        'status': 'active',
        'rejection_reason': null,
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', event.shopId);
    } catch (_) {
      final index = AdminFallbackStore.shops.indexWhere((s) => s['id'] == event.shopId);
      if (index != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.shops[index]);
        updated['status'] = 'active';
        updated['rejection_reason'] = null;
        updated['approved_at'] = DateTime.now().toIso8601String();
        AdminFallbackStore.shops[index] = updated;
      }
    }
    add(AdminFetchShops());
  }

  Future<void> _onRejectShop(
    AdminRejectShop event,
    Emitter<AdminState> emit,
  ) async {
    try {
      await Supabase.instance.client.from('shops').update({
        'status': 'rejected',
        'rejection_reason': event.reason,
      }).eq('id', event.shopId);
    } catch (_) {
      final index = AdminFallbackStore.shops.indexWhere((s) => s['id'] == event.shopId);
      if (index != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.shops[index]);
        updated['status'] = 'rejected';
        updated['rejection_reason'] = event.reason;
        AdminFallbackStore.shops[index] = updated;
      }
    }
    add(AdminFetchShops());
  }

  Future<void> _onFetchUsers(
    AdminFetchUsers event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      dynamic response;
      try {
        response = await Supabase.instance.client
            .from('profiles')
            .select('*, videos:videos!author_id(id)')
            .order('created_at', ascending: false);
      } catch (err) {
        response = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .order('created_at', ascending: false);
      }

      final List<Map<String, dynamic>> realUsers = (response as List).map((u) {
        final map = Map<String, dynamic>.from(u as Map);
        final vids = map['videos'] as List?;
        if (vids != null) {
          map['video_count'] = vids.length;
        } else {
          map['video_count'] = (map['video_count'] as num?)?.toInt() ?? 0;
        }
        map['is_verified'] = map['is_verified'] == true;
        map['is_banned'] = map['is_banned'] == true;
        map['can_live'] = map['can_live'] ?? true;
        map['can_comment'] = map['can_comment'] ?? true;
        map['can_post_video'] = map['can_post_video'] ?? true;
        map['strike_count'] = (map['strike_count'] as num?)?.toInt() ?? 0;
        map['follower_count'] = (map['follower_count'] as num?)?.toInt() ?? 0;
        map['following_count'] = (map['following_count'] as num?)?.toInt() ?? 0;
        return map;
      }).toList();

      AdminFallbackStore.isOfflineMode = false;
      emit(state.copyWith(
        status: AdminStatus.success,
        users: realUsers,
      ));
    } catch (_) {
      AdminFallbackStore.isOfflineMode = true;
      emit(state.copyWith(
        status: AdminStatus.success,
        users: List<Map<String, dynamic>>.from(AdminFallbackStore.users),
      ));
    }
  }

  Future<void> _onToggleUserVerified(
    AdminToggleUserVerified event,
    Emitter<AdminState> emit,
  ) async {
    // 1. Cập nhật lạc quan (optimistic) trên state hiện tại
    final updatedUsers = state.users.map((u) {
      if (u['id'] == event.userId) {
        final m = Map<String, dynamic>.from(u);
        m['is_verified'] = event.isVerified;
        return m;
      }
      return u;
    }).toList();
    emit(state.copyWith(users: updatedUsers));

    // 2. Gửi lệnh cập nhật lên Supabase database
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_verified': event.isVerified})
          .eq('id', event.userId);
    } catch (_) {
      final idx = AdminFallbackStore.users.indexWhere((u) => u['id'] == event.userId);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.users[idx]);
        updated['is_verified'] = event.isVerified;
        AdminFallbackStore.users[idx] = updated;
      }
    }
  }

  Future<void> _onBanUser(
    AdminBanUser event,
    Emitter<AdminState> emit,
  ) async {
    final Map<String, dynamic> updateData = {
      'is_banned': event.isBanned,
      'ban_reason': event.isBanned ? event.reason : null,
      'banned_at': event.isBanned ? DateTime.now().toIso8601String() : null,
      'banned_until': event.isBanned && event.durationDays != null
          ? DateTime.now().add(Duration(days: event.durationDays!)).toIso8601String()
          : null,
    };
    if (event.isBanned) {
      updateData['can_live'] = false;
    }

    // 1. Cập nhật lạc quan (optimistic) trên state
    final updatedUsers = state.users.map((u) {
      if (u['id'] == event.userId) {
        final m = Map<String, dynamic>.from(u);
        m.addAll(updateData);
        return m;
      }
      return u;
    }).toList();
    emit(state.copyWith(users: updatedUsers));

    // 2. Gửi lệnh cập nhật lên Supabase database
    try {
      await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', event.userId);
    } catch (_) {
      final idx = AdminFallbackStore.users.indexWhere((u) => u['id'] == event.userId);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.users[idx]);
        updated.addAll(updateData);
        AdminFallbackStore.users[idx] = updated;
      }
    }
  }

  Future<void> _onToggleUserCanLive(
    AdminToggleUserCanLive event,
    Emitter<AdminState> emit,
  ) async {
    final Map<String, dynamic> updateData = {
      'can_live': event.canLive,
      if (!event.canLive && event.reason != null) 'ban_reason': event.reason,
    };

    // 1. Cập nhật lạc quan (optimistic) trên state
    final updatedUsers = state.users.map((u) {
      if (u['id'] == event.userId) {
        final m = Map<String, dynamic>.from(u);
        m.addAll(updateData);
        return m;
      }
      return u;
    }).toList();
    emit(state.copyWith(users: updatedUsers));

    // 2. Gửi lệnh cập nhật lên Supabase database
    try {
      await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', event.userId);
    } catch (_) {
      final idx = AdminFallbackStore.users.indexWhere((u) => u['id'] == event.userId);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.users[idx]);
        updated.addAll(updateData);
        AdminFallbackStore.users[idx] = updated;
      }
    }
  }

  Future<void> _onToggleUserCanComment(
    AdminToggleUserCanComment event,
    Emitter<AdminState> emit,
  ) async {
    final Map<String, dynamic> updateData = {'can_comment': event.canComment};

    // 1. Cập nhật lạc quan (optimistic) trên state
    final updatedUsers = state.users.map((u) {
      if (u['id'] == event.userId) {
        final m = Map<String, dynamic>.from(u);
        m.addAll(updateData);
        return m;
      }
      return u;
    }).toList();
    emit(state.copyWith(users: updatedUsers));

    // 2. Gửi lệnh cập nhật lên Supabase database
    try {
      await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', event.userId);
    } catch (_) {
      final idx = AdminFallbackStore.users.indexWhere((u) => u['id'] == event.userId);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.users[idx]);
        updated.addAll(updateData);
        AdminFallbackStore.users[idx] = updated;
      }
    }
  }

  Future<void> _onIssueUserWarning(
    AdminIssueUserWarning event,
    Emitter<AdminState> emit,
  ) async {
    int currentStrikes = 0;
    final existing = state.users.firstWhere((u) => u['id'] == event.userId, orElse: () => {});
    if (existing.isNotEmpty) {
      currentStrikes = (existing['strike_count'] as num?)?.toInt() ?? 0;
    }
    final newStrikes = currentStrikes + 1;
    final shouldBan = newStrikes >= 3;
    final reason = 'Gậy cảnh cáo vi phạm lần thứ $newStrikes: ${event.reason}${shouldBan ? ' (Tự động khóa tài khoản do tích lũy đủ 3 gậy vi phạm)' : ''}';

    final Map<String, dynamic> updateData = {
      'strike_count': newStrikes,
      if (shouldBan) 'is_banned': true,
      if (shouldBan) 'can_live': false,
      'ban_reason': reason,
    };

    // 1. Cập nhật lạc quan (optimistic) trên state
    final updatedUsers = state.users.map((u) {
      if (u['id'] == event.userId) {
        final m = Map<String, dynamic>.from(u);
        m.addAll(updateData);
        return m;
      }
      return u;
    }).toList();
    emit(state.copyWith(users: updatedUsers));

    // 2. Gửi lệnh cập nhật lên Supabase database
    try {
      await Supabase.instance.client.from('profiles').update(updateData).eq('id', event.userId);
    } catch (_) {
      final idx = AdminFallbackStore.users.indexWhere((u) => u['id'] == event.userId);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.users[idx]);
        updated.addAll(updateData);
        AdminFallbackStore.users[idx] = updated;
      }
    }
  }

  Future<void> _onFetchProducts(AdminFetchProducts event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      dynamic query = Supabase.instance.client.from('products').select('''
        *,
        shops (shop_name),
        product_media (*),
        product_variants (*)
      ''');

      if (event.shopId != null) {
        query = query.eq('shop_id', event.shopId);
      }

      final response = await query.order('created_at', ascending: false);

      final productsList = List<Map<String, dynamic>>.from(response).map((p) {
        final shopMap = p['shops'] as Map<String, dynamic>?;
        final mediaList = List<Map<String, dynamic>>.from(p['product_media'] ?? []).map((m) {
          return ProductMedia(
            id: m['id'] ?? '',
            productId: m['product_id'] ?? '',
            mediaType: m['media_type'] ?? 'image',
            storagePath: m['storage_path'] ?? '',
            sortOrder: m['sort_order'] ?? 0,
          );
        }).toList();

        final variantsList = List<Map<String, dynamic>>.from(p['product_variants'] ?? []).map((v) {
          return ProductVariant(
            id: v['id'],
            productId: v['product_id'],
            sku: v['sku'],
            variantName: v['variant_name'],
            price: (v['price'] as num).toDouble(),
            stockQty: v['stock_qty'] ?? 0,
            status: v['status'] ?? 'active',
          );
        }).toList();

        return Product(
          id: p['id'],
          shopId: p['shop_id'],
          categoryId: p['category_id'],
          shopName: shopMap?['shop_name'],
          title: p['title'] ?? '',
          description: p['description'],
          brand: p['brand'],
          status: p['status'] ?? 'active',
          priceMin: (p['price_min'] as num?)?.toDouble() ?? 0.0,
          priceMax: (p['price_max'] as num?)?.toDouble() ?? 0.0,
          originalPrice: p['original_price'] != null ? (p['original_price'] as num).toDouble() : null,
          currency: p['currency'] ?? 'VND',
          stockTotal: p['stock_total'] ?? 0,
          soldCount: p['sold_count'] ?? 0,
          ratingAvg: (p['rating_avg'] as num?)?.toDouble() ?? 5.0,
          ratingCount: p['rating_count'] ?? 0,
          coverPath: p['cover_path'],
          media: mediaList,
          variants: variantsList,
        );
      }).toList();

      AdminFallbackStore.isOfflineMode = false;
      emit(state.copyWith(status: AdminStatus.success, products: productsList));
    } catch (_) {
      AdminFallbackStore.isOfflineMode = true;
      final list = event.shopId == null
          ? List<Product>.from(AdminFallbackStore.products)
          : AdminFallbackStore.products.where((p) => p.shopId == event.shopId).toList();
      emit(state.copyWith(status: AdminStatus.success, products: list));
    }
  }

  Future<void> _onCreateProduct(AdminCreateProduct event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      final shopData = await Supabase.instance.client
          .from('shops')
          .select('shop_name')
          .eq('id', event.shopId)
          .single();
      final shopName = shopData['shop_name'] as String? ?? '';
      final brandName = shopName.isNotEmpty ? shopName.split(' ').first : null;

      final productResult = await Supabase.instance.client.from('products').insert({
        'shop_id': event.shopId,
        'category_id': event.categoryId,
        'title': event.title,
        'description': event.description,
        'brand': brandName,
        'price_min': event.price,
        'price_max': event.price,
        'original_price': event.originalPrice,
        'currency': 'VND',
        'stock_total': event.stock,
        'sold_count': 0,
        'rating_avg': 5.0,
        'rating_count': 0,
        'cover_path': event.coverPath ??
            'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400',
        'status': 'active',
      }).select('id').single();

      final productId = productResult['id'] as String;

      if (event.variants.isNotEmpty) {
        final insertVariants = event.variants
            .map((v) => {
                  'product_id': productId,
                  'sku':
                      'SKU-${productId.split('-').first.toUpperCase()}-${(v['name'] as String).toUpperCase().replaceAll(' ', '')}',
                  'variant_name': v['name'],
                  'price': (v['price'] as num).toDouble(),
                  'compare_at_price': event.originalPrice,
                  'original_price': event.originalPrice,
                  'stock_qty': v['stock'] as int,
                  'weight_grams': 200,
                  'status': 'active',
                })
            .toList();
        await Supabase.instance.client.from('product_variants').insert(insertVariants);
      } else {
        await Supabase.instance.client.from('product_variants').insert({
          'product_id': productId,
          'sku': 'SKU-${productId.split('-').first.toUpperCase()}-STANDARD',
          'variant_name': 'Tiêu chuẩn',
          'price': event.price,
          'compare_at_price': event.originalPrice,
          'original_price': event.originalPrice,
          'stock_qty': event.stock,
          'weight_grams': 200,
          'status': 'active',
        });
      }

      final currentShopId =
          AdminSession.loggedInRole == 'shop' ? AdminSession.loggedInShopId : null;
      add(AdminFetchProducts(shopId: currentShopId));
    } catch (_) {
      final shopMatch = AdminFallbackStore.shops.firstWhere(
        (s) => s['id'] == event.shopId,
        orElse: () => {'shop_name': AdminSession.loggedInShopName ?? 'Shareco Brand'},
      );
      final shopName = shopMatch['shop_name'] as String? ?? 'Shareco Brand';
      final newId = 'prod-${DateTime.now().millisecondsSinceEpoch}';
      AdminFallbackStore.products.insert(
        0,
        Product(
          id: newId,
          shopId: event.shopId,
          categoryId: event.categoryId,
          shopName: shopName,
          title: event.title,
          description: event.description,
          brand: shopName.split(' ').first,
          status: 'active',
          priceMin: event.price,
          priceMax: event.price,
          originalPrice: event.originalPrice,
          currency: 'VND',
          stockTotal: event.stock,
          soldCount: 0,
          ratingAvg: 5.0,
          ratingCount: 0,
          coverPath: event.coverPath ??
              'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=400&h=400&fit=crop',
        ),
      );
      final currentShopId =
          AdminSession.loggedInRole == 'shop' ? AdminSession.loggedInShopId : null;
      add(AdminFetchProducts(shopId: currentShopId));
    }
  }

  Future<void> _onUpdateProduct(AdminUpdateProduct event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      final shopData = await Supabase.instance.client
          .from('shops')
          .select('shop_name')
          .eq('id', event.shopId)
          .single();
      final shopName = shopData['shop_name'] as String? ?? '';
      final brandName = shopName.isNotEmpty ? shopName.split(' ').first : null;

      await Supabase.instance.client.from('products').update({
        'shop_id': event.shopId,
        'category_id': event.categoryId,
        'title': event.title,
        'description': event.description,
        'brand': brandName,
        'price_min': event.price,
        'price_max': event.price,
        'original_price': event.originalPrice,
        'stock_total': event.stock,
        if (event.coverPath != null) 'cover_path': event.coverPath,
      }).eq('id', event.productId);

      await Supabase.instance.client
          .from('product_variants')
          .update({
            'price': event.price,
            'compare_at_price': event.originalPrice,
            'original_price': event.originalPrice,
            'stock_qty': event.stock,
          })
          .eq('product_id', event.productId)
          .eq('variant_name', 'Tiêu chuẩn');

      final currentShopId =
          AdminSession.loggedInRole == 'shop' ? AdminSession.loggedInShopId : null;
      add(AdminFetchProducts(shopId: currentShopId));
    } catch (_) {
      final index = AdminFallbackStore.products.indexWhere((p) => p.id == event.productId);
      if (index != -1) {
        final old = AdminFallbackStore.products[index];
        AdminFallbackStore.products[index] = Product(
          id: old.id,
          shopId: event.shopId,
          categoryId: event.categoryId,
          shopName: old.shopName,
          title: event.title,
          description: event.description,
          brand: old.brand,
          status: old.status,
          priceMin: event.price,
          priceMax: event.price,
          originalPrice: event.originalPrice,
          currency: old.currency,
          stockTotal: event.stock,
          soldCount: old.soldCount,
          ratingAvg: old.ratingAvg,
          ratingCount: old.ratingCount,
          coverPath: event.coverPath ?? old.coverPath,
          media: old.media,
          variants: old.variants,
        );
      }
      final currentShopId =
          AdminSession.loggedInRole == 'shop' ? AdminSession.loggedInShopId : null;
      add(AdminFetchProducts(shopId: currentShopId));
    }
  }

  Future<void> _onDeleteProduct(AdminDeleteProduct event, Emitter<AdminState> emit) async {
    add(AdminToggleProductStatus(productId: event.productId, status: 'inactive'));
  }

  Future<void> _onToggleProductStatus(
    AdminToggleProductStatus event,
    Emitter<AdminState> emit,
  ) async {
    try {
      await Supabase.instance.client.from('products').update({
        'status': event.status,
      }).eq('id', event.productId);
    } catch (_) {
      final index = AdminFallbackStore.products.indexWhere((p) => p.id == event.productId);
      if (index != -1) {
        final old = AdminFallbackStore.products[index];
        AdminFallbackStore.products[index] = Product(
          id: old.id,
          shopId: old.shopId,
          categoryId: old.categoryId,
          shopName: old.shopName,
          title: old.title,
          description: old.description,
          brand: old.brand,
          status: event.status,
          priceMin: old.priceMin,
          priceMax: old.priceMax,
          originalPrice: old.originalPrice,
          currency: old.currency,
          stockTotal: old.stockTotal,
          soldCount: old.soldCount,
          ratingAvg: old.ratingAvg,
          ratingCount: old.ratingCount,
          coverPath: old.coverPath,
          media: old.media,
          variants: old.variants,
        );
      }
    }
    final currentShopId =
        AdminSession.loggedInRole == 'shop' ? AdminSession.loggedInShopId : null;
    add(AdminFetchProducts(shopId: currentShopId));
  }

  Future<void> _onFetchOrders(AdminFetchOrders event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      dynamic response;
      try {
        dynamic query = Supabase.instance.client.from('orders').select('''
          *,
          order_items (
            *,
            products (title, cover_path)
          ),
          order_tracking_events (*)
        ''');

        if (event.shopId != null) {
          query = query.eq('shop_id', event.shopId!);
        }

        response = await query.order('placed_at', ascending: false);
      } catch (_) {
        dynamic query = Supabase.instance.client.from('orders').select('''
          *,
          order_items (
            *,
            products (title, cover_path)
          )
        ''');

        if (event.shopId != null) {
          query = query.eq('shop_id', event.shopId!);
        }

        response = await query.order('placed_at', ascending: false);
      }

      final orderList = List<Map<String, dynamic>>.from(response).map((o) {
        final rawItems = List<Map<String, dynamic>>.from(o['order_items'] ?? []);
        final items = rawItems.map((item) {
          final productMap = item['products'] as Map<String, dynamic>?;
          return OrderItem(
            id: item['id']?.toString() ?? '',
            orderId: item['order_id']?.toString() ?? '',
            productId: item['product_id']?.toString() ?? '',
            variantId: item['variant_id']?.toString(),
            shopId: item['shop_id']?.toString() ?? o['shop_id']?.toString() ?? '',
            title: productMap?['title'] ?? item['title'] ?? 'Sản phẩm',
            variantName: item['variant_name']?.toString(),
            imagePath: productMap?['cover_path'] ?? item['image_path'],
            unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0.0,
            qty: (item['qty'] as num?)?.toInt() ?? 1,
            lineTotal: (item['line_total'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();

        final rawTracking = List<Map<String, dynamic>>.from(o['order_tracking_events'] ?? []);
        final trackingEvents = rawTracking.map((t) {
          return OrderTrackingEvent(
            id: t['id']?.toString() ?? '',
            orderId: t['order_id']?.toString() ?? '',
            status: t['status']?.toString() ?? 'pending',
            title: t['title']?.toString() ?? 'Cập nhật vận đơn',
            description: t['description']?.toString(),
            location: t['location']?.toString(),
            carrierName: t['carrier_name']?.toString(),
            lat: (t['lat'] as num?)?.toDouble(),
            lng: (t['lng'] as num?)?.toDouble(),
            actorRole: t['actor_role']?.toString() ?? 'carrier',
            createdAt: t['created_at'] != null ? DateTime.tryParse(t['created_at'].toString()) : null,
          );
        }).toList();

        // Sắp xếp các mốc thời gian mới nhất lên trên
        trackingEvents.sort((a, b) {
          final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return timeB.compareTo(timeA);
        });

        return EcommerceOrder(
          id: o['id']?.toString() ?? '',
          buyerId: o['buyer_id']?.toString() ?? '',
          shopId: o['shop_id']?.toString() ?? '',
          shopName: o['shop_name']?.toString(),
          shopOwnerId: o['shop_owner_id']?.toString(),
          orderCode: o['order_code']?.toString() ?? 'ORD',
          status: o['status']?.toString() ?? 'pending',
          subtotalAmount: (o['subtotal_amount'] as num?)?.toDouble() ?? 0.0,
          discountAmount: (o['discount_amount'] as num?)?.toDouble() ?? 0.0,
          shippingAmount: (o['shipping_amount'] as num?)?.toDouble() ?? 0.0,
          totalAmount: (o['total_amount'] as num?)?.toDouble() ?? 0.0,
          currency: o['currency']?.toString() ?? 'VND',
          addressSnapshot: Map<String, dynamic>.from(o['address_snapshot'] ?? {}),
          note: o['note']?.toString(),
          placedAt: o['placed_at'] != null ? DateTime.tryParse(o['placed_at'].toString()) : null,
          updatedAt: o['updated_at'] != null ? DateTime.tryParse(o['updated_at'].toString()) : null,
          shippingCarrier: o['shipping_carrier']?.toString(),
          shippingService: o['shipping_service']?.toString(),
          trackingCode: o['tracking_code']?.toString(),
          currentLocation: o['current_location']?.toString(),
          pickupLocation: o['pickup_location']?.toString(),
          estimatedDeliveryAt: o['estimated_delivery_at'] != null ? DateTime.tryParse(o['estimated_delivery_at'].toString()) : null,
          confirmedAt: o['confirmed_at'] != null ? DateTime.tryParse(o['confirmed_at'].toString()) : null,
          shippedAt: o['shipped_at'] != null ? DateTime.tryParse(o['shipped_at'].toString()) : null,
          deliveredAt: o['delivered_at'] != null ? DateTime.tryParse(o['delivered_at'].toString()) : null,
          cancelReason: o['cancel_reason']?.toString(),
          items: items,
          trackingEvents: trackingEvents,
        );
      }).toList();

      AdminFallbackStore.isOfflineMode = false;
      emit(state.copyWith(status: AdminStatus.success, orders: orderList));
    } catch (_) {
      AdminFallbackStore.isOfflineMode = true;
      final list = event.shopId == null
          ? List<EcommerceOrder>.from(AdminFallbackStore.orders)
          : AdminFallbackStore.orders.where((o) => o.shopId == event.shopId).toList();
      emit(state.copyWith(status: AdminStatus.success, orders: list));
    }
  }

  Future<void> _onUpdateOrderStatus(AdminUpdateOrderStatus event, Emitter<AdminState> emit) async {
    final now = DateTime.now();
    // 1. Cập nhật lạc quan (Optimistic update) trên state
    final updatedOrders = state.orders.map((o) {
      if (o.id == event.orderId) {
        return EcommerceOrder(
          id: o.id,
          buyerId: o.buyerId,
          shopId: o.shopId,
          shopName: o.shopName,
          shopOwnerId: o.shopOwnerId,
          orderCode: o.orderCode,
          status: event.status,
          subtotalAmount: o.subtotalAmount,
          discountAmount: o.discountAmount,
          shippingAmount: o.shippingAmount,
          totalAmount: o.totalAmount,
          currency: o.currency,
          addressSnapshot: o.addressSnapshot,
          note: o.note,
          placedAt: o.placedAt,
          updatedAt: now,
          confirmedAt: o.confirmedAt,
          shippedAt: o.shippedAt,
          deliveredAt: event.status == 'completed' ? now : o.deliveredAt,
          shippingCarrier: o.shippingCarrier,
          shippingService: o.shippingService,
          trackingCode: o.trackingCode,
          currentLocation: event.status == 'completed' ? 'Đã giao thành công' : o.currentLocation,
          pickupLocation: o.pickupLocation,
          estimatedDeliveryAt: o.estimatedDeliveryAt,
          cancelReason: o.cancelReason,
          items: o.items,
          trackingEvents: o.trackingEvents,
        );
      }
      return o;
    }).toList();
    emit(state.copyWith(orders: updatedOrders));

    // 2. Gửi cập nhật trực tiếp lên database Supabase
    try {
      await Supabase.instance.client.from('orders').update({
        'status': event.status,
        if (event.status == 'completed') 'delivered_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).eq('id', event.orderId);
    } catch (_) {
      final index = AdminFallbackStore.orders.indexWhere((o) => o.id == event.orderId);
      if (index != -1) {
        final old = AdminFallbackStore.orders[index];
        AdminFallbackStore.orders[index] = EcommerceOrder(
          id: old.id,
          buyerId: old.buyerId,
          shopId: old.shopId,
          shopName: old.shopName,
          orderCode: old.orderCode,
          status: event.status,
          subtotalAmount: old.subtotalAmount,
          discountAmount: old.discountAmount,
          shippingAmount: old.shippingAmount,
          totalAmount: old.totalAmount,
          currency: old.currency,
          addressSnapshot: old.addressSnapshot,
          note: old.note,
          placedAt: old.placedAt,
          updatedAt: now,
          items: old.items,
          trackingEvents: old.trackingEvents,
        );
      }
    }
  }

  Future<void> _onConfirmAndPackOrder(
    AdminConfirmAndPackOrder event,
    Emitter<AdminState> emit,
  ) async {
    final now = DateTime.now();
    final newTracking = OrderTrackingEvent(
      id: 'trk-${now.millisecondsSinceEpoch}',
      orderId: event.orderId,
      status: 'packed',
      title: 'Người bán đã đóng gói hàng',
      description: event.note ?? 'Đã hoàn tất đóng gói, chờ bàn giao cho đơn vị vận chuyển',
      actorRole: 'seller',
      createdAt: now,
    );

    // 1. Cập nhật lạc quan (Optimistic update) trên state
    final updatedOrders = state.orders.map((o) {
      if (o.id == event.orderId) {
        final updatedEvents = List<OrderTrackingEvent>.from(o.trackingEvents);
        updatedEvents.insert(0, newTracking);

        return EcommerceOrder(
          id: o.id,
          buyerId: o.buyerId,
          shopId: o.shopId,
          shopName: o.shopName,
          shopOwnerId: o.shopOwnerId,
          orderCode: o.orderCode,
          status: 'packed',
          subtotalAmount: o.subtotalAmount,
          discountAmount: o.discountAmount,
          shippingAmount: o.shippingAmount,
          totalAmount: o.totalAmount,
          currency: o.currency,
          addressSnapshot: o.addressSnapshot,
          note: o.note,
          placedAt: o.placedAt,
          updatedAt: now,
          confirmedAt: now,
          shippedAt: o.shippedAt,
          deliveredAt: o.deliveredAt,
          shippingCarrier: o.shippingCarrier,
          shippingService: o.shippingService,
          trackingCode: o.trackingCode,
          currentLocation: 'Kho người bán (Chờ lấy hàng)',
          pickupLocation: o.pickupLocation,
          estimatedDeliveryAt: o.estimatedDeliveryAt,
          cancelReason: o.cancelReason,
          items: o.items,
          trackingEvents: updatedEvents,
        );
      }
      return o;
    }).toList();
    emit(state.copyWith(orders: updatedOrders));

    // 2. Gửi cập nhật trực tiếp lên database Supabase
    try {
      await Supabase.instance.client.from('orders').update({
        'status': 'packed',
        'confirmed_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).eq('id', event.orderId);

      try {
        await Supabase.instance.client.from('order_tracking_events').insert({
          'order_id': event.orderId,
          'status': 'packed',
          'title': 'Người bán đã đóng gói hàng',
          'description': event.note ?? 'Đã hoàn tất đóng gói, chờ bàn giao cho đơn vị vận chuyển',
          'actor_role': 'seller',
        });
      } catch (_) {}
    } catch (_) {
      final idx = AdminFallbackStore.orders.indexWhere((o) => o.id == event.orderId);
      if (idx != -1) {
        final old = AdminFallbackStore.orders[idx];
        final newEvents = List<OrderTrackingEvent>.from(old.trackingEvents);
        newEvents.insert(0, newTracking);
        AdminFallbackStore.orders[idx] = EcommerceOrder(
          id: old.id,
          buyerId: old.buyerId,
          shopId: old.shopId,
          shopName: old.shopName,
          orderCode: old.orderCode,
          status: 'packed',
          subtotalAmount: old.subtotalAmount,
          discountAmount: old.discountAmount,
          shippingAmount: old.shippingAmount,
          totalAmount: old.totalAmount,
          currency: old.currency,
          addressSnapshot: old.addressSnapshot,
          note: old.note,
          placedAt: old.placedAt,
          updatedAt: now,
          confirmedAt: now,
          shippingCarrier: old.shippingCarrier,
          trackingCode: old.trackingCode,
          currentLocation: 'Kho người bán (Chờ lấy hàng)',
          items: old.items,
          trackingEvents: newEvents,
        );
      }
    }
  }

  Future<void> _onHandoverOrderToCarrier(
    AdminHandoverOrderToCarrier event,
    Emitter<AdminState> emit,
  ) async {
    final now = DateTime.now();
    final code = (event.trackingCode != null && event.trackingCode!.trim().isNotEmpty)
        ? event.trackingCode!.trim()
        : 'SHC${now.millisecondsSinceEpoch.toString().substring(5)}';
    final hub = (event.pickupHub != null && event.pickupHub!.trim().isNotEmpty)
        ? event.pickupHub!.trim()
        : 'Bưu cục nhận hàng';

    final newTracking = OrderTrackingEvent(
      id: 'trk-${now.millisecondsSinceEpoch}',
      orderId: event.orderId,
      status: 'shipping',
      title: 'Đã bàn giao cho ${event.carrier}',
      location: hub,
      carrierName: event.carrier,
      description: 'Kiện hàng đã rời điểm nhận hàng và được chuyển về trung tâm khai thác',
      actorRole: 'carrier',
      createdAt: now,
    );

    // 1. Cập nhật lạc quan (Optimistic update) trên state
    final updatedOrders = state.orders.map((o) {
      if (o.id == event.orderId) {
        final updatedEvents = List<OrderTrackingEvent>.from(o.trackingEvents);
        updatedEvents.insert(0, newTracking);

        return EcommerceOrder(
          id: o.id,
          buyerId: o.buyerId,
          shopId: o.shopId,
          shopName: o.shopName,
          shopOwnerId: o.shopOwnerId,
          orderCode: o.orderCode,
          status: 'shipping',
          subtotalAmount: o.subtotalAmount,
          discountAmount: o.discountAmount,
          shippingAmount: o.shippingAmount,
          totalAmount: o.totalAmount,
          currency: o.currency,
          addressSnapshot: o.addressSnapshot,
          note: o.note,
          placedAt: o.placedAt,
          updatedAt: now,
          confirmedAt: o.confirmedAt,
          shippedAt: now,
          deliveredAt: o.deliveredAt,
          shippingCarrier: event.carrier,
          shippingService: o.shippingService,
          trackingCode: code,
          currentLocation: hub,
          pickupLocation: hub,
          estimatedDeliveryAt: o.estimatedDeliveryAt,
          cancelReason: o.cancelReason,
          items: o.items,
          trackingEvents: updatedEvents,
        );
      }
      return o;
    }).toList();
    emit(state.copyWith(orders: updatedOrders));

    // 2. Gửi cập nhật trực tiếp lên database Supabase
    try {
      await Supabase.instance.client.from('orders').update({
        'status': 'shipping',
        'shipping_carrier': event.carrier,
        'tracking_code': code,
        'current_location': hub,
        'pickup_location': hub,
        'shipped_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).eq('id', event.orderId);

      try {
        await Supabase.instance.client.from('order_tracking_events').insert({
          'order_id': event.orderId,
          'status': 'shipping',
          'title': 'Đã bàn giao cho ${event.carrier}',
          'location': hub,
          'carrier_name': event.carrier,
          'description': 'Kiện hàng đã rời điểm nhận hàng và được chuyển về trung tâm khai thác',
          'actor_role': 'carrier',
        });
      } catch (_) {}
    } catch (_) {
      final idx = AdminFallbackStore.orders.indexWhere((o) => o.id == event.orderId);
      if (idx != -1) {
        final old = AdminFallbackStore.orders[idx];
        final newEvents = List<OrderTrackingEvent>.from(old.trackingEvents);
        newEvents.insert(0, newTracking);
        AdminFallbackStore.orders[idx] = EcommerceOrder(
          id: old.id,
          buyerId: old.buyerId,
          shopId: old.shopId,
          shopName: old.shopName,
          orderCode: old.orderCode,
          status: 'shipping',
          subtotalAmount: old.subtotalAmount,
          discountAmount: old.discountAmount,
          shippingAmount: old.shippingAmount,
          totalAmount: old.totalAmount,
          currency: old.currency,
          addressSnapshot: old.addressSnapshot,
          note: old.note,
          placedAt: old.placedAt,
          updatedAt: now,
          shippedAt: now,
          shippingCarrier: event.carrier,
          trackingCode: code,
          currentLocation: hub,
          items: old.items,
          trackingEvents: newEvents,
        );
      }
    }
  }

  Future<void> _onAdvanceOrderLocation(
    AdminAdvanceOrderLocation event,
    Emitter<AdminState> emit,
  ) async {
    final now = DateTime.now();
    final isCompleted = event.stepStatus == 'completed';
    final nextStatus = isCompleted ? 'completed' : 'shipping';

    final newTracking = OrderTrackingEvent(
      id: 'trk-${now.millisecondsSinceEpoch}',
      orderId: event.orderId,
      status: event.stepStatus,
      title: event.title,
      location: event.location,
      description: event.description,
      carrierName: 'SPX Express',
      actorRole: 'carrier',
      createdAt: now,
    );

    // 1. Cập nhật lạc quan (Optimistic update) NGAY LẬP TỨC trên state
    // Giúp giao diện cập nhật vị trí mới trong 1ms mà không phụ thuộc vào mạng
    final updatedOrders = state.orders.map((o) {
      if (o.id == event.orderId) {
        final updatedEvents = List<OrderTrackingEvent>.from(o.trackingEvents);
        updatedEvents.insert(0, newTracking);

        return EcommerceOrder(
          id: o.id,
          buyerId: o.buyerId,
          shopId: o.shopId,
          shopName: o.shopName,
          shopOwnerId: o.shopOwnerId,
          orderCode: o.orderCode,
          status: nextStatus,
          subtotalAmount: o.subtotalAmount,
          discountAmount: o.discountAmount,
          shippingAmount: o.shippingAmount,
          totalAmount: o.totalAmount,
          currency: o.currency,
          addressSnapshot: o.addressSnapshot,
          note: o.note,
          placedAt: o.placedAt,
          updatedAt: now,
          confirmedAt: o.confirmedAt,
          shippedAt: o.shippedAt,
          deliveredAt: isCompleted ? now : o.deliveredAt,
          shippingCarrier: o.shippingCarrier ?? 'SPX Express',
          shippingService: o.shippingService,
          trackingCode: o.trackingCode,
          currentLocation: event.location, // <-- Vị trí mới được cập nhật ngay lập tức
          pickupLocation: o.pickupLocation,
          estimatedDeliveryAt: o.estimatedDeliveryAt,
          cancelReason: o.cancelReason,
          items: o.items,
          trackingEvents: updatedEvents,
        );
      }
      return o;
    }).toList();
    emit(state.copyWith(orders: updatedOrders));

    // 2. Gửi lệnh cập nhật trực tiếp lên database Supabase
    try {
      await Supabase.instance.client.from('orders').update({
        'status': nextStatus,
        'current_location': event.location,
        if (isCompleted) 'delivered_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).eq('id', event.orderId);

      // Thử thêm tracking event vào bảng order_tracking_events nếu có thể
      try {
        await Supabase.instance.client.from('order_tracking_events').insert({
          'order_id': event.orderId,
          'status': event.stepStatus,
          'title': event.title,
          'location': event.location,
          if (event.description != null && event.description!.trim().isNotEmpty)
            'description': event.description!.trim(),
          'actor_role': 'carrier',
        });
      } catch (_) {}
    } catch (_) {
      final idx = AdminFallbackStore.orders.indexWhere((o) => o.id == event.orderId);
      if (idx != -1) {
        final old = AdminFallbackStore.orders[idx];
        final newEvents = List<OrderTrackingEvent>.from(old.trackingEvents);
        newEvents.insert(0, newTracking);
        AdminFallbackStore.orders[idx] = EcommerceOrder(
          id: old.id,
          buyerId: old.buyerId,
          shopId: old.shopId,
          shopName: old.shopName,
          orderCode: old.orderCode,
          status: nextStatus,
          subtotalAmount: old.subtotalAmount,
          discountAmount: old.discountAmount,
          shippingAmount: old.shippingAmount,
          totalAmount: old.totalAmount,
          currency: old.currency,
          addressSnapshot: old.addressSnapshot,
          note: old.note,
          placedAt: old.placedAt,
          updatedAt: now,
          deliveredAt: isCompleted ? now : old.deliveredAt,
          shippingCarrier: old.shippingCarrier,
          trackingCode: old.trackingCode,
          currentLocation: event.location,
          items: old.items,
          trackingEvents: newEvents,
        );
      }
    }
  }

  Future<void> _onSellerCancelOrder(
    AdminSellerCancelOrder event,
    Emitter<AdminState> emit,
  ) async {
    final now = DateTime.now();
    // 1. Cập nhật lạc quan (Optimistic update) trên state
    final updatedOrders = state.orders.map((o) {
      if (o.id == event.orderId) {
        return EcommerceOrder(
          id: o.id,
          buyerId: o.buyerId,
          shopId: o.shopId,
          shopName: o.shopName,
          shopOwnerId: o.shopOwnerId,
          orderCode: o.orderCode,
          status: 'cancelled',
          subtotalAmount: o.subtotalAmount,
          discountAmount: o.discountAmount,
          shippingAmount: o.shippingAmount,
          totalAmount: o.totalAmount,
          currency: o.currency,
          addressSnapshot: o.addressSnapshot,
          note: o.note,
          placedAt: o.placedAt,
          updatedAt: now,
          cancelReason: event.reason,
          items: o.items,
          trackingEvents: o.trackingEvents,
        );
      }
      return o;
    }).toList();
    emit(state.copyWith(orders: updatedOrders));

    // 2. Gửi cập nhật trực tiếp lên database Supabase
    try {
      await Supabase.instance.client.from('orders').update({
        'status': 'cancelled',
        'cancel_reason': event.reason,
        'updated_at': now.toIso8601String(),
      }).eq('id', event.orderId);
    } catch (_) {
      final idx = AdminFallbackStore.orders.indexWhere((o) => o.id == event.orderId);
      if (idx != -1) {
        final old = AdminFallbackStore.orders[idx];
        AdminFallbackStore.orders[idx] = EcommerceOrder(
          id: old.id,
          buyerId: old.buyerId,
          shopId: old.shopId,
          shopName: old.shopName,
          orderCode: old.orderCode,
          status: 'cancelled',
          subtotalAmount: old.subtotalAmount,
          discountAmount: old.discountAmount,
          shippingAmount: old.shippingAmount,
          totalAmount: old.totalAmount,
          currency: old.currency,
          addressSnapshot: old.addressSnapshot,
          note: old.note,
          placedAt: old.placedAt,
          updatedAt: now,
          cancelReason: event.reason,
          items: old.items,
          trackingEvents: old.trackingEvents,
        );
      }
    }
  }

  Future<void> _onFetchVideos(AdminFetchVideos event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      final response = await Supabase.instance.client
          .from('videos')
          .select('''
            *,
            profiles:author_id (
              id, username, display_name, avatar_url, is_verified
            ),
            video_product_tags (
              sort_order,
              products (
                id, title, price_min, cover_path, brand
              )
            )
          ''')
          .neq('status', 'deleted')
          .order('created_at', ascending: false);

      AdminFallbackStore.isOfflineMode = false;
      emit(state.copyWith(
        status: AdminStatus.success,
        videos: List<Map<String, dynamic>>.from(response),
      ));
    } catch (_) {
      AdminFallbackStore.isOfflineMode = true;
      final activeVideos = AdminFallbackStore.videos
          .where((v) => v['status'] != 'deleted')
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
      emit(state.copyWith(
        status: AdminStatus.success,
        videos: activeVideos,
      ));
    }
  }

  Future<void> _onUpdateVideoStatus(
    AdminUpdateVideoStatus event,
    Emitter<AdminState> emit,
  ) async {
    try {
      final payload = <String, dynamic>{
        'status': event.status,
        if (event.status == 'published') 'published_at': DateTime.now().toIso8601String(),
      };
      await Supabase.instance.client
          .from('videos')
          .update(payload)
          .eq('id', event.videoId);
    } catch (_) {
      final index = AdminFallbackStore.videos.indexWhere((v) => v['id'] == event.videoId);
      if (index != -1) {
        final updated = Map<String, dynamic>.from(AdminFallbackStore.videos[index]);
        updated['status'] = event.status;
        if (event.status == 'published') {
          updated['published_at'] = DateTime.now().toIso8601String();
        }
        AdminFallbackStore.videos[index] = updated;
      }
    }
    add(AdminFetchVideos());
  }

  Future<void> _onApproveAllPendingVideos(
    AdminApproveAllPendingVideos event,
    Emitter<AdminState> emit,
  ) async {
    try {
      await Supabase.instance.client
          .from('videos')
          .update({
            'status': 'published',
            'published_at': DateTime.now().toIso8601String(),
          })
          .eq('status', 'draft');
    } catch (_) {
      for (var i = 0; i < AdminFallbackStore.videos.length; i++) {
        if (AdminFallbackStore.videos[i]['status'] == 'draft') {
          final updated = Map<String, dynamic>.from(AdminFallbackStore.videos[i]);
          updated['status'] = 'published';
          updated['published_at'] = DateTime.now().toIso8601String();
          AdminFallbackStore.videos[i] = updated;
        }
      }
    }
    add(AdminFetchVideos());
  }
}
