class DeviceConfig {
  final String key;
  final String value;
  final DateTime updatedAt;

  DeviceConfig({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DeviceConfig.fromMap(Map<String, dynamic> map) {
    return DeviceConfig(
      key: map['key'],
      value: map['value'],
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}

class AppConfig {
  static const String serverPort = 'server_port';
  static const String defaultSimSlot = 'default_sim_slot';
  static const String rateLimitPerMinute = 'rate_limit_per_minute';
  static const String autoStartServer = 'auto_start_server';
  static const String requireApiKey = 'require_api_key';
  static const String maxMessageLength = 'max_message_length';
  static const String retryFailedMessages = 'retry_failed_messages';
  static const String maxRetryAttempts = 'max_retry_attempts';
  static const String appVersion = 'app_version';
  static const String lastServerStart = 'last_server_start';
  static const String totalMessagesSent = 'total_messages_sent';
  static const String serverAutoStart = 'server_auto_start';
  static const String serverHost = 'server_host';
  static const String enableHttps = 'enable_https';
  static const String rateLimitWindow = 'rate_limit_window';
  static const String autoRefreshInterval = 'auto_refresh_interval';
  static const String messagesPerPage = 'messages_per_page';
  static const String logRequests = 'log_requests';
  static const String allowedIps = 'allowed_ips';
  static const String themeMode = 'theme_mode';
  static const String showNotifications = 'show_notifications';
  static const String messageQueueSize = 'message_queue_size';
  static const String rateLimitRequests = 'rate_limit_requests';
  static const String deliveryReports = 'delivery_reports';
  static const String rateLimitEnabled = 'rate_limit_enabled';

  static const Map<String, String> defaultValues = {
    serverPort: '8080',
    serverHost: '0.0.0.0',
    enableHttps: 'false',
    defaultSimSlot: '0',
    rateLimitPerMinute: '60',
    rateLimitWindow: '60',
    autoStartServer: 'true',
    autoRefreshInterval: '30',
    messagesPerPage: '50',
    requireApiKey: 'true',
    maxMessageLength: '160',
    retryFailedMessages: 'true',
    logRequests: 'true',
    allowedIps: '',
    themeMode: 'system',
    showNotifications: 'true',
    messageQueueSize: '100',
    rateLimitRequests: '60',
    deliveryReports: 'true',
    rateLimitEnabled: 'true',
    maxRetryAttempts: '3',
    appVersion: '1.0.0',
    lastServerStart: '',
    totalMessagesSent: '0',
    serverAutoStart: 'false',
  };

  static String getDefaultValue(String key) {
    return defaultValues[key] ?? '';
  }

  static List<String> getAllKeys() {
    return defaultValues.keys.toList();
  }
}