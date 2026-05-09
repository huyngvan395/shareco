import 'package:equatable/equatable.dart';

abstract class ProductDetailEvent extends Equatable {
  const ProductDetailEvent();

  @override
  List<Object?> get props => [];
}

class ProductDetailRequested extends ProductDetailEvent {
  final String productId;

  const ProductDetailRequested(this.productId);

  @override
  List<Object?> get props => [productId];
}
