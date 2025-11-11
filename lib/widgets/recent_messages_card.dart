import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/app_state_provider.dart';
import '../models/sms_message.dart';
import '../services/sms_service.dart';

class RecentMessagesCard extends StatefulWidget {
  const RecentMessagesCard({super.key});

  @override
  State<RecentMessagesCard> createState() => _RecentMessagesCardState();
}

class _RecentMessagesCardState extends State<RecentMessagesCard> {
  final SmsService _smsService = SmsService();
  StreamSubscription<SmsMessage>? _messageStreamSubscription;

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
  }

  @override
  void dispose() {
    _messageStreamSubscription?.cancel();
    super.dispose();
  }

  void _setupMessageListener() {
    // Listen to real-time message updates and refresh recent messages
    _messageStreamSubscription = _smsService.messageStatusStream.listen((updatedMessage) {
      if (mounted) {
        // Refresh recent messages when a new message is sent or updated
        context.read<AppStateProvider>().refreshRecentMessages();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Messages',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to message logs page
                        DefaultTabController.of(context).animateTo(1);
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (provider.recentMessages.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No recent messages',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.recentMessages.length > 5 
                        ? 5 
                        : provider.recentMessages.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final message = provider.recentMessages[index];
                      return _buildMessageTile(context, message);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageTile(BuildContext context, SmsMessage message) {
    Color statusColor;
    IconData statusIcon;
    
    switch (message.status) {
      case MessageStatus.sent:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case MessageStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case MessageStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case MessageStatus.delivered:
        statusColor = Colors.blue;
        statusIcon = Icons.done_all;
        break;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.1),
        child: Icon(
          statusIcon,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Text(
        message.phoneNumber,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.message.length > 50
                ? '${message.message.substring(0, 50)}...'
                : message.message,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _formatDateTime(message.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          message.status.toString().split('.').last.toUpperCase(),
          style: TextStyle(
            color: statusColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}