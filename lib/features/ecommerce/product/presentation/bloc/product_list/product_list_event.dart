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

  const ProductListRequested({
    this.limit = 20,
    this.search,
    this.categoryId,
    this.brand,
  });

  @override
  List<Object?> get props => [limit, search, categoryId, brand];
}
