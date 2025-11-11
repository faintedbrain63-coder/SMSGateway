import 'dart:async';
import 'dart:io';

// import 'package:flutter_sms/flutter_sms.dart'; // Commented out due to namespace issues
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/sms_message.dart' as models;
import '../models/message_log.dart';
import '../models/device_info.dart';
import 'database_service.dart';
import 'logging_service.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  // Using platform channel for SMS functionality
  static const MethodChannel _smsChannel = MethodChannel('sms_gateway/sms');
  final DatabaseService _databaseService = DatabaseService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final _uuid = const Uuid();
  
  Timer? _retryTimer;
  final StreamController<models.SmsMessage> _messageStatusController = StreamController<models.SmsMessage>.broadcast();
  
  Stream<models.SmsMessage> get messageStatusStream => _messageStatusController.stream;
  bool _isInitialized = false;

  /// Initialize the SMS service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      LoggingService.info('Initializing SMS service', tag: 'SmsService');
      
      // Check permissions
      final hasPermissions = await _checkPermissions();
      if (!hasPermissions) {
        throw Exception('SMS permissions not granted');
      }

      // Initialize SMS service
      // No specific initialization needed for sms_advanced
      
      // Start retry timer for failed messages
      _startRetryTimer();
      
      _isInitialized = true;
      LoggingService.info('SMS service initialized successfully', tag: 'SmsService');
    } catch (e) {
      LoggingService.error('Failed to initialize SMS service', tag: 'SmsService', error: e);
      rethrow;
    }
  }

  /// Check and request necessary permissions
  Future<bool> _checkPermissions() async {
    final permissions = [
      Permission.sms,
      Permission.phone,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    return statuses.values.every((status) => status.isGranted);
  }

  /// Send SMS message
  Future<models.SmsMessage> sendSms({
    required String recipient,
    required String message,
    int simSlot = 0,
  }) async {
    try {
      LoggingService.info('Sending SMS to $recipient', tag: 'SmsService');
      
      // Create message record
      final smsMessage = models.SmsMessage(
        id: _uuid.v4(),
        recipient: recipient,
        messageContent: message,
        status: models.MessageStatus.pending,
        simSlot: simSlot,
        createdAt: DateTime.now(),
      );

      // Save to database
      await _databaseService.insertSmsMessage(smsMessage);

      // Send SMS
      await _sendSmsMessage(smsMessage);
      
      return smsMessage;
    } catch (e) {
      LoggingService.error('Error sending SMS', tag: 'SmsService', error: e);
      rethrow;
    }
  }

  /// Send bulk SMS messages
  Future<List<models.SmsMessage>> sendBulkSms({
    required List<String> recipients,
    required String message,
    int simSlot = 0,
  }) async {
    final messages = <models.SmsMessage>[];
    
    for (final recipient in recipients) {
      try {
        final smsMessage = await sendSms(
          recipient: recipient,
          message: message,
          simSlot: simSlot,
        );
        messages.add(smsMessage);
      } catch (e) {
        LoggingService.error('Error sending bulk SMS to $recipient', tag: 'SmsService', error: e);
        // Continue with other recipients
      }
    }
    
    return messages;
  }

  /// Internal method to send SMS
  Future<void> _sendSmsMessage(models.SmsMessage message) async {
    try {
      // Send SMS using platform channel
      await _smsChannel.invokeMethod('sendSMS', {
        'recipient': message.recipient,
        'message': message.messageContent,
        'messageId': message.id,
      });

      // Update message status to sent
      final updatedMessage = message.copyWith(
        status: models.MessageStatus.sent,
        sentAt: DateTime.now(),
      );
      
      await _databaseService.updateSmsMessage(updatedMessage);
      await _logMessageStatus(message.id, models.MessageStatus.sent, 'Message sent successfully');
      
      _messageStatusController.add(updatedMessage);
      
    } catch (e) {
      // Update message status to failed
      final updatedMessage = message.copyWith(
        status: models.MessageStatus.failed,
        errorMessage: e.toString(),
      );
      
      await _databaseService.updateSmsMessage(updatedMessage);
      await _logMessageStatus(message.id, models.MessageStatus.failed, e.toString());
      
      _messageStatusController.add(updatedMessage);
      
      LoggingService.error('Failed to send SMS', tag: 'SmsService', error: e);
      rethrow;
    }
  }

  /// Start retry timer for failed messages
  void _startRetryTimer() {
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _retryFailedMessages();
    });
  }

  /// Retry failed messages
  Future<void> _retryFailedMessages() async {
    try {
      final failedMessages = await _databaseService.getSmsMessagesByStatus('failed');
      
      for (final message in failedMessages) {
        // Check if message should be retried (implement retry logic here)
        if (_shouldRetryMessage(message)) {
          await _sendSmsMessage(message);
        }
      }
    } catch (e) {
      LoggingService.error('Error retrying failed messages', tag: 'SmsService', error: e);
    }
  }

  /// Check if message should be retried
  bool _shouldRetryMessage(models.SmsMessage message) {
    // Implement retry logic based on configuration
    // For now, retry messages that are less than 1 hour old
    final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
    return message.createdAt.isAfter(hourAgo);
  }

  /// Log message status change
  Future<void> _logMessageStatus(String messageId, models.MessageStatus status, String details) async {
    try {
      await _databaseService.insertMessageLog(
        MessageLog(
          id: _uuid.v4(),
          messageId: messageId,
          status: status,
          timestamp: DateTime.now(),
          details: details,
        ),
      );
    } catch (e) {
      LoggingService.error('Error logging message status', tag: 'SmsService', error: e);
    }
  }

  // Removed unused _handleSmsStatus method

  /// Get message status
  Future<models.SmsMessage?> getMessageStatus(String messageId) async {
    try {
      return await _databaseService.getMessageById(messageId);
    } catch (e) {
      LoggingService.error('Error getting message status', tag: 'SmsService', error: e);
      return null;
    }
  }

  /// Get device information
  Future<DeviceInfo> getDeviceInfo() async {
    try {
      final simCards = await _getSimCardInfo();
      
      String deviceId = 'unknown';
      String deviceName = 'Android Device';
      String deviceModel = 'Unknown';
      String osVersion = 'Unknown';
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceName = androidInfo.device;
        deviceModel = androidInfo.model;
        osVersion = 'Android ${androidInfo.version.release}';
      }
      
      return DeviceInfo(
        deviceId: deviceId,
        deviceName: deviceName,
        deviceModel: deviceModel,
        osVersion: osVersion,
        appVersion: '1.0.0',
        simCards: simCards,
        isServerRunning: false, // Will be updated by server service
        serverPort: 8080,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      LoggingService.error('Error getting device info', tag: 'SmsService', error: e);
      rethrow;
    }
  }

  /// Get SIM card information
  Future<List<SimInfo>> _getSimCardInfo() async {
    try {
      // This is a simplified implementation
      // In a real app, you'd use TelephonyManager to get actual SIM info
      return [
        SimInfo(
          slot: 0,
          carrierName: 'Carrier 1',
          phoneNumber: null,
          isActive: true,
        ),
        SimInfo(
          slot: 1,
          carrierName: 'Carrier 2',
          phoneNumber: null,
          isActive: false,
        ),
      ];
    } catch (e) {
      LoggingService.error('Error getting SIM card info', tag: 'SmsService', error: e);
      return [];
    }
  }

  /// Get SMS statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final stats = await _databaseService.getMessageStatistics();
      return stats;
    } catch (e) {
      LoggingService.error('Error getting SMS statistics', tag: 'SmsService', error: e);
      return {
        'total': 0,
        'sent': 0,
        'delivered': 0,
        'failed': 0,
        'pending': 0,
        'todayCount': 0,
        'successRate': 0.0,
        'failedCount': 0,
        'totalSent': 0,
      };
    }
  }

  Future<List<models.SmsMessage>> getRecentMessages({int limit = 10}) async {
    try {
      return await _databaseService.getRecentMessages(limit: limit);
    } catch (e) {
      LoggingService.error('Error getting recent messages', tag: 'SmsService', error: e);
      return [];
    }
  }

  Future<int> getTodayMessageCount() async {
    try {
      return await _databaseService.getTodayMessageCount();
    } catch (e) {
      LoggingService.error('Error getting today message count', tag: 'SmsService', error: e);
      return 0;
    }
  }

  Future<double> getSuccessRate() async {
    try {
      return await _databaseService.getSuccessRate();
    } catch (e) {
      LoggingService.error('Error getting success rate', tag: 'SmsService', error: e);
      return 0.0;
    }
  }

  Future<int> getFailedMessageCount() async {
    try {
      return await _databaseService.getFailedMessageCount();
    } catch (e) {
      LoggingService.error('Error getting failed message count', tag: 'SmsService', error: e);
      return 0;
    }
  }

  /// Check if device has SIM card
  Future<bool> hasSimCard() async {
    try {
      final simCards = await _getSimCardInfo();
      return simCards.any((sim) => sim.isActive);
    } catch (e) {
      return false;
    }
  }

  /// Get SIM card information
  Future<Map<String, dynamic>> getSimInfo() async {
    try {
      final simCards = await _getSimCardInfo();
      final activeSimCount = simCards.where((sim) => sim.isActive).length;
      
      return {
        'simCount': activeSimCount,
        'networkStatus': 'Connected',
        'isReady': activeSimCount > 0,
      };
    } catch (e) {
      return {
        'simCount': 0,
        'networkStatus': 'Unknown',
        'isReady': false,
      };
    }
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _messageStatusController.close();
    _isInitialized = false;
  }
}