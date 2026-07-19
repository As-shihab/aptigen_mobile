class UserModel {
  final int id;
  final String? name;
  final String? email;
  final String? avatar;
  final String? phone;

  const UserModel({
    required this.id,
    this.name,
    this.email,
    this.avatar,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        name: json['name'] as String?,
        email: json['email'] as String?,
        avatar: json['avatar'] as String?,
        phone: json['phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar': avatar,
        'phone': phone,
      };

  String get initials {
    final n = name ?? email ?? 'U';
    final parts = n.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return n.substring(0, n.length >= 2 ? 2 : 1).toUpperCase();
  }
}
