class ApiConfig {
  // Production API — blukios.store, served through nginx.
  static const String baseUrl = 'https://blukios.store/api';
  // static const String baseUrl = 'http://10.0.2.2/api'; // local backend, Android emulator
  // static const String baseUrl = 'http://localhost/api'; // local backend, iOS simulator
  
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Midtrans Snap payment page host — sandbox by default, matches backend .env
  static const bool midtransIsProduction = false;
  static String midtransSnapUrl(String snapToken) {
    const host = midtransIsProduction
        ? 'https://app.midtrans.com'
        : 'https://app.sandbox.midtrans.com';
    return '$host/snap/v2/vtweb/$snapToken';
  }

  // Endpoints
  static const String login = '/login';
  static const String register = '/register';
  static const String me = '/me';
  static const String logout = '/logout';
  static const String products = '/product';
  static const String productsPaginated = '/product/all/paginated';
  static const String productBySlug = '/product/slug';
  static const String categories = '/product-category';
  static const String stores = '/store';
  static const String cart = '/cart';
  static const String cartSync = '/cart/sync';
  static const String cartValidateStock = '/cart/validate-stock';
  static const String wishlist = '/wishlist';
  static const String transactions = '/transaction';
  static const String transactionsPaginated = '/transaction/all/paginated';
  static const String address = '/address';
  static const String shipmentDestination = '/shipment/destination';
  static const String shipmentCalculate = '/shipment/calculate';
  static const String health = '/health';

  static String transactionCheckStatus(String id) => '/transaction/$id/check-status';
}
