import 'package:awamir_plus_mobile/core/errors/app_exception.dart';
import 'package:awamir_plus_mobile/models/app_models.dart';
import 'package:awamir_plus_mobile/repositories/accounting_repository.dart';
import 'package:awamir_plus_mobile/repositories/order_repository.dart';
import 'package:awamir_plus_mobile/repositories/payment_repository.dart';
import 'package:awamir_plus_mobile/services/mock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('لا يمكن إنشاء Sales Order لطلب Draft ويحفظ erpSyncError', () async {
    final fixture = _fixture();
    final draft = await fixture.orders.saveDraft(_draftRequest());

    await expectLater(
      fixture.accounting.createSalesOrderForOrder(
        orderId: draft.id,
        changedBy: _accountant,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'sales_order_not_allowed',
        ),
      ),
    );
    final failed = (await fixture.orders.getOrders()).firstWhere(
      (order) => order.id == draft.id,
    );

    expect(failed.erpSyncStatus, ErpSyncStatus.failed);
    expect(failed.erpSyncError, isNotEmpty);
  });

  test('لا يتم إنشاء Sales Order مرتين لنفس الطلب', () async {
    final fixture = _fixture();

    final first = await fixture.accounting.createSalesOrderForOrder(
      orderId: 'ORD-0018',
      changedBy: _accountant,
    );
    final second = await fixture.accounting.createSalesOrderForOrder(
      orderId: 'ORD-0018',
      changedBy: _accountant,
    );

    expect(first.erpnextSalesOrderId, startsWith('SO-2026-'));
    expect(second.erpnextSalesOrderId, first.erpnextSalesOrderId);
  });

  test('إنشاء Sales Order يحفظ الرقم داخل الطلب', () async {
    final fixture = _fixture();

    final updated = await fixture.accounting.createSalesOrderForOrder(
      orderId: 'ORD-0018',
      changedBy: _accountant,
    );

    expect(updated.erpnextSalesOrderId, startsWith('SO-2026-'));
    expect(updated.erpnextCustomerId, 'CUST-ORD-0018');
    expect(updated.erpSyncStatus, ErpSyncStatus.partiallySynced);
  });

  test('لا يمكن إنشاء Work Order قبل Sales Order', () async {
    final fixture = _fixture();

    await expectLater(
      fixture.accounting.createWorkOrderForOrder(
        orderId: 'ORD-0018',
        changedBy: _accountant,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'work_order_requires_sales_order',
        ),
      ),
    );
  });

  test('لا يمكن ترحيل دفعة قبل قبول العهدة', () async {
    final fixture = _fixture();
    final closure = await fixture.payments.getMyDailyCashClosure(_employee);
    final payment = closure.payments.first;

    await expectLater(
      fixture.accounting.createPaymentEntryForPayment(
        paymentId: payment.id,
        changedBy: _accountant,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'payment_not_accepted_for_posting',
        ),
      ),
    );
  });

  test('لا يتم ترحيل نفس الدفعة مرتين', () async {
    final fixture = _fixture();
    final payment = await _acceptedPaymentForOrder(fixture, 'ORD-0015');

    final first = await fixture.accounting.createPaymentEntryForPayment(
      paymentId: payment.id,
      changedBy: _accountant,
    );
    final second = await fixture.accounting.createPaymentEntryForPayment(
      paymentId: payment.id,
      changedBy: _accountant,
    );

    expect(first.erpnextPaymentEntryId, startsWith('ACC-PAY-2026-'));
    expect(second.erpnextPaymentEntryId, first.erpnextPaymentEntryId);
  });

  test('ترحيل الدفعة يغير حالتها إلى Posted To ERPNext', () async {
    final fixture = _fixture();
    final payment = await _acceptedPaymentForOrder(fixture, 'ORD-0015');

    final posted = await fixture.accounting.createPaymentEntryForPayment(
      paymentId: payment.id,
      changedBy: _accountant,
    );

    expect(posted.status, OrderPaymentStatus.postedToErpNext);
    expect(posted.postedToErpNext, isTrue);
    expect(posted.erpnextPaymentEntryId, startsWith('ACC-PAY-2026-'));
  });

  test('لا يمكن إنشاء Sales Invoice قبل Sales Order', () async {
    final fixture = _fixture();

    await expectLater(
      fixture.accounting.createSalesInvoiceForOrder(
        orderId: 'ORD-0018',
        changedBy: _accountant,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'invoice_requires_sales_order',
        ),
      ),
    );
  });

  test('لا يتم إنشاء Sales Invoice مرتين', () async {
    final fixture = _fixture();
    await fixture.accounting.createSalesOrderForOrder(
      orderId: 'ORD-0018',
      changedBy: _accountant,
    );

    final first = await fixture.accounting.createSalesInvoiceForOrder(
      orderId: 'ORD-0018',
      changedBy: _accountant,
    );
    final second = await fixture.accounting.createSalesInvoiceForOrder(
      orderId: 'ORD-0018',
      changedBy: _accountant,
    );

    expect(first.erpnextSalesInvoiceId, startsWith('ACC-SINV-2026-'));
    expect(second.erpnextSalesInvoiceId, first.erpnextSalesInvoiceId);
  });

  test('لا يمكن تخصيص عربون قبل وجود Sales Invoice', () async {
    final fixture = _fixture();

    await expectLater(
      fixture.accounting.allocateAdvancePaymentToInvoice(
        orderId: 'ORD-0015',
        changedBy: _accountant,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'allocation_requires_invoice',
        ),
      ),
    );
  });

  test('لا يمكن تخصيص دفعة غير Posted To ERPNext', () async {
    final fixture = _fixture();
    await fixture.accounting.createSalesOrderForOrder(
      orderId: 'ORD-0015',
      changedBy: _accountant,
    );
    await fixture.accounting.createSalesInvoiceForOrder(
      orderId: 'ORD-0015',
      changedBy: _accountant,
    );

    await expectLater(
      fixture.accounting.allocateAdvancePaymentToInvoice(
        orderId: 'ORD-0015',
        changedBy: _accountant,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'allocation_requires_posted_payment',
        ),
      ),
    );
  });

  test('تخصيص العربون يحدث المتبقي', () async {
    final fixture = _fixture();
    final payment = await _acceptedPaymentForOrder(fixture, 'ORD-0014');
    await fixture.accounting.createSalesOrderForOrder(
      orderId: 'ORD-0014',
      changedBy: _accountant,
    );
    await fixture.accounting.createPaymentEntryForPayment(
      paymentId: payment.id,
      changedBy: _accountant,
    );
    await fixture.accounting.createSalesInvoiceForOrder(
      orderId: 'ORD-0014',
      changedBy: _accountant,
    );

    final allocations = await fixture.accounting
        .allocateAdvancePaymentToInvoice(
          orderId: 'ORD-0014',
          changedBy: _accountant,
        );
    final order = (await fixture.orders.getOrders()).firstWhere(
      (item) => item.id == 'ORD-0014',
    );

    expect(allocations, isNotEmpty);
    expect(order.remainingAmount, 0);
    expect(order.erpSyncStatus, ErpSyncStatus.synced);
  });

  test('كل إجراء محاسبي ينشئ Notification', () async {
    final fixture = _fixture();
    final payment = await _acceptedPaymentForOrder(fixture, 'ORD-0014');

    await fixture.accounting.createSalesOrderForOrder(
      orderId: 'ORD-0014',
      changedBy: _accountant,
    );
    await fixture.accounting.createPaymentEntryForPayment(
      paymentId: payment.id,
      changedBy: _accountant,
    );
    await fixture.accounting.createSalesInvoiceForOrder(
      orderId: 'ORD-0014',
      changedBy: _accountant,
    );
    await fixture.accounting.allocateAdvancePaymentToInvoice(
      orderId: 'ORD-0014',
      changedBy: _accountant,
    );
    final notifications = await fixture.orders.getNotificationsForCurrentUser(
      _accountant,
    );

    expect(
      notifications.map((notification) => notification.type),
      containsAll([
        NotificationType.salesOrderCreated,
        NotificationType.paymentEntryPosted,
        NotificationType.salesInvoiceCreated,
        NotificationType.advancePaymentAllocated,
      ]),
    );
  });
}

Future<OrderPayment> _acceptedPaymentForOrder(
  _Fixture fixture,
  String orderId,
) async {
  final closure = await fixture.payments.getMyDailyCashClosure(_employee);
  final submitted = await fixture.payments.submitCashClosure(
    closureId: closure.id,
    submittedBy: _employee,
  );
  await fixture.payments.acceptCashClosure(
    closureId: submitted.id,
    cashier: _cashier,
    actualCash: submitted.methodTotal(PaymentMethod.cash),
    actualCard: submitted.methodTotal(PaymentMethod.card),
    actualTransfer: submitted.methodTotal(PaymentMethod.transfer),
    actualOther: submitted.methodTotal(PaymentMethod.other),
  );
  final payments = await fixture.payments.getCashClosurePayments(submitted.id);
  return payments.firstWhere((payment) => payment.orderId == orderId);
}

CreateOrderRequest _draftRequest() {
  final request = CreateOrderRequest(
    createdBranch: const BranchRef(
      id: 'BR-RUH-MUR',
      name: 'فرع الرياض — المروج',
    ),
    pickupBranch: const BranchRef(
      id: 'BR-RUH-MUR',
      name: 'فرع الرياض — المروج',
    ),
  );
  request.customerName = 'عميل مسودة';
  request.customerPhone = '0509999999';
  request.createdByUserId = _employee.id;
  request.createdByName = _employee.fullName;
  request.pickupDate = DateTime(2026, 5, 10);
  request.pickupTime = const TimeOfDay(hour: 18, minute: 0);
  return request;
}

_Fixture _fixture() {
  final mock = MockService();
  return _Fixture(
    accounting: AccountingRepository(mockService: mock, useMockData: true),
    orders: OrderRepository(mockService: mock, useMockData: true),
    payments: PaymentRepository(mockService: mock, useMockData: true),
  );
}

class _Fixture {
  const _Fixture({
    required this.accounting,
    required this.orders,
    required this.payments,
  });

  final AccountingRepository accounting;
  final OrderRepository orders;
  final PaymentRepository payments;
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

const _accountant = AppUser(
  id: 'EMP-0007',
  fullName: 'خالد الناصر',
  email: 'accountant@awamir.local',
  phone: '0507777777',
  role: UserRole.accountant,
  branchId: 'ACC-RUH',
  branchName: 'الإدارة المالية',
  isActive: true,
);
