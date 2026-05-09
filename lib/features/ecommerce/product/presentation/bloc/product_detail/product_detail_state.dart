import 'package:equatable/equatable.dart';

import '../../../domain/entities/product.dart';

abstract class ProductDetailState extends Equatable {
  const ProductDetailState();

  @override
  List<Object?> get props => [];
}

class ProductDetailInitial extends ProductDetailState {
  const ProductDetailInitial();
}

class ProductDetailLoading extends ProductDetailState {
  const ProductDetailLoading();
}

class ProductDetailLoaded extends ProductDetailState {
  final Product product;

  const ProductDetailLoaded(this.product);

  @override
  List<Object?> get props => [product];
}

class ProductDetailFailure extends ProductDetailState {
  final String message;

  const ProductDetailFailure(this.message);

  @override
  List<Object?> get props => [message];
}
