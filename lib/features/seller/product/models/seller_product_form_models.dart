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
///
/// Variants are out of scope for this pass (see feature notes) — the API
/// accepts them, but this app doesn't build the payload for them yet.
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
  });
}
