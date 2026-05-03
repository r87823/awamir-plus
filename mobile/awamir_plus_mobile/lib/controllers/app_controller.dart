import 'package:flutter/material.dart';

import '../core/constants/environment.dart';
import '../core/errors/app_exception.dart';
import '../core/permissions/access_control.dart';
import '../core/utils/view_state.dart';
import '../models/app_models.dart';
import '../repositories/accounting_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/product_repository.dart';
import '../services/erpnext_service.dart';
import '../services/mock_service.dart';

class AppController extends ChangeNotifier {
  factory AppController({
    required AppUser currentUser,
    MockService? mockService,
    bool useMockData = AppEnvironment.useMockData,
  }) {
    final sharedMockService = mockService ?? MockService();
    final erpnextService = ErpnextService();

    return AppController.withRepositories(
      currentUser: currentUser,
      productRepository: ProductRepository(
        mockService: sharedMockService,
        erpnextService: erpnextService,
        useMockData: useMockData,
      ),
      orderRepository: OrderRepository(
        mockService: sharedMockService,
        erpnextService: erpnextService,
        useMockData: useMockData,
      ),
      customerRepository: CustomerRepository(
        mockService: sharedMockService,
        erpnextService: erpnextService,
        useMockData: useMockData,
      ),
      paymentRepository: PaymentRepository(
        mockService: sharedMockService,
        erpnextService: erpnextService,
        useMockData: useMockData,
      ),
      accountingRepository: AccountingRepository(
        mockService: sharedMockService,
        erpnextService: erpnextService,
        useMockData: useMockData,
      ),
    );
  }

  AppController.withRepositories({
    required this.currentUser,
    required ProductRepository productRepository,
    required OrderRepository orderRepository,
    required CustomerRepository customerRepository,
    required PaymentRepository paymentRepository,
    required AccountingRepository accountingRepository,
  }) : _productRepository = productRepository,
       _orderRepository = orderRepository,
       _customerRepository = customerRepository,
       _paymentRepository = paymentRepository,
       _accountingRepository = accountingRepository {
    loadInitialData();
  }

  final ProductRepository _productRepository;
  final OrderRepository _orderRepository;
  final CustomerRepository _customerRepository;
  final PaymentRepository _paymentRepository;
  final AccountingRepository _accountingRepository;
  final AppUser currentUser;

  ProductRepository get productRepository => _productRepository;
  OrderRepository get orderRepository => _orderRepository;
  CustomerRepository get customerRepository => _customerRepository;

  final OrderDraft draft = OrderDraft();

  ViewState<void> appState = const ViewState.loading();
  ViewState<void> actionState = const ViewState.success(null);

  List<ProductDepartment> departments = [];
  List<Product> products = [];
  List<Order> orders = [];
  List<Order> supervisorApprovals = [];
  List<Order> distributionOrders = [];
  List<Order> productionOrders = [];
  List<Order> branchPickupOrders = [];
  List<Order> driverOrders = [];
  List<ProductionDepartment> productionDepartments = [];
  List<AppNotification> notifications = [];
  List<TodayPickupOrder> pickupOrders = [];
  List<DailyCashClosure> cashierClosures = [];
  List<Order> ordersNeedingSalesOrder = [];
  List<OrderPayment> paymentsReadyForErpPosting = [];
  List<Order> ordersNeedingSalesInvoice = [];
  List<Order> invoicesNeedingAdvanceAllocation = [];
  List<Order> accountingSyncErrors = [];
  DailyCashClosure? dailyCashClosure;

  ProductDepartment? _selectedDepartment;

  bool get isLoading => appState.isLoading;
  bool get hasError => appState.isError;
  bool get isEmpty => appState.isEmpty;
  String get errorMessage => appState.message ?? 'حدث خطأ غير متوقع';
  bool get isActionLoading => actionState.isLoading;
  String? get actionErrorMessage =>
      actionState.isError ? actionState.message : null;

  ProductDepartment? get selectedDepartment =>
      _selectedDepartment ?? (departments.isEmpty ? null : departments.first);

  List<CashEntry> get cashEntries => dailyCashClosure?.entries ?? const [];

  int get unreadNotifications =>
      notifications.where((item) => !item.read).length;

  int get todayOrdersCount => orders.length < 12 ? 12 : orders.length;

  int get pendingOrdersCount => orders
      .where(
        (item) =>
            item.status == OrderStatus.pending ||
            item.status == OrderStatus.pendingSupervisorApproval,
      )
      .length;

  int get todayPickupCount =>
      pickupOrders.where((item) => !item.delivered).length;

  num get collectedDeposit => dailyCashClosure?.total ?? 0;

  num get totalRemainingFromCustomers =>
      dailyCashClosure?.remainingFromCustomers ?? 0;

  double get collectionRate => dailyCashClosure?.collectionRate ?? 0;

  int get dailyCashOrderCount => dailyCashClosure?.orderCount ?? 0;

  String get dailyCashDate => dailyCashClosure?.date ?? '';

  String get dailyCashBranch => dailyCashClosure?.branch ?? '';

  List<AppFeature> get homeFeatures => AccessControl.roleFeatures(currentUser);

  List<AppFeature> get navigationFeatures =>
      AccessControl.primaryNavigationFeatures(currentUser);

  bool canAccess(AppFeature feature) =>
      AccessControl.canAccessFeature(currentUser, feature);

  Future<void> loadInitialData() async {
    appState = const ViewState.loading();
    notifyListeners();

    try {
      departments = await _productRepository.getCategories();

      final loadedProducts = <Product>[];
      for (final department in departments) {
        loadedProducts.addAll(
          await _productRepository.getProductsByCategory(department.id),
        );
      }
      products = loadedProducts;
      _selectedDepartment = departments.isEmpty ? null : departments.first;

      driverOrders = AccessControl.canViewDriverOrders(currentUser)
          ? await _orderRepository.getDriverOrders(currentUser)
          : [];
      orders = _visibleOrders(await _orderRepository.getOrders());
      supervisorApprovals = AccessControl.canApproveOrders(currentUser)
          ? await _orderRepository.getPendingSupervisorApprovals(currentUser)
          : [];
      distributionOrders = AccessControl.canViewDistribution(currentUser)
          ? await _orderRepository.getDistributionOrders(currentUser)
          : [];
      productionDepartments = await _orderRepository.getProductionDepartments();
      productionOrders = AccessControl.canViewProductionOrders(currentUser)
          ? await _orderRepository.getProductionOrders(currentUser)
          : [];
      branchPickupOrders = AccessControl.canViewPickupOrders(currentUser)
          ? await _orderRepository.getPickupOrders(currentUser)
          : [];
      notifications = await _orderRepository.getNotificationsForCurrentUser(
        currentUser,
      );
      pickupOrders = await _orderRepository.getTodayPickupOrders();
      dailyCashClosure = AccessControl.canViewMyCashClosure(currentUser)
          ? await _paymentRepository.getMyDailyCashClosure(currentUser)
          : null;
      cashierClosures = AccessControl.canViewCashierClosures(currentUser)
          ? await _paymentRepository.getSubmittedCashClosures(currentUser)
          : [];
      await _loadAccountingListsIfAllowed();

      appState = departments.isEmpty && orders.isEmpty
          ? const ViewState.empty('لا توجد بيانات حالياً')
          : const ViewState.success(null);
    } on AppException catch (error) {
      appState = ViewState.error(error.message);
    } catch (error) {
      appState = const ViewState.error('تعذر تحميل بيانات التطبيق');
    }

    notifyListeners();
  }

  num methodTotal(PaymentMethod method) {
    return dailyCashClosure?.methodTotal(method) ?? 0;
  }

  List<Product> productsForDepartment(ProductDepartment department) {
    return products
        .where((item) => item.departmentId == department.id)
        .toList();
  }

  List<Product> currentDepartmentProducts({String query = ''}) {
    final department = selectedDepartment;
    if (department == null) return [];

    final normalized = query.trim();
    return productsForDepartment(department).where((product) {
      if (normalized.isEmpty) return true;
      return product.name.contains(normalized) ||
          product.description.contains(normalized);
    }).toList();
  }

  Product? productById(int id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  int quantityFor(Product product) => draft.quantityFor(product);

  num get cartTotal => draft.totalAmount(products);

  int get cartCount => draft.itemsCount;

  num get remainingAmount =>
      (cartTotal - draft.depositAmount).clamp(0, double.infinity);

  List<MapEntry<Product, int>> get cartLines {
    final lines = <MapEntry<Product, int>>[];
    for (final entry in draft.quantities.entries) {
      final product = productById(entry.key);
      if (product != null) lines.add(MapEntry(product, entry.value));
    }
    return lines;
  }

  void selectDepartment(ProductDepartment department) {
    _selectedDepartment = department;
    notifyListeners();
  }

  void addProduct(Product product) {
    draft.quantities[product.id] = 1;
    notifyListeners();
  }

  void changeProductQuantity(Product product, int delta) {
    final nextQuantity = (draft.quantities[product.id] ?? 0) + delta;
    if (nextQuantity <= 0) {
      draft.quantities.remove(product.id);
    } else {
      draft.quantities[product.id] = nextQuantity;
    }
    notifyListeners();
  }

  void updateCustomer({String? phone, String? name, bool? isCompany}) {
    draft.customerPhone = phone ?? draft.customerPhone;
    draft.customerName = name ?? draft.customerName;
    draft.isCompany = isCompany ?? draft.isCompany;
    notifyListeners();
  }

  Future<Customer?> searchCustomerByPhone(String phone) async {
    try {
      return _customerRepository.searchCustomerByPhone(phone);
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
      notifyListeners();
      return null;
    }
  }

  void updatePickup({DateTime? date, TimeOfDay? time, String? notes}) {
    draft.pickupDate = date ?? draft.pickupDate;
    draft.pickupTime = time ?? draft.pickupTime;
    draft.notes = notes ?? draft.notes;
    notifyListeners();
  }

  void updateDeposit(String value) {
    final sanitized = value.replaceAll(',', '').trim();
    draft.depositAmount = num.tryParse(sanitized) ?? 0;
    notifyListeners();
  }

  void updatePaymentMethod(PaymentMethod method) {
    draft.paymentMethod = method;
    notifyListeners();
  }

  Future<Order?> submitDraft() async {
    actionState = const ViewState.loading();
    notifyListeners();

    try {
      final depositAmount = draft.depositAmount;
      final paymentMethod = draft.paymentMethod;
      final order = await _orderRepository.createOrder(draft, products);
      final approvedOrder = await _orderRepository.submitOrderForApproval(
        order.id,
      );

      if (depositAmount > 0) {
        await _paymentRepository.recordDeposit(
          orderId: approvedOrder.id,
          customer: approvedOrder.customer,
          amount: depositAmount,
          method: paymentMethod,
        );
      }

      orders = _visibleOrders(await _orderRepository.getOrders());
      dailyCashClosure = AccessControl.canViewMyCashClosure(currentUser)
          ? await _paymentRepository.getMyDailyCashClosure(currentUser)
          : null;
      draft.reset();
      actionState = const ViewState.success(null);
      notifyListeners();
      return approvedOrder;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر إرسال الطلب للموافقة');
    }

    notifyListeners();
    return null;
  }

  Future<bool> saveDraft() async {
    actionState = const ViewState.loading();
    notifyListeners();

    try {
      await _orderRepository.saveOrderAsDraft(draft);
      actionState = const ViewState.success(null);
      notifyListeners();
      return true;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر حفظ الطلب كمسودة');
    }

    notifyListeners();
    return false;
  }

  Future<void> markNotificationRead(int id) async {
    try {
      await _orderRepository.markNotificationAsRead(id);
      notifications = await _orderRepository.getNotificationsForCurrentUser(
        currentUser,
      );
      notifyListeners();
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _orderRepository.markAllNotificationsRead();
      notifications = await _orderRepository.getNotificationsForCurrentUser(
        currentUser,
      );
      notifyListeners();
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
      notifyListeners();
    }
  }

  Future<void> loadSupervisorApprovals() async {
    if (!AccessControl.canApproveOrders(currentUser)) {
      supervisorApprovals = [];
      notifyListeners();
      return;
    }

    actionState = const ViewState.loading();
    notifyListeners();

    try {
      supervisorApprovals = await _orderRepository
          .getPendingSupervisorApprovals(currentUser);
      actionState = const ViewState.success(null);
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تحميل موافقات الفرع');
    }

    notifyListeners();
  }

  Future<void> loadDistributionOrders() async {
    if (!AccessControl.canViewDistribution(currentUser)) {
      distributionOrders = [];
      notifyListeners();
      return;
    }

    actionState = const ViewState.loading();
    notifyListeners();

    try {
      distributionOrders = await _orderRepository.getDistributionOrders(
        currentUser,
      );
      productionDepartments = await _orderRepository.getProductionDepartments();
      actionState = const ViewState.success(null);
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تحميل طلبات التوزيع');
    }

    notifyListeners();
  }

  Future<void> loadProductionOrders() async {
    if (!AccessControl.canViewProductionOrders(currentUser)) {
      productionOrders = [];
      notifyListeners();
      return;
    }

    actionState = const ViewState.loading();
    notifyListeners();

    try {
      productionOrders = await _orderRepository.getProductionOrders(
        currentUser,
      );
      actionState = const ViewState.success(null);
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تحميل طلبات الإنتاج');
    }

    notifyListeners();
  }

  Future<void> loadPickupOrders() async {
    if (!AccessControl.canViewPickupOrders(currentUser)) {
      branchPickupOrders = [];
      notifyListeners();
      return;
    }

    actionState = const ViewState.loading();
    notifyListeners();

    try {
      branchPickupOrders = await _orderRepository.getPickupOrders(currentUser);
      actionState = const ViewState.success(null);
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تحميل طلبات الاستلام');
    }

    notifyListeners();
  }

  Future<void> loadDriverOrders() async {
    if (!AccessControl.canViewDriverOrders(currentUser)) {
      driverOrders = [];
      notifyListeners();
      return;
    }

    actionState = const ViewState.loading();
    notifyListeners();

    try {
      driverOrders = await _orderRepository.getDriverOrders(currentUser);
      actionState = const ViewState.success(null);
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تحميل طلبات السائق');
    }

    notifyListeners();
  }

  Future<ProductionDepartment?> getDefaultDepartmentForOrder(Order order) {
    return _orderRepository.getDefaultDepartmentForOrder(order);
  }

  Future<Order?> assignProductionDepartment({
    required String orderId,
    required String productionDepartmentId,
  }) async {
    actionState = const ViewState.loading();
    notifyListeners();

    try {
      final updatedOrder = await _orderRepository.assignProductionDepartment(
        orderId: orderId,
        productionDepartmentId: productionDepartmentId,
        changedBy: currentUser,
      );
      await _refreshOperationalLists();
      actionState = const ViewState.success(null);
      notifyListeners();
      return updatedOrder;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تحويل الطلب للتنفيذ');
    }

    notifyListeners();
    return null;
  }

  Future<Order?> updateProductionStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    actionState = const ViewState.loading();
    notifyListeners();

    try {
      final updatedOrder = await _orderRepository.updateProductionStatus(
        orderId: orderId,
        status: status,
        changedBy: currentUser,
      );
      await _refreshOperationalLists();
      actionState = const ViewState.success(null);
      notifyListeners();
      return updatedOrder;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تحديث حالة الإنتاج');
    }

    notifyListeners();
    return null;
  }

  Future<Order?> collectRemainingPayment({
    required String orderId,
    required num amount,
    required PaymentMethod method,
    String transactionReference = '',
    String receiptPath = '',
  }) async {
    return _runOrderAction(
      () => _orderRepository.collectRemainingPayment(
        orderId: orderId,
        amount: amount,
        method: method,
        collectedBy: currentUser,
        transactionReference: transactionReference,
        receiptPath: receiptPath,
      ),
      fallbackError: 'تعذر تسجيل دفعة المتبقي',
    );
  }

  Future<Order?> markPickupOrderDelivered(String orderId) async {
    return _runOrderAction(
      () => _orderRepository.markPickupOrderDelivered(
        orderId: orderId,
        changedBy: currentUser,
      ),
      fallbackError: 'تعذر تسليم الطلب',
    );
  }

  Future<List<DriverProfile>> getAvailableDrivers({String? branchId}) {
    return _orderRepository.getAvailableDrivers(
      currentUser,
      branchId: branchId,
    );
  }

  Future<Order?> assignDriverToOrder({
    required String orderId,
    required String driverId,
  }) async {
    return _runOrderAction(
      () => _orderRepository.assignDriverToOrder(
        orderId: orderId,
        driverId: driverId,
        changedBy: currentUser,
      ),
      fallbackError: 'تعذر إسناد الطلب للسائق',
    );
  }

  Future<Order?> updateDeliveryStatus({
    required String orderId,
    required OrderStatus status,
    String proofImagePath = '',
    String driverNotes = '',
  }) async {
    return _runOrderAction(
      () => _orderRepository.updateDeliveryStatus(
        orderId: orderId,
        status: status,
        changedBy: currentUser,
        proofImagePath: proofImagePath,
        driverNotes: driverNotes,
      ),
      fallbackError: 'تعذر تحديث حالة التوصيل',
    );
  }

  Future<Order?> markDeliveryFailed({
    required String orderId,
    required String reason,
  }) async {
    return _runOrderAction(
      () => _orderRepository.markDeliveryFailed(
        orderId: orderId,
        changedBy: currentUser,
        reason: reason,
      ),
      fallbackError: 'تعذر تسجيل تعذر التسليم',
    );
  }

  Future<OrderPayment?> collectDeliveryPayment({
    required String orderId,
    required num amount,
    required PaymentMethod method,
    String transactionReference = '',
    String receiptPath = '',
  }) async {
    actionState = const ViewState.loading();
    notifyListeners();

    try {
      final payment = await _orderRepository.collectDeliveryPayment(
        orderId: orderId,
        amount: amount,
        method: method,
        collectedBy: currentUser,
        transactionReference: transactionReference,
        receiptPath: receiptPath,
      );
      await _refreshOperationalLists();
      actionState = const ViewState.success(null);
      notifyListeners();
      return payment;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تسجيل دفعة التوصيل');
    }

    notifyListeners();
    return null;
  }

  Future<DeliveryAssignment?> getDeliveryAssignment(String orderId) {
    return _orderRepository.getDeliveryAssignment(orderId);
  }

  Future<void> loadMyCashClosure() async {
    if (!AccessControl.canViewMyCashClosure(currentUser)) {
      dailyCashClosure = null;
      notifyListeners();
      return;
    }

    actionState = const ViewState.loading();
    notifyListeners();

    try {
      dailyCashClosure = await _paymentRepository.getMyDailyCashClosure(
        currentUser,
      );
      actionState = const ViewState.success(null);
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تحديث العهدة اليومية');
    }

    notifyListeners();
  }

  Future<void> loadCashierClosures() async {
    if (!AccessControl.canViewCashierClosures(currentUser)) {
      cashierClosures = [];
      notifyListeners();
      return;
    }

    actionState = const ViewState.loading();
    notifyListeners();

    try {
      cashierClosures = await _paymentRepository.getSubmittedCashClosures(
        currentUser,
      );
      actionState = const ViewState.success(null);
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تحميل عهد أمين الصندوق');
    }

    notifyListeners();
  }

  Future<DailyCashClosure?> acceptCashClosure({
    required String closureId,
    required num actualCash,
    required num actualCard,
    required num actualTransfer,
    num actualOther = 0,
    String cashierNotes = '',
    String differenceReason = '',
  }) async {
    return _runCashClosureAction(
      () => _paymentRepository.acceptCashClosure(
        closureId: closureId,
        cashier: currentUser,
        actualCash: actualCash,
        actualCard: actualCard,
        actualTransfer: actualTransfer,
        actualOther: actualOther,
        cashierNotes: cashierNotes,
        differenceReason: differenceReason,
      ),
      fallbackError: 'تعذر قبول العهدة',
    );
  }

  Future<DailyCashClosure?> returnCashClosure({
    required String closureId,
    required String reason,
  }) async {
    return _runCashClosureAction(
      () => _paymentRepository.returnCashClosure(
        closureId: closureId,
        cashier: currentUser,
        reason: reason,
      ),
      fallbackError: 'تعذر إرجاع العهدة',
    );
  }

  Future<DailyCashClosure?> closeCashClosure(String closureId) async {
    return _runCashClosureAction(
      () => _paymentRepository.closeCashClosure(
        closureId: closureId,
        closedBy: currentUser,
      ),
      fallbackError: 'تعذر إغلاق العهدة',
    );
  }

  Future<List<CashClosureLog>> getCashClosureLogs(String closureId) {
    return _paymentRepository.getCashClosureLogs(closureId);
  }

  Future<void> loadAccountingLists() async {
    if (!AccessControl.canManageAccounting(currentUser)) {
      _clearAccountingLists();
      notifyListeners();
      return;
    }

    actionState = const ViewState.loading();
    notifyListeners();

    try {
      await _loadAccountingListsIfAllowed();
      actionState = const ViewState.success(null);
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر تحميل البيانات المحاسبية');
    }

    notifyListeners();
  }

  Future<Order?> createSalesOrderForOrder(String orderId) async {
    return _runAccountingOrderAction(
      () => _accountingRepository.createSalesOrderForOrder(
        orderId: orderId,
        changedBy: currentUser,
      ),
      fallbackError: 'تعذر إنشاء Sales Order',
    );
  }

  Future<Order?> createWorkOrderForOrder(String orderId) async {
    return _runAccountingOrderAction(
      () => _accountingRepository.createWorkOrderForOrder(
        orderId: orderId,
        changedBy: currentUser,
      ),
      fallbackError: 'تعذر إنشاء Work Order',
    );
  }

  Future<OrderPayment?> createPaymentEntryForPayment(String paymentId) async {
    actionState = const ViewState.loading();
    notifyListeners();

    try {
      final payment = await _accountingRepository.createPaymentEntryForPayment(
        paymentId: paymentId,
        changedBy: currentUser,
      );
      await _refreshOperationalLists();
      actionState = const ViewState.success(null);
      notifyListeners();
      return payment;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر ترحيل الدفعة');
    }

    notifyListeners();
    return null;
  }

  Future<Order?> createSalesInvoiceForOrder(String orderId) async {
    return _runAccountingOrderAction(
      () => _accountingRepository.createSalesInvoiceForOrder(
        orderId: orderId,
        changedBy: currentUser,
      ),
      fallbackError: 'تعذر إنشاء الفاتورة',
    );
  }

  Future<List<PaymentAllocation>?> allocateAdvancePaymentToInvoice(
    String orderId,
  ) async {
    actionState = const ViewState.loading();
    notifyListeners();

    try {
      final allocations = await _accountingRepository
          .allocateAdvancePaymentToInvoice(
            orderId: orderId,
            changedBy: currentUser,
          );
      await _refreshOperationalLists();
      actionState = const ViewState.success(null);
      notifyListeners();
      return allocations;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر ربط العربون بالفاتورة');
    }

    notifyListeners();
    return null;
  }

  Future<Order?> approveOrder(String orderId) async {
    return _changeSupervisorOrder(
      () => _orderRepository.approveOrder(
        orderId: orderId,
        changedBy: currentUser,
      ),
    );
  }

  Future<Order?> rejectOrder(String orderId, String reason) async {
    return _changeSupervisorOrder(
      () => _orderRepository.rejectOrder(
        orderId: orderId,
        changedBy: currentUser,
        reason: reason,
      ),
    );
  }

  Future<Order?> returnOrderForEdit(String orderId, String notes) async {
    return _changeSupervisorOrder(
      () => _orderRepository.returnOrderForEdit(
        orderId: orderId,
        changedBy: currentUser,
        notes: notes,
      ),
    );
  }

  Future<List<OrderStatusLog>> getOrderStatusLogs(String orderId) {
    return _orderRepository.getOrderStatusLogs(orderId);
  }

  Future<Order?> _changeSupervisorOrder(Future<Order> Function() action) async {
    return _runOrderAction(action, fallbackError: 'تعذر تحديث حالة الطلب');
  }

  Future<Order?> _runOrderAction(
    Future<Order> Function() action, {
    required String fallbackError,
  }) async {
    actionState = const ViewState.loading();
    notifyListeners();

    try {
      final updatedOrder = await action();
      await _refreshOperationalLists();
      actionState = const ViewState.success(null);
      notifyListeners();
      return updatedOrder;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = ViewState.error(fallbackError);
    }

    notifyListeners();
    return null;
  }

  Future<DailyCashClosure?> _runCashClosureAction(
    Future<DailyCashClosure> Function() action, {
    required String fallbackError,
  }) async {
    actionState = const ViewState.loading();
    notifyListeners();

    try {
      final closure = await action();
      await _refreshOperationalLists();
      actionState = const ViewState.success(null);
      notifyListeners();
      return closure;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = ViewState.error(fallbackError);
    }

    notifyListeners();
    return null;
  }

  Future<Order?> _runAccountingOrderAction(
    Future<Order> Function() action, {
    required String fallbackError,
  }) async {
    actionState = const ViewState.loading();
    notifyListeners();

    try {
      final order = await action();
      await _refreshOperationalLists();
      actionState = const ViewState.success(null);
      notifyListeners();
      return order;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = ViewState.error(fallbackError);
    }

    notifyListeners();
    return null;
  }

  Future<void> collectPickupPayment(int id, num amount) async {
    try {
      await _orderRepository.collectPickupPayment(id, amount);
      pickupOrders = await _orderRepository.getTodayPickupOrders();
      notifyListeners();
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
      notifyListeners();
    }
  }

  Future<bool> deliverPickupOrder(int id) async {
    try {
      final updatedOrder = await _orderRepository.deliverPickupOrder(id);
      pickupOrders = await _orderRepository.getTodayPickupOrders();
      notifyListeners();
      return updatedOrder?.delivered ?? false;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitDailyCashClosure() async {
    final closure = dailyCashClosure;
    if (closure == null) return false;

    actionState = const ViewState.loading();
    notifyListeners();

    try {
      dailyCashClosure = await _paymentRepository.submitCashClosure(
        closureId: closure.id,
        submittedBy: currentUser,
      );
      await _refreshOperationalLists();
      actionState = const ViewState.success(null);
      notifyListeners();
      return true;
    } on AppException catch (error) {
      actionState = ViewState.error(error.message);
    } catch (error) {
      actionState = const ViewState.error('تعذر إرسال العهدة اليومية');
    }

    notifyListeners();
    return false;
  }

  List<Order> _visibleOrders(List<Order> allOrders) {
    if (currentUser.role == UserRole.systemAdmin) return allOrders;
    if (currentUser.role == UserRole.branchEmployee) {
      return allOrders
          .where((order) => order.createdByUserId == currentUser.id)
          .toList();
    }
    if (currentUser.role == UserRole.branchSupervisor) {
      return allOrders
          .where(
            (order) =>
                order.createdBranchId == currentUser.branchId ||
                order.pickupBranchId == currentUser.branchId,
          )
          .toList();
    }
    if (currentUser.role == UserRole.distributionManager) {
      const distributionStatuses = {
        OrderStatus.sentToDistribution,
        OrderStatus.readyForDelivery,
        OrderStatus.assignedToDriver,
        OrderStatus.driverPickedUp,
        OrderStatus.outForDelivery,
        OrderStatus.deliveryFailed,
      };
      return allOrders
          .where((order) => distributionStatuses.contains(order.status))
          .toList();
    }
    if (currentUser.role == UserRole.driver) {
      return driverOrders;
    }
    return allOrders;
  }

  Future<void> _refreshOperationalLists() async {
    driverOrders = AccessControl.canViewDriverOrders(currentUser)
        ? await _orderRepository.getDriverOrders(currentUser)
        : [];
    orders = _visibleOrders(await _orderRepository.getOrders());
    supervisorApprovals = AccessControl.canApproveOrders(currentUser)
        ? await _orderRepository.getPendingSupervisorApprovals(currentUser)
        : [];
    distributionOrders = AccessControl.canViewDistribution(currentUser)
        ? await _orderRepository.getDistributionOrders(currentUser)
        : [];
    productionOrders = AccessControl.canViewProductionOrders(currentUser)
        ? await _orderRepository.getProductionOrders(currentUser)
        : [];
    branchPickupOrders = AccessControl.canViewPickupOrders(currentUser)
        ? await _orderRepository.getPickupOrders(currentUser)
        : [];
    notifications = await _orderRepository.getNotificationsForCurrentUser(
      currentUser,
    );
    dailyCashClosure = AccessControl.canViewMyCashClosure(currentUser)
        ? await _paymentRepository.getMyDailyCashClosure(currentUser)
        : null;
    cashierClosures = AccessControl.canViewCashierClosures(currentUser)
        ? await _paymentRepository.getSubmittedCashClosures(currentUser)
        : [];
    await _loadAccountingListsIfAllowed();
  }

  Future<void> _loadAccountingListsIfAllowed() async {
    if (!AccessControl.canManageAccounting(currentUser)) {
      _clearAccountingLists();
      return;
    }
    ordersNeedingSalesOrder = await _accountingRepository
        .getOrdersNeedingSalesOrder();
    paymentsReadyForErpPosting = await _accountingRepository
        .getPaymentsReadyForErpPosting();
    ordersNeedingSalesInvoice = await _accountingRepository
        .getOrdersNeedingSalesInvoice();
    invoicesNeedingAdvanceAllocation = await _accountingRepository
        .getInvoicesNeedingAdvanceAllocation();
    accountingSyncErrors = await _accountingRepository
        .getAccountingSyncErrors();
  }

  void _clearAccountingLists() {
    ordersNeedingSalesOrder = [];
    paymentsReadyForErpPosting = [];
    ordersNeedingSalesInvoice = [];
    invoicesNeedingAdvanceAllocation = [];
    accountingSyncErrors = [];
  }
}
