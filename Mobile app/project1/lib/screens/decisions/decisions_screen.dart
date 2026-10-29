import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/decision.dart';
import '../../models/system_state.dart';
import '../../providers/decisions_provider.dart';
import '../../providers/system_state_provider.dart';
import '../../shared/widgets/glass_card.dart';

class DecisionsScreen extends ConsumerWidget {
  const DecisionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(decisionsProvider);
    final stateAsync = ref.watch(systemStateProvider);
    final automationMode = stateAsync.valueOrNull?.automationMode ?? 'auto';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
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
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0060AC)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(child: Text('HC', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 12),
                      Text('Decisions Feed', style: AppTextStyles.headlineMd),
                      const Spacer(),
                      // Automation mode pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: automationMode == 'auto'
                              ? AppColors.secondary.withOpacity(0.15)
                              : AppColors.tertiary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: automationMode == 'auto'
                                ? AppColors.secondary.withOpacity(0.4)
                                : AppColors.tertiary.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          automationMode == 'auto' ? 'Auto' : 'Manual',
                          style: AppTextStyles.labelSm.copyWith(
                            color: automationMode == 'auto'
                                ? AppColors.secondary
                                : AppColors.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // List
                Expanded(
                  child: decisionsAsync.when(
                    data: (decisions) => decisions.isEmpty
                        ? _EmptyDecisions()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                            itemCount: decisions.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DecisionCard(
                                decision: decisions[i],
                                automationMode: automationMode,
                              ),
                            ),
                          ),
                    loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (_, __) => const Center(child: Text('Error')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decision Card ──────────────────────────────────────────────────────────────

class _DecisionCard extends ConsumerStatefulWidget {
  const _DecisionCard({
    required this.decision,
    required this.automationMode,
  });
  final Decision decision;
  final String automationMode;

  @override
  ConsumerState<_DecisionCard> createState() => _DecisionCardState();
}

class _DecisionCardState extends ConsumerState<_DecisionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.decision;
    final showApprovalButtons =
        d.status == DecisionStatus.proposed && widget.automationMode == 'manual_approval';

    final (typeColor, typeIcon) = _decisionStyle(d.decisionType);

    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          // Main card content
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: typeColor.withOpacity(0.15),
                          border: Border.all(color: typeColor.withOpacity(0.3)),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      // Title + summary
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(d.displayTitle,
                                      style: AppTextStyles.labelMd.copyWith(
                                          fontWeight: FontWeight.w700)),
                                ),
                                Text(
                                  _timeAgo(d.createdAt),
                                  style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d.reasoningSummary,
                              style: AppTextStyles.bodyMd.copyWith(
                                  color: AppColors.onSurfaceVariant),
                              maxLines: _expanded ? null : 2,
                              overflow: _expanded
                                  ? null
                                  : TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Status chip + target
                  Row(
                    children: [
                      _StatusChip(status: d.status),
                      if (d.targetApplianceName != null ||
                          d.targetDeviceName != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.device_hub_rounded,
                            size: 14,
                            color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          d.targetApplianceName ?? d.targetDeviceName ?? '',
                          style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant),
                        ),
                      ],
                      const Spacer(),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.onSurfaceVariant,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded reasoning panel
          if (_expanded) ...[
            Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.white.withOpacity(0.08)),
            _ReasoningPanel(reasoning: d.reasoning),
          ],

          // Approve / Reject buttons
          if (showApprovalButtons) ...[
            Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.white.withOpacity(0.08)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  // Approve
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: AppColors.onSecondary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                      onPressed: () => ref
                          .read(decisionsProvider.notifier)
                          .approveDecision(d.id),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reject
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.outlineVariant),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      onPressed: () => ref
                          .read(decisionsProvider.notifier)
                          .rejectDecision(d.id),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData) _decisionStyle(DecisionType type) {
    switch (type) {
      case DecisionType.switchToSolar:
        return (AppColors.tertiary, Icons.solar_power_rounded);
      case DecisionType.chargeBattery:
        return (AppColors.secondary, Icons.battery_charging_full_rounded);
      case DecisionType.disableAppliance:
        return (AppColors.error, Icons.outlet_rounded);
      case DecisionType.postponeLoad:
        return (AppColors.primary, Icons.schedule_rounded);
      case DecisionType.sendAlert:
        return (AppColors.tertiary, Icons.notifications_rounded);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ── Reasoning Panel ───────────────────────────────────────────────────────────

class _ReasoningPanel extends StatelessWidget {
  const _ReasoningPanel({required this.reasoning});
  final Map<String, dynamic> reasoning;

  @override
  Widget build(BuildContext context) {
    final factors = reasoning['factors'] as List<dynamic>?;
    final confidence = reasoning['confidence'] as num?;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surfaceLow.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text('AI Reasoning',
                  style: AppTextStyles.labelSm
                      .copyWith(color: AppColors.primary)),
              const Spacer(),
              if (confidence != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${(confidence * 100).round()}% confidence',
                    style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.secondary),
                  ),
                ),
            ],
          ),
          if (factors != null && factors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Key Factors:',
                style: AppTextStyles.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 6),
            ...factors.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(right: 8, top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.7),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          f.toString(),
                          style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ── Status Chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final DecisionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = switch (status) {
      DecisionStatus.proposed  => (AppColors.tertiary, AppColors.tertiary.withOpacity(0.15)),
      DecisionStatus.approved  => (AppColors.secondary, AppColors.secondary.withOpacity(0.15)),
      DecisionStatus.rejected  => (AppColors.error, AppColors.error.withOpacity(0.15)),
      DecisionStatus.executed  => (AppColors.secondary, AppColors.secondary.withOpacity(0.15)),
      DecisionStatus.confirmed => (AppColors.secondary, AppColors.secondary.withOpacity(0.1)),
      DecisionStatus.failed    => (AppColors.error, AppColors.error.withOpacity(0.15)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status.label,
          style: AppTextStyles.labelSm.copyWith(color: color)),
    );
  }
}

class _EmptyDecisions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology_outlined,
              color: AppColors.onSurfaceVariant, size: 48),
          const SizedBox(height: 12),
          Text('No decisions yet',
              style: AppTextStyles.headlineMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('The AI will propose decisions as system conditions change.',
              style: AppTextStyles.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
