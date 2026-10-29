import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/agent_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(agentProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _runOptimizer() async {
    await ref.read(agentProvider.notifier).runOptimizer();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final agentState = ref.watch(agentProvider);
    final messages = agentState.messages;

    // Auto-scroll when new messages arrive
    if (messages.isNotEmpty) {
      _scrollToBottom(animate: _hasScrolledToBottom);
      _hasScrolledToBottom = true;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.8),
                  radius: 1.2,
                  colors: [Color(0xFF1A237E), Color(0xFF0B1326)],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(isOnline: agentState.agentOnline, isLoading: agentState.isLoading),
                const SizedBox(height: 4),
                _QuickActions(
                  isLoading: agentState.isLoading,
                  onRunOptimizer: _runOptimizer,
                  onClear: () => ref.read(agentProvider.notifier).clearHistory(),
                ),
                // Message list
                Expanded(
                  child: messages.isEmpty
                      ? _EmptyState(onPromptTap: (p) {
                          _controller.text = p;
                          _send();
                        })
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: messages.length + (agentState.isLoading ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == messages.length) {
                              return const _TypingIndicator();
                            }
                            return _MessageBubble(entry: messages[i]);
                          },
                        ),
                ),
                // Input bar
                _InputBar(
                  controller: _controller,
                  isLoading: agentState.isLoading,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isOnline, required this.isLoading});
  final bool isOnline;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0060AC)]),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12)],
            ),
            child: const Center(
              child: Text('HC', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Genesis AI', style: AppTextStyles.headlineMd),
              Text('Power Orchestration Assistant',
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const Spacer(),
          _OnlinePill(isOnline: isOnline, isLoading: isLoading),
        ],
      ),
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill({required this.isOnline, required this.isLoading});
  final bool isOnline;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final color = isLoading
        ? AppColors.tertiary
        : isOnline
            ? AppColors.secondary
            : AppColors.error;
    final label = isLoading ? 'Thinking...' : isOnline ? 'Online' : 'Offline';
    final icon = isLoading
        ? Icons.more_horiz_rounded
        : isOnline
            ? Icons.psychology_rounded
            : Icons.cloud_off_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.isLoading,
    required this.onRunOptimizer,
    required this.onClear,
  });
  final bool isLoading;
  final VoidCallback onRunOptimizer;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: '⚡ Run Optimizer',
            onTap: isLoading ? null : onRunOptimizer,
            color: AppColors.tertiary,
          ),
          const SizedBox(width: 8),
          _Chip(label: '🗑 Clear Chat', onTap: isLoading ? null : onClear),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap, this.color});
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: c.withOpacity(onTap != null ? 0.4 : 0.15)),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: onTap != null ? c : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.entry});
  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _AvatarIcon(isError: entry.isError),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF0060AC), Color(0xFF1A237E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser
                        ? null
                        : entry.isError
                            ? AppColors.error.withOpacity(0.12)
                            : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: entry.isError
                                ? AppColors.error.withOpacity(0.3)
                                : Colors.white.withOpacity(0.08),
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? AppColors.primary.withOpacity(0.3)
                            : Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    entry.content,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: isUser
                          ? Colors.white
                          : entry.isError
                              ? AppColors.error
                              : Colors.white.withOpacity(0.92),
                      height: 1.5,
                    ),
                  ),
                ),
                // Tool calls badge
                if (entry.toolCallsMade.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: entry.toolCallsMade.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '🔧 $t',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _AvatarIcon extends StatelessWidget {
  const _AvatarIcon({required this.isError});
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isError ? AppColors.error.withOpacity(0.15) : AppColors.primary.withOpacity(0.15),
        border: Border.all(
          color: isError ? AppColors.error.withOpacity(0.3) : AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Icon(
        isError ? Icons.error_outline_rounded : Icons.auto_awesome_rounded,
        color: isError ? AppColors.error : AppColors.primary,
        size: 16,
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true, period: Duration(milliseconds: 600 + i * 150)),
    );
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0, end: 6).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
    // Stagger start
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _controllers[1].forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controllers[2].forward();
    });
    _controllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const _AvatarIcon(isError: false),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _anims[i],
                  builder: (context, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.translate(
                        offset: Offset(0, -_anims[i].value),
                        child: Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.7),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPromptTap});
  final void Function(String prompt) onPromptTap;

  static const _prompts = [
    "What's today's power schedule?",
    "Which appliances are detected right now?",
    "How much will I save today?",
    "Why did the optimizer fail?",
    "Predict next 24h consumption",
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 30),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 40),
          ),
        ),
        const SizedBox(height: 24),
        Text('Genesis AI', style: AppTextStyles.headlineMd, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Ask me about your energy schedule, appliances, costs, or battery status.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Text(
          'Try asking:',
          style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        ..._prompts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onPromptTap(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.send_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p, style: AppTextStyles.bodyMd.copyWith(color: Colors.white.withOpacity(0.85))),
                      ),
                    ],
                  ),
                ),
              ),
            )),
        const SizedBox(height: 120),
      ],
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1326).withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: controller,
                enabled: !isLoading,
                style: AppTextStyles.bodyMd.copyWith(color: Colors.white),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: isLoading ? 'Genesis is thinking...' : 'Ask Genesis AI...',
                  hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isLoading ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isLoading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF0060AC), Color(0xFF1A237E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isLoading ? Colors.white.withOpacity(0.07) : null,
                boxShadow: isLoading
                    ? null
                    : [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12)],
              ),
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
