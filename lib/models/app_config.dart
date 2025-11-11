class AppConfig {
  static const Map<String, String> defaultValues = {
    'server_host': '0.0.0.0',
    'server_port': '8080',
    'auto_start_server': 'true',
    'max_retry_attempts': '3',
    'retry_delay_seconds': '30',
    'enable_delivery_reports': 'true',
    'enable_request_logging': 'true',
    'log_retention_days': '30',
    'rate_limit_per_minute': '60',
    'enable_authentication': 'true',
    'default_sim_slot': '0',
    'enable_background_service': 'true',
    'retry_failed_messages': 'true',
    'rate_limit_enabled': 'true',
    'rate_limit_requests': '100',
    'rate_limit_window': '60',
    'log_requests': 'true',
    'allowed_ips': '',
    'message_queue_size': '100',
    'delivery_reports': 'true',
  };

  // Server configuration keys
  static const String serverHost = 'server_host';
  static const String serverPort = 'server_port';
  static const String autoStartServer = 'auto_start_server';
  
  // SMS configuration keys
  static const String defaultSimSlot = 'default_sim_slot';
  static const String retryFailedMessages = 'retry_failed_messages';
  static const String maxRetryAttempts = 'max_retry_attempts';
  static const String retryDelay = 'retry_delay_seconds';
  static const String messageQueueSize = 'message_queue_size';
  static const String deliveryReports = 'delivery_reports';
  
  // Security configuration keys
  static const String rateLimitEnabled = 'rate_limit_enabled';
  static const String rateLimitRequests = 'rate_limit_requests';
  static const String rateLimitWindow = 'rate_limit_window';
  static const String logRequests = 'log_requests';
  static const String allowedIps = 'allowed_ips';
  
  // Background service
  static const String enableBackgroundService = 'enable_background_service';
}