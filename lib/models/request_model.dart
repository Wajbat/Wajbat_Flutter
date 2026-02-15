class RequestModel {
  final String requestId;
  final String postId;
  final String recipientId;
  final String donorId;
  final String requestStatus; // 'pending', 'accepted', 'rejected', 'completed', 'cancelled'
  final String? message;
  final DateTime createdAt;
  final DateTime updatedAt;

  RequestModel({
    required this.requestId,
    required this.postId,
    required this.recipientId,
    required this.donorId,
    required this.requestStatus,
    this.message,
    required this.createdAt,
    required this.updatedAt,
  });

  // Getters
  bool get isPending => requestStatus == 'pending';
  bool get isAccepted => requestStatus == 'accepted';
  bool get isRejected => requestStatus == 'rejected';
  bool get isCompleted => requestStatus == 'completed';
  bool get isCancelled => requestStatus == 'cancelled';

  // JSON Serialization
  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      requestId: json['request_id'] as String,
      postId: json['post_id'] as String,
      recipientId: json['recipient_id'] as String,
      donorId: json['donor_id'] as String,
      requestStatus: json['request_status'] as String,
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'post_id': postId,
      'recipient_id': recipientId,
      'donor_id': donorId,
      'request_status': requestStatus,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // CopyWith
  RequestModel copyWith({
    String? requestId,
    String? postId,
    String? recipientId,
    String? donorId,
    String? requestStatus,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RequestModel(
      requestId: requestId ?? this.requestId,
      postId: postId ?? this.postId,
      recipientId: recipientId ?? this.recipientId,
      donorId: donorId ?? this.donorId,
      requestStatus: requestStatus ?? this.requestStatus,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
