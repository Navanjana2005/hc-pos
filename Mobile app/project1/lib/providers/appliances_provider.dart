import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/appliance.dart';
import '../services/supabase_service.dart';
import '../services/mock_data.dart';

class AppliancesNotifier extends AsyncNotifier<List<Appliance>> {
  @override
  Future<List<Appliance>> build() async {
    List<Appliance> appliances = [];
    try {
      final rows = await SupabaseService.instance.fetchAppliances();
      if (rows.isNotEmpty) {
        appliances = rows.map(Appliance.fromJson).toList();
      }
    } catch (e) {
      rethrow;
    }
    return appliances;
  }

  Future<void> toggleAppliance(int applianceId, bool isOn) async {
    final current = state.valueOrNull ?? [];
    // Optimistic update.
    state = AsyncData(
      current.map((a) => a.applianceId == applianceId ? a.copyWith(isOn: isOn) : a).toList(),
    );
    try {
      // The is_on field is not in the Supabase schema yet; this will be
      // handled by the Pi agent via MQTT. We send a REST call as a command hint.
      await SupabaseService.instance.updateAppliance(applianceId, {'is_controllable': true});
    } catch (_) {}
  }

  Future<void> updatePriority(int applianceId, int priority) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((a) => a.applianceId == applianceId
          ? a.copyWith(priorityLevel: priority)
          : a).toList(),
    );
    try {
      await SupabaseService.instance
          .updateAppliance(applianceId, {'priority_level': priority});
    } catch (_) {}
  }
}

final appliancesProvider =
    AsyncNotifierProvider<AppliancesNotifier, List<Appliance>>(
  AppliancesNotifier.new,
);
