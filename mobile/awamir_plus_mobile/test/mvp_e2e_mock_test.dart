import 'package:awamir_plus_mobile/models/app_models.dart';
import 'package:awamir_plus_mobile/repositories/accounting_repository.dart';
import 'package:awamir_plus_mobile/repositories/order_repository.dart';
import 'package:awamir_plus_mobile/repositories/payment_repository.dart';
import 'package:awamir_plus_mobile/services/mock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('مسار MVP mock كامل من إنشاء الطلب حتى مزامنة المحاسبة', () async {
    final fixture = _fixture();
    final request = _createPickupRequest();

    final created = await fixture.orders.submitForApproval(request);
    expect(created.status, OrderStatus.pendingSupervisorApproval);
    expect(created.remainingAmount, 120);

    final approved = await fixture.orders.approveOrder(
      orderId: created.id,
      changedBy: _supervisor,
    );
    expect(approved.status, OrderStatus.sentToDistribution);

    final distributed = await fixture.orders.assignProductionDepartment(
      orderId: created.id,
      productionDepartmentId: 'PD-SWEETS',
      changedBy: _distribution,
    );
    expect(distributed.status, OrderStatus.sentToProduction);
    expect(distributed.productionDepartmentId, 'PD-SWEETS');

    await fixture.orders.updateProductionStatus(
      orderId: created.id,
      status: OrderStatus.inProduction,
      changedBy: _production,
    );
    await fixture.orders.updateProductionStatus(
      orderId: created.id,
      status: OrderStatus.productionCompleted,
      changedBy: _production,
    );
    final ready = await fixture.orders.updateProductionStatus(
      orderId: created.id,
      status: OrderStatus.readyForPickup,
      changedBy: _production,
    );
    expect(ready.status, OrderStatus.readyForPickup);

    final paid = await fixture.orders.collectRemainingPayment(
      orderId: created.id,
      amount: ready.remainingAmount,
      method: PaymentMethod.transfer,
      collectedBy: _employee,
      transactionReference: 'TRF-MVP-MOCK-REMAINING',
    );
    expect(paid.remainingAmount, 0);

    final delivered = await fixture.orders.markPickupOrderDelivered(
      orderId: created.id,
      changedBy: _employee,
    );
    expect(delivered.status, OrderStatus.delivered);

    final closure = await fixture.payments.getMyDailyCashClosure(_employee);
    expect(closure.methodTotal(PaymentMethod.card), greaterThanOrEqualTo(40));
    expect(
      closure.methodTotal(PaymentMethod.transfer),
      greaterThanOrEqualTo(120),
    );

    final submitted = await fixture.payments.submitCashClosure(
      closureId: closure.id,
      submittedBy: _employee,
    );
    final accepted = await fixture.payments.acceptCashClosure(
      closureId: submitted.id,
      cashier: _cashier,
      actualCash: submitted.methodTotal(PaymentMethod.cash),
      actualCard: submitted.methodTotal(PaymentMethod.card),
      actualTransfer: submitted.methodTotal(PaymentMethod.transfer),
      actualOther: submitted.methodTotal(PaymentMethod.other),
    );
    expect(accepted.status, CashClosureStatus.accepted);

    final closed = await fixture.payments.closeCashClosure(
      closureId: submitted.id,
      closedBy: _cashier,
    );
    expect(closed.status, CashClosureStatus.closed);

    final salesOrder = await fixture.accounting.createSalesOrderForOrder(
      orderId: created.id,
      changedBy: _accountant,
    );
    expect(salesOrder.erpnextSalesOrderId, startsWith('SO-2026-'));

    final orderPayments = (await fixture.payments.getCashClosurePayments(
      submitted.id,
    )).where((payment) => payment.orderId == created.id).toList();
    expect(orderPayments, hasLength(2));
    expect(
      orderPayments.map((payment) => payment.method),
      containsAll([PaymentMethod.card, PaymentMethod.transfer]),
    );
    expect(
      orderPayments.map((payment) => payment.transactionReference),
      containsAll(['CARD-MVP-MOCK-DEPOSIT', 'TRF-MVP-MOCK-REMAINING']),
    );

    final postedPayments = <OrderPayment>[];
    for (final payment in orderPayments) {
      postedPayments.add(
        await fixture.accounting.createPaymentEntryForPayment(
          paymentId: payment.id,
          changedBy: _accountant,
        ),
      );
    }
    expect(
      postedPayments.every(
        (payment) => payment.status == OrderPaymentStatus.postedToErpNext,
      ),
      isTrue,
    );

    final invoice = await fixture.accounting.createSalesInvoiceForOrder(
      orderId: created.id,
      changedBy: _accountant,
    );
    expect(invoice.erpnextSalesInvoiceId, startsWith('ACC-SINV-2026-'));

    final allocations = await fixture.accounting
        .allocateAdvancePaymentToInvoice(
          orderId: created.id,
          changedBy: _accountant,
        );
    expect(allocations, hasLength(2));
    expect(
      allocations.fold<num>(
        0,
        (total, allocation) => total + allocation.allocatedAmount,
      ),
      160,
    );

    final synced = await fixture.accounting.syncOrderAccountingStatus(
      orderId: created.id,
      changedBy: _accountant,
    );
    final logs = await fixture.orders.getOrderStatusLogs(created.id);
    final finalPayments = (await fixture.payments.getCashClosurePayments(
      submitted.id,
    )).where((payment) => payment.orderId == created.id);

    expect(synced.status, OrderStatus.delivered);
    expect(synced.erpSyncStatus, ErpSyncStatus.synced);
    expect(synced.erpnextSalesOrderId, isNotEmpty);
    expect(synced.erpnextSalesInvoiceId, isNotEmpty);
    expect(synced.erpnextPaymentEntryIds, hasLength(2));
    expect(
      finalPayments.every(
        (payment) => payment.status == OrderPaymentStatus.linkedToInvoice,
      ),
      isTrue,
    );
    expect(logs.map((log) => log.newStatus), contains(OrderStatus.delivered));
    expect(logs.any((log) => log.notes.contains('Sales Order')), isTrue);
    expect(logs.any((log) => log.notes.contains('Payment Entry')), isTrue);
    expect(logs.any((log) => log.notes.contains('Sales Invoice')), isTrue);
  });
}

_Fixture _fixture() {
  final mock = MockService();
  return _Fixture(
    orders: OrderRepository(mockService: mock, useMockData: true),
    payments: PaymentRepository(mockService: mock, useMockData: true),
    accounting: AccountingRepository(mockService: mock, useMockData: true),
  );
}

CreateOrderRequest _createPickupRequest() {
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
  request.department = const ProductDepartment(
    id: 'sweets',
    name: 'الحلويات',
    icon: Icons.cake,
  );
  request.customerName = 'عميل اختبار MVP';
  request.customerPhone = '0501234500';
  request.orderDetails = 'اختبار مسار MVP كامل';
  request.customerNotes = 'بدون ملاحظات إضافية';
  request.createdByUserId = _employee.id;
  request.createdByName = _employee.fullName;
  request.pickupDate = DateTime(2026, 5, 15);
  request.pickupTime = const TimeOfDay(hour: 18, minute: 30);
  request.depositAmount = 40;
  request.paymentMethod = PaymentMethod.card;
  request.transactionReference = 'CARD-MVP-MOCK-DEPOSIT';
  request.setProductQuantity(
    const Product(
      id: 910,
      departmentId: 'sweets',
      name: 'كيكة اختبار MVP',
      description: 'منتج تجريبي لمسار MVP',
      price: 160,
      imageUrl: '',
      itemCode: 'MVP-MOCK-CAKE',
    ),
    1,
  );
  return request;
}

class _Fixture {
  const _Fixture({
    required this.orders,
    required this.payments,
    required this.accounting,
  });

  final OrderRepository orders;
  final PaymentRepository payments;
  final AccountingRepository accounting;
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

const _supervisor = AppUser(
  id: 'EMP-0002',
  fullName: 'نورة القحطاني',
  email: 'supervisor@awamir.local',
  phone: '0502222222',
  role: UserRole.branchSupervisor,
  branchId: 'BR-RUH-MUR',
  branchName: 'فرع الرياض — المروج',
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

const _production = AppUser(
  id: 'EMP-0004',
  fullName: 'سارة العمري',
  email: 'production@awamir.local',
  phone: '0504444444',
  role: UserRole.productionUser,
  branchId: 'PROD-RUH',
  branchName: 'مصنع الرياض',
  isActive: true,
  productionDepartmentId: 'PD-SWEETS',
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
