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

  const SellerProductFormData({
    this.store,
    this.categories = const [],
    this.isLoadingCategories = true,
    this.isSaving = false,
    this.errorMessage,
  });

  SellerProductFormData copyWith({
    StoreMini? store,
    List<CategoryDetailModel>? categories,
    bool? isLoadingCategories,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SellerProductFormData(
      store: store ?? this.store,
      categories: categories ?? this.categories,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Backs the create/edit product form: resolves the seller's own store,
/// loads sub-categories for the category picker (only leaf categories —
/// the API rejects a top-level one), and submits the create/update calls.
class SellerProductFormNotifier extends AutoDisposeNotifier<SellerProductFormData> {
  @override
  SellerProductFormData build() => const SellerProductFormData();

  Future<void> init() async {
    state = state.copyWith(isLoadingCategories: true, clearError: true);

    try {
      final store = await ref.read(sellerProductRepositoryProvider).getMyStore();
      // is_parent: false → only sub-categories, which is what
      // ProductStoreRequest/ProductUpdateRequest require.
      final categoriesPage = await ref
          .read(categoryRepositoryProvider)
          .getCategoriesPaginated(page: 1, isParent: false, rowPerPage: 100);

      state = state.copyWith(
        store: store,
        categories: categoriesPage.items,
        isLoadingCategories: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingCategories: false,
        errorMessage: 'Gagal memuat data toko/kategori: $e',
      );
    }
  }

  /// Returns the created product on success, or null with
  /// [SellerProductFormData.errorMessage] populated on failure.
  Future<SellerProductModel?> submitCreate(SellerProductPayload payload) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final product =
          await ref.read(sellerProductRepositoryProvider).createProduct(payload);
      state = state.copyWith(isSaving: false);
      return product;
    } catch (e) {
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
      state = state.copyWith(isSaving: false);
      return product;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return null;
    }
  }
}

final sellerProductFormProvider = AutoDisposeNotifierProvider<
    SellerProductFormNotifier, SellerProductFormData>(
  SellerProductFormNotifier.new,
);
