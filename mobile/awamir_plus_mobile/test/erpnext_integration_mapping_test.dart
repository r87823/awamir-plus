import 'dart:convert';

import 'package:awamir_plus_mobile/core/errors/app_exception.dart';
import 'package:awamir_plus_mobile/core/network/api_client.dart';
import 'package:awamir_plus_mobile/core/network/session_cookie_store.dart';
import 'package:awamir_plus_mobile/models/app_models.dart';
import 'package:awamir_plus_mobile/repositories/accounting_repository.dart';
import 'package:awamir_plus_mobile/repositories/customer_repository.dart';
import 'package:awamir_plus_mobile/repositories/order_repository.dart';
import 'package:awamir_plus_mobile/repositories/payment_repository.dart';
import 'package:awamir_plus_mobile/repositories/product_repository.dart';
import 'package:awamir_plus_mobile/services/erpnext_service.dart';
import 'package:awamir_plus_mobile/services/mock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Login يحفظ الجلسة عند النجاح ويحمّل المستخدم الحالي', () async {
    final seenCookies = <String>[];
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return _jsonResponse(
              {'message': 'Logged In'},
              headers: {'set-cookie': 'sid=abc123; Path=/; HttpOnly'},
            );
          }
          seenCookies.add(request.headers['Cookie'] ?? '');
          return _jsonResponse({
            'message': {
              'id': 'Administrator',
              'full_name': 'Administrator',
              'email': 'admin@example.com',
              'roles': ['Awamir System Admin'],
              'branch': null,
              'production_department': null,
              'driver_profile': null,
            },
          });
        }),
      ),
    );

    final user = await service.login(
      username: 'Administrator',
      password: 'admin',
    );

    expect(user.role, UserRole.systemAdmin);
    expect(seenCookies.single, contains('sid=abc123'));
  });

  test('get_current_user يحوّل أدوار Frappe إلى UserRole', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'message': {
              'id': 'production@example.com',
              'full_name': 'موظف إنتاج',
              'email': 'production@example.com',
              'roles': ['Awamir Production User'],
              'branch': 'Main Branch',
              'production_department': 'SWEETS',
              'driver_profile': null,
            },
          }),
        ),
      ),
    );

    final user = await service.getCurrentUser();

    expect(user?.role, UserRole.productionUser);
    expect(user?.productionDepartmentId, 'SWEETS');
    expect(user?.branchName, 'Main Branch');
  });

  test(
    'product repository يستخدم ErpnextService عندما useMockData = false',
    () async {
      final fakeService = _FakeErpnextService(
        categories: const [
          ProductDepartment(
            id: 'ERP',
            name: 'ERP Category',
            icon: Icons.category,
          ),
        ],
      );

      final repository = ProductRepository(
        mockService: MockService(),
        erpnextService: fakeService,
        useMockData: false,
      );

      final categories = await repository.getCategories();

      expect(categories.single.id, 'ERP');
      expect(fakeService.categoriesCalled, isTrue);
    },
  );

  test('customer search يتعامل مع العميل الموجود وغير الموجود', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((request) async {
          final phone = request.url.queryParameters['phone'];
          return _jsonResponse({
            'message': phone == '0501234567'
                ? [
                    {
                      'name': 'CUST-0001',
                      'customer_name': 'خالد العتيبي',
                      'customer_type': 'Individual',
                      'mobile_no': phone,
                    },
                  ]
                : [],
          });
        }),
      ),
    );

    final existing = await service.searchCustomerByPhone('0501234567');
    final missing = await service.searchCustomerByPhone('0599999999');

    expect(existing?.name, 'خالد العتيبي');
    expect(missing, isNull);
  });

  test('mock mode ما زال يعمل عندما useMockData = true', () async {
    final repository = ProductRepository(
      mockService: MockService(),
      erpnextService: _FakeErpnextService(
        categories: const [
          ProductDepartment(
            id: 'ERP',
            name: 'ERP Category',
            icon: Icons.category,
          ),
        ],
      ),
      useMockData: true,
    );

    final categories = await repository.getCategories();

    expect(categories.map((item) => item.id), contains('special'));
  });

  test('customer repository يستخدم ErpnextService للبحث الحقيقي', () async {
    final repository = CustomerRepository(
      mockService: MockService(),
      erpnextService: _FakeErpnextService(
        customer: const Customer(
          id: 'CUST-ERP',
          name: 'عميل ERP',
          phone: '0500000000',
          isCompany: false,
        ),
      ),
      useMockData: false,
    );

    final customer = await repository.searchCustomerByPhone('0500000000');

    expect(customer?.id, 'CUST-ERP');
  });

  test('save draft يرسل payload إنشاء الطلب ويرجع حالة Draft', () async {
    late Map<String, dynamic> sentBody;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({
            'message': {
              'order_id': 'ORD-2026-00011',
              'order_number': 'ORD-2026-00011',
              'status': 'Draft',
              'order': _orderPayload(status: 'Draft'),
            },
          });
        }),
      ),
    );

    final request = _createOrderRequest();
    final order = await service.saveDraft(request);
    final orderData = sentBody['order_data'] as Map<String, dynamic>;
    final items = orderData['items'] as List<dynamic>;

    expect(request.hasProducts, isTrue);
    expect(order.status, OrderStatus.draft);
    expect(orderData['submit_for_approval'], isFalse);
    expect(orderData['customer_phone'], '0500000001');
    expect(orderData['deposit_amount'], 100);
    expect(orderData['payment_method'], 'Card');
    expect(items.single['item_code'], 'AWAMIR-KUNAFA');
  });

  test(
    'submit approval يرسل submit_for_approval ويرجع Pending Approval',
    () async {
      late Map<String, dynamic> sentBody;
      final service = ErpnextService(
        apiClient: ApiClient(
          baseUrl: 'https://example.com',
          cookieStore: _MemoryCookieStore(),
          httpClient: MockClient((request) async {
            sentBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse({
              'message': {
                'order_id': 'ORD-2026-00012',
                'order_number': 'ORD-2026-00012',
                'status': 'Pending Supervisor Approval',
                'order': _orderPayload(status: 'Pending Supervisor Approval'),
              },
            });
          }),
        ),
      );

      final order = await service.submitForApproval(_createOrderRequest());
      final orderData = sentBody['order_data'] as Map<String, dynamic>;

      expect(orderData['submit_for_approval'], isTrue);
      expect(order.status, OrderStatus.pendingSupervisorApproval);
    },
  );

  test('فشل create order لا يمسح بيانات نموذج الطلب', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'exception': 'Delivery address or location URL is required.',
          }, statusCode: 417),
        ),
      ),
    );
    final request = _createOrderRequest()
      ..fulfillmentType = FulfillmentType.customerDelivery
      ..deliveryDetails = const DeliveryDetailsDraft();

    await expectLater(service.saveDraft(request), throwsA(isA<Exception>()));

    expect(request.customerPhone, '0500000001');
    expect(request.lineItems.single.product.itemCode, 'AWAMIR-KUNAFA');
    expect(request.depositAmount, 100);
  });

  test(
    'getPendingSupervisorApprovals يستخدم ErpnextService في real mode',
    () async {
      final fakeService = _FakeErpnextService(
        supervisorOrders: [
          _localOrder(status: OrderStatus.pendingSupervisorApproval),
        ],
      );
      final repository = OrderRepository(
        mockService: MockService(),
        erpnextService: fakeService,
        useMockData: false,
      );

      final orders = await repository.getPendingSupervisorApprovals(_erpUser);

      expect(fakeService.supervisorApprovalsCalled, isTrue);
      expect(orders.single.status, OrderStatus.pendingSupervisorApproval);
    },
  );

  test('getDistributionOrders يستخدم ErpnextService في real mode', () async {
    final fakeService = _FakeErpnextService(
      distributionOrders: [_localOrder(status: OrderStatus.sentToDistribution)],
    );
    final repository = OrderRepository(
      mockService: MockService(),
      erpnextService: fakeService,
      useMockData: false,
    );

    final orders = await repository.getDistributionOrders(_distributionUser);

    expect(fakeService.distributionOrdersCalled, isTrue);
    expect(orders.single.status, OrderStatus.sentToDistribution);
  });

  test('getProductionOrders يستخدم ErpnextService في real mode', () async {
    final fakeService = _FakeErpnextService(
      productionOrders: [_localOrder(status: OrderStatus.sentToProduction)],
    );
    final repository = OrderRepository(
      mockService: MockService(),
      erpnextService: fakeService,
      useMockData: false,
    );

    final orders = await repository.getProductionOrders(_productionUser);

    expect(fakeService.productionOrdersCalled, isTrue);
    expect(orders.single.status, OrderStatus.sentToProduction);
  });

  test('getPickupOrders يستخدم ErpnextService في real mode', () async {
    final fakeService = _FakeErpnextService(
      pickupOrders: [_localOrder(status: OrderStatus.readyForPickup)],
    );
    final repository = OrderRepository(
      mockService: MockService(),
      erpnextService: fakeService,
      useMockData: false,
    );

    final orders = await repository.getPickupOrders(_erpUser);

    expect(fakeService.pickupOrdersCalled, isTrue);
    expect(orders.single.status, OrderStatus.readyForPickup);
  });

  test('getDriverOrders يستخدم ErpnextService في real mode', () async {
    final fakeService = _FakeErpnextService(
      driverOrders: [_localOrder(status: OrderStatus.assignedToDriver)],
    );
    final repository = OrderRepository(
      mockService: MockService(),
      erpnextService: fakeService,
      useMockData: false,
    );

    final orders = await repository.getDriverOrders(_driverUser);

    expect(fakeService.driverOrdersCalled, isTrue);
    expect(orders.single.status, OrderStatus.assignedToDriver);
  });

  test('getProductionDepartments يرجع قائمة قابلة للعرض', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'message': [
              {
                'id': 'PD-SWEETS',
                'name': 'مصنع الحلويات',
                'code': 'SWEETS_FACTORY',
                'branch': 'فرع المروج',
                'is_active': 1,
              },
            ],
          }),
        ),
      ),
    );

    final departments = await service.getProductionDepartments();

    expect(departments.single.id, 'PD-SWEETS');
    expect(departments.single.name, 'مصنع الحلويات');
    expect(departments.single.code, 'SWEETS_FACTORY');
    expect(departments.single.branch, 'فرع المروج');
    expect(departments.single.isActive, isTrue);
  });

  test('getDefaultDepartmentForOrder يعمل حسب mapping', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['order'], 'ORD-2026-00012');
          return _jsonResponse({
            'message': {
              'production_department': 'PD-SWEETS',
              'requires_work_order': 1,
              'source': 'item_group',
              'department': {
                'id': 'PD-SWEETS',
                'name': 'مصنع الحلويات',
                'code': 'SWEETS_FACTORY',
                'branch': 'فرع المروج',
                'is_active': 1,
              },
            },
          });
        }),
      ),
    );

    final department = await service.getDefaultDepartmentForOrder(
      _localOrder(status: OrderStatus.sentToDistribution),
    );

    expect(department?.id, 'PD-SWEETS');
    expect(department?.name, 'مصنع الحلويات');
  });

  test(
    'assignProductionDepartment يرفض بدون department قبل استدعاء API',
    () async {
      var called = false;
      final service = ErpnextService(
        apiClient: ApiClient(
          baseUrl: 'https://example.com',
          cookieStore: _MemoryCookieStore(),
          httpClient: MockClient((_) async {
            called = true;
            return _jsonResponse({});
          }),
        ),
      );

      await expectLater(
        service.assignProductionDepartment(
          orderId: 'ORD-2026-00012',
          productionDepartmentId: ' ',
          changedBy: _distributionUser,
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'production_department_required',
          ),
        ),
      );

      expect(called, isFalse);
    },
  );

  test(
    'assignProductionDepartment يحول الحالة إلى Sent To Production',
    () async {
      late Map<String, dynamic> sentBody;
      final service = ErpnextService(
        apiClient: ApiClient(
          baseUrl: 'https://example.com',
          cookieStore: _MemoryCookieStore(),
          httpClient: MockClient((request) async {
            sentBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse({
              'message': {
                'order_id': 'ORD-2026-00012',
                'order_number': 'ORD-2026-00012',
                'status': 'Sent To Production',
                'production_department': 'PD-SWEETS',
                'message': 'Order assigned to production successfully.',
                'order': _orderPayload(
                  status: 'Sent To Production',
                  productionDepartment: 'PD-SWEETS',
                ),
              },
            });
          }),
        ),
      );

      final order = await service.assignProductionDepartment(
        orderId: 'ORD-2026-00012',
        productionDepartmentId: 'PD-SWEETS',
        changedBy: _distributionUser,
      );

      expect(sentBody['order'], 'ORD-2026-00012');
      expect(sentBody['production_department'], 'PD-SWEETS');
      expect(order.status, OrderStatus.sentToProduction);
      expect(order.productionDepartmentId, 'PD-SWEETS');
    },
  );

  test('assignProductionDepartment API error لا يغيّر الحالة المحلية', () async {
    final existingOrder = _localOrder(status: OrderStatus.sentToDistribution);
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'exception':
                'Only orders sent to distribution can be assigned to production.',
          }, statusCode: 417),
        ),
      ),
    );

    await expectLater(
      service.assignProductionDepartment(
        orderId: existingOrder.id,
        productionDepartmentId: 'PD-SWEETS',
        changedBy: _distributionUser,
      ),
      throwsA(isA<AppException>()),
    );

    expect(existingOrder.status, OrderStatus.sentToDistribution);
    expect(existingOrder.productionDepartmentId, isEmpty);
  });

  test('updateProductionStatus يرسل الحالة الصحيحة', () async {
    late Map<String, dynamic> sentBody;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({
            'message': {
              'order_id': 'ORD-2026-00012',
              'order_number': 'ORD-2026-00012',
              'status': 'In Production',
              'message': 'Production status updated successfully.',
              'order': _orderPayload(status: 'In Production'),
            },
          });
        }),
      ),
    );

    final order = await service.updateProductionStatus(
      orderId: 'ORD-2026-00012',
      status: OrderStatus.inProduction,
      changedBy: _productionUser,
    );

    expect(sentBody['order'], 'ORD-2026-00012');
    expect(sentBody['new_status'], 'In Production');
    expect(order.status, OrderStatus.inProduction);
  });

  test('updateProductionStatus API error لا يغيّر الحالة المحلية', () async {
    final existingOrder = _localOrder(status: OrderStatus.sentToProduction);
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'exception': 'Invalid production status transition.',
          }, statusCode: 417),
        ),
      ),
    );

    await expectLater(
      service.updateProductionStatus(
        orderId: existingOrder.id,
        status: OrderStatus.productionCompleted,
        changedBy: _productionUser,
      ),
      throwsA(isA<AppException>()),
    );

    expect(existingOrder.status, OrderStatus.sentToProduction);
  });

  test('getAvailableDrivers يرجع قائمة السائقين من API الحقيقي', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'message': [
              {
                'id': 'driver@awamir.plus',
                'user_id': 'driver@awamir.plus',
                'full_name': 'سائق أوامر',
                'phone': '0500000005',
                'branch_id': 'فرع المروج',
                'branch_name': 'فرع المروج',
                'current_assigned_orders_count': 2,
                'is_active': 1,
              },
            ],
          }),
        ),
      ),
    );

    final drivers = await service.getAvailableDrivers(_distributionUser);

    expect(drivers.single.id, 'driver@awamir.plus');
    expect(drivers.single.fullName, 'سائق أوامر');
    expect(drivers.single.currentAssignedOrdersCount, 2);
    expect(drivers.single.isActive, isTrue);
  });

  test('assignDriverToOrder يرفض بدون سائق قبل استدعاء API', () async {
    var called = false;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((_) async {
          called = true;
          return _jsonResponse({});
        }),
      ),
    );

    await expectLater(
      service.assignDriverToOrder(
        orderId: 'ORD-2026-00012',
        driverId: ' ',
        changedBy: _distributionUser,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'driver_required',
        ),
      ),
    );

    expect(called, isFalse);
  });

  test('assignDriverToOrder يحول الحالة إلى Assigned To Driver', () async {
    late Map<String, dynamic> sentBody;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({
            'message': {
              'order_id': 'ORD-2026-00012',
              'order_number': 'ORD-2026-00012',
              'status': 'Assigned To Driver',
              'order': _orderPayload(
                status: 'Assigned To Driver',
                assignedDriver: 'driver@awamir.plus',
              ),
            },
          });
        }),
      ),
    );

    final order = await service.assignDriverToOrder(
      orderId: 'ORD-2026-00012',
      driverId: 'driver@awamir.plus',
      changedBy: _distributionUser,
    );

    expect(sentBody['driver'], 'driver@awamir.plus');
    expect(order.status, OrderStatus.assignedToDriver);
    expect(order.assignedDriverId, 'driver@awamir.plus');
  });

  test('updateDeliveryStatus يرسل حالة التوصيل الصحيحة', () async {
    late Map<String, dynamic> sentBody;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({
            'message': {
              'order_id': 'ORD-2026-00012',
              'order_number': 'ORD-2026-00012',
              'status': 'Driver Picked Up',
              'order': _orderPayload(status: 'Driver Picked Up'),
            },
          });
        }),
      ),
    );

    final order = await service.updateDeliveryStatus(
      orderId: 'ORD-2026-00012',
      status: OrderStatus.driverPickedUp,
      changedBy: _driverUser,
      driverNotes: 'تم الاستلام',
    );

    expect(sentBody['new_status'], 'Driver Picked Up');
    expect(sentBody['driver_notes'], 'تم الاستلام');
    expect(order.status, OrderStatus.driverPickedUp);
  });

  test('markDeliveryFailed يرفض بدون سبب قبل استدعاء API', () async {
    var called = false;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((_) async {
          called = true;
          return _jsonResponse({});
        }),
      ),
    );

    await expectLater(
      service.markDeliveryFailed(
        orderId: 'ORD-2026-00012',
        changedBy: _driverUser,
        reason: '  ',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'delivery_failure_reason_required',
        ),
      ),
    );

    expect(called, isFalse);
  });

  test('collectDeliveryPayment يحول الدفعة إلى عهدة السائق', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'message': {
              'payment_id': 'PAY-0001',
              'payment': {
                'name': 'PAY-0001',
                'order': 'ORD-2026-00012',
                'customer': 'CUST-0001',
                'amount': 90,
                'payment_method': 'Cash',
                'received_by_user': 'driver@awamir.plus',
                'received_by_role': 'driver',
                'cash_closure': 'CASH-2026-00001',
                'status': 'In Daily Closure',
                'created_at': '2026-05-03 10:00:00',
              },
            },
          }),
        ),
      ),
    );

    final payment = await service.collectDeliveryPayment(
      orderId: 'ORD-2026-00012',
      amount: 90,
      method: PaymentMethod.cash,
      collectedBy: _driverUser,
    );

    expect(payment.id, 'PAY-0001');
    expect(payment.collectorType, CashClosureOwnerType.driver);
    expect(payment.driverId, 'driver@awamir.plus');
    expect(payment.status, OrderPaymentStatus.inDailyClosure);
    expect(payment.postedToErpNext, isFalse);
  });

  test('getMyDailyCashClosure يستخدم ErpnextService في real mode', () async {
    final fakeService = _FakeErpnextService(
      myClosure: _localClosure(status: CashClosureStatus.open),
    );
    final repository = PaymentRepository(
      mockService: MockService(),
      erpnextService: fakeService,
      useMockData: false,
    );

    final closure = await repository.getMyDailyCashClosure(_erpUser);

    expect(fakeService.myClosureCalled, isTrue);
    expect(closure.id, 'CASH-2026-00001');
  });

  test('submitCashClosure يحول الحالة إلى Submitted To Cashier', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'message': _cashClosurePayload(
              status: 'Submitted To Cashier',
              paymentStatus: 'Submitted To Cashier',
            ),
          }),
        ),
      ),
    );

    final closure = await service.submitCashClosure(
      closureId: 'CASH-2026-00001',
      submittedBy: _erpUser,
    );

    expect(closure.status, CashClosureStatus.submittedToCashier);
    expect(
      closure.payments.single.status,
      OrderPaymentStatus.submittedToCashier,
    );
    expect(closure.payments.single.canEdit, isFalse);
  });

  test('getSubmittedCashClosures يظهر لأمين الصندوق في real mode', () async {
    final fakeService = _FakeErpnextService(
      submittedClosures: [
        _localClosure(status: CashClosureStatus.submittedToCashier),
      ],
    );
    final repository = PaymentRepository(
      mockService: MockService(),
      erpnextService: fakeService,
      useMockData: false,
    );

    final closures = await repository.getSubmittedCashClosures(_cashierUser);

    expect(fakeService.submittedClosuresCalled, isTrue);
    expect(closures.single.status, CashClosureStatus.submittedToCashier);
  });

  test('acceptCashClosure يغير حالة الدفعات إلى Cashier Accepted', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'message': _cashClosurePayload(
              status: 'Accepted',
              paymentStatus: 'Cashier Accepted',
            ),
          }),
        ),
      ),
    );

    final closure = await service.acceptCashClosure(
      closureId: 'CASH-2026-00001',
      cashier: _cashierUser,
      actualCash: 85,
      actualCard: 0,
      actualTransfer: 0,
    );

    expect(closure.status, CashClosureStatus.accepted);
    expect(closure.payments.single.status, OrderPaymentStatus.cashierAccepted);
  });

  test('قبول عهدة بفرق يحفظ differenceAmount', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'message': _cashClosurePayload(
              status: 'Has Difference',
              paymentStatus: 'Cashier Accepted',
              actualTotal: 90,
              differenceAmount: 5,
              differenceReason: 'زيادة عند العد',
            ),
          }),
        ),
      ),
    );

    final closure = await service.acceptCashClosure(
      closureId: 'CASH-2026-00001',
      cashier: _cashierUser,
      actualCash: 90,
      actualCard: 0,
      actualTransfer: 0,
      differenceReason: 'زيادة عند العد',
    );

    expect(closure.status, CashClosureStatus.hasDifference);
    expect(closure.differenceAmount, 5);
    expect(closure.differenceReason, 'زيادة عند العد');
  });

  test('returnCashClosure يتطلب reason قبل استدعاء API', () async {
    var called = false;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((_) async {
          called = true;
          return _jsonResponse({});
        }),
      ),
    );

    await expectLater(
      service.returnCashClosure(
        closureId: 'CASH-2026-00001',
        cashier: _cashierUser,
        reason: ' ',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'cash_closure_return_reason_required',
        ),
      ),
    );

    expect(called, isFalse);
  });

  test('closeCashClosure لا يعمل قبل القبول إذا رفض API', () async {
    final existingClosure = _localClosure(
      status: CashClosureStatus.submittedToCashier,
    );
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'exception':
                'Cash closure must be accepted before it can be closed.',
          }, statusCode: 417),
        ),
      ),
    );

    await expectLater(
      service.closeCashClosure(
        closureId: existingClosure.id,
        closedBy: _cashierUser,
      ),
      throwsA(isA<AppException>()),
    );

    expect(existingClosure.status, CashClosureStatus.submittedToCashier);
  });

  test(
    'getOrdersNeedingSalesOrder يستخدم ErpnextService في real mode',
    () async {
      final fakeService = _FakeErpnextService(
        accountingOrders: [_localOrder(status: OrderStatus.delivered)],
      );
      final repository = AccountingRepository(
        mockService: MockService(),
        erpnextService: fakeService,
        useMockData: false,
      );

      final orders = await repository.getOrdersNeedingSalesOrder();

      expect(fakeService.ordersNeedingSalesOrderCalled, isTrue);
      expect(orders.single.status, OrderStatus.delivered);
    },
  );

  test(
    'getPaymentsReadyForErpPosting يستخدم ErpnextService في real mode',
    () async {
      final fakeService = _FakeErpnextService(
        accountingPayments: [
          OrderPayment(
            id: 'PAY-0001',
            orderId: 'ORD-2026-00012',
            customer: 'عميل اختبار',
            amount: 85,
            method: PaymentMethod.cash,
            collectedByUserId: 'employee@awamir.plus',
            collectedByName: 'موظف فرع أوامر',
            collectorType: CashClosureOwnerType.employee,
            createdAt: DateTime(2026, 5, 3, 10),
            status: OrderPaymentStatus.readyForErpnextPosting,
          ),
        ],
      );
      final repository = AccountingRepository(
        mockService: MockService(),
        erpnextService: fakeService,
        useMockData: false,
      );

      final payments = await repository.getPaymentsReadyForErpPosting();

      expect(fakeService.paymentsReadyForErpPostingCalled, isTrue);
      expect(payments.single.status, OrderPaymentStatus.readyForErpnextPosting);
    },
  );

  test('createSalesOrderForOrder يحول استجابة ERPNext إلى Order', () async {
    late Map<String, dynamic> sentBody;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({
            'message': {
              'order_id': 'ORD-2026-00012',
              'order_number': 'ORD-2026-00012',
              'sales_order': 'SAL-ORD-2026-00001',
              'status': 'Delivered',
              'order': _orderPayload(
                status: 'Delivered',
                salesOrder: 'SAL-ORD-2026-00001',
                syncStatus: 'Partially Synced',
              ),
            },
          });
        }),
      ),
    );

    final order = await service.createSalesOrderForOrder(
      orderId: 'ORD-2026-00012',
      changedBy: _accountantUser,
    );

    expect(sentBody['order'], 'ORD-2026-00012');
    expect(order.erpnextSalesOrderId, 'SAL-ORD-2026-00001');
    expect(order.erpSyncStatus, ErpSyncStatus.partiallySynced);
  });

  test(
    'createPaymentEntryForPayment يحول الدفعة إلى Posted To ERPNext',
    () async {
      late Map<String, dynamic> sentBody;
      final service = ErpnextService(
        apiClient: ApiClient(
          baseUrl: 'https://example.com',
          cookieStore: _MemoryCookieStore(),
          httpClient: MockClient((request) async {
            sentBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse({
              'message': {
                'payment_id': 'PAY-0001',
                'payment_entry': 'ACC-PAY-2026-00001',
                'payment': {
                  'name': 'PAY-0001',
                  'order': 'ORD-2026-00012',
                  'order_number': 'ORD-2026-00012',
                  'customer': 'CUST-0001',
                  'customer_name': 'عميل أوامر التجريبي',
                  'amount': 85,
                  'payment_method': 'Cash',
                  'received_by_user': 'employee@awamir.plus',
                  'received_by_role': 'branch_employee',
                  'cash_closure': 'CASH-2026-00001',
                  'erpnext_payment_entry': 'ACC-PAY-2026-00001',
                  'status': 'Posted To ERPNext',
                  'created_at': '2026-05-03 10:00:00',
                },
              },
            });
          }),
        ),
      );

      final payment = await service.createPaymentEntryForPayment(
        paymentId: 'PAY-0001',
        changedBy: _accountantUser,
      );

      expect(sentBody['payment'], 'PAY-0001');
      expect(payment.status, OrderPaymentStatus.postedToErpNext);
      expect(payment.erpnextPaymentEntryId, 'ACC-PAY-2026-00001');
    },
  );

  test('allocateAdvancePaymentToInvoice يحول allocations من ERPNext', () async {
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'message': {
              'order': _orderPayload(
                status: 'Delivered',
                salesOrder: 'SAL-ORD-2026-00001',
                salesInvoice: 'ACC-SINV-2026-00001',
                syncStatus: 'Synced',
              ),
              'allocations': [
                {
                  'id': 'PAY-0001-ACC-SINV-2026-00001',
                  'order_id': 'ORD-2026-00012',
                  'payment_id': 'PAY-0001',
                  'sales_invoice_id': 'ACC-SINV-2026-00001',
                  'payment_entry_id': 'ACC-PAY-2026-00001',
                  'allocated_amount': 85,
                  'allocated_at': '2026-05-03 12:00:00',
                  'status': 'allocated',
                },
              ],
            },
          }),
        ),
      ),
    );

    final allocations = await service.allocateAdvancePaymentToInvoice(
      orderId: 'ORD-2026-00012',
      changedBy: _accountantUser,
    );

    expect(allocations.single.paymentId, 'PAY-0001');
    expect(allocations.single.status, PaymentAllocationStatus.allocated);
    expect(allocations.single.allocatedAmount, 85);
  });

  test('approveOrder يحول الاستجابة إلى Sent To Distribution', () async {
    late Map<String, dynamic> sentBody;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({
            'message': {
              'order_id': 'ORD-2026-00012',
              'order_number': 'ORD-2026-00012',
              'status': 'Sent To Distribution',
              'message': 'Order approved and sent to distribution.',
              'order': _orderPayload(status: 'Sent To Distribution'),
            },
          });
        }),
      ),
    );

    final order = await service.approveOrder(
      orderId: 'ORD-2026-00012',
      changedBy: _erpUser,
    );

    expect(sentBody['order'], 'ORD-2026-00012');
    expect(order.status, OrderStatus.sentToDistribution);
  });

  test('rejectOrder يرفض بدون reason قبل استدعاء API', () async {
    var called = false;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((_) async {
          called = true;
          return _jsonResponse({});
        }),
      ),
    );

    await expectLater(
      service.rejectOrder(
        orderId: 'ORD-2026-00012',
        changedBy: _erpUser,
        reason: '  ',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'rejection_reason_required',
        ),
      ),
    );

    expect(called, isFalse);
  });

  test('returnOrderForEdit يرفض بدون note قبل استدعاء API', () async {
    var called = false;
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient((_) async {
          called = true;
          return _jsonResponse({});
        }),
      ),
    );

    await expectLater(
      service.returnOrderForEdit(
        orderId: 'ORD-2026-00012',
        changedBy: _erpUser,
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

    expect(called, isFalse);
  });

  test('API error لا يغيّر الحالة المحلية للطلب', () async {
    final existingOrder = _localOrder(
      status: OrderStatus.pendingSupervisorApproval,
    );
    final service = ErpnextService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        cookieStore: _MemoryCookieStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'exception':
                'Only orders pending supervisor approval can be approved.',
          }, statusCode: 417),
        ),
      ),
    );

    await expectLater(
      service.approveOrder(orderId: existingOrder.id, changedBy: _erpUser),
      throwsA(isA<AppException>()),
    );

    expect(existingOrder.status, OrderStatus.pendingSupervisorApproval);
  });
}

class _FakeErpnextService extends ErpnextService {
  _FakeErpnextService({
    this.categories = const [],
    this.customer,
    this.supervisorOrders = const [],
    this.distributionOrders = const [],
    this.productionOrders = const [],
    this.pickupOrders = const [],
    this.driverOrders = const [],
    this.myClosure,
    this.submittedClosures = const [],
    this.accountingOrders = const [],
    this.accountingPayments = const [],
  }) : super(
         apiClient: ApiClient(
           baseUrl: 'https://example.com',
           cookieStore: _MemoryCookieStore(),
           httpClient: MockClient((_) async => http.Response('{}', 200)),
         ),
       );

  final List<ProductDepartment> categories;
  final Customer? customer;
  final List<Order> supervisorOrders;
  final List<Order> distributionOrders;
  final List<Order> productionOrders;
  final List<Order> pickupOrders;
  final List<Order> driverOrders;
  final DailyCashClosure? myClosure;
  final List<DailyCashClosure> submittedClosures;
  final List<Order> accountingOrders;
  final List<OrderPayment> accountingPayments;
  bool categoriesCalled = false;
  bool supervisorApprovalsCalled = false;
  bool distributionOrdersCalled = false;
  bool productionOrdersCalled = false;
  bool pickupOrdersCalled = false;
  bool driverOrdersCalled = false;
  bool myClosureCalled = false;
  bool submittedClosuresCalled = false;
  bool ordersNeedingSalesOrderCalled = false;
  bool paymentsReadyForErpPostingCalled = false;

  @override
  Future<List<ProductDepartment>> getCategories() async {
    categoriesCalled = true;
    return categories;
  }

  @override
  Future<Customer?> searchCustomerByPhone(String phone) async {
    return customer;
  }

  @override
  Future<List<Order>> getPendingSupervisorApprovals(AppUser user) async {
    supervisorApprovalsCalled = true;
    return supervisorOrders;
  }

  @override
  Future<List<Order>> getDistributionOrders(AppUser user) async {
    distributionOrdersCalled = true;
    return distributionOrders;
  }

  @override
  Future<List<Order>> getProductionOrders(AppUser user) async {
    productionOrdersCalled = true;
    return productionOrders;
  }

  @override
  Future<List<Order>> getPickupOrders(AppUser user) async {
    pickupOrdersCalled = true;
    return pickupOrders;
  }

  @override
  Future<List<Order>> getDriverOrders(AppUser user) async {
    driverOrdersCalled = true;
    return driverOrders;
  }

  @override
  Future<DailyCashClosure> getMyDailyCashClosure(AppUser user) async {
    myClosureCalled = true;
    return myClosure ?? _localClosure(status: CashClosureStatus.open);
  }

  @override
  Future<List<DailyCashClosure>> getSubmittedCashClosures(AppUser user) async {
    submittedClosuresCalled = true;
    return submittedClosures;
  }

  @override
  Future<List<Order>> getOrdersNeedingSalesOrder() async {
    ordersNeedingSalesOrderCalled = true;
    return accountingOrders;
  }

  @override
  Future<List<OrderPayment>> getPaymentsReadyForErpPosting() async {
    paymentsReadyForErpPostingCalled = true;
    return accountingPayments;
  }
}

http.Response _jsonResponse(
  Object payload, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(payload)),
    statusCode,
    headers: {'content-type': 'application/json', ...headers},
  );
}

class _MemoryCookieStore extends SessionCookieStore {
  _MemoryCookieStore();

  String? value;

  @override
  Future<String?> readCookieHeader() async => value;

  @override
  Future<void> saveCookieHeader(String cookieHeader) async {
    value = cookieHeader;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

CreateOrderRequest _createOrderRequest() {
  final request = CreateOrderRequest(
    createdBranch: const BranchRef(id: 'فرع المروج', name: 'فرع المروج'),
    pickupBranch: const BranchRef(id: 'فرع المروج', name: 'فرع المروج'),
  );
  request
    ..department = const ProductDepartment(
      id: 'الحلويات',
      name: 'الحلويات',
      icon: Icons.category,
    )
    ..customerPhone = '0500000001'
    ..customerName = 'عميل أوامر التجريبي'
    ..orderDetails = 'تفاصيل طلب اختبار'
    ..customerNotes = 'ملاحظات العميل'
    ..pickupDate = DateTime(2026, 5, 10)
    ..pickupTime = const TimeOfDay(hour: 18, minute: 30)
    ..depositAmount = 100
    ..paymentMethod = PaymentMethod.card
    ..transactionReference = 'TX-100';
  request.setProductQuantity(
    const Product(
      id: 1,
      itemCode: 'AWAMIR-KUNAFA',
      departmentId: 'الحلويات',
      name: 'كنافة',
      description: 'كنافة',
      price: 95,
      imageUrl: '',
    ),
    2,
  );
  return request;
}

Map<String, dynamic> _orderPayload({
  required String status,
  String productionDepartment = '',
  String assignedDriver = '',
  String salesOrder = '',
  String workOrder = '',
  String salesInvoice = '',
  String syncStatus = 'Not Synced',
  String syncError = '',
}) {
  return {
    'name': status == 'Draft' ? 'ORD-2026-00011' : 'ORD-2026-00012',
    'order_number': status == 'Draft' ? 'ORD-2026-00011' : 'ORD-2026-00012',
    'customer': 'عميل أوامر التجريبي',
    'customer_name': 'عميل أوامر التجريبي',
    'customer_phone': '0500000001',
    'customer_type': 'Individual',
    'created_branch': 'فرع المروج',
    'pickup_branch': 'فرع المروج',
    'delivery_type': 'Pickup',
    'required_date': '2026-05-10',
    'required_time': '18:30:00',
    'order_notes': 'تفاصيل طلب اختبار',
    'customer_notes': 'ملاحظات العميل',
    'status': status,
    'production_department': productionDepartment,
    'production_department_name': productionDepartment.isEmpty
        ? ''
        : 'مصنع الحلويات',
    'production_department_code': productionDepartment.isEmpty
        ? ''
        : 'SWEETS_FACTORY',
    'assigned_driver': assignedDriver,
    'assigned_driver_name': assignedDriver.isEmpty ? '' : 'سائق أوامر',
    'total_amount': 190,
    'delivery_fee': 0,
    'deposit_amount': 100,
    'remaining_amount': 90,
    'erpnext_sales_order': salesOrder,
    'erpnext_work_order': workOrder,
    'erpnext_sales_invoice': salesInvoice,
    'erp_sync_status': syncStatus,
    'erp_sync_error': syncError,
    'erp_synced_at': syncStatus == 'Not Synced' ? null : '2026-05-03 12:00:00',
    'creation': '2026-05-03 10:00:00',
    'items': [
      {
        'item_code': 'AWAMIR-KUNAFA',
        'item_name': 'كنافة',
        'description': 'كنافة',
        'qty': 2,
        'rate': 95,
        'amount': 190,
        'product_category': 'الحلويات',
      },
    ],
    'payments': [
      {'payment_method': 'Card'},
    ],
  };
}

Map<String, dynamic> _cashClosurePayload({
  required String status,
  required String paymentStatus,
  num actualTotal = 85,
  num differenceAmount = 0,
  String differenceReason = '',
}) {
  return {
    'name': 'CASH-2026-00001',
    'closure_id': 'CASH-2026-00001',
    'closure_number': 'CASH-2026-00001',
    'closure_type': 'branch_employee',
    'user': 'employee@awamir.plus',
    'owner_name': 'موظف فرع أوامر',
    'branch': 'فرع المروج',
    'date': '2026-05-03',
    'status': status,
    'total_cash': 85,
    'total_card': 0,
    'total_transfer': 0,
    'total_other': 0,
    'total_amount': 85,
    'actual_total': actualTotal,
    'difference_amount': differenceAmount,
    'difference_reason': differenceReason,
    'totals': {
      'total_cash': 85,
      'total_card': 0,
      'total_transfer': 0,
      'total_other': 0,
      'total_amount': 85,
    },
    'payments': [
      {
        'name': 'PAY-0001',
        'payment_id': 'PAY-0001',
        'order': 'ORD-2026-00005',
        'order_number': 'ORD-2026-00005',
        'customer': 'CUST-0001',
        'customer_name': 'عميل أوامر التجريبي',
        'amount': 85,
        'payment_method': 'Cash',
        'received_by_user': 'employee@awamir.plus',
        'received_by_role': 'branch_employee',
        'cash_closure': 'CASH-2026-00001',
        'status': paymentStatus,
        'created_at': '2026-05-03 10:00:00',
      },
    ],
    'logs': [
      {
        'name': 'LOG-0001',
        'closure': 'CASH-2026-00001',
        'old_status': 'Open',
        'new_status': status,
        'changed_by': 'cashier@awamir.plus',
        'created_at': '2026-05-03 10:10:00',
        'notes': 'اختبار',
      },
    ],
  };
}

const _erpUser = AppUser(
  id: 'supervisor@awamir.plus',
  fullName: 'مشرف أوامر',
  email: 'supervisor@awamir.plus',
  phone: '',
  role: UserRole.branchSupervisor,
  branchId: 'فرع المروج',
  branchName: 'فرع المروج',
  isActive: true,
);

const _distributionUser = AppUser(
  id: 'distribution@awamir.plus',
  fullName: 'مسؤول توزيع أوامر',
  email: 'distribution@awamir.plus',
  phone: '',
  role: UserRole.distributionManager,
  branchId: 'فرع المروج',
  branchName: 'فرع المروج',
  isActive: true,
);

const _productionUser = AppUser(
  id: 'production@awamir.plus',
  fullName: 'موظف إنتاج أوامر',
  email: 'production@awamir.plus',
  phone: '',
  role: UserRole.productionUser,
  branchId: 'فرع المروج',
  branchName: 'فرع المروج',
  isActive: true,
  productionDepartmentId: 'PD-SWEETS',
);

const _driverUser = AppUser(
  id: 'driver@awamir.plus',
  fullName: 'سائق أوامر',
  email: 'driver@awamir.plus',
  phone: '0500000005',
  role: UserRole.driver,
  branchId: 'فرع المروج',
  branchName: 'فرع المروج',
  isActive: true,
);

const _cashierUser = AppUser(
  id: 'cashier@awamir.plus',
  fullName: 'أمين صندوق أوامر',
  email: 'cashier@awamir.plus',
  phone: '',
  role: UserRole.cashier,
  branchId: 'فرع المروج',
  branchName: 'فرع المروج',
  isActive: true,
);

const _accountantUser = AppUser(
  id: 'accountant@awamir.plus',
  fullName: 'محاسب أوامر',
  email: 'accountant@awamir.plus',
  phone: '',
  role: UserRole.accountant,
  branchId: 'فرع المروج',
  branchName: 'فرع المروج',
  isActive: true,
);

Order _localOrder({required OrderStatus status}) {
  return Order(
    id: 'ORD-2026-00012',
    customer: 'عميل اختبار',
    productSummary: 'كنافة',
    amount: 190,
    status: status,
    date: '2026-05-03',
    progress: 1,
    paymentMethod: PaymentMethod.card,
  );
}

DailyCashClosure _localClosure({required CashClosureStatus status}) {
  return DailyCashClosure(
    id: 'CASH-2026-00001',
    date: '2026-05-03',
    ownerUserId: 'employee@awamir.plus',
    ownerName: 'موظف فرع أوامر',
    ownerRoleLabel: CashClosureOwnerType.employee.label,
    branchId: 'فرع المروج',
    branch: 'فرع المروج',
    type: CashClosureOwnerType.employee,
    status: status,
    orderCount: 1,
    entries: const [],
    payments: [
      OrderPayment(
        id: 'PAY-0001',
        orderId: 'ORD-2026-00005',
        customer: 'عميل أوامر التجريبي',
        amount: 85,
        method: PaymentMethod.cash,
        collectedByUserId: 'employee@awamir.plus',
        collectedByName: 'موظف فرع أوامر',
        collectorType: CashClosureOwnerType.employee,
        createdAt: DateTime(2026, 5, 3, 10),
      ),
    ],
    remainingFromCustomers: 0,
    collectionRate: 0,
  );
}
