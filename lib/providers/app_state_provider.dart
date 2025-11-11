import 'package:flutter/foundation.dart';

import '../services/http_server_service.dart';
import '../services/sms_service.dart';
import '../services/config_service.dart';
import '../services/network_discovery_service.dart';
import '../services/api_key_service.dart';
import '../models/sms_message.dart';
import '../models/device_info.dart';
import '../services/logging_service.dart';


class AppStateProvider extends ChangeNotifier {
  final HttpServerService _httpServerService = HttpServerService();
  final SmsService _smsService = SmsService();
  final ConfigService _configService = ConfigService();
  final NetworkDiscoveryService _networkDiscovery = NetworkDiscoveryService();
  final ApiKeyService _apiKeyService = ApiKeyService();
  

  bool _isLoading = false;
  bool _isServerRunning = false;
  String _serverUrl = 'http://localhost:8080';
  Map<String, dynamic> _stats = {};
  List<SmsMessage> _recentMessages = [];
  DeviceInfo? _deviceInfo;

  // Getters
  bool get isLoading => _isLoading;
  bool get isServerRunning => _isServerRunning;
  String get serverUrl => _serverUrl;
  Map<String, dynamic> get stats => _stats;
  List<SmsMessage> get recentMessages => _recentMessages;
  DeviceInfo? get deviceInfo => _deviceInfo;

  // Initialize the provider
  Future<void> initialize() async {
    await _updateServerUrl();
    await refreshAll();
  }

  /// Update server URL with device IP address
  Future<void> _updateServerUrl() async {
    try {
      // Get server configuration
      final serverConfig = await _configService.getServerConfig();
      final port = serverConfig['port'] ?? 8080;
      
      // Use network discovery service to get the best server address
      final deviceIP = await _networkDiscovery.getBestServerAddress();
      
      if (deviceIP != '0.0.0.0') {
        _serverUrl = 'http://$deviceIP:$port';
        LoggingService.info('Server URL updated to: $_serverUrl (IP: $deviceIP)', tag: 'AppStateProvider');
      } else {
        // Fallback to 0.0.0.0 to indicate server is listening on all interfaces
        _serverUrl = 'http://0.0.0.0:$port';
        LoggingService.warning('Could not determine device IP, server listening on all interfaces', tag: 'AppStateProvider');
      }
      
      notifyListeners();
    } catch (e) {
      LoggingService.error('Error updating server URL', tag: 'AppStateProvider', error: e);
      // Keep default localhost URL on error
      final serverConfig = await _configService.getServerConfig();
      final port = serverConfig['port'] ?? 8080;
      _serverUrl = 'http://localhost:$port';
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshServerStatus(),
      refreshStats(),
      refreshRecentMessages(),
      refreshDeviceInfo(),
    ]);
  }

  Future<void> refreshServerStatus() async {
    try {
      _isServerRunning = _httpServerService.isRunning;
      // Update server URL when checking status
      await _updateServerUrl();
      notifyListeners();
    } catch (e) {
      LoggingService.error('Error refreshing server status', tag: 'AppStateProvider', error: e);
    }
  }

  Future<void> refreshStats() async {
    try {
      final stats = await _smsService.getStatistics();
      _stats = stats;
      notifyListeners();
    } catch (e) {
      LoggingService.error('Error refreshing stats', tag: 'AppStateProvider', error: e);
    }
  }

  Future<void> refreshRecentMessages() async {
    try {
      _recentMessages = await _smsService.getRecentMessages(limit: 10);
      notifyListeners();
    } catch (e) {
      LoggingService.error('Error refreshing recent messages', tag: 'AppStateProvider', error: e);
    }
  }

  Future<void> startServer() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _httpServerService.startServer();
      _isServerRunning = true;
    } catch (e) {
      LoggingService.error('Error starting server', tag: 'AppStateProvider', error: e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _httpServerService.stopServer();
      _isServerRunning = false;
    } catch (e) {
      LoggingService.error('Error stopping server', tag: 'AppStateProvider', error: e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> sendTestSms(String phoneNumber, String message, {int? simSlot}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final smsMessage = await _smsService.sendSms(
        recipient: phoneNumber,
        message: message,
        simSlot: simSlot ?? 0,
      );
      
      // Refresh recent messages
      await refreshRecentMessages();
      
      return smsMessage.id;
    } catch (e) {
      LoggingService.error('Error sending test SMS', tag: 'AppStateProvider', error: e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDeviceInfo() async {
    try {
      _deviceInfo = await _smsService.getDeviceInfo();
      notifyListeners();
    } catch (e) {
      LoggingService.error('Error getting device info', tag: 'AppStateProvider', error: e);
    }
  }

  // Network Discovery Methods
  NetworkDiscoveryService get networkDiscovery => _networkDiscovery;

  Future<Map<String, dynamic>> getNetworkInfo() async {
    return await _networkDiscovery.getNetworkInfo();
  }

  Future<List<Map<String, dynamic>>> getNetworkInterfaces() async {
    return await _networkDiscovery.getNetworkInterfaces();
  }

  Future<bool> isConnectedToWiFi() async {
    return await _networkDiscovery.isConnectedToWiFi();
  }

  Future<String> generateConnectionQR() async {
    final serverConfig = await _configService.getServerConfig();
    final port = serverConfig['port'] ?? 8080;
    final serverAddress = await _networkDiscovery.getBestServerAddress();
    final defaultApiKey = await _apiKeyService.getDefaultApiKey() ?? 'default-api-key';
    return _networkDiscovery.generateConnectionQR(serverAddress, port, defaultApiKey);
  }

  Future<Map<String, dynamic>> getConnectionInstructions() async {
    final serverConfig = await _configService.getServerConfig();
    final port = serverConfig['port'] ?? 8080;
    final serverAddress = await _networkDiscovery.getBestServerAddress();
    final defaultApiKey = await _apiKeyService.getDefaultApiKey() ?? 'default-api-key';
    return _networkDiscovery.getConnectionInstructions(serverAddress, port, defaultApiKey);
  }
}