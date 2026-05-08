import 'package:flutter/material.dart';

import '../core/constants/environment.dart';
import '../core/errors/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';
import '../models/app_models.dart';
import 'auth_service.dart';

class ErpnextService implements AuthService {
  ErpnextService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    await _apiClient.post<Map<String, dynamic>>(
      'login',
      body: {'usr': username.trim(), 'pwd': password},
      parser: (data) => _asMap(data),
    );
    final user = await getCurrentUser();
    if (user == null) {
      throw const NetworkException(
        'تم تسجيل الدخول، لكن تعذر تحميل بيانات المستخدم',
        code: 'current_user_missing',
      );
    }
    return user;
  }

  @override
  Future<AppUser?> restoreSession(String sessionKey) {
    return getCurrentUser();
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      'awamir_plus.api.auth.get_current_user',
      parser: (data) => _asMap(data),
    );
    return _mapAppUser(data);
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.post<Object?>('logout');
    } on AppException {
      // Clearing the local session is still correct if the server session
      // already expired.
    } finally {
      await _apiClient.clearSession();
    }
  }

  Future<List<ProductDepartment>> getCategories() async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.products.get_categories',
      parser: _asList,
    );
    return data.map((item) {
      final row = _asMap(item);
      final id = _string(row['name']);
      return ProductDepartment(
        id: id,
        name: _string(row['item_group_name'], fallback: id),
        icon: Icons.category,
      );
    }).toList();
  }

  Future<List<Product>> getProductsByCategory(String categoryId) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.products.get_products_by_category',
      queryParameters: {'category': categoryId},
      parser: _asList,
    );
    final products = <Product>[];
    for (final item in data) {
      final row = _asMap(item);
      final itemCode = _string(
        row['item_code'],
        fallback: _string(row['name']),
      );
      final price = await _getProductPrice(itemCode);
      products.add(
        Product(
          id: itemCode.hashCode & 0x7fffffff,
          itemCode: itemCode,
          departmentId: categoryId,
          name: _string(row['item_name'], fallback: itemCode),
          description: _string(row['description']),
          price: price,
          imageUrl: _absoluteUrl(_string(row['image'])),
        ),
      );
    }
    return products;
  }

  Future<Customer?> searchCustomerByPhone(String phone) async {
    final normalized = normalizePhoneInput(phone);
    if (normalized.isEmpty) return null;
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.customers.search_customer_by_phone',
      queryParameters: {'phone': normalized},
      parser: _asList,
    );
    if (data.isEmpty) return null;
    return _mapCustomer(_asMap(data.first), fallbackPhone: normalized);
  }

  Future<List<CustomerAddress>> getCustomerAddresses(String customerId) async {
    if (customerId.trim().isEmpty) return const [];
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.customers.get_customer_addresses',
      queryParameters: {'customer': customerId},
      parser: _asList,
    );
    return data.map((item) => _mapCustomerAddress(_asMap(item))).toList();
  }

  Future<Order> createOrder(OrderDraft draft, List<Product> products) {
    return _notConfigured();
  }

  Future<void> saveOrderAsDraft(OrderDraft draft) {
    return _notConfigured();
  }

  Future<Order> saveDraft(CreateOrderRequest request) {
    return _saveCreateOrderRequest(
      method: 'awamir_plus.api.orders.save_order_as_draft',
      request: request,
      submitForApproval: false,
    );
  }

  Future<Order> submitForApproval(CreateOrderRequest request) {
    return _saveCreateOrderRequest(
      method: 'awamir_plus.api.orders.submit_order_for_approval',
      request: request,
      submitForApproval: true,
    );
  }

  Future<Order> submitOrderForApproval(String orderId) {
    return _notConfigured();
  }

  Future<void> recordDeposit({
    required String orderId,
    required String customer,
    required num amount,
    required PaymentMethod method,
  }) {
    return _notConfigured();
  }

  Future<List<Order>> getOrders({OrderStatus? status}) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.orders.get_my_orders',
      parser: _asList,
    );
    final orders = data.map((item) => _mapOrder(_asMap(item))).toList();
    if (status == null) return orders;
    return orders.where((order) => order.status == status).toList();
  }

  Future<List<Order>> getDistributionOrders(AppUser user) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.distribution.get_distribution_orders',
      parser: _asList,
    );
    return data.map((item) => _mapOrder(_asMap(item))).toList();
  }

  Future<List<ProductionDepartment>> getProductionDepartments() async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.distribution.get_production_departments',
      parser: _asList,
    );
    return data.map((item) => _mapProductionDepartment(_asMap(item))).toList();
  }

  Future<ProductionDepartment?> getDefaultDepartmentForOrder(
    Order order,
  ) async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      'awamir_plus.api.distribution.get_default_department_for_order',
      queryParameters: {'order': order.id},
      parser: (data) => _asMap(data),
    );
    if (data.isEmpty) return null;
    final department = _asMap(data['department']);
    if (department.isNotEmpty) return _mapProductionDepartment(department);
    final departmentId = _string(data['production_department']);
    if (departmentId.isEmpty) return null;
    return ProductionDepartment(
      id: departmentId,
      name: departmentId,
      code: '',
      isActive: true,
    );
  }

  Future<Order> assignProductionDepartment({
    required String orderId,
    required String productionDepartmentId,
    required AppUser changedBy,
  }) async {
    final trimmedDepartment = productionDepartmentId.trim();
    if (trimmedDepartment.isEmpty) {
      throw const NetworkException(
        'جهة التنفيذ مطلوبة',
        code: 'production_department_required',
      );
    }
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.distribution.assign_production_department',
      body: {
        'order': orderId,
        'order_id': orderId,
        'production_department': trimmedDepartment,
      },
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<List<DepartmentWorkOrder>> createDepartmentWorkOrders({
    required String orderId,
    String fallbackDepartmentId = '',
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.distribution.create_department_work_orders',
      body: {
        'order': orderId,
        'order_id': orderId,
        'fallback_department': fallbackDepartmentId.trim(),
      },
      parser: (data) => _asMap(data),
    );
    return _asList(
      data['work_orders'],
    ).map((item) => _mapDepartmentWorkOrder(_asMap(item))).toList();
  }

  Future<List<DepartmentWorkOrder>> getDepartmentWorkOrders({
    String? orderId,
    String? departmentId,
  }) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.distribution.get_department_work_orders',
      queryParameters: {'order': orderId, 'department': departmentId},
      parser: _asList,
    );
    return data.map((item) => _mapDepartmentWorkOrder(_asMap(item))).toList();
  }

  Future<List<Order>> getProductionOrders(AppUser user) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.production.get_production_orders',
      parser: _asList,
    );
    return data.map((item) => _mapOrder(_asMap(item))).toList();
  }

  Future<Order> updateProductionStatus({
    required String orderId,
    required OrderStatus status,
    required AppUser changedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.production.update_production_status',
      body: {
        'order': orderId,
        'order_id': orderId,
        'new_status': _orderStatusKey(status),
        'status': _orderStatusKey(status),
      },
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<DepartmentWorkOrder> updateWorkOrderStatus({
    required String workOrderId,
    required DepartmentWorkOrderStatus status,
    String notes = '',
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.production.update_work_order_status',
      body: {
        'work_order': workOrderId,
        'status': _departmentWorkOrderStatusKey(status),
        'notes': notes.trim(),
      },
      parser: (data) => _asMap(data),
    );
    final workOrder = _asMap(data['work_order']);
    return _mapDepartmentWorkOrder(workOrder.isEmpty ? data : workOrder);
  }

  Future<List<Order>> getPickupOrders(AppUser user) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.delivery.get_pickup_orders',
      parser: _asList,
    );
    return data.map((item) => _mapOrder(_asMap(item))).toList();
  }

  Future<Order> markPickupOrderDelivered({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.delivery.mark_pickup_order_delivered',
      body: {'order': orderId, 'order_id': orderId},
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<Order> collectRemainingPayment({
    required String orderId,
    required num amount,
    required PaymentMethod method,
    required AppUser collectedBy,
    String transactionReference = '',
    String receiptPath = '',
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.delivery.collect_remaining_payment',
      body: {
        'order': orderId,
        'order_id': orderId,
        'amount': amount,
        'payment_method': _paymentMethodKey(method),
        'payment_reference': transactionReference.trim(),
        'receipt_attachment': receiptPath.trim(),
      },
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<List<DriverProfile>> getAvailableDrivers(
    AppUser user, {
    String? branchId,
  }) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.delivery.get_available_drivers',
      queryParameters: {'branch_id': branchId},
      parser: _asList,
    );
    return data.map((item) => _mapDriverProfile(_asMap(item))).toList();
  }

  Future<List<DeliveryBatch>> createDeliveryBatches({String? branchId}) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.delivery.create_delivery_batches',
      body: {'branch_id': branchId},
      parser: (data) => _asMap(data),
    );
    return _asList(
      data['batches'],
    ).map((item) => _mapDeliveryBatch(_asMap(item))).toList();
  }

  Future<List<DeliveryBatch>> getDeliveryBatches({
    DeliveryBatchStatus? status,
    String? destinationBranch,
  }) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.delivery.get_delivery_batches',
      queryParameters: {
        'status': status == null ? null : _deliveryBatchStatusKey(status),
        'destination_branch': destinationBranch,
      },
      parser: _asList,
    );
    return data.map((item) => _mapDeliveryBatch(_asMap(item))).toList();
  }

  Future<DeliveryBatch> assignDeliveryBatch({
    required String batchId,
    required String driverId,
  }) async {
    final trimmedDriver = driverId.trim();
    if (trimmedDriver.isEmpty) {
      throw const NetworkException(
        'اختيار السائق مطلوب',
        code: 'driver_required',
      );
    }
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.delivery.assign_delivery_batch',
      body: {
        'batch': batchId,
        'batch_id': batchId,
        'driver': trimmedDriver,
        'driver_id': trimmedDriver,
      },
      parser: (data) => _asMap(data),
    );
    final batch = _asMap(data['batch']);
    return _mapDeliveryBatch(batch.isEmpty ? data : batch);
  }

  Future<Order> assignDriverToOrder({
    required String orderId,
    required String driverId,
    required AppUser changedBy,
  }) async {
    final trimmedDriver = driverId.trim();
    if (trimmedDriver.isEmpty) {
      throw const NetworkException(
        'اختيار السائق مطلوب',
        code: 'driver_required',
      );
    }
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.delivery.assign_driver_to_order',
      body: {
        'order': orderId,
        'order_id': orderId,
        'driver': trimmedDriver,
        'driver_id': trimmedDriver,
      },
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<List<Order>> getDriverOrders(AppUser user) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.delivery.get_driver_orders',
      parser: _asList,
    );
    return data.map((item) => _mapOrder(_asMap(item))).toList();
  }

  Future<Order> updateDeliveryStatus({
    required String orderId,
    required OrderStatus status,
    required AppUser changedBy,
    String proofImagePath = '',
    String driverNotes = '',
  }) async {
    final statusKey = _orderStatusKey(status);
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.delivery.update_delivery_status',
      body: {
        'order': orderId,
        'order_id': orderId,
        'new_status': statusKey,
        'status': statusKey,
        'proof_image': proofImagePath.trim(),
        'driver_notes': driverNotes.trim(),
      },
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<Order> markDeliveryFailed({
    required String orderId,
    required AppUser changedBy,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const NetworkException(
        'سبب تعذر التسليم مطلوب',
        code: 'delivery_failure_reason_required',
      );
    }
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.delivery.mark_delivery_failed',
      body: {
        'order': orderId,
        'order_id': orderId,
        'reason': trimmedReason,
        'failure_reason': trimmedReason,
      },
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<OrderPayment> collectDeliveryPayment({
    required String orderId,
    required num amount,
    required PaymentMethod method,
    required AppUser collectedBy,
    String transactionReference = '',
    String receiptPath = '',
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.delivery.collect_delivery_payment',
      body: {
        'order': orderId,
        'order_id': orderId,
        'amount': amount,
        'payment_method': _paymentMethodKey(method),
        'payment_reference': transactionReference.trim(),
        'receipt_attachment': receiptPath.trim(),
      },
      parser: (data) => _asMap(data),
    );
    final payment = _asMap(data['payment']);
    return _mapOrderPayment(payment.isEmpty ? data : payment);
  }

  Future<DeliveryAssignment?> getDeliveryAssignment(String orderId) async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      'awamir_plus.api.orders.get_order_detail',
      queryParameters: {'order': orderId},
      parser: (data) => _asMap(data),
    );
    final assignments = _asList(data['delivery_assignment']);
    if (assignments.isEmpty) return null;
    return _mapDeliveryAssignment(_asMap(assignments.first));
  }

  Future<List<Order>> getPendingSupervisorApprovals(AppUser user) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.approvals.get_pending_supervisor_approvals',
      parser: _asList,
    );
    return data.map((item) => _mapOrder(_asMap(item))).toList();
  }

  Future<Order> approveOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.approvals.approve_order',
      body: {'order': orderId},
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<Order> rejectOrder({
    required String orderId,
    required AppUser changedBy,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const NetworkException(
        'سبب الرفض مطلوب',
        code: 'rejection_reason_required',
      );
    }
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.approvals.reject_order',
      body: {'order': orderId, 'reason': trimmedReason},
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<Order> returnOrderForEdit({
    required String orderId,
    required AppUser changedBy,
    required String notes,
  }) async {
    final trimmedNotes = notes.trim();
    if (trimmedNotes.isEmpty) {
      throw const NetworkException(
        'ملاحظة الإرجاع مطلوبة',
        code: 'return_notes_required',
      );
    }
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.approvals.return_order_for_edit',
      body: {'order': orderId, 'notes': trimmedNotes, 'note': trimmedNotes},
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<Order> cancelOrder({
    required String orderId,
    required AppUser changedBy,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const NetworkException(
        'سبب الإلغاء مطلوب',
        code: 'cancellation_reason_required',
      );
    }
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.orders.cancel_order',
      body: {'order': orderId, 'reason': trimmedReason},
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<OrderStatusLog> addStatusLog(OrderStatusLog log) {
    return _notConfigured();
  }

  Future<List<OrderStatusLog>> getOrderStatusLogs(String orderId) async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      'awamir_plus.api.orders.get_order_detail',
      queryParameters: {'order': orderId},
      parser: (data) => _asMap(data),
    );
    return _asList(
      data['status_logs'],
    ).map((item) => _mapStatusLog(_asMap(item))).toList();
  }

  Future<AppNotification> createNotification(AppNotification notification) {
    return _notConfigured();
  }

  Future<DailyCashClosure> getDailyCashClosure() {
    return _notConfigured();
  }

  Future<void> submitDailyCashClosure(DailyCashClosure closure) {
    return _notConfigured();
  }

  Future<DailyCashClosure> getMyDailyCashClosure(AppUser user) async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      'awamir_plus.api.cash_closure.get_my_daily_cash_closure',
      parser: (data) => _asMap(data),
    );
    return _mapDailyCashClosure(data);
  }

  Future<DailyCashClosure> getCashClosureById(String closureId) async {
    final data = await _apiClient.get<Map<String, dynamic>>(
      'awamir_plus.api.cash_closure.get_cash_closure_detail',
      queryParameters: {'closure': closureId},
      parser: (data) => _asMap(data),
    );
    return _mapDailyCashClosure(data);
  }

  Future<DailyCashClosure> submitCashClosure({
    required String closureId,
    required AppUser submittedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.cash_closure.submit_cash_closure',
      body: {'closure': closureId},
      parser: (data) => _asMap(data),
    );
    return _mapDailyCashClosure(data);
  }

  Future<List<DailyCashClosure>> getSubmittedCashClosures(AppUser user) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.cash_closure.get_submitted_cash_closures',
      parser: _asList,
    );
    return data.map((item) => _mapDailyCashClosure(_asMap(item))).toList();
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
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.cash_closure.accept_cash_closure',
      body: {
        'closure': closureId,
        'actual_cash': actualCash,
        'actual_card': actualCard,
        'actual_transfer': actualTransfer,
        'actual_other': actualOther,
        'cashier_notes': cashierNotes.trim(),
        'difference_reason': differenceReason.trim(),
      },
      parser: (data) => _asMap(data),
    );
    return _mapDailyCashClosure(data);
  }

  Future<DailyCashClosure> returnCashClosure({
    required String closureId,
    required AppUser cashier,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const NetworkException(
        'سبب إرجاع العهدة مطلوب',
        code: 'cash_closure_return_reason_required',
      );
    }
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.cash_closure.return_cash_closure',
      body: {'closure': closureId, 'reason': trimmedReason},
      parser: (data) => _asMap(data),
    );
    return _mapDailyCashClosure(data);
  }

  Future<DailyCashClosure> closeCashClosure({
    required String closureId,
    required AppUser closedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.cash_closure.close_cash_closure',
      body: {'closure': closureId},
      parser: (data) => _asMap(data),
    );
    return _mapDailyCashClosure(data);
  }

  Future<List<OrderPayment>> getCashClosurePayments(String closureId) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.cash_closure.get_cash_closure_payments',
      queryParameters: {'closure': closureId},
      parser: _asList,
    );
    return data.map((item) => _mapOrderPayment(_asMap(item))).toList();
  }

  Future<CashClosureTotals> calculateClosureTotals(
    List<OrderPayment> payments,
  ) async {
    return _calculateClosureTotals(payments);
  }

  Future<void> markPaymentsAsSubmitted(String closureId) async {
    await submitCashClosure(
      closureId: closureId,
      submittedBy: const AppUser(
        id: '',
        fullName: '',
        email: '',
        phone: '',
        role: UserRole.systemAdmin,
        branchId: '',
        branchName: '',
        isActive: true,
      ),
    );
  }

  Future<void> markPaymentsAsCashierAccepted(String closureId) async {
    await getCashClosureById(closureId);
  }

  Future<List<CashClosureLog>> getCashClosureLogs(String closureId) async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.cash_closure.get_cash_closure_logs',
      queryParameters: {'closure': closureId},
      parser: _asList,
    );
    return data.map((item) => _mapCashClosureLog(_asMap(item))).toList();
  }

  Future<String> createCustomerIfMissing(Order order) {
    return _notConfigured();
  }

  Future<CreateSalesOrderResponse> createSalesOrder(
    CreateSalesOrderRequest request,
  ) {
    return _notConfigured();
  }

  Future<CreateWorkOrderResponse> createWorkOrder(
    CreateWorkOrderRequest request,
  ) {
    return _notConfigured();
  }

  Future<CreatePaymentEntryResponse> createPaymentEntry(
    CreatePaymentEntryRequest request,
  ) {
    return _notConfigured();
  }

  Future<CreateSalesInvoiceResponse> createSalesInvoice(
    CreateSalesInvoiceRequest request,
  ) {
    return _notConfigured();
  }

  Future<AllocateAdvancePaymentResponse> allocateAdvancePayment(
    AllocateAdvancePaymentRequest request,
  ) {
    return _notConfigured();
  }

  Future<Order> getSalesOrder(String salesOrderId) {
    return _notConfigured();
  }

  Future<Order> getSalesInvoice(String salesInvoiceId) {
    return _notConfigured();
  }

  Future<OrderPayment> getPaymentEntry(String paymentEntryId) {
    return _notConfigured();
  }

  Future<List<Order>> getCustomerOutstandingInvoices(String customerId) {
    return _notConfigured();
  }

  Future<Order> createSalesOrderForOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.accounting.create_sales_order_for_order',
      body: {'order': orderId},
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<Order> createWorkOrderForOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.accounting.create_work_order_for_order',
      body: {'order': orderId},
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<List<OrderPayment>> postAcceptedPaymentsToErpnext({
    required String closureId,
    required AppUser changedBy,
  }) async {
    final data = await _apiClient.post<List<dynamic>>(
      'awamir_plus.api.accounting.post_accepted_payments_to_erpnext',
      body: {'closure': closureId},
      parser: _asList,
    );
    return data.map((item) => _mapOrderPayment(_asMap(item))).toList();
  }

  Future<OrderPayment> createPaymentEntryForPayment({
    required String paymentId,
    required AppUser changedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.accounting.create_payment_entry_for_payment',
      body: {'payment': paymentId},
      parser: (data) => _asMap(data),
    );
    final payment = _asMap(data['payment']);
    return _mapOrderPayment(payment.isEmpty ? data : payment);
  }

  Future<Order> createSalesInvoiceForOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.accounting.create_sales_invoice_for_order',
      body: {'order': orderId},
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<List<PaymentAllocation>> allocateAdvancePaymentToInvoice({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.accounting.allocate_advance_payment_to_invoice',
      body: {'order': orderId},
      parser: (data) => _asMap(data),
    );
    return _asList(
      data['allocations'],
    ).map((item) => _mapPaymentAllocation(_asMap(item))).toList();
  }

  Future<List<Order>> getCustomerInvoices(String customerId) async {
    await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.accounting.get_customer_invoices',
      queryParameters: {'customer': customerId},
      parser: _asList,
    );
    return const [];
  }

  Future<Order> syncOrderAccountingStatus({
    required String orderId,
    required AppUser changedBy,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      'awamir_plus.api.accounting.sync_order_accounting_status',
      body: {'order': orderId},
      parser: (data) => _asMap(data),
    );
    return _mapOrderFromActionResponse(data);
  }

  Future<List<Order>> getOrdersNeedingSalesOrder() async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.accounting.get_orders_needing_sales_order',
      parser: _asList,
    );
    return data.map((item) => _mapOrder(_asMap(item))).toList();
  }

  Future<List<OrderPayment>> getPaymentsReadyForErpPosting() async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.accounting.get_payments_ready_for_erp_posting',
      parser: _asList,
    );
    return data.map((item) => _mapOrderPayment(_asMap(item))).toList();
  }

  Future<List<Order>> getOrdersNeedingSalesInvoice() async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.accounting.get_orders_needing_sales_invoice',
      parser: _asList,
    );
    return data.map((item) => _mapOrder(_asMap(item))).toList();
  }

  Future<List<Order>> getInvoicesNeedingAdvanceAllocation() async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.accounting.get_invoices_needing_advance_allocation',
      parser: _asList,
    );
    return data.map((item) => _mapOrder(_asMap(item))).toList();
  }

  Future<List<Order>> getAccountingSyncErrors() async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.accounting.get_accounting_sync_errors',
      parser: _asList,
    );
    return data.map((item) => _mapOrder(_asMap(item))).toList();
  }

  Future<List<AppNotification>> getNotifications() async {
    final data = await _apiClient.get<List<dynamic>>(
      'awamir_plus.api.notifications.get_notifications',
      parser: _asList,
    );
    return data.map((item) => _mapNotification(_asMap(item))).toList();
  }

  Future<List<AppNotification>> getNotificationsForCurrentUser(AppUser user) {
    return getNotifications();
  }

  Future<void> markNotificationAsRead(int id) async {
    await _apiClient.post<Object?>(
      'awamir_plus.api.notifications.mark_notification_as_read',
      body: {'notification': id.toString()},
    );
  }

  Future<void> markNotificationRead(int id) {
    return markNotificationAsRead(id);
  }

  Future<void> markAllNotificationsRead() async {
    await _apiClient.post<Object?>(
      'awamir_plus.api.notifications.mark_all_notifications_as_read',
    );
  }

  Future<List<TodayPickupOrder>> getTodayPickupOrders() async {
    return const [];
  }

  Future<TodayPickupOrder?> collectPickupPayment(int id, num amount) {
    return _notConfigured();
  }

  Future<TodayPickupOrder?> deliverPickupOrder(int id) {
    return _notConfigured();
  }

  Future<T> _notConfigured<T>() {
    throw const NetworkException(
      'خدمة ERPNext غير مفعّلة حالياً. غيّر useMockData بعد إضافة الربط.',
      code: 'erpnext_not_configured',
    );
  }

  Future<num> _getProductPrice(String itemCode) async {
    if (itemCode.isEmpty) return 0;
    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        'awamir_plus.api.products.get_product_price',
        queryParameters: {'item_code': itemCode},
        parser: (data) => _asMap(data),
      );
      return num.tryParse(_string(data['rate'])) ?? 0;
    } on AppException {
      return 0;
    }
  }

  Future<Order> _saveCreateOrderRequest({
    required String method,
    required CreateOrderRequest request,
    required bool submitForApproval,
  }) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      method,
      body: {'order_data': _createOrderPayload(request, submitForApproval)},
      parser: (data) => _asMap(data),
    );
    final orderData = _asMap(data['order']);
    return _mapOrder(orderData.isEmpty ? data : orderData);
  }

  Order _mapOrderFromActionResponse(Map<String, dynamic> data) {
    final orderData = _asMap(data['order']);
    return _mapOrder(orderData.isEmpty ? data : orderData);
  }

  Map<String, dynamic> _createOrderPayload(
    CreateOrderRequest request,
    bool submitForApproval,
  ) {
    final delivery = request.deliveryDetails;
    return {
      'submit_for_approval': submitForApproval,
      'customer': request.existingCustomer?.id,
      'customer_phone': normalizePhoneInput(request.customerPhone),
      'customer_name': request.customerName.trim(),
      'customer_type': _customerTypeKey(request.customerType),
      'company_name': request.companyName.trim(),
      'tax_id': request.taxNumber.trim(),
      'company_address': request.companyAddress.trim(),
      'company_email': request.companyEmail.trim(),
      'contact_person': request.companyContactPerson.trim(),
      'items': request.lineItems.map(_linePayload).toList(),
      'required_date': _dateKey(request.pickupDate),
      'required_time': _timeKey(request.pickupTime),
      'delivery_type': request.fulfillmentType == FulfillmentType.branchPickup
          ? 'Pickup'
          : 'Delivery',
      'created_branch': request.createdBranch.id,
      'pickup_branch': request.fulfillmentType == FulfillmentType.branchPickup
          ? request.pickupBranch.id
          : null,
      'delivery_address': delivery.addressText.trim(),
      'district': delivery.district.trim(),
      'city': delivery.city.trim(),
      'postal_code': delivery.postalCode.trim(),
      'delivery_location_url': delivery.googleMapsUrl.trim(),
      'latitude': delivery.latitude,
      'longitude': delivery.longitude,
      'delivery_notes': delivery.notes.trim(),
      'delivery_fee': request.deliveryFee,
      'order_notes': request.orderDetails.trim(),
      'customer_notes': request.customerNotes.trim(),
      'deposit_amount': request.depositAmount,
      'payment_method': _paymentMethodKey(request.paymentMethod),
      'payment_reference': request.transactionReference.trim(),
      'receipt_attachment': request.paymentReceipt?.path,
    };
  }

  Map<String, dynamic> _linePayload(OrderLineDraft line) {
    final product = line.product;
    final itemCode = product.itemCode.trim();
    return {
      'item_code': itemCode.isEmpty ? product.name : itemCode,
      'item_name': product.name,
      'description': product.description,
      'qty': line.quantity,
      'rate': product.price,
      'amount': line.subtotal,
      'product_category': product.departmentId,
      'requires_work_order': 1,
    };
  }

  Order _mapOrder(Map<String, dynamic> data) {
    final id = _string(
      data['order_number'],
      fallback: _string(data['name'], fallback: _string(data['order_id'])),
    );
    final items = _asList(data['items']).map((item) {
      final row = _asMap(item);
      final itemCode = _string(row['item_code']);
      final product = Product(
        id: itemCode.hashCode & 0x7fffffff,
        itemCode: itemCode,
        departmentId: _string(row['product_category']),
        name: _string(row['item_name'], fallback: itemCode),
        description: _string(row['description']),
        price: _number(row['rate']),
        imageUrl: '',
      );
      return OrderLineDraft(
        product: product,
        quantity: _number(row['qty']).round().clamp(1, 9999).toInt(),
      );
    }).toList();

    final payments = _asList(data['payments']);
    final payment = payments.isEmpty
        ? <String, dynamic>{}
        : _asMap(payments.first);
    final deliveryType = _string(data['delivery_type']);
    final fulfillmentType = deliveryType == 'Delivery'
        ? FulfillmentType.customerDelivery
        : FulfillmentType.branchPickup;
    final totalAmount = _number(data['total_amount']);
    final deliveryFee = _number(data['delivery_fee']);
    final customerName = _string(
      data['customer_name'],
      fallback: _string(data['company_name']),
    );

    return Order(
      id: id,
      customer: customerName,
      productSummary: _productSummary(items),
      amount: totalAmount + deliveryFee,
      status: _mapOrderStatus(_string(data['status'])),
      date: _dateOnlyText(
        _string(data['creation'], fallback: _string(data['modified'])),
      ),
      progress: _mapOrderProgress(_string(data['status'])),
      paymentMethod: _mapPaymentMethod(_string(payment['payment_method'])),
      customerPhone: _string(data['customer_phone']),
      customerType: _string(data['customer_type']) == 'Company'
          ? CustomerType.company
          : CustomerType.individual,
      companyName: _string(data['company_name']),
      taxNumber: _string(data['tax_id']),
      companyAddress: _string(data['company_address']),
      companyEmail: _string(data['company_email']),
      companyContactPerson: _string(data['contact_person']),
      categoryId: items.isEmpty ? '' : items.first.product.departmentId,
      categoryName: items.isEmpty ? '' : items.first.product.departmentId,
      lineItems: items,
      details: _string(data['order_notes']),
      customerNotes: _string(data['customer_notes']),
      pickupDate: DateTime.tryParse(_string(data['required_date'])),
      pickupTime: _parseTimeOfDay(_string(data['required_time'])),
      fulfillmentType: fulfillmentType,
      deliveryDetails: DeliveryDetailsDraft(
        addressText: _string(data['delivery_address']),
        googleMapsUrl: _string(data['delivery_location_url']),
        latitude: double.tryParse(_string(data['latitude'])),
        longitude: double.tryParse(_string(data['longitude'])),
        notes: _string(data['delivery_notes']),
        deliveryFee: deliveryFee,
      ),
      depositAmount: _number(data['deposit_amount']),
      remainingAmount: _number(data['remaining_amount']),
      createdBranch: _string(data['created_branch']),
      createdBranchId: _string(data['created_branch']),
      pickupBranch: _string(data['pickup_branch']),
      pickupBranchId: _string(data['pickup_branch']),
      createdByUserId: _string(data['created_by_user']),
      productionDepartmentId: _string(data['production_department']),
      productionDepartmentName: _string(
        data['production_department_name'],
        fallback: _string(data['production_department']),
      ),
      productionDepartmentCode: _string(data['production_department_code']),
      assignedDriverId: _string(data['assigned_driver']),
      assignedDriverName: _string(data['assigned_driver_name']),
      erpnextCustomerId: _string(data['customer']),
      erpnextSalesOrderId: _string(data['erpnext_sales_order']),
      erpnextWorkOrderId: _string(data['erpnext_work_order']),
      erpnextSalesInvoiceId: _string(data['erpnext_sales_invoice']),
      erpSyncStatus: _mapErpSyncStatus(_string(data['erp_sync_status'])),
      erpSyncError: _string(data['erp_sync_error']),
      erpSyncedAt: DateTime.tryParse(_string(data['erp_synced_at'])),
      departmentWorkOrders: _asList(
        data['department_work_orders'],
      ).map((item) => _mapDepartmentWorkOrder(_asMap(item))).toList(),
      deliveryBatches: _asList(
        data['delivery_batches'],
      ).map((item) => _mapDeliveryBatch(_asMap(item))).toList(),
    );
  }

  OrderStatusLog _mapStatusLog(Map<String, dynamic> data) {
    return OrderStatusLog(
      id: int.tryParse(_string(data['name'])) ?? _string(data['name']).hashCode,
      orderId: _string(data['order']),
      oldStatus: _mapOrderStatus(_string(data['old_status'])),
      newStatus: _mapOrderStatus(_string(data['new_status'])),
      changedByUserId: _string(data['changed_by']),
      changedByName: _string(data['changed_by']),
      changedAt:
          DateTime.tryParse(_string(data['changed_at'])) ?? DateTime.now(),
      notes: _string(data['notes']),
    );
  }

  AppNotification _mapNotification(Map<String, dynamic> data) {
    final idText = _string(data['name']);
    return AppNotification(
      id: int.tryParse(idText) ?? idText.hashCode,
      userId: _string(data['user']),
      title: _string(data['title']),
      message: _string(data['message']),
      relatedOrderId: _string(data['related_order']),
      createdAt:
          DateTime.tryParse(_string(data['created_at'])) ?? DateTime.now(),
      isRead: _asBool(data['is_read']),
      type: _mapNotificationType(_string(data['notification_type'])),
    );
  }

  ProductionDepartment _mapProductionDepartment(Map<String, dynamic> data) {
    final id = _string(data['id'], fallback: _string(data['name']));
    return ProductionDepartment(
      id: id,
      name: _string(
        data['department_name'],
        fallback: _string(data['name'], fallback: id),
      ),
      code: _string(data['department_code'], fallback: _string(data['code'])),
      branch: _string(data['branch']),
      isActive: _asBool(data['is_active']),
    );
  }

  DriverProfile _mapDriverProfile(Map<String, dynamic> data) {
    final id = _string(
      data['id'],
      fallback: _string(data['user_id'], fallback: _string(data['user'])),
    );
    final branch = _string(
      data['branch_id'],
      fallback: _string(data['branch']),
    );
    return DriverProfile(
      id: id,
      userId: _string(data['user_id'], fallback: id),
      fullName: _string(data['full_name'], fallback: id),
      phone: _string(data['phone']),
      branchId: branch,
      branchName: _string(data['branch_name'], fallback: branch),
      isActive: _asBool(data['is_active']),
      currentAssignedOrdersCount: _number(
        data['current_assigned_orders_count'],
      ).round(),
    );
  }

  OrderPayment _mapOrderPayment(Map<String, dynamic> data) {
    final id = _string(data['name'], fallback: _string(data['payment_id']));
    final role = _string(data['received_by_role']);
    final collectorType = _mapCollectorType(role);
    final collector = _string(data['received_by_user']);
    return OrderPayment(
      id: id,
      orderId: _string(
        data['order_number'],
        fallback: _string(data['order'], fallback: _string(data['order_id'])),
      ),
      customer: _string(
        data['customer_name'],
        fallback: _string(data['customer']),
      ),
      amount: _number(data['amount']),
      method: _mapPaymentMethod(_string(data['payment_method'])),
      collectedByUserId: collector,
      collectedByName: collector,
      collectorType: collectorType,
      createdAt: _dateTimeValue(
        _string(data['created_at'], fallback: _string(data['creation'])),
      ),
      transactionReference: _string(data['payment_reference']),
      receiptPath: _string(data['receipt_attachment']),
      driverId: collectorType == CashClosureOwnerType.driver ? collector : '',
      closureId: _string(data['cash_closure']),
      status: _mapOrderPaymentStatus(_string(data['status'])),
      erpnextPaymentEntryId: _string(data['erpnext_payment_entry']),
      postedToErpNext:
          _mapOrderPaymentStatus(_string(data['status'])) ==
          OrderPaymentStatus.postedToErpNext,
    );
  }

  PaymentAllocation _mapPaymentAllocation(Map<String, dynamic> data) {
    final id = _string(data['id'], fallback: _string(data['name']));
    return PaymentAllocation(
      id: id,
      orderId: _string(data['order_id'], fallback: _string(data['order'])),
      paymentId: _string(
        data['payment_id'],
        fallback: _string(data['payment']),
      ),
      salesInvoiceId: _string(
        data['sales_invoice_id'],
        fallback: _string(data['sales_invoice']),
      ),
      paymentEntryId: _string(
        data['payment_entry_id'],
        fallback: _string(data['payment_entry']),
      ),
      allocatedAmount: _number(data['allocated_amount']),
      allocatedAt: _dateTimeValue(_string(data['allocated_at'])),
      status: _mapPaymentAllocationStatus(_string(data['status'])),
      error: _string(data['error']),
    );
  }

  DeliveryAssignment _mapDeliveryAssignment(Map<String, dynamic> data) {
    return DeliveryAssignment(
      id: _string(data['name']),
      orderId: _string(data['order']),
      driverId: _string(data['driver']),
      driverName: _string(
        data['driver_name'],
        fallback: _string(data['driver']),
      ),
      assignedByUserId: _string(data['assigned_by']),
      assignedAt: _dateTimeValue(_string(data['assigned_at'])),
      status: _mapOrderStatus(_string(data['status'])),
      pickedUpAt: _nullableDateTime(_string(data['picked_up_at'])),
      outForDeliveryAt: _nullableDateTime(_string(data['out_for_delivery_at'])),
      deliveredAt: _nullableDateTime(_string(data['delivered_at'])),
      failedAt: _nullableDateTime(_string(data['failed_at'])),
      failureReason: _string(data['failure_reason']),
      proofImagePath: _string(data['proof_image']),
      driverNotes: _string(data['driver_notes']),
    );
  }

  DepartmentWorkOrder _mapDepartmentWorkOrder(Map<String, dynamic> data) {
    final departmentId = _string(data['department']);
    return DepartmentWorkOrder(
      id: _string(data['name'], fallback: _string(data['id'])),
      orderId: _string(data['order']),
      departmentId: departmentId,
      departmentName: _string(data['department_name'], fallback: departmentId),
      status: _mapDepartmentWorkOrderStatus(_string(data['status'])),
      productionCenter: _string(data['production_center']),
      priority: _string(data['priority'], fallback: 'Normal'),
      createdBy: _string(data['created_by']),
      acceptedAt: _nullableDateTime(_string(data['accepted_at'])),
      startedAt: _nullableDateTime(_string(data['started_at'])),
      readyAt: _nullableDateTime(_string(data['ready_at'])),
      rejectedAt: _nullableDateTime(_string(data['rejected_at'])),
      delayReason: _string(data['delay_reason']),
      rejectionReason: _string(data['rejection_reason']),
      items: _asList(
        data['items'],
      ).map((item) => _mapDepartmentWorkOrderItem(_asMap(item))).toList(),
    );
  }

  DepartmentWorkOrderItem _mapDepartmentWorkOrderItem(
    Map<String, dynamic> data,
  ) {
    return DepartmentWorkOrderItem(
      itemCode: _string(data['item_code']),
      itemName: _string(
        data['item_name'],
        fallback: _string(data['item_code']),
      ),
      description: _string(data['description']),
      qty: _number(data['qty']),
      rate: _number(data['rate']),
      amount: _number(data['amount']),
      productCategory: _string(data['product_category']),
      sourceOrderItem: _string(data['source_order_item']),
    );
  }

  DeliveryBatch _mapDeliveryBatch(Map<String, dynamic> data) {
    final id = _string(data['name'], fallback: _string(data['id']));
    return DeliveryBatch(
      id: id,
      batchNumber: _string(data['batch_number'], fallback: id),
      destinationBranch: _string(data['destination_branch']),
      status: _mapDeliveryBatchStatus(_string(data['status'])),
      driverId: _string(data['driver']),
      driverName: _string(
        data['driver_name'],
        fallback: _string(data['driver']),
      ),
      assignedBy: _string(data['assigned_by']),
      assignedAt: _nullableDateTime(_string(data['assigned_at'])),
      orders: _asList(
        data['orders'],
      ).map((item) => _mapDeliveryBatchOrder(_asMap(item))).toList(),
    );
  }

  DeliveryBatchOrder _mapDeliveryBatchOrder(Map<String, dynamic> data) {
    return DeliveryBatchOrder(
      orderId: _string(data['order']),
      orderNumber: _string(
        data['order_number'],
        fallback: _string(data['order']),
      ),
      customerName: _string(data['customer_name']),
      customerPhone: _string(data['customer_phone']),
      status: _mapOrderStatus(_string(data['status'])),
    );
  }

  DailyCashClosure _mapDailyCashClosure(Map<String, dynamic> data) {
    final totals = _asMap(data['totals']);
    final payments = _asList(
      data['payments'],
    ).map((item) => _mapOrderPayment(_asMap(item))).toList();
    final logs = _asList(
      data['logs'],
    ).map((item) => _mapCashClosureLog(_asMap(item))).toList();
    final type = _mapCashClosureOwnerType(_string(data['closure_type']));
    final orderIds = payments.map((payment) => payment.orderId).toSet();
    final recordedAmount = _number(
      totals['total_amount'] ?? data['total_amount'],
    );
    final actualAmount = _number(data['actual_total']);
    return DailyCashClosure(
      id: _string(
        data['closure_number'],
        fallback: _string(data['closure_id'], fallback: _string(data['name'])),
      ),
      date: _dateOnlyText(_string(data['date'])),
      ownerUserId: _string(data['user']),
      ownerName: _string(data['owner_name'], fallback: _string(data['user'])),
      ownerRoleLabel: type.label,
      branchId: _string(data['branch']),
      branch: _string(data['branch']),
      type: type,
      status: _mapCashClosureStatus(_string(data['status'])),
      orderCount: _number(data['payments_count'] ?? orderIds.length).round(),
      entries: payments.map(_cashEntryFromPayment).toList(),
      payments: payments,
      logs: logs,
      remainingFromCustomers: 0,
      collectionRate: 0,
      recordedAmount: recordedAmount,
      actualAmount: actualAmount,
      differenceAmount: _number(data['difference_amount']),
      differenceReason: _string(data['difference_reason']),
      cashierNotes: _string(data['cashier_notes']),
    );
  }

  CashEntry _cashEntryFromPayment(OrderPayment payment) {
    return CashEntry(
      orderId: payment.orderId,
      customer: payment.customer,
      method: payment.method,
      amount: payment.amount,
      collectedByUserId: payment.collectedByUserId,
      collectedByName: payment.collectedByName,
      collectorType: payment.collectorType,
      driverId: payment.driverId,
      postedToErpNext: payment.postedToErpNext,
    );
  }

  CashClosureLog _mapCashClosureLog(Map<String, dynamic> data) {
    final idText = _string(data['name']);
    return CashClosureLog(
      id: int.tryParse(idText) ?? idText.hashCode,
      closureId: _string(data['closure']),
      oldStatus: _string(data['old_status']).isEmpty
          ? null
          : _mapCashClosureStatus(_string(data['old_status'])),
      newStatus: _mapCashClosureStatus(_string(data['new_status'])),
      changedByUserId: _string(data['changed_by']),
      changedByName: _string(data['changed_by']),
      changedAt: _dateTimeValue(
        _string(data['created_at'], fallback: _string(data['creation'])),
      ),
      notes: _string(data['notes']),
    );
  }

  String _productSummary(List<OrderLineDraft> items) {
    if (items.isEmpty) return 'طلب بدون منتجات';
    final names = items.map((line) {
      return line.quantity > 1
          ? '${line.product.name} × ${line.quantity}'
          : line.product.name;
    }).toList();
    if (names.length <= 2) return names.join(' + ');
    return '${names.take(2).join(' + ')} + ${names.length - 2} أخرى';
  }

  String _customerTypeKey(CustomerType type) {
    return type == CustomerType.company ? 'Company' : 'Individual';
  }

  String _paymentMethodKey(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.transfer:
        return 'Transfer';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  PaymentMethod _mapPaymentMethod(String value) {
    switch (value) {
      case 'Card':
        return PaymentMethod.card;
      case 'Transfer':
        return PaymentMethod.transfer;
      case 'Other':
        return PaymentMethod.other;
      case 'Cash':
      default:
        return PaymentMethod.cash;
    }
  }

  OrderPaymentStatus _mapOrderPaymentStatus(String value) {
    switch (value) {
      case 'In Daily Closure':
        return OrderPaymentStatus.inDailyClosure;
      case 'Submitted To Cashier':
        return OrderPaymentStatus.submittedToCashier;
      case 'Returned For Review':
        return OrderPaymentStatus.returnedForReview;
      case 'Cashier Accepted':
        return OrderPaymentStatus.cashierAccepted;
      case 'Ready For ERPNext Posting':
        return OrderPaymentStatus.readyForErpnextPosting;
      case 'Posted To ERPNext':
        return OrderPaymentStatus.postedToErpNext;
      case 'Linked To Invoice':
        return OrderPaymentStatus.linkedToInvoice;
      case 'Recorded By Employee':
      default:
        return OrderPaymentStatus.recordedByEmployee;
    }
  }

  PaymentAllocationStatus _mapPaymentAllocationStatus(String value) {
    switch (value) {
      case 'allocated':
      case 'Allocated':
        return PaymentAllocationStatus.allocated;
      case 'failed':
      case 'Failed':
        return PaymentAllocationStatus.failed;
      case 'pending':
      case 'Pending':
      default:
        return PaymentAllocationStatus.pending;
    }
  }

  CashClosureOwnerType _mapCollectorType(String value) {
    return value == 'driver'
        ? CashClosureOwnerType.driver
        : CashClosureOwnerType.employee;
  }

  CashClosureOwnerType _mapCashClosureOwnerType(String value) {
    return value == 'driver'
        ? CashClosureOwnerType.driver
        : CashClosureOwnerType.employee;
  }

  CashClosureStatus _mapCashClosureStatus(String value) {
    switch (value) {
      case 'Submitted To Cashier':
        return CashClosureStatus.submittedToCashier;
      case 'Returned For Review':
        return CashClosureStatus.returnedForReview;
      case 'Accepted':
        return CashClosureStatus.accepted;
      case 'Closed':
        return CashClosureStatus.closed;
      case 'Has Difference':
        return CashClosureStatus.hasDifference;
      case 'Open':
      default:
        return CashClosureStatus.open;
    }
  }

  CashClosureTotals _calculateClosureTotals(List<OrderPayment> payments) {
    num cash = 0;
    num card = 0;
    num transfer = 0;
    num other = 0;
    final orderIds = <String>{};
    for (final payment in payments) {
      orderIds.add(payment.orderId);
      switch (payment.method) {
        case PaymentMethod.cash:
          cash += payment.amount;
        case PaymentMethod.card:
          card += payment.amount;
        case PaymentMethod.transfer:
          transfer += payment.amount;
        case PaymentMethod.other:
          other += payment.amount;
      }
    }
    return CashClosureTotals(
      cash: cash,
      card: card,
      transfer: transfer,
      other: other,
      orderCount: orderIds.length,
    );
  }

  String _orderStatusKey(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return 'Draft';
      case OrderStatus.pendingSupervisorApproval:
        return 'Pending Supervisor Approval';
      case OrderStatus.returnedForEdit:
        return 'Returned For Edit';
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.sentToDistribution:
        return 'Sent To Distribution';
      case OrderStatus.sentToProduction:
        return 'Sent To Production';
      case OrderStatus.inProduction:
        return 'In Production';
      case OrderStatus.productionCompleted:
        return 'Production Completed';
      case OrderStatus.readyForPickup:
        return 'Ready For Pickup';
      case OrderStatus.readyForDelivery:
        return 'Ready For Delivery';
      case OrderStatus.assignedToDriver:
        return 'Assigned To Driver';
      case OrderStatus.driverPickedUp:
        return 'Driver Picked Up';
      case OrderStatus.outForDelivery:
        return 'Out For Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.deliveryFailed:
        return 'Delivery Failed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.pending:
        return 'Pending Supervisor Approval';
      case OrderStatus.approved:
        return 'Sent To Distribution';
      case OrderStatus.ready:
        return 'Ready For Pickup';
    }
  }

  String _departmentWorkOrderStatusKey(DepartmentWorkOrderStatus status) {
    switch (status) {
      case DepartmentWorkOrderStatus.pending:
        return 'pending';
      case DepartmentWorkOrderStatus.accepted:
        return 'accepted';
      case DepartmentWorkOrderStatus.inProduction:
        return 'in_production';
      case DepartmentWorkOrderStatus.delayed:
        return 'delayed';
      case DepartmentWorkOrderStatus.ready:
        return 'ready';
      case DepartmentWorkOrderStatus.rejected:
        return 'rejected';
      case DepartmentWorkOrderStatus.cancelled:
        return 'cancelled';
    }
  }

  DepartmentWorkOrderStatus _mapDepartmentWorkOrderStatus(String value) {
    switch (value) {
      case 'accepted':
        return DepartmentWorkOrderStatus.accepted;
      case 'in_production':
        return DepartmentWorkOrderStatus.inProduction;
      case 'delayed':
        return DepartmentWorkOrderStatus.delayed;
      case 'ready':
        return DepartmentWorkOrderStatus.ready;
      case 'rejected':
        return DepartmentWorkOrderStatus.rejected;
      case 'cancelled':
        return DepartmentWorkOrderStatus.cancelled;
      case 'pending':
      default:
        return DepartmentWorkOrderStatus.pending;
    }
  }

  String _deliveryBatchStatusKey(DeliveryBatchStatus status) {
    switch (status) {
      case DeliveryBatchStatus.draft:
        return 'draft';
      case DeliveryBatchStatus.assigned:
        return 'assigned';
      case DeliveryBatchStatus.pickedUp:
        return 'picked_up';
      case DeliveryBatchStatus.outForDelivery:
        return 'out_for_delivery';
      case DeliveryBatchStatus.delivered:
        return 'delivered';
      case DeliveryBatchStatus.partiallyDelivered:
        return 'partially_delivered';
      case DeliveryBatchStatus.returned:
        return 'returned';
      case DeliveryBatchStatus.cancelled:
        return 'cancelled';
    }
  }

  DeliveryBatchStatus _mapDeliveryBatchStatus(String value) {
    switch (value) {
      case 'assigned':
        return DeliveryBatchStatus.assigned;
      case 'picked_up':
        return DeliveryBatchStatus.pickedUp;
      case 'out_for_delivery':
        return DeliveryBatchStatus.outForDelivery;
      case 'delivered':
        return DeliveryBatchStatus.delivered;
      case 'partially_delivered':
        return DeliveryBatchStatus.partiallyDelivered;
      case 'returned':
        return DeliveryBatchStatus.returned;
      case 'cancelled':
        return DeliveryBatchStatus.cancelled;
      case 'draft':
      default:
        return DeliveryBatchStatus.draft;
    }
  }

  OrderStatus _mapOrderStatus(String value) {
    switch (value) {
      case 'Draft':
        return OrderStatus.draft;
      case 'Pending Supervisor Approval':
        return OrderStatus.pendingSupervisorApproval;
      case 'Returned For Edit':
        return OrderStatus.returnedForEdit;
      case 'Rejected':
        return OrderStatus.rejected;
      case 'Sent To Distribution':
        return OrderStatus.sentToDistribution;
      case 'Sent To Production':
        return OrderStatus.sentToProduction;
      case 'In Production':
        return OrderStatus.inProduction;
      case 'Production Completed':
        return OrderStatus.productionCompleted;
      case 'Ready For Pickup':
        return OrderStatus.readyForPickup;
      case 'Ready For Delivery':
        return OrderStatus.readyForDelivery;
      case 'Assigned To Driver':
        return OrderStatus.assignedToDriver;
      case 'Driver Picked Up':
        return OrderStatus.driverPickedUp;
      case 'Out For Delivery':
        return OrderStatus.outForDelivery;
      case 'Delivered':
        return OrderStatus.delivered;
      case 'Delivery Failed':
        return OrderStatus.deliveryFailed;
      case 'Cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  int _mapOrderProgress(String status) {
    switch (_mapOrderStatus(status)) {
      case OrderStatus.draft:
        return 0;
      case OrderStatus.pendingSupervisorApproval:
      case OrderStatus.pending:
        return 1;
      case OrderStatus.sentToDistribution:
      case OrderStatus.sentToProduction:
      case OrderStatus.inProduction:
        return 2;
      case OrderStatus.productionCompleted:
      case OrderStatus.readyForPickup:
      case OrderStatus.readyForDelivery:
      case OrderStatus.assignedToDriver:
      case OrderStatus.driverPickedUp:
      case OrderStatus.outForDelivery:
        return 3;
      case OrderStatus.delivered:
        return 4;
      case OrderStatus.deliveryFailed:
      case OrderStatus.approved:
      case OrderStatus.returnedForEdit:
      case OrderStatus.ready:
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return 1;
    }
  }

  ErpSyncStatus _mapErpSyncStatus(String value) {
    switch (value) {
      case 'Pending':
        return ErpSyncStatus.pending;
      case 'Synced':
        return ErpSyncStatus.synced;
      case 'Failed':
        return ErpSyncStatus.failed;
      case 'Partially Synced':
        return ErpSyncStatus.partiallySynced;
      case 'Not Synced':
      default:
        return ErpSyncStatus.notSynced;
    }
  }

  NotificationType _mapNotificationType(String value) {
    switch (value) {
      case 'order_approved':
        return NotificationType.orderApproved;
      case 'order_rejected':
        return NotificationType.orderRejected;
      case 'order_returned':
        return NotificationType.orderReturned;
      case 'order_sent_to_distribution':
        return NotificationType.orderSentToDistribution;
      case 'order_sent_to_production':
        return NotificationType.orderSentToProduction;
      case 'production_started':
        return NotificationType.productionStarted;
      case 'production_completed':
        return NotificationType.productionCompleted;
      case 'ready_for_pickup':
        return NotificationType.readyForPickup;
      case 'ready_for_delivery':
        return NotificationType.readyForDelivery;
      case 'driver_assigned':
        return NotificationType.driverAssigned;
      case 'driver_picked_up':
        return NotificationType.driverPickedUp;
      case 'out_for_delivery':
        return NotificationType.outForDelivery;
      case 'order_delivered':
        return NotificationType.orderDelivered;
      case 'delivery_failed':
        return NotificationType.deliveryFailed;
      case 'payment_collected':
        return NotificationType.paymentCollected;
      case 'cash_closure_submitted':
        return NotificationType.cashClosureSubmitted;
      case 'cash_closure_accepted':
        return NotificationType.cashClosureAccepted;
      case 'cash_closure_returned':
        return NotificationType.cashClosureReturned;
      case 'cash_closure_difference':
        return NotificationType.cashClosureDifference;
      case 'cash_closure_closed':
        return NotificationType.cashClosureClosed;
      case 'payments_ready_for_posting':
        return NotificationType.paymentsReadyForPosting;
      default:
        return NotificationType.general;
    }
  }

  String? _dateKey(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String? _timeKey(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    if (value.trim().isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _dateOnlyText(String value) {
    if (value.length >= 10) return value.substring(0, 10);
    return value;
  }

  DateTime _dateTimeValue(String value) {
    return _nullableDateTime(value) ?? DateTime.now();
  }

  DateTime? _nullableDateTime(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  AppUser _mapAppUser(Map<String, dynamic> data) {
    final roles = _asList(
      data['roles'],
    ).map((role) => role.toString()).toList();
    final role = _mapUserRole(roles);
    final branch = _string(data['branch']);
    return AppUser(
      id: _string(data['id']),
      fullName: _string(data['full_name'], fallback: _string(data['id'])),
      email: _string(data['email']),
      phone: _string(data['phone']),
      role: role,
      branchId: branch,
      branchName: branch,
      isActive: true,
      productionDepartmentId: _string(data['production_department']),
    );
  }

  UserRole _mapUserRole(List<String> roles) {
    const mapping = <String, UserRole>{
      'Awamir System Admin': UserRole.systemAdmin,
      'Awamir Accountant': UserRole.accountant,
      'Awamir Cashier': UserRole.cashier,
      'Awamir Driver': UserRole.driver,
      'Awamir Production User': UserRole.productionUser,
      'Awamir Distribution Manager': UserRole.distributionManager,
      'Awamir Branch Supervisor': UserRole.branchSupervisor,
      'Awamir Branch Employee': UserRole.branchEmployee,
    };
    for (final entry in mapping.entries) {
      if (roles.contains(entry.key)) return entry.value;
    }
    return UserRole.branchEmployee;
  }

  Customer _mapCustomer(
    Map<String, dynamic> data, {
    String fallbackPhone = '',
  }) {
    final id = _string(data['name']);
    final type = _string(data['customer_type']).toLowerCase();
    final isCompany = type == 'company';
    return Customer(
      id: id,
      name: _string(data['customer_name'], fallback: id),
      phone: _string(data['mobile_no'], fallback: fallbackPhone),
      isCompany: isCompany,
      companyName: isCompany
          ? _string(data['customer_name'], fallback: id)
          : '',
      taxNumber: _string(data['tax_id']),
    );
  }

  CustomerAddress _mapCustomerAddress(Map<String, dynamic> data) {
    final id = _string(data['name']);
    return CustomerAddress(
      id: id,
      title: _string(data['address_title'], fallback: id),
      details: _string(data['address_line1']),
      city: _string(data['city']),
      district: _string(data['district']),
      postalCode: _string(data['pincode']),
      googleMapsUrl: _string(data['custom_google_maps_url']),
      latitude: double.tryParse(_string(data['custom_latitude'])),
      longitude: double.tryParse(_string(data['custom_longitude'])),
      notes: _string(data['notes']),
    );
  }

  String _absoluteUrl(String value) {
    if (value.isEmpty || value.startsWith('http')) return value;
    final base = Uri.parse(AppEnvironment.baseUrl);
    return base.replace(path: value).toString();
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(Object? data) {
    if (data is List) return data;
    return const [];
  }

  bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString() == '1' || value.toString().toLowerCase() == 'true';
  }

  num _number(Object? value) {
    if (value is num) return value;
    return num.tryParse(_string(value)) ?? 0;
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }
}
