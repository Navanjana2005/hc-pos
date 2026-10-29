import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/agent_service.dart';
import '../services/supabase_service.dart';

// ── Chat message model ────────────────────────────────────────────────────────

/// A single message in the Genesis AI chat feed.
class ChatEntry {
  const ChatEntry({
    required this.role,
    required this.content,
    this.toolCallsMade = const [],
    this.isError = false,
  });

  final String role;   // 'user' | 'assistant'
  final String content;
  final List<String> toolCallsMade;
  final bool isError;

  AgentMessage toAgentMessage() => AgentMessage(role: role, content: content);
}

// ── State ─────────────────────────────────────────────────────────────────────

class AgentState {
  const AgentState({
    this.messages = const [],
    this.isLoading = false,
    this.agentOnline = false,
    this.lastError,
  });

  final List<ChatEntry> messages;
  final bool isLoading;
  final bool agentOnline;
  final String? lastError;

  AgentState copyWith({
    List<ChatEntry>? messages,
    bool? isLoading,
    bool? agentOnline,
    String? lastError,
  }) =>
      AgentState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        agentOnline: agentOnline ?? this.agentOnline,
        lastError: lastError,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AgentNotifier extends StateNotifier<AgentState> {
  AgentNotifier() : super(const AgentState()) {
    _checkHealth();
  }

  final _service = AgentService.instance;

  // ── Health check ─────────────────────────────────────────

  Future<void> _checkHealth() async {
    final ok = await _service.checkHealth();
    state = state.copyWith(agentOnline: ok);
  }

  Future<void> refreshHealth() => _checkHealth();

  // ── Send a user message ──────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isLoading) return;

    // Append user message immediately
    final userEntry = ChatEntry(role: 'user', content: text.trim());
    final updatedMessages = [...state.messages, userEntry];
    state = state.copyWith(messages: updatedMessages, isLoading: true, lastError: null);

    try {
      // Build history from existing messages (exclude error entries)
      final history = state.messages
          .where((m) => !m.isError)
          .map((m) => m.toAgentMessage())
          .toList();

      final result = await _service.sendMessage(text.trim(), history);

      final agentEntry = ChatEntry(
        role: 'assistant',
        content: result.reply,
        toolCallsMade: result.toolCallsMade,
      );

      state = state.copyWith(
        messages: [...updatedMessages, agentEntry],
        isLoading: false,
        agentOnline: true,
      );
    } on AgentException catch (e) {
      final errEntry = ChatEntry(
        role: 'assistant',
        content: e.message,
        isError: true,
      );
      state = state.copyWith(
        messages: [...updatedMessages, errEntry],
        isLoading: false,
        agentOnline: false,
        lastError: e.message,
      );
    }
  }

  // ── Run optimizer ─────────────────────────────────────────

  Future<OptimizerResult?> runOptimizer() async {
    if (state.isLoading) return null;
    state = state.copyWith(isLoading: true, lastError: null);

    try {
      final userId = SupabaseService.instance.currentUser?.id;
      final result = await _service.runOptimizer(userId: userId);

      final summary =
          '✅ Optimizer ran successfully.\n'
          'Status: ${result.status}\n'
          'Decisions written: ${result.decisionsWritten}\n'
          'Forecasts written: ${result.forecastsWritten}'
          '${result.message != null ? "\n${result.message}" : ""}';

      final agentEntry = ChatEntry(
        role: 'assistant',
        content: summary,
        toolCallsMade: ['run-optimizer'],
      );

      state = state.copyWith(
        messages: [...state.messages, agentEntry],
        isLoading: false,
        agentOnline: true,
      );

      return result;
    } on AgentException catch (e) {
      final errEntry = ChatEntry(
        role: 'assistant',
        content: '❌ Optimizer failed: ${e.message}',
        isError: true,
      );
      state = state.copyWith(
        messages: [...state.messages, errEntry],
        isLoading: false,
        lastError: e.message,
      );
      return null;
    }
  }

  // ── Clear history ─────────────────────────────────────────

  void clearHistory() {
    state = state.copyWith(messages: []);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final agentProvider = StateNotifierProvider<AgentNotifier, AgentState>(
  (ref) => AgentNotifier(),
);
