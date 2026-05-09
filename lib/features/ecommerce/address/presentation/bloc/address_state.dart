import 'package:equatable/equatable.dart';

import '../../domain/entities/shipping_address.dart';

abstract class AddressState extends Equatable {
  const AddressState();

  @override
  List<Object?> get props => [];
}

class AddressInitial extends AddressState {
  const AddressInitial();
}

class AddressLoading extends AddressState {
  const AddressLoading();
}

class AddressLoaded extends AddressState {
  final List<ShippingAddress> addresses;
  final bool isUpdating;

  const AddressLoaded({
    required this.addresses,
    this.isUpdating = false,
  });

  @override
  List<Object?> get props => [addresses, isUpdating];
}

class AddressSaving extends AddressState {
  const AddressSaving();
}

class AddressSaveSuccess extends AddressState {
  final ShippingAddress address;

  const AddressSaveSuccess(this.address);

  @override
  List<Object?> get props => [address];
}

class AddressFailure extends AddressState {
  final String message;

  const AddressFailure(this.message);

  @override
  List<Object?> get props => [message];
}
