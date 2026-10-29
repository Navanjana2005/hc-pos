import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// A single chat message in the conversation history.
class AgentMessage {
  const AgentMessage({required this.role, required this.content});
  final String role;   // 'user' | 'assistant'
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Response from the /chat endpoint.
class ChatResult {
  const ChatResult({required this.reply, this.toolCallsMade = const []});
  final String reply;
  final List<String> toolCallsMade;
}

/// Response from the /run-optimizer endpoint.
class OptimizerResult {
  const OptimizerResult({
    required this.status,
    required this.summary,
    required this.decisionsWritten,
    required this.forecastsWritten,
    this.message,
  });
  final String status;
  final Map<String, dynamic> summary;
  final int decisionsWritten;
  final int forecastsWritten;
  final String? message;
}

/// HTTP client for the HC-POS Genesis AI FastAPI backend.
class AgentService {
  AgentService._();
  static final AgentService instance = AgentService._();

  final _client = http.Client();

  // ── /chat ────────────────────────────────────────────────

  /// Send [message] to the LangChain agent, returning its reply.
  /// [history] is the full conversation so far (user + assistant turns).
  Future<ChatResult> sendMessage(
    String message,
    List<AgentMessage> history,
  ) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/chat');
    final body = jsonEncode({
      'message': message,
      'history': history.map((m) => m.toJson()).toList(),
    });

    try {
      final response = await _client
          .post(url, headers: _jsonHeaders, body: body)
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ChatResult(
          reply: data['reply'] as String,
          toolCallsMade: List<String>.from(data['tool_calls_made'] ?? []),
        );
      } else {
        final detail = _extractDetail(response.body);
        throw AgentException('Server error ${response.statusCode}: $detail');
      }
    } on AgentException {
      rethrow;
    } catch (e) {
      throw AgentException('Could not reach Genesis AI server. '
          'Is the Python backend running at ${AppConstants.apiBaseUrl}?\n($e)');
    }
  }

  // ── /run-optimizer ───────────────────────────────────────

  /// Trigger the MILP optimizer on the server. Results are written to
  /// Supabase automatically; the Flutter app picks them up via Realtime.
  Future<OptimizerResult> runOptimizer({String? userId}) async {
    var url = Uri.parse('${AppConstants.apiBaseUrl}/run-optimizer');
    if (userId != null) {
      url = url.replace(queryParameters: {'user_id': userId});
    }

    try {
      final response = await _client
          .post(url, headers: _jsonHeaders)
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return OptimizerResult(
          status: data['status'] as String,
          summary: Map<String, dynamic>.from(data['summary'] ?? {}),
          decisionsWritten: data['decisions_written'] as int? ?? 0,
          forecastsWritten: data['forecasts_written'] as int? ?? 0,
          message: data['message'] as String?,
        );
      } else {
        throw AgentException('Optimizer failed: ${_extractDetail(response.body)}');
      }
    } on AgentException {
      rethrow;
    } catch (e) {
      throw AgentException('Could not reach optimizer. ($e)');
    }
  }

  // ── /health ──────────────────────────────────────────────

  /// Returns true if the FastAPI server is reachable and healthy.
  Future<bool> checkHealth() async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/health');
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static String _extractDetail(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      return map['detail']?.toString() ?? body;
    } catch (_) {
      return body.length > 200 ? '${body.substring(0, 200)}...' : body;
    }
  }
}

/// Thrown when the AgentService encounters an HTTP or network error.
class AgentException implements Exception {
  const AgentException(this.message);
  final String message;
  @override
  String toString() => message;
}
