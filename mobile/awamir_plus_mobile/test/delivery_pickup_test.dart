import 'package:awamir_plus_mobile/core/errors/app_exception.dart';
import 'package:awamir_plus_mobile/core/permissions/access_control.dart';
import 'package:awamir_plus_mobile/models/app_models.dart';
import 'package:awamir_plus_mobile/repositories/order_repository.dart';
import 'package:awamir_plus_mobile/services/mock_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('موظف الفرع يرى فقط طلبات Ready For Pickup الخاصة بفرعه', () async {
    final repository = _repository();

    final orders = await repository.getPickupOrders(_employee);

    expect(orders, isNotEmpty);
    expect(
      orders.every((order) => order.status == OrderStatus.readyForPickup),
      isTrue,
    );
    expect(
      orders.every((order) => order.pickupBranchId == _employee.branchId),
      isTrue,
    );
    expect(orders.map((order) => order.id), contains('ORD-0021'));
    expect(orders.map((order) => order.id), isNot(contains('ORD-0020')));
  });

  test('لا يمكن تسليم طلب فيه متبقي بدون تسجيل دفعة', () async {
    final repository = _repository();

    expect(
      () => repository.markPickupOrderDelivered(
        orderId: 'ORD-0021',
        changedBy: _employee,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'payment_required_before_delivery',
        ),
      ),
    );
  });

  test('تسجيل دفعة المتبقي يجعل المتبقي يساوي صفر', () async {
    final repository = _repository();

    final updated = await repository.collectRemainingPayment(
      orderId: 'ORD-0021',
      amount: 80,
      method: PaymentMethod.cash,
      collectedBy: _employee,
    );

    expect(updated.remainingAmount, 0);
  });

  test('مسؤول التوزيع يستطيع رؤية Ready For Delivery', () async {
    final repository = _repository();

    final orders = await repository.getDistributionOrders(_distribution);

    expect(
      orders,
      contains(
        isA<Order>()
            .having((order) => order.id, 'id', 'ORD-0022')
            .having(
              (order) => order.status,
              'status',
              OrderStatus.readyForDelivery,
            ),
      ),
    );
  });

  test('لا يمكن إسناد الطلب بدون اختيار سائق', () async {
    final repository = _repository();

    expect(
      () => repository.assignDriverToOrder(
        orderId: 'ORD-0022',
        driverId: '',
        changedBy: _distribution,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'driver_required',
        ),
      ),
    );
  });

  test('إسناد السائق يحول الحالة إلى Assigned To Driver', () async {
    final repository = _repository();

    final updated = await repository.assignDriverToOrder(
      orderId: 'ORD-0022',
      driverId: 'DRV-001',
      changedBy: _distribution,
    );
    final assignment = await repository.getDeliveryAssignment('ORD-0022');

    expect(updated.status, OrderStatus.assignedToDriver);
    expect(updated.assignedDriverId, 'DRV-001');
    expect(assignment, isNotNull);
    expect(assignment!.driverId, 'DRV-001');
  });

  test('السائق يرى فقط الطلبات المسندة له', () async {
    final repository = _repository();

    await repository.assignDriverToOrder(
      orderId: 'ORD-0022',
      driverId: 'DRV-001',
      changedBy: _distribution,
    );

    final orders = await repository.getDriverOrders(_driver);

    expect(orders.map((order) => order.id), contains('ORD-0022'));
    expect(
      orders.every((order) => order.assignedDriverId == 'DRV-001'),
      isTrue,
    );
  });

  test('لا يمكن Out For Delivery قبل Driver Picked Up', () async {
    final repository = _repository();

    await repository.assignDriverToOrder(
      orderId: 'ORD-0022',
      driverId: 'DRV-001',
      changedBy: _distribution,
    );

    expect(
      () => repository.updateDeliveryStatus(
        orderId: 'ORD-0022',
        status: OrderStatus.outForDelivery,
        changedBy: _driver,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'invalid_delivery_transition',
        ),
      ),
    );
  });

  test('لا يمكن Delivered قبل Out For Delivery', () async {
    final repository = _repository();

    await repository.assignDriverToOrder(
      orderId: 'ORD-0022',
      driverId: 'DRV-001',
      changedBy: _distribution,
    );

    expect(
      () => repository.updateDeliveryStatus(
        orderId: 'ORD-0022',
        status: OrderStatus.delivered,
        changedBy: _driver,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'invalid_delivery_transition',
        ),
      ),
    );
  });

  test('Delivery Failed يتطلب سبب', () async {
    final repository = _repository();

    await repository.assignDriverToOrder(
      orderId: 'ORD-0022',
      driverId: 'DRV-001',
      changedBy: _distribution,
    );

    expect(
      () => repository.markDeliveryFailed(
        orderId: 'ORD-0022',
        changedBy: _driver,
        reason: '',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'delivery_failure_reason_required',
        ),
      ),
    );
  });

  test('كل تحديث توصيل ينشئ Status Log', () async {
    final repository = _repository();

    await repository.assignDriverToOrder(
      orderId: 'ORD-0022',
      driverId: 'DRV-001',
      changedBy: _distribution,
    );
    final before = await repository.getOrderStatusLogs('ORD-0022');
    final updated = await repository.updateDeliveryStatus(
      orderId: 'ORD-0022',
      status: OrderStatus.driverPickedUp,
      changedBy: _driver,
    );
    final after = await repository.getOrderStatusLogs('ORD-0022');

    expect(updated.status, OrderStatus.driverPickedUp);
    expect(after.length, before.length + 1);
    expect(after.last.newStatus, OrderStatus.driverPickedUp);
  });

  test('إجراءات التوصيل المهمة تنشئ Notifications', () async {
    final repository = _repository();

    await repository.assignDriverToOrder(
      orderId: 'ORD-0022',
      driverId: 'DRV-001',
      changedBy: _distribution,
    );
    final driverNotifications = await repository.getNotificationsForCurrentUser(
      _driver,
    );

    await repository.updateDeliveryStatus(
      orderId: 'ORD-0022',
      status: OrderStatus.driverPickedUp,
      changedBy: _driver,
    );
    await repository.markDeliveryFailed(
      orderId: 'ORD-0022',
      changedBy: _driver,
      reason: 'العميل لا يرد',
    );
    final employeeNotifications = await repository
        .getNotificationsForCurrentUser(_employee);
    final distributionNotifications = await repository
        .getNotificationsForCurrentUser(_distribution);

    expect(
      driverNotifications,
      contains(
        isA<AppNotification>().having(
          (notification) => notification.type,
          'type',
          NotificationType.driverAssigned,
        ),
      ),
    );
    expect(
      employeeNotifications,
      contains(
        isA<AppNotification>().having(
          (notification) => notification.type,
          'type',
          NotificationType.driverPickedUp,
        ),
      ),
    );
    expect(
      distributionNotifications,
      contains(
        isA<AppNotification>().having(
          (notification) => notification.type,
          'type',
          NotificationType.deliveryFailed,
        ),
      ),
    );
  });

  test('دفعة السائق تدخل في عهدة السائق ولا تترحل ERPNext مباشرة', () async {
    final repository = _repository();

    await repository.assignDriverToOrder(
      orderId: 'ORD-0022',
      driverId: 'DRV-001',
      changedBy: _distribution,
    );
    final payment = await repository.collectDeliveryPayment(
      orderId: 'ORD-0022',
      amount: 50,
      method: PaymentMethod.cash,
      collectedBy: _driver,
    );
    final order = (await repository.getOrders()).firstWhere(
      (item) => item.id == 'ORD-0022',
    );

    expect(payment.collectorType, CashClosureOwnerType.driver);
    expect(payment.driverId, 'DRV-001');
    expect(payment.postedToErpNext, isFalse);
    expect(order.remainingAmount, 0);
  });

  test('الصلاحيات تمنع موظف الفرع من شاشة التوزيع وتسمح له بالاستلام', () {
    expect(AccessControl.canViewDistribution(_employee), isFalse);
    expect(AccessControl.canViewPickupOrders(_employee), isTrue);
  });
}

OrderRepository _repository() {
  return OrderRepository(mockService: MockService(), useMockData: true);
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
