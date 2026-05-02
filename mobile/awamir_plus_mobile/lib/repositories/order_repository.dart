import '../core/constants/environment.dart';
import '../core/errors/app_exception.dart';
import '../models/app_models.dart';
import '../services/erpnext_service.dart';
import '../services/mock_service.dart';

class OrderRepository {
  OrderRepository({
    MockService? mockService,
    ErpnextService? erpnextService,
    bool useMockData = AppEnvironment.useMockData,
  }) : _mockService = mockService ?? MockService(),
       _erpnextService = erpnextService ?? const ErpnextService(),
       _useMockData = useMockData;

  final MockService _mockService;
  final ErpnextService _erpnextService;
  final bool _useMockData;

  Future<Order> createOrder(OrderDraft draft, List<Product> products) async {
    try {
      return _useMockData
          ? _mockService.createOrder(draft, products)
          : _erpnextService.createOrder(draft, products);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر إنشاء الطلب',
        code: 'order_create_failed',
        cause: error,
      );
    }
  }

  Future<void> saveOrderAsDraft(OrderDraft draft) async {
    try {
      return _useMockData
          ? _mockService.saveOrderAsDraft(draft)
          : _erpnextService.saveOrderAsDraft(draft);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر حفظ الطلب كمسودة',
        code: 'order_draft_failed',
        cause: error,
      );
    }
  }

  Future<Order> saveDraft(CreateOrderRequest request) async {
    try {
      return _useMockData
          ? _mockService.saveDraft(request)
          : _erpnextService.saveDraft(request);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر حفظ الطلب كمسودة',
        code: 'create_order_draft_failed',
        cause: error,
      );
    }
  }

  Future<Order> submitForApproval(CreateOrderRequest request) async {
    try {
      return _useMockData
          ? _mockService.submitForApproval(request)
          : _erpnextService.submitForApproval(request);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر إرسال الطلب للموافقة',
        code: 'create_order_submit_failed',
        cause: error,
      );
    }
  }

  Future<Order> submitOrderForApproval(String orderId) async {
    try {
      return _useMockData
          ? _mockService.submitOrderForApproval(orderId)
          : _erpnextService.submitOrderForApproval(orderId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر إرسال الطلب للموافقة',
        code: 'order_submit_failed',
        cause: error,
      );
    }
  }

  Future<List<Order>> getOrders({OrderStatus? status}) async {
    try {
      return _useMockData
          ? _mockService.getOrders(status: status)
          : _erpnextService.getOrders(status: status);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل الطلبات',
        code: 'orders_load_failed',
        cause: error,
      );
    }
  }

  Future<List<Order>> getDistributionOrders(AppUser user) async {
    try {
      return _useMockData
          ? _mockService.getDistributionOrders(user)
          : _erpnextService.getDistributionOrders(user);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل طلبات التوزيع',
        code: 'distribution_orders_load_failed',
        cause: error,
      );
    }
  }

  Future<List<ProductionDepartment>> getProductionDepartments() async {
    try {
      return _useMockData
          ? _mockService.getProductionDepartments()
          : _erpnextService.getProductionDepartments();
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل جهات التنفيذ',
        code: 'production_departments_load_failed',
        cause: error,
      );
    }
  }

  Future<ProductionDepartment?> getDefaultDepartmentForOrder(
    Order order,
  ) async {
    try {
      return _useMockData
          ? _mockService.getDefaultDepartmentForOrder(order)
          : _erpnextService.getDefaultDepartmentForOrder(order);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحديد جهة التنفيذ الافتراضية',
        code: 'default_production_department_failed',
        cause: error,
      );
    }
  }

  Future<Order> assignProductionDepartment({
    required String orderId,
    required String productionDepartmentId,
    required AppUser changedBy,
  }) async {
    try {
      return _useMockData
          ? _mockService.assignProductionDepartment(
              orderId: orderId,
              productionDepartmentId: productionDepartmentId,
              changedBy: changedBy,
            )
          : _erpnextService.assignProductionDepartment(
              orderId: orderId,
              productionDepartmentId: productionDepartmentId,
              changedBy: changedBy,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحويل الطلب للتنفيذ',
        code: 'assign_production_failed',
        cause: error,
      );
    }
  }

  Future<List<Order>> getProductionOrders(AppUser user) async {
    try {
      return _useMockData
          ? _mockService.getProductionOrders(user)
          : _erpnextService.getProductionOrders(user);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل طلبات الإنتاج',
        code: 'production_orders_load_failed',
        cause: error,
      );
    }
  }

  Future<Order> updateProductionStatus({
    required String orderId,
    required OrderStatus status,
    required AppUser changedBy,
  }) async {
    try {
      return _useMockData
          ? _mockService.updateProductionStatus(
              orderId: orderId,
              status: status,
              changedBy: changedBy,
            )
          : _erpnextService.updateProductionStatus(
              orderId: orderId,
              status: status,
              changedBy: changedBy,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحديث حالة الإنتاج',
        code: 'production_status_update_failed',
        cause: error,
      );
    }
  }

  Future<List<Order>> getPickupOrders(AppUser user) async {
    try {
      return _useMockData
          ? _mockService.getPickupOrders(user)
          : _erpnextService.getPickupOrders(user);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل طلبات الاستلام من الفرع',
        code: 'pickup_orders_load_failed',
        cause: error,
      );
    }
  }

  Future<Order> markPickupOrderDelivered({
    required String orderId,
    required AppUser changedBy,
  }) async {
    try {
      return _useMockData
          ? _mockService.markPickupOrderDelivered(
              orderId: orderId,
              changedBy: changedBy,
            )
          : _erpnextService.markPickupOrderDelivered(
              orderId: orderId,
              changedBy: changedBy,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تسليم الطلب من الفرع',
        code: 'pickup_deliver_failed',
        cause: error,
      );
    }
  }

  Future<Order> collectRemainingPayment({
    required String orderId,
    required num amount,
    required PaymentMethod method,
    required AppUser collectedBy,
    String transactionReference = '',
    String receiptPath = '',
  }) async {
    try {
      return _useMockData
          ? _mockService.collectRemainingPayment(
              orderId: orderId,
              amount: amount,
              method: method,
              collectedBy: collectedBy,
              transactionReference: transactionReference,
              receiptPath: receiptPath,
            )
          : _erpnextService.collectRemainingPayment(
              orderId: orderId,
              amount: amount,
              method: method,
              collectedBy: collectedBy,
              transactionReference: transactionReference,
              receiptPath: receiptPath,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تسجيل دفعة المتبقي',
        code: 'remaining_payment_failed',
        cause: error,
      );
    }
  }

  Future<List<DriverProfile>> getAvailableDrivers(
    AppUser user, {
    String? branchId,
  }) async {
    try {
      return _useMockData
          ? _mockService.getAvailableDrivers(user, branchId: branchId)
          : _erpnextService.getAvailableDrivers(user, branchId: branchId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل السائقين',
        code: 'drivers_load_failed',
        cause: error,
      );
    }
  }

  Future<Order> assignDriverToOrder({
    required String orderId,
    required String driverId,
    required AppUser changedBy,
  }) async {
    try {
      return _useMockData
          ? _mockService.assignDriverToOrder(
              orderId: orderId,
              driverId: driverId,
              changedBy: changedBy,
            )
          : _erpnextService.assignDriverToOrder(
              orderId: orderId,
              driverId: driverId,
              changedBy: changedBy,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر إسناد الطلب للسائق',
        code: 'assign_driver_failed',
        cause: error,
      );
    }
  }

  Future<List<Order>> getDriverOrders(AppUser user) async {
    try {
      return _useMockData
          ? _mockService.getDriverOrders(user)
          : _erpnextService.getDriverOrders(user);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل طلبات السائق',
        code: 'driver_orders_load_failed',
        cause: error,
      );
    }
  }

  Future<Order> updateDeliveryStatus({
    required String orderId,
    required OrderStatus status,
    required AppUser changedBy,
    String proofImagePath = '',
    String driverNotes = '',
  }) async {
    try {
      return _useMockData
          ? _mockService.updateDeliveryStatus(
              orderId: orderId,
              status: status,
              changedBy: changedBy,
              proofImagePath: proofImagePath,
              driverNotes: driverNotes,
            )
          : _erpnextService.updateDeliveryStatus(
              orderId: orderId,
              status: status,
              changedBy: changedBy,
              proofImagePath: proofImagePath,
              driverNotes: driverNotes,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحديث حالة التوصيل',
        code: 'delivery_status_update_failed',
        cause: error,
      );
    }
  }

  Future<Order> markDeliveryFailed({
    required String orderId,
    required AppUser changedBy,
    required String reason,
  }) async {
    try {
      return _useMockData
          ? _mockService.markDeliveryFailed(
              orderId: orderId,
              changedBy: changedBy,
              reason: reason,
            )
          : _erpnextService.markDeliveryFailed(
              orderId: orderId,
              changedBy: changedBy,
              reason: reason,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تسجيل تعذر التسليم',
        code: 'delivery_failed_update_failed',
        cause: error,
      );
    }
  }

  Future<OrderPayment> collectDeliveryPayment({
    required String orderId,
    required num amount,
    required PaymentMethod method,
    required AppUser collectedBy,
    String transactionReference = '',
    String receiptPath = '',
  }) async {
    try {
      return _useMockData
          ? _mockService.collectDeliveryPayment(
              orderId: orderId,
              amount: amount,
              method: method,
              collectedBy: collectedBy,
              transactionReference: transactionReference,
              receiptPath: receiptPath,
            )
          : _erpnextService.collectDeliveryPayment(
              orderId: orderId,
              amount: amount,
              method: method,
              collectedBy: collectedBy,
              transactionReference: transactionReference,
              receiptPath: receiptPath,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تسجيل دفعة التوصيل',
        code: 'delivery_payment_failed',
        cause: error,
      );
    }
  }

  Future<DeliveryAssignment?> getDeliveryAssignment(String orderId) async {
    try {
      return _useMockData
          ? _mockService.getDeliveryAssignment(orderId)
          : _erpnextService.getDeliveryAssignment(orderId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل تكليف التوصيل',
        code: 'delivery_assignment_load_failed',
        cause: error,
      );
    }
  }

  Future<List<Order>> getPendingSupervisorApprovals(AppUser user) async {
    try {
      return _useMockData
          ? _mockService.getPendingSupervisorApprovals(user)
          : _erpnextService.getPendingSupervisorApprovals(user);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل موافقات المشرف',
        code: 'supervisor_approvals_load_failed',
        cause: error,
      );
    }
  }

  Future<Order> approveOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    try {
      return _useMockData
          ? _mockService.approveOrder(orderId: orderId, changedBy: changedBy)
          : _erpnextService.approveOrder(
              orderId: orderId,
              changedBy: changedBy,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر الموافقة على الطلب',
        code: 'order_approve_failed',
        cause: error,
      );
    }
  }

  Future<Order> rejectOrder({
    required String orderId,
    required AppUser changedBy,
    required String reason,
  }) async {
    try {
      return _useMockData
          ? _mockService.rejectOrder(
              orderId: orderId,
              changedBy: changedBy,
              reason: reason,
            )
          : _erpnextService.rejectOrder(
              orderId: orderId,
              changedBy: changedBy,
              reason: reason,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر رفض الطلب',
        code: 'order_reject_failed',
        cause: error,
      );
    }
  }

  Future<Order> returnOrderForEdit({
    required String orderId,
    required AppUser changedBy,
    required String notes,
  }) async {
    try {
      return _useMockData
          ? _mockService.returnOrderForEdit(
              orderId: orderId,
              changedBy: changedBy,
              notes: notes,
            )
          : _erpnextService.returnOrderForEdit(
              orderId: orderId,
              changedBy: changedBy,
              notes: notes,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر إرجاع الطلب للتعديل',
        code: 'order_return_failed',
        cause: error,
      );
    }
  }

  Future<OrderStatusLog> addStatusLog(OrderStatusLog log) async {
    return _useMockData
        ? _mockService.addStatusLog(log)
        : _erpnextService.addStatusLog(log);
  }

  Future<List<OrderStatusLog>> getOrderStatusLogs(String orderId) async {
    try {
      return _useMockData
          ? _mockService.getOrderStatusLogs(orderId)
          : _erpnextService.getOrderStatusLogs(orderId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل سجل حالات الطلب',
        code: 'status_logs_load_failed',
        cause: error,
      );
    }
  }

  Future<AppNotification> createNotification(
    AppNotification notification,
  ) async {
    return _useMockData
        ? _mockService.createNotification(notification)
        : _erpnextService.createNotification(notification);
  }

  Future<List<AppNotification>> getNotifications() async {
    try {
      return _useMockData
          ? _mockService.getNotifications()
          : _erpnextService.getNotifications();
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل الإشعارات',
        code: 'notifications_load_failed',
        cause: error,
      );
    }
  }

  Future<List<AppNotification>> getNotificationsForCurrentUser(
    AppUser user,
  ) async {
    try {
      return _useMockData
          ? _mockService.getNotificationsForCurrentUser(user)
          : _erpnextService.getNotificationsForCurrentUser(user);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل إشعارات المستخدم',
        code: 'user_notifications_load_failed',
        cause: error,
      );
    }
  }

  Future<void> markNotificationAsRead(int id) => markNotificationRead(id);

  Future<void> markNotificationRead(int id) async {
    return _useMockData
        ? _mockService.markNotificationRead(id)
        : _erpnextService.markNotificationRead(id);
  }

  Future<void> markAllNotificationsRead() async {
    return _useMockData
        ? _mockService.markAllNotificationsRead()
        : _erpnextService.markAllNotificationsRead();
  }

  Future<List<TodayPickupOrder>> getTodayPickupOrders() async {
    try {
      return _useMockData
          ? _mockService.getTodayPickupOrders()
          : _erpnextService.getTodayPickupOrders();
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل طلبات الاستلام',
        code: 'pickup_load_failed',
        cause: error,
      );
    }
  }

  Future<TodayPickupOrder?> collectPickupPayment(int id, num amount) async {
    return _useMockData
        ? _mockService.collectPickupPayment(id, amount)
        : _erpnextService.collectPickupPayment(id, amount);
  }

  Future<TodayPickupOrder?> deliverPickupOrder(int id) async {
    return _useMockData
        ? _mockService.deliverPickupOrder(id)
        : _erpnextService.deliverPickupOrder(id);
  }
}
