import 'package:awamir_plus_mobile/controllers/create_order_controller.dart';
import 'package:awamir_plus_mobile/core/utils/maps_utils.dart';
import 'package:awamir_plus_mobile/models/app_models.dart';
import 'package:awamir_plus_mobile/repositories/customer_repository.dart';
import 'package:awamir_plus_mobile/repositories/order_repository.dart';
import 'package:awamir_plus_mobile/repositories/product_repository.dart';
import 'package:awamir_plus_mobile/services/mock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('لا يمكن الانتقال بدون اختيار منتج', () async {
    final controller = await _createController();
    addTearDown(controller.dispose);

    await controller.selectDepartment(controller.departments.first);

    expect(controller.currentStep, CreateOrderStep.products);
    expect(controller.nextStep(), isFalse);
    expect(controller.validationMessage, 'اختر منتجاً واحداً على الأقل');
  });

  test('لا يمكن إدخال عربون أكبر من إجمالي الطلب', () async {
    final controller = await _createValidController();
    addTearDown(controller.dispose);

    controller.updatePayment(depositAmount: controller.request.grandTotal + 1);

    expect(controller.validateStep(CreateOrderStep.payment), isFalse);
    expect(
      controller.validationMessage,
      'العربون لا يمكن أن يتجاوز إجمالي الطلب ورسوم التوصيل',
    );
  });

  test('فرع الاستلام الافتراضي يساوي فرع الموظف', () async {
    final controller = await _createController();
    addTearDown(controller.dispose);

    expect(controller.request.createdBranch.id, _employee.branchId);
    expect(controller.request.pickupBranch.id, _employee.branchId);
  });

  test('يتم استخراج الإحداثيات من رابط Google Maps', () {
    final point = extractGoogleMapsCoordinates(
      'https://maps.google.com/?q=21.488775,39.930210',
    );

    expect(point, isNotNull);
    expect(point!.latitude, 21.488775);
    expect(point.longitude, 39.930210);
  });

  test('إنشاء الطلب يحفظ الحالة حسب زر المسودة أو الموافقة', () async {
    final draftController = await _createValidController();
    addTearDown(draftController.dispose);

    final draftOrder = await draftController.saveDraft();

    expect(draftOrder, isNotNull);
    expect(draftOrder!.id, startsWith('ORD-2026-'));
    expect(draftOrder.status, OrderStatus.draft);

    final submitController = await _createValidController();
    addTearDown(submitController.dispose);

    final pendingOrder = await submitController.submitForApproval();

    expect(pendingOrder, isNotNull);
    expect(pendingOrder!.id, startsWith('ORD-2026-'));
    expect(pendingOrder.status, OrderStatus.pendingSupervisorApproval);
  });
}

Future<CreateOrderController> _createController() async {
  final mockService = MockService();
  final controller = CreateOrderController(
    currentUser: _employee,
    productRepository: ProductRepository(
      mockService: mockService,
      useMockData: true,
    ),
    customerRepository: CustomerRepository(
      mockService: mockService,
      useMockData: true,
    ),
    orderRepository: OrderRepository(
      mockService: mockService,
      useMockData: true,
    ),
  );
  await controller.loadCategories();
  return controller;
}

Future<CreateOrderController> _createValidController() async {
  final controller = await _createController();
  await controller.selectDepartment(controller.departments.first);
  controller.changeProductQuantity(controller.products.first, 1);
  controller.updateCustomerPhone('0550000000');
  controller.updateCustomerName('عميل اختبار');
  controller.updateOrderDetails(details: 'تفاصيل طلب اختبار');
  controller.updatePickupDate(DateTime.now().add(const Duration(days: 1)));
  controller.updatePickupTime(const TimeOfDay(hour: 12, minute: 30));
  controller.updatePayment(depositAmount: 10, method: PaymentMethod.cash);
  return controller;
}

const _employee = AppUser(
  id: 'EMP-TEST',
  fullName: 'موظف اختبار',
  email: 'employee.test@awamir.local',
  phone: '0500000000',
  role: UserRole.branchEmployee,
  branchId: 'BR-RUH-MUR',
  branchName: 'فرع الرياض — المروج',
  isActive: true,
);
