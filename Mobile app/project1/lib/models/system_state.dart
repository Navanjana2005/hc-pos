/// Snapshot of the current system state from the `system_state` table.
/// Single-row table (id = 1).
class SystemState {
  const SystemState({
    required this.id,
    required this.batterySocPct,
    required this.batteryHealthPct,
    required this.solarGenerationW,
    required this.wholeHousePowerW,
    required this.currentPowerSource,
    required this.automationMode,
    required this.emergencyStopActive,
    required this.updatedAt,
  });

  final int id;
  final double batterySocPct;
  final double batteryHealthPct;
  final double solarGenerationW;
  final double wholeHousePowerW;
  final String currentPowerSource; // 'grid' | 'solar' | 'battery'
  final String automationMode;     // 'auto' | 'manual_approval'
  final bool emergencyStopActive;
  final DateTime updatedAt;

  factory SystemState.fromJson(Map<String, dynamic> json) => SystemState(
        id: json['id'] as int,
        batterySocPct: (json['battery_soc_pct'] as num?)?.toDouble() ?? 0,
        batteryHealthPct: (json['battery_health_pct'] as num?)?.toDouble() ?? 0,
        solarGenerationW: (json['solar_generation_w'] as num?)?.toDouble() ?? 0,
        wholeHousePowerW: (json['whole_house_power_w'] as num?)?.toDouble() ?? 0,
        currentPowerSource: json['current_power_source'] as String? ?? 'grid',
        automationMode: json['automation_mode'] as String? ?? 'auto',
        emergencyStopActive: json['emergency_stop_active'] as bool? ?? false,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'battery_soc_pct': batterySocPct,
        'battery_health_pct': batteryHealthPct,
        'solar_generation_w': solarGenerationW,
        'whole_house_power_w': wholeHousePowerW,
        'current_power_source': currentPowerSource,
        'automation_mode': automationMode,
        'emergency_stop_active': emergencyStopActive,
        'updated_at': updatedAt.toIso8601String(),
      };

  SystemState copyWith({
    double? batterySocPct,
    double? batteryHealthPct,
    double? solarGenerationW,
    double? wholeHousePowerW,
    String? currentPowerSource,
    String? automationMode,
    bool? emergencyStopActive,
    DateTime? updatedAt,
  }) =>
      SystemState(
        id: id,
        batterySocPct: batterySocPct ?? this.batterySocPct,
        batteryHealthPct: batteryHealthPct ?? this.batteryHealthPct,
        solarGenerationW: solarGenerationW ?? this.solarGenerationW,
        wholeHousePowerW: wholeHousePowerW ?? this.wholeHousePowerW,
        currentPowerSource: currentPowerSource ?? this.currentPowerSource,
        automationMode: automationMode ?? this.automationMode,
        emergencyStopActive: emergencyStopActive ?? this.emergencyStopActive,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// A realistic mock value for development.
  static SystemState get mock => SystemState(
        id: 1,
        batterySocPct: 84,
        batteryHealthPct: 98,
        solarGenerationW: 3100,
        wholeHousePowerW: 2400,
        currentPowerSource: 'solar',
        automationMode: 'manual_approval',
        emergencyStopActive: false,
        updatedAt: DateTime.now(),
      );
}
