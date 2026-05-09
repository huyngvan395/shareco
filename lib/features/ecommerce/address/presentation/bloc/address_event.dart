import 'package:equatable/equatable.dart';

import '../../domain/entities/shipping_address_draft.dart';

abstract class AddressEvent extends Equatable {
  const AddressEvent();

  @override
  List<Object?> get props => [];
}

class AddressListRequested extends AddressEvent {
  const AddressListRequested();
}

class AddressSaved extends AddressEvent {
  final ShippingAddressDraft draft;

  const AddressSaved(this.draft);

  @override
  List<Object?> get props => [draft];
}

class AddressDeleted extends AddressEvent {
  final String id;

  const AddressDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

class AddressDefaultChanged extends AddressEvent {
  final String id;

  const AddressDefaultChanged(this.id);

  @override
  List<Object?> get props => [id];
}
