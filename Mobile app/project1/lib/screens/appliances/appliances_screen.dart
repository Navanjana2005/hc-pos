import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/appliance.dart';
import '../../providers/appliances_provider.dart';
import '../../providers/system_state_provider.dart';
import '../../shared/widgets/glass_card.dart';

class AppliancesScreen extends ConsumerWidget {
  const AppliancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appliancesAsync = ref.watch(appliancesProvider);
    final stateAsync = ref.watch(systemStateProvider);
    final source = stateAsync.valueOrNull?.currentPowerSource ?? 'grid';

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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Appliances', style: AppTextStyles.headlineMd),
                          Text('Sockets', style: AppTextStyles.headlineMd),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.bolt_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      // Source indicator
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Icon(
                                source == 'solar' ? Icons.light_mode_rounded : Icons.power_rounded,
                                color: source == 'solar' ? AppColors.tertiary : AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '100%',
                                style: AppTextStyles.labelMd.copyWith(
                                  color: source == 'solar' ? AppColors.tertiary : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            source[0].toUpperCase() + source.substring(1),
                            style: AppTextStyles.labelSm.copyWith(
                              color: source == 'solar' ? AppColors.tertiary : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Active loads and socket control',
                    style: AppTextStyles.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 16),
                // Grid
                Expanded(
                  child: appliancesAsync.when(
                    data: (appliances) => GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: appliances.length,
                      itemBuilder: (context, i) =>
                          _ApplianceCard(appliance: appliances[i]),
                    ),
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
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

// ── Appliance Card ────────────────────────────────────────────────────────────

class _ApplianceCard extends ConsumerWidget {
  const _ApplianceCard({required this.appliance});
  final Appliance appliance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = appliance;
    final (priorityColor, priorityLabel) = _priorityStyle(a.priorityLevel);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + priority badge
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHigh,
                ),
                child: Icon(_nilmIcon(a.nilmPredictedType),
                    color: AppColors.onSurfaceVariant, size: 22),
              ),
              const Spacer(),
              _PriorityBadge(label: priorityLabel, color: priorityColor),
            ],
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            a.applianceName,
            style: AppTextStyles.headlineLgMobile.copyWith(fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${a.ratedPowerW != null ? '${a.ratedPowerW!.toInt()}W' : '0W'} • ${a.roomLocation ?? 'Unknown'}',
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const Spacer(),
          // Toggle row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                a.isOn ? 'ON' : 'OFF',
                style: AppTextStyles.labelMd.copyWith(
                  color: a.isOn ? AppColors.secondary : AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onLongPress: a.isControllable
                    ? () => _showPrioritySheet(context, ref, a)
                    : null,
                child: Switch(
                  value: a.isOn,
                  onChanged: a.isControllable
                      ? (val) => ref
                          .read(appliancesProvider.notifier)
                          .toggleAppliance(a.applianceId, val)
                      : null,
                  activeColor: AppColors.secondaryFixed,
                  inactiveThumbColor: AppColors.onSurfaceVariant,
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.secondary.withOpacity(0.4);
                    }
                    return AppColors.surfaceContainerHighest;
                  }),
                ),
              ),
            ],
          ),
          // NILM type label
          if (a.nilmPredictedType != null)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                _nilmLabel(a.nilmPredictedType!),
                style: AppTextStyles.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  void _showPrioritySheet(
      BuildContext context, WidgetRef ref, Appliance appliance) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _PrioritySheet(appliance: appliance),
    );
  }

  (Color, String) _priorityStyle(int level) {
    switch (level) {
      case 1: return (AppColors.error, 'Critical');
      case 2: return (AppColors.error, 'High');
      case 3: return (AppColors.tertiary, 'Med');
      case 4: return (AppColors.primary, 'Low');
      case 5: return (AppColors.onSurfaceVariant, 'Stby');
      default: return (AppColors.tertiary, 'Med');
    }
  }

  IconData _nilmIcon(String? type) {
    switch (type) {
      case 'refrigerator': return Icons.kitchen_rounded;
      case 'air_conditioner': return Icons.ac_unit_rounded;
      case 'washing_machine': return Icons.local_laundry_service_rounded;
      case 'ev_charger': return Icons.ev_station_rounded;
      case 'lighting': return Icons.lightbulb_rounded;
      default: return Icons.electrical_services_rounded;
    }
  }

  String _nilmLabel(String type) {
    return type.replaceAll('_', ' ');
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _PrioritySheet extends ConsumerWidget {
  const _PrioritySheet({required this.appliance});
  final Appliance appliance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Priority Level', style: AppTextStyles.headlineMd),
          Text('${appliance.applianceName} • Long press card to change',
              style: AppTextStyles.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 20),
          ...List.generate(5, (i) {
            final level = i + 1;
            final (color, label) = _style(level);
            final isSelected = appliance.priorityLevel == level;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? color : AppColors.outlineVariant),
                ),
                child: Center(child: Text('$level',
                    style: TextStyle(color: isSelected ? color : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w700))),
              ),
              title: Text(label,
                  style: AppTextStyles.labelMd.copyWith(
                    color: isSelected ? color : AppColors.onSurface)),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: color)
                  : null,
              onTap: () {
                ref.read(appliancesProvider.notifier)
                    .updatePriority(appliance.applianceId, level);
                Navigator.of(context).pop();
              },
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  (Color, String) _style(int level) {
    switch (level) {
      case 1: return (AppColors.error, 'Critical — Never shut off');
      case 2: return (AppColors.error, 'High — Only in emergency');
      case 3: return (AppColors.tertiary, 'Medium — Standard priority');
      case 4: return (AppColors.primary, 'Low — Defer when needed');
      case 5: return (AppColors.onSurfaceVariant, 'Standby — Shut off freely');
      default: return (AppColors.tertiary, 'Medium');
    }
  }
}
