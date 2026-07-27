import 'dart:math';

/// Generates a unique key per mutating request attempt (checkout, etc.) to
/// prevent double-charge on double-taps/retries/unstable network -- the
/// backend's IdempotencyMiddleware only requires a unique string per
/// attempt, not a strict UUID format, so this avoids adding a uuid package
/// dependency just for this.
class IdempotencyKey {
  static final _random = Random.secure();

  static String generate() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();
    return '$timestamp-$randomPart';
  }
}
