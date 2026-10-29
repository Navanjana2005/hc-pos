import '../models/system_state.dart';
import '../models/decision.dart';
import '../models/appliance.dart';
import '../models/alert.dart';
import '../models/telemetry_point.dart';
import '../models/forecast.dart';

/// Realistic mock data used while Supabase is not yet seeded or offline.
class MockData {
  MockData._();

  static SystemState get systemState => SystemState(
        id: 1,
        batterySocPct: 84,
        batteryHealthPct: 98,
        solarGenerationW: 3100,
        wholeHousePowerW: 2400,
        currentPowerSource: 'solar',
        automationMode: 'manual_approval',
        emergencyStopActive: false,
        updatedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );

  static List<Decision> get decisions => [
        Decision(
          id: 1,
          decisionType: DecisionType.chargeBattery,
          reasoning: {
            'summary': 'Solar surplus detected. Battery can absorb 2.4 kWh before reaching full capacity.',
            'confidence': 0.92,
            'factors': ['solar_excess: +700W', 'battery_soc: 84%', 'forecast: sunny 4h'],
          },
          status: DecisionStatus.proposed,
          decidedBy: 'ai',
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
          targetApplianceName: null,
          targetDeviceName: 'Solar MPPT Controller',
        ),
        Decision(
          id: 2,
          decisionType: DecisionType.switchToSolar,
          reasoning: {
            'summary': 'Grid price surge detected (peak tariff). Switching to solar avoids ₹12.5/kWh penalty.',
            'confidence': 0.97,
            'factors': ['grid_tariff: peak', 'solar_available: 3.1kW', 'house_load: 2.4kW'],
          },
          status: DecisionStatus.executed,
          decidedBy: 'ai',
          createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 14)),
          targetDeviceName: 'Distribution Board',
        ),
        Decision(
          id: 3,
          decisionType: DecisionType.disableAppliance,
          reasoning: {
            'summary': 'User preference override noted. HVAC was flagged for shutdown during peak hours but user rejected.',
            'confidence': 0.78,
            'factors': ['peak_hours: true', 'hvac_priority: 3', 'user_rejection: last 2 attempts'],
          },
          status: DecisionStatus.rejected,
          decidedBy: 'user',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
          targetApplianceName: 'LR AC',
        ),
        Decision(
          id: 4,
          decisionType: DecisionType.postponeLoad,
          reasoning: {
            'summary': 'Washing machine scheduled for 10 PM when off-peak tariff begins. Expected saving: ₹8.',
            'confidence': 0.89,
            'factors': ['washer_priority: 4', 'off_peak_starts: 22:00', 'solar_forecast: nil by 19:00'],
          },
          status: DecisionStatus.approved,
          decidedBy: 'user',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 55)),
          targetApplianceName: 'Washer',
        ),
      ];

  static List<Appliance> get appliances => [
        const Appliance(
          applianceId: 1,
          deviceId: 1,
          applianceName: 'Fridge',
          nilmPredictedType: 'refrigerator',
          ratedPowerW: 120,
          priorityLevel: 2,
          isControllable: false,
          isOn: true,
          roomLocation: 'Kitchen',
        ),
        const Appliance(
          applianceId: 2,
          deviceId: 2,
          applianceName: 'LR AC',
          nilmPredictedType: 'air_conditioner',
          ratedPowerW: 1500,
          priorityLevel: 3,
          isControllable: true,
          isOn: false,
          roomLocation: 'Living Rm',
        ),
        const Appliance(
          applianceId: 3,
          deviceId: 3,
          applianceName: 'Washer',
          nilmPredictedType: 'washing_machine',
          ratedPowerW: 850,
          priorityLevel: 4,
          isControllable: true,
          isOn: true,
          roomLocation: 'Utility',
        ),
        const Appliance(
          applianceId: 4,
          deviceId: 4,
          applianceName: 'EV',
          nilmPredictedType: 'ev_charger',
          ratedPowerW: 3300,
          priorityLevel: 5,
          isControllable: true,
          isOn: false,
          roomLocation: 'Garage',
        ),
      ];

  static List<Alert> get alerts => [
        Alert(
          id: 1,
          alertType: 'battery_low',
          severity: AlertSeverity.critical,
          message: 'Battery Low: 15% — System will transition to power-saving mode in 10 minutes.',
          acknowledged: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        Alert(
          id: 2,
          alertType: 'high_grid_usage',
          severity: AlertSeverity.warning,
          message: 'High Grid Usage Detected — Current usage exceeds normal evening patterns. Consider deferring non-critical loads.',
          acknowledged: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        Alert(
          id: 3,
          alertType: 'solar_forecast',
          severity: AlertSeverity.info,
          message: 'Solar Forecast: Bright Tomorrow — Expected high solar generation tomorrow. System will prioritize battery charging tonight.',
          acknowledged: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];

  // ── Telemetry — 24h simulated readings ───────────────────
  static List<TelemetryPoint> solarTelemetry(TimeRange range) {
    final now = DateTime.now();
    final count = range == TimeRange.day ? 12 : (range == TimeRange.week ? 28 : 30);
    final solarValues = [
      0.0, 0.0, 0.2, 0.8, 1.5, 2.2, 3.1, 3.4, 3.2, 2.8, 2.1, 1.4,
      0.7, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
      1.2, 2.4, 3.1, 1.8,
    ];
    return List.generate(count, (i) {
      final offset = range == TimeRange.day
          ? Duration(hours: 2 * i - 18)
          : range == TimeRange.week
              ? Duration(hours: 6 * i - 7 * 24)
              : Duration(days: i - 30);
      return TelemetryPoint(
        recordedAt: now.add(offset),
        value: solarValues[i % solarValues.length] * 1000,
        metricType: 'solar_generation_w',
      );
    });
  }

  static List<TelemetryPoint> consumptionTelemetry(TimeRange range) {
    final now = DateTime.now();
    final count = range == TimeRange.day ? 12 : (range == TimeRange.week ? 28 : 30);
    final usageValues = [
      1.8, 1.5, 1.2, 1.0, 1.1, 1.4, 2.0, 2.4, 2.2, 2.1, 2.0, 1.9,
      1.7, 1.6, 1.8, 2.2, 2.5, 2.7, 2.4, 2.0, 1.8, 1.6, 1.5, 1.4,
      2.1, 1.9, 2.3, 2.0,
    ];
    return List.generate(count, (i) {
      final offset = range == TimeRange.day
          ? Duration(hours: 2 * i - 18)
          : range == TimeRange.week
              ? Duration(hours: 6 * i - 7 * 24)
              : Duration(days: i - 30);
      return TelemetryPoint(
        recordedAt: now.add(offset),
        value: usageValues[i % usageValues.length] * 1000,
        metricType: 'whole_house_power_w',
      );
    });
  }

  static List<Forecast> get forecasts {
    final now = DateTime.now();
    return List.generate(8, (i) {
      final start = now.add(Duration(hours: i));
      final end = start.add(const Duration(hours: 1));
      final predicted = i < 4
          ? (2.0 + i * 0.3)
          : (3.2 - (i - 4) * 0.4);
      final actual = i <= 3 ? (predicted * (0.9 + (i % 3) * 0.05)) : null;
      return Forecast(
        id: i + 1,
        forecastType: 'solar',
        horizonStart: start,
        horizonEnd: end,
        predictedValue: predicted * 1000,
        actualValue: actual != null ? actual * 1000 : null,
      );
    });
  }
}
