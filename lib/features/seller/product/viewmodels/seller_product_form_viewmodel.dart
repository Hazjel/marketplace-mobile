import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/category/models/category_detail_model.dart';
import 'package:blukios_marketplace/features/category/viewmodels/category_viewmodel.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_form_models.dart';
import 'package:blukios_marketplace/features/seller/product/models/seller_product_model.dart';

class SellerProductFormData {
  final StoreMini? store;
  final List<CategoryDetailModel> categories;
  final bool isLoadingCategories;
  final bool isSaving;
  final String? errorMessage;

  /// Whether the seller is selling this product as a set of variants
  /// rather than a single price/stock.
  final bool hasVariants;
  final List<SellerProductVariantModel> variants;

  const SellerProductFormData({
    this.store,
    this.categories = const [],
    this.isLoadingCategories = true,
    this.isSaving = false,
    this.errorMessage,
    this.hasVariants = false,
    this.variants = const [],
  });

  SellerProductFormData copyWith({
    StoreMini? store,
    List<CategoryDetailModel>? categories,
    bool? isLoadingCategories,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    bool? hasVariants,
    List<SellerProductVariantModel>? variants,
  }) {
    return SellerProductFormData(
      store: store ?? this.store,
      categories: categories ?? this.categories,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasVariants: hasVariants ?? this.hasVariants,
      variants: variants ?? this.variants,
    );
  }
}

/// Backs the create/edit product form: resolves the seller's own store,
/// loads sub-categories for the category picker (only leaf categories —
/// the API rejects a top-level one), submits the create/update calls, and
/// owns the variant list the form's variants section edits.
class SellerProductFormNotifier extends AutoDisposeNotifier<SellerProductFormData> {
  bool _disposed = false;

  @override
  SellerProductFormData build() {
    ref.onDispose(() => _disposed = true);
    return const SellerProductFormData();
  }

  Future<void> init() async {
    state = state.copyWith(isLoadingCategories: true, clearError: true);

    try {
      final store = await ref.read(sellerProductRepositoryProvider).getMyStore();
      if (_disposed) return;
      // is_parent: false → only sub-categories, which is what
      // ProductStoreRequest/ProductUpdateRequest require.
      final categoriesPage = await ref
          .read(categoryRepositoryProvider)
          .getCategoriesPaginated(page: 1, isParent: false, rowPerPage: 100);
      if (_disposed) return;

      state = state.copyWith(
        store: store,
        categories: categoriesPage.items,
        isLoadingCategories: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        isLoadingCategories: false,
        errorMessage: 'Gagal memuat data toko/kategori: $e',
      );
    }
  }

  /// Seeds the variants section from an existing product when editing.
  /// Call once, before the user has had a chance to touch the toggle.
  void loadExistingVariants(SellerProductModel? existing) {
    if (existing == null || existing.variants.isEmpty) return;
    state = state.copyWith(hasVariants: true, variants: existing.variants);
  }

  void setHasVariants(bool value) {
    state = state.copyWith(
      hasVariants: value,
      // Dropping the toggle clears the rows too — flipping it back on
      // starts from a clean slate rather than resurrecting stale rows.
      variants: value ? state.variants : const [],
    );
  }

  void addVariant() {
    state = state.copyWith(
      variants: [
        ...state.variants,
        const SellerProductVariantModel(name: '', price: 0, stock: 0),
      ],
    );
  }

  void updateVariant(int index, SellerProductVariantModel variant) {
    if (index < 0 || index >= state.variants.length) return;
    final updated = [...state.variants];
    updated[index] = variant;
    state = state.copyWith(variants: updated);
  }

  void removeVariant(int index) {
    if (index < 0 || index >= state.variants.length) return;
    final updated = [...state.variants]..removeAt(index);
    state = state.copyWith(variants: updated);
  }

  /// Returns the created product on success, or null with
  /// [SellerProductFormData.errorMessage] populated on failure.
  Future<SellerProductModel?> submitCreate(SellerProductPayload payload) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final product =
          await ref.read(sellerProductRepositoryProvider).createProduct(payload);
      if (_disposed) return null;
      state = state.copyWith(isSaving: false);
      return product;
    } catch (e) {
      if (_disposed) return null;
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<SellerProductModel?> submitUpdate(
    String id,
    SellerProductPayload payload,
  ) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final product = await ref
          .read(sellerProductRepositoryProvider)
          .updateProduct(id, payload);
      if (_disposed) return null;
      state = state.copyWith(isSaving: false);
      return product;
    } catch (e) {
      if (_disposed) return null;
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return null;
    }
  }
}

final sellerProductFormProvider = AutoDisposeNotifierProvider<
    SellerProductFormNotifier, SellerProductFormData>(
  SellerProductFormNotifier.new,
);
