import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/config_service.dart';
import '../services/background_service.dart';
import '../models/app_config.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  final ConfigService _configService = ConfigService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  final _serverPortController = TextEditingController();
  final _serverHostController = TextEditingController();
  final _maxRetryAttemptsController = TextEditingController();
  final _retryDelayController = TextEditingController();
  final _rateLimitController = TextEditingController();
  final _rateLimitWindowController = TextEditingController();
  final _logRetentionController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _autoStartServer = false;
  bool _enableLogging = true;
  bool _enableRateLimit = true;
  bool _enableRetry = true;
  bool _backgroundServiceEnabled = false;
  bool _autoStartOnBoot = false;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  @override
  void dispose() {
    _serverPortController.dispose();
    _serverHostController.dispose();
    _maxRetryAttemptsController.dispose();
    _retryDelayController.dispose();
    _rateLimitController.dispose();
    _rateLimitWindowController.dispose();
    _logRetentionController.dispose();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    setState(() => _isLoading = true);
    try {
      final serverConfig = await _configService.getServerConfig();
      final smsConfig = await _configService.getSmsConfig();
      final securityConfig = await _configService.getSecurityConfig();
      
      // Load background service status
      final backgroundServiceRunning = await BackgroundService.instance.isServiceRunning();
      final autoStartOnBoot = await BackgroundService.instance.getAutoStart();

      setState(() {
        // Server configuration with defaults
        _serverPortController.text = serverConfig['port']?.toString() ?? AppConfig.defaultValues['server_port'] ?? '8080';
        _serverHostController.text = serverConfig['host'] ?? AppConfig.defaultValues['server_host'] ?? '0.0.0.0';
        _autoStartServer = serverConfig['autoStart'] ?? (AppConfig.defaultValues['auto_start_server'] == 'true');
        
        // Background service configuration
        _backgroundServiceEnabled = backgroundServiceRunning;
        _autoStartOnBoot = autoStartOnBoot;
        
        // SMS configuration with defaults
        _maxRetryAttemptsController.text = smsConfig['maxRetryAttempts']?.toString() ?? AppConfig.defaultValues['max_retry_attempts'] ?? '3';
        _retryDelayController.text = smsConfig['retryDelay']?.toString() ?? AppConfig.defaultValues['retry_delay_seconds'] ?? '30';
        _enableRetry = smsConfig['enableRetry'] ?? (AppConfig.defaultValues['retry_failed_messages'] == 'true');
        
        // Security configuration with defaults
        _rateLimitController.text = securityConfig['rateLimit']?.toString() ?? AppConfig.defaultValues['rate_limit_requests'] ?? '100';
        _rateLimitWindowController.text = securityConfig['rateLimitWindow']?.toString() ?? AppConfig.defaultValues['rate_limit_window'] ?? '60';
        _logRetentionController.text = securityConfig['logRetentionDays']?.toString() ?? AppConfig.defaultValues['log_retention_days'] ?? '30';
        _enableRateLimit = securityConfig['enableRateLimit'] ?? (AppConfig.defaultValues['rate_limit_enabled'] == 'true');
        _enableLogging = securityConfig['enableLogging'] ?? (AppConfig.defaultValues['log_requests'] == 'true');
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // Update server configuration
      await _configService.updateServerConfig(
        port: int.parse(_serverPortController.text),
        host: _serverHostController.text,
        autoStart: _autoStartServer,
      );

      // Update SMS configuration
      await _configService.updateSmsConfig(
        maxRetryAttempts: int.parse(_maxRetryAttemptsController.text),
        retryDelay: int.parse(_retryDelayController.text),
        enableRetry: _enableRetry,
      );

      // Update security configuration
      await _configService.updateSecurityConfig(
        rateLimitRequests: int.parse(_rateLimitController.text),
        rateLimitWindow: int.parse(_rateLimitWindowController.text),
        logRequests: true,
        rateLimitEnabled: _enableRateLimit,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Configuration'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _configService.resetToDefaults();
        await _loadConfiguration();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuration reset to defaults'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting configuration: $e'),
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
        title: const Text('Configuration'),
        actions: [
          IconButton(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to defaults',
          ),
          IconButton(
            onPressed: _loadConfiguration,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildServerSection(),
                  const SizedBox(height: 24),
                  _buildSmsSection(),
                  const SizedBox(height: 24),
                  _buildSecuritySection(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildServerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dns,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Server Configuration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serverHostController,
              decoration: const InputDecoration(
                labelText: 'Server Host',
                hintText: '0.0.0.0',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter server host';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serverPortController,
              decoration: const InputDecoration(
                labelText: 'Server Port',
                hintText: '8080',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter server port';
                }
                final port = int.tryParse(value);
                if (port == null || port < 1 || port > 65535) {
                  return 'Please enter a valid port (1-65535)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto-start server'),
              subtitle: const Text('Start server automatically when app launches'),
              value: _autoStartServer,
              onChanged: (value) {
                setState(() => _autoStartServer = value);
              },
            ),
            const Divider(),
            // Background Service Section
            Text(
              'Background Service',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Background Service'),
              subtitle: Text(_backgroundServiceEnabled 
                  ? 'Service is running in background' 
                  : 'Service is stopped'),
              value: _backgroundServiceEnabled,
              onChanged: (value) async {
                setState(() => _backgroundServiceEnabled = value);
                try {
                  if (value) {
                    await BackgroundService.instance.startBackgroundService();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Background service started'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    await BackgroundService.instance.stopBackgroundService();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Background service stopped'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  setState(() => _backgroundServiceEnabled = !value);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            SwitchListTile(
              title: const Text('Auto-start on Boot'),
              subtitle: const Text('Start service automatically when device boots'),
              value: _autoStartOnBoot,
              onChanged: (value) async {
                setState(() => _autoStartOnBoot = value);
                try {
                  await BackgroundService.instance.setAutoStart(value);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value 
                            ? 'Auto-start on boot enabled' 
                            : 'Auto-start on boot disabled'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                } catch (e) {
                  setState(() => _autoStartOnBoot = !value);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sms,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'SMS Configuration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable retry mechanism'),
              subtitle: const Text('Automatically retry failed messages'),
              value: _enableRetry,
              onChanged: (value) {
                setState(() => _enableRetry = value);
              },
            ),
            if (_enableRetry) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxRetryAttemptsController,
                decoration: const InputDecoration(
                  labelText: 'Max retry attempts',
                  hintText: '3',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter max retry attempts';
                  }
                  final attempts = int.tryParse(value);
                  if (attempts == null || attempts < 0 || attempts > 10) {
                    return 'Please enter a valid number (0-10)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _retryDelayController,
                decoration: const InputDecoration(
                  labelText: 'Retry delay (seconds)',
                  hintText: '30',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter retry delay';
                  }
                  final delay = int.tryParse(value);
                  if (delay == null || delay < 1 || delay > 3600) {
                    return 'Please enter a valid delay (1-3600 seconds)';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Security Configuration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable rate limiting'),
              subtitle: const Text('Limit requests per time window'),
              value: _enableRateLimit,
              onChanged: (value) {
                setState(() => _enableRateLimit = value);
              },
            ),
            if (_enableRateLimit) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _rateLimitController,
                decoration: const InputDecoration(
                  labelText: 'Rate limit (requests)',
                  hintText: '100',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter rate limit';
                  }
                  final limit = int.tryParse(value);
                  if (limit == null || limit < 1 || limit > 10000) {
                    return 'Please enter a valid limit (1-10000)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rateLimitWindowController,
                decoration: const InputDecoration(
                  labelText: 'Rate limit window (minutes)',
                  hintText: '60',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter rate limit window';
                  }
                  final window = int.tryParse(value);
                  if (window == null || window < 1 || window > 1440) {
                    return 'Please enter a valid window (1-1440 minutes)';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable logging'),
              subtitle: const Text('Log requests and responses'),
              value: _enableLogging,
              onChanged: (value) {
                setState(() => _enableLogging = value);
              },
            ),
            if (_enableLogging) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _logRetentionController,
                decoration: const InputDecoration(
                  labelText: 'Log retention (days)',
                  hintText: '30',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.history),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter log retention days';
                  }
                  final days = int.tryParse(value);
                  if (days == null || days < 1 || days > 365) {
                    return 'Please enter a valid number (1-365 days)';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveConfiguration,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}