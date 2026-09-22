/// The logged-in account, as returned by the backend's `/auth` endpoints.
///
/// Mirrors `User.toPublicJSON()` on the backend
/// (backend/src/models/User.js) -- never carries a password or hash.
class AppUser {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? country;
  final bool isGuest;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.country,
    required this.isGuest,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      country: json['country'] as String?,
      isGuest: json['isGuest'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'country': country,
      'isGuest': isGuest,
    };
  }
}
