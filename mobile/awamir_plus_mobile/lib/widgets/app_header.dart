import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.title,
    this.subtitle,
    this.compact = false,
    this.showBack = false,
    this.onBack,
    this.notificationCount = 0,
    this.onNotificationTap,
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final bool compact;
  final bool showBack;
  final VoidCallback? onBack;
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        compact ? 24 : 44,
        20,
        compact ? 20 : 28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.navy, AppColors.navyDark],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeaderPatternPainter())),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBack)
                Row(
                  children: [
                    _HeaderIconButton(
                      icon: Icons.arrow_forward,
                      onTap: onBack ?? () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title ?? '',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                )
              else
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [AppColors.gold, AppColors.goldDark],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'أ',
                          style: TextStyle(
                            color: AppColors.navyDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title ?? 'مرحباً، أحمد الراجحي',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle ?? 'فرع الرياض — المروج',
                            style: const TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onNotificationTap != null)
                      _HeaderIconButton(
                        icon: Icons.notifications,
                        badge: notificationCount,
                        onTap: onNotificationTap,
                      ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, this.badge = 0, this.onTap});

  final IconData icon;
  final int badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(icon, color: AppColors.white, size: 21),
          ),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (double x = 8; x < size.width; x += 58) {
      for (double y = 4; y < size.height; y += 52) {
        canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y), paint);
        canvas.drawLine(Offset(x, y - 5), Offset(x, y + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
