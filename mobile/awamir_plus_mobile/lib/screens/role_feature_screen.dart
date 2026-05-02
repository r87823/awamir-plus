import 'package:flutter/material.dart';

import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';

class RoleFeatureScreen extends StatelessWidget {
  const RoleFeatureScreen({
    super.key,
    required this.user,
    required this.feature,
  });

  final AppUser user;
  final AppFeature feature;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canAccessFeature(user, feature)) {
      return const AccessDeniedStateView();
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppHeader(title: feature.label, subtitle: user.role.label),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(feature.icon, color: AppColors.goldLight),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.label,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'واجهة جاهزة للصلاحيات وسيتم ربط بياناتها لاحقاً عبر ERPNext',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
