class ApiKey {
  final String id;
  final String keyHash;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int usageCount;
  final int rateLimit;

  ApiKey({
    required this.id,
    required this.keyHash,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.expiresAt,
    required this.usageCount,
    required this.rateLimit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'key_hash': keyHash,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'usage_count': usageCount,
      'rate_limit': rateLimit,
    };
  }

  factory ApiKey.fromMap(Map<String, dynamic> map) {
    return ApiKey(
      id: map['id'],
      keyHash: map['key_hash'],
      name: map['name'],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      expiresAt: map['expires_at'] != null ? DateTime.parse(map['expires_at']) : null,
      usageCount: map['usage_count'],
      rateLimit: map['rate_limit'],
    );
  }

  ApiKey copyWith({
    String? id,
    String? keyHash,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? usageCount,
    int? rateLimit,
  }) {
    return ApiKey(
      id: id ?? this.id,
      keyHash: keyHash ?? this.keyHash,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      usageCount: usageCount ?? this.usageCount,
      rateLimit: rateLimit ?? this.rateLimit,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isValid {
    return isActive && !isExpired;
  }
}