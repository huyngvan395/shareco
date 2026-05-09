import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shareco/features/ecommerce/product/domain/entities/product.dart';
import 'package:shareco/features/ecommerce/product/domain/entities/product_media.dart';
import 'package:shareco/features/ecommerce/product/domain/entities/product_variant.dart';
import 'package:shareco/features/ecommerce/order/domain/entities/ecommerce_order.dart';
import 'package:shareco/features/ecommerce/order/domain/entities/order_item.dart';

import 'admin_event.dart';
import 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc() : super(const AdminState()) {
    on<AdminFetchShops>(_onFetchShops);
    on<AdminCreateShop>(_onCreateShop);
    on<AdminUpdateShop>(_onUpdateShop);
    on<AdminFetchProducts>(_onFetchProducts);
    on<AdminCreateProduct>(_onCreateProduct);
    on<AdminUpdateProduct>(_onUpdateProduct);
    on<AdminDeleteProduct>(_onDeleteProduct);
    on<AdminFetchOrders>(_onFetchOrders);
    on<AdminUpdateOrderStatus>(_onUpdateOrderStatus);
  }

  Future<void> _onFetchShops(AdminFetchShops event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      final response = await Supabase.instance.client
          .from('shops')
          .select('*')
          .order('shop_name', ascending: true);

      emit(state.copyWith(
        status: AdminStatus.success,
        shops: List<Map<String, dynamic>>.from(response),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.failure,
        errorMessage: 'Lỗi tải danh sách nhãn hàng: $e',
      ));
    }
  }

  Future<void> _onCreateShop(AdminCreateShop event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      final profiles = await Supabase.instance.client.from('profiles').select('id').limit(1);
      if (profiles.isEmpty) {
        throw Exception('Vui lòng tạo ít nhất một tài khoản người dùng trước khi tạo shop.');
      }
      final ownerId = profiles.first['id'];
      final slug = event.shopName.toLowerCase().replaceAll(RegExp(r'\s+'), '-');

      await Supabase.instance.client.from('shops').insert({
        'owner_id': ownerId,
        'shop_name': event.shopName,
        'shop_slug': slug,
        'description': event.description,
        'logo_path': event.logoPath ?? 'https://images.unsplash.com/photo-1541963463532-d68292c34b19?w=150&h=150&fit=crop',
        'cover_path': event.coverPath ?? 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?w=800&h=400&fit=crop',
        'rating_avg': 5.0,
        'rating_count': 0,
        'follower_count': 0,
        'status': 'active',
      });

      add(AdminFetchShops());
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.failure,
        errorMessage: 'Lỗi tạo nhãn hàng: $e',
      ));
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
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.failure,
        errorMessage: 'Lỗi cập nhật nhãn hàng: $e',
      ));
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

      emit(state.copyWith(status: AdminStatus.success, products: productsList));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.failure,
        errorMessage: 'Lỗi tải sản phẩm: $e',
      ));
    }
  }

  Future<void> _onCreateProduct(AdminCreateProduct event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      final productResult = await Supabase.instance.client.from('products').insert({
        'shop_id': event.shopId,
        'category_id': event.categoryId,
        'title': event.title,
        'description': event.description,
        'price_min': event.price,
        'price_max': event.price,
        'original_price': event.originalPrice,
        'currency': 'VND',
        'stock_total': event.stock,
        'sold_count': 0,
        'rating_avg': 5.0,
        'rating_count': 0,
        'cover_path': event.coverPath ?? 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400',
        'status': 'active',
      }).select('id').single();

      final productId = productResult['id'] as String;

      if (event.variants.isNotEmpty) {
        final insertVariants = event.variants.map((v) => {
          'product_id': productId,
          'variant_name': v['name'],
          'price': (v['price'] as num).toDouble(),
          'stock_qty': v['stock'] as int,
          'status': 'active',
        }).toList();
        await Supabase.instance.client.from('product_variants').insert(insertVariants);
      } else {
        await Supabase.instance.client.from('product_variants').insert({
          'product_id': productId,
          'variant_name': 'Tiêu chuẩn',
          'price': event.price,
          'stock_qty': event.stock,
          'status': 'active',
        });
      }

      add(AdminFetchProducts());
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.failure,
        errorMessage: 'Lỗi tạo sản phẩm: $e',
      ));
    }
  }

  Future<void> _onUpdateProduct(AdminUpdateProduct event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      await Supabase.instance.client.from('products').update({
        'title': event.title,
        'description': event.description,
        'price_min': event.price,
        'price_max': event.price,
        'original_price': event.originalPrice,
        'stock_total': event.stock,
        if (event.coverPath != null) 'cover_path': event.coverPath,
      }).eq('id', event.productId);

      await Supabase.instance.client.from('product_variants').update({
        'price': event.price,
        'stock_qty': event.stock,
      }).eq('product_id', event.productId).eq('variant_name', 'Tiêu chuẩn');

      add(AdminFetchProducts());
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.failure,
        errorMessage: 'Lỗi cập nhật sản phẩm: $e',
      ));
    }
  }

  Future<void> _onDeleteProduct(AdminDeleteProduct event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      await Supabase.instance.client.from('products').update({
        'status': 'inactive',
      }).eq('id', event.productId);

      add(AdminFetchProducts());
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.failure,
        errorMessage: 'Lỗi xóa sản phẩm: $e',
      ));
    }
  }

  Future<void> _onFetchOrders(AdminFetchOrders event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      final response = await Supabase.instance.client.from('orders').select('''
        *,
        order_items (
          *,
          products (title, cover_path)
        )
      ''').order('placed_at', ascending: false);

      final orderList = List<Map<String, dynamic>>.from(response).map((o) {
        final rawItems = List<Map<String, dynamic>>.from(o['order_items'] ?? []);
        final items = rawItems.map((item) {
          final productMap = item['products'] as Map<String, dynamic>?;
          return OrderItem(
            id: item['id'],
            orderId: item['order_id'],
            productId: item['product_id'],
            variantId: item['variant_id'],
            shopId: item['shop_id'] ?? o['shop_id'] ?? '',
            title: productMap?['title'] ?? item['title'] ?? 'Sản phẩm',
            variantName: item['variant_name'],
            imagePath: productMap?['cover_path'] ?? item['image_path'],
            unitPrice: (item['unit_price'] as num).toDouble(),
            qty: item['qty'] ?? 1,
            lineTotal: (item['line_total'] as num).toDouble(),
          );
        }).toList();

        return EcommerceOrder(
          id: o['id'],
          buyerId: o['buyer_id'] ?? '',
          shopId: o['shop_id'] ?? '',
          shopName: o['shop_name'],
          orderCode: o['order_code'] ?? 'ORD',
          status: o['status'] ?? 'pending',
          subtotalAmount: (o['subtotal_amount'] as num?)?.toDouble() ?? 0.0,
          discountAmount: (o['discount_amount'] as num?)?.toDouble() ?? 0.0,
          shippingAmount: (o['shipping_amount'] as num?)?.toDouble() ?? 0.0,
          totalAmount: (o['total_amount'] as num?)?.toDouble() ?? 0.0,
          currency: o['currency'] ?? 'VND',
          addressSnapshot: Map<String, dynamic>.from(o['address_snapshot'] ?? {}),
          note: o['note'],
          placedAt: o['placed_at'] != null ? DateTime.parse(o['placed_at']) : null,
          updatedAt: o['updated_at'] != null ? DateTime.parse(o['updated_at']) : null,
          items: items,
        );
      }).toList();

      emit(state.copyWith(status: AdminStatus.success, orders: orderList));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.failure,
        errorMessage: 'Lỗi tải đơn hàng: $e',
      ));
    }
  }

  Future<void> _onUpdateOrderStatus(AdminUpdateOrderStatus event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      await Supabase.instance.client.from('orders').update({
        'status': event.status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', event.orderId);

      add(AdminFetchOrders());
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.failure,
        errorMessage: 'Lỗi cập nhật đơn hàng: $e',
      ));
    }
  }
}
