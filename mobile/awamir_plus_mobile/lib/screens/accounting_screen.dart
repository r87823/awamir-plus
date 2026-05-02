import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  var _tab = _AccountingTab.salesOrders;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canManageAccounting(widget.controller.currentUser)) {
      return const AccessDeniedStateView();
    }

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final items = _itemsForTab();
        return RefreshIndicator(
          onRefresh: widget.controller.loadAccountingLists,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHeader(
                title: 'المحاسبة',
                subtitle: 'Sales Order و Payment Entry و Sales Invoice',
                notificationCount: widget.controller.unreadNotifications,
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _AccountingTab.values.map((tab) {
                    final selected = tab == _tab;
                    return ChoiceChip(
                      label: Text('${tab.label} (${_countForTab(tab)})'),
                      selected: selected,
                      onSelected: (_) => setState(() => _tab = tab),
                      selectedColor: AppColors.goldLight,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.navy : AppColors.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              SectionHeader(title: _tab.label),
              if (widget.controller.isActionLoading && items.isEmpty)
                const SizedBox(height: 260, child: LoadingStateView())
              else if (items.isEmpty)
                const SizedBox(
                  height: 260,
                  child: EmptyStateView(
                    message: 'لا توجد عناصر في هذا التبويب',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                )
              else
                ...items,
              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _itemsForTab() {
    switch (_tab) {
      case _AccountingTab.salesOrders:
        return widget.controller.ordersNeedingSalesOrder
            .map(
              (order) => _AccountingOrderCard(
                order: order,
                actionLabel: 'إنشاء Sales Order',
                actionIcon: Icons.description_outlined,
                onWorkOrder: () => _runOrderAction(
                  () => widget.controller.createWorkOrderForOrder(order.id),
                  'تم إنشاء Work Order',
                ),
                onAction: () => _runOrderAction(
                  () => widget.controller.createSalesOrderForOrder(order.id),
                  'تم إنشاء Sales Order',
                ),
              ),
            )
            .toList();
      case _AccountingTab.payments:
        return widget.controller.paymentsReadyForErpPosting
            .map(
              (payment) => _PaymentPostingCard(
                payment: payment,
                onAction: () => _runPaymentAction(
                  () => widget.controller.createPaymentEntryForPayment(
                    payment.id,
                  ),
                  'تم ترحيل الدفعة',
                ),
              ),
            )
            .toList();
      case _AccountingTab.invoices:
        return widget.controller.ordersNeedingSalesInvoice
            .map(
              (order) => _AccountingOrderCard(
                order: order,
                actionLabel: 'إنشاء فاتورة',
                actionIcon: Icons.request_quote_outlined,
                onWorkOrder: () => _runOrderAction(
                  () => widget.controller.createWorkOrderForOrder(order.id),
                  'تم إنشاء Work Order',
                ),
                onAction: () => _runOrderAction(
                  () => widget.controller.createSalesInvoiceForOrder(order.id),
                  'تم إنشاء الفاتورة',
                ),
              ),
            )
            .toList();
      case _AccountingTab.allocations:
        return widget.controller.invoicesNeedingAdvanceAllocation
            .map(
              (order) => _AccountingOrderCard(
                order: order,
                actionLabel: 'ربط العربون',
                actionIcon: Icons.link,
                onWorkOrder: () => _runOrderAction(
                  () => widget.controller.createWorkOrderForOrder(order.id),
                  'تم إنشاء Work Order',
                ),
                onAction: () async {
                  final result = await widget.controller
                      .allocateAdvancePaymentToInvoice(order.id);
                  if (!mounted) return;
                  _showSnack(
                    result == null
                        ? widget.controller.actionErrorMessage ??
                              'تعذر ربط العربون'
                        : 'تم ربط العربون بالفاتورة',
                  );
                },
              ),
            )
            .toList();
      case _AccountingTab.errors:
        return widget.controller.accountingSyncErrors
            .map(
              (order) => _AccountingOrderCard(
                order: order,
                actionLabel: 'إعادة المحاولة',
                actionIcon: Icons.refresh,
                onWorkOrder: () => _runOrderAction(
                  () => widget.controller.createWorkOrderForOrder(order.id),
                  'تم إنشاء Work Order',
                ),
                onAction: () => _retry(order),
                showError: true,
              ),
            )
            .toList();
    }
  }

  int _countForTab(_AccountingTab tab) {
    switch (tab) {
      case _AccountingTab.salesOrders:
        return widget.controller.ordersNeedingSalesOrder.length;
      case _AccountingTab.payments:
        return widget.controller.paymentsReadyForErpPosting.length;
      case _AccountingTab.invoices:
        return widget.controller.ordersNeedingSalesInvoice.length;
      case _AccountingTab.allocations:
        return widget.controller.invoicesNeedingAdvanceAllocation.length;
      case _AccountingTab.errors:
        return widget.controller.accountingSyncErrors.length;
    }
  }

  Future<void> _runOrderAction(
    Future<Order?> Function() action,
    String success,
  ) async {
    final order = await action();
    if (!mounted) return;
    _showSnack(
      order == null ? widget.controller.actionErrorMessage ?? success : success,
    );
  }

  Future<void> _runPaymentAction(
    Future<OrderPayment?> Function() action,
    String success,
  ) async {
    final payment = await action();
    if (!mounted) return;
    _showSnack(
      payment == null
          ? widget.controller.actionErrorMessage ?? success
          : success,
    );
  }

  Future<void> _retry(Order order) async {
    if (order.erpnextSalesOrderId.isEmpty) {
      await _runOrderAction(
        () => widget.controller.createSalesOrderForOrder(order.id),
        'تمت إعادة المحاولة',
      );
      return;
    }
    if (order.erpnextSalesInvoiceId.isEmpty) {
      await _runOrderAction(
        () => widget.controller.createSalesInvoiceForOrder(order.id),
        'تمت إعادة المحاولة',
      );
      return;
    }
    final result = await widget.controller.allocateAdvancePaymentToInvoice(
      order.id,
    );
    if (!mounted) return;
    _showSnack(result == null ? 'تعذرت إعادة المحاولة' : 'تمت إعادة المحاولة');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _AccountingTab { salesOrders, payments, invoices, allocations, errors }

extension _AccountingTabDetails on _AccountingTab {
  String get label {
    switch (this) {
      case _AccountingTab.salesOrders:
        return 'تحتاج Sales Order';
      case _AccountingTab.payments:
        return 'دفعات جاهزة للترحيل';
      case _AccountingTab.invoices:
        return 'تحتاج فاتورة';
      case _AccountingTab.allocations:
        return 'تحتاج ربط عربون';
      case _AccountingTab.errors:
        return 'أخطاء الربط';
    }
  }
}

class _AccountingOrderCard extends StatelessWidget {
  const _AccountingOrderCard({
    required this.order,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.onWorkOrder,
    this.showError = false,
  });

  final Order order;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final VoidCallback? onWorkOrder;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          _Row(label: 'رقم الطلب', value: order.id, strong: true),
          _Row(label: 'العميل', value: order.customer),
          _Row(label: 'الإجمالي', value: formatCurrency(order.amount)),
          _Row(label: 'العربون', value: formatCurrency(order.depositAmount)),
          _Row(label: 'المتبقي', value: formatCurrency(order.remainingAmount)),
          _Row(label: 'Sales Order', value: order.erpnextSalesOrderId),
          _Row(
            label: 'Payment Entry',
            value: order.erpnextPaymentEntryIds.join(', '),
          ),
          _Row(label: 'Sales Invoice', value: order.erpnextSalesInvoiceId),
          _Row(label: 'حالة المزامنة', value: order.erpSyncStatus.label),
          if (showError) _Row(label: 'الخطأ', value: order.erpSyncError),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: order.erpnextSalesOrderId.isEmpty
                      ? null
                      : onWorkOrder,
                  icon: const Icon(Icons.precision_manufacturing_outlined),
                  label: const Text('إنشاء Work Order'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon),
                  label: Text(actionLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentPostingCard extends StatelessWidget {
  const _PaymentPostingCard({required this.payment, required this.onAction});

  final OrderPayment payment;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          _Row(label: 'الدفع', value: payment.id, strong: true),
          _Row(label: 'الطلب', value: payment.orderId),
          _Row(label: 'العميل', value: payment.customer),
          _Row(label: 'المبلغ', value: formatCurrency(payment.amount)),
          _Row(label: 'الطريقة', value: payment.method.label),
          _Row(label: 'الحالة', value: payment.status.label),
          _Row(label: 'Payment Entry', value: payment.erpnextPaymentEntryId),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('ترحيل الدفعة'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
