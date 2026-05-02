import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: colors.$2,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  (Color, Color) _colorsForStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return (const Color(0xFFECEFF1), const Color(0xFF455A64));
      case OrderStatus.pendingSupervisorApproval:
        return (const Color(0xFFFFF8E1), AppColors.goldDark);
      case OrderStatus.pending:
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
      case OrderStatus.sentToDistribution:
        return (const Color(0xFFE3F2FD), const Color(0xFF1565C0));
      case OrderStatus.sentToProduction:
        return (const Color(0xFFEDE7F6), const Color(0xFF5E35B1));
      case OrderStatus.inProduction:
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
      case OrderStatus.productionCompleted:
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case OrderStatus.readyForPickup:
        return (const Color(0xFFE0F2F1), const Color(0xFF00695C));
      case OrderStatus.readyForDelivery:
        return (const Color(0xFFE3F2FD), const Color(0xFF1565C0));
      case OrderStatus.assignedToDriver:
        return (const Color(0xFFEDE7F6), const Color(0xFF5E35B1));
      case OrderStatus.driverPickedUp:
        return (const Color(0xFFE0F2F1), const Color(0xFF00695C));
      case OrderStatus.outForDelivery:
        return (const Color(0xFFE1F5FE), const Color(0xFF0277BD));
      case OrderStatus.deliveryFailed:
        return (const Color(0xFFFFEBEE), AppColors.red);
      case OrderStatus.approved:
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case OrderStatus.returnedForEdit:
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
      case OrderStatus.ready:
        return (const Color(0xFFE3F2FD), const Color(0xFF1565C0));
      case OrderStatus.delivered:
        return (const Color(0xFFF3E5F5), const Color(0xFF7B1FA2));
      case OrderStatus.rejected:
        return (const Color(0xFFFFEBEE), AppColors.red);
    }
  }
}
