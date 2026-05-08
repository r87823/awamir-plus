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

enum AppPermission {
  orderCreate('order.create'),
  orderViewOwn('order.view_own'),
  orderViewBranch('order.view_branch'),
  orderEditDraft('order.edit_draft'),
  orderCancel('order.cancel'),
  orderApprove('order.approve'),
  orderReject('order.reject'),
  orderReturnForEdit('order.return_for_edit'),
  orderDeliverBranch('order.deliver_branch'),
  fulfillmentViewQueue('fulfillment.view_queue'),
  fulfillmentCreate('fulfillment.create'),
  fulfillmentSplitByDepartment('fulfillment.split_by_department'),
  fulfillmentCreateWorkOrders('fulfillment.create_department_work_orders'),
  fulfillmentAssignDepartment('fulfillment.assign_department'),
  fulfillmentViewDepartmentStatus('fulfillment.view_department_status'),
  workOrderViewDepartment('work_order.view_department'),
  workOrderAccept('work_order.accept'),
  workOrderReject('work_order.reject'),
  workOrderUpdateStatus('work_order.update_status'),
  productionMarkReady('production.mark_ready'),
  deliveryBatchCreate('delivery_batch.create'),
  deliveryBatchAssignDriver('delivery_batch.assign_driver'),
  deliveryBatchView('delivery_batch.view'),
  deliveryBatchViewAssigned('delivery_batch.view_assigned'),
  deliveryBatchUpdateStatus('delivery_batch.update_status'),
  deliveryViewAll('delivery.view_all'),
  deliveryViewAssigned('delivery.view_assigned'),
  deliveryUpdateStatus('delivery.update_status'),
  deliveryConfirmDelivered('delivery.confirm_delivered'),
  deliveryCollectCash('delivery.collect_cash'),
  paymentCollectBranch('payment.collect_branch'),
  cashboxViewOwn('cashbox.view_own'),
  cashboxViewAll('cashbox.view_all'),
  cashboxReview('cashbox.review'),
  cashboxApprove('cashbox.approve'),
  cashboxReturn('cashbox.return'),
  cashboxCloseDay('cashbox.close_day'),
  accountingViewFinancials('accounting.view_financials'),
  accountingReviewInvoice('accounting.review_invoice'),
  accountingSubmitInvoice('accounting.submit_invoice'),
  accountingReviewPayment('accounting.review_payment'),
  accountingSubmitPayment('accounting.submit_payment'),
  accountingReconcilePayments('accounting.reconcile_payments'),
  accountingViewReports('accounting.view_reports'),
  accountingCloseFinancialDay('accounting.close_financial_day'),
  adminManageUsers('admin.manage_users'),
  adminManageRoles('admin.manage_roles'),
  adminManagePermissions('admin.manage_permissions'),
  adminManageBranches('admin.manage_branches'),
  adminManageDepartments('admin.manage_departments'),
  adminManageSettings('admin.manage_settings'),
  adminManageWorkflows('admin.manage_workflows'),
  adminViewAuditLogs('admin.view_audit_logs'),
  systemFullAccess('system.full_access');

  const AppPermission(this.key);

  final String key;
}

class AccessControl {
  const AccessControl._();

  static const Map<UserRole, Set<AppPermission>> _rolePermissions = {
    UserRole.branchEmployee: {
      AppPermission.orderCreate,
      AppPermission.orderViewOwn,
      AppPermission.orderEditDraft,
      AppPermission.orderCancel,
      AppPermission.orderDeliverBranch,
      AppPermission.paymentCollectBranch,
      AppPermission.cashboxViewOwn,
    },
    UserRole.branchSupervisor: {
      AppPermission.orderViewBranch,
      AppPermission.orderCancel,
      AppPermission.orderApprove,
      AppPermission.orderReject,
      AppPermission.orderReturnForEdit,
      AppPermission.orderDeliverBranch,
      AppPermission.fulfillmentCreate,
    },
    UserRole.distributionManager: {
      AppPermission.fulfillmentViewQueue,
      AppPermission.orderCancel,
      AppPermission.fulfillmentSplitByDepartment,
      AppPermission.fulfillmentCreateWorkOrders,
      AppPermission.fulfillmentAssignDepartment,
      AppPermission.fulfillmentViewDepartmentStatus,
      AppPermission.deliveryBatchCreate,
      AppPermission.deliveryBatchAssignDriver,
      AppPermission.deliveryBatchView,
      AppPermission.deliveryViewAll,
    },
    UserRole.productionUser: {
      AppPermission.workOrderViewDepartment,
      AppPermission.workOrderAccept,
      AppPermission.workOrderReject,
      AppPermission.workOrderUpdateStatus,
      AppPermission.productionMarkReady,
    },
    UserRole.driver: {
      AppPermission.deliveryBatchViewAssigned,
      AppPermission.deliveryBatchUpdateStatus,
      AppPermission.deliveryViewAssigned,
      AppPermission.deliveryUpdateStatus,
      AppPermission.deliveryConfirmDelivered,
      AppPermission.deliveryCollectCash,
      AppPermission.cashboxViewOwn,
    },
    UserRole.cashier: {
      AppPermission.cashboxViewAll,
      AppPermission.cashboxReview,
      AppPermission.cashboxApprove,
      AppPermission.cashboxReturn,
      AppPermission.cashboxCloseDay,
    },
    UserRole.accountant: {
      AppPermission.accountingViewFinancials,
      AppPermission.accountingReviewInvoice,
      AppPermission.accountingSubmitInvoice,
      AppPermission.accountingReviewPayment,
      AppPermission.accountingSubmitPayment,
      AppPermission.accountingReconcilePayments,
      AppPermission.accountingViewReports,
      AppPermission.accountingCloseFinancialDay,
    },
    UserRole.systemAdmin: {
      AppPermission.systemFullAccess,
      AppPermission.adminManageUsers,
      AppPermission.adminManageRoles,
      AppPermission.adminManagePermissions,
      AppPermission.adminManageBranches,
      AppPermission.adminManageDepartments,
      AppPermission.adminManageSettings,
      AppPermission.adminManageWorkflows,
      AppPermission.adminViewAuditLogs,
    },
  };

  static Set<AppPermission> permissionsFor(AppUser user) {
    if (!user.isActive) return const {};
    if (user.role == UserRole.systemAdmin) return AppPermission.values.toSet();
    return _rolePermissions[user.role] ?? const {};
  }

  static bool hasPermission(AppUser user, AppPermission permission) {
    final permissions = permissionsFor(user);
    return permissions.contains(AppPermission.systemFullAccess) ||
        permissions.contains(permission);
  }

  static bool hasAnyPermission(
    AppUser user,
    Iterable<AppPermission> permissions,
  ) {
    return permissions.any((permission) => hasPermission(user, permission));
  }

  static bool hasAllPermissions(
    AppUser user,
    Iterable<AppPermission> permissions,
  ) {
    return permissions.every((permission) => hasPermission(user, permission));
  }

  static bool canCreateOrder(AppUser user) =>
      hasPermission(user, AppPermission.orderCreate);

  static bool canViewBranchOrders(AppUser user) => hasAnyPermission(user, {
    AppPermission.orderViewOwn,
    AppPermission.orderViewBranch,
  });

  static bool canApproveOrders(AppUser user) =>
      hasPermission(user, AppPermission.orderApprove);

  static bool canCancelOrder(AppUser user) =>
      hasPermission(user, AppPermission.orderCancel);

  static bool canDistributeOrders(AppUser user) => canViewDistribution(user);

  static bool canViewDistribution(AppUser user) =>
      hasPermission(user, AppPermission.fulfillmentViewQueue);

  static bool canAssignProductionDepartment(AppUser user) =>
      hasPermission(user, AppPermission.fulfillmentAssignDepartment);

  static bool canViewProductionOrders(AppUser user) =>
      hasPermission(user, AppPermission.workOrderViewDepartment);

  static bool canUpdateProductionStatus(AppUser user) => hasAnyPermission(
    user,
    {AppPermission.workOrderUpdateStatus, AppPermission.productionMarkReady},
  );

  static bool canUpdateProduction(AppUser user) =>
      canUpdateProductionStatus(user);

  static bool canAssignDriver(AppUser user) =>
      hasPermission(user, AppPermission.deliveryBatchAssignDriver);

  static bool canViewPickupOrders(AppUser user) => hasAnyPermission(user, {
    AppPermission.orderDeliverBranch,
    AppPermission.orderViewBranch,
  });

  static bool canDeliverPickupOrder(AppUser user) =>
      hasPermission(user, AppPermission.orderDeliverBranch);

  static bool canViewDriverOrders(AppUser user) =>
      hasPermission(user, AppPermission.deliveryViewAssigned);

  static bool canUpdateDeliveryStatus(AppUser user) =>
      hasPermission(user, AppPermission.deliveryUpdateStatus);

  static bool canCollectDeliveryPayment(AppUser user) =>
      hasPermission(user, AppPermission.deliveryCollectCash);

  static bool canOverrideDeliveryWithoutFullPayment(AppUser user) =>
      hasPermission(user, AppPermission.systemFullAccess);

  static bool canUpdateDelivery(AppUser user) => canUpdateDeliveryStatus(user);

  static bool canViewDailyCashClosure(AppUser user) => hasAnyPermission(user, {
    AppPermission.cashboxViewOwn,
    AppPermission.cashboxViewAll,
    AppPermission.accountingViewFinancials,
  });

  static bool canSubmitDailyCashClosure(AppUser user) =>
      canSubmitCashClosure(user);

  static bool canViewMyCashClosure(AppUser user) =>
      hasPermission(user, AppPermission.cashboxViewOwn);

  static bool canSubmitCashClosure(AppUser user) =>
      hasPermission(user, AppPermission.cashboxViewOwn);

  static bool canViewCashierClosures(AppUser user) =>
      hasPermission(user, AppPermission.cashboxViewAll);

  static bool canReviewCashClosure(AppUser user) =>
      hasPermission(user, AppPermission.cashboxReview);

  static bool canAcceptCashClosure(AppUser user) =>
      hasPermission(user, AppPermission.cashboxApprove);

  static bool canReturnCashClosure(AppUser user) =>
      hasPermission(user, AppPermission.cashboxReturn);

  static bool canCloseCashClosure(AppUser user) =>
      hasPermission(user, AppPermission.cashboxCloseDay);

  static bool canViewClosureDifferences(AppUser user) => hasAnyPermission(
    user,
    {AppPermission.cashboxReview, AppPermission.accountingViewFinancials},
  );

  static bool canReceiveCashClosure(AppUser user) => canReviewCashClosure(user);

  static bool canManagePayments(AppUser user) =>
      hasPermission(user, AppPermission.accountingReviewPayment);

  static bool canManageAccounting(AppUser user) =>
      hasPermission(user, AppPermission.accountingViewFinancials);

  static bool canManageSettings(AppUser user) =>
      hasPermission(user, AppPermission.adminManageSettings);

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

  static bool hasRole(AppUser user, UserRole role) =>
      user.isActive && user.role == role;
}
