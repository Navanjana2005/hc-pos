/// Appliance linked to a room/socket device.
class Appliance {
  const Appliance({
    required this.applianceId,
    required this.deviceId,
    required this.applianceName,
    required this.priorityLevel,
    required this.isControllable,
    this.nilmPredictedType,
    this.ratedPowerW,
    this.isOn = false,
    this.roomLocation,
  });

  final int applianceId;
  final int deviceId;
  final String applianceName;
  final int priorityLevel;     // 1-5
  final bool isControllable;
  final String? nilmPredictedType;
  final double? ratedPowerW;
  final bool isOn;
  final String? roomLocation;

  String get priorityLabel {
    switch (priorityLevel) {
      case 1:  return 'Critical';
      case 2:  return 'High';
      case 3:  return 'Med';
      case 4:  return 'Low';
      case 5:  return 'Stby';
      default: return 'Med';
    }
  }

  factory Appliance.fromJson(Map<String, dynamic> json) => Appliance(
        applianceId: json['appliance_id'] as int,
        deviceId: json['device_id'] as int,
        applianceName: json['appliance_name'] as String,
        nilmPredictedType: json['nilm_predicted_type'] as String?,
        ratedPowerW: (json['rated_power_w'] as num?)?.toDouble(),
        priorityLevel: json['priority_level'] as int? ?? 3,
        isControllable: json['is_controllable'] as bool? ?? true,
        roomLocation: json['devices']?['room_location'] as String?,
      );

  Appliance copyWith({int? priorityLevel, bool? isOn}) => Appliance(
        applianceId: applianceId,
        deviceId: deviceId,
        applianceName: applianceName,
        nilmPredictedType: nilmPredictedType,
        ratedPowerW: ratedPowerW,
        priorityLevel: priorityLevel ?? this.priorityLevel,
        isControllable: isControllable,
        isOn: isOn ?? this.isOn,
        roomLocation: roomLocation,
      );
}
