import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/create_order_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/product_card.dart';
import '../widgets/state_views.dart';

class EditDraftOrderScreen extends StatefulWidget {
  const EditDraftOrderScreen({
    super.key,
    required this.controller,
    required this.order,
  });

  final AppController controller;
  final Order order;

  @override
  State<EditDraftOrderScreen> createState() => _EditDraftOrderScreenState();
}

class _EditDraftOrderScreenState extends State<EditDraftOrderScreen> {
  late final CreateOrderController _flow;
  final _detailsController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _flow = CreateOrderController(
      currentUser: widget.controller.currentUser,
      productRepository: widget.controller.productRepository,
      customerRepository: widget.controller.customerRepository,
      orderRepository: widget.controller.orderRepository,
      existingOrder: widget.order,
    );
    _detailsController.text = _flow.request.orderDetails;
    _notesController.text = _flow.request.customerNotes;
  }

  @override
  void dispose() {
    _flow.dispose();
    _detailsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _flow,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    AppHeader(
                      title: 'تعديل المسودة',
                      subtitle: widget.order.id,
                      showBack: true,
                      onBack: () => Navigator.maybePop(context),
                    ),
                    if (_flow.validationMessage != null)
                      _InlineMessage(
                        message: _flow.validationMessage!,
                        color: AppColors.red,
                        icon: Icons.info_outline,
                      ),
                    if (_flow.errorMessage != null)
                      _InlineMessage(
                        message: _flow.errorMessage!,
                        color: AppColors.red,
                        icon: Icons.error_outline,
                      ),
                    _CustomerLockCard(order: widget.order),
                    _ProductsSection(flow: _flow),
                    _DetailsSection(
                      detailsController: _detailsController,
                      notesController: _notesController,
                      onDetailsChanged: (value) =>
                          _flow.updateOrderDetails(details: value),
                      onNotesChanged: (value) =>
                          _flow.updateOrderDetails(notes: value),
                    ),
                    _PickupSection(
                      flow: _flow,
                      onPickDate: _pickDate,
                      onPickTime: _pickTime,
                    ),
                    const SizedBox(height: 96),
                  ],
                ),
              ),
              _EditFooter(
                isSaving: _flow.isSaving,
                onSave: () => _handleSave(submit: false),
                onSubmit: () => _handleSave(submit: true),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final currentDate = _flow.request.pickupDate;
    final initialDate = currentDate == null || currentDate.isBefore(now)
        ? now
        : currentDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
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

  Future<void> _handleSave({required bool submit}) async {
    final order = submit
        ? await _flow.submitForApproval()
        : await _flow.saveDraft();
    if (!mounted) return;

    if (order == null) {
      final message = _flow.validationMessage ?? _flow.errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    await widget.controller.loadInitialData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submit
              ? 'تم تحديث الطلب وإرساله للموافقة'
              : 'تم حفظ التعديل على المسودة',
        ),
      ),
    );
    Navigator.of(context).pop(order);
  }
}

class _CustomerLockCard extends StatelessWidget {
  const _CustomerLockCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'بيانات ثابتة',
      icon: Icons.lock_outline,
      child: Column(
        children: [
          _InfoRow(label: 'العميل', value: order.customer),
          _InfoRow(label: 'الجوال', value: order.customerPhone),
          _InfoRow(label: 'الدفع', value: order.paymentMethod.label),
          _InfoRow(
            label: 'العربون',
            value: formatCurrency(order.depositAmount),
          ),
        ],
      ),
    );
  }
}

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.flow});

  final CreateOrderController flow;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (flow.productsState.isLoading) {
      content = const SizedBox(height: 220, child: LoadingStateView());
    } else if (flow.productsState.isError) {
      content = SizedBox(
        height: 220,
        child: ErrorStateView(
          message: flow.productsState.message ?? 'تعذر تحميل المنتجات',
          onRetry: flow.loadCategories,
        ),
      );
    } else {
      final products = flow.products.isEmpty
          ? flow.request.lineItems.map((line) => line.product).toList()
          : flow.products;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (products.isEmpty)
            const SizedBox(
              height: 180,
              child: EmptyStateView(message: 'لا توجد منتجات متاحة للتعديل'),
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
                  childAspectRatio: 0.72,
                  children: products.map((product) {
                    final quantity = flow.request.quantityFor(product);
                    return ProductCard(
                      product: product,
                      quantity: quantity,
                      onAdd: () => flow.changeProductQuantity(product, 1),
                      onIncrement: () => flow.changeProductQuantity(product, 1),
                      onDecrement: () =>
                          flow.changeProductQuantity(product, -1),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 12),
          _TotalStrip(
            itemsCount: flow.request.itemsCount,
            total: flow.request.productsTotal,
          ),
        ],
      );
    }

    return _SectionCard(
      title: 'المنتجات',
      icon: Icons.inventory_2_outlined,
      child: content,
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.detailsController,
    required this.notesController,
    required this.onDetailsChanged,
    required this.onNotesChanged,
  });

  final TextEditingController detailsController;
  final TextEditingController notesController;
  final ValueChanged<String> onDetailsChanged;
  final ValueChanged<String> onNotesChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'التفاصيل',
      icon: Icons.edit_note_outlined,
      child: Column(
        children: [
          TextField(
            controller: detailsController,
            maxLines: 4,
            onChanged: onDetailsChanged,
            decoration: const InputDecoration(
              labelText: 'تفاصيل الطلب',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notesController,
            maxLines: 3,
            onChanged: onNotesChanged,
            decoration: const InputDecoration(
              labelText: 'ملاحظات العميل',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupSection extends StatelessWidget {
  const _PickupSection({
    required this.flow,
    required this.onPickDate,
    required this.onPickTime,
  });

  final CreateOrderController flow;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'تاريخ ووقت الاستلام',
      icon: Icons.event_available_outlined,
      child: Row(
        children: [
          Expanded(
            child: _PickerTile(
              icon: Icons.calendar_today_outlined,
              label: 'تاريخ الاستلام',
              value: flow.request.pickupDate == null
                  ? 'اختر التاريخ'
                  : formatDate(flow.request.pickupDate!),
              onTap: onPickDate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PickerTile(
              icon: Icons.schedule_outlined,
              label: 'وقت الاستلام',
              value: flow.request.pickupTime == null
                  ? 'اختر الوقت'
                  : formatTime(flow.request.pickupTime!),
              onTap: onPickTime,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditFooter extends StatelessWidget {
  const _EditFooter({
    required this.isSaving,
    required this.onSave,
    required this.onSubmit,
  });

  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
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
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : onSubmit,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('إرسال للموافقة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
                Icon(icon, color: AppColors.goldDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
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

class _TotalStrip extends StatelessWidget {
  const _TotalStrip({required this.itemsCount, required this.total});

  final int itemsCount;
  final num total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'عدد المنتجات: $itemsCount',
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            formatCurrency(total),
            style: const TextStyle(
              color: AppColors.goldDark,
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.creamDark),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.goldDark, size: 20),
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
                  const SizedBox(height: 3),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
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
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
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
