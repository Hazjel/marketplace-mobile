import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persistent per-device session id for guest (not-logged-in) product view
/// tracking — this app's equivalent of the web app's `localStorage`-backed
/// `getGuestSessionId()` in `guestSession.js`. Generated once, then reused
/// on every subsequent guest view so repeat views from the same guest count
/// as the same person.
class GuestSessionStore {
  static const String _key = 'blukios_guest_session_id';
  static const _uuid = Uuid();

  /// Returns the persisted guest session id, generating and saving one on
  /// first call.
  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null) return existing;

    final generated = _uuid.v4();
    await prefs.setString(_key, generated);
    return generated;
  }
}
