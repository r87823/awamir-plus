import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/products_screen.dart';
import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class DepartmentsScreen extends StatelessWidget {
  const DepartmentsScreen({
    super.key,
    required this.controller,
    required this.onFinished,
  });

  final AppController controller;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canCreateOrder(controller.currentUser)) {
      return const Scaffold(body: AccessDeniedStateView());
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppHeader(title: 'اختيار الأقسام', compact: true, showBack: true),
          const SizedBox(height: 18),
          const SectionHeader(title: 'الأقسام المتاحة'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.departments.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final department = controller.departments[index];
                return _DepartmentCard(
                  department: department,
                  count: controller.productsForDepartment(department).length,
                  onTap: () {
                    controller.selectDepartment(department);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductsScreen(
                          controller: controller,
                          onFinished: onFinished,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.department,
    required this.count,
    required this.onTap,
  });

  final ProductDepartment department;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  department.icon,
                  color: AppColors.goldLight,
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                department.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$count منتجات',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
