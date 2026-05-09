import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../di/injector.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/cart_event.dart';
import '../bloc/cart_state.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/cart_summary_bar.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final CartBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<CartBloc>()..add(const CartRequested());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          final cart = state is CartLoaded ? state.cart : null;
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              title: Text(
                cart == null ? 'Giỏ hàng' : 'Giỏ hàng (${cart.totalItems})',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            body: _buildBody(state),
            bottomNavigationBar: cart == null
                ? null
                : CartSummaryBar(
                    cart: cart,
                    onCheckout: () => context.push('/checkout'),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBody(CartState state) {
    if (state is CartInitial || state is CartLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is CartFailure) {
      return _StateMessage(
        icon: Icons.error_outline_rounded,
        title: state.message,
        actionLabel: 'Thử lại',
        onAction: () => _bloc.add(const CartRequested()),
      );
    }

    if (state is! CartLoaded) return const SizedBox.shrink();

    if (state.cart.items.isEmpty) {
      return _StateMessage(
        icon: Icons.shopping_cart_outlined,
        title: 'Giỏ hàng trống',
        actionLabel: 'Làm mới',
        onAction: () => _bloc.add(const CartRequested()),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _bloc.add(const CartRequested()),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: AppSizes.md, bottom: 96),
        itemCount: state.cart.items.length,
        itemBuilder: (_, index) {
          final item = state.cart.items[index];
          return CartItemTile(
            item: item,
            isUpdating: state.isUpdating,
            onQtyChanged: (qty) => _bloc.add(
              CartItemQtyChanged(itemId: item.id, qty: qty),
            ),
            onRemove: () => _bloc.add(CartItemRemoved(item.id)),
          );
        },
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
                fontWeight: FontWeight.w700,
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
