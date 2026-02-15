class FoodPostModel {
  final String postId;
  final String donorId;
  final String itemName;
  final String quantity;
  final DateTime expirationDate;
  final String location;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final List<String> ingredients;
  final String postStatus; // 'available', 'reserved', 'expired', 'completed'
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodPostModel({
    required this.postId,
    required this.donorId,
    required this.itemName,
    required this.quantity,
    required this.expirationDate,
    required this.location,
    this.latitude,
    this.longitude,
    this.imageUrl,
    required this.ingredients,
    required this.postStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  // Getters
  bool get isExpired => expirationDate.isBefore(DateTime.now());
  bool get isAvailable => postStatus == 'available' && !isExpired;

  // JSON Serialization
  factory FoodPostModel.fromJson(Map<String, dynamic> json) {
    return FoodPostModel(
      postId: json['post_id'] as String,
      donorId: json['donor_id'] as String,
      itemName: json['item_name'] as String,
      quantity: json['quantity'] as String,
      expirationDate: DateTime.parse(json['expiration_date']),
      location: json['location'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      postStatus: json['post_status'] as String,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'donor_id': donorId,
      'item_name': itemName,
      'quantity': quantity,
      'expiration_date': expirationDate.toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'image_url': imageUrl,
      'ingredients': ingredients,
      'post_status': postStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // CopyWith
  FoodPostModel copyWith({
    String? postId,
    String? donorId,
    String? itemName,
    String? quantity,
    DateTime? expirationDate,
    String? location,
    double? latitude,
    double? longitude,
    String? imageUrl,
    List<String>? ingredients,
    String? postStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodPostModel(
      postId: postId ?? this.postId,
      donorId: donorId ?? this.donorId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      expirationDate: expirationDate ?? this.expirationDate,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredients: ingredients ?? this.ingredients,
      postStatus: postStatus ?? this.postStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
