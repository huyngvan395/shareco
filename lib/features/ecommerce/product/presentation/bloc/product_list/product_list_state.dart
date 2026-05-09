import 'package:equatable/equatable.dart';

import '../../../domain/entities/product.dart';

abstract class ProductListState extends Equatable {
  const ProductListState();

  @override
  List<Object?> get props => [];
}

class ProductListInitial extends ProductListState {
  const ProductListInitial();
}

class ProductListLoading extends ProductListState {
  const ProductListLoading();
}

class ProductListLoaded extends ProductListState {
  final List<Product> products;
  final String? search;

  const ProductListLoaded({
    required this.products,
    this.search,
  });

  @override
  List<Object?> get props => [products, search];
}

class ProductListFailure extends ProductListState {
  final String message;

  const ProductListFailure(this.message);

  @override
  List<Object?> get props => [message];
}
