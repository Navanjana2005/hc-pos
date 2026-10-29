import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/system_state.dart';
import '../services/supabase_service.dart';
import '../services/mock_data.dart';
import '../core/constants.dart';

/// Tracks whether we have a live Supabase connection and when data was last
/// received, so the UI can show a "stale data" indicator.
class ConnectionStatus {
  const ConnectionStatus({
    required this.isLive,
    this.lastUpdated,
  });
  final bool isLive;
  final DateTime? lastUpdated;

  String get ageLabel {
    if (lastUpdated == null) return 'Never';
    final diff = DateTime.now().difference(lastUpdated!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  bool get isStale =>
      lastUpdated == null ||
      DateTime.now().difference(lastUpdated!) > AppConstants.staleThreshold;
}

class SystemStateNotifier extends StateNotifier<AsyncValue<SystemState>> {
  SystemStateNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  ConnectionStatus _connStatus = const ConnectionStatus(isLive: false);

  ConnectionStatus get connectionStatus => _connStatus;

  void _init() async {
    try {
      // Try fetching live data first.
      final json = await SupabaseService.instance.fetchSystemState();
      if (json != null) {
        state = AsyncValue.data(SystemState.fromJson(json));
        _connStatus = ConnectionStatus(isLive: true, lastUpdated: DateTime.now());
      } else {
        // If no data exists yet, we just stay loading or show error.
        // But for UI stability, we can show a default empty state until Pi inserts row.
        state = AsyncValue.data(SystemState.mock);
        _connStatus = ConnectionStatus(isLive: true, lastUpdated: DateTime.now());
      }

      // Subscribe to Realtime stream.
      _sub = SupabaseService.instance.watchSystemState().listen(
        (rows) {
          if (rows.isNotEmpty) {
            state = AsyncValue.data(SystemState.fromJson(rows.first));
            _connStatus = ConnectionStatus(isLive: true, lastUpdated: DateTime.now());
          }
        },
        onError: (err) {
          _connStatus = ConnectionStatus(isLive: false, lastUpdated: _connStatus.lastUpdated);
          state = AsyncValue.error(err, StackTrace.current);
        },
      );
    } catch (e, st) {
      _connStatus = ConnectionStatus(isLive: false, lastUpdated: _connStatus.lastUpdated);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateAutomationMode(String mode) async {
    try {
      await SupabaseService.instance.updateSystemState({'automation_mode': mode});
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(automationMode: mode));
      }
    } catch (_) {}
  }

  Future<void> triggerEmergencyStop() async {
    try {
      await SupabaseService.instance.updateSystemState({'emergency_stop_active': true});
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(emergencyStopActive: true));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final systemStateProvider =
    StateNotifierProvider<SystemStateNotifier, AsyncValue<SystemState>>(
  (ref) => SystemStateNotifier(),
);

/// Exposes connection status separately so the app bar and stale banner
/// can react without re-rendering the whole dashboard.
final connectionStatusProvider = Provider<ConnectionStatus>((ref) {
  final notifier = ref.watch(systemStateProvider.notifier);
  ref.watch(systemStateProvider); // depend on state changes to rebuild
  return notifier.connectionStatus;
});
