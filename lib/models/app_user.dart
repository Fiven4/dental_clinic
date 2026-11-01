import 'json_utils.dart';
import 'role.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final Role role;
  final DateTime? created;
  final String? password;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.created,
    this.password,
  });

  bool get isDeleted => false;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: stringOf(json['id']),
    email: stringOf(json['email']),
    name: stringOf(json['name']),
    role: Role.fromString(json['role'] as String?),
    created: dateOf(json['created']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'role': role.value,
    'created': created == null ? '' : pbDate(created!),
  };

  Map<String, dynamic> toBody() => {
    'email': email,
    'name': name,
    'role': role.value,
    'emailVisibility': true,
    if (password != null && password!.isNotEmpty) ...{
      'password': password,
      'passwordConfirm': password,
    },
  };
}
