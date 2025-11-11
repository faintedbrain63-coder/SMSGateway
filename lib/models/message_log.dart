import 'sms_message.dart';

class MessageLog {
  final String id;
  final String messageId;
  final MessageStatus status;
  final DateTime timestamp;
  final String? details;

  MessageLog({
    required this.id,
    required this.messageId,
    required this.status,
    required this.timestamp,
    this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message_id': messageId,
      'status': status.value,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }

  factory MessageLog.fromMap(Map<String, dynamic> map) {
    return MessageLog(
      id: map['id'],
      messageId: map['message_id'],
      status: MessageStatusExtension.fromString(map['status']),
      timestamp: DateTime.parse(map['timestamp']),
      details: map['details'],
    );
  }
}