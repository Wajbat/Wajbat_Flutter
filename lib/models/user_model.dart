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
  final List<String> allergies; // Optional: List of allergens for recipients
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
    this.allergies = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Getters
  bool get isDonor => active_role == 'donor';
  bool get isRecipient => active_role == 'recipient';
  bool hasRole(String role) => roles.contains(role);
  bool get canSwitchRoles => roles.length > 1;

  /// Checks if the user has an allergy to a specific ingredient.
  /// Performs a case-insensitive partial match.
  bool hasAllergy(String ingredient) {
    if (allergies.isEmpty) return false;
    final lowerIngredient = ingredient.toLowerCase();
    return allergies.any((allergy) => 
      lowerIngredient.contains(allergy.toLowerCase()) || 
      allergy.toLowerCase().contains(lowerIngredient)
    );
  }

  /// Returns a list of ingredients from the provided list that match the user's allergies.
  List<String> getAllergenIngredients(List<String> ingredients) {
    if (allergies.isEmpty) return [];
    return ingredients.where((ingredient) => hasAllergy(ingredient)).toList();
  }

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
      allergies: List<String>.from(json['allergies'] ?? []),
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
      'allergies': allergies,
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
    List<String>? allergies,
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
      allergies: allergies ?? this.allergies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
