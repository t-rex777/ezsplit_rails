class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.dob,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final DateTime? dob;

  String get initials {
    final f = firstName.isEmpty ? '' : firstName[0];
    final l = lastName.isEmpty ? '' : lastName[0];
    return (f + l).toUpperCase();
  }

  /// Reads a JSON:API user resource: {"id": "2", "type": "user", "attributes": {...}}.
  factory User.fromJson(Map<String, dynamic> resource) {
    final a = resource['attributes'] as Map<String, dynamic>;
    final dob = a['date_of_birth'] as String?;
    return User(
      id: (a['id'] as num?)?.toInt() ?? int.parse(resource['id'] as String),
      firstName: a['first_name'] as String? ?? '',
      lastName: a['last_name'] as String? ?? '',
      email: a['email_address'] as String? ?? '',
      phone: a['phone'] as String?,
      dob: dob == null ? null : DateTime.parse(dob),
    );
  }
}
