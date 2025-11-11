import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/request_log.dart';
import 'database_service.dart';
import 'sms_service.dart';
import 'api_key_service.dart';
import 'config_service.dart';
import 'logging_service.dart';
import 'network_discovery_service.dart';

class HttpServerService {
  static final HttpServerService _instance = HttpServerService._internal();
  factory HttpServerService() => _instance;
  HttpServerService._internal();

  HttpServer? _server;
  final DatabaseService _databaseService = DatabaseService();
  final SmsService _smsService = SmsService();
  final ApiKeyService _apiKeyService = ApiKeyService();
  final ConfigService _configService = ConfigService();
  final _uuid = const Uuid();

  bool get isRunning => _server != null;
  String? get serverAddress => _server?.address.address;
  int? get serverPort => _server?.port;

  Future<void> startServer() async {
    if (_server != null) {
      LoggingService.info('Server is already running', tag: 'HttpServer');
      return;
    }

    try {
      final config = await _configService.getServerConfig();
      final port = config['port'] ?? 8080;

      final router = _createRouter();
      final handler = Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(_corsMiddleware)
          .addMiddleware(_authMiddleware)
          .addHandler(router.call);

      // Ensure we bind to all network interfaces for WiFi access
      // Bind to all available network interfaces for better accessibility
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port, shared: true);
      
      // Set server options for better background performance
      _server!.autoCompress = false; // Reduce CPU usage
      
      // Log all available network addresses
      await _logNetworkAddresses(port);
      
      LoggingService.info('Server started on http://${_server!.address.address}:${_server!.port}', tag: 'HttpServer');
      LoggingService.info('Server accessible on WiFi network with shared binding', tag: 'HttpServer');
    } catch (e) {
      LoggingService.error('Failed to start server', tag: 'HttpServer', error: e);
      rethrow;
    }
  }

  /// Log all available network addresses for easier connectivity
  Future<void> _logNetworkAddresses(int port) async {
    try {
      final interfaces = await NetworkInterface.list();
      LoggingService.info('=== SMS Gateway Network Information ===', tag: 'HttpServer');
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            LoggingService.info('WiFi/Network Access: http://${addr.address}:$port', tag: 'HttpServer');
          }
        }
      }
      LoggingService.info('=======================================', tag: 'HttpServer');
     } catch (e) {
       LoggingService.warning('Could not enumerate network interfaces: $e', tag: 'HttpServer');
     }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      LoggingService.info('Server stopped', tag: 'HttpServer');
    }
  }

  Router _createRouter() {
    final router = Router();

    // Health check endpoint
    router.get('/health', _handleHealthCheck);

    // Device info endpoint
    router.get('/device-info', _handleDeviceInfo);

    // Send SMS endpoint
    router.post('/send-sms', _handleSendSms);

    // Send bulk SMS endpoint
    router.post('/send-bulk', _handleSendBulkSms);

    // Get message status endpoint
    router.get('/message/<messageId>/status', _handleMessageStatus);

    // Get statistics endpoint
    router.get('/statistics', _handleStatistics);

    // Get recent messages endpoint
    router.get('/messages/recent', _handleRecentMessages);

    // Received SMS endpoints
    router.get('/sms/received', _handleGetReceivedSms);
    router.get('/sms/received/<messageId>', _handleGetReceivedSmsById);
    router.put('/sms/received/<messageId>/read', _handleMarkReceivedSmsAsRead);
    router.put('/sms/received/read-all', _handleMarkAllReceivedSmsAsRead);
    router.delete('/sms/received/<messageId>', _handleDeleteReceivedSms);
    router.delete('/sms/received/all', _handleDeleteAllReceivedSms);
    router.get('/sms/received/statistics', _handleReceivedSmsStatistics);

    // Add network discovery endpoint
    router.get('/network-info', (Request request) async {
      try {
        final networkDiscovery = NetworkDiscoveryService();
        final networkInfo = await networkDiscovery.getNetworkInfo();
        final interfaces = await networkDiscovery.getNetworkInterfaces();
        
        // Get default API key for connection instructions
         final defaultApiKey = await _apiKeyService.getDefaultApiKey();
         final apiKeyValue = defaultApiKey ?? 'sms-gateway-default-key-2024';
        
        final connectionInstructions = networkDiscovery.getConnectionInstructions(
          _server?.address.address ?? '0.0.0.0',
          _server?.port ?? 8080,
          apiKeyValue,
        );
        
        return Response.ok(
          jsonEncode({
            'network_info': networkInfo,
            'interfaces': interfaces,
            'server_info': {
              'address': _server?.address.address,
              'port': _server?.port,
              'is_running': isRunning,
            },
            'connection_instructions': connectionInstructions,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        LoggingService.error('Error getting network info', tag: 'HttpServer', error: e);
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to get network info', 'details': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    return router;
  }

  // CORS middleware
  Middleware get _corsMiddleware => (Handler handler) {
    return (Request request) async {
      // Handle preflight OPTIONS requests
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }

      final response = await handler(request);
      return response.change(headers: _corsHeaders);
    };
  };

  Map<String, String> get _corsHeaders => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS, PATCH',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-API-Key, Accept, Origin, X-Requested-With',
    'Access-Control-Allow-Credentials': 'false',
    'Access-Control-Max-Age': '86400',
  };

  // Authentication middleware
  Middleware get _authMiddleware => (Handler handler) {
    return (Request request) async {
      // Skip auth for health check and network-info
      if (request.url.path == 'health' || request.url.path == 'network-info') {
        return handler(request);
      }

      String? apiKey = request.headers['x-api-key'] ?? 
                       request.headers['authorization'];
      
      // Handle Bearer token format
      if (apiKey != null && apiKey.startsWith('Bearer ')) {
        apiKey = apiKey.substring(7);
      }
      
      if (apiKey == null || apiKey.isEmpty) {
        LoggingService.warning('API key missing in request to ${request.url.path} from ${request.headers['x-forwarded-for'] ?? 'unknown'}', tag: 'HttpServer');
        return Response.unauthorized(
          jsonEncode({
            'error': 'API key required', 
            'hint': 'Use X-API-Key header or Authorization: Bearer <key>',
            'default_key': 'sms-gateway-default-key-2024'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final validatedKey = await _apiKeyService.validateApiKey(apiKey);
      if (validatedKey == null) {
        LoggingService.warning('Invalid API key used: ${apiKey.length > 8 ? apiKey.substring(0, 8) : apiKey}... from ${request.headers['x-forwarded-for'] ?? 'unknown'}', tag: 'HttpServer');
        return Response.forbidden(
          jsonEncode({
            'error': 'Invalid API key', 
            'hint': 'Check your API key and ensure it is active',
            'default_key': 'sms-gateway-default-key-2024'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Log successful authentication
      LoggingService.info('Authenticated request to ${request.url.path} from ${request.headers['x-forwarded-for'] ?? 'unknown'}', tag: 'HttpServer');

      // Log the request
      await _logRequest(request, apiKey);

      return handler(request);
    };
  };

  // Health check handler
  Future<Response> _handleHealthCheck(Request request) async {
    try {
      final deviceInfo = await _smsService.getDeviceInfo();
      final stats = await _smsService.getStatistics();
      
      return Response.ok(
        jsonEncode({
          'status': 'healthy',
          'timestamp': DateTime.now().toIso8601String(),
          'server': {
            'running': isRunning,
            'address': serverAddress,
            'port': serverPort,
          },
          'device': deviceInfo.toMap(),
          'statistics': stats,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Health check failed', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Health check failed', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Device info handler
  Future<Response> _handleDeviceInfo(Request request) async {
    try {
      final deviceInfo = await _smsService.getDeviceInfo();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': deviceInfo.toMap(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to get device info', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get device info', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Send SMS handler
  Future<Response> _handleSendSms(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final recipient = data['recipient'] as String?;
      final message = data['message'] as String?;
      final simSlot = data['simSlot'] as int? ?? 0;

      if (recipient == null || message == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing required fields: recipient, message'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (message.trim().isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Message content cannot be empty'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final smsMessage = await _smsService.sendSms(
        recipient: recipient,
        message: message,
        simSlot: simSlot,
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'messageId': smsMessage.id,
          'status': smsMessage.status.toString().split('.').last,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to send SMS', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to send SMS', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Send bulk SMS handler
  Future<Response> _handleSendBulkSms(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final recipients = (data['recipients'] as List?)?.cast<String>();
      final message = data['message'] as String?;
      final simSlot = data['simSlot'] as int? ?? 0;

      if (recipients == null || message == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing required fields: recipients, message'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (recipients.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Recipients list cannot be empty'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (recipients.length > 100) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Too many recipients (max 100)'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final messages = await _smsService.sendBulkSms(
        recipients: recipients,
        message: message,
        simSlot: simSlot,
      );

      final results = messages.map((msg) => {
        'messageId': msg.id,
        'recipient': msg.recipient,
        'status': msg.status.toString().split('.').last,
      }).toList();

      return Response.ok(
        jsonEncode({
          'success': true,
          'results': results,
          'totalSent': messages.length,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to send bulk SMS', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to send bulk SMS', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Message status handler
  Future<Response> _handleMessageStatus(Request request, String messageId) async {
    try {
      final message = await _smsService.getMessageStatus(messageId);
      
      if (message == null) {
        return Response.notFound(
          jsonEncode({'error': 'Message not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'messageId': message.id,
          'recipient': message.recipient,
          'status': message.status.toString().split('.').last,
          'createdAt': message.createdAt.toIso8601String(),
          'sentAt': message.sentAt?.toIso8601String(),
          'deliveredAt': message.deliveredAt?.toIso8601String(),
          'errorMessage': message.errorMessage,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to get message status', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get message status', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Statistics handler
  Future<Response> _handleStatistics(Request request) async {
    try {
      final stats = await _smsService.getStatistics();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'statistics': stats,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to get statistics', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get statistics', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Recent messages handler
  Future<Response> _handleRecentMessages(Request request) async {
    try {
      final limitParam = request.url.queryParameters['limit'];
      final limit = int.tryParse(limitParam ?? '10') ?? 10;
      
      final messages = await _smsService.getRecentMessages(limit: limit);
      
      final messageData = messages.map((msg) => {
        'messageId': msg.id,
        'recipient': msg.recipient,
        'message': msg.messageContent,
        'status': msg.status.toString().split('.').last,
        'createdAt': msg.createdAt.toIso8601String(),
        'sentAt': msg.sentAt?.toIso8601String(),
        'deliveredAt': msg.deliveredAt?.toIso8601String(),
      }).toList();

      return Response.ok(
        jsonEncode({
          'success': true,
          'messages': messageData,
          'count': messages.length,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to get recent messages', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get recent messages', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Get received SMS messages handler
  Future<Response> _handleGetReceivedSms(Request request) async {
    try {
      final limitParam = request.url.queryParameters['limit'];
      final offsetParam = request.url.queryParameters['offset'];
      final senderParam = request.url.queryParameters['sender'];
      final unreadOnlyParam = request.url.queryParameters['unread_only'];
      final simSlotParam = request.url.queryParameters['sim_slot'];

      final limit = int.tryParse(limitParam ?? '50') ?? 50;
      final offset = int.tryParse(offsetParam ?? '0') ?? 0;
      final unreadOnly = unreadOnlyParam?.toLowerCase() == 'true';
      final simSlot = simSlotParam != null ? int.tryParse(simSlotParam) : null;

      final messages = await _databaseService.getReceivedSms(
        limit: limit,
        offset: offset,
        sender: senderParam,
        unreadOnly: unreadOnly,
        simSlot: simSlot,
      );

      final messageData = messages.map((msg) => {
        'id': msg.id,
        'sender': msg.sender,
        'message': msg.messageContent,
        'simSlot': msg.simSlot,
        'receivedAt': msg.receivedAt.toIso8601String(),
        'isRead': msg.isRead,
        'isMultipart': msg.isMultipart,
        'multipartCount': msg.multipartCount,
        'createdAt': msg.createdAt.toIso8601String(),
      }).toList();

      return Response.ok(
        jsonEncode({
          'success': true,
          'messages': messageData,
          'count': messages.length,
          'pagination': {
            'limit': limit,
            'offset': offset,
            'hasMore': messages.length == limit,
          },
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to get received SMS messages', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get received SMS messages', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Get received SMS by ID handler
  Future<Response> _handleGetReceivedSmsById(Request request, String messageId) async {
    try {
      final message = await _databaseService.getReceivedSmsById(messageId);
      
      if (message == null) {
        return Response.notFound(
          jsonEncode({'error': 'Received SMS message not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': {
            'id': message.id,
            'sender': message.sender,
            'message': message.messageContent,
            'simSlot': message.simSlot,
            'receivedAt': message.receivedAt.toIso8601String(),
            'isRead': message.isRead,
            'isMultipart': message.isMultipart,
            'multipartCount': message.multipartCount,
            'createdAt': message.createdAt.toIso8601String(),
          },
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to get received SMS by ID', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get received SMS', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Mark received SMS as read handler
  Future<Response> _handleMarkReceivedSmsAsRead(Request request, String messageId) async {
    try {
      final success = await _databaseService.markReceivedSmsAsRead(messageId);
      
      if (!success) {
        return Response.notFound(
          jsonEncode({'error': 'Received SMS message not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'SMS marked as read',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to mark received SMS as read', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to mark SMS as read', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Mark all received SMS as read handler
  Future<Response> _handleMarkAllReceivedSmsAsRead(Request request) async {
    try {
      final count = await _databaseService.markAllReceivedSmsAsRead();

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'All SMS messages marked as read',
          'markedCount': count,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to mark all received SMS as read', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to mark all SMS as read', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Delete received SMS handler
  Future<Response> _handleDeleteReceivedSms(Request request, String messageId) async {
    try {
      final success = await _databaseService.deleteReceivedSms(messageId);
      
      if (!success) {
        return Response.notFound(
          jsonEncode({'error': 'Received SMS message not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'SMS message deleted',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to delete received SMS', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to delete SMS', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Delete all received SMS handler
  Future<Response> _handleDeleteAllReceivedSms(Request request) async {
    try {
      final count = await _databaseService.deleteAllReceivedSms();

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'All SMS messages deleted',
          'deletedCount': count,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to delete all received SMS', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to delete all SMS', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Received SMS statistics handler
  Future<Response> _handleReceivedSmsStatistics(Request request) async {
    try {
      final totalCount = await _databaseService.getReceivedSmsCount();
      final unreadCount = await _databaseService.getUnreadReceivedSmsCount();
      final multipartCount = await _databaseService.getMultipartReceivedSmsCount();
      final todayCount = await _databaseService.getTodayReceivedSmsCount();
      final uniqueSendersCount = await _databaseService.getUniqueSendersCount();

      return Response.ok(
        jsonEncode({
          'success': true,
          'statistics': {
            'totalReceived': totalCount,
            'unreadCount': unreadCount,
            'multipartCount': multipartCount,
            'todayCount': todayCount,
            'uniqueSendersCount': uniqueSendersCount,
          },
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggingService.error('Failed to get received SMS statistics', tag: 'HttpServer', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get statistics', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Log request
  Future<void> _logRequest(Request request, String apiKey) async {
    try {
      final requestLog = RequestLog(
        id: _uuid.v4(),
        endpoint: request.url.path,
        method: request.method,
        apiKey: apiKey,
        ipAddress: request.headers['x-forwarded-for'] ?? 'unknown',
        userAgent: request.headers['user-agent'] ?? 'unknown',
        timestamp: DateTime.now(),
        responseStatus: 200, // Will be updated later if needed
      );

      await _databaseService.insertRequestLog(requestLog);
    } catch (e) {
      LoggingService.error('Failed to log request', tag: 'HttpServer', error: e);
    }
  }

  // Get server status
  Map<String, dynamic> getServerStatus() {
    return {
      'isRunning': isRunning,
      'address': serverAddress,
      'port': serverPort,
      'uptime': _server != null ? DateTime.now().toIso8601String() : null,
    };
  }

  void dispose() {
    stopServer();
  }
}