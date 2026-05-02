import '../core/constants/environment.dart';
import '../core/errors/app_exception.dart';
import '../models/app_models.dart';
import '../services/erpnext_service.dart';
import '../services/mock_service.dart';

class PaymentRepository {
  PaymentRepository({
    MockService? mockService,
    ErpnextService? erpnextService,
    bool useMockData = AppEnvironment.useMockData,
  }) : _mockService = mockService ?? MockService(),
       _erpnextService = erpnextService ?? const ErpnextService(),
       _useMockData = useMockData;

  final MockService _mockService;
  final ErpnextService _erpnextService;
  final bool _useMockData;

  Future<void> recordDeposit({
    required String orderId,
    required String customer,
    required num amount,
    required PaymentMethod method,
  }) async {
    try {
      return _useMockData
          ? _mockService.recordDeposit(
              orderId: orderId,
              customer: customer,
              amount: amount,
              method: method,
            )
          : _erpnextService.recordDeposit(
              orderId: orderId,
              customer: customer,
              amount: amount,
              method: method,
            );
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تسجيل العربون',
        code: 'deposit_record_failed',
        cause: error,
      );
    }
  }

  Future<DailyCashClosure> getDailyCashClosure() async {
    try {
      return _useMockData
          ? _mockService.getDailyCashClosure()
          : _erpnextService.getDailyCashClosure();
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل العهدة اليومية',
        code: 'daily_cash_load_failed',
        cause: error,
      );
    }
  }

  Future<void> submitDailyCashClosure(DailyCashClosure closure) async {
    try {
      return _useMockData
          ? _mockService.submitDailyCashClosure(closure)
          : _erpnextService.submitDailyCashClosure(closure);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر إرسال العهدة اليومية',
        code: 'daily_cash_submit_failed',
        cause: error,
      );
    }
  }

  Future<DailyCashClosure> getMyDailyCashClosure(AppUser user) async {
    try {
      return _useMockData
          ? _mockService.getMyDailyCashClosure(user)
          : _erpnextService.getMyDailyCashClosure(user);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل عهدتي اليومية',
        code: 'my_cash_closure_load_failed',
        cause: error,
      );
    }
  }

  Future<DailyCashClosure> getCashClosureById(String closureId) async {
    return _useMockData
        ? _mockService.getCashClosureById(closureId)
        : _erpnextService.getCashClosureById(closureId);
  }

  Future<DailyCashClosure> submitCashClosure({
    required String closureId,
    required AppUser submittedBy,
  }) async {
    return _useMockData
        ? _mockService.submitCashClosure(
            closureId: closureId,
            submittedBy: submittedBy,
          )
        : _erpnextService.submitCashClosure(
            closureId: closureId,
            submittedBy: submittedBy,
          );
  }

  Future<List<DailyCashClosure>> getSubmittedCashClosures(AppUser user) async {
    return _useMockData
        ? _mockService.getSubmittedCashClosures(user)
        : _erpnextService.getSubmittedCashClosures(user);
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
    return _useMockData
        ? _mockService.acceptCashClosure(
            closureId: closureId,
            cashier: cashier,
            actualCash: actualCash,
            actualCard: actualCard,
            actualTransfer: actualTransfer,
            actualOther: actualOther,
            cashierNotes: cashierNotes,
            differenceReason: differenceReason,
          )
        : _erpnextService.acceptCashClosure(
            closureId: closureId,
            cashier: cashier,
            actualCash: actualCash,
            actualCard: actualCard,
            actualTransfer: actualTransfer,
            actualOther: actualOther,
            cashierNotes: cashierNotes,
            differenceReason: differenceReason,
          );
  }

  Future<DailyCashClosure> returnCashClosure({
    required String closureId,
    required AppUser cashier,
    required String reason,
  }) async {
    return _useMockData
        ? _mockService.returnCashClosure(
            closureId: closureId,
            cashier: cashier,
            reason: reason,
          )
        : _erpnextService.returnCashClosure(
            closureId: closureId,
            cashier: cashier,
            reason: reason,
          );
  }

  Future<DailyCashClosure> closeCashClosure({
    required String closureId,
    required AppUser closedBy,
  }) async {
    return _useMockData
        ? _mockService.closeCashClosure(
            closureId: closureId,
            closedBy: closedBy,
          )
        : _erpnextService.closeCashClosure(
            closureId: closureId,
            closedBy: closedBy,
          );
  }

  Future<List<OrderPayment>> getCashClosurePayments(String closureId) async {
    return _useMockData
        ? _mockService.getCashClosurePayments(closureId)
        : _erpnextService.getCashClosurePayments(closureId);
  }

  Future<CashClosureTotals> calculateClosureTotals(
    List<OrderPayment> payments,
  ) async {
    return _useMockData
        ? _mockService.calculateClosureTotals(payments)
        : _erpnextService.calculateClosureTotals(payments);
  }

  Future<void> markPaymentsAsSubmitted(String closureId) async {
    return _useMockData
        ? _mockService.markPaymentsAsSubmitted(closureId)
        : _erpnextService.markPaymentsAsSubmitted(closureId);
  }

  Future<void> markPaymentsAsCashierAccepted(String closureId) async {
    return _useMockData
        ? _mockService.markPaymentsAsCashierAccepted(closureId)
        : _erpnextService.markPaymentsAsCashierAccepted(closureId);
  }

  Future<List<CashClosureLog>> getCashClosureLogs(String closureId) async {
    return _useMockData
        ? _mockService.getCashClosureLogs(closureId)
        : _erpnextService.getCashClosureLogs(closureId);
  }
}
