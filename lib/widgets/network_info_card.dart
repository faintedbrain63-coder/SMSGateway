import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class NetworkInfoCard extends StatefulWidget {
  const NetworkInfoCard({super.key});

  @override
  State<NetworkInfoCard> createState() => _NetworkInfoCardState();
}

class _NetworkInfoCardState extends State<NetworkInfoCard> {
  Map<String, dynamic>? _networkInfo;
  List<Map<String, dynamic>>? _networkInterfaces;
  Map<String, dynamic>? _connectionInstructions;
  bool _isLoading = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
  }

  Future<void> _loadNetworkInfo() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final appState = context.read<AppStateProvider>();
      final networkInfo = await appState.getNetworkInfo();
      final interfaces = await appState.getNetworkInterfaces();
      final instructions = await appState.getConnectionInstructions();

      if (mounted) {
        setState(() {
          _networkInfo = networkInfo;
          _networkInterfaces = interfaces;
          _connectionInstructions = instructions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load network info: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text(
          'Network Information',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: _networkInfo != null
            ? Text('WiFi: ${_networkInfo!['wifi_name']} • IP: ${_networkInfo!['wifi_ip']}')
            : const Text('Loading network information...'),
        leading: Icon(
          _networkInfo?['is_connected'] == true 
              ? Icons.wifi 
              : Icons.wifi_off,
          color: _networkInfo?['is_connected'] == true 
              ? Colors.green 
              : Colors.red,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _loadNetworkInfo,
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_networkInfo != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // WiFi Information
                  _buildInfoSection('WiFi Information', [
                    _buildInfoRow('Network Name', _networkInfo!['wifi_name']),
                    _buildInfoRow('IP Address', _networkInfo!['wifi_ip'], copyable: true),
                    _buildInfoRow('Gateway', _networkInfo!['gateway_ip']),
                    _buildInfoRow('Subnet Mask', _networkInfo!['subnet_mask']),
                    _buildInfoRow('BSSID', _networkInfo!['wifi_bssid']),
                  ]),
                  
                  const SizedBox(height: 16),
                  
                  // Connection Instructions
                  if (_connectionInstructions != null) ...[
                    _buildInfoSection('Connection Details', [
                      _buildInfoRow('Server URL', _connectionInstructions!['server_url'], copyable: true),
                      _buildInfoRow('API Key', _connectionInstructions!['api_key'], copyable: true),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    // Example cURL command
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.terminal, size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                'Example cURL Command',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                onPressed: () => _copyToClipboard(
                                  _connectionInstructions!['example_curl'],
                                  'cURL command',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _connectionInstructions!['example_curl'],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Network Interfaces
                  if (_networkInterfaces != null && _networkInterfaces!.isNotEmpty) ...[
                    _buildInfoSection('Network Interfaces', 
                      _networkInterfaces!.map((interface) {
                        final addresses = interface['addresses'] as List;
                        final addressText = addresses
                            .map((addr) => addr['address'])
                            .join(', ');
                        return _buildInfoRow(interface['name'], addressText);
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Failed to load network information'),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String? value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Unknown',
              style: TextStyle(
                color: value != null ? null : Colors.grey,
              ),
            ),
          ),
          if (copyable && value != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () => _copyToClipboard(value, label),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}