import '../core/constants/environment.dart';
import '../core/errors/app_exception.dart';
import '../models/app_models.dart';
import '../services/erpnext_service.dart';
import '../services/mock_service.dart';

class AccountingRepository {
  AccountingRepository({
    MockService? mockService,
    ErpnextService? erpnextService,
    bool useMockData = AppEnvironment.useMockData,
  }) : _mockService = mockService ?? MockService(),
       _erpnextService = erpnextService ?? ErpnextService(),
       _useMockData = useMockData;

  final MockService _mockService;
  final ErpnextService _erpnextService;
  final bool _useMockData;

  Future<Order> createSalesOrderForOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    try {
      return _useMockData
          ? _mockService.createSalesOrderForOrder(
              orderId: orderId,
              changedBy: changedBy,
            )
          : _erpnextService.createSalesOrderForOrder(
              orderId: orderId,
              changedBy: changedBy,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر إنشاء Sales Order',
        code: 'sales_order_create_failed',
        cause: error,
      );
    }
  }

  Future<Order> createWorkOrderForOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    try {
      return _useMockData
          ? _mockService.createWorkOrderForOrder(
              orderId: orderId,
              changedBy: changedBy,
            )
          : _erpnextService.createWorkOrderForOrder(
              orderId: orderId,
              changedBy: changedBy,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر إنشاء Work Order',
        code: 'work_order_create_failed',
        cause: error,
      );
    }
  }

  Future<List<OrderPayment>> postAcceptedPaymentsToErpnext({
    required String closureId,
    required AppUser changedBy,
  }) async {
    return _useMockData
        ? _mockService.postAcceptedPaymentsToErpnext(
            closureId: closureId,
            changedBy: changedBy,
          )
        : _erpnextService.postAcceptedPaymentsToErpnext(
            closureId: closureId,
            changedBy: changedBy,
          );
  }

  Future<OrderPayment> createPaymentEntryForPayment({
    required String paymentId,
    required AppUser changedBy,
  }) async {
    return _useMockData
        ? _mockService.createPaymentEntryForPayment(
            paymentId: paymentId,
            changedBy: changedBy,
          )
        : _erpnextService.createPaymentEntryForPayment(
            paymentId: paymentId,
            changedBy: changedBy,
          );
  }

  Future<Order> createSalesInvoiceForOrder({
    required String orderId,
    required AppUser changedBy,
  }) async {
    return _useMockData
        ? _mockService.createSalesInvoiceForOrder(
            orderId: orderId,
            changedBy: changedBy,
          )
        : _erpnextService.createSalesInvoiceForOrder(
            orderId: orderId,
            changedBy: changedBy,
          );
  }

  Future<List<PaymentAllocation>> allocateAdvancePaymentToInvoice({
    required String orderId,
    required AppUser changedBy,
  }) async {
    return _useMockData
        ? _mockService.allocateAdvancePaymentToInvoice(
            orderId: orderId,
            changedBy: changedBy,
          )
        : _erpnextService.allocateAdvancePaymentToInvoice(
            orderId: orderId,
            changedBy: changedBy,
          );
  }

  Future<List<Order>> getCustomerInvoices(String customerId) async {
    return _useMockData
        ? _mockService.getCustomerInvoices(customerId)
        : _erpnextService.getCustomerInvoices(customerId);
  }

  Future<Order> syncOrderAccountingStatus({
    required String orderId,
    required AppUser changedBy,
  }) async {
    return _useMockData
        ? _mockService.syncOrderAccountingStatus(
            orderId: orderId,
            changedBy: changedBy,
          )
        : _erpnextService.syncOrderAccountingStatus(
            orderId: orderId,
            changedBy: changedBy,
          );
  }

  Future<List<Order>> getOrdersNeedingSalesOrder() async {
    return _useMockData
        ? _mockService.getOrdersNeedingSalesOrder()
        : _erpnextService.getOrdersNeedingSalesOrder();
  }

  Future<List<OrderPayment>> getPaymentsReadyForErpPosting() async {
    return _useMockData
        ? _mockService.getPaymentsReadyForErpPosting()
        : _erpnextService.getPaymentsReadyForErpPosting();
  }

  Future<List<Order>> getOrdersNeedingSalesInvoice() async {
    return _useMockData
        ? _mockService.getOrdersNeedingSalesInvoice()
        : _erpnextService.getOrdersNeedingSalesInvoice();
  }

  Future<List<Order>> getInvoicesNeedingAdvanceAllocation() async {
    return _useMockData
        ? _mockService.getInvoicesNeedingAdvanceAllocation()
        : _erpnextService.getInvoicesNeedingAdvanceAllocation();
  }

  Future<List<Order>> getAccountingSyncErrors() async {
    return _useMockData
        ? _mockService.getAccountingSyncErrors()
        : _erpnextService.getAccountingSyncErrors();
  }
}
