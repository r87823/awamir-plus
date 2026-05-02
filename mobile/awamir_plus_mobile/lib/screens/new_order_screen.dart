import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/create_order_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/view_state.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/product_card.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import 'order_detail_screen.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({
    super.key,
    required this.controller,
    required this.onFinished,
  });

  final AppController controller;
  final VoidCallback onFinished;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  late final CreateOrderController _flow;
  Timer? _phoneSearchDebounce;

  final _phoneController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyContactController = TextEditingController();
  final _detailsController = TextEditingController();
  final _notesController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _deliveryDistrictController = TextEditingController();
  final _deliveryCityController = TextEditingController();
  final _deliveryPostalController = TextEditingController();
  final _mapsController = TextEditingController();
  final _deliveryNotesController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _depositController = TextEditingController();
  final _transactionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _flow = CreateOrderController(
      currentUser: widget.controller.currentUser,
      productRepository: widget.controller.productRepository,
      customerRepository: widget.controller.customerRepository,
      orderRepository: widget.controller.orderRepository,
    );
  }

  @override
  void dispose() {
    _phoneSearchDebounce?.cancel();
    _flow.dispose();
    _phoneController.dispose();
    _customerNameController.dispose();
    _companyNameController.dispose();
    _taxNumberController.dispose();
    _companyAddressController.dispose();
    _companyEmailController.dispose();
    _companyContactController.dispose();
    _detailsController.dispose();
    _notesController.dispose();
    _deliveryAddressController.dispose();
    _deliveryDistrictController.dispose();
    _deliveryCityController.dispose();
    _deliveryPostalController.dispose();
    _mapsController.dispose();
    _deliveryNotesController.dispose();
    _deliveryFeeController.dispose();
    _depositController.dispose();
    _transactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canCreateOrder(widget.controller.currentUser)) {
      return const AccessDeniedStateView();
    }

    return AnimatedBuilder(
      animation: _flow,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  AppHeader(
                    title: 'إنشاء طلب جديد',
                    subtitle: 'طلب متكامل بخطوات واضحة',
                    notificationCount: widget.controller.unreadNotifications,
                  ),
                  const SizedBox(height: 14),
                  _StepIndicator(flow: _flow),
                  if (_flow.validationMessage != null)
                    _InlineMessage(
                      icon: Icons.info_outline,
                      message: _flow.validationMessage!,
                      color: AppColors.red,
                    ),
                  if (_flow.errorMessage != null)
                    _InlineMessage(
                      icon: Icons.error_outline,
                      message: _flow.errorMessage!,
                      color: AppColors.red,
                    ),
                  _buildCurrentStep(),
                  const SizedBox(height: 22),
                ],
              ),
            ),
            _FlowFooter(
              flow: _flow,
              onPrevious: _flow.previousStep,
              onNext: () {
                if (!_flow.nextStep()) _showValidation();
              },
              onSaveDraft: () => _handleSave(draft: true),
              onSubmit: () => _handleSave(draft: false),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrentStep() {
    switch (_flow.currentStep) {
      case CreateOrderStep.category:
        return _buildCategoryStep();
      case CreateOrderStep.products:
        return _buildProductsStep();
      case CreateOrderStep.customer:
        return _buildCustomerStep();
      case CreateOrderStep.details:
        return _buildDetailsStep();
      case CreateOrderStep.attachments:
        return _buildAttachmentsStep();
      case CreateOrderStep.fulfillment:
        return _buildFulfillmentStep();
      case CreateOrderStep.payment:
        return _buildPaymentStep();
      case CreateOrderStep.review:
        return _buildReviewStep();
    }
  }

  Widget _buildCategoryStep() {
    if (_flow.loadState.isLoading) {
      return const _StepCard(
        title: 'نوع الطلب / القسم',
        icon: Icons.category_outlined,
        child: SizedBox(height: 220, child: LoadingStateView()),
      );
    }
    if (_flow.loadState.isError) {
      return _StepCard(
        title: 'نوع الطلب / القسم',
        icon: Icons.category_outlined,
        child: SizedBox(
          height: 240,
          child: ErrorStateView(
            message: _flow.loadState.message ?? 'تعذر تحميل الأقسام',
            onRetry: _flow.loadCategories,
          ),
        ),
      );
    }
    if (_flow.departments.isEmpty) {
      return const _StepCard(
        title: 'نوع الطلب / القسم',
        icon: Icons.category_outlined,
        child: SizedBox(
          height: 220,
          child: EmptyStateView(message: 'لا توجد أقسام متاحة'),
        ),
      );
    }

    return _StepCard(
      title: 'نوع الطلب / القسم',
      icon: Icons.category_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 620 ? 3 : 2;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.18,
            children: _flow.departments.map((department) {
              return _DepartmentCard(
                department: department,
                selected: _flow.request.department?.id == department.id,
                onTap: () => _flow.selectDepartment(department),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildProductsStep() {
    Widget content;
    if (_flow.productsState.isLoading) {
      content = const SizedBox(height: 260, child: LoadingStateView());
    } else if (_flow.productsState.isError) {
      content = SizedBox(
        height: 260,
        child: ErrorStateView(
          message: _flow.productsState.message ?? 'تعذر تحميل المنتجات',
          onRetry: () {
            final department = _flow.request.department;
            if (department != null) _flow.selectDepartment(department);
          },
        ),
      );
    } else {
      final products = _flow.filteredProducts;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: _flow.updateSearch,
            decoration: const InputDecoration(
              labelText: 'البحث في المنتجات',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 14),
          if (products.isEmpty)
            const SizedBox(
              height: 220,
              child: EmptyStateView(message: 'لا توجد منتجات في هذا القسم'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 680 ? 3 : 2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.68,
                  children: products.map((product) {
                    final quantity = _flow.request.quantityFor(product);
                    return ProductCard(
                      product: product,
                      quantity: quantity,
                      onAdd: () => _flow.changeProductQuantity(product, 1),
                      onIncrement: () =>
                          _flow.changeProductQuantity(product, 1),
                      onDecrement: () =>
                          _flow.changeProductQuantity(product, -1),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 14),
          _TotalStrip(
            itemsCount: _flow.request.itemsCount,
            total: _flow.request.productsTotal,
          ),
        ],
      );
    }

    return _StepCard(
      title: 'اختيار المنتجات',
      icon: Icons.inventory_2_outlined,
      child: content,
    );
  }

  Widget _buildCustomerStep() {
    final isCompany = _flow.request.customerType == CustomerType.company;

    return _StepCard(
      title: 'بيانات العميل',
      icon: Icons.person_search_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: _handlePhoneChanged,
                  onSubmitted: (_) => _searchCustomer(),
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال',
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 106,
                child: ElevatedButton(
                  onPressed: _flow.customerSearchState.isLoading
                      ? null
                      : _searchCustomer,
                  child: _flow.customerSearchState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('بحث'),
                ),
              ),
            ],
          ),
          if (_flow.customerSearchState.status == ViewStatus.success &&
              _flow.request.existingCustomer != null)
            const _InlineMessage(
              icon: Icons.verified_outlined,
              message: 'تم العثور على العميل وتعبئة البيانات',
              color: AppColors.green,
            ),
          if (_flow.customerSearchState.isEmpty)
            const _InlineMessage(
              icon: Icons.person_add_alt,
              message: 'العميل غير موجود، أدخل بيانات عميل جديد',
              color: AppColors.goldDark,
            ),
          const SizedBox(height: 14),
          _SegmentedChoice<CustomerType>(
            values: CustomerType.values,
            selected: _flow.request.customerType,
            labelOf: (type) => type.label,
            iconOf: (type) => type == CustomerType.individual
                ? Icons.person_outline
                : Icons.apartment_outlined,
            onChanged: _flow.setCustomerType,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _customerNameController,
            onChanged: _flow.updateCustomerName,
            decoration: InputDecoration(
              labelText: isCompany ? 'اسم مسؤول التواصل' : 'اسم العميل',
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          if (isCompany) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _companyNameController,
              onChanged: (value) => _flow.updateCompany(companyName: value),
              decoration: const InputDecoration(
                labelText: 'اسم الشركة',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _taxNumberController,
              keyboardType: TextInputType.number,
              onChanged: (value) => _flow.updateCompany(taxNumber: value),
              decoration: const InputDecoration(
                labelText: 'الرقم الضريبي',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _companyAddressController,
              onChanged: (value) => _flow.updateCompany(address: value),
              decoration: const InputDecoration(
                labelText: 'العنوان',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _companyEmailController,
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => _flow.updateCompany(email: value),
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _companyContactController,
              onChanged: (value) => _flow.updateCompany(contactPerson: value),
              decoration: const InputDecoration(
                labelText: 'اسم مسؤول التواصل',
                prefixIcon: Icon(Icons.support_agent_outlined),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return _StepCard(
      title: 'تفاصيل الطلب',
      icon: Icons.edit_note_outlined,
      child: Column(
        children: [
          TextField(
            controller: _detailsController,
            maxLines: 4,
            onChanged: (value) => _flow.updateOrderDetails(details: value),
            decoration: const InputDecoration(
              labelText: 'تفاصيل الطلب',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 3,
            onChanged: (value) => _flow.updateOrderDetails(notes: value),
            decoration: const InputDecoration(
              labelText: 'ملاحظات العميل',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'تاريخ الاستلام',
                  value: _flow.request.pickupDate == null
                      ? 'اختر التاريخ'
                      : formatDate(_flow.request.pickupDate!),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.schedule_outlined,
                  label: 'وقت الاستلام',
                  value: _flow.request.pickupTime == null
                      ? 'اختر الوقت'
                      : formatTime(_flow.request.pickupTime!),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsStep() {
    return _StepCard(
      title: 'المرفقات',
      icon: Icons.attach_file_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _flow.addMockAttachment(OrderAttachmentType.image),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('إضافة صورة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _flow.addMockAttachment(OrderAttachmentType.pdf),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('إضافة PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AttachmentList(
            attachments: _flow.request.attachments,
            onRemove: _flow.removeAttachment,
          ),
        ],
      ),
    );
  }

  Widget _buildFulfillmentStep() {
    final isDelivery =
        _flow.request.fulfillmentType == FulfillmentType.customerDelivery;

    return _StepCard(
      title: 'طريقة الاستلام أو التوصيل',
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SegmentedChoice<FulfillmentType>(
            values: FulfillmentType.values,
            selected: _flow.request.fulfillmentType,
            labelOf: (type) => type.label,
            iconOf: (type) => type == FulfillmentType.branchPickup
                ? Icons.storefront_outlined
                : Icons.delivery_dining_outlined,
            onChanged: _flow.setFulfillmentType,
          ),
          const SizedBox(height: 14),
          if (!isDelivery) _buildBranchPickupFields(),
          if (isDelivery) _buildDeliveryFields(),
        ],
      ),
    );
  }

  Widget _buildBranchPickupFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadonlyInfo(
          icon: Icons.add_business_outlined,
          label: 'فرع إنشاء الطلب',
          value: _flow.request.createdBranch.name,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<BranchRef>(
          initialValue: _flow.request.pickupBranch,
          decoration: const InputDecoration(
            labelText: 'فرع الاستلام',
            prefixIcon: Icon(Icons.store_outlined),
          ),
          items: _flow.branches.map((branch) {
            return DropdownMenuItem(value: branch, child: Text(branch.name));
          }).toList(),
          onChanged: (branch) {
            if (branch != null) _flow.setPickupBranch(branch);
          },
        ),
      ],
    );
  }

  Widget _buildDeliveryFields() {
    final delivery = _flow.request.deliveryDetails;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_flow.customerAddresses.isNotEmpty) ...[
          DropdownButtonFormField<CustomerAddress>(
            decoration: const InputDecoration(
              labelText: 'العناوين المحفوظة',
              prefixIcon: Icon(Icons.bookmark_outline),
            ),
            items: _flow.customerAddresses.map((address) {
              return DropdownMenuItem(
                value: address,
                child: Text('${address.title} — ${address.city}'),
              );
            }).toList(),
            onChanged: (address) {
              if (address != null) {
                _flow.applySavedAddress(address);
                _syncDeliveryControllers();
              }
            },
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _deliveryAddressController,
          onChanged: (value) => _flow.updateDelivery(addressText: value),
          decoration: const InputDecoration(
            labelText: 'العنوان النصي',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _deliveryDistrictController,
                onChanged: (value) => _flow.updateDelivery(district: value),
                decoration: const InputDecoration(labelText: 'الحي'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _deliveryCityController,
                onChanged: (value) => _flow.updateDelivery(city: value),
                decoration: const InputDecoration(labelText: 'المدينة'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _deliveryPostalController,
          keyboardType: TextInputType.number,
          onChanged: (value) => _flow.updateDelivery(postalCode: value),
          decoration: const InputDecoration(
            labelText: 'الرمز البريدي',
            prefixIcon: Icon(Icons.local_post_office_outlined),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _mapsController,
          onChanged: (value) {
            _flow.updateDelivery(googleMapsUrl: value);
            _syncCoordinatesOnly();
          },
          decoration: const InputDecoration(
            labelText: 'رابط Google Maps',
            prefixIcon: Icon(Icons.map_outlined),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ReadonlyInfo(
                icon: Icons.my_location_outlined,
                label: 'Latitude',
                value: delivery.latitude?.toStringAsFixed(6) ?? '-',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReadonlyInfo(
                icon: Icons.explore_outlined,
                label: 'Longitude',
                value: delivery.longitude?.toStringAsFixed(6) ?? '-',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _deliveryNotesController,
          maxLines: 2,
          onChanged: (value) => _flow.updateDelivery(notes: value),
          decoration: const InputDecoration(
            labelText: 'ملاحظات التوصيل',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _deliveryFeeController,
          keyboardType: TextInputType.number,
          onChanged: (value) =>
              _flow.updateDelivery(deliveryFee: _parseAmount(value)),
          decoration: const InputDecoration(
            labelText: 'رسوم التوصيل',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStep() {
    return _StepCard(
      title: 'العربون والدفع',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PaymentTotals(request: _flow.request),
          const SizedBox(height: 14),
          TextField(
            controller: _depositController,
            keyboardType: TextInputType.number,
            onChanged: (value) =>
                _flow.updatePayment(depositAmount: _parseAmount(value)),
            decoration: const InputDecoration(
              labelText: 'مبلغ العربون',
              prefixIcon: Icon(Icons.savings_outlined),
            ),
          ),
          const SizedBox(height: 14),
          PaymentMethodSelector(
            selectedMethod: _flow.request.paymentMethod,
            onChanged: (method) => _flow.updatePayment(method: method),
          ),
          if (_flow.request.requiresTransactionReference) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _transactionController,
              onChanged: (value) =>
                  _flow.updatePayment(transactionReference: value),
              decoration: const InputDecoration(
                labelText: 'رقم العملية',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addReceipt,
            icon: const Icon(Icons.receipt_outlined),
            label: Text(
              _flow.request.paymentReceipt == null
                  ? 'إرفاق إيصال'
                  : 'استبدال الإيصال',
            ),
          ),
          if (_flow.request.paymentReceipt != null)
            _AttachmentList(
              attachments: [_flow.request.paymentReceipt!],
              onRemove: (_) => _flow.clearPaymentReceipt(),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final request = _flow.request;
    final fulfillmentValue =
        request.fulfillmentType == FulfillmentType.branchPickup
        ? request.pickupBranch.name
        : [
            request.deliveryDetails.addressText,
            request.deliveryDetails.district,
            request.deliveryDetails.city,
          ].where((part) => part.trim().isNotEmpty).join('، ');

    return _StepCard(
      title: 'المراجعة النهائية',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewSection(
            title: 'العميل',
            children: [
              _SummaryRow(label: 'رقم الجوال', value: request.customerPhone),
              _SummaryRow(
                label: 'اسم العميل',
                value: request.customerName.trim().isEmpty
                    ? request.companyName
                    : request.customerName,
              ),
              _SummaryRow(
                label: 'نوع العميل',
                value: request.customerType.label,
              ),
              if (request.customerType == CustomerType.company)
                _SummaryRow(label: 'اسم الشركة', value: request.companyName),
            ],
          ),
          _ReviewSection(
            title: 'المنتجات',
            children: [
              ...request.lineItems.map((line) {
                return _SummaryRow(
                  label: '${line.product.name} × ${line.quantity}',
                  value: formatCurrency(line.subtotal),
                );
              }),
              _SummaryRow(
                label: 'الإجمالي',
                value: formatCurrency(request.productsTotal),
              ),
            ],
          ),
          _ReviewSection(
            title: 'الاستلام والدفع',
            children: [
              _SummaryRow(
                label: 'التاريخ والوقت',
                value: [
                  if (request.pickupDate != null)
                    formatDate(request.pickupDate!),
                  if (request.pickupTime != null)
                    formatTime(request.pickupTime!),
                ].join(' — '),
              ),
              _SummaryRow(
                label: 'طريقة الاستلام',
                value: request.fulfillmentType.label,
              ),
              _SummaryRow(label: 'الفرع / العنوان', value: fulfillmentValue),
              _SummaryRow(
                label: 'إجمالي الطلب',
                value: formatCurrency(request.grandTotal),
              ),
              _SummaryRow(
                label: 'العربون',
                value: formatCurrency(request.depositAmount),
              ),
              _SummaryRow(
                label: 'المتبقي',
                value: formatCurrency(request.remainingAmount),
              ),
            ],
          ),
          _ReviewSection(
            title: 'التفاصيل والمرفقات',
            children: [
              _SummaryRow(label: 'تفاصيل الطلب', value: request.orderDetails),
              _SummaryRow(
                label: 'ملاحظات العميل',
                value: request.customerNotes.trim().isEmpty
                    ? 'لا توجد'
                    : request.customerNotes,
              ),
              _SummaryRow(
                label: 'المرفقات',
                value: request.attachments.isEmpty
                    ? 'لا توجد'
                    : '${request.attachments.length} مرفق',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _searchCustomer() async {
    _flow.updateCustomerPhone(_phoneController.text);
    await _flow.searchCurrentCustomer();
    _syncCustomerControllers();
    _syncDeliveryControllers();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _flow.request.pickupDate ?? now,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) _flow.updatePickupDate(date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _flow.request.pickupTime ?? TimeOfDay.now(),
    );
    if (time != null) _flow.updatePickupTime(time);
  }

  Future<void> _handleSave({required bool draft}) async {
    final order = draft
        ? await _flow.saveDraft()
        : await _flow.submitForApproval();
    if (!mounted) return;

    if (order == null) {
      _showValidation();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          draft ? 'تم حفظ الطلب كمسودة بنجاح' : 'تم إرسال الطلب للموافقة بنجاح',
        ),
      ),
    );

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));

    if (!mounted) return;
    await widget.controller.loadInitialData();
    if (mounted) widget.onFinished();
  }

  void _handlePhoneChanged(String value) {
    _flow.updateCustomerPhone(value);
    _phoneSearchDebounce?.cancel();
    if (value.trim().length < 10) return;
    _phoneSearchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _searchCustomer();
    });
  }

  void _showValidation() {
    final message = _flow.validationMessage ?? _flow.errorMessage;
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addReceipt() {
    _flow.updatePayment(
      receipt: OrderAttachmentDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: 'إيصال_دفع.jpg',
        path: '/mock/payment_receipt.jpg',
        type: OrderAttachmentType.receipt,
        sizeInBytes: 240000,
      ),
    );
  }

  void _syncCustomerControllers() {
    _setText(_customerNameController, _flow.request.customerName);
    _setText(_companyNameController, _flow.request.companyName);
    _setText(_taxNumberController, _flow.request.taxNumber);
    _setText(_companyAddressController, _flow.request.companyAddress);
    _setText(_companyEmailController, _flow.request.companyEmail);
    _setText(_companyContactController, _flow.request.companyContactPerson);
  }

  void _syncDeliveryControllers() {
    final delivery = _flow.request.deliveryDetails;
    _setText(_deliveryAddressController, delivery.addressText);
    _setText(_deliveryDistrictController, delivery.district);
    _setText(_deliveryCityController, delivery.city);
    _setText(_deliveryPostalController, delivery.postalCode);
    _setText(_mapsController, delivery.googleMapsUrl);
    _setText(_deliveryNotesController, delivery.notes);
    _setText(
      _deliveryFeeController,
      delivery.deliveryFee == 0 ? '' : delivery.deliveryFee.toString(),
    );
  }

  void _syncCoordinatesOnly() {
    setState(() {});
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  num _parseAmount(String value) {
    return num.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.flow});

  final CreateOrderController flow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final step = CreateOrderStep.values[index];
          final active = step == flow.currentStep;
          final done = index < flow.currentStepIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 118,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active ? AppColors.navy : AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: active || done ? AppColors.gold : AppColors.creamDark,
              ),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: done
                      ? AppColors.green
                      : active
                      ? AppColors.gold
                      : AppColors.creamDark,
                  child: Icon(
                    done ? Icons.check : Icons.circle,
                    color: done || active
                        ? AppColors.white
                        : AppColors.textMuted,
                    size: done ? 16 : 8,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? AppColors.white : AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: CreateOrderStep.values.length,
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Icon(icon, color: AppColors.goldDark, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.department,
    required this.selected,
    required this.onTap,
  });

  final ProductDepartment department;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFFDE7) : AppColors.cream,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.creamDark,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(department.icon, color: AppColors.navy, size: 32),
            const SizedBox(height: 10),
            Text(
              department.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedChoice<T> extends StatelessWidget {
  const _SegmentedChoice({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final IconData Function(T value) iconOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values.map((value) {
        final isSelected = value == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: InkWell(
              onTap: () => onChanged(value),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFFDE7) : AppColors.cream,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: isSelected ? AppColors.gold : AppColors.creamDark,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconOf(value), color: AppColors.navy, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        labelOf(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TotalStrip extends StatelessWidget {
  const _TotalStrip({required this.itemsCount, required this.total});

  final int itemsCount;
  final num total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_bag_outlined, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$itemsCount منتج',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            formatCurrency(total),
            style: const TextStyle(
              color: AppColors.goldLight,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.creamDark),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList({required this.attachments, required this.onRemove});

  final List<OrderAttachmentDraft> attachments;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const EmptyStateView(
        message: 'لا توجد مرفقات',
        icon: Icons.attach_file_outlined,
      );
    }

    return Column(
      children: attachments.map((attachment) {
        final valid = attachment.isValidType && attachment.isValidSize;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: valid ? AppColors.creamDark : AppColors.red,
            ),
          ),
          child: Row(
            children: [
              Icon(
                attachment.type == OrderAttachmentType.pdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
                color: AppColors.navy,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name.isEmpty ? 'إيصال الدفع' : attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${attachment.type.label} • ${(attachment.sizeInBytes / 1024).round()} KB',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onRemove(attachment.id),
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ReadonlyInfo extends StatelessWidget {
  const _ReadonlyInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.creamDark),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTotals extends StatelessWidget {
  const _PaymentTotals({required this.request});

  final CreateOrderRequest request;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryRow(
          label: 'إجمالي المنتجات',
          value: formatCurrency(request.productsTotal),
        ),
        _SummaryRow(
          label: 'رسوم التوصيل',
          value: formatCurrency(request.deliveryFee),
        ),
        _SummaryRow(
          label: 'الإجمالي النهائي',
          value: formatCurrency(request.grandTotal),
        ),
        _SummaryRow(
          label: 'المتبقي',
          value: formatCurrency(request.remainingAmount),
        ),
      ],
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, padding: EdgeInsets.zero),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowFooter extends StatelessWidget {
  const _FlowFooter({
    required this.flow,
    required this.onPrevious,
    required this.onNext,
    required this.onSaveDraft,
    required this.onSubmit,
  });

  final CreateOrderController flow;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isReview = flow.currentStep == CreateOrderStep.review;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: const Border(top: BorderSide(color: AppColors.creamDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isReview)
              Row(
                children: [
                  if (flow.currentStepIndex > 0) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPrevious,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('السابق'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: flow.isSaving ? null : onNext,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('التالي'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: flow.isSaving ? null : onPrevious,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('السابق'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: flow.isSaving ? null : onSaveDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('مسودة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: flow.isSaving ? null : onSubmit,
                      icon: flow.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: const Text('إرسال'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
