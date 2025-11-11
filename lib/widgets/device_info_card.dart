import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class DeviceInfoCard extends StatelessWidget {
  const DeviceInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        final deviceInfo = provider.deviceInfo;
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Device Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (deviceInfo != null) ...[
                  _buildInfoRow('Device ID', deviceInfo.deviceId),
                  _buildInfoRow('Device Name', deviceInfo.deviceName),
                  _buildInfoRow('Device Model', deviceInfo.deviceModel),
                  _buildInfoRow('OS Version', deviceInfo.osVersion),
                  _buildInfoRow('App Version', deviceInfo.appVersion),
                  _buildInfoRow('SIM Cards', '${deviceInfo.simCards.length}'),
                  _buildInfoRow('Server Port', '${deviceInfo.serverPort}'),
                  _buildInfoRow('Last Updated', _formatDateTime(deviceInfo.lastUpdated)),
                ] else ...[
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}