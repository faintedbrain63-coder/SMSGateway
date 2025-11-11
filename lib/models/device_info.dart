class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String deviceModel;
  final String osVersion;
  final String appVersion;
  final List<SimInfo> simCards;
  final bool isServerRunning;
  final int serverPort;
  final DateTime lastUpdated;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
    required this.simCards,
    required this.isServerRunning,
    required this.serverPort,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'device_model': deviceModel,
      'os_version': osVersion,
      'app_version': appVersion,
      'sim_cards': simCards.map((sim) => sim.toMap()).toList(),
      'is_server_running': isServerRunning,
      'server_port': serverPort,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    return DeviceInfo(
      deviceId: map['device_id'],
      deviceName: map['device_name'],
      deviceModel: map['device_model'],
      osVersion: map['os_version'],
      appVersion: map['app_version'],
      simCards: (map['sim_cards'] as List<dynamic>)
          .map((sim) => SimInfo.fromMap(sim))
          .toList(),
      isServerRunning: map['is_server_running'] ?? false,
      serverPort: map['server_port'] ?? 8080,
      lastUpdated: DateTime.parse(map['last_updated']),
    );
  }

  DeviceInfo copyWith({
    String? deviceId,
    String? deviceName,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
    List<SimInfo>? simCards,
    bool? isServerRunning,
    int? serverPort,
    DateTime? lastUpdated,
  }) {
    return DeviceInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      simCards: simCards ?? this.simCards,
      isServerRunning: isServerRunning ?? this.isServerRunning,
      serverPort: serverPort ?? this.serverPort,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class SimInfo {
  final int slot;
  final String? carrierName;
  final String? phoneNumber;
  final bool isActive;

  SimInfo({
    required this.slot,
    this.carrierName,
    this.phoneNumber,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'slot': slot,
      'carrier_name': carrierName,
      'phone_number': phoneNumber,
      'is_active': isActive,
    };
  }

  factory SimInfo.fromMap(Map<String, dynamic> map) {
    return SimInfo(
      slot: map['slot'],
      carrierName: map['carrier_name'],
      phoneNumber: map['phone_number'],
      isActive: map['is_active'] ?? false,
    );
  }
}