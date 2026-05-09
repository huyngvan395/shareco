import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../domain/entities/product_variant.dart';
import 'product_price.dart';

class ProductVariantSelector extends StatelessWidget {
  final List<ProductVariant> variants;
  final ProductVariant? selectedVariant;
  final String currency;
  final ValueChanged<ProductVariant> onChanged;

  const ProductVariantSelector({
    super.key,
    required this.variants,
    required this.selectedVariant,
    required this.currency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.xl,
        0,
        AppSizes.xl,
        AppSizes.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: AppSizes.xl),
          const Text(
            'Variants',
            style: TextStyle(
              color: Colors.black87,
              fontSize: AppSizes.fontXl,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: variants.map((variant) {
              final selected = selectedVariant?.id == variant.id;
              final disabled = !variant.isActive || !variant.isInStock;
              return _VariantTile(
                variant: variant,
                currency: currency,
                selected: selected,
                disabled: disabled,
                onTap: disabled ? null : () => onChanged(variant),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  final ProductVariant variant;
  final String currency;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _VariantTile({
    required this.variant,
    required this.currency,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 132,
        constraints: const BoxConstraints(minWidth: 112),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        decoration: BoxDecoration(
          color: disabled
              ? const Color(0xFFF5F5F5)
              : selected
                  ? AppColors.primary.withOpacity(0.08)
                  : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E5E5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    variant.variantName ?? variant.sku ?? 'Default',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: disabled ? Colors.black38 : Colors.black87,
                      fontSize: AppSizes.fontMd,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AppSizes.xs),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              disabled
                  ? 'Out of stock'
                  : ProductPrice.formatAmount(variant.price, currency),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: disabled ? Colors.black38 : AppColors.primary,
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
