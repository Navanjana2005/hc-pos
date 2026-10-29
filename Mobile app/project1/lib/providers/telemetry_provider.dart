import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/telemetry_point.dart';
import '../models/forecast.dart';
import '../services/supabase_service.dart';
import '../services/mock_data.dart';

/// Family provider: fetches solar + consumption telemetry for a given range.
final solarTelemetryProvider =
    FutureProvider.family<List<TelemetryPoint>, TimeRange>((ref, range) async {
  try {
    final now = DateTime.now();
    final from = switch (range) {
      TimeRange.day   => now.subtract(const Duration(hours: 24)),
      TimeRange.week  => now.subtract(const Duration(days: 7)),
      TimeRange.month => now.subtract(const Duration(days: 30)),
    };
    final rows = await SupabaseService.instance.fetchTelemetry(
      metricType: 'solar_generation_w',
      from: from,
      to: now,
    );
    if (rows.isNotEmpty) return rows.map(TelemetryPoint.fromJson).toList();
    return [];
  } catch (e) {
    throw e;
  }
});

final consumptionTelemetryProvider =
    FutureProvider.family<List<TelemetryPoint>, TimeRange>((ref, range) async {
  try {
    final now = DateTime.now();
    final from = switch (range) {
      TimeRange.day   => now.subtract(const Duration(hours: 24)),
      TimeRange.week  => now.subtract(const Duration(days: 7)),
      TimeRange.month => now.subtract(const Duration(days: 30)),
    };
    final rows = await SupabaseService.instance.fetchTelemetry(
      metricType: 'whole_house_power_w',
      from: from,
      to: now,
    );
    if (rows.isNotEmpty) return rows.map(TelemetryPoint.fromJson).toList();
    return [];
  } catch (e) {
    throw e;
  }
});

final forecastsProvider =
    FutureProvider.family<List<Forecast>, String>((ref, forecastType) async {
  try {
    final rows = await SupabaseService.instance.fetchForecasts(
      forecastType: forecastType,
      from: DateTime.now().subtract(const Duration(hours: 1)),
    );
    if (rows.isNotEmpty) return rows.map(Forecast.fromJson).toList();
    return [];
  } catch (e) {
    throw e;
  }
});
