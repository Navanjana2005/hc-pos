import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/decision.dart';
import '../services/supabase_service.dart';
import '../services/mock_data.dart';

class DecisionsNotifier extends AsyncNotifier<List<Decision>> {
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  Future<List<Decision>> build() async {
    ref.onDispose(() => _sub?.cancel());

    List<Decision> decisions = [];

    try {
      final rows = await SupabaseService.instance.fetchDecisions();
      if (rows.isNotEmpty) {
        decisions = rows.map(Decision.fromJson).toList();
      }

      // Subscribe to realtime updates.
      _sub = SupabaseService.instance.watchDecisions().listen((rows) {
        if (rows.isNotEmpty) {
          // In a real app we might want to merge, but replacing is fine for now
          // if watchDecisions() returns the latest X rows.
          state = AsyncData(rows.map(Decision.fromJson).toList());
        } else {
           state = const AsyncData([]);
        }
      }, onError: (err) {
        state = AsyncError(err, StackTrace.current);
      });
    } catch (e) {
      rethrow;
    }

    return decisions;
  }

  Future<void> approveDecision(int decisionId) async {
    try {
      await SupabaseService.instance.updateDecisionStatus(decisionId, 'approved');
      _updateLocalStatus(decisionId, DecisionStatus.approved);
    } catch (_) {}
  }

  Future<void> rejectDecision(int decisionId) async {
    try {
      await SupabaseService.instance.updateDecisionStatus(decisionId, 'rejected');
      _updateLocalStatus(decisionId, DecisionStatus.rejected);
    } catch (_) {}
  }

  void _updateLocalStatus(int decisionId, DecisionStatus newStatus) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((d) => d.id == decisionId ? d.copyWith(status: newStatus) : d).toList(),
    );
  }
}

final decisionsProvider =
    AsyncNotifierProvider<DecisionsNotifier, List<Decision>>(
  DecisionsNotifier.new,
);
