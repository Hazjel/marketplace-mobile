import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Recent-search history, persisted locally via [SharedPreferences] —
/// this app's equivalent of the web app's `localStorage`-backed history in
/// `Navbar.vue` (`saveHistory`/`removeHistoryItem`/`clearHistory`). Mirrors
/// that behavior exactly: JSON-encoded list of strings, capped at 5 entries,
/// most-recent-first, case-insensitive de-dup.
class SearchHistoryRepository {
  static const String _key = 'blukios_search_history';
  static const int _maxEntries = 5;

  /// Reads the saved history, most-recent-first. Returns an empty list on
  /// any missing/corrupt data rather than throwing.
  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Adds [query] to the front of history, removing any existing
  /// case-insensitive duplicate first, then caps to [_maxEntries].
  /// Returns the updated list.
  Future<List<String>> save(String query) async {
    if (query.trim().isEmpty) return load();
    final history = await load();
    history.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    history.insert(0, query);
    final capped = history.length > _maxEntries
        ? history.sublist(0, _maxEntries)
        : history;
    await _persist(capped);
    return capped;
  }

  /// Removes the entry at [index]. Returns the updated list.
  Future<List<String>> removeAt(int index) async {
    final history = await load();
    if (index < 0 || index >= history.length) return history;
    history.removeAt(index);
    await _persist(history);
    return history;
  }

  /// Clears all history.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _persist(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(history));
  }
}
