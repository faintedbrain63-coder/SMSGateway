import 'package:flutter/services.dart';
import 'logging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'http_server_service.dart';

class BackgroundService {
  static const MethodChannel _channel = MethodChannel('sms_gateway/background_service');
  static BackgroundService? _instance;
  
  BackgroundService._();
  
  static BackgroundService get instance {
    _instance ??= BackgroundService._();
    return _instance!;
  }
  
  final HttpServerService _httpServerService = HttpServerService();
  
  /// Start the background HTTP server service
  Future<bool> startBackgroundService() async {
    try {
      LoggingService.info('Starting background service and HTTP server...', tag: 'BackgroundService');
      
      // Start the Flutter HTTP server first
      await _httpServerService.startServer();
      
      // Verify the server is running on port 8080
      if (!_httpServerService.isRunning || _httpServerService.serverPort != 8080) {
        throw Exception('HTTP server failed to start on port 8080');
      }
      
      LoggingService.info('HTTP server started successfully on ${_httpServerService.serverAddress}:${_httpServerService.serverPort}', tag: 'BackgroundService');
      
      // Then start the Android background service for foreground notification
      final result = await _channel.invokeMethod('startService');
      
      LoggingService.info('Background service started successfully', tag: 'BackgroundService');
      return result == true;
    } catch (e) {
      LoggingService.error('Error starting background service', tag: 'BackgroundService', error: e);
      return false;
    }
  }
  
  /// Stop the background HTTP server service
  Future<bool> stopBackgroundService() async {
    try {
      // Stop the Android background service first
      final result = await _channel.invokeMethod('stopService');
      
      // Then stop the Flutter HTTP server
      await _httpServerService.stopServer();
      
      LoggingService.info('Background service stopped successfully', tag: 'BackgroundService');
      return result == true;
    } catch (e) {
      LoggingService.error('Error stopping background service', tag: 'BackgroundService', error: e);
      return false;
    }
  }
  
  /// Check if background service is running
  Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isServiceRunning');
      final httpServerRunning = _httpServerService.isRunning;
      
      // Both services should be running for true background operation
      return result == true && httpServerRunning;
    } catch (e) {
      LoggingService.error('Error checking service status', tag: 'BackgroundService', error: e);
      return false;
    }
  }
  
  /// Enable auto-start on boot
  Future<void> setAutoStart(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_start_server', enabled);
  }
  
  /// Get auto-start preference
  Future<bool> getAutoStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_start_server') ?? false;
  }
  
  /// Initialize background service integration
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onServerStarted':
        LoggingService.info('Background server started', tag: 'BackgroundService');
        // Ensure HTTP server is also running
        if (!_httpServerService.isRunning) {
          await _httpServerService.startServer();
        }
        break;
      case 'onServerStopped':
        LoggingService.info('Background server stopped', tag: 'BackgroundService');
        // Stop HTTP server when background service stops
        if (_httpServerService.isRunning) {
          await _httpServerService.stopServer();
        }
        break;
      case 'onServerError':
        LoggingService.error('Background server error: ${call.arguments}', tag: 'BackgroundService');
        break;
      case 'startBackgroundServer':
        // Called from Android service to start HTTP server
        if (!_httpServerService.isRunning) {
          await _httpServerService.startServer();
        }
        break;
      case 'stopBackgroundServer':
        // Called from Android service to stop HTTP server
        if (_httpServerService.isRunning) {
          await _httpServerService.stopServer();
        }
        break;
      default:
        LoggingService.warning('Unknown method call: ${call.method}', tag: 'BackgroundService');
    }
  }
  
  Future<void> startBackgroundServer() async {
    try {
      LoggingService.info('Starting background HTTP server...', tag: 'BackgroundService');
      
      if (!_httpServerService.isRunning) {
        await _httpServerService.startServer();
        LoggingService.info('Background HTTP server started successfully on ${_httpServerService.serverAddress}:${_httpServerService.serverPort}', tag: 'BackgroundService');
      } else {
        LoggingService.info('Background HTTP server already running on ${_httpServerService.serverAddress}:${_httpServerService.serverPort}', tag: 'BackgroundService');
      }
    } catch (e, stackTrace) {
      LoggingService.error('Failed to start background HTTP server', 
          tag: 'BackgroundService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> stopBackgroundServer() async {
    try {
      LoggingService.info('Stopping background HTTP server...', tag: 'BackgroundService');
      
      if (_httpServerService.isRunning) {
        await _httpServerService.stopServer();
        LoggingService.info('Background HTTP server stopped successfully', tag: 'BackgroundService');
      } else {
        LoggingService.info('Background HTTP server already stopped', tag: 'BackgroundService');
      }
    } catch (e, stackTrace) {
      LoggingService.error('Failed to stop background HTTP server', 
          tag: 'BackgroundService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get server status information
  Map<String, dynamic> getServerStatus() {
    return {
      'http_server_running': _httpServerService.isRunning,
      'server_address': _httpServerService.serverAddress,
      'server_port': _httpServerService.serverPort,
    };
  }
}