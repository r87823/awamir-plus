import 'package:flutter/material.dart';

import '../../models/app_models.dart';

enum AppFeature {
  home,
  createOrder,
  branchOrders,
  dailyCashClosure,
  notifications,
  branchApprovals,
  distribution,
  approvedOrders,
  drivers,
  manufacturingOrders,
  productionInProgress,
  readyForPickupDelivery,
  assignedDeliveries,
  onTheWay,
  deliveredOrders,
  employeeCashClosures,
  receiveCashClosure,
  cashDifferences,
  payments,
  invoices,
  paymentEntry,
  settings,
}

extension AppFeatureDetails on AppFeature {
  String get label {
    switch (this) {
      case AppFeature.home:
        return 'الرئيسية';
      case AppFeature.createOrder:
        return 'طلب جديد';
      case AppFeature.branchOrders:
        return 'طلباتي';
      case AppFeature.dailyCashClosure:
        return 'عهدتي اليومية';
      case AppFeature.notifications:
        return 'الإشعارات';
      case AppFeature.branchApprovals:
        return 'موافقات الفرع';
      case AppFeature.distribution:
        return 'التوزيع';
      case AppFeature.approvedOrders:
        return 'الطلبات المعتمدة';
      case AppFeature.drivers:
        return 'السائقين';
      case AppFeature.manufacturingOrders:
        return 'طلبات التصنيع';
      case AppFeature.productionInProgress:
        return 'قيد التنفيذ';
      case AppFeature.readyForPickupDelivery:
        return 'جاهز للاستلام/التوصيل';
      case AppFeature.assignedDeliveries:
        return 'طلباتي المسندة';
      case AppFeature.onTheWay:
        return 'في الطريق';
      case AppFeature.deliveredOrders:
        return 'تم التسليم';
      case AppFeature.employeeCashClosures:
        return 'عهد الموظفين';
      case AppFeature.receiveCashClosure:
        return 'قبول العهدة';
      case AppFeature.cashDifferences:
        return 'الفروقات';
      case AppFeature.payments:
        return 'الدفعات';
      case AppFeature.invoices:
        return 'الفواتير';
      case AppFeature.paymentEntry:
        return 'Payment Entry';
      case AppFeature.settings:
        return 'الإعدادات';
    }
  }

  IconData get icon {
    switch (this) {
      case AppFeature.home:
        return Icons.home_rounded;
      case AppFeature.createOrder:
        return Icons.add_circle_rounded;
      case AppFeature.branchOrders:
      case AppFeature.branchApprovals:
      case AppFeature.approvedOrders:
      case AppFeature.manufacturingOrders:
      case AppFeature.assignedDeliveries:
        return Icons.checklist_rounded;
      case AppFeature.dailyCashClosure:
      case AppFeature.employeeCashClosures:
      case AppFeature.receiveCashClosure:
      case AppFeature.cashDifferences:
      case AppFeature.payments:
      case AppFeature.paymentEntry:
        return Icons.account_balance_wallet_rounded;
      case AppFeature.notifications:
        return Icons.notifications_rounded;
      case AppFeature.distribution:
      case AppFeature.drivers:
      case AppFeature.onTheWay:
      case AppFeature.deliveredOrders:
        return Icons.local_shipping_rounded;
      case AppFeature.productionInProgress:
      case AppFeature.readyForPickupDelivery:
        return Icons.precision_manufacturing_rounded;
      case AppFeature.invoices:
        return Icons.receipt_long_rounded;
      case AppFeature.settings:
        return Icons.settings_rounded;
    }
  }
}

class AccessControl {
  const AccessControl._();

  static bool canCreateOrder(AppUser user) =>
      _hasRole(user, {UserRole.branchEmployee, UserRole.systemAdmin});

  static bool canViewBranchOrders(AppUser user) => _hasRole(user, {
    UserRole.branchEmployee,
    UserRole.branchSupervisor,
    UserRole.systemAdmin,
  });

  static bool canApproveOrders(AppUser user) =>
      _hasRole(user, {UserRole.branchSupervisor, UserRole.systemAdmin});

  static bool canDistributeOrders(AppUser user) =>
      _hasRole(user, {UserRole.distributionManager, UserRole.systemAdmin});

  static bool canViewDistribution(AppUser user) =>
      _hasRole(user, {UserRole.distributionManager, UserRole.systemAdmin});

  static bool canAssignProductionDepartment(AppUser user) =>
      _hasRole(user, {UserRole.distributionManager, UserRole.systemAdmin});

  static bool canViewProductionOrders(AppUser user) =>
      _hasRole(user, {UserRole.productionUser, UserRole.systemAdmin});

  static bool canUpdateProductionStatus(AppUser user) =>
      _hasRole(user, {UserRole.productionUser, UserRole.systemAdmin});

  static bool canUpdateProduction(AppUser user) =>
      _hasRole(user, {UserRole.productionUser, UserRole.systemAdmin});

  static bool canAssignDriver(AppUser user) =>
      _hasRole(user, {UserRole.distributionManager, UserRole.systemAdmin});

  static bool canViewPickupOrders(AppUser user) => _hasRole(user, {
    UserRole.branchEmployee,
    UserRole.branchSupervisor,
    UserRole.systemAdmin,
  });

  static bool canDeliverPickupOrder(AppUser user) => _hasRole(user, {
    UserRole.branchEmployee,
    UserRole.branchSupervisor,
    UserRole.systemAdmin,
  });

  static bool canViewDriverOrders(AppUser user) =>
      _hasRole(user, {UserRole.driver, UserRole.systemAdmin});

  static bool canUpdateDeliveryStatus(AppUser user) =>
      _hasRole(user, {UserRole.driver, UserRole.systemAdmin});

  static bool canCollectDeliveryPayment(AppUser user) =>
      _hasRole(user, {UserRole.driver, UserRole.systemAdmin});

  static bool canOverrideDeliveryWithoutFullPayment(AppUser user) =>
      _hasRole(user, {UserRole.systemAdmin});

  static bool canUpdateDelivery(AppUser user) =>
      _hasRole(user, {UserRole.driver, UserRole.systemAdmin});

  static bool canViewDailyCashClosure(AppUser user) => _hasRole(user, {
    UserRole.branchEmployee,
    UserRole.driver,
    UserRole.cashier,
    UserRole.accountant,
    UserRole.systemAdmin,
  });

  static bool canSubmitDailyCashClosure(AppUser user) =>
      canSubmitCashClosure(user);

  static bool canViewMyCashClosure(AppUser user) => _hasRole(user, {
    UserRole.branchEmployee,
    UserRole.driver,
    UserRole.systemAdmin,
  });

  static bool canSubmitCashClosure(AppUser user) => _hasRole(user, {
    UserRole.branchEmployee,
    UserRole.driver,
    UserRole.systemAdmin,
  });

  static bool canViewCashierClosures(AppUser user) =>
      _hasRole(user, {UserRole.cashier, UserRole.systemAdmin});

  static bool canReviewCashClosure(AppUser user) =>
      _hasRole(user, {UserRole.cashier, UserRole.systemAdmin});

  static bool canAcceptCashClosure(AppUser user) =>
      _hasRole(user, {UserRole.cashier, UserRole.systemAdmin});

  static bool canReturnCashClosure(AppUser user) =>
      _hasRole(user, {UserRole.cashier, UserRole.systemAdmin});

  static bool canCloseCashClosure(AppUser user) =>
      _hasRole(user, {UserRole.cashier, UserRole.systemAdmin});

  static bool canViewClosureDifferences(AppUser user) => _hasRole(user, {
    UserRole.cashier,
    UserRole.accountant,
    UserRole.systemAdmin,
  });

  static bool canReceiveCashClosure(AppUser user) =>
      _hasRole(user, {UserRole.cashier, UserRole.systemAdmin});

  static bool canManagePayments(AppUser user) =>
      _hasRole(user, {UserRole.accountant, UserRole.systemAdmin});

  static bool canManageAccounting(AppUser user) =>
      _hasRole(user, {UserRole.accountant, UserRole.systemAdmin});

  static bool canManageSettings(AppUser user) =>
      _hasRole(user, {UserRole.systemAdmin});

  static bool canAccessFeature(AppUser user, AppFeature feature) {
    if (!user.isActive) return false;
    if (user.role == UserRole.systemAdmin) return true;

    switch (feature) {
      case AppFeature.home:
        return true;
      case AppFeature.createOrder:
        return canCreateOrder(user);
      case AppFeature.branchOrders:
        return canViewBranchOrders(user);
      case AppFeature.dailyCashClosure:
        return canViewMyCashClosure(user);
      case AppFeature.notifications:
        return true;
      case AppFeature.branchApprovals:
        return canApproveOrders(user);
      case AppFeature.distribution:
      case AppFeature.approvedOrders:
        return canViewDistribution(user);
      case AppFeature.drivers:
        return canAssignDriver(user);
      case AppFeature.manufacturingOrders:
      case AppFeature.productionInProgress:
      case AppFeature.readyForPickupDelivery:
        return canViewProductionOrders(user);
      case AppFeature.assignedDeliveries:
      case AppFeature.onTheWay:
        return canUpdateDelivery(user);
      case AppFeature.deliveredOrders:
        return canViewPickupOrders(user) || canViewDriverOrders(user);
      case AppFeature.employeeCashClosures:
      case AppFeature.receiveCashClosure:
        return canViewCashierClosures(user);
      case AppFeature.cashDifferences:
        return canViewClosureDifferences(user);
      case AppFeature.payments:
      case AppFeature.invoices:
      case AppFeature.paymentEntry:
        return canManageAccounting(user);
      case AppFeature.settings:
        return canManageSettings(user);
    }
  }

  static List<AppFeature> roleFeatures(AppUser user) {
    if (user.role == UserRole.systemAdmin) {
      return AppFeature.values
          .where((feature) => feature != AppFeature.home)
          .toList();
    }

    switch (user.role) {
      case UserRole.branchEmployee:
        return const [
          AppFeature.createOrder,
          AppFeature.branchOrders,
          AppFeature.dailyCashClosure,
          AppFeature.notifications,
          AppFeature.deliveredOrders,
        ];
      case UserRole.branchSupervisor:
        return const [
          AppFeature.branchApprovals,
          AppFeature.branchOrders,
          AppFeature.notifications,
          AppFeature.deliveredOrders,
        ];
      case UserRole.distributionManager:
        return const [
          AppFeature.distribution,
          AppFeature.approvedOrders,
          AppFeature.drivers,
          AppFeature.notifications,
        ];
      case UserRole.productionUser:
        return const [
          AppFeature.manufacturingOrders,
          AppFeature.productionInProgress,
          AppFeature.readyForPickupDelivery,
        ];
      case UserRole.driver:
        return const [
          AppFeature.assignedDeliveries,
          AppFeature.onTheWay,
          AppFeature.deliveredOrders,
          AppFeature.dailyCashClosure,
        ];
      case UserRole.cashier:
        return const [
          AppFeature.employeeCashClosures,
          AppFeature.receiveCashClosure,
          AppFeature.cashDifferences,
        ];
      case UserRole.accountant:
        return const [
          AppFeature.payments,
          AppFeature.invoices,
          AppFeature.paymentEntry,
        ];
      case UserRole.systemAdmin:
        return const [];
    }
  }

  static List<AppFeature> primaryNavigationFeatures(AppUser user) {
    if (user.role == UserRole.systemAdmin) {
      return const [
        AppFeature.home,
        AppFeature.branchOrders,
        AppFeature.createOrder,
        AppFeature.dailyCashClosure,
        AppFeature.notifications,
      ];
    }

    return [AppFeature.home, ...roleFeatures(user)].take(5).toList();
  }

  static bool _hasRole(AppUser user, Set<UserRole> roles) =>
      user.isActive && roles.contains(user.role);
}
