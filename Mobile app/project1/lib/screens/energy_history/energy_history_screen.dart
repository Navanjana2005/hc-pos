import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/telemetry_point.dart';
import '../../providers/telemetry_provider.dart';
import '../../shared/widgets/glass_card.dart';

/// Selected time range state, scoped to Energy History screen.
final _selectedRangeProvider = StateProvider<TimeRange>((ref) => TimeRange.day);

class EnergyHistoryScreen extends ConsumerWidget {
  const EnergyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(_selectedRangeProvider);

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1A237E), Color(0xFF0060AC)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                            child: Text('HC',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 12),
                      Text('Energy History', style: AppTextStyles.headlineMd),
                      const Spacer(),
                      const Icon(Icons.bolt_rounded, color: AppColors.primary),
                    ],
                  ),
                ),
                // Time range selector
                _TimeRangeSelector(selected: range),
                const SizedBox(height: 8),
                // Charts
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    child: Column(
                      children: [
                        _EnergyFlowChart(range: range),
                        const SizedBox(height: 16),
                        _ForecastAccuracyChart(range: range),
                        const SizedBox(height: 16),
                        _SummaryCards(range: range),
                      ],
                    ),
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

// ── Time Range Selector ────────────────────────────────────────────────────────

class _TimeRangeSelector extends ConsumerWidget {
  const _TimeRangeSelector({required this.selected});
  final TimeRange selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer.withOpacity(0.6),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: TimeRange.values.map((r) {
            final isSelected = r == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () =>
                    ref.read(_selectedRangeProvider.notifier).state = r,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.tertiary.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    border: isSelected
                        ? Border.all(color: AppColors.tertiary.withOpacity(0.4))
                        : null,
                  ),
                  child: Text(
                    r.name[0].toUpperCase() + r.name.substring(1),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelMd.copyWith(
                      color: isSelected
                          ? AppColors.tertiary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Energy Flow Chart ─────────────────────────────────────────────────────────

class _EnergyFlowChart extends ConsumerWidget {
  const _EnergyFlowChart({required this.range});
  final TimeRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solarAsync = ref.watch(solarTelemetryProvider(range));
    final usageAsync = ref.watch(consumptionTelemetryProvider(range));

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Energy Flow', style: AppTextStyles.headlineMd),
                  Text(
                    range == TimeRange.day
                        ? "Today's Balance"
                        : range == TimeRange.week
                            ? "This Week"
                            : "This Month",
                    style: AppTextStyles.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.light_mode_rounded,
                        color: AppColors.tertiary, size: 14),
                    const SizedBox(width: 4),
                    Text('42 kWh',
                        style: AppTextStyles.labelMd
                            .copyWith(color: AppColors.onSurface)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            children: [
              _LegendDot(color: AppColors.tertiary, label: 'Solar'),
              const SizedBox(width: 16),
              _LegendDot(color: AppColors.primary, label: 'Usage'),
            ],
          ),
          const SizedBox(height: 20),
          // Chart
          SizedBox(
            height: 200,
            child: solarAsync.when(
              data: (solar) => usageAsync.when(
                data: (usage) => _buildLineChart(solar, usage),
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
                error: (_, __) =>
                    const Center(child: Text('Error loading chart')),
              ),
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) =>
                  const Center(child: Text('Error loading chart')),
            ),
          ),
          const SizedBox(height: 8),
          // X-axis labels
          _XAxisLabels(range: range),
        ],
      ),
    );
  }

  Widget _buildLineChart(
      List<TelemetryPoint> solar, List<TelemetryPoint> usage) {
    if (solar.isEmpty && usage.isEmpty) {
      return const Center(
          child: Text('No data',
              style: TextStyle(color: AppColors.onSurfaceVariant)));
    }

    FlSpot toSpot(TelemetryPoint p, int i) =>
        FlSpot(i.toDouble(), p.value / 1000);

    final solarSpots =
        solar.asMap().entries.map((e) => toSpot(e.value, e.key)).toList();
    final usageSpots =
        usage.asMap().entries.map((e) => toSpot(e.value, e.key)).toList();
    final maxY = [
      ...solarSpots.map((s) => s.y),
      ...usageSpots.map((s) => s.y),
    ].fold<double>(0, (prev, e) => e > prev ? e : prev);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY * 1.2,
        lineBarsData: [
          // Solar line
          LineChartBarData(
            spots: solarSpots,
            isCurved: true,
            color: AppColors.tertiary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.tertiary.withOpacity(0.25),
                  AppColors.tertiary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Usage line
          LineChartBarData(
            spots: usageSpots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceContainerHighest,
            getTooltipItems: (spots) => spots.map((s) {
              final isSolar = s.barIndex == 0;
              return LineTooltipItem(
                '${s.y.toStringAsFixed(1)} kW',
                TextStyle(
                  color: isSolar ? AppColors.tertiary : AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

class _XAxisLabels extends StatelessWidget {
  const _XAxisLabels({required this.range});
  final TimeRange range;

  @override
  Widget build(BuildContext context) {
    final labels = range == TimeRange.day
        ? ['6AM', '12PM', '6PM']
        : range == TimeRange.week
            ? ['Mon', 'Wed', 'Fri', 'Sun']
            : ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map((l) => Text(l,
              style: AppTextStyles.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant)))
          .toList(),
    );
  }
}

// ── Forecast Accuracy Chart ────────────────────────────────────────────────────

class _ForecastAccuracyChart extends ConsumerWidget {
  const _ForecastAccuracyChart({required this.range});
  final TimeRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(forecastsProvider('consumption'));

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Forecast Accuracy', style: AppTextStyles.headlineMd),
          Text('Predicted vs Actual Load',
              style: AppTextStyles.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          // Legend
          Row(
            children: [
              _LegendLine(
                  color: AppColors.secondary, dashed: false, label: 'Actual'),
              const SizedBox(width: 16),
              _LegendLine(
                  color: AppColors.onSurfaceVariant,
                  dashed: true,
                  label: 'Forecast'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: forecastAsync.when(
              data: (forecasts) => _buildForecastChart(forecasts),
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary)),
              error: (_, __) =>
                  const Center(child: Text('Error loading forecasts')),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Now', '+2h', '+4h', '+6h']
                .map((l) => Text(l,
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastChart(forecasts) {
    if (forecasts.isEmpty) {
      return const Center(child: Text('No forecasts'));
    }

    final allSpots = <FlSpot>[];
    final actualSpots = <FlSpot>[];
    final predictedSpots = <FlSpot>[];

    for (int i = 0; i < forecasts.length; i++) {
      final f = forecasts[i];
      // Forecast values are stored in kW, matching the chart's axis units.
      predictedSpots.add(FlSpot(i.toDouble(), f.predictedValue));
      if (f.actualValue != null) {
        actualSpots.add(FlSpot(i.toDouble(), f.actualValue!));
      }
    }

    final maxY = [
      ...predictedSpots.map((s) => s.y),
      ...actualSpots.map((s) => s.y)
    ].fold<double>(0, (prev, e) => e > prev ? e : prev);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY * 1.3,
        lineBarsData: [
          // Actual (solid green)
          if (actualSpots.isNotEmpty)
            LineChartBarData(
              spots: actualSpots,
              isCurved: true,
              color: AppColors.secondary,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.secondary,
                  strokeWidth: 2,
                  strokeColor: AppColors.surfaceContainerHigh,
                ),
              ),
            ),
          // Predicted (dashed grey)
          LineChartBarData(
            spots: predictedSpots,
            isCurved: true,
            color: AppColors.onSurfaceVariant.withOpacity(0.6),
            barWidth: 1.5,
            isStrokeCapRound: true,
            dashArray: [6, 4],
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({
    required this.color,
    required this.dashed,
    required this.label,
  });
  final Color color;
  final bool dashed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 2,
          decoration: BoxDecoration(
            color: dashed ? null : color,
            border: dashed ? Border.all(color: color, width: 1.5) : null,
          ),
          child: dashed ? null : null,
        ),
        const SizedBox(width: 6),
        Text(label,
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

// ── Summary Cards ─────────────────────────────────────────────────────────────

class _SummaryCards extends ConsumerWidget {
  const _SummaryCards({required this.range});
  final TimeRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    const Icon(Icons.light_mode_rounded,
                        color: AppColors.tertiary, size: 18),
                    const SizedBox(width: 6),
                    Text('Solar Generated',
                        style: AppTextStyles.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('42.3 kWh',
                    style: AppTextStyles.headlineMd
                        .copyWith(color: AppColors.tertiary)),
                Text(range == TimeRange.day ? 'Today' : range.name,
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
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
                    const Icon(Icons.home_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text('Consumed',
                        style: AppTextStyles.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('38.1 kWh',
                    style: AppTextStyles.headlineMd
                        .copyWith(color: AppColors.primary)),
                Text(range == TimeRange.day ? 'Today' : range.name,
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
