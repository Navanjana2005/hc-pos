/// A single data point from the `telemetry_log` table.
class TelemetryPoint {
  const TelemetryPoint({
    required this.recordedAt,
    required this.value,
    required this.metricType,
  });

  final DateTime recordedAt;
  final double value;
  final String metricType; // e.g. 'solar_generation_w', 'whole_house_power_w'

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) => TelemetryPoint(
        recordedAt: DateTime.parse(json['recorded_at'] as String),
        value: (json['value'] as num).toDouble(),
        metricType: json['metric_type'] as String,
      );
}

/// Range selector for energy history charts.
enum TimeRange { day, week, month }
