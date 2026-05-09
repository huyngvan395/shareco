import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/delete_address_usecase.dart';
import '../../domain/usecases/get_addresses_usecase.dart';
import '../../domain/usecases/save_address_usecase.dart';
import '../../domain/usecases/set_default_address_usecase.dart';
import 'address_event.dart';
import 'address_state.dart';

class AddressBloc extends Bloc<AddressEvent, AddressState> {
  final GetAddressesUseCase getAddressesUseCase;
  final SaveAddressUseCase saveAddressUseCase;
  final DeleteAddressUseCase deleteAddressUseCase;
  final SetDefaultAddressUseCase setDefaultAddressUseCase;

  AddressBloc({
    required this.getAddressesUseCase,
    required this.saveAddressUseCase,
    required this.deleteAddressUseCase,
    required this.setDefaultAddressUseCase,
  }) : super(const AddressInitial()) {
    on<AddressListRequested>(_onListRequested);
    on<AddressSaved>(_onSaved);
    on<AddressDeleted>(_onDeleted);
    on<AddressDefaultChanged>(_onDefaultChanged);
  }

  Future<void> _onListRequested(
    AddressListRequested event,
    Emitter<AddressState> emit,
  ) async {
    emit(const AddressLoading());
    final result = await getAddressesUseCase();
    result.fold(
      (failure) => emit(AddressFailure(failure.message)),
      (addresses) => emit(AddressLoaded(addresses: addresses)),
    );
  }

  Future<void> _onSaved(
    AddressSaved event,
    Emitter<AddressState> emit,
  ) async {
    emit(const AddressSaving());
    final result = await saveAddressUseCase(event.draft);
    result.fold(
      (failure) => emit(AddressFailure(failure.message)),
      (address) => emit(AddressSaveSuccess(address)),
    );
  }

  Future<void> _onDeleted(
    AddressDeleted event,
    Emitter<AddressState> emit,
  ) async {
    final current = state;
    if (current is AddressLoaded) {
      emit(AddressLoaded(addresses: current.addresses, isUpdating: true));
    }

    final result = await deleteAddressUseCase(event.id);
    result.fold(
      (failure) => emit(AddressFailure(failure.message)),
      (addresses) => emit(AddressLoaded(addresses: addresses)),
    );
  }

  Future<void> _onDefaultChanged(
    AddressDefaultChanged event,
    Emitter<AddressState> emit,
  ) async {
    final current = state;
    if (current is AddressLoaded) {
      emit(AddressLoaded(addresses: current.addresses, isUpdating: true));
    }

    final result = await setDefaultAddressUseCase(event.id);
    result.fold(
      (failure) => emit(AddressFailure(failure.message)),
      (addresses) => emit(AddressLoaded(addresses: addresses)),
    );
  }
}
