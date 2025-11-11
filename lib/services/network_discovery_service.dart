import 'dart:io';
import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';
import 'logging_service.dart';

/// Service for network discovery and connectivity management
class NetworkDiscoveryService {
  static final NetworkDiscoveryService _instance = NetworkDiscoveryService._internal();
  factory NetworkDiscoveryService() => _instance;
  NetworkDiscoveryService._internal();

  final NetworkInfo _networkInfo = NetworkInfo();

  /// Get current WiFi network information
  Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      final wifiName = await _networkInfo.getWifiName();
      final wifiIP = await _networkInfo.getWifiIP();
      final wifiBSSID = await _networkInfo.getWifiBSSID();
      final wifiGatewayIP = await _networkInfo.getWifiGatewayIP();
      final wifiSubmask = await _networkInfo.getWifiSubmask();

      return {
        'wifi_name': wifiName?.replaceAll('"', '') ?? 'Unknown',
        'wifi_ip': wifiIP ?? 'Unknown',
        'wifi_bssid': wifiBSSID ?? 'Unknown',
        'gateway_ip': wifiGatewayIP ?? 'Unknown',
        'subnet_mask': wifiSubmask ?? 'Unknown',
        'is_connected': wifiIP != null,
      };
    } catch (e) {
      LoggingService.error('Failed to get network info', tag: 'NetworkDiscovery', error: e);
      return {
        'wifi_name': 'Unknown',
        'wifi_ip': 'Unknown',
        'wifi_bssid': 'Unknown',
        'gateway_ip': 'Unknown',
        'subnet_mask': 'Unknown',
        'is_connected': false,
        'error': e.toString(),
      };
    }
  }

  /// Get all available network interfaces
  Future<List<Map<String, dynamic>>> getNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      return interfaces.map((interface) {
        return {
          'name': interface.name,
          'addresses': interface.addresses.map((addr) => {
            'address': addr.address,
            'type': addr.type.name,
            'is_loopback': addr.isLoopback,
          }).toList(),
        };
      }).toList();
    } catch (e) {
      LoggingService.error('Failed to get network interfaces', tag: 'NetworkDiscovery', error: e);
      return [];
    }
  }

  /// Get the best IP address for server binding
  Future<String> getBestServerAddress() async {
    try {
      // First try to get WiFi IP
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty) {
        LoggingService.info('Using WiFi IP for server: $wifiIP', tag: 'NetworkDiscovery');
        return wifiIP;
      }

      // Fallback to first non-loopback IPv4 address
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            LoggingService.info('Using interface ${interface.name} IP for server: ${addr.address}', tag: 'NetworkDiscovery');
            return addr.address;
          }
        }
      }

      // Ultimate fallback
      LoggingService.warning('No suitable network interface found, using 0.0.0.0', tag: 'NetworkDiscovery');
      return '0.0.0.0';
    } catch (e) {
      LoggingService.error('Failed to get best server address', tag: 'NetworkDiscovery', error: e);
      return '0.0.0.0';
    }
  }

  /// Check if device is connected to WiFi
  Future<bool> isConnectedToWiFi() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      return wifiIP != null && wifiIP.isNotEmpty;
    } catch (e) {
      LoggingService.error('Failed to check WiFi connection', tag: 'NetworkDiscovery', error: e);
      return false;
    }
  }

  /// Generate QR code data for easy connection
  String generateConnectionQR(String serverAddress, int port, String apiKey) {
    final connectionData = {
      'type': 'sms_gateway',
      'server': 'http://$serverAddress:$port',
      'api_key': apiKey,
      'version': '1.0',
    };
    return jsonEncode(connectionData);
  }

  /// Get connection instructions for clients
  Map<String, dynamic> getConnectionInstructions(String serverAddress, int port, String apiKey) {
    return {
      'server_url': 'http://$serverAddress:$port',
      'api_key': apiKey,
      'headers': {
        'X-API-Key': apiKey,
        'Content-Type': 'application/json',
      },
      'endpoints': {
        'health': 'GET /health',
        'device_info': 'GET /device-info',
        'statistics': 'GET /statistics',
        'recent_messages': 'GET /messages/recent',
        'send_sms': 'POST /send-sms',
      },
      'example_curl': 'curl -H "X-API-Key: $apiKey" http://$serverAddress:$port/health',
      'qr_code_data': generateConnectionQR(serverAddress, port, apiKey),
    };
  }
}