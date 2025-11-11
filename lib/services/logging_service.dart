import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class LoggingService {
  static const String _defaultTag = 'SmsGateway';
  
  /// Log info message
  static void info(String message, {String? tag, Object? data}) {
    _log('INFO', message, tag: tag, data: data);
  }
  
  /// Log warning message
  static void warning(String message, {String? tag, Object? data}) {
    _log('WARNING', message, tag: tag, data: data);
  }
  
  /// Log error message
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, tag: tag, data: error);
    if (stackTrace != null && kDebugMode) {
      developer.log(
        stackTrace.toString(),
        name: tag ?? _defaultTag,
        level: 1000, // Error level
      );
    }
  }
  
  /// Log debug message (only in debug mode)
  static void debug(String message, {String? tag, Object? data}) {
    if (kDebugMode) {
      _log('DEBUG', message, tag: tag, data: data);
    }
  }
  
  /// Internal logging method
  static void _log(String level, String message, {String? tag, Object? data}) {
    final timestamp = DateTime.now().toIso8601String();
    final logTag = tag ?? _defaultTag;
    final logMessage = '[$timestamp] [$level] [$logTag] $message';
    
    if (kDebugMode) {
      developer.log(
        logMessage,
        name: logTag,
        time: DateTime.now(),
      );
      
      if (data != null) {
        developer.log(
          'Data: $data',
          name: logTag,
          time: DateTime.now(),
        );
      }
    }
    
    // In production, you might want to send logs to a remote service
    // or save them to local storage for debugging purposes
  }
}