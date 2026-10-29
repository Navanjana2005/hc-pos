import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/system_state_provider.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/dialogs/emergency_stop_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      Text('Settings', style: AppTextStyles.headlineMd),
                      const Spacer(),
                      const Icon(Icons.bolt_rounded, color: AppColors.primary),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(title: 'AUTOMATION'),
                        const _EnergyControlModeCard(),
                        const SizedBox(height: 32),
                        
                        _SectionHeader(title: 'PREFERENCES'),
                        const _PreferencesList(),
                        const SizedBox(height: 32),
                        
                        _SectionHeader(title: 'SYSTEM CONTROL'),
                        const _EmergencyStopCard(),
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

// ── Headers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Energy Control Mode (Auto / Manual) ──────────────────────────────────────

class _EnergyControlModeCard extends ConsumerWidget {
  const _EnergyControlModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(systemStateProvider);
    final automationMode = stateAsync.valueOrNull?.automationMode ?? 'auto';

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Energy Control Mode', style: AppTextStyles.headlineMd),
          const SizedBox(height: 8),
          Text(
            'Choose how HC-POS manages power distribution.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withOpacity(0.5),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _ModeSegment(
                    label: 'Manual',
                    isSelected: automationMode == 'manual_approval',
                    onTap: () => ref.read(systemStateProvider.notifier).updateAutomationMode('manual_approval'),
                  ),
                ),
                Expanded(
                  child: _ModeSegment(
                    label: 'Auto',
                    isSelected: automationMode == 'auto',
                    onTap: () => ref.read(systemStateProvider.notifier).updateAutomationMode('auto'),
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

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelMd.copyWith(
            color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Preferences List ─────────────────────────────────────────────────────────

class _PreferencesList extends StatelessWidget {
  const _PreferencesList();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ListTile(
            icon: Icons.sort_rounded,
            title: 'Appliance Priorities',
            color: AppColors.tertiary,
            onTap: () {},
          ),
          Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.05)),
          _ListTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notification Settings',
            color: AppColors.primary,
            onTap: () {},
          ),
          Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.05)),
          _ListTile(
            icon: Icons.hub_outlined,
            title: 'Smart Home Link',
            color: AppColors.secondary,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Text(
                'Connected',
                style: AppTextStyles.labelSm.copyWith(color: AppColors.secondary),
              ),
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.icon,
    required this.title,
    required this.color,
    this.trailing,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final Color color;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: AppTextStyles.bodyLg),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 12),
            ],
            Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Emergency Stop ───────────────────────────────────────────────────────────

class _EmergencyStopCard extends StatelessWidget {
  const _EmergencyStopCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => EmergencyStopDialog.show(context),
          borderRadius: BorderRadius.circular(24),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.power_settings_new_rounded, color: AppColors.error, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Emergency Stop',
                  style: AppTextStyles.headlineMd.copyWith(color: AppColors.error),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Instantly halts all non-critical power flow and disconnects from the grid.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
