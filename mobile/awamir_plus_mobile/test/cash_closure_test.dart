import 'package:awamir_plus_mobile/core/errors/app_exception.dart';
import 'package:awamir_plus_mobile/models/app_models.dart';
import 'package:awamir_plus_mobile/repositories/order_repository.dart';
import 'package:awamir_plus_mobile/repositories/payment_repository.dart';
import 'package:awamir_plus_mobile/services/mock_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('موظف الفرع يرى عهدته فقط', () async {
    final fixture = _fixture();

    final closure = await fixture.payments.getMyDailyCashClosure(_employee);

    expect(closure.ownerUserId, _employee.id);
    expect(closure.type, CashClosureOwnerType.employee);
    expect(
      closure.payments.every(
        (payment) => payment.collectedByUserId == _employee.id,
      ),
      isTrue,
    );
  });

  test('السائق يرى عهدته فقط', () async {
    final fixture = _fixture();
    await _collectDriverPayment(fixture);

    final closure = await fixture.payments.getMyDailyCashClosure(_driver);

    expect(closure.ownerUserId, _driver.id);
    expect(closure.type, CashClosureOwnerType.driver);
    expect(closure.payments, isNotEmpty);
    expect(
      closure.payments.every(
        (payment) => payment.collectorType == CashClosureOwnerType.driver,
      ),
      isTrue,
    );
  });

  test('أمين الصندوق يرى العهد المرسلة فقط', () async {
    final fixture = _fixture();
    final openClosure = await fixture.payments.getMyDailyCashClosure(_employee);

    var cashierClosures = await fixture.payments.getSubmittedCashClosures(
      _cashier,
    );
    expect(cashierClosures, isEmpty);

    await fixture.payments.submitCashClosure(
      closureId: openClosure.id,
      submittedBy: _employee,
    );
    cashierClosures = await fixture.payments.getSubmittedCashClosures(_cashier);

    expect(
      cashierClosures.map((closure) => closure.id),
      contains(openClosure.id),
    );
    expect(
      cashierClosures.every(
        (closure) => closure.status == CashClosureStatus.submittedToCashier,
      ),
      isTrue,
    );
  });

  test('إرسال العهدة يغير الحالة إلى Submitted To Cashier', () async {
    final fixture = _fixture();
    final closure = await fixture.payments.getMyDailyCashClosure(_employee);

    final submitted = await fixture.payments.submitCashClosure(
      closureId: closure.id,
      submittedBy: _employee,
    );

    expect(submitted.status, CashClosureStatus.submittedToCashier);
  });

  test('بعد إرسال العهدة لا يمكن تعديل الدفعات المرتبطة', () async {
    final fixture = _fixture();
    final closure = await fixture.payments.getMyDailyCashClosure(_employee);

    await fixture.payments.submitCashClosure(
      closureId: closure.id,
      submittedBy: _employee,
    );
    final payments = await fixture.payments.getCashClosurePayments(closure.id);

    expect(payments, isNotEmpty);
    expect(payments.every((payment) => payment.canEdit == false), isTrue);
    expect(
      payments.every(
        (payment) => payment.status == OrderPaymentStatus.submittedToCashier,
      ),
      isTrue,
    );
  });

  test('قبول العهدة يغير حالة الدفعات إلى Cashier Accepted', () async {
    final fixture = _fixture();
    final closure = await _submittedEmployeeClosure(fixture);

    final accepted = await fixture.payments.acceptCashClosure(
      closureId: closure.id,
      cashier: _cashier,
      actualCash: closure.methodTotal(PaymentMethod.cash),
      actualCard: closure.methodTotal(PaymentMethod.card),
      actualTransfer: closure.methodTotal(PaymentMethod.transfer),
      actualOther: closure.methodTotal(PaymentMethod.other),
    );
    final payments = await fixture.payments.getCashClosurePayments(closure.id);

    expect(accepted.status, CashClosureStatus.accepted);
    expect(
      payments.every(
        (payment) => payment.status == OrderPaymentStatus.cashierAccepted,
      ),
      isTrue,
    );
  });

  test('إرجاع العهدة يتطلب سبب', () async {
    final fixture = _fixture();
    final closure = await _submittedEmployeeClosure(fixture);

    expect(
      () => fixture.payments.returnCashClosure(
        closureId: closure.id,
        cashier: _cashier,
        reason: '',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'cash_closure_return_reason_required',
        ),
      ),
    );
  });

  test('قبول عهدة بفرق يحفظ differenceAmount', () async {
    final fixture = _fixture();
    final closure = await _submittedEmployeeClosure(fixture);

    final accepted = await fixture.payments.acceptCashClosure(
      closureId: closure.id,
      cashier: _cashier,
      actualCash: closure.methodTotal(PaymentMethod.cash) + 10,
      actualCard: closure.methodTotal(PaymentMethod.card),
      actualTransfer: closure.methodTotal(PaymentMethod.transfer),
      actualOther: closure.methodTotal(PaymentMethod.other),
      differenceReason: 'زيادة نقدية عند العد',
    );

    expect(accepted.status, CashClosureStatus.hasDifference);
    expect(accepted.differenceAmount, 10);
    expect(accepted.differenceReason, 'زيادة نقدية عند العد');
  });

  test('كل إجراء ينشئ Notification', () async {
    final fixture = _fixture();
    final closure = await _submittedEmployeeClosure(fixture);

    final cashierNotifications = await fixture.orders
        .getNotificationsForCurrentUser(_cashier);
    await fixture.payments.acceptCashClosure(
      closureId: closure.id,
      cashier: _cashier,
      actualCash: closure.methodTotal(PaymentMethod.cash),
      actualCard: closure.methodTotal(PaymentMethod.card),
      actualTransfer: closure.methodTotal(PaymentMethod.transfer),
      actualOther: closure.methodTotal(PaymentMethod.other),
    );
    final employeeNotifications = await fixture.orders
        .getNotificationsForCurrentUser(_employee);

    expect(
      cashierNotifications,
      contains(
        isA<AppNotification>().having(
          (notification) => notification.type,
          'type',
          NotificationType.cashClosureSubmitted,
        ),
      ),
    );
    expect(
      employeeNotifications,
      contains(
        isA<AppNotification>().having(
          (notification) => notification.type,
          'type',
          NotificationType.cashClosureAccepted,
        ),
      ),
    );
  });

  test('كل إجراء ينشئ Closure Log', () async {
    final fixture = _fixture();
    final closure = await fixture.payments.getMyDailyCashClosure(_employee);
    final before = await fixture.payments.getCashClosureLogs(closure.id);

    await fixture.payments.submitCashClosure(
      closureId: closure.id,
      submittedBy: _employee,
    );
    final after = await fixture.payments.getCashClosureLogs(closure.id);

    expect(after.length, before.length + 1);
    expect(after.last.newStatus, CashClosureStatus.submittedToCashier);
  });

  test('لا يمكن ترحيل دفعة إلى ERPNext قبل قبول العهدة', () async {
    final fixture = _fixture();
    final closure = await _submittedEmployeeClosure(fixture);
    final payments = await fixture.payments.getCashClosurePayments(closure.id);

    expect(
      payments.every((payment) => payment.canPostToErpNext == false),
      isTrue,
    );
    expect(
      () => fixture.payments.closeCashClosure(
        closureId: closure.id,
        closedBy: _cashier,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'cash_closure_not_accepted_for_close',
        ),
      ),
    );
  });
}

Future<DailyCashClosure> _submittedEmployeeClosure(_Fixture fixture) async {
  final closure = await fixture.payments.getMyDailyCashClosure(_employee);
  return fixture.payments.submitCashClosure(
    closureId: closure.id,
    submittedBy: _employee,
  );
}

Future<void> _collectDriverPayment(_Fixture fixture) async {
  await fixture.orders.assignDriverToOrder(
    orderId: 'ORD-0022',
    driverId: 'DRV-001',
    changedBy: _distribution,
  );
  await fixture.orders.collectDeliveryPayment(
    orderId: 'ORD-0022',
    amount: 50,
    method: PaymentMethod.cash,
    collectedBy: _driver,
  );
}

_Fixture _fixture() {
  final mock = MockService();
  return _Fixture(
    payments: PaymentRepository(mockService: mock, useMockData: true),
    orders: OrderRepository(mockService: mock, useMockData: true),
  );
}

class _Fixture {
  const _Fixture({required this.payments, required this.orders});

  final PaymentRepository payments;
  final OrderRepository orders;
}

const _employee = AppUser(
  id: 'EMP-0001',
  fullName: 'أحمد الراجحي',
  email: 'employee@awamir.local',
  phone: '0501111111',
  role: UserRole.branchEmployee,
  branchId: 'BR-RUH-MUR',
  branchName: 'فرع الرياض — المروج',
  isActive: true,
);

const _driver = AppUser(
  id: 'EMP-0005',
  fullName: 'عبدالله الدوسري',
  email: 'driver@awamir.local',
  phone: '0505555555',
  role: UserRole.driver,
  branchId: 'DIST-RUH',
  branchName: 'مركز توزيع الرياض',
  isActive: true,
);

const _distribution = AppUser(
  id: 'EMP-0003',
  fullName: 'ماجد الحربي',
  email: 'distribution@awamir.local',
  phone: '0503333333',
  role: UserRole.distributionManager,
  branchId: 'DIST-RUH',
  branchName: 'مركز توزيع الرياض',
  isActive: true,
);

const _cashier = AppUser(
  id: 'EMP-0006',
  fullName: 'ريم الشهري',
  email: 'cashier@awamir.local',
  phone: '0506666666',
  role: UserRole.cashier,
  branchId: 'CASH-RUH',
  branchName: 'الخزينة المركزية',
  isActive: true,
);
