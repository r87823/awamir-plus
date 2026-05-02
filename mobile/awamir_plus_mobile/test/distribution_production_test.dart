import 'package:awamir_plus_mobile/core/errors/app_exception.dart';
import 'package:awamir_plus_mobile/core/permissions/access_control.dart';
import 'package:awamir_plus_mobile/models/app_models.dart';
import 'package:awamir_plus_mobile/repositories/order_repository.dart';
import 'package:awamir_plus_mobile/services/mock_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('مسؤول التوزيع يرى طلبات التوزيع والتوصيل فقط', () async {
    final repository = _repository();

    final orders = await repository.getDistributionOrders(_distribution);

    expect(orders, isNotEmpty);
    const distributionStatuses = {
      OrderStatus.sentToDistribution,
      OrderStatus.readyForDelivery,
      OrderStatus.assignedToDriver,
      OrderStatus.driverPickedUp,
      OrderStatus.outForDelivery,
      OrderStatus.deliveryFailed,
    };
    expect(
      orders.every((order) => distributionStatuses.contains(order.status)),
      isTrue,
    );
    expect(orders.map((order) => order.id), contains('ORD-0018'));
    expect(orders.map((order) => order.id), contains('ORD-0022'));
    expect(orders.map((order) => order.id), isNot(contains('ORD-0017')));
  });

  test('موظف الفرع لا يستطيع فتح شاشة التوزيع', () {
    expect(AccessControl.canViewDistribution(_employee), isFalse);
    expect(AccessControl.canAssignProductionDepartment(_employee), isFalse);
  });

  test('لا يمكن تحويل الطلب للتنفيذ بدون اختيار جهة تنفيذ', () async {
    final repository = _repository();

    expect(
      () => repository.assignProductionDepartment(
        orderId: 'ORD-0018',
        productionDepartmentId: '',
        changedBy: _distribution,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'production_department_required',
        ),
      ),
    );
  });

  test('التحويل للتنفيذ يحفظ الجهة وينشئ سجل وإشعارات', () async {
    final repository = _repository();

    final beforeLogs = await repository.getOrderStatusLogs('ORD-0018');
    final updated = await repository.assignProductionDepartment(
      orderId: 'ORD-0018',
      productionDepartmentId: 'PD-SWEETS',
      changedBy: _distribution,
    );
    final afterLogs = await repository.getOrderStatusLogs('ORD-0018');
    final productionNotifications = await repository
        .getNotificationsForCurrentUser(_production);
    final employeeNotifications = await repository
        .getNotificationsForCurrentUser(_employee);

    expect(updated.status, OrderStatus.sentToProduction);
    expect(updated.productionDepartmentId, 'PD-SWEETS');
    expect(updated.productionDepartmentName, 'مصنع الحلويات');
    expect(afterLogs.length, beforeLogs.length + 1);
    expect(afterLogs.last.newStatus, OrderStatus.sentToProduction);
    expect(
      productionNotifications,
      contains(
        isA<AppNotification>()
            .having((item) => item.relatedOrderId, 'order', 'ORD-0018')
            .having(
              (item) => item.type,
              'type',
              NotificationType.orderSentToProduction,
            ),
      ),
    );
    expect(
      employeeNotifications,
      contains(
        isA<AppNotification>()
            .having((item) => item.relatedOrderId, 'order', 'ORD-0018')
            .having(
              (item) => item.type,
              'type',
              NotificationType.orderSentToProduction,
            ),
      ),
    );
  });

  test('production_user يرى فقط طلبات جهة التنفيذ التابعة له', () async {
    final repository = _repository();

    await repository.assignProductionDepartment(
      orderId: 'ORD-0018',
      productionDepartmentId: 'PD-SWEETS',
      changedBy: _distribution,
    );
    await repository.assignProductionDepartment(
      orderId: 'ORD-0015',
      productionDepartmentId: 'PD-SPECIAL',
      changedBy: _distribution,
    );

    final orders = await repository.getProductionOrders(_production);

    expect(orders.map((order) => order.id), contains('ORD-0018'));
    expect(orders.map((order) => order.id), isNot(contains('ORD-0015')));
  });

  test('production_user يستطيع تحويل الحالة إلى In Production', () async {
    final repository = _repository();

    await repository.assignProductionDepartment(
      orderId: 'ORD-0018',
      productionDepartmentId: 'PD-SWEETS',
      changedBy: _distribution,
    );
    final updated = await repository.updateProductionStatus(
      orderId: 'ORD-0018',
      status: OrderStatus.inProduction,
      changedBy: _production,
    );

    expect(updated.status, OrderStatus.inProduction);
  });

  test('Pickup يمكن تحويله إلى Ready For Pickup بعد اكتمال الإنتاج', () async {
    final repository = _repository();

    await repository.assignProductionDepartment(
      orderId: 'ORD-0018',
      productionDepartmentId: 'PD-SWEETS',
      changedBy: _distribution,
    );
    await repository.updateProductionStatus(
      orderId: 'ORD-0018',
      status: OrderStatus.inProduction,
      changedBy: _production,
    );
    await repository.updateProductionStatus(
      orderId: 'ORD-0018',
      status: OrderStatus.productionCompleted,
      changedBy: _production,
    );
    final ready = await repository.updateProductionStatus(
      orderId: 'ORD-0018',
      status: OrderStatus.readyForPickup,
      changedBy: _production,
    );
    final logs = await repository.getOrderStatusLogs('ORD-0018');

    expect(ready.status, OrderStatus.readyForPickup);
    expect(logs.last.newStatus, OrderStatus.readyForPickup);
  });

  test(
    'Delivery يمكن تحويله إلى Ready For Delivery بعد اكتمال الإنتاج',
    () async {
      final repository = _repository();

      await repository.assignProductionDepartment(
        orderId: 'ORD-0019',
        productionDepartmentId: 'PD-SWEETS',
        changedBy: _distribution,
      );
      await repository.updateProductionStatus(
        orderId: 'ORD-0019',
        status: OrderStatus.inProduction,
        changedBy: _production,
      );
      await repository.updateProductionStatus(
        orderId: 'ORD-0019',
        status: OrderStatus.productionCompleted,
        changedBy: _production,
      );
      final ready = await repository.updateProductionStatus(
        orderId: 'ORD-0019',
        status: OrderStatus.readyForDelivery,
        changedBy: _production,
      );
      final logs = await repository.getOrderStatusLogs('ORD-0019');

      expect(ready.status, OrderStatus.readyForDelivery);
      expect(logs.last.newStatus, OrderStatus.readyForDelivery);
    },
  );

  test('كل تحديث إنتاج ينشئ Status Log', () async {
    final repository = _repository();

    await repository.assignProductionDepartment(
      orderId: 'ORD-0018',
      productionDepartmentId: 'PD-SWEETS',
      changedBy: _distribution,
    );
    final before = await repository.getOrderStatusLogs('ORD-0018');
    await repository.updateProductionStatus(
      orderId: 'ORD-0018',
      status: OrderStatus.inProduction,
      changedBy: _production,
    );
    final after = await repository.getOrderStatusLogs('ORD-0018');

    expect(after.length, before.length + 1);
    expect(after.last.newStatus, OrderStatus.inProduction);
  });
}

OrderRepository _repository() {
  return OrderRepository(mockService: MockService());
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

const _production = AppUser(
  id: 'EMP-0004',
  fullName: 'نواف القحطاني',
  email: 'production@awamir.local',
  phone: '0504444444',
  role: UserRole.productionUser,
  branchId: 'PROD-RUH',
  branchName: 'مصنع الحلويات',
  isActive: true,
  productionDepartmentId: 'PD-SWEETS',
);
