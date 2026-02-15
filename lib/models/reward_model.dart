class RewardModel {
  final String rewardId;
  final String userId;
  final int points;
  final List<String> badges;
  final int totalDonations;
  final DateTime createdAt;
  final DateTime updatedAt;

  RewardModel({
    required this.rewardId,
    required this.userId,
    required this.points,
    required this.badges,
    required this.totalDonations,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper getters
  String get badgeLevel {
    if (points < 50) return 'Bronze';
    if (points < 150) return 'Silver';
    if (points < 300) return 'Gold';
    return 'Platinum';
  }

  // JSON Serialization
  factory RewardModel.fromJson(Map<String, dynamic> json) {
    return RewardModel(
      rewardId: json['reward_id'] as String,
      userId: json['user_id'] as String,
      points: json['points'] ?? 0,
      badges: List<String>.from(json['badges'] ?? []),
      totalDonations: json['total_donations'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reward_id': rewardId,
      'user_id': userId,
      'points': points,
      'badges': badges,
      'total_donations': totalDonations,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // CopyWith
  RewardModel copyWith({
    String? rewardId,
    String? userId,
    int? points,
    List<String>? badges,
    int? totalDonations,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RewardModel(
      rewardId: rewardId ?? this.rewardId,
      userId: userId ?? this.userId,
      points: points ?? this.points,
      badges: badges ?? this.badges,
      totalDonations: totalDonations ?? this.totalDonations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
