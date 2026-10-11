import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';

/// Where a tapped push should land, or null to leave navigation alone.
/// Waits for the session to be restored first (a cold-start tap arrives
/// before it is), and drops the deep link if the user is not signed in, or
/// signs out while the transaction lookup is running — the router then
/// sends them to login.
Future<String?> pushTarget(
  Map<String, dynamic> data, {
  required Future<AuthData> Function() settledAuth,
  required AuthData Function() currentAuth,
  required Future<String?> Function(String id) transactionStoreId,
  required Future<String?> Function() myStoreId,
}) async {
  final auth = await settledAuth();
  if (auth.state != AuthState.authenticated) return null;

  final senderId = data['sender_id']?.toString();
  if (data['type'] == 'chat' && senderId != null) {
    return AppRoutes.chatThreadPath(senderId);
  }

  final route = await transactionPushRoute(
    data['transaction_id']?.toString(),
    isSeller: auth.currentUser?.role == 'store',
    transactionStoreId: transactionStoreId,
    myStoreId: myStoreId,
  );
  return currentAuth().state == AuthState.authenticated ? route : null;
}

/// Where tapping a `type: transaction` push lands. Buyers and sellers both
/// get these (sellers for complaints): a seller goes to the order's detail
/// when it belongs to their store; everyone else, and any failed lookup,
/// goes to the buyer transaction list (it has no per-order detail screen).
/// That includes a `store`-role user whose store is missing or could not be
/// fetched — intentional, the buyer list is always a safe landing.
Future<String> transactionPushRoute(
  String? transactionId, {
  required bool isSeller,
  required Future<String?> Function(String id) transactionStoreId,
  required Future<String?> Function() myStoreId,
}) async {
  if (transactionId == null || !isSeller) return AppRoutes.transactions;
  try {
    final (orderStore, ownStore) =
        await (transactionStoreId(transactionId), myStoreId()).wait;
    if (orderStore != null && orderStore == ownStore) {
      return AppRoutes.sellerOrderDetailPath(transactionId);
    }
  } catch (_) {
    // Fall through to the buyer list.
  }
  return AppRoutes.transactions;
}
