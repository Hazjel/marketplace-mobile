import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/auth/models/user_model.dart';

void main() {
  group('UserModel.isEmailVerified', () {
    test('true when email_verified_at is present', () {
      final user = UserModel.fromJson({
        'id': 1,
        'name': 'Budi',
        'email': 'budi@test.com',
        'role': 'buyer',
        'email_verified_at': '2026-01-01T00:00:00Z',
      });

      expect(user.isEmailVerified, isTrue);
    });

    test('false when email_verified_at is absent', () {
      final user = UserModel.fromJson({
        'id': 1,
        'name': 'Budi',
        'email': 'budi@test.com',
        'role': 'buyer',
      });

      expect(user.isEmailVerified, isFalse);
    });
  });
}
