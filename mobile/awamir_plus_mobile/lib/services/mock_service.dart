import 'package:flutter/material.dart';

import '../core/errors/app_exception.dart';
import '../core/permissions/access_control.dart';
import '../models/app_models.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import 'auth_service.dart';

class MockService implements AuthService {
  MockService()
    : _orders = List.of(_MockData.orders),
      _cashEntries = List.of(_MockData.cashEntries),
      _notifications = List.of(_MockData.notifications),
      _statusLogs = List.of(_MockData.statusLogs),
      _drivers = List.of(_MockData.drivers),
      _deliveryAssignments = List.of(_MockData.deliveryAssignments),
      _orderPayments = List.of(_MockData.orderPayments),
      _cashClosures = List.of(_MockData.cashClosures),
      _cashClosureLogs = List.of(_MockData.cashClosureLogs),
      _paymentAllocations = List.of(_MockData.paymentAllocations),
      _pickupOrders = List.of(_MockData.pickupOrders) {
    _statusLogSequence = _statusLogs.length + 1;
    _notificationSequence = _notifications.length + 1;
    _paymentSequence = _orderPayments.length + 1;
    _assignmentSequence = _deliveryAssignments.length + 1;
    _cashClosureLogSequence = _cashClosureLogs.length + 1;
    _closureSequence = _cashClosures.length + 1;
    _salesOrderSequence = _nextDocumentSequence(
      'SO-',
      _orders.map((o) => o.erpnextSalesOrderId),
    );
    _workOrderSequence = _nextDocumentSequence(
      'WO-',
      _orders.map((o) => o.erpnextWorkOrderId),
    );
    _paymentEntrySequence = _nextDocumentSequence(
      'ACC-PAY-',
      _orderPayments.map((p) => p.erpnextPaymentEntryId),
    );
    _salesInvoiceSequence = _nextDocumentSequence(
      'ACC-SINV-',
      _orders.map((o) => o.erpnextSalesInvoiceId),
    );
    _paymentAllocationSequence = _paymentAllocations.length + 1;
    _seedOrderPaymentsFromCashEntries();
  }

  final List<Order> _orders;
  final List<CashEntry> _cashEntries;
  final List<AppNotification> _notifications;
  final List<OrderStatusLog> _statusLogs;
  final List<DriverProfile> _drivers;
  final List<DeliveryAssignment> _deliveryAssignments;
  final List<OrderPayment> _orderPayments;
  final List<DailyCashClosure> _cashClosures;
  final List<CashClosureLog> _cashClosureLogs;
  final List<PaymentAllocation> _paymentAllocations;
  final List<TodayPickupOrder> _pickupOrders;
  AppUser? _currentUser;
  int _createdOrderSequence = 1;
  int _statusLogSequence = 1;
  int _notificationSequence = 100;
  int _paymentSequence = 1;
  int _assignmentSequence = 1;
  int _closureSequence = 1;
  int _cashClosureLogSequence = 1;
  int _salesOrderSequence = 1;
  int _workOrderSequence = 1;
  int _paymentEntrySequence = 1;
  int _salesInvoiceSequence = 1;
  int _paymentAllocationSequence = 1;

  @override
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final account = _MockData.userAccounts[username.trim()];
    if (account == null || account.password != password) {
      throw const RepositoryException(
        'اسم المستخدم أو كلمة المرور غير صحيحة',
        code: 'invalid_credentials',
      );
    }
    if (!account.user.isActive) {
      throw const RepositoryException(
        'هذا المستخدم غير مفعل',
        code: 'inactive_user',
      );
    }

    _currentUser = account.user;
    return account.user;
  }

  @override
  Future<AppUser?> restoreSession(String sessionKey) async {
    final account = _MockData.userAccounts[sessionKey.trim()];
    if (account == null || !account.user.isActive) return null;
    _currentUser = account.user;
    return account.user;
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  Future<List<ProductDepartment>> getCategories() async {
    return List.of(_MockData.departments);
  }

  Future<List<Product>> getProductsByCategory(String categoryId) async {
    return _MockData.products
        .where((product) => product.departmentId == categoryId)
        .toList();
  }

  Future<Customer?> searchCustomerByPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return null;
    if (normalized != '0501234567') return null;
    return Customer(
      id: 'CUST-0001',
      name: 'خالد العتيبي',
      phone: normalized,
      isCompany: false,
    );
  }

  Future<List<CustomerAddress>> getCustomerAddresses(String customerId) async {
    return const [
      CustomerAddress(
        id: 'ADDR-0001',
        title: 'العنوان الرئيسي',
        details: 'الرياض، حي المروج',
        city: 'الرياض',
        district: 'المروج',
        postalCode: '12284',
        googleMapsUrl: 'https://maps.google.com/?q=24.774265,46.738586',
        latitude: 24.774265,
        longitude: 46.738586,
      ),
    ];
  }

  Future<Order> createOrder(OrderDraft draft, List<Product> products) async {
    final order = Order(
      id: _nextOrderId(),
      customer: draft.customerName.trim().isEmpty
          ? 'عميل جديد'
          : draft.customerName.trim(),
      productSummary: _draftProductSummary(draft, products),
      amount: draft.totalAmount(products),
      status: OrderStatus.pending,
      date: formatDate(DateTime.now()),
      progress: 1,
      paymentMethod: draft.paymentMethod,
    );

    _orders.insert(0, order);
    return order;
  }

  Future<void> saveOrderAsDraft(OrderDraft draft) async {}

  Future<Order> saveDraft(CreateOrderRequest request) async {
    final order = _orderFromRequest(request, OrderStatus.draft);
    _orders.insert(0, order);
    return order;
  }

  Future<Order> submitForApproval(CreateOrderRequest request) async {
    final order = _orderFromRequest(
      request,
      OrderStatus.pendingSupervisorApproval,
    );
    _orders.insert(0, order);
    _statusLogs.insert(
      0,
      OrderStatusLog(
        id: _nextStatusLogId(),
        orderId: order.id,
        oldStatus: OrderStatus.draft,
        newStatus: OrderStatus.pendingSupervisorApproval,
        changedByUserId: order.createdByUserId,
        changedByName: order.createdByName,
        changedAt: DateTime.now(),
        notes: 'تم إرسال الطلب للموافقة',
      ),
    );
    if (request.depositAmount > 0) {
      _recordPayment(
        order: order,
        amount: request.depositAmount,
        method: request.paymentMethod,
        collectedBy: AppUser(
          id: request.createdByUserId,
          fullName: request.createdByName,
          email: '',
          phone: request.customerPhone,
          role: UserRole.branchEmployee,
          branchId: request.createdBranch.id,
          branchName: request.createdBranch.name,
          isActive: true,
        ),
        collectorType: CashClosureOwnerType.employee,
        transactionReference: request.transactionReference,
        receiptPath: request.paymentReceipt?.path ?? '',
      );
    }
    return order;
  }

  Future<Order> submitOrderForApproval(String orderId) async {
    final order = _orders.firstWhere((item) => item.id == orderId);
    return order;
  }

  Future<void> recordDeposit({
    required String orderId,
    required String customer,
    required num amount,
    required PaymentMethod method,
  }) async {
    _recordPayment(
      order: Order(
        id: orderId,
        customer: customer,
        productSummary: '',
        amount: amount,
        status: OrderStatus.pending,
        date: formatDate(DateTime.now()),
        progress: 0,
        paymentMethod: method,
        createdByUserId: 'EMP-0001',
        createdByName: 'أحمد الراجحي',
        createdBranch: 'فرع الرياض — المروج',
        createdBranchId: 'BR-RUH-MUR',
      ),
      amount: amount,
      method: method,
      collectedBy: _MockData.userAccounts['employee']!.user,
      collectorType: CashClosureOwnerType.employee,
    );
  }

  Future<List<Order>> getOrders({OrderStatus? status}) async {
    if (status == null) return List.of(_orders);
    return _orders.where((order) => order.status == status).toList();
  }

  Future<List<Order>> getDistributionOrders(AppUser user) async {
    if (!AccessControl.canViewDistribution(user)) {
      throw const RepositoryException(
        'ليس لديك صلاحية عرض التوزيع',
        code: 'distribution_forbidden',
      );
    }
    const statuses = {
      OrderStatus.sentToDistribution,
      OrderStatus.readyForDelivery,
      OrderStatus.assignedToDriver,
      OrderStatus.driverPickedUp,
      OrderStatus.outForDelivery,
      OrderStatus.deliveryFailed,
    };
    return _orders.where((order) => statuses.contains(order.status)).toList();
  }

  Future<List<ProductionDepartment>> getProductionDepartments() async {
    return _MockData.productionDepartments
        .where((department) => department.isActive)
        .toList();
  }

  Future<ProductionDepartment?> getDefaultDepartmentForOrder(
    Order order,
  ) async {
    for (final line in order.lineItems) {
      final productMapping = _MockData.productDepartmentMappings.where(
        (mapping) => mapping.productId == line.product.id,
      );
      if (productMapping.isNotEmpty) {
        return _productionDepartmentById(
          productMapping.first.defaultDepartmentId,
        );
      }
    }

    final categoryId = order.categoryId.isNotEmpty
        ? order.categoryId
        : order.lineItems.isEmpty
        ? ''
        : order.lineItems.first.product.departmentId;
    if (categoryId.isEmpty) return null;

    final categoryMapping = _MockData.productDepartmentMappings.where(
      (mapping) => mapping.categoryId == categoryId,
    );
    if (categoryMapping.isEmpty) return null;
    return _productionDepartmentById(categoryMapping.first.defaultDepartmentId);
  }

  Future<Order> assignProductionDepartment({
    required String orderId,
    required String productionDepartmentId,
    required AppUser changedBy,
  }) async {
    if (productionDepartmentId.trim().isEmpty) {
      throw const RepositoryException(
        'جهة التنفيذ مطلوبة',
        code: 'production_department_required',
      );
    }
    if (!AccessControl.canAssignProductionDepartment(changedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية تحويل الطلب للتنفيذ',
        code: 'assign_production_forbidden',
      );
    }

    final department = _productionDepartmentById(productionDepartmentId);
    if (department == null || !department.isActive) {
      throw const RepositoryException(
        'جهة التنفيذ غير متاحة',
        code: 'production_department_not_found',
      );
    }
    final order = _findOrder(orderId);
    if (order.status != OrderStatus.sentToDistribution) {
      throw const RepositoryException(
        'الطلب ليس جاهزاً للتحويل للتنفيذ',
        code: 'order_not_ready_for_distribution',
      );
    }

    final updated = _updateOrderStatus(
      order: order,
      newStatus: OrderStatus.sentToProduction,
      changedBy: changedBy,
      notes: 'تم تحويل الطلب إلى ${department.name}',
      progress: 3,
      productionDepartment: department,
    );

    _createNotificationForProductionDepartment(
      departmentId: department.id,
      title: 'طلب جديد للتنفيذ',
      message: 'يوجد طلب جديد محول للتنفيذ رقم ${order.id}',
      relatedOrderId: order.id,
      type: NotificationType.orderSentToProduction,
    );
    _createNotificationForUser(
      userId: order.createdByUserId,
      title: 'تم تحويل الطلب للتنفيذ',
      message: 'تم تحويل الطلب رقم ${order.id} إلى جهة التنفيذ',
      relatedOrderId: order.id,
      type: NotificationType.orderSentToProduction,
    );

    return updated;
  }

  Future<List<Order>> getProductionOrders(AppUser user) async {
    if (!AccessControl.canViewProductionOrders(user)) {
      throw const RepositoryException(
        'ليس لديك صلاحية عرض طلبات الإنتاج',
        code: 'production_forbidden',
      );
    }

    const statuses = {
      OrderStatus.sentToProduction,
      OrderStatus.inProduction,
      OrderStatus.productionCompleted,
      OrderStatus.readyForPickup,
      OrderStatus.readyForDelivery,
    };
    return _orders.where((order) {
      if (!statuses.contains(order.status)) return false;
      if (user.role == UserRole.systemAdmin) return true;
      return order.productionDepartmentId == user.productionDepartmentId;
    }).toList();
  }

  Future<Order> updateProductionStatus({
    required String orderId,
    required OrderStatus status,
    required AppUser changedBy,
  }) async {
    if (!AccessControl.canUpdateProductionStatus(changedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية تحديث حالة الإنتاج',
        code: 'production_update_forbidden',
      );
    }

    final order = _findOrder(orderId);
    if (changedBy.role != UserRole.systemAdmin &&
        order.productionDepartmentId != changedBy.productionDepartmentId) {
      throw const RepositoryException(
        'لا يمكنك تحديث طلبات جهة تنفيذ أخرى',
        code: 'production_scope_forbidden',
      );
    }
    _validateProductionTransition(order, status);

    final updated = _updateOrderStatus(
      order: order,
      newStatus: status,
      changedBy: changedBy,
      notes: _productionLogNote(status),
      progress: _progressForStatus(status),
    );
    _createProductionNotifications(order: updated, newStatus: status);
    return updated;
  }

  Future<List<Order>> getPickupOrders(AppUser user) async {
    if (!AccessControl.canViewPickupOrders(user)) {
      throw const RepositoryException(
        'ليس لديك صلاحية عرض طلبات الاستلام',
        code: 'pickup_orders_forbidden',
      );
    }

    return _orders.where((order) {
      if (order.status != OrderStatus.readyForPickup) return false;
      if (user.role == UserRole.systemAdmin) return true;
      return order.pickupBranchId == user.branchId;
    }).toList();
  }

  Future<Order> markPickupOrderDelivered({
    required String orderId,
    required AppUser changedBy,
  }) async {
    if (!AccessControl.canDeliverPickupOrder(changedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية تسليم طلبات الاستلام',
        code: 'pickup_delivery_forbidden',
      );
    }

    final order = _findOrder(orderId);
    if (order.status != OrderStatus.readyForPickup) {
      throw const RepositoryException(
        'الطلب ليس جاهزاً للاستلام من الفرع',
        code: 'pickup_order_not_ready',
      );
    }
    if (changedBy.role != UserRole.systemAdmin &&
        order.pickupBranchId != changedBy.branchId) {
      throw const RepositoryException(
        'لا يمكنك تسليم طلبات فرع آخر',
        code: 'pickup_branch_scope_forbidden',
      );
    }
    if (order.remainingAmount > 0 &&
        !AccessControl.canOverrideDeliveryWithoutFullPayment(changedBy)) {
      throw const RepositoryException(
        'لا يمكن تسليم الطلب قبل سداد المتبقي',
        code: 'payment_required_before_delivery',
      );
    }

    final updated = _updateOrderStatus(
      order: order,
      newStatus: OrderStatus.delivered,
      changedBy: changedBy,
      notes: 'تم تسليم الطلب للعميل من الفرع',
      progress: 5,
    );
    _createNotificationForUser(
      userId: order.createdByUserId,
      title: 'تم تسليم الطلب',
      message: 'تم تسليم الطلب رقم ${order.id}',
      relatedOrderId: order.id,
      type: NotificationType.orderDelivered,
    );
    return updated;
  }

  Future<Order> collectRemainingPayment({
    required String orderId,
    required num amount,
    required PaymentMethod method,
    required AppUser collectedBy,
    String transactionReference = '',
    String receiptPath = '',
  }) async {
    final order = _findOrder(orderId);
    if (!AccessControl.canDeliverPickupOrder(collectedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية تسجيل دفعة المتبقي',
        code: 'remaining_payment_forbidden',
      );
    }
    if (collectedBy.role != UserRole.systemAdmin &&
        order.pickupBranchId != collectedBy.branchId) {
      throw const RepositoryException(
        'لا يمكنك تحصيل دفعات فرع آخر',
        code: 'pickup_branch_scope_forbidden',
      );
    }

    _validatePaymentAmount(order: order, amount: amount);
    _recordPayment(
      order: order,
      amount: amount,
      method: method,
      collectedBy: collectedBy,
      collectorType: CashClosureOwnerType.employee,
      transactionReference: transactionReference,
      receiptPath: receiptPath,
    );
    final updated = _updateOrderRemaining(order, amount);
    _createNotificationForUser(
      userId: order.createdByUserId,
      title: 'تم تسجيل دفعة',
      message: 'تم تسجيل دفعة للطلب رقم ${order.id}',
      relatedOrderId: order.id,
      type: NotificationType.paymentCollected,
    );
    return updated;
  }

  Future<List<DriverProfile>> getAvailableDrivers(
    AppUser user, {
    String? branchId,
  }) async {
    if (!AccessControl.canAssignDriver(user)) {
      throw const RepositoryException(
        'ليس لديك صلاحية عرض السائقين',
        code: 'drivers_forbidden',
      );
    }
    return _drivers
        .where((driver) {
          if (!driver.isActive) return false;
          if (branchId == null || branchId.isEmpty) return true;
          return driver.branchId == branchId || driver.branchId == 'ALL';
        })
        .map((driver) {
          return driver.copyWith(
            currentAssignedOrdersCount: _driverAssignmentCount(driver.id),
          );
        })
        .toList();
  }

  Future<Order> assignDriverToOrder({
    required String orderId,
    required String driverId,
    required AppUser changedBy,
  }) async {
    if (driverId.trim().isEmpty) {
      throw const RepositoryException(
        'اختيار السائق مطلوب',
        code: 'driver_required',
      );
    }
    if (!AccessControl.canAssignDriver(changedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية إسناد الطلب لسائق',
        code: 'assign_driver_forbidden',
      );
    }

    final driver = _driverById(driverId);
    if (driver == null || !driver.isActive) {
      throw const RepositoryException(
        'السائق غير متاح',
        code: 'driver_not_found',
      );
    }
    final order = _findOrder(orderId);
    if (order.status != OrderStatus.readyForDelivery &&
        order.status != OrderStatus.deliveryFailed) {
      throw const RepositoryException(
        'الطلب ليس جاهزاً لإسناد السائق',
        code: 'order_not_ready_for_driver',
      );
    }

    final updated = _updateOrderStatus(
      order: order,
      newStatus: OrderStatus.assignedToDriver,
      changedBy: changedBy,
      notes: 'تم إسناد الطلب للسائق ${driver.fullName}',
      progress: 5,
      assignedDriver: driver,
    );

    final assignment = DeliveryAssignment(
      id: 'DA-${_assignmentSequence.toString().padLeft(4, '0')}',
      orderId: order.id,
      driverId: driver.id,
      driverName: driver.fullName,
      assignedByUserId: changedBy.id,
      assignedAt: DateTime.now(),
      status: OrderStatus.assignedToDriver,
    );
    _assignmentSequence++;
    _deliveryAssignments.removeWhere((item) => item.orderId == order.id);
    _deliveryAssignments.insert(0, assignment);

    _createNotificationForUser(
      userId: driver.userId,
      title: 'طلب جديد مسند لك',
      message: 'تم إسناد طلب جديد لك رقم ${order.id}',
      relatedOrderId: order.id,
      type: NotificationType.driverAssigned,
    );
    _createNotificationForUser(
      userId: order.createdByUserId,
      title: 'تم إسناد السائق',
      message: 'تم إسناد الطلب رقم ${order.id} للسائق ${driver.fullName}',
      relatedOrderId: order.id,
      type: NotificationType.driverAssigned,
    );

    return updated;
  }

  Future<List<Order>> getDriverOrders(AppUser user) async {
    if (!AccessControl.canViewDriverOrders(user)) {
      throw const RepositoryException(
        'ليس لديك صلاحية عرض طلبات السائق',
        code: 'driver_orders_forbidden',
      );
    }

    const statuses = {
      OrderStatus.assignedToDriver,
      OrderStatus.driverPickedUp,
      OrderStatus.outForDelivery,
      OrderStatus.deliveryFailed,
      OrderStatus.delivered,
    };
    return _orders.where((order) {
      if (!statuses.contains(order.status)) return false;
      if (user.role == UserRole.systemAdmin) return true;
      final driver = _driverByUserId(user.id);
      return driver != null && order.assignedDriverId == driver.id;
    }).toList();
  }

  Future<Order> updateDeliveryStatus({
    required String orderId,
    required OrderStatus status,
    required AppUser changedBy,
    String proofImagePath = '',
    String driverNotes = '',
  }) async {
    if (!AccessControl.canUpdateDeliveryStatus(changedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية تحديث حالة التوصيل',
        code: 'delivery_update_forbidden',
      );
    }

    final order = _findOrder(orderId);
    final assignment = _findDeliveryAssignment(orderId);
    _validateDriverScope(user: changedBy, assignment: assignment);
    _validateDeliveryTransition(order, status);
    if (status == OrderStatus.delivered && order.remainingAmount > 0) {
      throw const RepositoryException(
        'يجب تسجيل المتبقي قبل التسليم',
        code: 'delivery_payment_required',
      );
    }

    final updated = _updateOrderStatus(
      order: order,
      newStatus: status,
      changedBy: changedBy,
      notes: _deliveryLogNote(status, driverNotes),
      progress: status == OrderStatus.delivered ? 6 : 5,
    );
    _updateDeliveryAssignment(
      assignment.copyWith(
        status: status,
        pickedUpAt: status == OrderStatus.driverPickedUp
            ? DateTime.now()
            : null,
        outForDeliveryAt: status == OrderStatus.outForDelivery
            ? DateTime.now()
            : null,
        deliveredAt: status == OrderStatus.delivered ? DateTime.now() : null,
        proofImagePath: proofImagePath.isEmpty ? null : proofImagePath,
        driverNotes: driverNotes.isEmpty ? null : driverNotes,
      ),
    );
    _createDeliveryNotifications(order: updated, status: status);
    return updated;
  }

  Future<Order> markDeliveryFailed({
    required String orderId,
    required AppUser changedBy,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const RepositoryException(
        'سبب تعذر التسليم مطلوب',
        code: 'delivery_failure_reason_required',
      );
    }
    if (!AccessControl.canUpdateDeliveryStatus(changedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية تحديث حالة التوصيل',
        code: 'delivery_update_forbidden',
      );
    }

    final order = _findOrder(orderId);
    final assignment = _findDeliveryAssignment(orderId);
    _validateDriverScope(user: changedBy, assignment: assignment);
    if (order.status != OrderStatus.assignedToDriver &&
        order.status != OrderStatus.driverPickedUp &&
        order.status != OrderStatus.outForDelivery) {
      throw const RepositoryException(
        'لا يمكن تعذر التسليم لهذه الحالة',
        code: 'invalid_delivery_transition',
      );
    }

    final updated = _updateOrderStatus(
      order: order,
      newStatus: OrderStatus.deliveryFailed,
      changedBy: changedBy,
      notes: reason.trim(),
      progress: 5,
    );
    _updateDeliveryAssignment(
      assignment.copyWith(
        status: OrderStatus.deliveryFailed,
        failedAt: DateTime.now(),
        failureReason: reason.trim(),
      ),
    );
    _createDeliveryNotifications(
      order: updated,
      status: OrderStatus.deliveryFailed,
      failureReason: reason.trim(),
    );
    return updated;
  }

  Future<OrderPayment> collectDeliveryPayment({
    required String orderId,
    required num amount,
    required PaymentMethod method,
    required AppUser collectedBy,
    String transactionReference = '',
    String receiptPath = '',
  }) async {
    if (!AccessControl.canCollectDeliveryPayment(collectedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية تحصيل دفعة التوصيل',
        code: 'delivery_payment_forbidden',
      );
    }
    final order = _findOrder(orderId);
    final assignment = _findDeliveryAssignment(orderId);
    _validateDriverScope(user: collectedBy, assignment: assignment);
    _validatePaymentAmount(order: order, amount: amount);

    final driver = _driverByUserId(collectedBy.id);
    final payment = _recordPayment(
      order: order,
      amount: amount,
      method: method,
      collectedBy: collectedBy,
      collectorType: CashClosureOwnerType.driver,
      transactionReference: transactionReference,
      receiptPath: receiptPath,
      driverId: driver?.id ?? assignment.driverId,
    );
    _updateOrderRemaining(order, amount);
    _createNotificationForUser(
      userId: order.createdByUserId,
      title: 'تم تحصيل دفعة التوصيل',
      message: 'تم تسجيل دفعة عند التسليم للطلب رقم ${order.id}',
      relatedOrderId: order.id,
      type: NotificationType.paymentCollected,
    );
    return payment;
  }

  Future<DeliveryAssignment?> getDeliveryAssignment(String orderId) async {
    for (final assignment in _deliveryAssignments) {
      if (assignment.orderId == orderId) return assignment;
    }
    return null;
  }

  Future<List<Order>> getPendingSupervisorApprovals(AppUser user) async {
    if (!AccessControl.canApproveOrders(user)) {
      throw const RepositoryException(
        'ليس لديك صلاحية الموافقة على الطلبات',
        code: 'approval_forbidden',
      );
    }

    return _orders.where((order) {
      if (order.status != OrderStatus.pendingSupervisorApproval) return false;
      if (user.role == UserRole.systemAdmin) return true;
      return order.createdBranchId == user.branchId ||
          order.pickupBranchId == user.branchId;
    }).toList();
  }

  Future<Order> approveOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    if (!AccessControl.canApproveOrders(changedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية الموافقة على الطلبات',
        code: 'approval_forbidden',
      );
    }

    final order = _findOrderForSupervisorAction(orderId, changedBy);
    final updated = _updateOrderStatus(
      order: order,
      newStatus: OrderStatus.sentToDistribution,
      changedBy: changedBy,
      notes: 'تمت الموافقة على الطلب وإرساله للتوزيع',
      progress: 2,
    );

    _createNotificationForUser(
      userId: order.createdByUserId,
      title: 'تمت الموافقة على الطلب',
      message: 'تمت الموافقة على الطلب رقم ${order.id}',
      relatedOrderId: order.id,
      type: NotificationType.orderApproved,
    );
    _createNotificationForRole(
      role: UserRole.distributionManager,
      title: 'طلب جديد بانتظار التوزيع',
      message: 'يوجد طلب جديد بانتظار التوزيع رقم ${order.id}',
      relatedOrderId: order.id,
      type: NotificationType.orderSentToDistribution,
    );

    return updated;
  }

  Future<Order> rejectOrder({
    required String orderId,
    required AppUser changedBy,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const RepositoryException(
        'سبب الرفض مطلوب',
        code: 'rejection_reason_required',
      );
    }
    if (!AccessControl.canApproveOrders(changedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية رفض الطلبات',
        code: 'approval_forbidden',
      );
    }

    final order = _findOrderForSupervisorAction(orderId, changedBy);
    final updated = _updateOrderStatus(
      order: order,
      newStatus: OrderStatus.rejected,
      changedBy: changedBy,
      notes: reason.trim(),
      progress: 0,
    );

    _createNotificationForUser(
      userId: order.createdByUserId,
      title: 'تم رفض الطلب',
      message: 'تم رفض الطلب رقم ${order.id} مع توضيح السبب: ${reason.trim()}',
      relatedOrderId: order.id,
      type: NotificationType.orderRejected,
    );

    return updated;
  }

  Future<Order> returnOrderForEdit({
    required String orderId,
    required AppUser changedBy,
    required String notes,
  }) async {
    if (notes.trim().isEmpty) {
      throw const RepositoryException(
        'ملاحظة التعديل مطلوبة',
        code: 'return_notes_required',
      );
    }
    if (!AccessControl.canApproveOrders(changedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية إرجاع الطلبات للتعديل',
        code: 'approval_forbidden',
      );
    }

    final order = _findOrderForSupervisorAction(orderId, changedBy);
    final updated = _updateOrderStatus(
      order: order,
      newStatus: OrderStatus.returnedForEdit,
      changedBy: changedBy,
      notes: notes.trim(),
      progress: 0,
    );

    _createNotificationForUser(
      userId: order.createdByUserId,
      title: 'تم إرجاع الطلب للتعديل',
      message: 'تم إرجاع الطلب رقم ${order.id} للتعديل',
      relatedOrderId: order.id,
      type: NotificationType.orderReturned,
    );

    return updated;
  }

  Future<OrderStatusLog> addStatusLog(OrderStatusLog log) async {
    _statusLogs.insert(0, log);
    return log;
  }

  Future<List<OrderStatusLog>> getOrderStatusLogs(String orderId) async {
    final logs = _statusLogs.where((log) => log.orderId == orderId).toList()
      ..sort((first, second) => first.changedAt.compareTo(second.changedAt));
    return logs;
  }

  Future<AppNotification> createNotification(
    AppNotification notification,
  ) async {
    _notifications.insert(0, notification);
    return notification;
  }

  Future<DailyCashClosure> getDailyCashClosure() async {
    final user = _currentUser ?? _MockData.userAccounts['employee']!.user;
    if (AccessControl.canViewMyCashClosure(user)) {
      return getMyDailyCashClosure(user);
    }
    return DailyCashClosure(
      date: '2026-05-01',
      branch: 'فرع الرياض المروج',
      orderCount: _cashEntries.length,
      entries: List.of(_cashEntries),
      remainingFromCustomers: 5750,
      collectionRate: 53.8,
    );
  }

  Future<void> submitDailyCashClosure(DailyCashClosure closure) async {
    final user = _currentUser ?? _MockData.userAccounts['employee']!.user;
    await submitCashClosure(closureId: closure.id, submittedBy: user);
  }

  Future<DailyCashClosure> getMyDailyCashClosure(AppUser user) async {
    if (!AccessControl.canViewMyCashClosure(user)) {
      throw const RepositoryException(
        'ليس لديك صلاحية عرض عهدتك اليومية',
        code: 'my_cash_closure_forbidden',
      );
    }
    final date = formatDate(DateTime.now());
    if (user.role == UserRole.systemAdmin) {
      final payments = _orderPayments
          .where(
            (payment) =>
                payment.status == OrderPaymentStatus.recordedByEmployee ||
                payment.status == OrderPaymentStatus.inDailyClosure ||
                payment.status == OrderPaymentStatus.returnedForReview,
          )
          .toList();
      return _buildClosureSnapshot(
        closure: DailyCashClosure(
          id: 'DCC-ALL-$date',
          date: date,
          ownerUserId: user.id,
          ownerName: user.fullName,
          ownerRoleLabel: user.role.label,
          branchId: user.branchId,
          branch: user.branchName,
          type: CashClosureOwnerType.employee,
          status: CashClosureStatus.open,
          orderCount: 0,
          entries: const [],
          payments: payments,
          remainingFromCustomers: 0,
          collectionRate: 0,
        ),
        payments: payments,
      );
    }

    final type = user.role == UserRole.driver
        ? CashClosureOwnerType.driver
        : CashClosureOwnerType.employee;
    final closure = _findOrCreateOpenClosure(
      user: user,
      type: type,
      date: date,
    );
    final payments = _paymentsForClosureOwner(user, closure);
    for (final payment in payments) {
      if (payment.closureId.isEmpty ||
          payment.status == OrderPaymentStatus.recordedByEmployee) {
        _replacePayment(
          payment.copyWith(
            closureId: closure.id,
            status: OrderPaymentStatus.inDailyClosure,
          ),
        );
      }
    }
    return _refreshClosure(closure.id);
  }

  Future<DailyCashClosure> getCashClosureById(String closureId) async {
    return _refreshClosure(closureId);
  }

  Future<List<OrderPayment>> getCashClosurePayments(String closureId) async {
    return _orderPayments
        .where((payment) => payment.closureId == closureId)
        .toList();
  }

  Future<CashClosureTotals> calculateClosureTotals(
    List<OrderPayment> payments,
  ) async {
    return _calculateClosureTotals(payments);
  }

  Future<DailyCashClosure> submitCashClosure({
    required String closureId,
    required AppUser submittedBy,
  }) async {
    if (!AccessControl.canSubmitCashClosure(submittedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية إرسال العهدة',
        code: 'cash_closure_submit_forbidden',
      );
    }
    final closure = _refreshClosure(closureId);
    if (submittedBy.role != UserRole.systemAdmin &&
        closure.ownerUserId != submittedBy.id) {
      throw const RepositoryException(
        'لا يمكنك إرسال عهدة مستخدم آخر',
        code: 'cash_closure_owner_forbidden',
      );
    }
    if (closure.status != CashClosureStatus.open &&
        closure.status != CashClosureStatus.returnedForReview) {
      throw const RepositoryException(
        'العهدة غير قابلة للإرسال حالياً',
        code: 'cash_closure_not_submittable',
      );
    }

    await markPaymentsAsSubmitted(closure.id);
    final updated = _updateCashClosureStatus(
      closure: closure,
      newStatus: CashClosureStatus.submittedToCashier,
      changedBy: submittedBy,
      notes: 'تم إرسال العهدة لأمين الصندوق',
    );
    _createNotificationForRole(
      role: UserRole.cashier,
      title: 'عهدة جديدة بانتظار المراجعة',
      message: 'تم إرسال العهدة ${closure.id} لأمين الصندوق',
      relatedOrderId: closure.id,
      type: NotificationType.cashClosureSubmitted,
    );
    return updated;
  }

  Future<List<DailyCashClosure>> getSubmittedCashClosures(AppUser user) async {
    if (!AccessControl.canViewCashierClosures(user)) {
      throw const RepositoryException(
        'ليس لديك صلاحية عرض عهد أمين الصندوق',
        code: 'cashier_closures_forbidden',
      );
    }
    return _cashClosures
        .where(
          (closure) => closure.status == CashClosureStatus.submittedToCashier,
        )
        .map((closure) => _refreshClosure(closure.id))
        .toList();
  }

  Future<DailyCashClosure> acceptCashClosure({
    required String closureId,
    required AppUser cashier,
    required num actualCash,
    required num actualCard,
    required num actualTransfer,
    num actualOther = 0,
    String cashierNotes = '',
    String differenceReason = '',
  }) async {
    if (!AccessControl.canAcceptCashClosure(cashier)) {
      throw const RepositoryException(
        'ليس لديك صلاحية قبول العهدة',
        code: 'cash_closure_accept_forbidden',
      );
    }
    final closure = _refreshClosure(closureId);
    if (closure.status != CashClosureStatus.submittedToCashier) {
      throw const RepositoryException(
        'العهدة ليست بانتظار أمين الصندوق',
        code: 'cash_closure_not_submitted',
      );
    }

    await markPaymentsAsCashierAccepted(closure.id);
    final actualTotal = actualCash + actualCard + actualTransfer + actualOther;
    final difference = actualTotal - closure.total;
    final nextStatus = difference == 0
        ? CashClosureStatus.accepted
        : CashClosureStatus.hasDifference;
    final index = _cashClosures.indexWhere((item) => item.id == closure.id);
    final accepted = closure.copyWith(
      status: nextStatus,
      actualAmount: actualTotal,
      recordedAmount: closure.total,
      differenceAmount: difference,
      differenceReason: differenceReason,
      cashierNotes: cashierNotes,
    );
    _cashClosures[index] = accepted;
    _addCashClosureLog(
      closureId: closure.id,
      oldStatus: closure.status,
      newStatus: nextStatus,
      changedBy: cashier,
      notes: difference == 0
          ? 'تم قبول العهدة'
          : 'تم قبول العهدة مع فرق ${difference.toStringAsFixed(2)}',
    );
    _createNotificationForUser(
      userId: closure.ownerUserId,
      title: difference == 0
          ? 'تم قبول عهدتك اليومية'
          : 'تم قبول العهدة مع فرق',
      message: difference == 0
          ? 'تم قبول عهدتك اليومية'
          : 'تم قبول عهدتك اليومية مع فرق ${difference.toStringAsFixed(2)}',
      relatedOrderId: closure.id,
      type: difference == 0
          ? NotificationType.cashClosureAccepted
          : NotificationType.cashClosureDifference,
    );
    if (difference != 0) {
      _createNotificationForRole(
        role: UserRole.accountant,
        title: 'فرق في عهدة يومية',
        message: 'يوجد فرق في العهدة ${closure.id}',
        relatedOrderId: closure.id,
        type: NotificationType.cashClosureDifference,
      );
    }
    return _refreshClosure(closure.id);
  }

  Future<DailyCashClosure> returnCashClosure({
    required String closureId,
    required AppUser cashier,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const RepositoryException(
        'سبب إرجاع العهدة مطلوب',
        code: 'cash_closure_return_reason_required',
      );
    }
    if (!AccessControl.canReturnCashClosure(cashier)) {
      throw const RepositoryException(
        'ليس لديك صلاحية إرجاع العهدة',
        code: 'cash_closure_return_forbidden',
      );
    }
    final closure = _refreshClosure(closureId);
    if (closure.status != CashClosureStatus.submittedToCashier) {
      throw const RepositoryException(
        'العهدة ليست بانتظار أمين الصندوق',
        code: 'cash_closure_not_submitted',
      );
    }
    _setPaymentStatuses(
      closureId: closure.id,
      status: OrderPaymentStatus.returnedForReview,
    );
    final updated = _updateCashClosureStatus(
      closure: closure,
      newStatus: CashClosureStatus.returnedForReview,
      changedBy: cashier,
      notes: reason.trim(),
    );
    _createNotificationForUser(
      userId: closure.ownerUserId,
      title: 'تم إرجاع العهدة للمراجعة',
      message: 'تم إرجاع عهدتك اليومية للمراجعة: ${reason.trim()}',
      relatedOrderId: closure.id,
      type: NotificationType.cashClosureReturned,
    );
    return updated;
  }

  Future<DailyCashClosure> closeCashClosure({
    required String closureId,
    required AppUser closedBy,
  }) async {
    if (!AccessControl.canCloseCashClosure(closedBy)) {
      throw const RepositoryException(
        'ليس لديك صلاحية إغلاق العهدة',
        code: 'cash_closure_close_forbidden',
      );
    }
    final closure = _refreshClosure(closureId);
    if (closure.status != CashClosureStatus.accepted &&
        closure.status != CashClosureStatus.hasDifference) {
      throw const RepositoryException(
        'لا يمكن تجهيز الدفعات للترحيل قبل قبول العهدة',
        code: 'cash_closure_not_accepted_for_close',
      );
    }
    _setPaymentStatuses(
      closureId: closure.id,
      status: OrderPaymentStatus.readyForErpnextPosting,
    );
    final updated = _updateCashClosureStatus(
      closure: closure,
      newStatus: CashClosureStatus.closed,
      changedBy: closedBy,
      notes: 'تم إغلاق العهدة وتجهيز الدفعات للترحيل',
    );
    _createNotificationForUser(
      userId: closure.ownerUserId,
      title: 'تم إغلاق العهدة',
      message: 'تم إغلاق عهدتك اليومية',
      relatedOrderId: closure.id,
      type: NotificationType.cashClosureClosed,
    );
    _createNotificationForRole(
      role: UserRole.accountant,
      title: 'دفعات جاهزة للترحيل',
      message: 'دفعات العهدة ${closure.id} جاهزة للترحيل إلى ERPNext',
      relatedOrderId: closure.id,
      type: NotificationType.paymentsReadyForPosting,
    );
    return updated;
  }

  Future<void> markPaymentsAsSubmitted(String closureId) async {
    _setPaymentStatuses(
      closureId: closureId,
      status: OrderPaymentStatus.submittedToCashier,
    );
  }

  Future<void> markPaymentsAsCashierAccepted(String closureId) async {
    _setPaymentStatuses(
      closureId: closureId,
      status: OrderPaymentStatus.cashierAccepted,
    );
  }

  Future<List<CashClosureLog>> getCashClosureLogs(String closureId) async {
    return _cashClosureLogs.where((log) => log.closureId == closureId).toList()
      ..sort((first, second) => first.changedAt.compareTo(second.changedAt));
  }

  Future<Order> createSalesOrderForOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final order = _findOrder(orderId);
    if (order.erpnextSalesOrderId.isNotEmpty) return order;
    if (!_canCreateSalesOrder(order)) {
      final failed = _updateOrderErpSync(
        order,
        status: ErpSyncStatus.failed,
        error: 'لا يمكن إنشاء Sales Order لهذه الحالة',
      );
      _createNotificationForUser(
        userId: changedBy.id,
        title: 'فشل إنشاء Sales Order',
        message: 'تعذر إنشاء Sales Order للطلب ${order.id}',
        relatedOrderId: order.id,
        type: NotificationType.salesOrderFailed,
      );
      throw RepositoryException(
        'لا يمكن إنشاء Sales Order لهذه الحالة',
        code: 'sales_order_not_allowed',
        cause: failed.erpSyncError,
      );
    }

    final salesOrderId = _nextAccountingId('SO-', _salesOrderSequence++);
    final customerId = order.erpnextCustomerId.isNotEmpty
        ? order.erpnextCustomerId
        : 'CUST-${order.id}';
    final updated = _updateOrderErpSync(
      order,
      customerId: customerId,
      salesOrderId: salesOrderId,
      status: ErpSyncStatus.partiallySynced,
      clearError: true,
    );
    _addAccountingLog(
      order: order,
      changedBy: changedBy,
      notes: 'تم إنشاء Sales Order $salesOrderId',
    );
    _createNotificationForUser(
      userId: changedBy.id,
      title: 'تم إنشاء Sales Order',
      message: 'تم إنشاء Sales Order للطلب ${order.id}: $salesOrderId',
      relatedOrderId: order.id,
      type: NotificationType.salesOrderCreated,
    );
    return updated;
  }

  Future<Order> createWorkOrderForOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final order = _findOrder(orderId);
    if (order.erpnextWorkOrderId.isNotEmpty) return order;
    if (order.erpnextSalesOrderId.isEmpty) {
      final failed = _updateOrderErpSync(
        order,
        status: ErpSyncStatus.failed,
        error: 'لا يمكن إنشاء Work Order قبل Sales Order',
      );
      throw RepositoryException(
        'لا يمكن إنشاء Work Order قبل Sales Order',
        code: 'work_order_requires_sales_order',
        cause: failed.erpSyncError,
      );
    }
    if (!_orderRequiresWorkOrder(order)) return order;

    final workOrderId = _nextAccountingId('WO-', _workOrderSequence++);
    final updated = _updateOrderErpSync(
      order,
      workOrderId: workOrderId,
      status: ErpSyncStatus.partiallySynced,
      clearError: true,
    );
    _addAccountingLog(
      order: order,
      changedBy: changedBy,
      notes: 'تم إنشاء Work Order $workOrderId',
    );
    _createNotificationForUser(
      userId: changedBy.id,
      title: 'تم إنشاء Work Order',
      message: 'تم إنشاء Work Order للطلب ${order.id}: $workOrderId',
      relatedOrderId: order.id,
      type: NotificationType.workOrderCreated,
    );
    return updated;
  }

  Future<List<OrderPayment>> postAcceptedPaymentsToErpnext({
    required String closureId,
    required AppUser changedBy,
  }) async {
    final payments = _orderPayments
        .where(
          (payment) =>
              payment.closureId == closureId &&
              (payment.status == OrderPaymentStatus.cashierAccepted ||
                  payment.status == OrderPaymentStatus.readyForErpnextPosting ||
                  payment.status == OrderPaymentStatus.postedToErpNext),
        )
        .toList();
    final posted = <OrderPayment>[];
    for (final payment in payments) {
      posted.add(
        await createPaymentEntryForPayment(
          paymentId: payment.id,
          changedBy: changedBy,
        ),
      );
    }
    return posted;
  }

  Future<OrderPayment> createPaymentEntryForPayment({
    required String paymentId,
    required AppUser changedBy,
  }) async {
    final payment = _findPayment(paymentId);
    if (payment.status == OrderPaymentStatus.postedToErpNext &&
        payment.erpnextPaymentEntryId.isNotEmpty) {
      return payment;
    }
    if (payment.status != OrderPaymentStatus.cashierAccepted &&
        payment.status != OrderPaymentStatus.readyForErpnextPosting) {
      final failed = payment.copyWith(
        erpSyncStatus: ErpSyncStatus.failed,
        erpSyncError: 'لا يمكن ترحيل دفعة قبل قبول العهدة',
      );
      _replacePayment(failed);
      _createNotificationForUser(
        userId: changedBy.id,
        title: 'فشل ترحيل دفعة',
        message: 'تعذر ترحيل الدفعة ${payment.id} إلى ERPNext',
        relatedOrderId: payment.orderId,
        type: NotificationType.paymentEntryFailed,
      );
      throw RepositoryException(
        'لا يمكن ترحيل دفعة قبل قبول العهدة',
        code: 'payment_not_accepted_for_posting',
        cause: failed.erpSyncError,
      );
    }

    final paymentEntryId = _nextAccountingId(
      'ACC-PAY-',
      _paymentEntrySequence++,
    );
    final posted = payment.copyWith(
      status: OrderPaymentStatus.postedToErpNext,
      erpnextPaymentEntryId: paymentEntryId,
      erpSyncStatus: ErpSyncStatus.synced,
      erpSyncedAt: DateTime.now(),
      postedToErpNext: true,
      clearErpSyncError: true,
    );
    _replacePayment(posted);
    final order = _findOrder(payment.orderId);
    final entries = {...order.erpnextPaymentEntryIds, paymentEntryId}.toList();
    _replaceOrder(
      order.copyWith(
        erpnextPaymentEntryIds: entries,
        erpSyncStatus: _syncStatusForOrder(order, paymentEntries: entries),
        erpSyncedAt: DateTime.now(),
        clearErpSyncError: true,
      ),
    );
    _addAccountingLog(
      order: order,
      changedBy: changedBy,
      notes: 'تم ترحيل الدفعة ${payment.id} كـ Payment Entry $paymentEntryId',
    );
    _createNotificationForUser(
      userId: changedBy.id,
      title: 'تم ترحيل دفعة',
      message: 'تم ترحيل الدفعة ${payment.id} إلى ERPNext',
      relatedOrderId: payment.orderId,
      type: NotificationType.paymentEntryPosted,
    );
    return posted;
  }

  Future<Order> createSalesInvoiceForOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final order = _findOrder(orderId);
    if (order.erpnextSalesInvoiceId.isNotEmpty) return order;
    if (order.erpnextSalesOrderId.isEmpty) {
      final failed = _updateOrderErpSync(
        order,
        status: ErpSyncStatus.failed,
        error: 'لا يمكن إنشاء Sales Invoice قبل Sales Order',
      );
      throw RepositoryException(
        'لا يمكن إنشاء Sales Invoice قبل Sales Order',
        code: 'invoice_requires_sales_order',
        cause: failed.erpSyncError,
      );
    }

    final invoiceId = _nextAccountingId('ACC-SINV-', _salesInvoiceSequence++);
    final updated = _updateOrderErpSync(
      order,
      salesInvoiceId: invoiceId,
      status: ErpSyncStatus.partiallySynced,
      clearError: true,
    );
    _addAccountingLog(
      order: order,
      changedBy: changedBy,
      notes: 'تم إنشاء Sales Invoice $invoiceId',
    );
    _createNotificationForUser(
      userId: changedBy.id,
      title: 'تم إنشاء Sales Invoice',
      message: 'تم إنشاء فاتورة للطلب ${order.id}: $invoiceId',
      relatedOrderId: order.id,
      type: NotificationType.salesInvoiceCreated,
    );
    return updated;
  }

  Future<List<PaymentAllocation>> allocateAdvancePaymentToInvoice({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final order = _findOrder(orderId);
    if (order.erpnextSalesInvoiceId.isEmpty) {
      final failed = _updateOrderErpSync(
        order,
        status: ErpSyncStatus.failed,
        error: 'لا يمكن تخصيص دفعة قبل إنشاء Sales Invoice',
      );
      throw RepositoryException(
        'لا يمكن تخصيص دفعة قبل إنشاء Sales Invoice',
        code: 'allocation_requires_invoice',
        cause: failed.erpSyncError,
      );
    }
    final payments = _orderPayments
        .where((payment) => payment.orderId == orderId && payment.amount > 0)
        .toList();
    if (payments.any(
      (payment) => payment.status != OrderPaymentStatus.postedToErpNext,
    )) {
      final failed = _updateOrderErpSync(
        order,
        status: ErpSyncStatus.failed,
        error: 'لا يمكن تخصيص دفعة غير مرحلة إلى ERPNext',
      );
      throw RepositoryException(
        'لا يمكن تخصيص دفعة غير مرحلة إلى ERPNext',
        code: 'allocation_requires_posted_payment',
        cause: failed.erpSyncError,
      );
    }

    var remainingInvoice = order.amount;
    for (final existing in _paymentAllocations.where(
      (allocation) =>
          allocation.orderId == order.id &&
          allocation.status == PaymentAllocationStatus.allocated,
    )) {
      remainingInvoice -= existing.allocatedAmount;
    }

    final created = <PaymentAllocation>[];
    for (final payment in payments) {
      final alreadyAllocated = _paymentAllocations.any(
        (allocation) =>
            allocation.paymentId == payment.id &&
            allocation.salesInvoiceId == order.erpnextSalesInvoiceId &&
            allocation.status == PaymentAllocationStatus.allocated,
      );
      if (alreadyAllocated) continue;
      final amount = remainingInvoice <= 0
          ? payment.amount
          : payment.amount > remainingInvoice
          ? remainingInvoice
          : payment.amount;
      final allocation = PaymentAllocation(
        id: 'ALLOC-${_paymentAllocationSequence.toString().padLeft(4, '0')}',
        orderId: order.id,
        paymentId: payment.id,
        salesInvoiceId: order.erpnextSalesInvoiceId,
        paymentEntryId: payment.erpnextPaymentEntryId,
        allocatedAmount: amount,
        allocatedAt: DateTime.now(),
        status: PaymentAllocationStatus.allocated,
      );
      _paymentAllocationSequence++;
      _paymentAllocations.insert(0, allocation);
      created.add(allocation);
      remainingInvoice -= amount;
    }

    final totalAllocated = _paymentAllocations
        .where(
          (allocation) =>
              allocation.orderId == order.id &&
              allocation.status == PaymentAllocationStatus.allocated,
        )
        .fold<num>(
          0,
          (total, allocation) => total + allocation.allocatedAmount,
        );
    final updated = order.copyWith(
      remainingAmount: (order.amount - totalAllocated).clamp(
        0,
        double.infinity,
      ),
      erpSyncStatus: totalAllocated >= order.amount
          ? ErpSyncStatus.synced
          : ErpSyncStatus.partiallySynced,
      erpSyncedAt: DateTime.now(),
      clearErpSyncError: true,
    );
    _replaceOrder(updated);
    _addAccountingLog(
      order: order,
      changedBy: changedBy,
      notes: 'تم ربط العربون بالفاتورة ${order.erpnextSalesInvoiceId}',
    );
    _createNotificationForUser(
      userId: changedBy.id,
      title: 'تم ربط العربون بالفاتورة',
      message: 'تم ربط دفعات الطلب ${order.id} بالفاتورة',
      relatedOrderId: order.id,
      type: NotificationType.advancePaymentAllocated,
    );
    return created;
  }

  Future<List<Order>> getCustomerInvoices(String customerId) async {
    return _orders
        .where(
          (order) =>
              order.erpnextCustomerId == customerId &&
              order.erpnextSalesInvoiceId.isNotEmpty,
        )
        .toList();
  }

  Future<Order> syncOrderAccountingStatus({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final order = _findOrder(orderId);
    final updated = _replaceOrder(
      order.copyWith(
        erpSyncStatus: _syncStatusForOrder(order),
        erpSyncedAt: DateTime.now(),
        clearErpSyncError: true,
      ),
    );
    _addAccountingLog(
      order: order,
      changedBy: changedBy,
      notes: 'تم تحديث حالة الربط المحاسبي',
    );
    return updated;
  }

  Future<List<Order>> getOrdersNeedingSalesOrder() async {
    return _orders
        .where((order) => _canCreateSalesOrder(order))
        .where((order) => order.erpnextSalesOrderId.isEmpty)
        .toList();
  }

  Future<List<OrderPayment>> getPaymentsReadyForErpPosting() async {
    return _orderPayments
        .where(
          (payment) =>
              payment.status == OrderPaymentStatus.cashierAccepted ||
              payment.status == OrderPaymentStatus.readyForErpnextPosting,
        )
        .toList();
  }

  Future<List<Order>> getOrdersNeedingSalesInvoice() async {
    return _orders
        .where((order) => order.erpnextSalesOrderId.isNotEmpty)
        .where((order) => order.erpnextSalesInvoiceId.isEmpty)
        .toList();
  }

  Future<List<Order>> getInvoicesNeedingAdvanceAllocation() async {
    return _orders.where((order) {
      if (order.erpnextSalesInvoiceId.isEmpty) return false;
      final postedPayments = _orderPayments.where(
        (payment) =>
            payment.orderId == order.id &&
            payment.status == OrderPaymentStatus.postedToErpNext,
      );
      if (postedPayments.isEmpty) return false;
      return postedPayments.any(
        (payment) => !_paymentAllocations.any(
          (allocation) =>
              allocation.paymentId == payment.id &&
              allocation.status == PaymentAllocationStatus.allocated,
        ),
      );
    }).toList();
  }

  Future<List<Order>> getAccountingSyncErrors() async {
    return _orders
        .where((order) => order.erpSyncStatus == ErpSyncStatus.failed)
        .toList();
  }

  Future<List<AppNotification>> getNotifications() async {
    final user = _currentUser;
    if (user == null) return List.of(_notifications);
    return getNotificationsForCurrentUser(user);
  }

  Future<List<AppNotification>> getNotificationsForCurrentUser(
    AppUser user,
  ) async {
    return _notifications
        .where((notification) => notification.userId == user.id)
        .toList();
  }

  Future<void> markNotificationRead(int id) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _notifications[index] = _notifications[index].copyWith(read: true);
  }

  Future<void> markAllNotificationsRead() async {
    final user = _currentUser;
    for (var index = 0; index < _notifications.length; index++) {
      if (user != null && _notifications[index].userId != user.id) continue;
      _notifications[index] = _notifications[index].copyWith(read: true);
    }
  }

  Future<List<TodayPickupOrder>> getTodayPickupOrders() async {
    return List.of(_pickupOrders);
  }

  Future<TodayPickupOrder?> collectPickupPayment(int id, num amount) async {
    final index = _pickupOrders.indexWhere((item) => item.id == id);
    if (index == -1) return null;
    final order = _pickupOrders[index];
    final paid = (order.paid + amount).clamp(0, order.amount);
    _pickupOrders[index] = order.copyWith(paid: paid);
    return _pickupOrders[index];
  }

  Future<TodayPickupOrder?> deliverPickupOrder(int id) async {
    final index = _pickupOrders.indexWhere((item) => item.id == id);
    if (index == -1) return null;
    final order = _pickupOrders[index];
    if (!order.fullyPaid) return order;
    _pickupOrders[index] = order.copyWith(delivered: true);
    return _pickupOrders[index];
  }

  Order _findOrder(String orderId) {
    return _orders.firstWhere(
      (item) => item.id == orderId,
      orElse: () => throw const RepositoryException(
        'لم يتم العثور على الطلب',
        code: 'order_not_found',
      ),
    );
  }

  OrderPayment _findPayment(String paymentId) {
    return _orderPayments.firstWhere(
      (item) => item.id == paymentId,
      orElse: () => throw const RepositoryException(
        'لم يتم العثور على الدفعة',
        code: 'payment_not_found',
      ),
    );
  }

  Order _replaceOrder(Order order) {
    final index = _orders.indexWhere((item) => item.id == order.id);
    if (index == -1) {
      _orders.insert(0, order);
      return order;
    }
    _orders[index] = order;
    return order;
  }

  bool _canCreateSalesOrder(Order order) {
    const blocked = {
      OrderStatus.draft,
      OrderStatus.pending,
      OrderStatus.pendingSupervisorApproval,
      OrderStatus.returnedForEdit,
      OrderStatus.rejected,
    };
    return !blocked.contains(order.status);
  }

  bool _orderRequiresWorkOrder(Order order) {
    if (order.requiresWorkOrder) return true;
    if (order.productionDepartmentId.isNotEmpty) return true;
    const manufacturingCategories = {'sweets', 'kitchen', 'special', 'buffet'};
    if (manufacturingCategories.contains(order.categoryId)) return true;
    return order.lineItems.any(
      (line) => manufacturingCategories.contains(line.product.departmentId),
    );
  }

  Order _updateOrderErpSync(
    Order order, {
    String? customerId,
    String? salesOrderId,
    String? workOrderId,
    String? salesInvoiceId,
    ErpSyncStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return _replaceOrder(
      order.copyWith(
        erpnextCustomerId: customerId,
        erpnextSalesOrderId: salesOrderId,
        erpnextWorkOrderId: workOrderId,
        erpnextSalesInvoiceId: salesInvoiceId,
        erpSyncStatus: status,
        erpSyncError: error,
        erpSyncedAt: DateTime.now(),
        clearErpSyncError: clearError,
      ),
    );
  }

  ErpSyncStatus _syncStatusForOrder(
    Order order, {
    List<String>? paymentEntries,
  }) {
    final entries = paymentEntries ?? order.erpnextPaymentEntryIds;
    if (order.erpnextSalesOrderId.isNotEmpty &&
        order.erpnextSalesInvoiceId.isNotEmpty &&
        entries.isNotEmpty) {
      return ErpSyncStatus.synced;
    }
    if (order.erpnextSalesOrderId.isNotEmpty ||
        order.erpnextSalesInvoiceId.isNotEmpty ||
        entries.isNotEmpty ||
        order.erpnextWorkOrderId.isNotEmpty) {
      return ErpSyncStatus.partiallySynced;
    }
    return ErpSyncStatus.notSynced;
  }

  void _addAccountingLog({
    required Order order,
    required AppUser changedBy,
    required String notes,
  }) {
    _statusLogs.insert(
      0,
      OrderStatusLog(
        id: _nextStatusLogId(),
        orderId: order.id,
        oldStatus: order.status,
        newStatus: order.status,
        changedByUserId: changedBy.id,
        changedByName: changedBy.fullName,
        changedAt: DateTime.now(),
        notes: notes,
      ),
    );
  }

  Order _findOrderForSupervisorAction(String orderId, AppUser user) {
    final order = _findOrder(orderId);

    if (order.status != OrderStatus.pendingSupervisorApproval) {
      throw const RepositoryException(
        'هذا الطلب ليس بانتظار موافقة المشرف',
        code: 'order_not_pending_supervisor',
      );
    }

    if (user.role != UserRole.systemAdmin &&
        order.createdBranchId != user.branchId &&
        order.pickupBranchId != user.branchId) {
      throw const RepositoryException(
        'لا يمكنك معالجة طلبات فرع آخر',
        code: 'branch_scope_forbidden',
      );
    }

    return order;
  }

  Order _updateOrderStatus({
    required Order order,
    required OrderStatus newStatus,
    required AppUser changedBy,
    required String notes,
    required int progress,
    ProductionDepartment? productionDepartment,
    DriverProfile? assignedDriver,
  }) {
    final index = _orders.indexWhere((item) => item.id == order.id);
    final updated = order.copyWith(
      status: newStatus,
      progress: progress,
      productionDepartmentId: productionDepartment?.id,
      productionDepartmentName: productionDepartment?.name,
      productionDepartmentCode: productionDepartment?.code,
      assignedDriverId: assignedDriver?.id,
      assignedDriverName: assignedDriver?.fullName,
    );
    _orders[index] = updated;
    _statusLogs.insert(
      0,
      OrderStatusLog(
        id: _nextStatusLogId(),
        orderId: order.id,
        oldStatus: order.status,
        newStatus: newStatus,
        changedByUserId: changedBy.id,
        changedByName: changedBy.fullName,
        changedAt: DateTime.now(),
        notes: notes,
      ),
    );
    return updated;
  }

  int _nextStatusLogId() {
    final id = _statusLogSequence;
    _statusLogSequence++;
    return id;
  }

  int _nextNotificationId() {
    final id = _notificationSequence;
    _notificationSequence++;
    return id;
  }

  void _createNotificationForUser({
    required String userId,
    required String title,
    required String message,
    required String relatedOrderId,
    required NotificationType type,
  }) {
    if (userId.trim().isEmpty) return;
    _notifications.insert(
      0,
      AppNotification(
        id: _nextNotificationId(),
        userId: userId,
        title: title,
        message: message,
        relatedOrderId: relatedOrderId,
        createdAt: DateTime.now(),
        isRead: false,
        type: type,
      ),
    );
  }

  void _createNotificationForRole({
    required UserRole role,
    required String title,
    required String message,
    required String relatedOrderId,
    required NotificationType type,
  }) {
    for (final account in _MockData.userAccounts.values) {
      if (account.user.role != role) continue;
      _createNotificationForUser(
        userId: account.user.id,
        title: title,
        message: message,
        relatedOrderId: relatedOrderId,
        type: type,
      );
    }
  }

  void _createNotificationForProductionDepartment({
    required String departmentId,
    required String title,
    required String message,
    required String relatedOrderId,
    required NotificationType type,
  }) {
    for (final account in _MockData.userAccounts.values) {
      if (account.user.productionDepartmentId != departmentId) continue;
      _createNotificationForUser(
        userId: account.user.id,
        title: title,
        message: message,
        relatedOrderId: relatedOrderId,
        type: type,
      );
    }
  }

  ProductionDepartment? _productionDepartmentById(String id) {
    for (final department in _MockData.productionDepartments) {
      if (department.id == id) return department;
    }
    return null;
  }

  void _validateProductionTransition(Order order, OrderStatus nextStatus) {
    const allowed = {
      OrderStatus.inProduction,
      OrderStatus.productionCompleted,
      OrderStatus.readyForPickup,
      OrderStatus.readyForDelivery,
    };
    if (!allowed.contains(nextStatus)) {
      throw const RepositoryException(
        'حالة الإنتاج غير مدعومة',
        code: 'invalid_production_status',
      );
    }
    if (nextStatus == OrderStatus.inProduction &&
        order.status != OrderStatus.sentToProduction) {
      throw const RepositoryException(
        'لا يمكن بدء التنفيذ لهذه الحالة',
        code: 'invalid_production_transition',
      );
    }
    if (nextStatus == OrderStatus.productionCompleted &&
        order.status != OrderStatus.inProduction &&
        order.status != OrderStatus.sentToProduction) {
      throw const RepositoryException(
        'لا يمكن إكمال التنفيذ لهذه الحالة',
        code: 'invalid_production_transition',
      );
    }
    if (nextStatus == OrderStatus.readyForPickup) {
      if (order.status != OrderStatus.productionCompleted ||
          order.fulfillmentType != FulfillmentType.branchPickup) {
        throw const RepositoryException(
          'هذا الطلب غير مؤهل للجاهزية للاستلام',
          code: 'ready_for_pickup_not_allowed',
        );
      }
    }
    if (nextStatus == OrderStatus.readyForDelivery) {
      if (order.status != OrderStatus.productionCompleted ||
          order.fulfillmentType != FulfillmentType.customerDelivery) {
        throw const RepositoryException(
          'هذا الطلب غير مؤهل للجاهزية للتوصيل',
          code: 'ready_for_delivery_not_allowed',
        );
      }
    }
  }

  int _progressForStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.sentToProduction:
        return 3;
      case OrderStatus.inProduction:
        return 3;
      case OrderStatus.productionCompleted:
        return 4;
      case OrderStatus.readyForPickup:
      case OrderStatus.readyForDelivery:
        return 4;
      default:
        return 1;
    }
  }

  String _productionLogNote(OrderStatus status) {
    switch (status) {
      case OrderStatus.inProduction:
        return 'بدأ تنفيذ الطلب';
      case OrderStatus.productionCompleted:
        return 'اكتمل تنفيذ الطلب';
      case OrderStatus.readyForPickup:
        return 'الطلب جاهز للاستلام';
      case OrderStatus.readyForDelivery:
        return 'الطلب جاهز للتوصيل';
      default:
        return 'تحديث حالة الإنتاج';
    }
  }

  void _createProductionNotifications({
    required Order order,
    required OrderStatus newStatus,
  }) {
    switch (newStatus) {
      case OrderStatus.inProduction:
        _createNotificationForUser(
          userId: order.createdByUserId,
          title: 'بدأ تنفيذ الطلب',
          message: 'بدأ تنفيذ الطلب رقم ${order.id}',
          relatedOrderId: order.id,
          type: NotificationType.productionStarted,
        );
        return;
      case OrderStatus.productionCompleted:
        _createNotificationForRole(
          role: UserRole.distributionManager,
          title: 'اكتمل تنفيذ الطلب',
          message: 'اكتمل تنفيذ الطلب رقم ${order.id}',
          relatedOrderId: order.id,
          type: NotificationType.productionCompleted,
        );
        _createNotificationForUser(
          userId: order.createdByUserId,
          title: 'اكتمل تنفيذ الطلب',
          message: 'اكتمل تنفيذ الطلب رقم ${order.id}',
          relatedOrderId: order.id,
          type: NotificationType.productionCompleted,
        );
        return;
      case OrderStatus.readyForPickup:
        _createNotificationForUser(
          userId: order.createdByUserId,
          title: 'الطلب جاهز للاستلام',
          message: 'الطلب رقم ${order.id} جاهز للاستلام',
          relatedOrderId: order.id,
          type: NotificationType.readyForPickup,
        );
        return;
      case OrderStatus.readyForDelivery:
        _createNotificationForRole(
          role: UserRole.distributionManager,
          title: 'طلب جاهز للتوصيل',
          message: 'الطلب رقم ${order.id} جاهز للتوصيل ويحتاج إسناد سائق',
          relatedOrderId: order.id,
          type: NotificationType.readyForDelivery,
        );
        return;
      default:
        return;
    }
  }

  DriverProfile? _driverById(String id) {
    for (final driver in _drivers) {
      if (driver.id == id) return driver;
    }
    return null;
  }

  DriverProfile? _driverByUserId(String userId) {
    for (final driver in _drivers) {
      if (driver.userId == userId) return driver;
    }
    return null;
  }

  int _driverAssignmentCount(String driverId) {
    const activeStatuses = {
      OrderStatus.assignedToDriver,
      OrderStatus.driverPickedUp,
      OrderStatus.outForDelivery,
    };
    return _orders
        .where(
          (order) =>
              order.assignedDriverId == driverId &&
              activeStatuses.contains(order.status),
        )
        .length;
  }

  DeliveryAssignment _findDeliveryAssignment(String orderId) {
    for (final assignment in _deliveryAssignments) {
      if (assignment.orderId == orderId) return assignment;
    }
    throw const RepositoryException(
      'لم يتم العثور على تكليف التوصيل',
      code: 'delivery_assignment_not_found',
    );
  }

  void _updateDeliveryAssignment(DeliveryAssignment assignment) {
    final index = _deliveryAssignments.indexWhere(
      (item) => item.id == assignment.id,
    );
    if (index == -1) {
      _deliveryAssignments.insert(0, assignment);
      return;
    }
    _deliveryAssignments[index] = assignment;
  }

  void _validateDriverScope({
    required AppUser user,
    required DeliveryAssignment assignment,
  }) {
    if (user.role == UserRole.systemAdmin) return;
    final driver = _driverByUserId(user.id);
    if (driver == null || driver.id != assignment.driverId) {
      throw const RepositoryException(
        'لا يمكنك تحديث طلب غير مسند لك',
        code: 'driver_scope_forbidden',
      );
    }
  }

  void _validateDeliveryTransition(Order order, OrderStatus nextStatus) {
    const allowed = {
      OrderStatus.driverPickedUp,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    };
    if (!allowed.contains(nextStatus)) {
      throw const RepositoryException(
        'حالة التوصيل غير مدعومة',
        code: 'invalid_delivery_status',
      );
    }
    if (nextStatus == OrderStatus.driverPickedUp &&
        order.status != OrderStatus.assignedToDriver) {
      throw const RepositoryException(
        'لا يمكن استلام الطلب بهذه الحالة',
        code: 'invalid_delivery_transition',
      );
    }
    if (nextStatus == OrderStatus.outForDelivery &&
        order.status != OrderStatus.driverPickedUp) {
      throw const RepositoryException(
        'لا يمكن الخروج للتوصيل قبل استلام الطلب',
        code: 'invalid_delivery_transition',
      );
    }
    if (nextStatus == OrderStatus.delivered &&
        order.status != OrderStatus.outForDelivery) {
      throw const RepositoryException(
        'لا يمكن التسليم قبل أن يكون الطلب في الطريق',
        code: 'invalid_delivery_transition',
      );
    }
  }

  void _validatePaymentAmount({required Order order, required num amount}) {
    if (amount <= 0) {
      throw const RepositoryException(
        'مبلغ الدفعة يجب أن يكون أكبر من صفر',
        code: 'invalid_payment_amount',
      );
    }
    if (amount > order.remainingAmount) {
      throw const RepositoryException(
        'مبلغ الدفعة أكبر من المتبقي',
        code: 'payment_exceeds_remaining',
      );
    }
  }

  OrderPayment _recordPayment({
    required Order order,
    required num amount,
    required PaymentMethod method,
    required AppUser collectedBy,
    required CashClosureOwnerType collectorType,
    String transactionReference = '',
    String receiptPath = '',
    String driverId = '',
  }) {
    final payment = OrderPayment(
      id: 'PAY-${_paymentSequence.toString().padLeft(4, '0')}',
      orderId: order.id,
      customer: order.customer,
      amount: amount,
      method: method,
      collectedByUserId: collectedBy.id,
      collectedByName: collectedBy.fullName,
      collectorType: collectorType,
      createdAt: DateTime.now(),
      transactionReference: transactionReference,
      receiptPath: receiptPath,
      driverId: driverId,
      postedToErpNext: false,
    );
    _paymentSequence++;
    _orderPayments.insert(0, payment);
    _cashEntries.insert(
      0,
      CashEntry(
        orderId: order.id,
        customer: order.customer,
        method: method,
        amount: amount,
        collectedByUserId: collectedBy.id,
        collectedByName: collectedBy.fullName,
        collectorType: collectorType,
        driverId: driverId,
        postedToErpNext: false,
      ),
    );
    return payment;
  }

  Order _updateOrderRemaining(Order order, num paidAmount) {
    final index = _orders.indexWhere((item) => item.id == order.id);
    final updated = order.copyWith(
      remainingAmount: (order.remainingAmount - paidAmount).clamp(
        0,
        double.infinity,
      ),
    );
    _orders[index] = updated;
    return updated;
  }

  String _deliveryLogNote(OrderStatus status, String notes) {
    final extra = notes.trim().isEmpty ? '' : ' - ${notes.trim()}';
    switch (status) {
      case OrderStatus.driverPickedUp:
        return 'استلم السائق الطلب$extra';
      case OrderStatus.outForDelivery:
        return 'خرج السائق للتوصيل$extra';
      case OrderStatus.delivered:
        return 'تم تسليم الطلب$extra';
      default:
        return 'تحديث حالة التوصيل$extra';
    }
  }

  void _createDeliveryNotifications({
    required Order order,
    required OrderStatus status,
    String failureReason = '',
  }) {
    switch (status) {
      case OrderStatus.driverPickedUp:
        _createNotificationForUser(
          userId: order.createdByUserId,
          title: 'استلم السائق الطلب',
          message: 'استلم السائق الطلب رقم ${order.id}',
          relatedOrderId: order.id,
          type: NotificationType.driverPickedUp,
        );
        return;
      case OrderStatus.outForDelivery:
        _createNotificationForUser(
          userId: order.createdByUserId,
          title: 'الطلب في الطريق',
          message: 'خرج الطلب رقم ${order.id} للتوصيل',
          relatedOrderId: order.id,
          type: NotificationType.outForDelivery,
        );
        return;
      case OrderStatus.delivered:
        _createNotificationForUser(
          userId: order.createdByUserId,
          title: 'تم تسليم الطلب',
          message: 'تم تسليم الطلب رقم ${order.id}',
          relatedOrderId: order.id,
          type: NotificationType.orderDelivered,
        );
        _createNotificationForRole(
          role: UserRole.distributionManager,
          title: 'تم تسليم طلب توصيل',
          message: 'تم تسليم الطلب رقم ${order.id}',
          relatedOrderId: order.id,
          type: NotificationType.orderDelivered,
        );
        return;
      case OrderStatus.deliveryFailed:
        _createNotificationForRole(
          role: UserRole.distributionManager,
          title: 'تعذر تسليم طلب',
          message:
              'تعذر تسليم الطلب رقم ${order.id}${failureReason.isEmpty ? '' : ': $failureReason'}',
          relatedOrderId: order.id,
          type: NotificationType.deliveryFailed,
        );
        _createNotificationForUser(
          userId: order.createdByUserId,
          title: 'تعذر تسليم الطلب',
          message: 'تعذر تسليم الطلب رقم ${order.id}',
          relatedOrderId: order.id,
          type: NotificationType.deliveryFailed,
        );
        return;
      default:
        return;
    }
  }

  void _seedOrderPaymentsFromCashEntries() {
    if (_orderPayments.isNotEmpty) return;
    for (var index = 0; index < _cashEntries.length; index++) {
      final entry = _cashEntries[index];
      final order = _orders
          .where((item) => item.id == entry.orderId)
          .cast<Order?>()
          .firstWhere((item) => item != null, orElse: () => null);
      final collectedByUserId = entry.collectedByUserId.isNotEmpty
          ? entry.collectedByUserId
          : order?.createdByUserId.isNotEmpty == true
          ? order!.createdByUserId
          : 'EMP-0001';
      final collectedByName = entry.collectedByName.isNotEmpty
          ? entry.collectedByName
          : order?.createdByName.isNotEmpty == true
          ? order!.createdByName
          : 'أحمد الراجحي';
      _orderPayments.add(
        OrderPayment(
          id: 'PAY-${_paymentSequence.toString().padLeft(4, '0')}',
          orderId: entry.orderId,
          customer: entry.customer,
          amount: entry.amount,
          method: entry.method,
          collectedByUserId: collectedByUserId,
          collectedByName: collectedByName,
          collectorType: entry.collectorType,
          createdAt: DateTime.now().subtract(Duration(hours: index + 1)),
          driverId: entry.driverId,
          postedToErpNext: entry.postedToErpNext,
        ),
      );
      _paymentSequence++;
    }
  }

  DailyCashClosure _findOrCreateOpenClosure({
    required AppUser user,
    required CashClosureOwnerType type,
    required String date,
  }) {
    for (final closure in _cashClosures) {
      if (closure.ownerUserId == user.id &&
          closure.date == date &&
          (closure.status == CashClosureStatus.open ||
              closure.status == CashClosureStatus.returnedForReview)) {
        return closure;
      }
    }
    final closure = DailyCashClosure(
      id: 'DCC-${_closureSequence.toString().padLeft(4, '0')}',
      date: date,
      ownerUserId: user.id,
      ownerName: user.fullName,
      ownerRoleLabel: user.role.label,
      branchId: user.branchId,
      branch: user.branchName,
      type: type,
      status: CashClosureStatus.open,
      orderCount: 0,
      entries: const [],
      payments: const [],
      remainingFromCustomers: 0,
      collectionRate: 0,
    );
    _closureSequence++;
    _cashClosures.insert(0, closure);
    _addCashClosureLog(
      closureId: closure.id,
      oldStatus: null,
      newStatus: CashClosureStatus.open,
      changedBy: user,
      notes: 'تم فتح العهدة اليومية',
    );
    return closure;
  }

  List<OrderPayment> _paymentsForClosureOwner(
    AppUser user,
    DailyCashClosure closure,
  ) {
    return _orderPayments.where((payment) {
      if (payment.collectedByUserId != user.id) return false;
      if (payment.closureId.isEmpty) return true;
      return payment.closureId == closure.id;
    }).toList();
  }

  DailyCashClosure _refreshClosure(String closureId) {
    final index = _cashClosures.indexWhere((item) => item.id == closureId);
    if (index == -1) {
      throw const RepositoryException(
        'لم يتم العثور على العهدة',
        code: 'cash_closure_not_found',
      );
    }
    final closure = _cashClosures[index];
    final payments = _orderPayments
        .where((payment) => payment.closureId == closure.id)
        .toList();
    final refreshed = _buildClosureSnapshot(
      closure: closure,
      payments: payments,
    );
    _cashClosures[index] = refreshed;
    return refreshed;
  }

  DailyCashClosure _buildClosureSnapshot({
    required DailyCashClosure closure,
    required List<OrderPayment> payments,
  }) {
    final totals = _calculateClosureTotals(payments);
    final entries = payments
        .map(
          (payment) => CashEntry(
            orderId: payment.orderId,
            customer: payment.customer,
            method: payment.method,
            amount: payment.amount,
            collectedByUserId: payment.collectedByUserId,
            collectedByName: payment.collectedByName,
            collectorType: payment.collectorType,
            driverId: payment.driverId,
            postedToErpNext: payment.postedToErpNext,
          ),
        )
        .toList();
    final logs =
        _cashClosureLogs.where((log) => log.closureId == closure.id).toList()
          ..sort(
            (first, second) => first.changedAt.compareTo(second.changedAt),
          );
    return closure.copyWith(
      orderCount: totals.orderCount,
      entries: entries,
      payments: payments,
      logs: logs,
      recordedAmount: closure.recordedAmount == 0
          ? totals.total
          : closure.recordedAmount,
    );
  }

  CashClosureTotals _calculateClosureTotals(List<OrderPayment> payments) {
    num methodTotal(PaymentMethod method) {
      return payments
          .where((payment) => payment.method == method)
          .fold<num>(0, (total, payment) => total + payment.amount);
    }

    return CashClosureTotals(
      cash: methodTotal(PaymentMethod.cash),
      card: methodTotal(PaymentMethod.card),
      transfer: methodTotal(PaymentMethod.transfer),
      other: methodTotal(PaymentMethod.other),
      orderCount: payments.map((payment) => payment.orderId).toSet().length,
    );
  }

  DailyCashClosure _updateCashClosureStatus({
    required DailyCashClosure closure,
    required CashClosureStatus newStatus,
    required AppUser changedBy,
    required String notes,
  }) {
    final index = _cashClosures.indexWhere((item) => item.id == closure.id);
    final updated = closure.copyWith(status: newStatus);
    _cashClosures[index] = updated;
    _addCashClosureLog(
      closureId: closure.id,
      oldStatus: closure.status,
      newStatus: newStatus,
      changedBy: changedBy,
      notes: notes,
    );
    return _refreshClosure(closure.id);
  }

  void _addCashClosureLog({
    required String closureId,
    required CashClosureStatus? oldStatus,
    required CashClosureStatus newStatus,
    required AppUser changedBy,
    required String notes,
  }) {
    _cashClosureLogs.insert(
      0,
      CashClosureLog(
        id: _cashClosureLogSequence,
        closureId: closureId,
        oldStatus: oldStatus,
        newStatus: newStatus,
        changedByUserId: changedBy.id,
        changedByName: changedBy.fullName,
        changedAt: DateTime.now(),
        notes: notes,
      ),
    );
    _cashClosureLogSequence++;
  }

  void _setPaymentStatuses({
    required String closureId,
    required OrderPaymentStatus status,
  }) {
    for (var index = 0; index < _orderPayments.length; index++) {
      final payment = _orderPayments[index];
      if (payment.closureId != closureId) continue;
      _orderPayments[index] = payment.copyWith(status: status);
    }
  }

  void _replacePayment(OrderPayment payment) {
    final index = _orderPayments.indexWhere((item) => item.id == payment.id);
    if (index == -1) {
      _orderPayments.insert(0, payment);
      return;
    }
    _orderPayments[index] = payment;
  }

  String _nextOrderId() {
    final highest = _orders
        .map((order) => int.tryParse(order.id.replaceAll('ORD-', '')) ?? 0)
        .fold<int>(0, (max, value) => value > max ? value : max);
    return 'ORD-${(highest + 1).toString().padLeft(4, '0')}';
  }

  int _nextDocumentSequence(String prefix, Iterable<String> ids) {
    return ids
            .map((id) {
              if (!id.startsWith(prefix)) return 0;
              return int.tryParse(id.split('-').last) ?? 0;
            })
            .fold<int>(0, (max, value) => value > max ? value : max) +
        1;
  }

  String _nextAccountingId(String prefix, int sequence) {
    return '$prefix${DateTime.now().year}-${sequence.toString().padLeft(5, '0')}';
  }

  String _nextCreateOrderId() {
    final id = 'ORD-2026-${_createdOrderSequence.toString().padLeft(5, '0')}';
    _createdOrderSequence++;
    return id;
  }

  Order _orderFromRequest(CreateOrderRequest request, OrderStatus status) {
    final attachments = List<OrderAttachmentDraft>.of(request.attachments);
    final receipt = request.paymentReceipt;
    if (receipt != null) attachments.add(receipt);
    return Order(
      id: _nextCreateOrderId(),
      customer: request.customerName.trim().isEmpty
          ? request.companyName.trim()
          : request.customerName.trim(),
      productSummary: _requestProductSummary(request),
      amount: request.grandTotal,
      status: status,
      date: formatDate(DateTime.now()),
      progress: status == OrderStatus.draft ? 0 : 1,
      paymentMethod: request.paymentMethod,
      customerPhone: request.customerPhone,
      customerType: request.customerType,
      companyName: request.companyName,
      taxNumber: request.taxNumber,
      companyAddress: request.companyAddress,
      companyEmail: request.companyEmail,
      companyContactPerson: request.companyContactPerson,
      categoryId: request.department?.id ?? '',
      categoryName: request.department?.name ?? '',
      lineItems: List<OrderLineDraft>.of(request.lineItems),
      attachments: attachments,
      details: request.orderDetails,
      customerNotes: request.customerNotes,
      pickupDate: request.pickupDate,
      pickupTime: request.pickupTime,
      fulfillmentType: request.fulfillmentType,
      deliveryDetails: request.deliveryDetails,
      depositAmount: request.depositAmount,
      remainingAmount: request.remainingAmount,
      createdBranch: request.createdBranch.name,
      createdBranchId: request.createdBranch.id,
      pickupBranch: request.pickupBranch.name,
      pickupBranchId: request.pickupBranch.id,
      createdByUserId: request.createdByUserId,
      createdByName: request.createdByName,
    );
  }

  String _requestProductSummary(CreateOrderRequest request) {
    final names = request.lineItems.map((line) {
      return line.quantity > 1
          ? '${line.product.name} × ${line.quantity}'
          : line.product.name;
    }).toList();
    if (names.isEmpty) return 'طلب بدون منتجات';
    if (names.length <= 2) return names.join(' + ');
    return '${names.take(2).join(' + ')} + ${names.length - 2} أخرى';
  }

  String _draftProductSummary(OrderDraft draft, List<Product> products) {
    final names = draft.quantities.entries.map((entry) {
      Product? product;
      for (final item in products) {
        if (item.id == entry.key) {
          product = item;
          break;
        }
      }
      if (product == null) return 'منتج غير معروف';
      return entry.value > 1
          ? '${product.name} × ${entry.value}'
          : product.name;
    }).toList();

    if (names.isEmpty) return 'طلب بدون منتجات';
    if (names.length <= 2) return names.join(' + ');
    return '${names.take(2).join(' + ')} + ${names.length - 2} أخرى';
  }
}

class _MockData {
  const _MockData._();

  static const userAccounts = {
    'employee': _MockAccount(
      password: '123456',
      user: AppUser(
        id: 'EMP-0001',
        fullName: 'أحمد الراجحي',
        email: 'employee@awamir.local',
        phone: '0501111111',
        role: UserRole.branchEmployee,
        branchId: 'BR-RUH-MUR',
        branchName: 'فرع الرياض — المروج',
        isActive: true,
      ),
    ),
    'supervisor': _MockAccount(
      password: '123456',
      user: AppUser(
        id: 'EMP-0002',
        fullName: 'سارة العتيبي',
        email: 'supervisor@awamir.local',
        phone: '0502222222',
        role: UserRole.branchSupervisor,
        branchId: 'BR-RUH-MUR',
        branchName: 'فرع الرياض — المروج',
        isActive: true,
      ),
    ),
    'distribution': _MockAccount(
      password: '123456',
      user: AppUser(
        id: 'EMP-0003',
        fullName: 'ماجد الحربي',
        email: 'distribution@awamir.local',
        phone: '0503333333',
        role: UserRole.distributionManager,
        branchId: 'DIST-RUH',
        branchName: 'مركز توزيع الرياض',
        isActive: true,
      ),
    ),
    'production': _MockAccount(
      password: '123456',
      user: AppUser(
        id: 'EMP-0004',
        fullName: 'نواف القحطاني',
        email: 'production@awamir.local',
        phone: '0504444444',
        role: UserRole.productionUser,
        branchId: 'PROD-RUH',
        branchName: 'مصنع الحلويات',
        isActive: true,
        productionDepartmentId: 'PD-SWEETS',
      ),
    ),
    'driver': _MockAccount(
      password: '123456',
      user: AppUser(
        id: 'EMP-0005',
        fullName: 'عبدالله الدوسري',
        email: 'driver@awamir.local',
        phone: '0505555555',
        role: UserRole.driver,
        branchId: 'DIST-RUH',
        branchName: 'مركز توزيع الرياض',
        isActive: true,
      ),
    ),
    'cashier': _MockAccount(
      password: '123456',
      user: AppUser(
        id: 'EMP-0006',
        fullName: 'ريم الشهري',
        email: 'cashier@awamir.local',
        phone: '0506666666',
        role: UserRole.cashier,
        branchId: 'CASH-RUH',
        branchName: 'الخزينة المركزية',
        isActive: true,
      ),
    ),
    'accountant': _MockAccount(
      password: '123456',
      user: AppUser(
        id: 'EMP-0007',
        fullName: 'خالد الناصر',
        email: 'accountant@awamir.local',
        phone: '0507777777',
        role: UserRole.accountant,
        branchId: 'ACC-RUH',
        branchName: 'الإدارة المالية',
        isActive: true,
      ),
    ),
    'admin': _MockAccount(
      password: '123456',
      user: AppUser(
        id: 'EMP-0008',
        fullName: 'مدير النظام',
        email: 'admin@awamir.local',
        phone: '0508888888',
        role: UserRole.systemAdmin,
        branchId: 'HQ',
        branchName: 'الإدارة العامة',
        isActive: true,
      ),
    ),
  };

  static const departments = [
    ProductDepartment(
      id: 'special',
      name: 'طلبات خاصة',
      icon: Icons.restaurant,
    ),
    ProductDepartment(id: 'buffet', name: 'البوفيه', icon: Icons.room_service),
    ProductDepartment(id: 'sweets', name: 'الحلويات', icon: Icons.cake),
    ProductDepartment(id: 'kitchen', name: 'المطبخ', icon: Icons.soup_kitchen),
    ProductDepartment(
      id: 'hospitality',
      name: 'الضيافة',
      icon: Icons.local_cafe,
    ),
  ];

  static const productionDepartments = [
    ProductionDepartment(
      id: 'PD-SWEETS',
      name: 'مصنع الحلويات',
      code: 'SWEETS',
      isActive: true,
    ),
    ProductionDepartment(
      id: 'PD-KITCHEN',
      name: 'المطبخ',
      code: 'KITCHEN',
      isActive: true,
    ),
    ProductionDepartment(
      id: 'PD-SPECIAL',
      name: 'قسم الطلبات الخاصة',
      code: 'SPECIAL',
      isActive: true,
    ),
    ProductionDepartment(
      id: 'PD-BUFFET',
      name: 'قسم البوفيه',
      code: 'BUFFET',
      isActive: true,
    ),
  ];

  static const productDepartmentMappings = [
    ProductDepartmentMapping(
      categoryId: 'sweets',
      defaultDepartmentId: 'PD-SWEETS',
    ),
    ProductDepartmentMapping(
      categoryId: 'kitchen',
      defaultDepartmentId: 'PD-KITCHEN',
    ),
    ProductDepartmentMapping(
      categoryId: 'special',
      defaultDepartmentId: 'PD-SPECIAL',
    ),
    ProductDepartmentMapping(
      categoryId: 'buffet',
      defaultDepartmentId: 'PD-BUFFET',
    ),
    ProductDepartmentMapping(
      categoryId: 'hospitality',
      defaultDepartmentId: 'PD-SPECIAL',
    ),
  ];

  static const drivers = [
    DriverProfile(
      id: 'DRV-001',
      userId: 'EMP-0005',
      fullName: 'عبدالله الدوسري',
      phone: '0505555555',
      branchId: 'BR-RUH-MUR',
      branchName: 'فرع الرياض — المروج',
      isActive: true,
    ),
    DriverProfile(
      id: 'DRV-002',
      userId: 'EMP-DRV2',
      fullName: 'سائق فرع الشرائع',
      phone: '0505555556',
      branchId: 'BR-MAK-SHR',
      branchName: 'فرع مكة — الشرائع',
      isActive: true,
    ),
    DriverProfile(
      id: 'DRV-003',
      userId: 'EMP-DRV3',
      fullName: 'سائق عام',
      phone: '0505555557',
      branchId: 'ALL',
      branchName: 'كل الفروع',
      isActive: true,
    ),
  ];

  static const deliveryAssignments = <DeliveryAssignment>[];
  static const orderPayments = <OrderPayment>[];
  static const cashClosures = <DailyCashClosure>[];
  static const cashClosureLogs = <CashClosureLog>[];
  static const paymentAllocations = <PaymentAllocation>[];

  static const products = [
    Product(
      id: 1,
      departmentId: 'special',
      name: 'طبق كبسة لحم',
      description: 'أرز بسمتي مع لحم ضاني محمّر',
      price: 120,
      imageUrl:
          'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&h=250&fit=crop',
      badge: 'الأكثر طلباً',
      badgeColor: AppColors.red,
    ),
    Product(
      id: 2,
      departmentId: 'special',
      name: 'طبق مندي دجاج',
      description: 'مندي بدجاج مدخن على الحطب',
      price: 95,
      imageUrl:
          'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d4a?w=400&h=250&fit=crop',
    ),
    Product(
      id: 3,
      departmentId: 'special',
      name: 'طبق مظبي',
      description: 'مظبي لحم تقليدي يمني',
      price: 110,
      imageUrl:
          'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=400&h=250&fit=crop',
      badge: 'جديد',
      badgeColor: AppColors.green,
    ),
    Product(
      id: 4,
      departmentId: 'special',
      name: 'مشاوي مشكلة',
      description: 'مجموعة مشاوي متنوعة لـ 4 أشخاص',
      price: 180,
      imageUrl:
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=400&h=250&fit=crop',
    ),
    Product(
      id: 5,
      departmentId: 'special',
      name: 'برياني دجاج',
      description: 'برياني بالبهارات الهندية',
      price: 85,
      imageUrl:
          'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=400&h=250&fit=crop',
    ),
    Product(
      id: 6,
      departmentId: 'buffet',
      name: 'بوفيه 20 شخص',
      description: 'تشكيلة أطباق لـ 20 ضيف',
      price: 1800,
      imageUrl:
          'https://images.unsplash.com/photo-1555244162-803834f70033?w=400&h=250&fit=crop',
      badge: 'الأكثر طلباً',
      badgeColor: AppColors.red,
    ),
    Product(
      id: 7,
      departmentId: 'buffet',
      name: 'بوفيه 50 شخص',
      description: 'بوفيه فاخر مع المشاوي',
      price: 4000,
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&h=250&fit=crop',
    ),
    Product(
      id: 8,
      departmentId: 'buffet',
      name: 'بوفيه 100 شخص',
      description: 'بوفيه ملكي للمناسبات',
      price: 7200,
      imageUrl:
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400&h=250&fit=crop',
      badge: 'مناسبات',
      badgeColor: AppColors.navy,
    ),
    Product(
      id: 9,
      departmentId: 'sweets',
      name: 'كنافة نابلسية',
      description: 'كنافة بالجبنة طازجة',
      price: 65,
      imageUrl:
          'https://images.unsplash.com/photo-1579888944880-d98341245702?w=400&h=250&fit=crop',
    ),
    Product(
      id: 10,
      departmentId: 'sweets',
      name: 'بقلاوة مشكلة',
      description: 'صينية بقلاوة بأنواع مختلفة',
      price: 120,
      imageUrl:
          'https://images.unsplash.com/photo-1519676867240-f03562e64571?w=400&h=250&fit=crop',
    ),
    Product(
      id: 11,
      departmentId: 'sweets',
      name: 'تشيز كيك توت',
      description: 'تشيز كيك كريمي بصوص التوت',
      price: 85,
      imageUrl:
          'https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=400&h=250&fit=crop',
      badge: 'جديد',
      badgeColor: AppColors.green,
    ),
    Product(
      id: 12,
      departmentId: 'sweets',
      name: 'كب كيك 12 حبة',
      description: 'كب كيك بنكهات متنوعة',
      price: 90,
      imageUrl:
          'https://images.unsplash.com/photo-1587668178277-295251f900ce?w=400&h=250&fit=crop',
    ),
    Product(
      id: 13,
      departmentId: 'kitchen',
      name: 'مقلوبة',
      description: 'مقلوبة باذنجان باللحم',
      price: 100,
      imageUrl:
          'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=400&h=250&fit=crop',
    ),
    Product(
      id: 14,
      departmentId: 'kitchen',
      name: 'فطائر مشكلة',
      description: '12 قطعة بالجبن واللحم',
      price: 55,
      imageUrl:
          'https://images.unsplash.com/photo-1604068549290-dea0e4a305ca?w=400&h=250&fit=crop',
    ),
    Product(
      id: 15,
      departmentId: 'kitchen',
      name: 'سمبوسة لحم',
      description: '30 قطعة مقرمشة',
      price: 70,
      imageUrl:
          'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&h=250&fit=crop',
      badge: 'الأكثر طلباً',
      badgeColor: AppColors.red,
    ),
    Product(
      id: 16,
      departmentId: 'hospitality',
      name: 'قهوة + تمر',
      description: 'صينية قهوة عربية مع التمر',
      price: 75,
      imageUrl:
          'https://images.unsplash.com/photo-1514432324607-a09d9b4aefda?w=400&h=250&fit=crop',
    ),
    Product(
      id: 17,
      departmentId: 'hospitality',
      name: 'صينية فواكه',
      description: 'تشكيلة فواكه طازجة',
      price: 120,
      imageUrl:
          'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=400&h=250&fit=crop',
    ),
    Product(
      id: 18,
      departmentId: 'hospitality',
      name: 'عصائر طازجة',
      description: 'تشكيلة عصائر فريش',
      price: 50,
      imageUrl:
          'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&h=250&fit=crop',
    ),
  ];

  static final orders = [
    Order(
      id: 'ORD-0022',
      customer: 'منال السعدي',
      customerPhone: '0509000022',
      productSummary: 'تشيز كيك توت',
      amount: 110,
      status: OrderStatus.readyForDelivery,
      date: '2026-05-02',
      pickupDate: DateTime(2026, 5, 7),
      pickupTime: const TimeOfDay(hour: 18, minute: 0),
      progress: 4,
      paymentMethod: PaymentMethod.card,
      depositAmount: 60,
      remainingAmount: 50,
      createdBranch: 'فرع الرياض — المروج',
      createdBranchId: 'BR-RUH-MUR',
      pickupBranch: 'فرع الرياض — المروج',
      pickupBranchId: 'BR-RUH-MUR',
      createdByUserId: 'EMP-0001',
      createdByName: 'أحمد الراجحي',
      categoryId: 'sweets',
      categoryName: 'الحلويات',
      productionDepartmentId: 'PD-SWEETS',
      productionDepartmentName: 'مصنع الحلويات',
      productionDepartmentCode: 'SWEETS',
      fulfillmentType: FulfillmentType.customerDelivery,
      deliveryDetails: DeliveryDetailsDraft(
        addressText: 'الرياض، حي المروج، شارع العليا',
        district: 'المروج',
        city: 'الرياض',
        googleMapsUrl: 'https://maps.google.com/?q=24.774265,46.738586',
        latitude: 24.774265,
        longitude: 46.738586,
        notes: 'الاتصال قبل الوصول بعشر دقائق',
        deliveryFee: 25,
      ),
      details: 'تغليف هدية',
      lineItems: [OrderLineDraft(product: products[10], quantity: 1)],
    ),
    Order(
      id: 'ORD-0021',
      customer: 'عبدالعزيز الفهد',
      customerPhone: '0509000021',
      productSummary: 'كنافة نابلسية × 2',
      amount: 130,
      status: OrderStatus.readyForPickup,
      date: '2026-05-02',
      pickupDate: DateTime(2026, 5, 7),
      pickupTime: const TimeOfDay(hour: 20, minute: 0),
      progress: 4,
      paymentMethod: PaymentMethod.cash,
      depositAmount: 50,
      remainingAmount: 80,
      createdBranch: 'فرع الرياض — المروج',
      createdBranchId: 'BR-RUH-MUR',
      pickupBranch: 'فرع الرياض — المروج',
      pickupBranchId: 'BR-RUH-MUR',
      createdByUserId: 'EMP-0001',
      createdByName: 'أحمد الراجحي',
      categoryId: 'sweets',
      categoryName: 'الحلويات',
      productionDepartmentId: 'PD-SWEETS',
      productionDepartmentName: 'مصنع الحلويات',
      productionDepartmentCode: 'SWEETS',
      details: 'استلام من الفرع',
      lineItems: [OrderLineDraft(product: products[8], quantity: 2)],
    ),
    Order(
      id: 'ORD-0020',
      customer: 'بدر الشمري',
      customerPhone: '0509000020',
      productSummary: 'فطائر مشكلة',
      amount: 55,
      status: OrderStatus.readyForPickup,
      date: '2026-05-02',
      pickupDate: DateTime(2026, 5, 7),
      pickupTime: const TimeOfDay(hour: 16, minute: 30),
      progress: 4,
      paymentMethod: PaymentMethod.transfer,
      depositAmount: 55,
      remainingAmount: 0,
      createdBranch: 'فرع مكة — الشرائع',
      createdBranchId: 'BR-MAK-SHR',
      pickupBranch: 'فرع مكة — الشرائع',
      pickupBranchId: 'BR-MAK-SHR',
      createdByUserId: 'EMP-OTHER',
      createdByName: 'موظف فرع الشرائع',
      categoryId: 'kitchen',
      categoryName: 'المطبخ',
      productionDepartmentId: 'PD-KITCHEN',
      productionDepartmentName: 'المطبخ',
      productionDepartmentCode: 'KITCHEN',
      details: 'جاهز للاستلام من فرع الشرائع',
      lineItems: [OrderLineDraft(product: products[13], quantity: 1)],
    ),
    Order(
      id: 'ORD-0019',
      customer: 'شركة الضيافة الحديثة',
      customerPhone: '0509000019',
      customerType: CustomerType.company,
      companyName: 'شركة الضيافة الحديثة',
      taxNumber: '300000000000019',
      companyAddress: 'الرياض، حي النرجس',
      companyEmail: 'orders@modern-hospitality.local',
      companyContactPerson: 'راكان السالم',
      productSummary: 'بقلاوة مشكلة × 2',
      amount: 265,
      status: OrderStatus.sentToDistribution,
      date: '2026-05-01',
      pickupDate: DateTime(2026, 5, 6),
      pickupTime: const TimeOfDay(hour: 17, minute: 30),
      progress: 2,
      paymentMethod: PaymentMethod.transfer,
      depositAmount: 100,
      remainingAmount: 165,
      createdBranch: 'فرع الرياض — المروج',
      createdBranchId: 'BR-RUH-MUR',
      pickupBranch: 'فرع الرياض — المروج',
      pickupBranchId: 'BR-RUH-MUR',
      createdByUserId: 'EMP-0001',
      createdByName: 'أحمد الراجحي',
      categoryId: 'sweets',
      categoryName: 'الحلويات',
      fulfillmentType: FulfillmentType.customerDelivery,
      deliveryDetails: DeliveryDetailsDraft(
        addressText: 'الرياض، حي النرجس، طريق أبي بكر',
        district: 'النرجس',
        city: 'الرياض',
        deliveryFee: 25,
      ),
      details: 'تغليف مناسب لاجتماع شركة',
      lineItems: [OrderLineDraft(product: products[9], quantity: 2)],
    ),
    Order(
      id: 'ORD-0018',
      customer: 'هيا المطيري',
      customerPhone: '0509000018',
      productSummary: 'كنافة نابلسية',
      amount: 65,
      status: OrderStatus.sentToDistribution,
      date: '2026-05-01',
      pickupDate: DateTime(2026, 5, 6),
      pickupTime: const TimeOfDay(hour: 19, minute: 0),
      progress: 2,
      paymentMethod: PaymentMethod.cash,
      depositAmount: 30,
      remainingAmount: 35,
      createdBranch: 'فرع الرياض — المروج',
      createdBranchId: 'BR-RUH-MUR',
      pickupBranch: 'فرع الرياض — المروج',
      pickupBranchId: 'BR-RUH-MUR',
      createdByUserId: 'EMP-0001',
      createdByName: 'أحمد الراجحي',
      categoryId: 'sweets',
      categoryName: 'الحلويات',
      details: 'تجهيز طازج قبل موعد الاستلام',
      lineItems: [OrderLineDraft(product: products[8], quantity: 1)],
    ),
    Order(
      id: 'ORD-0017',
      customer: 'لمياء الشهري',
      customerPhone: '0509000017',
      productSummary: 'بوفيه 20 شخص',
      amount: 1800,
      status: OrderStatus.pendingSupervisorApproval,
      date: '2026-05-01',
      pickupDate: DateTime(2026, 5, 3),
      pickupTime: const TimeOfDay(hour: 18, minute: 30),
      progress: 1,
      paymentMethod: PaymentMethod.cash,
      depositAmount: 500,
      remainingAmount: 1300,
      createdBranch: 'فرع الرياض — المروج',
      createdBranchId: 'BR-RUH-MUR',
      pickupBranch: 'فرع الرياض — المروج',
      pickupBranchId: 'BR-RUH-MUR',
      createdByUserId: 'EMP-0001',
      createdByName: 'أحمد الراجحي',
      categoryId: 'buffet',
      categoryName: 'البوفيه',
      details: 'تجهيز بوفيه استقبال مع مشروبات ساخنة',
      lineItems: [OrderLineDraft(product: products[5], quantity: 1)],
    ),
    Order(
      id: 'ORD-0016',
      customer: 'سعود العمري',
      customerPhone: '0509000016',
      productSummary: 'طبق مظبي',
      amount: 110,
      status: OrderStatus.pendingSupervisorApproval,
      date: '2026-05-01',
      pickupDate: DateTime(2026, 5, 4),
      pickupTime: const TimeOfDay(hour: 14, minute: 0),
      progress: 1,
      paymentMethod: PaymentMethod.card,
      depositAmount: 50,
      remainingAmount: 60,
      createdBranch: 'فرع الرياض — النخيل',
      createdBranchId: 'BR-RUH-NKH',
      pickupBranch: 'فرع الرياض — النخيل',
      pickupBranchId: 'BR-RUH-NKH',
      createdByUserId: 'EMP-OTHER',
      createdByName: 'موظف فرع آخر',
      categoryId: 'special',
      categoryName: 'طلبات خاصة',
      details: 'طلب فردي للاستلام من الفرع',
      lineItems: [OrderLineDraft(product: products[2], quantity: 1)],
    ),
    Order(
      id: 'ORD-0015',
      customer: 'خالد العتيبي',
      customerPhone: '0501234567',
      productSummary: 'كبسة + مشاوي',
      amount: 3620,
      status: OrderStatus.sentToDistribution,
      date: '2026-05-01',
      progress: 2,
      paymentMethod: PaymentMethod.transfer,
      depositAmount: 500,
      remainingAmount: 3120,
      createdBranch: 'فرع الرياض — المروج',
      createdBranchId: 'BR-RUH-MUR',
      pickupBranch: 'فرع الرياض — المروج',
      pickupBranchId: 'BR-RUH-MUR',
      createdByUserId: 'EMP-0001',
      createdByName: 'أحمد الراجحي',
      categoryId: 'special',
      categoryName: 'طلبات خاصة',
      lineItems: [
        OrderLineDraft(product: products[0], quantity: 2),
        OrderLineDraft(product: products[3], quantity: 1),
      ],
    ),
    Order(
      id: 'ORD-0014',
      customer: 'نورة القحطاني',
      customerPhone: '0509000014',
      productSummary: 'مشاوي 4 أشخاص',
      amount: 300,
      status: OrderStatus.ready,
      date: '2026-05-01',
      progress: 3,
      paymentMethod: PaymentMethod.cash,
    ),
    Order(
      id: 'ORD-0013',
      customer: 'فهد الدوسري',
      customerPhone: '0509000013',
      productSummary: 'حلويات مشكلة',
      amount: 250,
      status: OrderStatus.pendingSupervisorApproval,
      date: '2026-05-01',
      pickupDate: DateTime(2026, 5, 5),
      pickupTime: const TimeOfDay(hour: 20, minute: 15),
      progress: 1,
      paymentMethod: PaymentMethod.card,
      depositAmount: 100,
      remainingAmount: 150,
      createdBranch: 'فرع الرياض — المروج',
      createdBranchId: 'BR-RUH-MUR',
      pickupBranch: 'فرع الرياض — المروج',
      pickupBranchId: 'BR-RUH-MUR',
      createdByUserId: 'EMP-0001',
      createdByName: 'أحمد الراجحي',
      categoryId: 'sweets',
      categoryName: 'الحلويات',
      fulfillmentType: FulfillmentType.customerDelivery,
      deliveryDetails: DeliveryDetailsDraft(
        addressText: 'الرياض، حي المروج، شارع الأمير مقرن',
        district: 'المروج',
        city: 'الرياض',
        googleMapsUrl: 'https://maps.google.com/?q=24.774265,46.738586',
        latitude: 24.774265,
        longitude: 46.738586,
        deliveryFee: 25,
      ),
      lineItems: [OrderLineDraft(product: products[9], quantity: 2)],
    ),
    Order(
      id: 'ORD-0012',
      customer: 'عبدالله الناصر',
      productSummary: 'طبق كبسة كبير',
      amount: 150,
      status: OrderStatus.delivered,
      date: '2026-05-01',
      progress: 4,
      paymentMethod: PaymentMethod.cash,
    ),
    Order(
      id: 'ORD-0011',
      customer: 'فاطمة الأحمد',
      productSummary: 'مناسف ورق عنب',
      amount: 220,
      status: OrderStatus.delivered,
      date: '2026-05-01',
      progress: 4,
      paymentMethod: PaymentMethod.transfer,
    ),
    Order(
      id: 'ORD-0010',
      customer: 'محمد السبيعي',
      productSummary: 'حلويات مشكلة',
      amount: 85,
      status: OrderStatus.ready,
      date: '2026-04-30',
      progress: 3,
      paymentMethod: PaymentMethod.card,
    ),
  ];

  static const cashEntries = [
    CashEntry(
      orderId: 'ORD-0012',
      customer: 'عبدالله الناصر',
      method: PaymentMethod.cash,
      amount: 150,
    ),
    CashEntry(
      orderId: 'ORD-0011',
      customer: 'فاطمة الأحمد',
      method: PaymentMethod.transfer,
      amount: 220,
    ),
    CashEntry(
      orderId: 'ORD-0013',
      customer: 'فهد الدوسري',
      method: PaymentMethod.card,
      amount: 250,
    ),
    CashEntry(
      orderId: 'ORD-0014',
      customer: 'نورة القحطاني',
      method: PaymentMethod.cash,
      amount: 300,
    ),
    CashEntry(
      orderId: 'ORD-0016',
      customer: 'سعود العمري',
      method: PaymentMethod.card,
      amount: 110,
    ),
    CashEntry(
      orderId: 'ORD-0015',
      customer: 'خالد العتيبي',
      method: PaymentMethod.transfer,
      amount: 500,
    ),
    CashEntry(
      orderId: 'ORD-0017',
      customer: 'لمياء الشهري',
      method: PaymentMethod.cash,
      amount: 1800,
    ),
    CashEntry(
      orderId: 'ORD-0010',
      customer: 'محمد السبيعي',
      method: PaymentMethod.card,
      amount: 85,
    ),
  ];

  static final notifications = [
    AppNotification(
      id: 1,
      userId: 'EMP-0001',
      title: 'تمت الموافقة على الطلب',
      message: 'طلب #ORD-0015 — خالد العتيبي',
      relatedOrderId: 'ORD-0015',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: false,
      type: NotificationType.orderApproved,
    ),
    AppNotification(
      id: 2,
      userId: 'EMP-0001',
      title: 'تم رفض الطلب',
      message: 'طلب #ORD-0012 — بيانات غير مكتملة',
      relatedOrderId: 'ORD-0012',
      createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
      isRead: false,
      type: NotificationType.orderRejected,
    ),
    AppNotification(
      id: 3,
      userId: 'EMP-0001',
      title: 'تذكير: طلب جاهز',
      message: 'طلب #ORD-0014 جاهز منذ 30 دقيقة',
      relatedOrderId: 'ORD-0014',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      isRead: false,
      type: NotificationType.general,
    ),
    AppNotification(
      id: 4,
      userId: 'EMP-0001',
      title: 'تذكير: إرسال العهدة',
      message: 'آخر مهلة 5:00 مساءً',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
      type: NotificationType.general,
    ),
    AppNotification(
      id: 5,
      userId: 'EMP-0003',
      title: 'تمت الموافقة',
      message: 'طلب #ORD-0013 — فهد الدوسري',
      relatedOrderId: 'ORD-0013',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: true,
      type: NotificationType.orderSentToDistribution,
    ),
    AppNotification(
      id: 6,
      userId: 'EMP-0002',
      title: 'تحديث النظام',
      message: 'تمت إضافة 3 منتجات جديدة',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
      type: NotificationType.general,
    ),
    AppNotification(
      id: 7,
      userId: 'EMP-0001',
      title: 'تم استلام دفعة',
      message: '500 ر.س عربون من خالد العتيبي',
      relatedOrderId: 'ORD-0015',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      isRead: true,
      type: NotificationType.general,
    ),
  ];

  static final statusLogs = [
    OrderStatusLog(
      id: 1,
      orderId: 'ORD-0015',
      oldStatus: OrderStatus.pendingSupervisorApproval,
      newStatus: OrderStatus.sentToDistribution,
      changedByUserId: 'EMP-0002',
      changedByName: 'سارة العتيبي',
      changedAt: DateTime.now().subtract(const Duration(hours: 2)),
      notes: 'تمت الموافقة وإرسال الطلب للتوزيع',
    ),
  ];

  static const pickupOrders = [
    TodayPickupOrder(
      id: 101,
      customer: 'عبدالله الناصر',
      product: 'طبق كبسة كبير',
      branch: 'فرع النخيل',
      amount: 150,
      paid: 0,
      date: '2026-05-01',
      delivered: false,
    ),
    TodayPickupOrder(
      id: 102,
      customer: 'فاطمة الأحمد',
      product: 'مناسف ورق عنب',
      branch: 'فرع العليا',
      amount: 220,
      paid: 0,
      date: '2026-05-01',
      delivered: false,
    ),
    TodayPickupOrder(
      id: 103,
      customer: 'محمد السبيعي',
      product: 'حلويات مشكلة',
      branch: 'فرع المروج',
      amount: 85,
      paid: 85,
      date: '2026-05-01',
      delivered: false,
    ),
    TodayPickupOrder(
      id: 104,
      customer: 'نورة القحطاني',
      product: 'مشاوي 4 أشخاص',
      branch: 'فرع الرياض',
      amount: 300,
      paid: 100,
      date: '2026-05-01',
      delivered: false,
    ),
  ];
}

class _MockAccount {
  const _MockAccount({required this.password, required this.user});

  final String password;
  final AppUser user;
}
