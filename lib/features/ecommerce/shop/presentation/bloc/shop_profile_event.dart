import 'package:equatable/equatable.dart';

abstract class ShopProfileEvent extends Equatable {
  const ShopProfileEvent();

  @override
  List<Object?> get props => [];
}

class ShopProfileRequested extends ShopProfileEvent {
  final String shopId;

  const ShopProfileRequested(this.shopId);

  @override
  List<Object?> get props => [shopId];
}

class ShopProductsFiltered extends ShopProfileEvent {
  final String shopId;
  final String search;

  const ShopProductsFiltered(this.shopId, this.search);

  @override
  List<Object?> get props => [shopId, search];
}
