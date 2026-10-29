/// A single forecast row from the `forecasts` table.
class Forecast {
  const Forecast({
    required this.id,
    required this.forecastType,
    required this.horizonStart,
    required this.horizonEnd,
    required this.predictedValue,
    this.actualValue,
  });

  final int id;
  final String forecastType; // 'solar' | 'consumption'
  final DateTime horizonStart;
  final DateTime horizonEnd;
  final double predictedValue;
  final double? actualValue;

  bool get hasActual => actualValue != null;

  factory Forecast.fromJson(Map<String, dynamic> json) => Forecast(
        id: json['id'] as int,
        forecastType: json['forecast_type'] as String,
        horizonStart: DateTime.parse(json['horizon_start'] as String),
        horizonEnd: DateTime.parse(json['horizon_end'] as String),
        predictedValue: (json['predicted_value'] as num).toDouble(),
        actualValue: (json['actual_value'] as num?)?.toDouble(),
      );
}
