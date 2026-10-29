/// HC-POS App Constants
///
/// SETUP REQUIRED:
///   1. Replace the Supabase values with your project credentials from supabase.com/dashboard
///   2. Set apiBaseUrl to your Python backend's LAN IP or cloud URL
///
/// NEVER commit real credentials to version control.
/// Use environment-specific build flavors or a config loader for production.
class AppConstants {
  AppConstants._();

  // ── Supabase ─────────────────────────────────────────────
  /// Replace with your Supabase project URL from supabase.com/dashboard > Settings > API
  static const String supabaseUrl = 'https://YOUR_PROJECT_REF.supabase.co';

  /// Replace with your Supabase anon (public) key from supabase.com/dashboard > Settings > API
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // ── Genesis AI Backend ────────────────────────────────────
  /// URL of the Python FastAPI server.
  /// • Local dev  : 'http://YOUR_MACHINE_LAN_IP:8000'
  ///   (find it with `ipconfig` on Windows, `ifconfig` on Linux/Mac)
  /// • Raspberry Pi: 'http://PI_IP_ADDRESS:8000'
  /// • Cloud      : 'https://your-deployed-url.com'
  static const String apiBaseUrl = 'http://YOUR_BACKEND_IP:8000';

  // ── System State ─────────────────────────────────────────
  /// The single-row ID in system_state table.
  static const int systemStateRowId = 1;

  // ── Timeouts ─────────────────────────────────────────────
  /// How long before we consider data "stale".
  static const Duration staleThreshold = Duration(seconds: 300);

  /// HTTP timeout for calls to the Genesis AI API.
  static const Duration apiTimeout = Duration(seconds: 300);

  // ── Misc ──────────────────────────────────────────────────
  static const String appName = 'HC-POS';
  static const String appTagline = 'Human-Centric Power Orchestration System';
}