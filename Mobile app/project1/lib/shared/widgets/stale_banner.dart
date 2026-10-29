import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Animated banner that slides in when the connection is lost.
class StaleBanner extends StatefulWidget {
  const StaleBanner({super.key, required this.lastUpdated});
  final DateTime? lastUpdated;

  @override
  State<StaleBanner> createState() => _StaleBannerState();
}

class _StaleBannerState extends State<StaleBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.errorContainer.withOpacity(0.85),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Connection lost · Showing last known data',
                style: AppTextStyles.labelSm.copyWith(color: AppColors.error),
              ),
            ),
            if (widget.lastUpdated != null)
              Text(
                _age(widget.lastUpdated!),
                style:
                    AppTextStyles.labelSm.copyWith(color: AppColors.onErrorContainer),
              ),
          ],
        ),
      ),
    );
  }

  String _age(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
