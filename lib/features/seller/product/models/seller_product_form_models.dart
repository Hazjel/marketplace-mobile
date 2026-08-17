import 'package:blukios_marketplace/features/seller/product/models/seller_product_model.dart';

/// A newly-picked-but-not-yet-uploaded product image, held as a local file
/// path until the form is submitted.
class SellerProductNewImage {
  final String localPath;
  final bool isThumbnail;

  const SellerProductNewImage({
    required this.localPath,
    required this.isThumbnail,
  });

  SellerProductNewImage copyWith({bool? isThumbnail}) {
    return SellerProductNewImage(
      localPath: localPath,
      isThumbnail: isThumbnail ?? this.isThumbnail,
    );
  }
}

/// Everything [SellerProductRepository.createProduct] /
/// `updateProduct` need, assembled by the form screen from its controllers.
class SellerProductPayload {
  final String storeId;
  final String categoryId;
  final String name;
  final String description;
  final String condition; // 'new' | 'second'
  final double price;
  final double weight;
  final int stock;

  /// New images to upload. On create this is the full image set (at least
  /// one, exactly one marked thumbnail). On update, the API only accepts
  /// *new* images here — it has no way to replace or re-flag existing ones,
  /// so this may be empty when the seller didn't add any.
  final List<SellerProductNewImage> newImages;

  /// Whether the seller is selling this product as a set of variants
  /// rather than a single price/stock. When true, [variants] must be
  /// non-empty — the API (`ProductRepository::create`/`update`) recomputes
  /// [price] as the minimum variant price and [stock] as the sum of variant
  /// stocks, so the top-level price/stock the seller entered end up
  /// informational only in that case (still required by validation, so we
  /// always send them).
  final bool hasVariants;

  /// Each entry with a non-null [SellerProductVariantModel.id] updates that
  /// existing variant; entries with a null id are created as new variants
  /// (update-only — on create every variant is necessarily new).
  final List<SellerProductVariantModel> variants;

  const SellerProductPayload({
    required this.storeId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.condition,
    required this.price,
    required this.weight,
    required this.stock,
    this.newImages = const [],
    this.hasVariants = false,
    this.variants = const [],
  });
}
