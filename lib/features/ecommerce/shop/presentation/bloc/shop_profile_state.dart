import 'package:equatable/equatable.dart';

import '../../../product/domain/entities/product.dart';
import '../../domain/entities/shop.dart';

abstract class ShopProfileState extends Equatable {
  const ShopProfileState();

  @override
  List<Object?> get props => [];
}

class ShopProfileInitial extends ShopProfileState {
  const ShopProfileInitial();
}

class ShopProfileLoading extends ShopProfileState {
  const ShopProfileLoading();
}

class ShopProfileLoaded extends ShopProfileState {
  final Shop shop;
  final List<Product> products;

  const ShopProfileLoaded({
    required this.shop,
    required this.products,
  });

  @override
  List<Object?> get props => [shop, products];
}

class ShopProfileFailure extends ShopProfileState {
  final String message;

  const ShopProfileFailure(this.message);

  @override
  List<Object?> get props => [message];
}
