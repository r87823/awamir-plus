import '../core/errors/app_exception.dart';
import '../models/app_models.dart';
import 'auth_service.dart';

class ErpnextService implements AuthService {
  const ErpnextService();

  @override
  Future<AppUser> login({required String username, required String password}) {
    return _notConfigured();
  }

  @override
  Future<AppUser?> restoreSession(String sessionKey) {
    return _notConfigured();
  }

  @override
  Future<AppUser?> getCurrentUser() {
    return _notConfigured();
  }

  @override
  Future<void> logout() {
    return _notConfigured();
  }

  Future<List<ProductDepartment>> getCategories() {
    return _notConfigured();
  }

  Future<List<Product>> getProductsByCategory(String categoryId) {
    return _notConfigured();
  }

  Future<Customer?> searchCustomerByPhone(String phone) {
    return _notConfigured();
  }

  Future<List<CustomerAddress>> getCustomerAddresses(String customerId) {
    return _notConfigured();
  }

  Future<Order> createOrder(OrderDraft draft, List<Product> products) {
    return _notConfigured();
  }

  Future<void> saveOrderAsDraft(OrderDraft draft) {
    return _notConfigured();
  }

  Future<Order> saveDraft(CreateOrderRequest request) {
    return _notConfigured();
  }

  Future<Order> submitForApproval(CreateOrderRequest request) {
    return _notConfigured();
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

  Future<List<Order>> getOrders({OrderStatus? status}) {
    return _notConfigured();
  }

  Future<List<Order>> getDistributionOrders(AppUser user) {
    return _notConfigured();
  }

  Future<List<ProductionDepartment>> getProductionDepartments() {
    return _notConfigured();
  }

  Future<ProductionDepartment?> getDefaultDepartmentForOrder(Order order) {
    return _notConfigured();
  }

  Future<Order> assignProductionDepartment({
    required String orderId,
    required String productionDepartmentId,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<List<Order>> getProductionOrders(AppUser user) {
    return _notConfigured();
  }

  Future<Order> updateProductionStatus({
    required String orderId,
    required OrderStatus status,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<List<Order>> getPickupOrders(AppUser user) {
    return _notConfigured();
  }

  Future<Order> markPickupOrderDelivered({
    required String orderId,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<Order> collectRemainingPayment({
    required String orderId,
    required num amount,
    required PaymentMethod method,
    required AppUser collectedBy,
    String transactionReference = '',
    String receiptPath = '',
  }) {
    return _notConfigured();
  }

  Future<List<DriverProfile>> getAvailableDrivers(
    AppUser user, {
    String? branchId,
  }) {
    return _notConfigured();
  }

  Future<Order> assignDriverToOrder({
    required String orderId,
    required String driverId,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<List<Order>> getDriverOrders(AppUser user) {
    return _notConfigured();
  }

  Future<Order> updateDeliveryStatus({
    required String orderId,
    required OrderStatus status,
    required AppUser changedBy,
    String proofImagePath = '',
    String driverNotes = '',
  }) {
    return _notConfigured();
  }

  Future<Order> markDeliveryFailed({
    required String orderId,
    required AppUser changedBy,
    required String reason,
  }) {
    return _notConfigured();
  }

  Future<OrderPayment> collectDeliveryPayment({
    required String orderId,
    required num amount,
    required PaymentMethod method,
    required AppUser collectedBy,
    String transactionReference = '',
    String receiptPath = '',
  }) {
    return _notConfigured();
  }

  Future<DeliveryAssignment?> getDeliveryAssignment(String orderId) {
    return _notConfigured();
  }

  Future<List<Order>> getPendingSupervisorApprovals(AppUser user) {
    return _notConfigured();
  }

  Future<Order> approveOrder({
    required String orderId,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<Order> rejectOrder({
    required String orderId,
    required AppUser changedBy,
    required String reason,
  }) {
    return _notConfigured();
  }

  Future<Order> returnOrderForEdit({
    required String orderId,
    required AppUser changedBy,
    required String notes,
  }) {
    return _notConfigured();
  }

  Future<OrderStatusLog> addStatusLog(OrderStatusLog log) {
    return _notConfigured();
  }

  Future<List<OrderStatusLog>> getOrderStatusLogs(String orderId) {
    return _notConfigured();
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

  Future<DailyCashClosure> getMyDailyCashClosure(AppUser user) {
    return _notConfigured();
  }

  Future<DailyCashClosure> getCashClosureById(String closureId) {
    return _notConfigured();
  }

  Future<DailyCashClosure> submitCashClosure({
    required String closureId,
    required AppUser submittedBy,
  }) {
    return _notConfigured();
  }

  Future<List<DailyCashClosure>> getSubmittedCashClosures(AppUser user) {
    return _notConfigured();
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
  }) {
    return _notConfigured();
  }

  Future<DailyCashClosure> returnCashClosure({
    required String closureId,
    required AppUser cashier,
    required String reason,
  }) {
    return _notConfigured();
  }

  Future<DailyCashClosure> closeCashClosure({
    required String closureId,
    required AppUser closedBy,
  }) {
    return _notConfigured();
  }

  Future<List<OrderPayment>> getCashClosurePayments(String closureId) {
    return _notConfigured();
  }

  Future<CashClosureTotals> calculateClosureTotals(
    List<OrderPayment> payments,
  ) {
    return _notConfigured();
  }

  Future<void> markPaymentsAsSubmitted(String closureId) {
    return _notConfigured();
  }

  Future<void> markPaymentsAsCashierAccepted(String closureId) {
    return _notConfigured();
  }

  Future<List<CashClosureLog>> getCashClosureLogs(String closureId) {
    return _notConfigured();
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
  }) {
    return _notConfigured();
  }

  Future<Order> createWorkOrderForOrder({
    required String orderId,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<List<OrderPayment>> postAcceptedPaymentsToErpnext({
    required String closureId,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<OrderPayment> createPaymentEntryForPayment({
    required String paymentId,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<Order> createSalesInvoiceForOrder({
    required String orderId,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<List<PaymentAllocation>> allocateAdvancePaymentToInvoice({
    required String orderId,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<List<Order>> getCustomerInvoices(String customerId) {
    return _notConfigured();
  }

  Future<Order> syncOrderAccountingStatus({
    required String orderId,
    required AppUser changedBy,
  }) {
    return _notConfigured();
  }

  Future<List<Order>> getOrdersNeedingSalesOrder() {
    return _notConfigured();
  }

  Future<List<OrderPayment>> getPaymentsReadyForErpPosting() {
    return _notConfigured();
  }

  Future<List<Order>> getOrdersNeedingSalesInvoice() {
    return _notConfigured();
  }

  Future<List<Order>> getInvoicesNeedingAdvanceAllocation() {
    return _notConfigured();
  }

  Future<List<Order>> getAccountingSyncErrors() {
    return _notConfigured();
  }

  Future<List<AppNotification>> getNotifications() {
    return _notConfigured();
  }

  Future<List<AppNotification>> getNotificationsForCurrentUser(AppUser user) {
    return _notConfigured();
  }

  Future<void> markNotificationAsRead(int id) {
    return _notConfigured();
  }

  Future<void> markNotificationRead(int id) {
    return _notConfigured();
  }

  Future<void> markAllNotificationsRead() {
    return _notConfigured();
  }

  Future<List<TodayPickupOrder>> getTodayPickupOrders() {
    return _notConfigured();
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
}
