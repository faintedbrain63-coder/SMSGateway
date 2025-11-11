class RequestLog {
  final String id;
  final String endpoint;
  final String method;
  final String apiKey;
  final String ipAddress;
  final String userAgent;
  final DateTime timestamp;
  final int responseStatus;

  RequestLog({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.apiKey,
    required this.ipAddress,
    required this.userAgent,
    required this.timestamp,
    required this.responseStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'endpoint': endpoint,
      'method': method,
      'api_key': apiKey,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'timestamp': timestamp.toIso8601String(),
      'response_status': responseStatus,
    };
  }

  factory RequestLog.fromMap(Map<String, dynamic> map) {
    return RequestLog(
      id: map['id'],
      endpoint: map['endpoint'],
      method: map['method'],
      apiKey: map['api_key'],
      ipAddress: map['ip_address'],
      userAgent: map['user_agent'],
      timestamp: DateTime.parse(map['timestamp']),
      responseStatus: map['response_status'],
    );
  }
}