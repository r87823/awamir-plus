import 'package:awamir_plus_mobile/core/permissions/access_control.dart';
import 'package:awamir_plus_mobile/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('branch employee sees only branch employee features', () {
    final user = _user(UserRole.branchEmployee);

    expect(AccessControl.canCreateOrder(user), isTrue);
    expect(AccessControl.canViewBranchOrders(user), isTrue);
    expect(AccessControl.canApproveOrders(user), isFalse);
    expect(AccessControl.roleFeatures(user), [
      AppFeature.createOrder,
      AppFeature.branchOrders,
      AppFeature.dailyCashClosure,
      AppFeature.notifications,
      AppFeature.deliveredOrders,
    ]);
  });

  test('role feature sets match requested dashboards', () {
    expect(_labels(UserRole.branchSupervisor), [
      'موافقات الفرع',
      'طلباتي',
      'الإشعارات',
      'تم التسليم',
    ]);
    expect(_labels(UserRole.distributionManager), [
      'التوزيع',
      'الطلبات المعتمدة',
      'السائقين',
      'الإشعارات',
    ]);
    expect(_labels(UserRole.productionUser), [
      'طلبات التصنيع',
      'قيد التنفيذ',
      'جاهز للاستلام/التوصيل',
    ]);
    expect(_labels(UserRole.driver), [
      'طلباتي المسندة',
      'في الطريق',
      'تم التسليم',
      'عهدتي اليومية',
    ]);
    expect(_labels(UserRole.cashier), [
      'عهد الموظفين',
      'قبول العهدة',
      'الفروقات',
    ]);
    expect(_labels(UserRole.accountant), [
      'الدفعات',
      'الفواتير',
      'Payment Entry',
    ]);
  });

  test('system admin can access every feature', () {
    final user = _user(UserRole.systemAdmin);

    for (final feature in AppFeature.values) {
      expect(AccessControl.canAccessFeature(user, feature), isTrue);
    }
  });
}

List<String> _labels(UserRole role) {
  return AccessControl.roleFeatures(
    _user(role),
  ).map((feature) => feature.label).toList();
}

AppUser _user(UserRole role) {
  return AppUser(
    id: role.key,
    fullName: role.label,
    email: '${role.key}@awamir.local',
    phone: '0500000000',
    role: role,
    branchId: 'BR-TEST',
    branchName: 'فرع تجريبي',
    isActive: true,
  );
}
