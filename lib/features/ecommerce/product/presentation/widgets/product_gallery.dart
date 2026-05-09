import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/storage_image.dart';
import '../../domain/entities/product.dart';

class ProductGallery extends StatelessWidget {
  final Product product;
  final double height;

  const ProductGallery({
    super.key,
    required this.product,
    this.height = 360,
  });

  @override
  Widget build(BuildContext context) {
    final images = <String>[
      if (product.coverPath != null && product.coverPath!.isNotEmpty)
        product.coverPath!,
      ...product.media
          .where((item) => item.isImage && item.storagePath.isNotEmpty)
          .map((item) => item.storagePath),
    ];

    if (images.isEmpty) {
      return SizedBox(
        height: height,
        child: const _GalleryPlaceholder(),
      );
    }

    return SizedBox(
      height: height,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (_, index) => _GalleryImage(path: images[index]),
      ),
    );
  }
}

class _GalleryImage extends StatelessWidget {
  final String path;

  const _GalleryImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final imageUrl = StorageImage.publicUrl(path);
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _GalleryPlaceholder(),
      );
    }

    return const _GalleryPlaceholder();
  }
}

class _GalleryPlaceholder extends StatelessWidget {
  const _GalleryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F3F3),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textMuted,
          size: 52,
        ),
      ),
    );
  }
}
