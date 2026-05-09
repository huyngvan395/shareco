import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../di/injector.dart';
import '../../domain/entities/shipping_address.dart';
import '../bloc/address_bloc.dart';
import '../bloc/address_event.dart';
import '../bloc/address_state.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  late final AddressBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<AddressBloc>()..add(const AddressListRequested());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _reload() {
    _bloc.add(const AddressListRequested());
  }

  Future<void> _openCreate() async {
    await context.push('/addresses/new');
    if (mounted) _reload();
  }

  Future<void> _openEdit(ShippingAddress address) async {
    await context.push('/addresses/${address.id}/edit', extra: address);
    if (mounted) _reload();
  }

  Future<void> _confirmDelete(ShippingAddress address) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa địa chỉ?'),
          content: Text(
            'Địa chỉ của ${address.fullName} sẽ bị xóa khỏi danh sách.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Không'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Xóa',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      _bloc.add(AddressDeleted(address.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          title: const Text(
            'Địa chỉ nhận hàng',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_location_alt_outlined),
            ),
          ],
        ),
        body: BlocConsumer<AddressBloc, AddressState>(
          listener: (context, state) {
            if (state is AddressFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          builder: (context, state) {
            if (state is AddressInitial || state is AddressLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is AddressFailure) {
              return _StateMessage(
                icon: Icons.error_outline_rounded,
                title: state.message,
                actionLabel: 'Thử lại',
                onAction: _reload,
              );
            }

            if (state is! AddressLoaded) return const SizedBox.shrink();

            if (state.addresses.isEmpty) {
              return _StateMessage(
                icon: Icons.location_on_outlined,
                title: 'Bạn chưa có địa chỉ nhận hàng',
                actionLabel: 'Thêm địa chỉ',
                onAction: _openCreate,
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.md,
                  AppSizes.md,
                  AppSizes.md,
                  AppSizes.xl,
                ),
                itemCount: state.addresses.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: AppSizes.md),
                itemBuilder: (_, index) {
                  if (index == state.addresses.length) {
                    return OutlinedButton.icon(
                      onPressed: _openCreate,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Thêm địa chỉ mới'),
                    );
                  }

                  final address = state.addresses[index];
                  return _AddressCard(
                    address: address,
                    isUpdating: state.isUpdating,
                    onEdit: () => _openEdit(address),
                    onDelete: () => _confirmDelete(address),
                    onSetDefault: address.isDefault
                        ? null
                        : () => _bloc.add(AddressDefaultChanged(address.id)),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final ShippingAddress address;
  final bool isUpdating;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;

  const _AddressCard({
    required this.address,
    required this.isUpdating,
    required this.onEdit,
    required this.onDelete,
    this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${address.fullName} · ${address.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (address.isDefault)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Mặc định',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            [
              address.addressLine,
              address.locationText,
            ].where((value) => value.trim().isNotEmpty).join(', '),
            style: const TextStyle(color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Sửa'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Xóa'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
              const Spacer(),
              TextButton(
                onPressed: isUpdating ? null : onSetDefault,
                child: const Text('Đặt mặc định'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textMuted, size: 48),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: AppSizes.fontXl,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
