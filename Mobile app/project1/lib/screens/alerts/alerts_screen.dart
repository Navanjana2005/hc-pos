import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/alert.dart';
import '../../providers/alerts_provider.dart';
import '../../shared/widgets/glass_card.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

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
                      Text('System Alerts', style: AppTextStyles.headlineMd),
                      const Spacer(),
                      TextButton(
                        onPressed: () => ref.read(alertsProvider.notifier).acknowledgeAll(),
                        child: Text(
                          'Mark all read',
                          style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                // List
                Expanded(
                  child: alertsAsync.when(
                    data: (alerts) => alerts.isEmpty
                        ? _EmptyAlerts()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                            itemCount: alerts.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AlertCard(alert: alerts[i]),
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

// ── Alert Card ───────────────────────────────────────────────────────────────

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert});
  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (iconColor, icon, title) = _alertStyle(alert);
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withOpacity(0.15),
                  border: Border.all(color: iconColor.withOpacity(0.3)),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(alert.createdAt),
                          style: AppTextStyles.labelSm.copyWith(
                            color: alert.acknowledged ? AppColors.onSurfaceVariant : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert.message,
                      style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!alert.acknowledged) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurface,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Acknowledge'),
                onPressed: () => ref.read(alertsProvider.notifier).acknowledge(alert.id),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData, String) _alertStyle(Alert alert) {
    switch (alert.alertType) {
      case 'battery_low':
        return (AppColors.error, Icons.battery_alert_rounded, 'Battery Low: 15%');
      case 'high_grid_usage':
        return (AppColors.tertiary, Icons.bolt_rounded, 'High Grid Usage Detected');
      case 'solar_forecast':
        return (AppColors.primary, Icons.light_mode_rounded, 'Solar Forecast: Bright');
      default:
        switch (alert.severity) {
          case AlertSeverity.critical: return (AppColors.error, Icons.warning_rounded, 'Critical Alert');
          case AlertSeverity.warning:  return (AppColors.tertiary, Icons.warning_amber_rounded, 'Warning');
          default:                     return (AppColors.primary, Icons.info_outline_rounded, 'System Info');
        }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _EmptyAlerts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_none_rounded,
              color: AppColors.onSurfaceVariant, size: 48),
          const SizedBox(height: 12),
          Text('No new alerts',
              style: AppTextStyles.headlineMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text("You're all caught up.",
              style: AppTextStyles.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
