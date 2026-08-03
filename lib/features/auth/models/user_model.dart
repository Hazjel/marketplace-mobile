class UserModel {
  final String id;
  final String name;
  final String email;
  final String? username;
  final String role;
  final String? profilePicture;
  final String? token;
  final List<String>? permissions;
  final BuyerMini? buyer;

  /// Settings maps returned by `GET /me` and `PUT /profile/settings`.
  /// The API key-filters these against its own defaults, so unknown keys
  /// are dropped server-side and partial updates preserve the rest.
  final Map<String, bool> notificationPrefs;
  final Map<String, bool> privacyPrefs;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    required this.role,
    this.profilePicture,
    this.token,
    this.permissions,
    this.buyer,
    this.notificationPrefs = const {},
    this.privacyPrefs = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      name: json['name'],
      email: json['email'],
      username: json['username'],
      role: json['role'],
      profilePicture: json['profile_picture'],
      token: json['token'],
      permissions: json['permissions'] != null
          ? List<String>.from(json['permissions'])
          : null,
      buyer: json['buyer'] != null ? BuyerMini.fromJson(json['buyer']) : null,
      notificationPrefs: _boolMap(json['notification_prefs']),
      privacyPrefs: _boolMap(json['privacy_prefs']),
    );
  }

  /// Coerces a prefs object to `Map<String, bool>`. The API may send
  /// booleans as 0/1 or "true"/"false" depending on how they round-trip
  /// through the database.
  static Map<String, bool> _boolMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((key, value) {
      final bool parsed;
      if (value is bool) {
        parsed = value;
      } else if (value is num) {
        parsed = value != 0;
      } else if (value is String) {
        parsed = value == '1' || value.toLowerCase() == 'true';
      } else {
        parsed = false;
      }
      return MapEntry(key.toString(), parsed);
    });
  }

  UserModel copyWith({
    String? name,
    String? profilePicture,
    Map<String, bool>? notificationPrefs,
    Map<String, bool>? privacyPrefs,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      username: username,
      role: role,
      profilePicture: profilePicture ?? this.profilePicture,
      token: token,
      permissions: permissions,
      buyer: buyer,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      privacyPrefs: privacyPrefs ?? this.privacyPrefs,
    );
  }
}

class BuyerMini {
  final String id;

  BuyerMini({required this.id});

  factory BuyerMini.fromJson(Map<String, dynamic> json) {
    return BuyerMini(id: json['id'].toString());
  }
}
