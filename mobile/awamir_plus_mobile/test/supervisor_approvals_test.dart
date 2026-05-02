import 'package:awamir_plus_mobile/core/errors/app_exception.dart';
import 'package:awamir_plus_mobile/models/app_models.dart';
import 'package:awamir_plus_mobile/repositories/order_repository.dart';
import 'package:awamir_plus_mobile/services/mock_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('مشرف الفرع يرى فقط طلبات فرعه', () async {
    final repository = _repository();

    final supervisorOrders = await repository.getPendingSupervisorApprovals(
      _supervisor,
    );
    final adminOrders = await repository.getPendingSupervisorApprovals(_admin);

    expect(supervisorOrders.map((order) => order.id), contains('ORD-0017'));
    expect(supervisorOrders.map((order) => order.id), contains('ORD-0013'));
    expect(
      supervisorOrders.map((order) => order.id),
      isNot(contains('ORD-0016')),
    );
    expect(adminOrders.map((order) => order.id), contains('ORD-0016'));
  });

  test('موظف الفرع لا يستطيع الموافقة', () async {
    final repository = _repository();

    expect(
      () => repository.approveOrder(orderId: 'ORD-0017', changedBy: _employee),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'approval_forbidden',
        ),
      ),
    );
  });

  test('لا يمكن رفض الطلب بدون سبب', () async {
    final repository = _repository();

    expect(
      () => repository.rejectOrder(
        orderId: 'ORD-0017',
        changedBy: _supervisor,
        reason: '',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'rejection_reason_required',
        ),
      ),
    );
  });

  test('لا يمكن إرجاع الطلب بدون ملاحظة', () async {
    final repository = _repository();

    expect(
      () => repository.returnOrderForEdit(
        orderId: 'ORD-0017',
        changedBy: _supervisor,
        notes: '',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'return_notes_required',
        ),
      ),
    );
  });

  test(
    'الموافقة تحول الحالة إلى Sent To Distribution وتنشئ سجل وإشعارات',
    () async {
      final mockService = MockService();
      final repository = _repository(mockService);

      final beforeLogs = await repository.getOrderStatusLogs('ORD-0017');
      final updated = await repository.approveOrder(
        orderId: 'ORD-0017',
        changedBy: _supervisor,
      );
      final afterLogs = await repository.getOrderStatusLogs('ORD-0017');
      final employeeNotifications = await repository
          .getNotificationsForCurrentUser(_employee);
      final distributionNotifications = await repository
          .getNotificationsForCurrentUser(_distribution);

      expect(updated.status, OrderStatus.sentToDistribution);
      expect(afterLogs.length, beforeLogs.length + 1);
      expect(afterLogs.last.newStatus, OrderStatus.sentToDistribution);
      expect(
        employeeNotifications,
        contains(
          isA<AppNotification>()
              .having((item) => item.relatedOrderId, 'order', 'ORD-0017')
              .having(
                (item) => item.type,
                'type',
                NotificationType.orderApproved,
              ),
        ),
      );
      expect(
        distributionNotifications,
        contains(
          isA<AppNotification>()
              .having((item) => item.relatedOrderId, 'order', 'ORD-0017')
              .having(
                (item) => item.type,
                'type',
                NotificationType.orderSentToDistribution,
              ),
        ),
      );
    },
  );

  test('الرفض يحول الحالة إلى Rejected وينشئ سجل وإشعار', () async {
    final repository = _repository();

    final updated = await repository.rejectOrder(
      orderId: 'ORD-0017',
      changedBy: _supervisor,
      reason: 'بيانات العميل غير مكتملة',
    );
    final logs = await repository.getOrderStatusLogs('ORD-0017');
    final notifications = await repository.getNotificationsForCurrentUser(
      _employee,
    );

    expect(updated.status, OrderStatus.rejected);
    expect(logs.last.newStatus, OrderStatus.rejected);
    expect(logs.last.notes, contains('بيانات العميل'));
    expect(
      notifications,
      contains(
        isA<AppNotification>()
            .having((item) => item.relatedOrderId, 'order', 'ORD-0017')
            .having(
              (item) => item.type,
              'type',
              NotificationType.orderRejected,
            ),
      ),
    );
  });

  test('الإرجاع يحول الحالة إلى Returned For Edit وينشئ سجل وإشعار', () async {
    final repository = _repository();

    final updated = await repository.returnOrderForEdit(
      orderId: 'ORD-0017',
      changedBy: _supervisor,
      notes: 'تعديل وقت الاستلام',
    );
    final logs = await repository.getOrderStatusLogs('ORD-0017');
    final notifications = await repository.getNotificationsForCurrentUser(
      _employee,
    );

    expect(updated.status, OrderStatus.returnedForEdit);
    expect(logs.last.newStatus, OrderStatus.returnedForEdit);
    expect(logs.last.notes, contains('تعديل وقت الاستلام'));
    expect(
      notifications,
      contains(
        isA<AppNotification>()
            .having((item) => item.relatedOrderId, 'order', 'ORD-0017')
            .having(
              (item) => item.type,
              'type',
              NotificationType.orderReturned,
            ),
      ),
    );
  });
}

OrderRepository _repository([MockService? mockService]) {
  return OrderRepository(mockService: mockService ?? MockService());
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
  fullName: 'سارة العتيبي',
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

const _admin = AppUser(
  id: 'EMP-0008',
  fullName: 'مدير النظام',
  email: 'admin@awamir.local',
  phone: '0508888888',
  role: UserRole.systemAdmin,
  branchId: 'HQ',
  branchName: 'الإدارة العامة',
  isActive: true,
);
