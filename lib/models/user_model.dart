class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final List<String> roles;
  final String active_role;
  final String languagePreference;
  final int donationPoints;
  final String? profileImageUrl;
  final String? organizationName;
  final String? recipientType; // 'individual' or 'charity'
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    required this.roles,
    required this.active_role,
    this.languagePreference = 'en',
    this.donationPoints = 0,
    this.profileImageUrl,
    this.organizationName,
    this.recipientType,
    required this.createdAt,
    required this.updatedAt,
  });

  // Getters
  bool get isDonor => active_role == 'donor';
  bool get isRecipient => active_role == 'recipient';
  bool hasRole(String role) => roles.contains(role);
  bool get canSwitchRoles => roles.length > 1;

  // JSON Serialization
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phoneNumber: json['phone_number'] as String?,
      roles: List<String>.from(json['roles'] ?? []),
      active_role: json['active_role'] as String,
      languagePreference: json['language_preference'] ?? 'en',
      donationPoints: json['donation_points'] ?? 0,
      profileImageUrl: json['profile_image_url'] as String?,
      organizationName: json['organization_name'] as String?,
      recipientType: json['recipient_type'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'roles': roles,
      'active_role': active_role,
      'language_preference': languagePreference,
      'donation_points': donationPoints,
      'profile_image_url': profileImageUrl,
      'organization_name': organizationName,
      'recipient_type': recipientType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // CopyWith
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    List<String>? roles,
    String? active_role,
    String? languagePreference,
    int? donationPoints,
    String? profileImageUrl,
    String? organizationName,
    String? recipientType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      roles: roles ?? this.roles,
      active_role: active_role ?? this.active_role,
      languagePreference: languagePreference ?? this.languagePreference,
      donationPoints: donationPoints ?? this.donationPoints,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      organizationName: organizationName ?? this.organizationName,
      recipientType: recipientType ?? this.recipientType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
