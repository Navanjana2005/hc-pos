import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin singleton wrapper around the Supabase client.
class SupabaseService {
  SupabaseService._();
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  // ── Auth ──────────────────────────────────────────────────
  User? get currentUser => client.auth.currentUser;

  Future<void> signInAnonymously() async {
    if (currentUser == null) {
      await client.auth.signInAnonymously();
    }
  }

  // ── System State ─────────────────────────────────────────
  Future<Map<String, dynamic>?> fetchSystemState() async {
    final res = await client
        .from('system_state')
        .select()
        .eq('id', 1)
        .maybeSingle();
    return res;
  }

  Future<void> updateSystemState(Map<String, dynamic> data) async {
    await client.from('system_state').update(data).eq('id', 1);
  }

  /// Realtime stream for system_state row changes.
  Stream<List<Map<String, dynamic>>> watchSystemState() =>
      client.from('system_state').stream(primaryKey: ['id']);

  // ── Decisions ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchDecisions() async {
    return await client
        .from('decisions')
        .select('*, appliances(appliance_name), devices(device_name)')
        .order('created_at', ascending: false)
        .limit(50);
  }

  Future<void> updateDecisionStatus(int decisionId, String status) async {
    await client
        .from('decisions')
        .update({'status': status})
        .eq('id', decisionId);
  }

  Stream<List<Map<String, dynamic>>> watchDecisions() =>
      client.from('decisions').stream(primaryKey: ['id']).order('created_at', ascending: false);

  // ── Appliances ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchAppliances() async {
    return await client
        .from('appliances')
        .select('*, devices(device_name, room_location)')
        .order('appliance_id');
  }

  Future<void> updateAppliance(int applianceId, Map<String, dynamic> data) async {
    await client.from('appliances').update(data).eq('appliance_id', applianceId);
  }

  // ── Alerts ────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    return await client
        .from('alerts')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
  }

  Future<void> acknowledgeAlert(int alertId) async {
    await client
        .from('alerts')
        .update({'acknowledged': true})
        .eq('id', alertId);
  }

  Future<void> acknowledgeAllAlerts() async {
    if (currentUser == null) return;
    await client
        .from('alerts')
        .update({'acknowledged': true})
        .eq('user_id', currentUser!.id);
  }

  Stream<List<Map<String, dynamic>>> watchAlerts() =>
      client.from('alerts').stream(primaryKey: ['id']).order('created_at', ascending: false);

  // ── Telemetry ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchTelemetry({
    required String metricType,
    required DateTime from,
    required DateTime to,
  }) async {
    return await client
        .from('telemetry_log')
        .select('metric_type, value, recorded_at')
        .eq('metric_type', metricType)
        .gte('recorded_at', from.toIso8601String())
        .lte('recorded_at', to.toIso8601String())
        .order('recorded_at');
  }

  // ── Forecasts ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchForecasts({
    required String forecastType,
    required DateTime from,
  }) async {
    return await client
        .from('forecasts')
        .select()
        .eq('forecast_type', forecastType)
        .gte('horizon_start', from.toIso8601String())
        .order('horizon_start');
  }
}
