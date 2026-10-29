import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert.dart';
import '../services/supabase_service.dart';
import '../services/mock_data.dart';

class AlertsNotifier extends AsyncNotifier<List<Alert>> {
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  Future<List<Alert>> build() async {
    ref.onDispose(() => _sub?.cancel());

    List<Alert> alerts = [];
    try {
      final rows = await SupabaseService.instance.fetchAlerts();
      if (rows.isNotEmpty) {
        alerts = rows.map(Alert.fromJson).toList();
      }

      _sub = SupabaseService.instance.watchAlerts().listen((rows) {
        if (rows.isNotEmpty) {
          state = AsyncData(rows.map(Alert.fromJson).toList());
        } else {
          state = const AsyncData([]);
        }
      }, onError: (err) {
        state = AsyncError(err, StackTrace.current);
      });
    } catch (e) {
      rethrow;
    }

    return alerts;
  }

  Future<void> acknowledge(int alertId) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((a) => a.id == alertId ? a.copyWith(acknowledged: true) : a).toList(),
    );
    try {
      await SupabaseService.instance.acknowledgeAlert(alertId);
    } catch (_) {}
  }

  Future<void> acknowledgeAll() async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.map((a) => a.copyWith(acknowledged: true)).toList());
    try {
      await SupabaseService.instance.acknowledgeAllAlerts();
    } catch (_) {}
  }

  int get unacknowledgedCount =>
      (state.valueOrNull ?? []).where((a) => !a.acknowledged).length;
}

final alertsProvider =
    AsyncNotifierProvider<AlertsNotifier, List<Alert>>(AlertsNotifier.new);

/// Reactive count of unacknowledged alerts for the nav badge.
final unacknowledgedAlertsCountProvider = Provider<int>((ref) {
  final alerts = ref.watch(alertsProvider).valueOrNull ?? [];
  return alerts.where((a) => !a.acknowledged).length;
});
