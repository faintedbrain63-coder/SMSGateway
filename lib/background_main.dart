import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/sms_service.dart';
import 'services/http_server_service.dart';
import 'services/database_service.dart';
import 'services/logging_service.dart';

// Background entry point for the service
@pragma('vm:entry-point')
void backgroundMain() {
  print("Background main entry point called");
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the background service
  FlutterBackgroundService().invoke("setAsForeground");
  
  // Set up method channel for communication with native service
  const platform = MethodChannel('sms_gateway/background_service');
  
  platform.setMethodCallHandler((call) async {
    print("Background service received method call: ${call.method}");
    switch (call.method) {
      case 'startBackgroundServer':
        print("Starting background server...");
        await _startBackgroundServer();
        break;
      case 'stopBackgroundServer':
        print("Stopping background server...");
        await _stopBackgroundServer();
        break;
      case 'sendSMS':
        final recipient = call.arguments['recipient'] as String?;
        final message = call.arguments['message'] as String?;
        final messageId = call.arguments['messageId'] as String?;
        
        if (recipient != null && message != null && messageId != null) {
          await _sendSMSFromBackground(recipient, message, messageId);
        }
        break;
      case 'storeReceivedSms':
        final smsData = call.arguments as Map<String, dynamic>?;
        if (smsData != null) {
          await _storeReceivedSms(smsData);
          return true;
        }
        return false;
    }
  });
  
  // Start the background service immediately
  _startBackgroundServer();
  
  // Start the background service loop
  _runBackgroundService();
}

HttpServerService? _backgroundHttpService;
SmsService? _backgroundSmsService;

Future<void> _startBackgroundServer() async {
  try {
    if (_backgroundHttpService != null && _backgroundHttpService!.isRunning) {
      LoggingService.info('Background server already running', tag: 'BackgroundMain');
      return;
    }
    
    LoggingService.info('Starting background HTTP server...', tag: 'BackgroundMain');
    
    // Initialize database service
    await DatabaseService().initialize();
    LoggingService.info('Database service initialized', tag: 'BackgroundMain');
    
    // Initialize SMS service
    _backgroundSmsService = SmsService();
    try {
      await _backgroundSmsService!.initialize();
      LoggingService.info('SMS service initialized', tag: 'BackgroundMain');
    } catch (e) {
      LoggingService.warning('SMS service initialization failed (may be expected on emulator): $e', tag: 'BackgroundMain');
    }
    
    // Initialize HTTP server service with retry logic
    _backgroundHttpService = HttpServerService();
    
    // Ensure server starts on port 8080 specifically
    int maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        await _backgroundHttpService!.startServer();
        
        // Verify the server is running on the expected port
        if (_backgroundHttpService!.isRunning && _backgroundHttpService!.serverPort == 8080) {
          LoggingService.info('Background SMS Gateway server started successfully on ${_backgroundHttpService!.serverAddress}:${_backgroundHttpService!.serverPort}', tag: 'BackgroundMain');
          break;
        } else {
          throw Exception('Server not running on expected port 8080');
        }
        
      } catch (e) {
        retryCount++;
        LoggingService.warning('Server start attempt $retryCount failed: $e', tag: 'BackgroundMain');
        
        if (retryCount < maxRetries) {
          // Stop any partially started server
          if (_backgroundHttpService != null) {
            try {
              await _backgroundHttpService!.stopServer();
            } catch (_) {}
          }
          
          // Wait before retry
          await Future.delayed(Duration(seconds: retryCount * 2));
        } else {
          throw Exception('Failed to start server after $maxRetries attempts: $e');
        }
      }
    }
    
    // Update service notification
    FlutterBackgroundService().invoke("updateNotification", {
      "title": "SMS Gateway Active",
      "content": "HTTP Server running on port ${_backgroundHttpService!.serverPort}"
    });
    
    // Verify server is actually listening
    await _verifyServerConnection();
    
  } catch (e, stackTrace) {
    LoggingService.error('Error starting background server', tag: 'BackgroundMain', error: e, stackTrace: stackTrace);
    
    // Update notification to show error
    FlutterBackgroundService().invoke("updateNotification", {
      "title": "SMS Gateway Error",
      "content": "Failed to start HTTP server - retrying..."
    });
    
    // Try to restart after a delay
    Timer(const Duration(seconds: 10), () async {
      LoggingService.info('Retrying background server start...', tag: 'BackgroundMain');
      await _startBackgroundServer();
    });
  }
}

Future<void> _verifyServerConnection() async {
  try {
    if (_backgroundHttpService != null && _backgroundHttpService!.isRunning) {
      final address = _backgroundHttpService!.serverAddress;
      final port = _backgroundHttpService!.serverPort;
      
      // Test if server is actually accepting connections with shorter timeout
      final socket = await Socket.connect(address, port!, timeout: const Duration(seconds: 3));
      await socket.close();
      
      LoggingService.info('Background server connection verified on $address:$port', tag: 'BackgroundMain');
    }
  } catch (e) {
    LoggingService.warning('Background server connection verification failed: $e - Attempting restart', tag: 'BackgroundMain');
    // If connection verification fails, try to restart the server
    await _stopBackgroundServer();
    await Future.delayed(const Duration(seconds: 2));
    await _startBackgroundServer();
  }
}

Future<void> _stopBackgroundServer() async {
  try {
    if (_backgroundHttpService != null) {
      await _backgroundHttpService!.stopServer();
      _backgroundHttpService = null;
      LoggingService.info('Background HTTP server stopped', tag: 'BackgroundMain');
    }
    
    if (_backgroundSmsService != null) {
      _backgroundSmsService!.dispose();
      _backgroundSmsService = null;
    }
    
    // Update service notification
    FlutterBackgroundService().invoke("updateNotification", {
      "title": "SMS Gateway",
      "content": "Service stopped"
    });
    
  } catch (e, stackTrace) {
    LoggingService.error('Error stopping background server', tag: 'BackgroundMain', error: e, stackTrace: stackTrace);
  }
}

Future<void> _sendSMSFromBackground(String recipient, String message, String messageId) async {
  try {
    LoggingService.info('Sending SMS from background: $recipient', tag: 'BackgroundMain');
    
    if (_backgroundSmsService == null) {
      // Initialize SMS service if not already done
      _backgroundSmsService = SmsService();
      try {
        await _backgroundSmsService!.initialize();
      } catch (e) {
        LoggingService.warning('SMS service initialization failed: $e', tag: 'BackgroundMain');
      }
    }
    
    // Use the SMS service directly for background SMS sending
    if (_backgroundSmsService != null) {
      await _backgroundSmsService!.sendSms(
        recipient: recipient,
        message: message,
        simSlot: 0, // Default SIM slot
      );
      LoggingService.info('SMS sent successfully from background via SmsService', tag: 'BackgroundMain');
    } else {
      throw Exception('SMS service not available');
    }
    
  } catch (e, stackTrace) {
    LoggingService.error('Error sending SMS from background', tag: 'BackgroundMain', error: e, stackTrace: stackTrace);
  }
}

void _runBackgroundService() {
  Timer.periodic(const Duration(seconds: 30), (timer) {
    // Keep the service alive and perform periodic tasks
    FlutterBackgroundService().invoke("setAsForeground");
    
    // Check if server is still running
    if (_backgroundHttpService != null && _backgroundHttpService!.isRunning) {
      LoggingService.info('Background service heartbeat - Server active on ${_backgroundHttpService!.serverAddress}:${_backgroundHttpService!.serverPort}', tag: 'BackgroundMain');
      
      // Periodic connectivity verification for better reliability
      _verifyServerConnection();
    } else {
      LoggingService.warning('Background HTTP server not running, attempting restart...', tag: 'BackgroundMain');
      _startBackgroundServer();
    }
  });
}

Future<void> _storeReceivedSms(Map<String, dynamic> smsData) async {
  try {
    final sender = smsData['sender'] as String;
    final message = smsData['message'] as String;
    final timestamp = smsData['timestamp'] as int;
    final simSlot = smsData['simSlot'] as int;
    
    LoggingService.info('Storing received SMS from $sender', tag: 'BackgroundMain');
    
    // Initialize database service if not already done
    final dbService = DatabaseService();
    await dbService.initialize();
    
    // Store the received SMS
    await dbService.insertReceivedSms(
      sender: sender,
      messageContent: message,
      simSlot: simSlot,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      isMultipart: message.length > 160,
      multipartCount: message.length > 160 ? (message.length / 160).ceil() : 1,
    );
    
    LoggingService.info('Received SMS stored successfully from $sender', tag: 'BackgroundMain');
    
  } catch (e, stackTrace) {
    LoggingService.error('Error storing received SMS', tag: 'BackgroundMain', error: e, stackTrace: stackTrace);
  }
}