import 'dart:async';

import 'package:flutter/material.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';
import '../core/utils/maps_utils.dart';
import '../core/utils/view_state.dart';
import '../models/app_models.dart';
import '../repositories/customer_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';

enum CreateOrderStep {
  category,
  customer,
  details,
  attachments,
  fulfillment,
  payment,
  review,
}

extension CreateOrderStepDetails on CreateOrderStep {
  String get label {
    switch (this) {
      case CreateOrderStep.category:
        return 'المنتجات';
      case CreateOrderStep.customer:
        return 'العميل';
      case CreateOrderStep.details:
        return 'التفاصيل';
      case CreateOrderStep.attachments:
        return 'المرفقات';
      case CreateOrderStep.fulfillment:
        return 'الاستلام';
      case CreateOrderStep.payment:
        return 'الدفع';
      case CreateOrderStep.review:
        return 'المراجعة';
    }
  }
}

class CreateOrderController extends ChangeNotifier {
  CreateOrderController({
    required this.currentUser,
    required ProductRepository productRepository,
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
    this.existingOrder,
  }) : _productRepository = productRepository,
       _customerRepository = customerRepository,
       _orderRepository = orderRepository,
       request = _buildInitialRequest(currentUser, existingOrder) {
    branches = [
      request.createdBranch,
      const BranchRef(id: 'BR-RUH-NKH', name: 'فرع الرياض — النخيل'),
      const BranchRef(id: 'BR-RUH-OLY', name: 'فرع الرياض — العليا'),
      const BranchRef(id: 'BR-JED-SAL', name: 'فرع جدة — السلامة'),
    ];
    if (existingOrder != null) {
      customerSearchState = ViewState.success(request.existingCustomer);
      currentStep = CreateOrderStep.category;
    }
    loadCategories();
  }

  final AppUser currentUser;
  final ProductRepository _productRepository;
  final CustomerRepository _customerRepository;
  final OrderRepository _orderRepository;
  final Order? existingOrder;
  final CreateOrderRequest request;

  ViewState<void> loadState = const ViewState.loading();
  ViewState<List<Product>> productsState = const ViewState.empty();
  ViewState<Customer?> customerSearchState = const ViewState.success(null);
  ViewState<void> saveState = const ViewState.success(null);

  CreateOrderStep currentStep = CreateOrderStep.category;
  String? validationMessage;
  String searchQuery = '';
  List<ProductDepartment> departments = [];
  List<Product> products = [];
  List<CustomerAddress> customerAddresses = [];
  List<BranchRef> branches = [];

  int get currentStepIndex => CreateOrderStep.values.indexOf(currentStep);
  int get totalSteps => CreateOrderStep.values.length;
  bool get isEditing => request.isEditing;
  bool get isSaving => saveState.isLoading;
  bool get isLoading => loadState.isLoading;
  bool get hasError => loadState.isError || saveState.isError;
  String? get errorMessage => saveState.message ?? loadState.message;

  List<Product> get filteredProducts {
    final query = searchQuery.trim();
    if (query.isEmpty) return products;
    return products
        .where(
          (product) =>
              product.name.contains(query) ||
              product.description.contains(query),
        )
        .toList();
  }

  Future<void> loadCategories() async {
    loadState = const ViewState.loading();
    notifyListeners();
    try {
      departments = await _productRepository.getCategories();
      _syncEditingDepartment();
      loadState = departments.isEmpty
          ? const ViewState.empty('لا توجد أقسام متاحة')
          : const ViewState.success(null);
      if (request.department != null) {
        unawaited(_hydrateExistingDraftContext());
      } else if (departments.isNotEmpty) {
        unawaited(selectDepartment(departments.first));
      }
    } on AppException catch (error) {
      loadState = ViewState.error(error.message);
    } catch (error) {
      loadState = const ViewState.error('تعذر تحميل الأقسام');
    }
    notifyListeners();
  }

  Future<void> selectDepartment(ProductDepartment department) async {
    request.department = department;
    validationMessage = null;
    searchQuery = '';
    productsState = const ViewState.loading();
    products = [];
    notifyListeners();

    try {
      products = await _productRepository.getProductsByCategory(department.id);
      productsState = products.isEmpty
          ? const ViewState.empty('لا توجد منتجات في هذا القسم')
          : ViewState.success(products);
    } on AppException catch (error) {
      productsState = ViewState.error(error.message);
    } catch (error) {
      productsState = const ViewState.error('تعذر تحميل المنتجات');
    }
    notifyListeners();
  }

  void updateSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void changeProductQuantity(Product product, int delta) {
    final nextQuantity = request.quantityFor(product) + delta;
    request.setProductQuantity(product, nextQuantity);
    validationMessage = null;
    notifyListeners();
  }

  void setCustomerType(CustomerType type) {
    request.customerType = type;
    notifyListeners();
  }

  void updateCustomerPhone(String phone) {
    request.customerPhone = normalizePhoneInput(phone);
    request.existingCustomer = null;
    validationMessage = null;
    notifyListeners();
  }

  Future<void> updatePhoneAndSearch(String phone) async {
    request.customerPhone = normalizePhoneInput(phone);
    validationMessage = null;
    notifyListeners();

    if (request.customerPhone.length < 7) return;

    await searchCurrentCustomer();
  }

  Future<void> searchCurrentCustomer() async {
    final phone = normalizePhoneInput(request.customerPhone);
    request.customerPhone = phone;
    if (!_validate(phone.isNotEmpty, 'رقم الجوال مطلوب للبحث')) {
      notifyListeners();
      return;
    }

    customerSearchState = const ViewState.loading();
    notifyListeners();

    try {
      final customer = await _customerRepository.searchCustomerByPhone(phone);
      request.existingCustomer = customer;
      if (customer != null) {
        request.customerName = customer.name;
        request.customerType = customer.isCompany
            ? CustomerType.company
            : CustomerType.individual;
        request.companyName = customer.companyName;
        request.taxNumber = customer.taxNumber;
        request.companyAddress = customer.address;
        request.companyEmail = customer.email;
        request.companyContactPerson = customer.contactPerson;
        customerAddresses = await _customerRepository.getCustomerAddresses(
          customer.id,
        );
        customerSearchState = ViewState.success(customer);
      } else {
        customerAddresses = [];
        customerSearchState = const ViewState.empty('العميل غير موجود');
      }
    } on AppException catch (error) {
      customerSearchState = ViewState.error(error.message);
    } catch (error) {
      customerSearchState = const ViewState.error('تعذر البحث عن العميل');
    }

    notifyListeners();
  }

  void updateCustomerName(String value) {
    request.customerName = value;
    notifyListeners();
  }

  void updateCompany({
    String? companyName,
    String? taxNumber,
    String? address,
    String? email,
    String? contactPerson,
  }) {
    request.companyName = companyName ?? request.companyName;
    request.taxNumber = taxNumber ?? request.taxNumber;
    request.companyAddress = address ?? request.companyAddress;
    request.companyEmail = email ?? request.companyEmail;
    request.companyContactPerson =
        contactPerson ?? request.companyContactPerson;
    notifyListeners();
  }

  void updateOrderDetails({String? details, String? notes}) {
    request.orderDetails = details ?? request.orderDetails;
    request.customerNotes = notes ?? request.customerNotes;
    notifyListeners();
  }

  void updatePickupDate(DateTime date) {
    request.pickupDate = date;
    validationMessage = null;
    notifyListeners();
  }

  void updatePickupTime(TimeOfDay time) {
    request.pickupTime = time;
    validationMessage = null;
    notifyListeners();
  }

  void updatePriority(OrderPriority priority) {
    request.priority = priority;
    validationMessage = null;
    notifyListeners();
  }

  void updateScheduledAt(DateTime? value) {
    request.scheduledAt = value;
    validationMessage = null;
    notifyListeners();
  }

  void updatePickupTimeOverride(TimeOfDay? value) {
    request.pickupTimeOverride = value;
    validationMessage = null;
    notifyListeners();
  }

  void updateDeliveryWindow({DateTime? start, DateTime? end}) {
    request.deliveryWindowStart = start ?? request.deliveryWindowStart;
    request.deliveryWindowEnd = end ?? request.deliveryWindowEnd;
    validationMessage = null;
    notifyListeners();
  }

  bool addAttachment(OrderAttachmentDraft attachment) {
    if (!attachment.isValidType) {
      validationMessage = 'نوع الملف غير مدعوم';
      notifyListeners();
      return false;
    }
    if (!attachment.isValidSize) {
      validationMessage = 'حجم الملف يجب ألا يتجاوز 5MB';
      notifyListeners();
      return false;
    }

    request.attachments.add(attachment);
    validationMessage = null;
    notifyListeners();
    return true;
  }

  void addMockAttachment(OrderAttachmentType type) {
    final extension = type == OrderAttachmentType.pdf ? 'pdf' : 'jpg';
    addAttachment(
      OrderAttachmentDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: type == OrderAttachmentType.pdf
            ? 'ملف_طلب.$extension'
            : 'صورة_طلب.$extension',
        path: '/mock/order_attachment.$extension',
        type: type,
        sizeInBytes: type == OrderAttachmentType.pdf ? 450000 : 320000,
      ),
    );
  }

  void removeAttachment(String id) {
    request.attachments.removeWhere((attachment) => attachment.id == id);
    notifyListeners();
  }

  void setFulfillmentType(FulfillmentType type) {
    request.fulfillmentType = type;
    if (type == FulfillmentType.branchPickup) {
      request.pickupBranch = request.createdBranch;
    }
    validationMessage = null;
    notifyListeners();
  }

  void setPickupBranch(BranchRef branch) {
    request.pickupBranch = branch;
    notifyListeners();
  }

  void applySavedAddress(CustomerAddress address) {
    request.deliveryDetails = DeliveryDetailsDraft(
      savedAddressId: address.id,
      addressText: address.details,
      district: address.district,
      city: address.city,
      postalCode: address.postalCode,
      googleMapsUrl: address.googleMapsUrl,
      latitude: address.latitude,
      longitude: address.longitude,
      notes: address.notes,
      deliveryFee: request.deliveryDetails.deliveryFee,
    );
    validationMessage = null;
    notifyListeners();
  }

  void updateDelivery({
    String? addressText,
    String? district,
    String? city,
    String? postalCode,
    String? googleMapsUrl,
    String? notes,
    num? deliveryFee,
  }) {
    double? latitude = request.deliveryDetails.latitude;
    double? longitude = request.deliveryDetails.longitude;
    if (googleMapsUrl != null) {
      final point = extractGoogleMapsCoordinates(googleMapsUrl);
      if (point != null) {
        latitude = point.latitude;
        longitude = point.longitude;
      }
    }

    request.deliveryDetails = request.deliveryDetails.copyWith(
      addressText: addressText,
      district: district,
      city: city,
      postalCode: postalCode,
      googleMapsUrl: googleMapsUrl,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      deliveryFee: deliveryFee,
      clearSavedAddress: addressText != null || googleMapsUrl != null,
    );
    validationMessage = null;
    notifyListeners();
  }

  void updatePayment({
    num? depositAmount,
    PaymentMethod? method,
    String? transactionReference,
    OrderAttachmentDraft? receipt,
  }) {
    request.depositAmount = depositAmount ?? request.depositAmount;
    request.paymentMethod = method ?? request.paymentMethod;
    request.transactionReference =
        transactionReference ?? request.transactionReference;
    request.paymentReceipt = receipt ?? request.paymentReceipt;
    validationMessage = null;
    notifyListeners();
  }

  void clearPaymentReceipt() {
    request.paymentReceipt = null;
    validationMessage = null;
    notifyListeners();
  }

  bool nextStep() {
    if (!validateCurrentStep()) {
      notifyListeners();
      return false;
    }
    if (currentStepIndex < totalSteps - 1) {
      currentStep = CreateOrderStep.values[currentStepIndex + 1];
      validationMessage = null;
      notifyListeners();
    }
    return true;
  }

  void previousStep() {
    if (currentStepIndex > 0) {
      currentStep = CreateOrderStep.values[currentStepIndex - 1];
      validationMessage = null;
      notifyListeners();
    }
  }

  bool validateCurrentStep() => validateStep(currentStep);

  bool validateStep(CreateOrderStep step) {
    switch (step) {
      case CreateOrderStep.category:
        return _validate(request.hasProducts, 'اختر منتجاً واحداً على الأقل');
      case CreateOrderStep.customer:
        if (!_validate(
          request.customerPhone.trim().isNotEmpty,
          'رقم الجوال مطلوب',
        )) {
          return false;
        }
        if (!_validate(
          request.customerName.trim().isNotEmpty ||
              request.companyName.trim().isNotEmpty,
          'اسم العميل مطلوب',
        )) {
          return false;
        }
        if (request.customerType == CustomerType.company) {
          return _validate(
            request.companyName.trim().isNotEmpty &&
                request.taxNumber.trim().isNotEmpty &&
                request.companyAddress.trim().isNotEmpty &&
                request.companyEmail.trim().isNotEmpty &&
                request.companyContactPerson.trim().isNotEmpty,
            'أكمل بيانات الشركة',
          );
        }
        return true;
      case CreateOrderStep.details:
        if (!_validate(
          request.orderDetails.trim().isNotEmpty,
          'تفاصيل الطلب مطلوبة',
        )) {
          return false;
        }
        if (!_validate(request.pickupDate != null, 'تاريخ الاستلام مطلوب')) {
          return false;
        }
        if (!_validate(request.pickupTime != null, 'وقت الاستلام مطلوب')) {
          return false;
        }
        final selectedDate = DateUtils.dateOnly(request.pickupDate!);
        final today = DateUtils.dateOnly(DateTime.now());
        if (!_validate(
          !selectedDate.isBefore(today),
          'لا يسمح بتاريخ استلام سابق',
        )) {
          return false;
        }
        if (request.deliveryWindowStart != null &&
            request.deliveryWindowEnd != null &&
            !request.deliveryWindowEnd!.isAfter(request.deliveryWindowStart!)) {
          return _validate(
            false,
            'نهاية نافذة التوصيل يجب أن تكون بعد البداية',
          );
        }
        return true;
      case CreateOrderStep.attachments:
        for (final attachment in request.attachments) {
          if (!_validate(attachment.isValidType, 'يوجد ملف غير مدعوم')) {
            return false;
          }
          if (!_validate(attachment.isValidSize, 'يوجد ملف حجمه أكبر من 5MB')) {
            return false;
          }
        }
        return true;
      case CreateOrderStep.fulfillment:
        if (request.fulfillmentType == FulfillmentType.branchPickup) {
          return _validate(
            request.createdBranch.id.isNotEmpty &&
                request.pickupBranch.id.isNotEmpty,
            'اختر فرع الاستلام',
          );
        }
        return _validate(
          request.deliveryDetails.hasAddressOrLocation,
          'أدخل عنوان التوصيل أو رابط الموقع',
        );
      case CreateOrderStep.payment:
        if (!_validate(
          request.depositAmount >= 0,
          'مبلغ العربون يجب أن يكون صفراً أو أكثر',
        )) {
          return false;
        }
        if (!_validate(
          request.depositAmount <= request.grandTotal,
          'العربون لا يمكن أن يتجاوز إجمالي الطلب ورسوم التوصيل',
        )) {
          return false;
        }
        if (request.requiresTransactionReference) {
          return _validate(
            request.transactionReference.trim().isNotEmpty,
            'رقم العملية مطلوب لطريقة الدفع المختارة',
          );
        }
        final receipt = request.paymentReceipt;
        if (receipt != null) {
          if (!_validate(receipt.isValidType, 'نوع إيصال الدفع غير مدعوم')) {
            return false;
          }
          if (!_validate(receipt.isValidSize, 'حجم إيصال الدفع أكبر من 5MB')) {
            return false;
          }
        }
        return true;
      case CreateOrderStep.review:
        return true;
    }
  }

  Future<Order?> saveDraft() => _save(_SaveMode.draft);

  Future<Order?> submitForApproval() => _save(_SaveMode.pendingApproval);

  Future<Order?> _save(_SaveMode mode) async {
    for (final step in CreateOrderStep.values) {
      currentStep = step;
      if (!validateCurrentStep()) {
        notifyListeners();
        return null;
      }
    }

    currentStep = CreateOrderStep.review;
    saveState = const ViewState.loading();
    notifyListeners();

    try {
      final order = mode == _SaveMode.draft
          ? await _orderRepository.saveDraft(request)
          : await _orderRepository.submitForApproval(request);
      saveState = const ViewState.success(null);
      notifyListeners();
      return order;
    } on AppException catch (error) {
      saveState = ViewState.error(error.message);
    } catch (error) {
      saveState = const ViewState.error('تعذر حفظ الطلب');
    }

    notifyListeners();
    return null;
  }

  bool _validate(bool condition, String message) {
    if (condition) {
      validationMessage = null;
      return true;
    }
    validationMessage = message;
    return false;
  }

  Future<void> _hydrateExistingDraftContext() async {
    await _loadExistingDepartmentProducts();
    await _loadExistingCustomerAddresses();
  }

  Future<void> _loadExistingDepartmentProducts() async {
    final department = request.department;
    if (department == null) return;

    final existingLines = List<OrderLineDraft>.of(request.lineItems);
    final quantitiesByKey = {
      for (final line in existingLines)
        _productKey(line.product): line.quantity,
    };

    productsState = const ViewState.loading();
    notifyListeners();

    try {
      final fetchedProducts = await _productRepository.getProductsByCategory(
        department.id,
      );
      products = _mergeProducts(fetchedProducts, existingLines);
      request.lines.clear();
      for (final product in products) {
        final quantity = quantitiesByKey[_productKey(product)];
        if (quantity != null) {
          request.setProductQuantity(product, quantity);
        }
      }
      productsState = products.isEmpty
          ? const ViewState.empty('لا توجد منتجات في هذا القسم')
          : ViewState.success(products);
    } on AppException catch (error) {
      productsState = ViewState.error(error.message);
    } catch (error) {
      productsState = const ViewState.error('تعذر تحميل المنتجات');
    }
    notifyListeners();
  }

  Future<void> _loadExistingCustomerAddresses() async {
    final customer = request.existingCustomer;
    if (customer == null || customer.id.trim().isEmpty) return;

    try {
      customerAddresses = await _customerRepository.getCustomerAddresses(
        customer.id,
      );
      notifyListeners();
    } on AppException {
      customerAddresses = [];
      notifyListeners();
    } catch (_) {
      customerAddresses = [];
      notifyListeners();
    }
  }

  void _syncEditingDepartment() {
    final department = request.department;
    if (department == null) return;
    for (final candidate in departments) {
      if (candidate.id == department.id) {
        request.department = candidate;
        break;
      }
    }
  }

  List<Product> _mergeProducts(
    List<Product> fetchedProducts,
    List<OrderLineDraft> existingLines,
  ) {
    if (fetchedProducts.isEmpty) {
      return existingLines.map((line) => line.product).toList();
    }
    final merged = List<Product>.of(fetchedProducts);
    final seenKeys = merged.map(_productKey).toSet();
    for (final line in existingLines) {
      final key = _productKey(line.product);
      if (seenKeys.add(key)) {
        merged.add(line.product);
      }
    }
    return merged;
  }

  String _productKey(Product product) {
    final itemCode = product.itemCode.trim();
    return itemCode.isNotEmpty ? itemCode : product.name.trim();
  }

  static CreateOrderRequest _buildInitialRequest(
    AppUser currentUser,
    Order? existingOrder,
  ) {
    final branch = BranchRef(
      id: currentUser.branchId,
      name: currentUser.branchName,
    );
    final request = CreateOrderRequest(
      createdBranch: branch,
      pickupBranch: branch,
    );
    request.createdByUserId = currentUser.id;
    request.createdByName = currentUser.fullName;

    if (existingOrder == null) {
      return request;
    }

    request.editingOrderId = existingOrder.id;
    request.department = existingOrder.categoryId.trim().isEmpty
        ? null
        : ProductDepartment(
            id: existingOrder.categoryId,
            name: existingOrder.categoryName.trim().isEmpty
                ? existingOrder.categoryId
                : existingOrder.categoryName,
            icon: Icons.category_outlined,
          );
    for (final line in existingOrder.lineItems) {
      request.setProductQuantity(line.product, line.quantity);
    }
    request.customerPhone = existingOrder.customerPhone;
    request.customerName = existingOrder.customer;
    request.customerType = existingOrder.customerType;
    request.companyName = existingOrder.companyName;
    request.taxNumber = existingOrder.taxNumber;
    request.companyAddress = existingOrder.companyAddress;
    request.companyEmail = existingOrder.companyEmail;
    request.companyContactPerson = existingOrder.companyContactPerson;
    request.existingCustomer = existingOrder.erpnextCustomerId.trim().isEmpty
        ? null
        : Customer(
            id: existingOrder.erpnextCustomerId,
            name: existingOrder.customer,
            phone: existingOrder.customerPhone,
            isCompany: existingOrder.customerType == CustomerType.company,
            companyName: existingOrder.companyName,
            taxNumber: existingOrder.taxNumber,
            address: existingOrder.companyAddress,
            email: existingOrder.companyEmail,
            contactPerson: existingOrder.companyContactPerson,
          );
    request.orderDetails = existingOrder.details;
    request.customerNotes = existingOrder.customerNotes;
    request.pickupDate = existingOrder.pickupDate;
    request.pickupTime = existingOrder.pickupTime;
    request.priority = existingOrder.priority;
    request.scheduledAt = existingOrder.scheduledAt;
    request.pickupTimeOverride = existingOrder.pickupTimeOverride;
    request.deliveryWindowStart = existingOrder.deliveryWindowStart;
    request.deliveryWindowEnd = existingOrder.deliveryWindowEnd;
    request.attachments.addAll(existingOrder.attachments);
    request.fulfillmentType = existingOrder.fulfillmentType;
    request.createdBranch = BranchRef(
      id: existingOrder.createdBranchId.trim().isEmpty
          ? branch.id
          : existingOrder.createdBranchId,
      name: existingOrder.createdBranch.trim().isEmpty
          ? branch.name
          : existingOrder.createdBranch,
    );
    request.pickupBranch = BranchRef(
      id: existingOrder.pickupBranchId.trim().isEmpty
          ? request.createdBranch.id
          : existingOrder.pickupBranchId,
      name: existingOrder.pickupBranch.trim().isEmpty
          ? request.createdBranch.name
          : existingOrder.pickupBranch,
    );
    request.deliveryDetails = existingOrder.deliveryDetails;
    request.depositAmount = existingOrder.depositAmount;
    request.paymentMethod = existingOrder.paymentMethod;
    request.transactionReference = existingOrder.transactionReference;
    if (existingOrder.paymentReceiptPath.trim().isNotEmpty) {
      request.paymentReceipt = OrderAttachmentDraft(
        id: '${existingOrder.id}-receipt',
        name: 'receipt.jpg',
        path: existingOrder.paymentReceiptPath,
        type: OrderAttachmentType.receipt,
        sizeInBytes: 0,
      );
    }
    return request;
  }
}

enum _SaveMode { draft, pendingApproval }
