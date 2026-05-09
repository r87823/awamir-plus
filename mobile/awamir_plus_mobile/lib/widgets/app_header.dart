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
    if (AppHeaderScope.suppressesEmbeddedHeaders(context)) {
      return const SizedBox.shrink();
    }

    const headerRadius = Radius.circular(28);
    final headerHeight = compact ? 92.0 : 124.0;
    final horizontalPadding = compact ? 16.0 : 20.0;
    final bottomPadding = compact ? 8.0 : 6.0;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: headerRadius),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.navy, AppColors.navyDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyDark.withValues(alpha: 0.24),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: headerHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _HeaderPatternPainter()),
              ),
              PositionedDirectional(
                start: horizontalPadding,
                end: horizontalPadding,
                bottom: bottomPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title ?? 'مرحباً، أحمد الراجحي',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  height: 1.2,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.gold.withValues(alpha: 0),
                                        AppColors.gold.withValues(alpha: 0.9),
                                        AppColors.gold.withValues(alpha: 0.2),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  subtitle ?? 'فرع الرياض — المروج',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.goldLight,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: 10),
                            trailing!,
                          ],
                          if (onNotificationTap != null) ...[
                            const SizedBox(width: 10),
                            _HeaderIconButton(
                              icon: Icons.notifications,
                              badge: notificationCount,
                              onTap: onNotificationTap,
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppHeaderScope extends InheritedWidget {
  const AppHeaderScope({
    super.key,
    required this.suppressEmbeddedHeaders,
    required super.child,
  });

  final bool suppressEmbeddedHeaders;

  static bool suppressesEmbeddedHeaders(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppHeaderScope>()
            ?.suppressEmbeddedHeaders ??
        false;
  }

  @override
  bool updateShouldNotify(covariant AppHeaderScope oldWidget) {
    return suppressEmbeddedHeaders != oldWidget.suppressEmbeddedHeaders;
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
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
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
