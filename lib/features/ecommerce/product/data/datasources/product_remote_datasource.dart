import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/errors/exception.dart';
import '../../../../../core/services/supabase/index.dart';
import '../models/product_model.dart';

abstract class ProductRemoteDataSource {
  Future<List<ProductModel>> getProducts({
    int limit = 20,
    String? search,
    String? categoryId,
    String? brand,
  });

  Future<ProductModel> getProductDetail(String productId);

  Future<List<ProductModel>> getFlashSaleProducts();
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  static const _productSelect =
      'id,shop_id,category_id,title,description,brand,status,price_min,price_max,'
      'currency,stock_total,sold_count,rating_avg,rating_count,cover_path,'
      'created_at,updated_at,shops(shop_name),'
      'product_media(id,product_id,media_type,storage_path,sort_order,created_at),'
      'product_variants(id,product_id,sku,variant_name,price,compare_at_price,'
      'stock_qty,weight_grams,status,created_at)';

  @override
  Future<List<ProductModel>> getProducts({
    int limit = 20,
    String? search,
    String? categoryId,
    String? brand,
  }) async {
    try {
      dynamic query = SupabaseService.from('products')
          .select(_productSelect)
          .eq('status', 'active');

      final keyword = search?.trim();
      if (keyword != null && keyword.isNotEmpty) {
        query = query.ilike('title', '%$keyword%');
      }

      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }

      if (brand != null && brand.isNotEmpty) {
        query = query.eq('brand', brand);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ProductModel> getProductDetail(String productId) async {
    try {
      final response = await SupabaseService.from('products')
          .select(_productSelect)
          .eq('id', productId)
          .single();

      return ProductModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const NotFoundException('Product not found');
      }
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ProductModel>> getFlashSaleProducts() async {
    try {
      final response = await SupabaseService.from('products')
          .select(_productSelect)
          .eq('status', 'active');

      final allProducts = (response as List)
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList();

      final flashSaleProducts = allProducts.where((product) {
        return product.variants.any((variant) =>
            variant.status == 'active' &&
            variant.compareAtPrice != null &&
            variant.compareAtPrice! > variant.price);
      }).toList();

      return flashSaleProducts;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
