import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/get_product_detail_usecase.dart';
import 'product_detail_event.dart';
import 'product_detail_state.dart';

class ProductDetailBloc extends Bloc<ProductDetailEvent, ProductDetailState> {
  final GetProductDetailUseCase getProductDetailUseCase;

  ProductDetailBloc({required this.getProductDetailUseCase})
      : super(const ProductDetailInitial()) {
    on<ProductDetailRequested>(_onRequested);
  }

  Future<void> _onRequested(
    ProductDetailRequested event,
    Emitter<ProductDetailState> emit,
  ) async {
    emit(const ProductDetailLoading());
    final result = await getProductDetailUseCase(event.productId);
    result.fold(
      (failure) => emit(ProductDetailFailure(failure.message)),
      (product) => emit(ProductDetailLoaded(product)),
    );
  }
}
