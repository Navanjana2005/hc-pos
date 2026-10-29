import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/system_state_provider.dart';

/// Two-step Emergency Stop confirmation dialog.
/// First tap shows the dialog; second tap (confirm) calls the action.
class EmergencyStopDialog extends ConsumerWidget {
  const EmergencyStopDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: const Icon(
        Icons.power_settings_new_rounded,
        color: AppColors.error,
        size: 48,
      ),
      title: Text(
        'Emergency Stop',
        style: AppTextStyles.headlineMd.copyWith(color: AppColors.error),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This will immediately halt ALL automated power actions and disconnect from the grid.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorContainer.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.tertiary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Critical appliances (refrigerator, medical) may be affected.',
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error.withOpacity(0.2),
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await ref
                  .read(systemStateProvider.notifier)
                  .triggerEmergencyStop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Emergency Stop activated.',
                      style: AppTextStyles.labelMd
                          .copyWith(color: AppColors.error),
                    ),
                    backgroundColor: AppColors.errorContainer,
                  ),
                );
              }
            },
            child: Text(
              'CONFIRM EMERGENCY STOP',
              style: AppTextStyles.labelMd
                  .copyWith(color: AppColors.error, letterSpacing: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const EmergencyStopDialog(),
      );
}
