import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../../core/errors/exception.dart';
import '../../../../../core/services/supabase/index.dart';
import '../../domain/entities/shipping_address_draft.dart';
import '../models/shipping_address_model.dart';

abstract class AddressRemoteDataSource {
  Future<List<ShippingAddressModel>> getAddresses();

  Future<ShippingAddressModel> saveAddress(ShippingAddressDraft draft);

  Future<List<ShippingAddressModel>> deleteAddress(String id);

  Future<List<ShippingAddressModel>> setDefaultAddress(String id);
}

class AddressRemoteDataSourceImpl implements AddressRemoteDataSource {
  static const _select =
      'id,user_id,full_name,phone,province,district,ward,address_line,'
      'postal_code,is_default,created_at';

  @override
  Future<List<ShippingAddressModel>> getAddresses() async {
    final userId = _requireUserId();

    try {
      final response = await SupabaseService.from('user_addresses')
          .select(_select)
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .whereType<Map<String, dynamic>>()
          .map(ShippingAddressModel.fromJson)
          .toList(growable: false);
    } on AuthException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ShippingAddressModel> saveAddress(ShippingAddressDraft draft) async {
    final userId = _requireUserId();

    try {
      final shouldDefault = draft.isDefault ||
          (draft.id == null && await _hasNoAddresses(userId));

      if (shouldDefault) {
        await _clearDefault(userId);
      }

      final payload = {
        'full_name': draft.fullName,
        'phone': draft.phone,
        'province': draft.province,
        'district': draft.district,
        'ward': draft.ward,
        'address_line': draft.addressLine,
        'postal_code': draft.postalCode,
        'is_default': shouldDefault,
      };

      final response = draft.id == null
          ? await SupabaseService.from('user_addresses')
              .insert({
                ...payload,
                'user_id': userId,
              })
              .select(_select)
              .single()
          : await SupabaseService.from('user_addresses')
              .update(payload)
              .eq('id', draft.id!)
              .eq('user_id', userId)
              .select(_select)
              .single();

      return ShippingAddressModel.fromJson(response);
    } on AuthException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ShippingAddressModel>> deleteAddress(String id) async {
    final userId = _requireUserId();

    try {
      await SupabaseService.from('user_addresses')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);

      final addresses = await getAddresses();
      if (addresses.isNotEmpty &&
          !addresses.any((address) => address.isDefault)) {
        return setDefaultAddress(addresses.first.id);
      }

      return addresses;
    } on AuthException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ShippingAddressModel>> setDefaultAddress(String id) async {
    final userId = _requireUserId();

    try {
      await _clearDefault(userId);
      await SupabaseService.from('user_addresses')
          .update({'is_default': true})
          .eq('id', id)
          .eq('user_id', userId);
      return getAddresses();
    } on AuthException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  String _requireUserId() {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Please sign in to manage addresses');
    }
    return userId;
  }

  Future<bool> _hasNoAddresses(String userId) async {
    final response = await SupabaseService.from('user_addresses')
        .select('id')
        .eq('user_id', userId)
        .limit(1);
    return (response as List).isEmpty;
  }

  Future<void> _clearDefault(String userId) async {
    await SupabaseService.from('user_addresses')
        .update({'is_default': false})
        .eq('user_id', userId);
  }
}
