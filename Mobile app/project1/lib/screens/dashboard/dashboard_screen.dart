import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/system_state.dart';
import '../../providers/system_state_provider.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/stale_banner.dart';
import '../../shared/dialogs/emergency_stop_dialog.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(systemStateProvider);
    final connStatus = ref.watch(connectionStatusProvider);

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

          // Main scrollable content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // App Bar
                _DashboardAppBar(connStatus: connStatus),

                // Stale banner
                if (connStatus.isStale)
                  StaleBanner(lastUpdated: connStatus.lastUpdated),

                // Content
                Expanded(
                  child: stateAsync.when(
                    data: (state) => _DashboardBody(state: state),
                    loading: () => const _DashboardSkeleton(),
                    error: (e, _) => _DashboardBody(state: SystemState.mock),
                  ),
                ),
              ],
            ),
          ),

          // Emergency Stop FAB — always accessible
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 100,
            right: 16,
            child: _EmergencyStopFab(),
          ),
        ],
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _DashboardAppBar extends StatelessWidget {
  const _DashboardAppBar({required this.connStatus});
  final ConnectionStatus connStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Logo placeholder
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF0060AC)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'HC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('Home Dashboard', style: AppTextStyles.headlineMd),
          const Spacer(),
          const Icon(Icons.bolt_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          // Live status pill
          _LiveStatusPill(connStatus: connStatus),
        ],
      ),
    );
  }
}

class _LiveStatusPill extends StatefulWidget {
  const _LiveStatusPill({required this.connStatus});
  final ConnectionStatus connStatus;

  @override
  State<_LiveStatusPill> createState() => _LiveStatusPillState();
}

class _LiveStatusPillState extends State<_LiveStatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLive = !widget.connStatus.isStale;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLive
                    ? AppColors.secondaryFixed
                    : AppColors.error,
                boxShadow: [
                  BoxShadow(
                    color: (isLive ? AppColors.secondaryFixed : AppColors.error)
                        .withOpacity(0.4 + 0.4 * _ctrl.value),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isLive
                ? 'Live • ${widget.connStatus.ageLabel}'
                : 'Offline',
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Body ─────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.state});
  final SystemState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        children: [
          _EnergySourceHero(state: state),
          const SizedBox(height: 16),
          _MetricsRow(state: state),
          const SizedBox(height: 20),
          _PowerFlowCard(state: state),
          const SizedBox(height: 16),
          _QuickStatsRow(state: state),
        ],
      ),
    );
  }
}

// ── Hero Card — Current Source ─────────────────────────────────────────────────

class _EnergySourceHero extends StatelessWidget {
  const _EnergySourceHero({required this.state});
  final SystemState state;

  @override
  Widget build(BuildContext context) {
    final isSolar = state.currentPowerSource == 'solar';
    final isBattery = state.currentPowerSource == 'battery';
    final glowColor = isSolar
        ? AppColors.tertiary
        : isBattery
            ? AppColors.secondary
            : AppColors.primary;
    final icon = isSolar
        ? Icons.solar_power_rounded
        : isBattery
            ? Icons.battery_charging_full_rounded
            : Icons.power_rounded;
    final label = isSolar
        ? 'Solar Power'
        : isBattery
            ? 'Battery Power'
            : 'Grid Power';
    final valueKw = (state.solarGenerationW / 1000).toStringAsFixed(1);

    return GlassCard(
      glowColor: glowColor,
      borderRadius: 28,
      padding: const EdgeInsets.all(0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Glow blobs
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glowColor.withOpacity(0.15),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: glowColor, size: 28),
                      const SizedBox(width: 8),
                      Text(label,
                          style: AppTextStyles.headlineMd
                              .copyWith(color: glowColor)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: valueKw,
                          style: AppTextStyles.headlineXl,
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: 'kW',
                          style: AppTextStyles.headlineMd.copyWith(
                              color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Energy Source',
                    style: AppTextStyles.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 3-column Metrics Row ──────────────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.state});
  final SystemState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _BatteryCard(state: state)),
        const SizedBox(width: 12),
        Expanded(child: _SolarCard(solarW: state.solarGenerationW)),
        const SizedBox(width: 12),
        Expanded(child: _GridCard(source: state.currentPowerSource)),
      ],
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.state});
  final SystemState state;

  @override
  Widget build(BuildContext context) {
    final soc = state.batterySocPct / 100;
    final color = soc > 0.5
        ? AppColors.secondaryFixed
        : soc > 0.2
            ? AppColors.tertiary
            : AppColors.error;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(64, 64),
                  painter: _RingPainter(progress: soc, color: color),
                ),
                Text(
                  '${state.batterySocPct.round()}%',
                  style: AppTextStyles.labelMd,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Battery', style: AppTextStyles.labelSm
              .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            'Health: ${state.batteryHealthPct.round()}%',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.secondaryFixed,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 4.0;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _SolarCard extends StatelessWidget {
  const _SolarCard({required this.solarW});
  final double solarW;

  @override
  Widget build(BuildContext context) {
    final kw = solarW / 1000;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tertiary.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.tertiary.withOpacity(0.2),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.light_mode_rounded,
                color: AppColors.tertiaryFixedDim, size: 32),
          ),
          const SizedBox(height: 8),
          Text('Solar',
              style: AppTextStyles.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            '+${kw.toStringAsFixed(1)} kW',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.tertiaryFixedDim),
          ),
        ],
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final isConnected = source == 'grid';
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.power_outlined,
                color: AppColors.primaryFixedDim, size: 32),
          ),
          const SizedBox(height: 8),
          Text('Grid',
              style: AppTextStyles.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            isConnected ? 'Connected' : 'Standby',
            style: AppTextStyles.labelMd
                .copyWith(color: AppColors.primaryFixedDim),
          ),
        ],
      ),
    );
  }
}

// ── Power Flow Card ────────────────────────────────────────────────────────────

class _PowerFlowCard extends StatelessWidget {
  const _PowerFlowCard({required this.state});
  final SystemState state;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Power Flow', style: AppTextStyles.labelMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Live',
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _FlowNode(
                icon: Icons.light_mode_rounded,
                label: 'Solar',
                value: '${(state.solarGenerationW / 1000).toStringAsFixed(1)} kW',
                color: AppColors.tertiary,
              ),
              _FlowArrow(),
              _FlowNode(
                icon: Icons.home_rounded,
                label: 'Home',
                value: '${(state.wholeHousePowerW / 1000).toStringAsFixed(1)} kW',
                color: AppColors.primary,
              ),
              _FlowArrow(),
              _FlowNode(
                icon: Icons.battery_charging_full_rounded,
                label: 'Battery',
                value: '${state.batterySocPct.round()}%',
                color: AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.labelMd.copyWith(color: color)),
        Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

class _FlowArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.arrow_forward_rounded,
        color: AppColors.outlineVariant, size: 20);
  }
}

// ── Quick Stats ────────────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.state});
  final SystemState state;

  @override
  Widget build(BuildContext context) {
    final surplus = state.solarGenerationW - state.wholeHousePowerW;
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      surplus >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: surplus >= 0 ? AppColors.secondary : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text('Energy Balance',
                        style: AppTextStyles.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${surplus >= 0 ? '+' : ''}${(surplus / 1000).toStringAsFixed(1)} kW',
                  style: AppTextStyles.headlineMd.copyWith(
                    color: surplus >= 0 ? AppColors.secondary : AppColors.error,
                  ),
                ),
                Text(
                  surplus >= 0 ? 'Solar surplus' : 'Grid importing',
                  style: AppTextStyles.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      state.automationMode == 'auto'
                          ? Icons.auto_mode_rounded
                          : Icons.pan_tool_rounded,
                      color: state.automationMode == 'auto'
                          ? AppColors.secondary
                          : AppColors.tertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text('AI Mode',
                        style: AppTextStyles.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  state.automationMode == 'auto' ? 'Auto' : 'Manual',
                  style: AppTextStyles.headlineMd.copyWith(
                    color: state.automationMode == 'auto'
                        ? AppColors.secondary
                        : AppColors.tertiary,
                  ),
                ),
                Text(
                  state.automationMode == 'auto'
                      ? 'AI controls active'
                      : 'Approval required',
                  style: AppTextStyles.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Emergency Stop FAB ─────────────────────────────────────────────────────────

class _EmergencyStopFab extends StatefulWidget {
  @override
  State<_EmergencyStopFab> createState() => _EmergencyStopFabState();
}

class _EmergencyStopFabState extends State<_EmergencyStopFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.2 + 0.2 * _ctrl.value),
              blurRadius: 24 + 8 * _ctrl.value,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: GestureDetector(
        onTap: () => EmergencyStopDialog.show(context),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withOpacity(0.15),
            border: Border.all(
              color: AppColors.error.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// ── Skeleton Loader ────────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
