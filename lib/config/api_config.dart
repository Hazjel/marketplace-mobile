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

  // Search & filters (3a)
  static const String productSearch = '/product/all/paginated';

  // Category browse (3b)
  static const String categoriesPaginated = '/product-category/all/paginated';
  static String categoryBySlug(String slug) => '/product-category/slug/$slug';

  // Wishlist (3c) — POST is a toggle, returns { status: "added" | "removed" }
  // GET /wishlist and POST /wishlist already defined above

  // Store detail & follow (3d)
  static String storeByUsername(String username) => '/store/username/$username';
  // Categories and reviews are keyed by username, not store id.
  static String storeCategories(String username) =>
      '/store/username/$username/categories';
  static String storeReviews(String username) =>
      '/store/username/$username/reviews';
  static String storeFollow(String id) => '/store/$id/follow';
  static String storeUnfollow(String id) => '/store/$id/unfollow';
  static String storeFollowStatus(String id) => '/store/$id/follow-status';
  static const String storeLocations = '/store/locations';

  // Product reviews (3e)
  static const String productReviews = '/product-review';
  static const String productReviewsPaginated = '/product-review/all/paginated';

  // Profile & settings (3f)
  static const String profile = '/profile';
  static const String profileSettings = '/profile/settings';

  // Buyer dashboard (3g)
  static const String buyerDashboard = '/buyer/dashboard/summary';

  // Chat (3h)
  static const String chatContacts = '/chat/contacts';
  static String chatMessages(String userId) => '/chat/$userId';
  static const String chatSend = '/chat/send';
  static String chatUser(String id) => '/chat/user/$id';
  // Note the /api prefix — Broadcast::routes() is registered inside
  // routes/api.php, not at the framework default /broadcasting/auth.
  static const String broadcastAuth = '/broadcasting/auth';
  static String get broadcastAuthUrl => '$baseUrl$broadcastAuth';

  // ── Reverb (WebSocket) ────────────────────────────────────────────
  // Values mirror docker-compose.yml. nginx proxies /app to the reverb
  // container, so the client connects on the normal web port rather
  // than 8080 directly.
  static const String reverbAppKey = 'reverbkey';
  static String get reverbHost => Uri.parse(baseUrl).host;
  static bool get reverbUseTLS => Uri.parse(baseUrl).scheme == 'https';
  static int get reverbPort => reverbUseTLS ? 443 : 80;
}
