import 'dart:async';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/sms_message.dart';
import '../models/api_key.dart';
import '../models/message_log.dart';
import '../models/received_sms.dart';
import 'logging_service.dart';
import '../models/request_log.dart';
import '../models/device_config.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;


  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'sms_gateway.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create SMS messages table
    await db.execute('''
      CREATE TABLE sms_messages (
        id TEXT PRIMARY KEY,
        recipient TEXT NOT NULL,
        message_content TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'delivered', 'failed')),
        sim_slot INTEGER DEFAULT 0 CHECK (sim_slot IN (0, 1)),
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        sent_at DATETIME,
        delivered_at DATETIME,
        error_message TEXT
      )
    ''');

    // Create indexes for SMS messages
    await db.execute('CREATE INDEX idx_sms_messages_status ON sms_messages(status)');
    await db.execute('CREATE INDEX idx_sms_messages_created_at ON sms_messages(created_at DESC)');
    await db.execute('CREATE INDEX idx_sms_messages_recipient ON sms_messages(recipient)');

    // Create message logs table
    await db.execute('''
      CREATE TABLE message_logs (
        id TEXT PRIMARY KEY,
        message_id TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        details TEXT,
        FOREIGN KEY (message_id) REFERENCES sms_messages(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for message logs
    await db.execute('CREATE INDEX idx_message_logs_message_id ON message_logs(message_id)');
    await db.execute('CREATE INDEX idx_message_logs_timestamp ON message_logs(timestamp DESC)');

    // Create API keys table
    await db.execute('''
      CREATE TABLE api_keys (
        id TEXT PRIMARY KEY,
        key_hash TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        is_active BOOLEAN DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        expires_at DATETIME,
        usage_count INTEGER DEFAULT 0,
        rate_limit INTEGER DEFAULT 100
      )
    ''');

    // Create indexes for API keys
    await db.execute('CREATE INDEX idx_api_keys_hash ON api_keys(key_hash)');
    await db.execute('CREATE INDEX idx_api_keys_active ON api_keys(is_active)');

    // Create request logs table
    await db.execute('''
      CREATE TABLE request_logs (
        id TEXT PRIMARY KEY,
        api_key_id TEXT,
        endpoint TEXT NOT NULL,
        client_ip TEXT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        response_code INTEGER,
        FOREIGN KEY (api_key_id) REFERENCES api_keys(id)
      )
    ''');

    // Create indexes for request logs
    await db.execute('CREATE INDEX idx_request_logs_timestamp ON request_logs(timestamp DESC)');
    await db.execute('CREATE INDEX idx_request_logs_api_key ON request_logs(api_key_id)');
    await db.execute('CREATE INDEX idx_request_logs_endpoint ON request_logs(endpoint)');

    // Create device configuration table
    await db.execute('''
      CREATE TABLE device_config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Insert default configuration
    for (String key in AppConfig.defaultValues.keys) {
      await db.insert('device_config', {
        'key': key,
        'value': AppConfig.defaultValues[key],
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    // Create default API key with a fixed, known key for testing
    String defaultKey = 'sms-gateway-default-key-2024';
    String keyHash = sha256.convert(utf8.encode(defaultKey)).toString();
    
    await db.insert('api_keys', {
      'id': 'default-key-001',
      'key_hash': keyHash,
      'name': 'Default API Key',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
      'expires_at': null,
      'usage_count': 0,
      'rate_limit': 100,
    });
    
    // Log the default API key for debugging
    LoggingService.info('Default API key created: $defaultKey', tag: 'DatabaseService');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add received_sms table for version 2
      await db.execute('''
        CREATE TABLE received_sms (
          id TEXT PRIMARY KEY,
          sender TEXT NOT NULL,
          message_content TEXT NOT NULL,
          sim_slot INTEGER DEFAULT 0 CHECK (sim_slot IN (0, 1)),
          received_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          is_read BOOLEAN DEFAULT 0,
          is_multipart BOOLEAN DEFAULT 0,
          multipart_count INTEGER DEFAULT 1,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Create indexes for received SMS
      await db.execute('CREATE INDEX idx_received_sms_sender ON received_sms(sender)');
      await db.execute('CREATE INDEX idx_received_sms_received_at ON received_sms(received_at DESC)');
      await db.execute('CREATE INDEX idx_received_sms_is_read ON received_sms(is_read)');
      await db.execute('CREATE INDEX idx_received_sms_sim_slot ON received_sms(sim_slot)');
    }
  }

  // SMS Messages CRUD operations
  Future<String> insertSmsMessage(SmsMessage message) async {
    final db = await database;
    await db.insert('sms_messages', message.toMap());
    return message.id;
  }

  // Alias methods for compatibility
  Future<String> insertMessage(SmsMessage message) async {
    return await insertSmsMessage(message);
  }

  Future<SmsMessage?> getMessageById(String id) async {
    return await getSmsMessage(id);
  }

  Future<void> updateMessage(SmsMessage message) async {
    return await updateSmsMessage(message);
  }

  Future<SmsMessage?> getSmsMessage(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_messages',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SmsMessage.fromMap(maps.first);
    }
    return null;
  }

  Future<List<SmsMessage>> getAllSmsMessages({int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_messages',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) => SmsMessage.fromMap(maps[i]));
  }

  Future<List<SmsMessage>> getSmsMessagesByStatus(String status) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_messages',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => SmsMessage.fromMap(maps[i]));
  }

  Future<void> updateSmsMessage(SmsMessage message) async {
    final db = await database;
    await db.update(
      'sms_messages',
      message.toMap(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  Future<void> deleteSmsMessage(String id) async {
    final db = await database;
    await db.delete(
      'sms_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllSmsMessages() async {
    final db = await database;
    await db.delete('sms_messages');
  }

  // Message Logs CRUD operations
  Future<void> insertMessageLog(MessageLog log) async {
    final db = await database;
    await db.insert('message_logs', log.toMap());
  }

  Future<List<MessageLog>> getMessageLogs(String messageId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'message_logs',
      where: 'message_id = ?',
      whereArgs: [messageId],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => MessageLog.fromMap(maps[i]));
  }

  // API Keys CRUD operations
  Future<void> insertApiKey(ApiKey apiKey) async {
    final db = await database;
    await db.insert('api_keys', apiKey.toMap());
  }

  Future<ApiKey?> getApiKeyByHash(String keyHash) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'api_keys',
      where: 'key_hash = ? AND is_active = 1',
      whereArgs: [keyHash],
    );

    if (maps.isNotEmpty) {
      return ApiKey.fromMap(maps.first);
    }
    return null;
  }

  Future<List<ApiKey>> getAllApiKeys() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'api_keys',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => ApiKey.fromMap(maps[i]));
  }

  Future<void> updateApiKey(ApiKey apiKey) async {
    final db = await database;
    await db.update(
      'api_keys',
      apiKey.toMap(),
      where: 'id = ?',
      whereArgs: [apiKey.id],
    );
  }



  Future<String> createApiKey({
    required String name,
    int? rateLimit,
  }) async {
    final apiKey = ApiKey(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      keyHash: _generateApiKey(),
      rateLimit: rateLimit ?? 100,
      isActive: true,
      createdAt: DateTime.now(),
      usageCount: 0,
    );
    
    await insertApiKey(apiKey);
    return apiKey.keyHash;
  }

  String _generateApiKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> incrementApiKeyUsage(String keyHash) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE api_keys SET usage_count = usage_count + 1 WHERE key_hash = ?',
      [keyHash],
    );
  }

  // Request Logs CRUD operations
  Future<void> insertRequestLog(RequestLog log) async {
    final db = await database;
    await db.insert('request_logs', log.toMap());
  }

  Future<List<RequestLog>> getRequestLogs({int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'request_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) => RequestLog.fromMap(maps[i]));
  }

  // Device Configuration CRUD operations
  Future<void> setConfig(String key, String value) async {
    final db = await database;
    await db.insert(
      'device_config',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getConfig(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'device_config',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'];
    }
    return AppConfig.defaultValues[key];
  }

  Future<Map<String, String>> getAllConfig() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('device_config');
    
    Map<String, String> config = {};
    for (var map in maps) {
      config[map['key']] = map['value'];
    }
    
    return config;
  }

  Future<List<DeviceConfig>> getAllConfigs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('device_config');
    
    return List.generate(maps.length, (i) => DeviceConfig.fromMap(maps[i]));
  }

  Future<ApiKey?> getApiKey(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'api_keys',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ApiKey.fromMap(maps.first);
    }
    return null;
  }

  Future<int> getRequestCountInWindow(String apiKeyId, DateTime since) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM request_logs WHERE api_key = ? AND timestamp >= ?',
      [apiKeyId, since.toIso8601String()],
    );
    
    return result.first['count'] as int;
  }

  Future<List<ApiKey>> getExpiredApiKeys() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'api_keys',
      where: 'expires_at IS NOT NULL AND expires_at < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );

    return List.generate(maps.length, (i) => ApiKey.fromMap(maps[i]));
  }

  Future<bool> deleteApiKey(String id) async {
    final db = await database;
    final result = await db.delete(
      'api_keys',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result > 0;
  }

  // Statistics methods
  Future<void> initialize() async {
    try {
      await database; // This will trigger database creation if needed
      
      // Create default API key if none exists
      final existingKeys = await getAllApiKeys();
      if (existingKeys.isEmpty) {
        final defaultKey = await createApiKey(
          name: 'Default API Key',
          rateLimit: 100,
        );
        LoggingService.info('Default API Key created: $defaultKey', tag: 'DatabaseService');
      }
    } catch (e) {
      LoggingService.error('Error initializing database', tag: 'DatabaseService', error: e);
      rethrow;
    }
  }

  // Statistics methods
  Future<Map<String, dynamic>> getMessageStatistics() async {
    final db = await database;
    
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM sms_messages');
    final sentResult = await db.rawQuery("SELECT COUNT(*) as count FROM sms_messages WHERE status = 'sent'");
    final deliveredResult = await db.rawQuery("SELECT COUNT(*) as count FROM sms_messages WHERE status = 'delivered'");
    final failedResult = await db.rawQuery("SELECT COUNT(*) as count FROM sms_messages WHERE status = 'failed'");
    final pendingResult = await db.rawQuery("SELECT COUNT(*) as count FROM sms_messages WHERE status = 'pending'");
    
    // Get today's message count
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final todayResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sms_messages WHERE created_at >= ?',
      [startOfDay.toIso8601String()],
    );
    
    // Calculate success rate
    final total = totalResult.first['count'] as int;
    final sent = sentResult.first['count'] as int;
    final delivered = deliveredResult.first['count'] as int;
    final failed = failedResult.first['count'] as int;
    final success = sent + delivered;
    final successRate = total > 0 ? (success / total) * 100 : 0.0;
    final totalSent = sent + delivered;
    
    return {
      'total': total,
      'sent': sent,
      'delivered': delivered,
      'failed': failed,
      'pending': pendingResult.first['count'] as int,
      'todayCount': todayResult.first['count'] as int,
      'successRate': successRate,
      'failedCount': failed,
      'totalSent': totalSent,
    };
  }

  Future<List<SmsMessage>> getRecentMessages({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_messages',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) => SmsMessage.fromMap(maps[i]));
  }

  Future<int> getTodayMessageCount() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sms_messages WHERE created_at >= ?',
      [startOfDay.toIso8601String()],
    );
    
    return result.first['count'] as int;
  }

  Future<double> getSuccessRate() async {
    final db = await database;
    
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM sms_messages');
    final successResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sms_messages WHERE status IN ('sent', 'delivered')",
    );
    
    final total = totalResult.first['count'] as int;
    final success = successResult.first['count'] as int;
    
    if (total == 0) return 0.0;
    return (success / total) * 100;
  }

  Future<int> getFailedMessageCount() async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as count FROM sms_messages WHERE status = 'failed'");
    return result.first['count'] as int;
  }

  Future<MessageStatus?> getMessageStatus(String messageId) async {
    final message = await getSmsMessage(messageId);
    return message?.status;
  }

  Future<List<SmsMessage>> getFailedMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_messages',
      where: "status = 'failed'",
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => SmsMessage.fromMap(maps[i]));
  }

  // Cleanup methods
  Future<void> cleanupOldLogs({int daysToKeep = 30}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    await db.delete(
      'request_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
    
    await db.delete(
      'message_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // Received SMS CRUD operations
  Future<String> insertReceivedSms({
    required String sender,
    required String messageContent,
    required int simSlot,
    required DateTime receivedAt,
    bool isMultipart = false,
    int multipartCount = 1,
  }) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    await db.insert('received_sms', {
      'id': id,
      'sender': sender,
      'message_content': messageContent,
      'sim_slot': simSlot,
      'received_at': receivedAt.toIso8601String(),
      'is_read': 0,
      'is_multipart': isMultipart ? 1 : 0,
      'multipart_count': multipartCount,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    return id;
  }

  Future<List<ReceivedSms>> getReceivedSms({
    int? limit,
    int? offset,
    String? sender,
    bool? unreadOnly,
    int? simSlot,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    List<String> conditions = [];
    
    if (sender != null) {
      conditions.add('sender = ?');
      whereArgs.add(sender);
    }
    
    if (unreadOnly == true) {
      conditions.add('is_read = ?');
      whereArgs.add(0);
    }
    
    if (simSlot != null) {
      conditions.add('sim_slot = ?');
      whereArgs.add(simSlot);
    }
    
    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'received_sms',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'received_at DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) => ReceivedSms.fromMap(maps[i]));
  }

  Future<ReceivedSms?> getReceivedSmsById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'received_sms',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ReceivedSms.fromMap(maps.first);
    }
    return null;
  }

  Future<bool> markReceivedSmsAsRead(String id) async {
    final db = await database;
    final result = await db.update(
      'received_sms',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    return result > 0;
  }

  Future<int> markAllReceivedSmsAsRead({String? sender}) async {
    final db = await database;
    
    if (sender != null) {
      return await db.update(
        'received_sms',
        {'is_read': 1},
        where: 'sender = ?',
        whereArgs: [sender],
      );
    } else {
      return await db.update(
        'received_sms',
        {'is_read': 1},
      );
    }
  }

  Future<int> getUnreadReceivedSmsCount({String? sender}) async {
    final db = await database;
    
    String whereClause = 'is_read = 0';
    List<dynamic> whereArgs = [0];
    
    if (sender != null) {
      whereClause += ' AND sender = ?';
      whereArgs.add(sender);
    }
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM received_sms WHERE $whereClause',
      whereArgs,
    );
    
    return result.first['count'] as int;
  }

  Future<bool> deleteReceivedSms(String id) async {
    final db = await database;
    final result = await db.delete(
      'received_sms',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result > 0;
  }

  Future<int> deleteAllReceivedSms({String? sender}) async {
    final db = await database;
    
    if (sender != null) {
      return await db.delete(
        'received_sms',
        where: 'sender = ?',
        whereArgs: [sender],
      );
    } else {
      return await db.delete('received_sms');
    }
  }

  Future<int> getReceivedSmsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM received_sms');
    return result.first['count'] as int;
  }

  Future<int> getMultipartReceivedSmsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM received_sms WHERE is_multipart = 1');
    return result.first['count'] as int;
  }

  Future<int> getTodayReceivedSmsCount() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM received_sms WHERE received_at >= ?',
      [startOfDay.toIso8601String()],
    );
    
    return result.first['count'] as int;
  }

  Future<int> getUniqueSendersCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(DISTINCT sender) as count FROM received_sms');
    return result.first['count'] as int;
  }

  Future<Map<String, dynamic>> getReceivedSmsStatistics() async {
    final db = await database;
    
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM received_sms');
    final unreadResult = await db.rawQuery('SELECT COUNT(*) as count FROM received_sms WHERE is_read = 0');
    final multipartResult = await db.rawQuery('SELECT COUNT(*) as count FROM received_sms WHERE is_multipart = 1');
    
    // Get today's received message count
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final todayResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM received_sms WHERE received_at >= ?',
      [startOfDay.toIso8601String()],
    );
    
    // Get unique senders count
    final sendersResult = await db.rawQuery('SELECT COUNT(DISTINCT sender) as count FROM received_sms');
    
    return {
      'total': totalResult.first['count'] as int,
      'unread': unreadResult.first['count'] as int,
      'multipart': multipartResult.first['count'] as int,
      'todayCount': todayResult.first['count'] as int,
      'uniqueSenders': sendersResult.first['count'] as int,
    };
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}