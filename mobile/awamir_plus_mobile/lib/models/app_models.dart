import 'package:flutter/material.dart';

enum OrderStatus {
  draft,
  pendingSupervisorApproval,
  pending,
  sentToDistribution,
  sentToProduction,
  inProduction,
  productionCompleted,
  readyForPickup,
  readyForDelivery,
  assignedToDriver,
  driverPickedUp,
  outForDelivery,
  deliveryFailed,
  approved,
  returnedForEdit,
  ready,
  delivered,
  rejected,
}

extension OrderStatusDetails on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.draft:
        return 'مسودة';
      case OrderStatus.pendingSupervisorApproval:
        return 'بانتظار موافقة المشرف';
      case OrderStatus.pending:
        return 'بانتظار الموافقة';
      case OrderStatus.sentToDistribution:
        return 'مرسل للتوزيع';
      case OrderStatus.sentToProduction:
        return 'مرسل للتنفيذ';
      case OrderStatus.inProduction:
        return 'قيد التنفيذ';
      case OrderStatus.productionCompleted:
        return 'اكتمل التنفيذ';
      case OrderStatus.readyForPickup:
        return 'جاهز للاستلام';
      case OrderStatus.readyForDelivery:
        return 'جاهز للتوصيل';
      case OrderStatus.assignedToDriver:
        return 'مسند للسائق';
      case OrderStatus.driverPickedUp:
        return 'استلمه السائق';
      case OrderStatus.outForDelivery:
        return 'في الطريق';
      case OrderStatus.deliveryFailed:
        return 'تعذر التسليم';
      case OrderStatus.approved:
        return 'معتمد';
      case OrderStatus.returnedForEdit:
        return 'معاد للتعديل';
      case OrderStatus.ready:
        return 'جاهز';
      case OrderStatus.delivered:
        return 'مسلّم';
      case OrderStatus.rejected:
        return 'مرفوض';
    }
  }
}

enum PaymentMethod { cash, card, transfer, other }

extension PaymentMethodDetails on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'نقدي';
      case PaymentMethod.card:
        return 'شبكة';
      case PaymentMethod.transfer:
        return 'تحويل';
      case PaymentMethod.other:
        return 'أخرى';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.cash:
        return Icons.payments;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.transfer:
        return Icons.account_balance;
      case PaymentMethod.other:
        return Icons.more_horiz;
    }
  }
}

enum CashClosureOwnerType { employee, driver }

extension CashClosureOwnerTypeDetails on CashClosureOwnerType {
  String get key {
    switch (this) {
      case CashClosureOwnerType.employee:
        return 'branch_employee';
      case CashClosureOwnerType.driver:
        return 'driver';
    }
  }

  String get label {
    switch (this) {
      case CashClosureOwnerType.employee:
        return 'موظف فرع';
      case CashClosureOwnerType.driver:
        return 'سائق';
    }
  }
}

enum CashClosureStatus {
  open,
  submittedToCashier,
  returnedForReview,
  accepted,
  closed,
  hasDifference,
}

extension CashClosureStatusDetails on CashClosureStatus {
  String get label {
    switch (this) {
      case CashClosureStatus.open:
        return 'مفتوحة';
      case CashClosureStatus.submittedToCashier:
        return 'مرسلة لأمين الصندوق';
      case CashClosureStatus.returnedForReview:
        return 'معادة للمراجعة';
      case CashClosureStatus.accepted:
        return 'مقبولة';
      case CashClosureStatus.closed:
        return 'مغلقة';
      case CashClosureStatus.hasDifference:
        return 'يوجد فرق';
    }
  }
}

enum OrderPaymentStatus {
  recordedByEmployee,
  inDailyClosure,
  submittedToCashier,
  returnedForReview,
  cashierAccepted,
  readyForErpnextPosting,
  postedToErpNext,
  linkedToInvoice,
}

enum ErpSyncStatus { notSynced, pending, synced, failed, partiallySynced }

extension ErpSyncStatusDetails on ErpSyncStatus {
  String get label {
    switch (this) {
      case ErpSyncStatus.notSynced:
        return 'غير مرحل';
      case ErpSyncStatus.pending:
        return 'قيد الترحيل';
      case ErpSyncStatus.synced:
        return 'مرحل';
      case ErpSyncStatus.failed:
        return 'فشل الترحيل';
      case ErpSyncStatus.partiallySynced:
        return 'مرحل جزئياً';
    }
  }
}

enum PaymentAllocationStatus { pending, allocated, failed }

extension PaymentAllocationStatusDetails on PaymentAllocationStatus {
  String get label {
    switch (this) {
      case PaymentAllocationStatus.pending:
        return 'بانتظار التخصيص';
      case PaymentAllocationStatus.allocated:
        return 'مخصص';
      case PaymentAllocationStatus.failed:
        return 'فشل التخصيص';
    }
  }
}

extension OrderPaymentStatusDetails on OrderPaymentStatus {
  String get label {
    switch (this) {
      case OrderPaymentStatus.recordedByEmployee:
        return 'مسجلة بواسطة الموظف';
      case OrderPaymentStatus.inDailyClosure:
        return 'ضمن العهدة اليومية';
      case OrderPaymentStatus.submittedToCashier:
        return 'مرسلة لأمين الصندوق';
      case OrderPaymentStatus.returnedForReview:
        return 'معادة للمراجعة';
      case OrderPaymentStatus.cashierAccepted:
        return 'مقبولة من أمين الصندوق';
      case OrderPaymentStatus.readyForErpnextPosting:
        return 'جاهزة للترحيل';
      case OrderPaymentStatus.postedToErpNext:
        return 'مرحلة إلى ERPNext';
      case OrderPaymentStatus.linkedToInvoice:
        return 'مرتبطة بفاتورة';
    }
  }

  bool get canEdit {
    switch (this) {
      case OrderPaymentStatus.recordedByEmployee:
      case OrderPaymentStatus.inDailyClosure:
      case OrderPaymentStatus.returnedForReview:
        return true;
      case OrderPaymentStatus.submittedToCashier:
      case OrderPaymentStatus.cashierAccepted:
      case OrderPaymentStatus.readyForErpnextPosting:
      case OrderPaymentStatus.postedToErpNext:
      case OrderPaymentStatus.linkedToInvoice:
        return false;
    }
  }

  bool get canPostToErpNext {
    switch (this) {
      case OrderPaymentStatus.readyForErpnextPosting:
      case OrderPaymentStatus.postedToErpNext:
      case OrderPaymentStatus.linkedToInvoice:
        return true;
      case OrderPaymentStatus.recordedByEmployee:
      case OrderPaymentStatus.inDailyClosure:
      case OrderPaymentStatus.submittedToCashier:
      case OrderPaymentStatus.returnedForReview:
      case OrderPaymentStatus.cashierAccepted:
        return false;
    }
  }
}

enum CustomerType { individual, company }

extension CustomerTypeDetails on CustomerType {
  String get label {
    switch (this) {
      case CustomerType.individual:
        return 'فرد';
      case CustomerType.company:
        return 'شركة';
    }
  }
}

enum FulfillmentType { branchPickup, customerDelivery }

extension FulfillmentTypeDetails on FulfillmentType {
  String get label {
    switch (this) {
      case FulfillmentType.branchPickup:
        return 'استلام من الفرع';
      case FulfillmentType.customerDelivery:
        return 'توصيل للعميل';
    }
  }
}

enum OrderAttachmentType { image, pdf, receipt }

extension OrderAttachmentTypeDetails on OrderAttachmentType {
  String get label {
    switch (this) {
      case OrderAttachmentType.image:
        return 'صورة';
      case OrderAttachmentType.pdf:
        return 'PDF';
      case OrderAttachmentType.receipt:
        return 'إيصال';
    }
  }
}

enum NotificationType {
  orderApproved,
  orderRejected,
  orderReturned,
  orderSentToDistribution,
  orderSentToProduction,
  productionStarted,
  productionCompleted,
  readyForPickup,
  readyForDelivery,
  driverAssigned,
  driverPickedUp,
  outForDelivery,
  orderDelivered,
  deliveryFailed,
  paymentCollected,
  cashClosureSubmitted,
  cashClosureAccepted,
  cashClosureReturned,
  cashClosureDifference,
  cashClosureClosed,
  paymentsReadyForPosting,
  salesOrderCreated,
  salesOrderFailed,
  workOrderCreated,
  paymentEntryPosted,
  paymentEntryFailed,
  salesInvoiceCreated,
  advancePaymentAllocated,
  advancePaymentAllocationFailed,
  general,
}

extension NotificationTypeDetails on NotificationType {
  String get key {
    switch (this) {
      case NotificationType.orderApproved:
        return 'order_approved';
      case NotificationType.orderRejected:
        return 'order_rejected';
      case NotificationType.orderReturned:
        return 'order_returned';
      case NotificationType.orderSentToDistribution:
        return 'order_sent_to_distribution';
      case NotificationType.orderSentToProduction:
        return 'order_sent_to_production';
      case NotificationType.productionStarted:
        return 'production_started';
      case NotificationType.productionCompleted:
        return 'production_completed';
      case NotificationType.readyForPickup:
        return 'ready_for_pickup';
      case NotificationType.readyForDelivery:
        return 'ready_for_delivery';
      case NotificationType.driverAssigned:
        return 'driver_assigned';
      case NotificationType.driverPickedUp:
        return 'driver_picked_up';
      case NotificationType.outForDelivery:
        return 'out_for_delivery';
      case NotificationType.orderDelivered:
        return 'order_delivered';
      case NotificationType.deliveryFailed:
        return 'delivery_failed';
      case NotificationType.paymentCollected:
        return 'payment_collected';
      case NotificationType.cashClosureSubmitted:
        return 'cash_closure_submitted';
      case NotificationType.cashClosureAccepted:
        return 'cash_closure_accepted';
      case NotificationType.cashClosureReturned:
        return 'cash_closure_returned';
      case NotificationType.cashClosureDifference:
        return 'cash_closure_difference';
      case NotificationType.cashClosureClosed:
        return 'cash_closure_closed';
      case NotificationType.paymentsReadyForPosting:
        return 'payments_ready_for_posting';
      case NotificationType.salesOrderCreated:
        return 'sales_order_created';
      case NotificationType.salesOrderFailed:
        return 'sales_order_failed';
      case NotificationType.workOrderCreated:
        return 'work_order_created';
      case NotificationType.paymentEntryPosted:
        return 'payment_entry_posted';
      case NotificationType.paymentEntryFailed:
        return 'payment_entry_failed';
      case NotificationType.salesInvoiceCreated:
        return 'sales_invoice_created';
      case NotificationType.advancePaymentAllocated:
        return 'advance_payment_allocated';
      case NotificationType.advancePaymentAllocationFailed:
        return 'advance_payment_allocation_failed';
      case NotificationType.general:
        return 'general';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.orderApproved:
        return Icons.check_circle;
      case NotificationType.orderRejected:
        return Icons.cancel;
      case NotificationType.orderReturned:
        return Icons.reply_all;
      case NotificationType.orderSentToDistribution:
        return Icons.local_shipping;
      case NotificationType.orderSentToProduction:
        return Icons.precision_manufacturing;
      case NotificationType.productionStarted:
        return Icons.play_circle;
      case NotificationType.productionCompleted:
        return Icons.task_alt;
      case NotificationType.readyForPickup:
        return Icons.storefront;
      case NotificationType.readyForDelivery:
        return Icons.delivery_dining;
      case NotificationType.driverAssigned:
        return Icons.assignment_ind;
      case NotificationType.driverPickedUp:
        return Icons.inventory_2;
      case NotificationType.outForDelivery:
        return Icons.route;
      case NotificationType.orderDelivered:
        return Icons.verified;
      case NotificationType.deliveryFailed:
        return Icons.report_problem;
      case NotificationType.paymentCollected:
        return Icons.payments;
      case NotificationType.cashClosureSubmitted:
        return Icons.outbox;
      case NotificationType.cashClosureAccepted:
        return Icons.fact_check;
      case NotificationType.cashClosureReturned:
        return Icons.assignment_return;
      case NotificationType.cashClosureDifference:
        return Icons.difference;
      case NotificationType.cashClosureClosed:
        return Icons.lock;
      case NotificationType.paymentsReadyForPosting:
        return Icons.cloud_upload;
      case NotificationType.salesOrderCreated:
        return Icons.description;
      case NotificationType.salesOrderFailed:
        return Icons.error_outline;
      case NotificationType.workOrderCreated:
        return Icons.precision_manufacturing;
      case NotificationType.paymentEntryPosted:
        return Icons.receipt_long;
      case NotificationType.paymentEntryFailed:
        return Icons.error_outline;
      case NotificationType.salesInvoiceCreated:
        return Icons.request_quote;
      case NotificationType.advancePaymentAllocated:
        return Icons.link;
      case NotificationType.advancePaymentAllocationFailed:
        return Icons.link_off;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.orderApproved:
        return const Color(0xFF2E7D32);
      case NotificationType.orderRejected:
        return const Color(0xFFC62828);
      case NotificationType.orderReturned:
        return const Color(0xFFE65100);
      case NotificationType.orderSentToDistribution:
        return const Color(0xFF1565C0);
      case NotificationType.orderSentToProduction:
        return const Color(0xFF5E35B1);
      case NotificationType.productionStarted:
        return const Color(0xFFE65100);
      case NotificationType.productionCompleted:
        return const Color(0xFF2E7D32);
      case NotificationType.readyForPickup:
        return const Color(0xFF00695C);
      case NotificationType.readyForDelivery:
        return const Color(0xFF1565C0);
      case NotificationType.driverAssigned:
        return const Color(0xFF1565C0);
      case NotificationType.driverPickedUp:
        return const Color(0xFF00695C);
      case NotificationType.outForDelivery:
        return const Color(0xFF0277BD);
      case NotificationType.orderDelivered:
        return const Color(0xFF2E7D32);
      case NotificationType.deliveryFailed:
        return const Color(0xFFC62828);
      case NotificationType.paymentCollected:
        return const Color(0xFFE65100);
      case NotificationType.cashClosureSubmitted:
        return const Color(0xFF1565C0);
      case NotificationType.cashClosureAccepted:
        return const Color(0xFF2E7D32);
      case NotificationType.cashClosureReturned:
        return const Color(0xFFE65100);
      case NotificationType.cashClosureDifference:
        return const Color(0xFFC62828);
      case NotificationType.cashClosureClosed:
        return const Color(0xFF455A64);
      case NotificationType.paymentsReadyForPosting:
        return const Color(0xFF5E35B1);
      case NotificationType.salesOrderCreated:
        return const Color(0xFF1565C0);
      case NotificationType.salesOrderFailed:
        return const Color(0xFFC62828);
      case NotificationType.workOrderCreated:
        return const Color(0xFF5E35B1);
      case NotificationType.paymentEntryPosted:
        return const Color(0xFF2E7D32);
      case NotificationType.paymentEntryFailed:
        return const Color(0xFFC62828);
      case NotificationType.salesInvoiceCreated:
        return const Color(0xFF00695C);
      case NotificationType.advancePaymentAllocated:
        return const Color(0xFF2E7D32);
      case NotificationType.advancePaymentAllocationFailed:
        return const Color(0xFFC62828);
      case NotificationType.general:
        return const Color(0xFF5E35B1);
    }
  }
}

enum UserRole {
  branchEmployee,
  branchSupervisor,
  distributionManager,
  productionUser,
  driver,
  cashier,
  accountant,
  systemAdmin,
}

extension UserRoleDetails on UserRole {
  String get key {
    switch (this) {
      case UserRole.branchEmployee:
        return 'branch_employee';
      case UserRole.branchSupervisor:
        return 'branch_supervisor';
      case UserRole.distributionManager:
        return 'distribution_manager';
      case UserRole.productionUser:
        return 'production_user';
      case UserRole.driver:
        return 'driver';
      case UserRole.cashier:
        return 'cashier';
      case UserRole.accountant:
        return 'accountant';
      case UserRole.systemAdmin:
        return 'system_admin';
    }
  }

  String get label {
    switch (this) {
      case UserRole.branchEmployee:
        return 'موظف فرع';
      case UserRole.branchSupervisor:
        return 'مشرف فرع';
      case UserRole.distributionManager:
        return 'مسؤول توزيع';
      case UserRole.productionUser:
        return 'موظف مصنع';
      case UserRole.driver:
        return 'سائق';
      case UserRole.cashier:
        return 'أمين صندوق';
      case UserRole.accountant:
        return 'محاسب';
      case UserRole.systemAdmin:
        return 'مدير نظام';
    }
  }

  static UserRole fromKey(String key) {
    return UserRole.values.firstWhere(
      (role) => role.key == key,
      orElse: () => UserRole.branchEmployee,
    );
  }
}

class ProductDepartment {
  const ProductDepartment({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;
  final IconData icon;
}

class ProductionDepartment {
  const ProductionDepartment({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    this.branch = '',
  });

  final String id;
  final String name;
  final String code;
  final bool isActive;
  final String branch;

  @override
  bool operator ==(Object other) {
    return other is ProductionDepartment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class ProductDepartmentMapping {
  const ProductDepartmentMapping({
    this.categoryId,
    this.productId,
    required this.defaultDepartmentId,
  });

  final String? categoryId;
  final int? productId;
  final String defaultDepartmentId;
}

class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.branchId,
    required this.branchName,
    required this.isActive,
    this.currentAssignedOrdersCount = 0,
  });

  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String branchId;
  final String branchName;
  final bool isActive;
  final int currentAssignedOrdersCount;

  DriverProfile copyWith({int? currentAssignedOrdersCount}) {
    return DriverProfile(
      id: id,
      userId: userId,
      fullName: fullName,
      phone: phone,
      branchId: branchId,
      branchName: branchName,
      isActive: isActive,
      currentAssignedOrdersCount:
          currentAssignedOrdersCount ?? this.currentAssignedOrdersCount,
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.branchId,
    required this.branchName,
    required this.isActive,
    this.productionDepartmentId = '',
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String branchId;
  final String branchName;
  final bool isActive;
  final String productionDepartmentId;
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.isCompany,
    this.companyName = '',
    this.taxNumber = '',
    this.address = '',
    this.email = '',
    this.contactPerson = '',
  });

  final String id;
  final String name;
  final String phone;
  final bool isCompany;
  final String companyName;
  final String taxNumber;
  final String address;
  final String email;
  final String contactPerson;
}

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.title,
    required this.details,
    required this.city,
    this.district = '',
    this.postalCode = '',
    this.googleMapsUrl = '',
    this.latitude,
    this.longitude,
    this.notes = '',
  });

  final String id;
  final String title;
  final String details;
  final String city;
  final String district;
  final String postalCode;
  final String googleMapsUrl;
  final double? latitude;
  final double? longitude;
  final String notes;

  CustomerAddress copyWith({
    String? id,
    String? title,
    String? details,
    String? city,
    String? district,
    String? postalCode,
    String? googleMapsUrl,
    double? latitude,
    double? longitude,
    String? notes,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      title: title ?? this.title,
      details: details ?? this.details,
      city: city ?? this.city,
      district: district ?? this.district,
      postalCode: postalCode ?? this.postalCode,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.departmentId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.itemCode = '',
    this.badge,
    this.badgeColor,
  });

  final int id;
  final String itemCode;
  final String departmentId;
  final String name;
  final String description;
  final num price;
  final String imageUrl;
  final String? badge;
  final Color? badgeColor;
}

class Order {
  const Order({
    required this.id,
    required this.customer,
    required this.productSummary,
    required this.amount,
    required this.status,
    required this.date,
    required this.progress,
    required this.paymentMethod,
    this.customerPhone = '',
    this.customerType = CustomerType.individual,
    this.companyName = '',
    this.taxNumber = '',
    this.companyAddress = '',
    this.companyEmail = '',
    this.companyContactPerson = '',
    this.categoryId = '',
    this.categoryName = '',
    this.lineItems = const [],
    this.attachments = const [],
    this.details = '',
    this.customerNotes = '',
    this.pickupDate,
    this.pickupTime,
    this.fulfillmentType = FulfillmentType.branchPickup,
    this.deliveryDetails = const DeliveryDetailsDraft(),
    this.depositAmount = 0,
    this.remainingAmount = 0,
    this.createdBranch = '',
    this.createdBranchId = '',
    this.pickupBranch = '',
    this.pickupBranchId = '',
    this.createdByUserId = '',
    this.createdByName = '',
    this.productionDepartmentId = '',
    this.productionDepartmentName = '',
    this.productionDepartmentCode = '',
    this.assignedDriverId = '',
    this.assignedDriverName = '',
    this.requiresWorkOrder = false,
    this.erpnextCustomerId = '',
    this.erpnextSalesOrderId = '',
    this.erpnextWorkOrderId = '',
    this.erpnextSalesInvoiceId = '',
    this.erpnextPaymentEntryIds = const [],
    this.erpSyncStatus = ErpSyncStatus.notSynced,
    this.erpSyncError = '',
    this.erpSyncedAt,
  });

  final String id;
  final String customer;
  final String productSummary;
  final num amount;
  final OrderStatus status;
  final String date;
  final int progress;
  final PaymentMethod paymentMethod;
  final String customerPhone;
  final CustomerType customerType;
  final String companyName;
  final String taxNumber;
  final String companyAddress;
  final String companyEmail;
  final String companyContactPerson;
  final String categoryId;
  final String categoryName;
  final List<OrderLineDraft> lineItems;
  final List<OrderAttachmentDraft> attachments;
  final String details;
  final String customerNotes;
  final DateTime? pickupDate;
  final TimeOfDay? pickupTime;
  final FulfillmentType fulfillmentType;
  final DeliveryDetailsDraft deliveryDetails;
  final num depositAmount;
  final num remainingAmount;
  final String createdBranch;
  final String createdBranchId;
  final String pickupBranch;
  final String pickupBranchId;
  final String createdByUserId;
  final String createdByName;
  final String productionDepartmentId;
  final String productionDepartmentName;
  final String productionDepartmentCode;
  final String assignedDriverId;
  final String assignedDriverName;
  final bool requiresWorkOrder;
  final String erpnextCustomerId;
  final String erpnextSalesOrderId;
  final String erpnextWorkOrderId;
  final String erpnextSalesInvoiceId;
  final List<String> erpnextPaymentEntryIds;
  final ErpSyncStatus erpSyncStatus;
  final String erpSyncError;
  final DateTime? erpSyncedAt;

  String get pickupDateText => pickupDate == null
      ? date
      : '${pickupDate!.year}-${pickupDate!.month.toString().padLeft(2, '0')}-${pickupDate!.day.toString().padLeft(2, '0')}';

  String get pickupTimeText => pickupTime == null
      ? ''
      : '${pickupTime!.hour.toString().padLeft(2, '0')}:${pickupTime!.minute.toString().padLeft(2, '0')}';

  String get fulfillmentSummary {
    if (fulfillmentType == FulfillmentType.branchPickup) {
      return pickupBranch.isEmpty ? 'استلام من الفرع' : pickupBranch;
    }
    final parts = [
      deliveryDetails.addressText,
      deliveryDetails.district,
      deliveryDetails.city,
    ].where((part) => part.trim().isNotEmpty);
    return parts.isEmpty ? 'توصيل للعميل' : parts.join('، ');
  }

  Order copyWith({
    OrderStatus? status,
    int? progress,
    String? date,
    String? details,
    num? remainingAmount,
    String? productionDepartmentId,
    String? productionDepartmentName,
    String? productionDepartmentCode,
    String? assignedDriverId,
    String? assignedDriverName,
    bool? requiresWorkOrder,
    String? erpnextCustomerId,
    String? erpnextSalesOrderId,
    String? erpnextWorkOrderId,
    String? erpnextSalesInvoiceId,
    List<String>? erpnextPaymentEntryIds,
    ErpSyncStatus? erpSyncStatus,
    String? erpSyncError,
    DateTime? erpSyncedAt,
    bool clearErpSyncError = false,
  }) {
    return Order(
      id: id,
      customer: customer,
      productSummary: productSummary,
      amount: amount,
      status: status ?? this.status,
      date: date ?? this.date,
      progress: progress ?? this.progress,
      paymentMethod: paymentMethod,
      customerPhone: customerPhone,
      customerType: customerType,
      companyName: companyName,
      taxNumber: taxNumber,
      companyAddress: companyAddress,
      companyEmail: companyEmail,
      companyContactPerson: companyContactPerson,
      categoryId: categoryId,
      categoryName: categoryName,
      lineItems: lineItems,
      attachments: attachments,
      details: details ?? this.details,
      customerNotes: customerNotes,
      pickupDate: pickupDate,
      pickupTime: pickupTime,
      fulfillmentType: fulfillmentType,
      deliveryDetails: deliveryDetails,
      depositAmount: depositAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      createdBranch: createdBranch,
      createdBranchId: createdBranchId,
      pickupBranch: pickupBranch,
      pickupBranchId: pickupBranchId,
      createdByUserId: createdByUserId,
      createdByName: createdByName,
      productionDepartmentId:
          productionDepartmentId ?? this.productionDepartmentId,
      productionDepartmentName:
          productionDepartmentName ?? this.productionDepartmentName,
      productionDepartmentCode:
          productionDepartmentCode ?? this.productionDepartmentCode,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      requiresWorkOrder: requiresWorkOrder ?? this.requiresWorkOrder,
      erpnextCustomerId: erpnextCustomerId ?? this.erpnextCustomerId,
      erpnextSalesOrderId: erpnextSalesOrderId ?? this.erpnextSalesOrderId,
      erpnextWorkOrderId: erpnextWorkOrderId ?? this.erpnextWorkOrderId,
      erpnextSalesInvoiceId:
          erpnextSalesInvoiceId ?? this.erpnextSalesInvoiceId,
      erpnextPaymentEntryIds:
          erpnextPaymentEntryIds ?? this.erpnextPaymentEntryIds,
      erpSyncStatus: erpSyncStatus ?? this.erpSyncStatus,
      erpSyncError: clearErpSyncError ? '' : erpSyncError ?? this.erpSyncError,
      erpSyncedAt: erpSyncedAt ?? this.erpSyncedAt,
    );
  }
}

class BranchRef {
  const BranchRef({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) {
    return other is BranchRef && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class OrderLineDraft {
  const OrderLineDraft({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  num get subtotal => product.price * quantity;
}

class OrderAttachmentDraft {
  const OrderAttachmentDraft({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.sizeInBytes,
  });

  final String id;
  final String name;
  final String path;
  final OrderAttachmentType type;
  final int sizeInBytes;

  bool get isValidSize => sizeInBytes <= 5 * 1024 * 1024;
  bool get isValidType =>
      name.toLowerCase().endsWith('.jpg') ||
      name.toLowerCase().endsWith('.jpeg') ||
      name.toLowerCase().endsWith('.png') ||
      name.toLowerCase().endsWith('.pdf');
}

class DeliveryDetailsDraft {
  const DeliveryDetailsDraft({
    this.savedAddressId,
    this.addressText = '',
    this.district = '',
    this.city = '',
    this.postalCode = '',
    this.googleMapsUrl = '',
    this.latitude,
    this.longitude,
    this.notes = '',
    this.deliveryFee = 0,
  });

  final String? savedAddressId;
  final String addressText;
  final String district;
  final String city;
  final String postalCode;
  final String googleMapsUrl;
  final double? latitude;
  final double? longitude;
  final String notes;
  final num deliveryFee;

  bool get hasAddressOrLocation =>
      addressText.trim().isNotEmpty ||
      googleMapsUrl.trim().isNotEmpty ||
      (latitude != null && longitude != null);

  DeliveryDetailsDraft copyWith({
    String? savedAddressId,
    String? addressText,
    String? district,
    String? city,
    String? postalCode,
    String? googleMapsUrl,
    double? latitude,
    double? longitude,
    String? notes,
    num? deliveryFee,
    bool clearSavedAddress = false,
  }) {
    return DeliveryDetailsDraft(
      savedAddressId: clearSavedAddress
          ? null
          : savedAddressId ?? this.savedAddressId,
      addressText: addressText ?? this.addressText,
      district: district ?? this.district,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      deliveryFee: deliveryFee ?? this.deliveryFee,
    );
  }
}

class CreateOrderRequest {
  CreateOrderRequest({required this.createdBranch, required this.pickupBranch});

  ProductDepartment? department;
  final Map<int, OrderLineDraft> lines = {};

  String customerPhone = '';
  String customerName = '';
  CustomerType customerType = CustomerType.individual;
  String companyName = '';
  String taxNumber = '';
  String companyAddress = '';
  String companyEmail = '';
  String companyContactPerson = '';
  Customer? existingCustomer;

  String orderDetails = '';
  String customerNotes = '';
  DateTime? pickupDate;
  TimeOfDay? pickupTime;

  final List<OrderAttachmentDraft> attachments = [];

  FulfillmentType fulfillmentType = FulfillmentType.branchPickup;
  BranchRef createdBranch;
  BranchRef pickupBranch;
  DeliveryDetailsDraft deliveryDetails = const DeliveryDetailsDraft();
  String createdByUserId = '';
  String createdByName = '';

  num depositAmount = 0;
  PaymentMethod paymentMethod = PaymentMethod.cash;
  String transactionReference = '';
  OrderAttachmentDraft? paymentReceipt;

  List<OrderLineDraft> get lineItems => lines.values.toList();
  int get itemsCount =>
      lines.values.fold(0, (total, line) => total + line.quantity);
  num get productsTotal =>
      lines.values.fold<num>(0, (total, line) => total + line.subtotal);
  num get deliveryFee => fulfillmentType == FulfillmentType.customerDelivery
      ? deliveryDetails.deliveryFee
      : 0;
  num get grandTotal => productsTotal + deliveryFee;
  num get remainingAmount =>
      (grandTotal - depositAmount).clamp(0, double.infinity);

  bool get hasProducts => lines.isNotEmpty;
  bool get requiresTransactionReference =>
      paymentMethod == PaymentMethod.card ||
      paymentMethod == PaymentMethod.transfer;

  void setProductQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      lines.remove(product.id);
      return;
    }
    lines[product.id] = OrderLineDraft(product: product, quantity: quantity);
  }

  int quantityFor(Product product) => lines[product.id]?.quantity ?? 0;
}

class CashEntry {
  const CashEntry({
    required this.orderId,
    required this.customer,
    required this.method,
    required this.amount,
    this.collectedByUserId = '',
    this.collectedByName = '',
    this.collectorType = CashClosureOwnerType.employee,
    this.driverId = '',
    this.postedToErpNext = false,
  });

  final String orderId;
  final String customer;
  final PaymentMethod method;
  final num amount;
  final String collectedByUserId;
  final String collectedByName;
  final CashClosureOwnerType collectorType;
  final String driverId;
  final bool postedToErpNext;
}

class OrderPayment {
  const OrderPayment({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.method,
    required this.collectedByUserId,
    required this.collectedByName,
    required this.collectorType,
    required this.createdAt,
    this.customer = '',
    this.transactionReference = '',
    this.receiptPath = '',
    this.driverId = '',
    this.closureId = '',
    this.status = OrderPaymentStatus.recordedByEmployee,
    this.erpnextPaymentEntryId = '',
    this.erpSyncStatus = ErpSyncStatus.notSynced,
    this.erpSyncError = '',
    this.erpSyncedAt,
    this.postedToErpNext = false,
  });

  final String id;
  final String orderId;
  final String customer;
  final num amount;
  final PaymentMethod method;
  final String collectedByUserId;
  final String collectedByName;
  final CashClosureOwnerType collectorType;
  final DateTime createdAt;
  final String transactionReference;
  final String receiptPath;
  final String driverId;
  final String closureId;
  final OrderPaymentStatus status;
  final String erpnextPaymentEntryId;
  final ErpSyncStatus erpSyncStatus;
  final String erpSyncError;
  final DateTime? erpSyncedAt;
  final bool postedToErpNext;

  bool get canEdit => status.canEdit;
  bool get canPostToErpNext => status.canPostToErpNext;

  OrderPayment copyWith({
    String? closureId,
    OrderPaymentStatus? status,
    String? erpnextPaymentEntryId,
    ErpSyncStatus? erpSyncStatus,
    String? erpSyncError,
    DateTime? erpSyncedAt,
    bool? postedToErpNext,
    bool clearErpSyncError = false,
  }) {
    return OrderPayment(
      id: id,
      orderId: orderId,
      customer: customer,
      amount: amount,
      method: method,
      collectedByUserId: collectedByUserId,
      collectedByName: collectedByName,
      collectorType: collectorType,
      createdAt: createdAt,
      transactionReference: transactionReference,
      receiptPath: receiptPath,
      driverId: driverId,
      closureId: closureId ?? this.closureId,
      status: status ?? this.status,
      erpnextPaymentEntryId:
          erpnextPaymentEntryId ?? this.erpnextPaymentEntryId,
      erpSyncStatus: erpSyncStatus ?? this.erpSyncStatus,
      erpSyncError: clearErpSyncError ? '' : erpSyncError ?? this.erpSyncError,
      erpSyncedAt: erpSyncedAt ?? this.erpSyncedAt,
      postedToErpNext: postedToErpNext ?? this.postedToErpNext,
    );
  }
}

class PaymentAllocation {
  const PaymentAllocation({
    required this.id,
    required this.orderId,
    required this.paymentId,
    required this.salesInvoiceId,
    required this.paymentEntryId,
    required this.allocatedAmount,
    required this.allocatedAt,
    required this.status,
    this.error = '',
  });

  final String id;
  final String orderId;
  final String paymentId;
  final String salesInvoiceId;
  final String paymentEntryId;
  final num allocatedAmount;
  final DateTime allocatedAt;
  final PaymentAllocationStatus status;
  final String error;
}

class DeliveryAssignment {
  const DeliveryAssignment({
    required this.id,
    required this.orderId,
    required this.driverId,
    required this.driverName,
    required this.assignedByUserId,
    required this.assignedAt,
    required this.status,
    this.pickedUpAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.failedAt,
    this.failureReason = '',
    this.proofImagePath = '',
    this.driverNotes = '',
  });

  final String id;
  final String orderId;
  final String driverId;
  final String driverName;
  final String assignedByUserId;
  final DateTime assignedAt;
  final OrderStatus status;
  final DateTime? pickedUpAt;
  final DateTime? outForDeliveryAt;
  final DateTime? deliveredAt;
  final DateTime? failedAt;
  final String failureReason;
  final String proofImagePath;
  final String driverNotes;

  DeliveryAssignment copyWith({
    OrderStatus? status,
    DateTime? pickedUpAt,
    DateTime? outForDeliveryAt,
    DateTime? deliveredAt,
    DateTime? failedAt,
    String? failureReason,
    String? proofImagePath,
    String? driverNotes,
  }) {
    return DeliveryAssignment(
      id: id,
      orderId: orderId,
      driverId: driverId,
      driverName: driverName,
      assignedByUserId: assignedByUserId,
      assignedAt: assignedAt,
      status: status ?? this.status,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      outForDeliveryAt: outForDeliveryAt ?? this.outForDeliveryAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      failedAt: failedAt ?? this.failedAt,
      failureReason: failureReason ?? this.failureReason,
      proofImagePath: proofImagePath ?? this.proofImagePath,
      driverNotes: driverNotes ?? this.driverNotes,
    );
  }
}

class DailyCashClosure {
  const DailyCashClosure({
    required this.date,
    required this.branch,
    required this.orderCount,
    required this.entries,
    required this.remainingFromCustomers,
    required this.collectionRate,
    this.id = '',
    this.ownerUserId = '',
    this.ownerName = '',
    this.ownerRoleLabel = '',
    this.branchId = '',
    this.type = CashClosureOwnerType.employee,
    this.status = CashClosureStatus.open,
    this.payments = const [],
    this.logs = const [],
    this.recordedAmount = 0,
    this.actualAmount = 0,
    this.differenceAmount = 0,
    this.differenceReason = '',
    this.cashierNotes = '',
  });

  final String id;
  final String date;
  final String ownerUserId;
  final String ownerName;
  final String ownerRoleLabel;
  final String branchId;
  final String branch;
  final CashClosureOwnerType type;
  final CashClosureStatus status;
  final int orderCount;
  final List<CashEntry> entries;
  final List<OrderPayment> payments;
  final List<CashClosureLog> logs;
  final num remainingFromCustomers;
  final double collectionRate;
  final num recordedAmount;
  final num actualAmount;
  final num differenceAmount;
  final String differenceReason;
  final String cashierNotes;

  num get total => payments.isNotEmpty
      ? payments.fold<num>(0, (total, item) => total + item.amount)
      : entries.fold<num>(0, (total, item) => total + item.amount);

  num methodTotal(PaymentMethod method) {
    if (payments.isNotEmpty) {
      return payments
          .where((item) => item.method == method)
          .fold<num>(0, (total, item) => total + item.amount);
    }
    return entries
        .where((item) => item.method == method)
        .fold<num>(0, (total, item) => total + item.amount);
  }

  DailyCashClosure copyWith({
    String? id,
    String? date,
    String? ownerUserId,
    String? ownerName,
    String? ownerRoleLabel,
    String? branchId,
    String? branch,
    CashClosureOwnerType? type,
    CashClosureStatus? status,
    int? orderCount,
    List<CashEntry>? entries,
    List<OrderPayment>? payments,
    List<CashClosureLog>? logs,
    num? remainingFromCustomers,
    double? collectionRate,
    num? recordedAmount,
    num? actualAmount,
    num? differenceAmount,
    String? differenceReason,
    String? cashierNotes,
  }) {
    return DailyCashClosure(
      id: id ?? this.id,
      date: date ?? this.date,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerName: ownerName ?? this.ownerName,
      ownerRoleLabel: ownerRoleLabel ?? this.ownerRoleLabel,
      branchId: branchId ?? this.branchId,
      branch: branch ?? this.branch,
      type: type ?? this.type,
      status: status ?? this.status,
      orderCount: orderCount ?? this.orderCount,
      entries: entries ?? this.entries,
      payments: payments ?? this.payments,
      logs: logs ?? this.logs,
      remainingFromCustomers:
          remainingFromCustomers ?? this.remainingFromCustomers,
      collectionRate: collectionRate ?? this.collectionRate,
      recordedAmount: recordedAmount ?? this.recordedAmount,
      actualAmount: actualAmount ?? this.actualAmount,
      differenceAmount: differenceAmount ?? this.differenceAmount,
      differenceReason: differenceReason ?? this.differenceReason,
      cashierNotes: cashierNotes ?? this.cashierNotes,
    );
  }
}

class CashClosureTotals {
  const CashClosureTotals({
    required this.cash,
    required this.card,
    required this.transfer,
    required this.other,
    required this.orderCount,
  });

  final num cash;
  final num card;
  final num transfer;
  final num other;
  final int orderCount;

  num get total => cash + card + transfer + other;

  num methodTotal(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return cash;
      case PaymentMethod.card:
        return card;
      case PaymentMethod.transfer:
        return transfer;
      case PaymentMethod.other:
        return other;
    }
  }
}

class CashClosureLog {
  const CashClosureLog({
    required this.id,
    required this.closureId,
    required this.newStatus,
    required this.changedByUserId,
    required this.changedByName,
    required this.changedAt,
    this.oldStatus,
    this.notes = '',
  });

  final int id;
  final String closureId;
  final CashClosureStatus? oldStatus;
  final CashClosureStatus newStatus;
  final String changedByUserId;
  final String changedByName;
  final DateTime changedAt;
  final String notes;
}

class CreateSalesOrderRequest {
  const CreateSalesOrderRequest({required this.order});

  final Order order;
}

class CreateSalesOrderResponse {
  const CreateSalesOrderResponse({
    required this.salesOrderId,
    required this.customerId,
  });

  final String salesOrderId;
  final String customerId;
}

class CreateWorkOrderRequest {
  const CreateWorkOrderRequest({required this.order});

  final Order order;
}

class CreateWorkOrderResponse {
  const CreateWorkOrderResponse({required this.workOrderId});

  final String workOrderId;
}

class CreatePaymentEntryRequest {
  const CreatePaymentEntryRequest({required this.order, required this.payment});

  final Order order;
  final OrderPayment payment;
}

class CreatePaymentEntryResponse {
  const CreatePaymentEntryResponse({required this.paymentEntryId});

  final String paymentEntryId;
}

class CreateSalesInvoiceRequest {
  const CreateSalesInvoiceRequest({required this.order});

  final Order order;
}

class CreateSalesInvoiceResponse {
  const CreateSalesInvoiceResponse({required this.salesInvoiceId});

  final String salesInvoiceId;
}

class AllocateAdvancePaymentRequest {
  const AllocateAdvancePaymentRequest({
    required this.order,
    required this.payment,
    required this.salesInvoiceId,
    required this.paymentEntryId,
    required this.amount,
  });

  final Order order;
  final OrderPayment payment;
  final String salesInvoiceId;
  final String paymentEntryId;
  final num amount;
}

class AllocateAdvancePaymentResponse {
  const AllocateAdvancePaymentResponse({
    required this.allocationId,
    required this.allocatedAmount,
    required this.status,
    this.remainingAmount = 0,
    this.warning = '',
  });

  final String allocationId;
  final num allocatedAmount;
  final PaymentAllocationStatus status;
  final num remainingAmount;
  final String warning;
}

class OrderStatusLog {
  const OrderStatusLog({
    required this.id,
    required this.orderId,
    required this.oldStatus,
    required this.newStatus,
    required this.changedByUserId,
    required this.changedByName,
    required this.changedAt,
    this.notes = '',
  });

  final int id;
  final String orderId;
  final OrderStatus oldStatus;
  final OrderStatus newStatus;
  final String changedByUserId;
  final String changedByName;
  final DateTime changedAt;
  final String notes;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.type,
    this.relatedOrderId,
  });

  final int id;
  final String userId;
  final String title;
  final String message;
  final String? relatedOrderId;
  final DateTime createdAt;
  final bool isRead;
  final NotificationType type;

  IconData get icon => type.icon;
  Color get color => type.color;
  String get body => message;
  bool get read => isRead;

  String get time {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) return 'الآن';
    if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
    if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
    return 'منذ ${difference.inDays} يوم';
  }

  AppNotification copyWith({bool? read, bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      relatedOrderId: relatedOrderId,
      createdAt: createdAt,
      isRead: isRead ?? read ?? this.isRead,
      type: type,
    );
  }
}

class TodayPickupOrder {
  const TodayPickupOrder({
    required this.id,
    required this.customer,
    required this.product,
    required this.branch,
    required this.amount,
    required this.paid,
    required this.date,
    required this.delivered,
  });

  final int id;
  final String customer;
  final String product;
  final String branch;
  final num amount;
  final num paid;
  final String date;
  final bool delivered;

  num get remaining => amount - paid;
  bool get fullyPaid => remaining <= 0;

  TodayPickupOrder copyWith({num? paid, bool? delivered}) {
    return TodayPickupOrder(
      id: id,
      customer: customer,
      product: product,
      branch: branch,
      amount: amount,
      paid: paid ?? this.paid,
      date: date,
      delivered: delivered ?? this.delivered,
    );
  }
}

class OrderDraft {
  final Map<int, int> quantities = {};
  String customerPhone = '0501234567';
  String customerName = 'خالد العتيبي';
  bool isCompany = false;
  DateTime pickupDate = DateTime(2026, 5, 10);
  TimeOfDay pickupTime = const TimeOfDay(hour: 17, minute: 30);
  String notes = '';
  num depositAmount = 500;
  PaymentMethod paymentMethod = PaymentMethod.cash;

  int quantityFor(Product product) => quantities[product.id] ?? 0;

  int get itemsCount => quantities.values.fold(0, (total, qty) => total + qty);

  num totalAmount(List<Product> products) {
    return quantities.entries.fold<num>(0, (total, entry) {
      Product? product;
      for (final item in products) {
        if (item.id == entry.key) {
          product = item;
          break;
        }
      }
      if (product == null) return total;
      return total + product.price * entry.value;
    });
  }

  void reset() {
    quantities.clear();
    customerPhone = '0501234567';
    customerName = 'خالد العتيبي';
    isCompany = false;
    pickupDate = DateTime(2026, 5, 10);
    pickupTime = const TimeOfDay(hour: 17, minute: 30);
    notes = '';
    depositAmount = 500;
    paymentMethod = PaymentMethod.cash;
  }
}
