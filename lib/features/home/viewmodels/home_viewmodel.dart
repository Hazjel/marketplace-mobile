import 'package:flutter/foundation.dart';
import 'package:blukios_marketplace/features/home/data/product_repository.dart';
import 'package:blukios_marketplace/features/home/models/product_model.dart';
import 'package:blukios_marketplace/features/home/models/category_model.dart';

class HomeViewModel extends ChangeNotifier {
  final ProductRepository _productRepository;

  HomeViewModel(this._productRepository);

  List<ProductModel> products = [];
  List<CategoryModel> categories = [];
  bool isLoading = true;
  String? error;
  String searchQuery = '';

  Future<void> loadData() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _productRepository.getProducts(search: searchQuery.isEmpty ? null : searchQuery),
        _productRepository.getCategories(),
      ]);

      products = results[0] as List<ProductModel>;
      categories = results[1] as List<CategoryModel>;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    searchQuery = query;
    await loadData();
  }
}
