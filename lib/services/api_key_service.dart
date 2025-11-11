import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../models/api_key.dart';
import 'database_service.dart';

class ApiKeyService {
  static final ApiKeyService _instance = ApiKeyService._internal();
  factory ApiKeyService() => _instance;
  ApiKeyService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final _uuid = const Uuid();

  /// Generate a new API key
  String generateApiKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Hash an API key for secure storage
  String hashApiKey(String apiKey) {
    final bytes = utf8.encode(apiKey);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Create a new API key
  Future<Map<String, dynamic>> createApiKey({
    required String name,
    int? rateLimit,
    DateTime? expiresAt,
  }) async {
    final apiKey = generateApiKey();
    final keyHash = hashApiKey(apiKey);
    
    final apiKeyModel = ApiKey(
      id: _uuid.v4(),
      keyHash: keyHash,
      name: name,
      isActive: true,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      usageCount: 0,
      rateLimit: rateLimit ?? 100,
    );

    await _databaseService.insertApiKey(apiKeyModel);

    return {
      'id': apiKeyModel.id,
      'api_key': apiKey, // Only return the plain key once during creation
      'name': name,
      'created_at': apiKeyModel.createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'rate_limit': rateLimit,
    };
  }

  /// Validate an API key
  Future<ApiKey?> validateApiKey(String apiKey) async {
    final keyHash = hashApiKey(apiKey);
    final apiKeyModel = await _databaseService.getApiKeyByHash(keyHash);
    
    if (apiKeyModel == null) {
      return null;
    }

    // Check if key is active and not expired
    if (!apiKeyModel.isValid) {
      return null;
    }

    return apiKeyModel;
  }

  /// Increment usage count for an API key
  Future<void> incrementUsage(String apiKeyId) async {
    final apiKey = await _databaseService.getApiKey(apiKeyId);
    if (apiKey != null) {
      final updatedKey = apiKey.copyWith(
        usageCount: apiKey.usageCount + 1,
      );
      await _databaseService.updateApiKey(updatedKey);
    }
  }

  /// Get all API keys (without the actual key values)
  Future<List<ApiKey>> getAllApiKeys() async {
    return await _databaseService.getAllApiKeys();
  }

  /// Get API key by ID
  Future<ApiKey?> getApiKey(String id) async {
    return await _databaseService.getApiKey(id);
  }

  /// Update API key
  Future<bool> updateApiKey({
    required String id,
    String? name,
    bool? isActive,
    DateTime? expiresAt,
    int? rateLimit,
  }) async {
    final existingKey = await _databaseService.getApiKey(id);
    if (existingKey == null) return false;

    final updatedKey = existingKey.copyWith(
      name: name ?? existingKey.name,
      isActive: isActive ?? existingKey.isActive,
      expiresAt: expiresAt ?? existingKey.expiresAt,
      rateLimit: rateLimit ?? existingKey.rateLimit,
    );

    await _databaseService.updateApiKey(updatedKey);
    return true;
  }

  /// Delete API key
  Future<bool> deleteApiKey(String id) async {
    return await _databaseService.deleteApiKey(id);
  }

  /// Check rate limit for an API key
  Future<bool> checkRateLimit(String apiKeyId, {Duration window = const Duration(minutes: 1)}) async {
    final apiKey = await _databaseService.getApiKey(apiKeyId);
    if (apiKey == null || apiKey.rateLimit <= 0) {
      return true; // No rate limit set
    }

    // Get request count in the time window
    final requestCount = await _databaseService.getRequestCountInWindow(
      apiKeyId,
      DateTime.now().subtract(window),
    );

    return requestCount < apiKey.rateLimit;
  }

  /// Get API key statistics
  Future<Map<String, dynamic>> getApiKeyStats(String apiKeyId) async {
    final apiKey = await _databaseService.getApiKey(apiKeyId);
    if (apiKey == null) {
      return {};
    }

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final todayRequests = await _databaseService.getRequestCountInWindow(
      apiKeyId,
      startOfDay,
    );

    final lastHourRequests = await _databaseService.getRequestCountInWindow(
      apiKeyId,
      DateTime.now().subtract(const Duration(hours: 1)),
    );

    return {
      'total_usage': apiKey.usageCount,
      'today_requests': todayRequests,
      'last_hour_requests': lastHourRequests,
      'is_active': apiKey.isActive,
      'is_expired': apiKey.isExpired,
      'rate_limit': apiKey.rateLimit,
    };
  }

  /// Regenerate API key (creates new key, invalidates old one)
  Future<Map<String, dynamic>?> regenerateApiKey(String id) async {
    final existingKey = await _databaseService.getApiKey(id);
    if (existingKey == null) return null;

    // Generate new key
    final newApiKey = generateApiKey();
    final newKeyHash = hashApiKey(newApiKey);

    // Update existing record with new hash
    final updatedKey = existingKey.copyWith(
      keyHash: newKeyHash,
      usageCount: 0, // Reset usage count
    );

    await _databaseService.updateApiKey(updatedKey);

    return {
      'id': updatedKey.id,
      'api_key': newApiKey, // Return new key once
      'name': updatedKey.name,
      'created_at': updatedKey.createdAt.toIso8601String(),
      'expires_at': updatedKey.expiresAt?.toIso8601String(),
      'rate_limit': updatedKey.rateLimit,
    };
  }

  /// Clean up expired API keys
  Future<int> cleanupExpiredKeys() async {
    final expiredKeys = await _databaseService.getExpiredApiKeys();
    int deletedCount = 0;

    for (final key in expiredKeys) {
        if (await _databaseService.deleteApiKey(key.id)) {
        deletedCount++;
      }
    }

    return deletedCount;
  }

  /// Get default API key (for initial setup)
  Future<String?> getDefaultApiKey() async {
    final defaultKey = await _databaseService.getApiKeyByHash(
      hashApiKey('sms-gateway-default-key-2024'),
    );
    
    if (defaultKey != null && defaultKey.isValid) {
      return 'sms-gateway-default-key-2024';
    }
    
    return null;
  }
}