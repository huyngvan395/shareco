import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/get_products_usecase.dart';
import 'product_list_event.dart';
import 'product_list_state.dart';

class ProductListBloc extends Bloc<ProductListEvent, ProductListState> {
  final GetProductsUseCase getProductsUseCase;

  ProductListBloc({required this.getProductsUseCase})
      : super(const ProductListInitial()) {
    on<ProductListRequested>(_onRequested);
  }

  Future<void> _onRequested(
    ProductListRequested event,
    Emitter<ProductListState> emit,
  ) async {
    emit(const ProductListLoading());
    final result = await getProductsUseCase(
      limit: event.limit,
      search: event.search,
      categoryId: event.categoryId,
      brand: event.brand,
    );
    result.fold(
      (failure) => emit(ProductListFailure(failure.message)),
      (products) => emit(
        ProductListLoaded(
          products: products,
          search: event.search,
        ),
      ),
    );
  }
}
