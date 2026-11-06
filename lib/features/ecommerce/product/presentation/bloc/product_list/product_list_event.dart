import 'package:equatable/equatable.dart';

abstract class ProductListEvent extends Equatable {
  const ProductListEvent();

  @override
  List<Object?> get props => [];
}

class ProductListRequested extends ProductListEvent {
  final int limit;
  final String? search;
  final String? categoryId;
  final String? brand;
  final String? shopId;

  const ProductListRequested({
    this.limit = 20,
    this.search,
    this.categoryId,
    this.brand,
    this.shopId,
  });

  @override
  List<Object?> get props => [limit, search, categoryId, brand, shopId];
}
