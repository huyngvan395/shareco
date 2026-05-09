import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_shop_detail_usecase.dart';
import '../../domain/usecases/get_shop_products_usecase.dart';
import 'shop_profile_event.dart';
import 'shop_profile_state.dart';

class ShopProfileBloc extends Bloc<ShopProfileEvent, ShopProfileState> {
  final GetShopDetailUseCase getShopDetailUseCase;
  final GetShopProductsUseCase getShopProductsUseCase;

  ShopProfileBloc({
    required this.getShopDetailUseCase,
    required this.getShopProductsUseCase,
  }) : super(const ShopProfileInitial()) {
    on<ShopProfileRequested>(_onRequested);
    on<ShopProductsFiltered>(_onFiltered);
  }

  Future<void> _onFiltered(
    ShopProductsFiltered event,
    Emitter<ShopProfileState> emit,
  ) async {
    if (state is ShopProfileLoaded) {
      final currentShop = (state as ShopProfileLoaded).shop;
      final productsResult = await getShopProductsUseCase(
        shopId: event.shopId,
        search: event.search,
      );

      productsResult.fold(
        (failure) => emit(ShopProfileFailure(failure.message)),
        (products) => emit(ShopProfileLoaded(shop: currentShop, products: products)),
      );
    }
  }

  Future<void> _onRequested(
    ShopProfileRequested event,
    Emitter<ShopProfileState> emit,
  ) async {
    emit(const ShopProfileLoading());

    final shopResult = await getShopDetailUseCase(event.shopId);
    
    await shopResult.fold(
      (failure) async => emit(ShopProfileFailure(failure.message)),
      (shop) async {
        final productsResult = await getShopProductsUseCase(shopId: event.shopId);
        
        productsResult.fold(
          (failure) => emit(ShopProfileFailure(failure.message)),
          (products) => emit(ShopProfileLoaded(shop: shop, products: products)),
        );
      },
    );
  }
}
