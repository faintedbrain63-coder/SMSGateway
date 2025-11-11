import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/api_key.dart';
import '../services/api_key_service.dart';

class ApiKeysPage extends StatefulWidget {
  const ApiKeysPage({super.key});

  @override
  State<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends State<ApiKeysPage> {
  final ApiKeyService _apiKeyService = ApiKeyService();
  List<ApiKey> _apiKeys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  Future<void> _loadApiKeys() async {
    setState(() => _isLoading = true);
    try {
      final apiKeys = await _apiKeyService.getAllApiKeys();
      setState(() {
        _apiKeys = apiKeys;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading API keys: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createApiKey() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CreateApiKeyDialog(),
    );

    if (result != null) {
      try {
        final apiKey = await _apiKeyService.createApiKey(
          name: result['name'],
          rateLimit: result['rateLimit'],
          expiresAt: result['expiresAt'],
        );

        if (mounted) {
          // Show the generated API key
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _ApiKeyGeneratedDialog(apiKey: apiKey),
          );
          
          await _loadApiKeys();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating API key: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _regenerateApiKey(ApiKey apiKey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate API Key'),
        content: Text(
          'Are you sure you want to regenerate the API key "${apiKey.name}"? The old key will no longer work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final newApiKey = await _apiKeyService.regenerateApiKey(apiKey.id);
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _ApiKeyGeneratedDialog(
              apiKey: newApiKey!,
              isRegenerated: true,
            ),
          );
          await _loadApiKeys();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error regenerating API key: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleApiKey(ApiKey apiKey) async {
    try {
      await _apiKeyService.updateApiKey(
        id: apiKey.id,
        isActive: !apiKey.isActive,
      );
      await _loadApiKeys();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'API key ${apiKey.isActive ? 'disabled' : 'enabled'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating API key: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteApiKey(ApiKey apiKey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete API Key'),
        content: Text(
          'Are you sure you want to delete the API key "${apiKey.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiKeyService.deleteApiKey(apiKey.id);
        await _loadApiKeys();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API key deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting API key: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
        actions: [
          IconButton(
            onPressed: _loadApiKeys,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _apiKeys.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.vpn_key_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No API keys yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first API key to start using the SMS Gateway',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _createApiKey,
                        icon: const Icon(Icons.add),
                        label: const Text('Create API Key'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadApiKeys,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _apiKeys.length,
                    itemBuilder: (context, index) {
                      final apiKey = _apiKeys[index];
                      return _buildApiKeyCard(apiKey);
                    },
                  ),
                ),
      floatingActionButton: _apiKeys.isNotEmpty
          ? FloatingActionButton(
              onPressed: _createApiKey,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildApiKeyCard(ApiKey apiKey) {
    final isExpired = apiKey.isExpired;
    final isValid = apiKey.isValid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apiKey.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created: ${_formatDateTime(apiKey.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(isValid, isExpired, apiKey.isActive),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Usage Count',
                    apiKey.usageCount.toString(),
                    Icons.analytics,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Rate Limit',
                    apiKey.rateLimit.toString(),
                    Icons.speed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (apiKey.expiresAt != null)
              _buildInfoItem(
                'Expires',
                _formatDateTime(apiKey.expiresAt!),
                Icons.schedule,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _regenerateApiKey(apiKey),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Regenerate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleApiKey(apiKey),
                    icon: Icon(
                      apiKey.isActive ? Icons.pause : Icons.play_arrow,
                      size: 16,
                    ),
                    label: Text(apiKey.isActive ? 'Disable' : 'Enable'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: apiKey.isActive ? Colors.red : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteApiKey(apiKey),
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isValid, bool isExpired, bool isActive) {
    String label;
    Color color;

    if (!isActive) {
      label = 'Disabled';
      color = Colors.grey;
    } else if (isExpired) {
      label = 'Expired';
      color = Colors.red;
    } else if (isValid) {
      label = 'Active';
      color = Colors.green;
    } else {
      label = 'Invalid';
      color = Colors.orange;
    }

    return Chip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class _CreateApiKeyDialog extends StatefulWidget {
  const _CreateApiKeyDialog();

  @override
  State<_CreateApiKeyDialog> createState() => _CreateApiKeyDialogState();
}

class _CreateApiKeyDialogState extends State<_CreateApiKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rateLimitController = TextEditingController();
  DateTime? _expiresAt;
  bool _hasRateLimit = false;
  bool _hasExpiration = false;

  @override
  void dispose() {
    _nameController.dispose();
    _rateLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create API Key'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'My API Key',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Set rate limit'),
              value: _hasRateLimit,
              onChanged: (value) {
                setState(() => _hasRateLimit = value ?? false);
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_hasRateLimit) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _rateLimitController,
                decoration: const InputDecoration(
                  labelText: 'Rate limit (requests per hour)',
                  hintText: '100',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (_hasRateLimit && (value == null || value.isEmpty)) {
                    return 'Please enter rate limit';
                  }
                  if (_hasRateLimit) {
                    final limit = int.tryParse(value!);
                    if (limit == null || limit < 1) {
                      return 'Please enter a valid rate limit';
                    }
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Set expiration date'),
              value: _hasExpiration,
              onChanged: (value) {
                setState(() => _hasExpiration = value ?? false);
                if (!_hasExpiration) {
                  _expiresAt = null;
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_hasExpiration) ...[
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                  _expiresAt != null
                      ? 'Expires: ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                      : 'Select expiration date',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _expiresAt = date);
                  }
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              if (_hasExpiration && _expiresAt == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select an expiration date'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(context).pop({
                'name': _nameController.text.trim(),
                'rateLimit': _hasRateLimit ? int.parse(_rateLimitController.text) : null,
                'expiresAt': _expiresAt,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _ApiKeyGeneratedDialog extends StatelessWidget {
  final Map<String, dynamic> apiKey;
  final bool isRegenerated;

  const _ApiKeyGeneratedDialog({
    required this.apiKey,
    this.isRegenerated = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isRegenerated ? 'API Key Regenerated' : 'API Key Created'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRegenerated
                ? 'Your API key has been regenerated successfully. Please copy and save it securely.'
                : 'Your API key has been created successfully. Please copy and save it securely.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'API Key:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    apiKey['api_key'], // This is the actual key from the service
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: apiKey['api_key']));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('API key copied to clipboard'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy to clipboard',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is the only time you will see this key. Make sure to copy it now.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}