class ReceivedSms {
  final String id;
  final String sender;
  final String messageContent;
  final int simSlot;
  final DateTime receivedAt;
  final bool isRead;
  final bool isMultipart;
  final int multipartCount;
  final DateTime createdAt;

  ReceivedSms({
    required this.id,
    required this.sender,
    required this.messageContent,
    required this.simSlot,
    required this.receivedAt,
    required this.isRead,
    required this.isMultipart,
    required this.multipartCount,
    required this.createdAt,
  });

  factory ReceivedSms.fromMap(Map<String, dynamic> map) {
    return ReceivedSms(
      id: map['id'] as String,
      sender: map['sender'] as String,
      messageContent: map['message_content'] as String,
      simSlot: map['sim_slot'] as int,
      receivedAt: DateTime.parse(map['received_at'] as String),
      isRead: (map['is_read'] as int) == 1,
      isMultipart: (map['is_multipart'] as int) == 1,
      multipartCount: map['multipart_count'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'message_content': messageContent,
      'sim_slot': simSlot,
      'received_at': receivedAt.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'is_multipart': isMultipart ? 1 : 0,
      'multipart_count': multipartCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ReceivedSms copyWith({
    String? id,
    String? sender,
    String? messageContent,
    int? simSlot,
    DateTime? receivedAt,
    bool? isRead,
    bool? isMultipart,
    int? multipartCount,
    DateTime? createdAt,
  }) {
    return ReceivedSms(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      messageContent: messageContent ?? this.messageContent,
      simSlot: simSlot ?? this.simSlot,
      receivedAt: receivedAt ?? this.receivedAt,
      isRead: isRead ?? this.isRead,
      isMultipart: isMultipart ?? this.isMultipart,
      multipartCount: multipartCount ?? this.multipartCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ReceivedSms(id: $id, sender: $sender, messageContent: $messageContent, simSlot: $simSlot, receivedAt: $receivedAt, isRead: $isRead, isMultipart: $isMultipart, multipartCount: $multipartCount, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceivedSms && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}