class SmsMessage {
  final String id;
  final String recipient;
  final String messageContent;
  final MessageStatus status;
  final int simSlot;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final String? errorMessage;

  // Getters for backward compatibility
  String get content => messageContent;
  String get phoneNumber => recipient;
  String get message => messageContent;

  SmsMessage({
    required this.id,
    required this.recipient,
    required this.messageContent,
    required this.status,
    required this.simSlot,
    required this.createdAt,
    this.sentAt,
    this.deliveredAt,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient': recipient,
      'message_content': messageContent,
      'status': status.value,
      'sim_slot': simSlot,
      'created_at': createdAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'error_message': errorMessage,
    };
  }

  factory SmsMessage.fromMap(Map<String, dynamic> map) {
    return SmsMessage(
      id: map['id'],
      recipient: map['recipient'],
      messageContent: map['message_content'],
      status: MessageStatusExtension.fromString(map['status']),
      simSlot: map['sim_slot'],
      createdAt: DateTime.parse(map['created_at']),
      sentAt: map['sent_at'] != null ? DateTime.parse(map['sent_at']) : null,
      deliveredAt: map['delivered_at'] != null ? DateTime.parse(map['delivered_at']) : null,
      errorMessage: map['error_message'],
    );
  }

  SmsMessage copyWith({
    String? id,
    String? recipient,
    String? messageContent,
    MessageStatus? status,
    int? simSlot,
    DateTime? createdAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
    String? errorMessage,
  }) {
    return SmsMessage(
      id: id ?? this.id,
      recipient: recipient ?? this.recipient,
      messageContent: messageContent ?? this.messageContent,
      status: status ?? this.status,
      simSlot: simSlot ?? this.simSlot,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum MessageStatus {
  pending,
  sent,
  delivered,
  failed,
}

extension MessageStatusExtension on MessageStatus {
  String get value {
    switch (this) {
      case MessageStatus.pending:
        return 'pending';
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.failed:
        return 'failed';
    }
  }

  String get displayName {
    switch (this) {
      case MessageStatus.pending:
        return 'Pending';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.failed:
        return 'Failed';
    }
  }

  static MessageStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return MessageStatus.pending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.pending;
    }
  }
}