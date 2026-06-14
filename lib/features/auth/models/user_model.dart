class UserModel {
  final String id;
  final String name;
  final String email;
  final String? username;
  final String role;
  final String? profilePicture;
  final String? token;
  final List<String>? permissions;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    required this.role,
    this.profilePicture,
    this.token,
    this.permissions,
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
    );
  }
}
