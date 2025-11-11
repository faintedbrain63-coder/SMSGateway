import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/received_sms.dart';
import '../services/database_service.dart';

class ReceivedSmsPage extends StatefulWidget {
  const ReceivedSmsPage({super.key});

  @override
  State<ReceivedSmsPage> createState() => _ReceivedSmsPageState();
}

class _ReceivedSmsPageState extends State<ReceivedSmsPage> {
  final DatabaseService _databaseService = DatabaseService();
  List<ReceivedSms> _receivedMessages = [];
  bool _isLoading = true;
  String? _selectedSender;
  bool _showUnreadOnly = false;
  int _totalCount = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadReceivedMessages();
    _loadStatistics();
  }

  Future<void> _loadReceivedMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await _databaseService.getReceivedSms(
        limit: 100,
        offset: 0,
        sender: _selectedSender,
        unreadOnly: _showUnreadOnly,
      );
      
      setState(() {
        _receivedMessages = messages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final totalCount = await _databaseService.getReceivedSmsCount();
      final unreadCount = await _databaseService.getUnreadReceivedSmsCount();
      
      setState(() {
        _totalCount = totalCount;
        _unreadCount = unreadCount;
      });
    } catch (e) {
      // Handle error silently for statistics
    }
  }

  Future<void> _markAsRead(ReceivedSms message) async {
    try {
      final success = await _databaseService.markReceivedSmsAsRead(message.id!);
      if (success) {
        await _loadReceivedMessages();
        await _loadStatistics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking message as read: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _databaseService.markAllReceivedSmsAsRead();
      await _loadReceivedMessages();
      await _loadStatistics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All messages marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking all messages as read: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(ReceivedSms message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _databaseService.deleteReceivedSms(message.id!);
        if (success) {
          await _loadReceivedMessages();
          await _loadStatistics();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting message: $e')),
          );
        }
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Received SMS'),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') {
                _loadReceivedMessages();
                _loadStatistics();
              } else if (value == 'clear_filter') {
                setState(() {
                  _selectedSender = null;
                  _showUnreadOnly = false;
                });
                _loadReceivedMessages();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_filter',
                child: Row(
                  children: [
                    Icon(Icons.clear),
                    SizedBox(width: 8),
                    Text('Clear Filters'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$_totalCount',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Text('Total'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$_unreadCount',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: _unreadCount > 0 ? Colors.orange : null,
                        ),
                      ),
                      const Text('Unread'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: Text(_showUnreadOnly ? 'Unread Only' : 'All Messages'),
                    selected: _showUnreadOnly,
                    onSelected: (selected) {
                      setState(() {
                        _showUnreadOnly = selected;
                      });
                      _loadReceivedMessages();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedSender != null)
                  Chip(
                    label: Text('From: $_selectedSender'),
                    onDeleted: () {
                      setState(() {
                        _selectedSender = null;
                      });
                      _loadReceivedMessages();
                    },
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _receivedMessages.isEmpty
                    ? const Center(
                        child: Text(
                          'No received messages',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadReceivedMessages();
                          await _loadStatistics();
                        },
                        child: ListView.builder(
                          itemCount: _receivedMessages.length,
                          itemBuilder: (context, index) {
                            final message = _receivedMessages[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: message.isRead 
                                      ? Colors.grey 
                                      : Theme.of(context).primaryColor,
                                  child: Text(
                                    message.sender.isNotEmpty 
                                        ? message.sender[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        message.sender,
                                        style: TextStyle(
                                          fontWeight: message.isRead 
                                              ? FontWeight.normal 
                                              : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (message.isMultipart)
                                      const Icon(
                                        Icons.merge_type,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDateTime(message.receivedAt),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.messageContent,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: message.isRead 
                                            ? FontWeight.normal 
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.sim_card,
                                          size: 12,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'SIM ${message.simSlot}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (message.isMultipart) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '${message.multipartCount} parts',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'copy':
                                        _copyToClipboard(message.messageContent);
                                        break;
                                      case 'copy_sender':
                                        _copyToClipboard(message.sender);
                                        break;
                                      case 'filter_sender':
                                        setState(() {
                                          _selectedSender = message.sender;
                                        });
                                        _loadReceivedMessages();
                                        break;
                                      case 'mark_read':
                                        if (!message.isRead) {
                                          _markAsRead(message);
                                        }
                                        break;
                                      case 'delete':
                                        _deleteMessage(message);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'copy',
                                      child: Row(
                                        children: [
                                          Icon(Icons.copy),
                                          SizedBox(width: 8),
                                          Text('Copy Message'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'copy_sender',
                                      child: Row(
                                        children: [
                                          Icon(Icons.copy),
                                          SizedBox(width: 8),
                                          Text('Copy Sender'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'filter_sender',
                                      child: Row(
                                        children: [
                                          Icon(Icons.filter_alt),
                                          SizedBox(width: 8),
                                          Text('Filter by Sender'),
                                        ],
                                      ),
                                    ),
                                    if (!message.isRead)
                                      const PopupMenuItem(
                                        value: 'mark_read',
                                        child: Row(
                                          children: [
                                            Icon(Icons.mark_email_read),
                                            SizedBox(width: 8),
                                            Text('Mark as Read'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  if (!message.isRead) {
                                    _markAsRead(message);
                                  }
                                  _showMessageDetails(message);
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showMessageDetails(ReceivedSms message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('From: ${message.sender}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Received: ${_formatDateTime(message.receivedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'SIM Slot: ${message.simSlot}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (message.isMultipart) ...[
                const SizedBox(height: 4),
                Text(
                  'Multipart: ${message.multipartCount} parts',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Message:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(message.messageContent),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyToClipboard(message.messageContent),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today - show time
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Older - show date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}