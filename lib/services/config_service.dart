import '../models/device_config.dart';
import 'database_service.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final DatabaseService _databaseService = DatabaseService();

  /// Get configuration value
  Future<String> getConfig(String key, {String? defaultValue}) async {
    final value = await _databaseService.getConfig(key);
    return value ?? defaultValue ?? AppConfig.getDefaultValue(key);
  }

  /// Set configuration value
  Future<void> setConfig(String key, String value) async {
    await _databaseService.setConfig(key, value);
  }

  /// Get all configuration values
  Future<Map<String, String>> getAllConfigs() async {
    final configs = await _databaseService.getAllConfigs();
    final configMap = <String, String>{};
    
    for (final config in configs) {
      configMap[config.key] = config.value;
    }
    
    // Add default values for missing configs
    for (final key in AppConfig.getAllKeys()) {
      if (!configMap.containsKey(key)) {
        configMap[key] = AppConfig.getDefaultValue(key);
      }
    }
    
    return configMap;
  }

  /// Get server configuration
  Future<Map<String, dynamic>> getServerConfig() async {
    return {
      'port': int.tryParse(await getConfig(AppConfig.serverPort)) ?? 8080,
      'host': await getConfig(AppConfig.serverHost),
      'auto_start': await getConfig(AppConfig.autoStartServer) == 'true',
      'enable_https': await getConfig(AppConfig.enableHttps) == 'true',
    };
  }

  /// Update server configuration
  Future<void> updateServerConfig({
    int? port,
    String? host,
    bool? autoStart,
    bool? enableHttps,
  }) async {
    if (port != null) {
      await setConfig(AppConfig.serverPort, port.toString());
    }
    if (host != null) {
      await setConfig(AppConfig.serverHost, host);
    }
    if (autoStart != null) {
      await setConfig(AppConfig.autoStartServer, autoStart.toString());
    }
    if (enableHttps != null) {
      await setConfig(AppConfig.enableHttps, enableHttps.toString());
    }
  }

  /// Get SMS configuration
  Future<Map<String, dynamic>> getSmsConfig() async {
    return {
      'default_sim_slot': int.tryParse(await getConfig(AppConfig.defaultSimSlot)) ?? 0,
      'retry_failed_messages': await getConfig(AppConfig.retryFailedMessages) == 'true',
      'max_retry_attempts': int.tryParse(await getConfig(AppConfig.maxRetryAttempts)) ?? 3,
      'message_queue_size': int.tryParse(await getConfig(AppConfig.messageQueueSize)) ?? 100,
      'delivery_reports': await getConfig(AppConfig.deliveryReports) == 'true',
    };
  }

  /// Update SMS configuration
  Future<void> updateSmsConfig({
    int? defaultSimSlot,
    bool? retryFailedMessages,
    int? maxRetryAttempts,
    int? retryDelay,
    bool? enableRetry,
    int? messageQueueSize,
    bool? deliveryReports,
  }) async {
    if (defaultSimSlot != null) {
      await setConfig(AppConfig.defaultSimSlot, defaultSimSlot.toString());
    }
    if (retryFailedMessages != null) {
      await setConfig(AppConfig.retryFailedMessages, retryFailedMessages.toString());
    }
    if (maxRetryAttempts != null) {
      await setConfig(AppConfig.maxRetryAttempts, maxRetryAttempts.toString());
    }
    if (retryDelay != null) {
      await setConfig('retry_delay_seconds', retryDelay.toString());
    }
    if (enableRetry != null) {
      await setConfig(AppConfig.retryFailedMessages, enableRetry.toString());
    }
    if (messageQueueSize != null) {
      await setConfig(AppConfig.messageQueueSize, messageQueueSize.toString());
    }
    if (deliveryReports != null) {
      await setConfig(AppConfig.deliveryReports, deliveryReports.toString());
    }
  }

  /// Get security configuration
  Future<Map<String, dynamic>> getSecurityConfig() async {
    return {
      'rate_limit_enabled': await getConfig(AppConfig.rateLimitEnabled) == 'true',
      'rate_limit_requests': int.tryParse(await getConfig(AppConfig.rateLimitRequests)) ?? 60,
      'rate_limit_window': int.tryParse(await getConfig(AppConfig.rateLimitWindow)) ?? 60,
      'log_requests': await getConfig(AppConfig.logRequests) == 'true',
      'allowed_ips': await getConfig(AppConfig.allowedIps),
    };
  }

  /// Update security configuration
  Future<void> updateSecurityConfig({
    bool? rateLimitEnabled,
    int? rateLimitRequests,
    int? rateLimitWindow,
    bool? logRequests,
    String? allowedIps,
  }) async {
    if (rateLimitEnabled != null) {
      await setConfig(AppConfig.rateLimitEnabled, rateLimitEnabled.toString());
    }
    if (rateLimitRequests != null) {
      await setConfig(AppConfig.rateLimitRequests, rateLimitRequests.toString());
    }
    if (rateLimitWindow != null) {
      await setConfig(AppConfig.rateLimitWindow, rateLimitWindow.toString());
    }
    if (logRequests != null) {
      await setConfig(AppConfig.logRequests, logRequests.toString());
    }
    if (allowedIps != null) {
      await setConfig(AppConfig.allowedIps, allowedIps);
    }
  }

  /// Get UI configuration
  Future<Map<String, dynamic>> getUiConfig() async {
    return {
      'theme_mode': await getConfig(AppConfig.themeMode),
      'show_notifications': await getConfig(AppConfig.showNotifications) == 'true',
      'auto_refresh_interval': int.tryParse(await getConfig(AppConfig.autoRefreshInterval)) ?? 30,
      'messages_per_page': int.tryParse(await getConfig(AppConfig.messagesPerPage)) ?? 50,
    };
  }

  /// Update UI configuration
  Future<void> updateUiConfig({
    String? themeMode,
    bool? showNotifications,
    int? autoRefreshInterval,
    int? messagesPerPage,
  }) async {
    if (themeMode != null) {
      await setConfig(AppConfig.themeMode, themeMode);
    }
    if (showNotifications != null) {
      await setConfig(AppConfig.showNotifications, showNotifications.toString());
    }
    if (autoRefreshInterval != null) {
      await setConfig(AppConfig.autoRefreshInterval, autoRefreshInterval.toString());
    }
    if (messagesPerPage != null) {
      await setConfig(AppConfig.messagesPerPage, messagesPerPage.toString());
    }
  }

  /// Reset configuration to defaults
  Future<void> resetToDefaults() async {
    for (final key in AppConfig.getAllKeys()) {
      await setConfig(key, AppConfig.getDefaultValue(key));
    }
  }

  /// Export configuration
  Future<Map<String, String>> exportConfig() async {
    return await getAllConfigs();
  }

  /// Import configuration
  Future<void> importConfig(Map<String, String> configs) async {
    for (final entry in configs.entries) {
      if (AppConfig.getAllKeys().contains(entry.key)) {
        await setConfig(entry.key, entry.value);
      }
    }
  }

  /// Validate configuration values
  Future<List<String>> validateConfig() async {
    final errors = <String>[];
    final configs = await getAllConfigs();

    // Validate server port
    final port = int.tryParse(configs[AppConfig.serverPort] ?? '');
    if (port == null || port < 1024 || port > 65535) {
      errors.add('Server port must be between 1024 and 65535');
    }

    // Validate SIM slot
    final simSlot = int.tryParse(configs[AppConfig.defaultSimSlot] ?? '');
    if (simSlot == null || simSlot < 0 || simSlot > 1) {
      errors.add('Default SIM slot must be 0 or 1');
    }

    // Validate retry attempts
    final retryAttempts = int.tryParse(configs[AppConfig.maxRetryAttempts] ?? '');
    if (retryAttempts == null || retryAttempts < 0 || retryAttempts > 10) {
      errors.add('Max retry attempts must be between 0 and 10');
    }

    // Validate queue size
    final queueSize = int.tryParse(configs[AppConfig.messageQueueSize] ?? '');
    if (queueSize == null || queueSize < 10 || queueSize > 1000) {
      errors.add('Message queue size must be between 10 and 1000');
    }

    // Validate rate limit
    final rateLimitRequests = int.tryParse(configs[AppConfig.rateLimitRequests] ?? '');
    if (rateLimitRequests == null || rateLimitRequests < 1 || rateLimitRequests > 1000) {
      errors.add('Rate limit requests must be between 1 and 1000');
    }

    final rateLimitWindow = int.tryParse(configs[AppConfig.rateLimitWindow] ?? '');
    if (rateLimitWindow == null || rateLimitWindow < 1 || rateLimitWindow > 3600) {
      errors.add('Rate limit window must be between 1 and 3600 seconds');
    }

    // Validate refresh interval
    final refreshInterval = int.tryParse(configs[AppConfig.autoRefreshInterval] ?? '');
    if (refreshInterval == null || refreshInterval < 5 || refreshInterval > 300) {
      errors.add('Auto refresh interval must be between 5 and 300 seconds');
    }

    // Validate messages per page
    final messagesPerPage = int.tryParse(configs[AppConfig.messagesPerPage] ?? '');
    if (messagesPerPage == null || messagesPerPage < 10 || messagesPerPage > 200) {
      errors.add('Messages per page must be between 10 and 200');
    }

    return errors;
  }

  /// Get configuration summary for display
  Future<Map<String, dynamic>> getConfigSummary() async {
    final serverConfig = await getServerConfig();
    final smsConfig = await getSmsConfig();
    final securityConfig = await getSecurityConfig();

    return {
      'server': {
        'status': 'Server running on ${serverConfig['host']}:${serverConfig['port']}',
        'auto_start': serverConfig['auto_start'] ? 'Enabled' : 'Disabled',
        'https': serverConfig['enable_https'] ? 'Enabled' : 'Disabled',
      },
      'sms': {
        'default_sim': 'SIM ${smsConfig['default_sim_slot'] + 1}',
        'retry_enabled': smsConfig['retry_failed_messages'] ? 'Yes' : 'No',
        'max_retries': smsConfig['max_retry_attempts'].toString(),
        'queue_size': smsConfig['message_queue_size'].toString(),
      },
      'security': {
        'rate_limiting': securityConfig['rate_limit_enabled'] ? 'Enabled' : 'Disabled',
        'request_logging': securityConfig['log_requests'] ? 'Enabled' : 'Disabled',
        'ip_restrictions': securityConfig['allowed_ips'].isNotEmpty ? 'Active' : 'None',
      },
    };
  }
}