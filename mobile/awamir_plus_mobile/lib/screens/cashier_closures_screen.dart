import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/reason_input_dialog.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class CashierClosuresScreen extends StatefulWidget {
  const CashierClosuresScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CashierClosuresScreen> createState() => _CashierClosuresScreenState();
}

class _CashierClosuresScreenState extends State<CashierClosuresScreen> {
  String _query = '';
  CashClosureOwnerType? _type;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canViewCashierClosures(widget.controller.currentUser)) {
      return const AccessDeniedStateView();
    }

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final closures = widget.controller.cashierClosures.where((closure) {
          final matchesQuery =
              _query.trim().isEmpty ||
              closure.ownerName.contains(_query.trim()) ||
              closure.branch.contains(_query.trim()) ||
              closure.date.contains(_query.trim());
          final matchesType = _type == null || closure.type == _type;
          return matchesQuery && matchesType;
        }).toList();

        return RefreshIndicator(
          onRefresh: widget.controller.loadCashierClosures,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHeader(
                title: 'عهد أمين الصندوق',
                subtitle: 'مراجعة عهد الموظفين والسائقين وتأكيد الدفعات',
                notificationCount: widget.controller.unreadNotifications,
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    labelText: 'بحث بالتاريخ أو الفرع أو اسم المستخدم',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('الكل'),
                      selected: _type == null,
                      onSelected: (_) => setState(() => _type = null),
                    ),
                    ChoiceChip(
                      label: const Text('موظف'),
                      selected: _type == CashClosureOwnerType.employee,
                      onSelected: (_) =>
                          setState(() => _type = CashClosureOwnerType.employee),
                    ),
                    ChoiceChip(
                      label: const Text('سائق'),
                      selected: _type == CashClosureOwnerType.driver,
                      onSelected: (_) =>
                          setState(() => _type = CashClosureOwnerType.driver),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const SectionHeader(title: 'العهد المرسلة'),
              if (widget.controller.isActionLoading && closures.isEmpty)
                const SizedBox(height: 260, child: LoadingStateView())
              else if (closures.isEmpty)
                const SizedBox(
                  height: 260,
                  child: EmptyStateView(
                    message: 'لا توجد عهد مرسلة لأمين الصندوق',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                )
              else
                ...closures.map(
                  (closure) => _ClosureCard(
                    closure: closure,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CashClosureDetailScreen(
                            controller: widget.controller,
                            closure: closure,
                          ),
                        ),
                      );
                      await widget.controller.loadCashierClosures();
                    },
                  ),
                ),
              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }
}

class CashClosureDetailScreen extends StatefulWidget {
  const CashClosureDetailScreen({
    super.key,
    required this.controller,
    required this.closure,
  });

  final AppController controller;
  final DailyCashClosure closure;

  @override
  State<CashClosureDetailScreen> createState() =>
      _CashClosureDetailScreenState();
}

class _CashClosureDetailScreenState extends State<CashClosureDetailScreen> {
  late DailyCashClosure _closure = widget.closure;
  late final TextEditingController _cashController = TextEditingController(
    text: _closure.methodTotal(PaymentMethod.cash).toString(),
  );
  late final TextEditingController _cardController = TextEditingController(
    text: _closure.methodTotal(PaymentMethod.card).toString(),
  );
  late final TextEditingController _transferController = TextEditingController(
    text: _closure.methodTotal(PaymentMethod.transfer).toString(),
  );
  late final TextEditingController _otherController = TextEditingController(
    text: _closure.methodTotal(PaymentMethod.other).toString(),
  );
  final _notesController = TextEditingController();
  final _differenceReasonController = TextEditingController();

  num get _actualTotal =>
      _amount(_cashController) +
      _amount(_cardController) +
      _amount(_transferController) +
      _amount(_otherController);

  num get _difference => _actualTotal - _closure.total;

  @override
  void dispose() {
    _cashController.dispose();
    _cardController.dispose();
    _transferController.dispose();
    _otherController.dispose();
    _notesController.dispose();
    _differenceReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canReviewCashClosure(widget.controller.currentUser)) {
      return const Scaffold(body: AccessDeniedStateView());
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppHeader(
            title: _closure.id,
            subtitle: 'تفاصيل العهدة',
            showBack: true,
            onBack: () => Navigator.maybePop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            child: Column(
              children: [
                _ClosureHeader(closure: _closure),
                _InfoBox(
                  title: 'بيانات صاحب العهدة',
                  rows: [
                    ('الاسم', _closure.ownerName),
                    ('الدور', _closure.ownerRoleLabel),
                    ('الفرع', _closure.branch),
                    ('التاريخ', _closure.date),
                    ('الحالة', _closure.status.label),
                  ],
                ),
                _InfoBox(
                  title: 'المبالغ المسجلة',
                  rows: [
                    (
                      'النقد',
                      formatCurrency(_closure.methodTotal(PaymentMethod.cash)),
                    ),
                    (
                      'الشبكة',
                      formatCurrency(_closure.methodTotal(PaymentMethod.card)),
                    ),
                    (
                      'التحويل',
                      formatCurrency(
                        _closure.methodTotal(PaymentMethod.transfer),
                      ),
                    ),
                    (
                      'أخرى',
                      formatCurrency(_closure.methodTotal(PaymentMethod.other)),
                    ),
                    ('الإجمالي', formatCurrency(_closure.total)),
                  ],
                ),
                _PaymentsBox(payments: _closure.payments),
                _ActualAmountsBox(
                  cashController: _cashController,
                  cardController: _cardController,
                  transferController: _transferController,
                  otherController: _otherController,
                  notesController: _notesController,
                  differenceReasonController: _differenceReasonController,
                  onChanged: () => setState(() {}),
                  difference: _difference,
                ),
                _LogsBox(
                  logsFuture: widget.controller.getCashClosureLogs(_closure.id),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _returnForReview,
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: const Text('إرجاع'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _accept,
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('قبول'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      _closure.status == CashClosureStatus.accepted ||
                          _closure.status == CashClosureStatus.hasDifference
                      ? _close
                      : null,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('إغلاق وتجهيز الدفعات للترحيل'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    final updated = await widget.controller.acceptCashClosure(
      closureId: _closure.id,
      actualCash: _amount(_cashController),
      actualCard: _amount(_cardController),
      actualTransfer: _amount(_transferController),
      actualOther: _amount(_otherController),
      cashierNotes: _notesController.text.trim(),
      differenceReason: _differenceReasonController.text.trim(),
    );
    if (!mounted) return;
    if (updated == null) {
      _showError();
      return;
    }
    setState(() => _closure = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم قبول العهدة بنجاح')));
  }

  Future<void> _returnForReview() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const ReasonInputDialog(
        title: 'إرجاع العهدة',
        label: 'سبب الإرجاع',
        emptyMessage: 'سبب الإرجاع مطلوب',
        suggestions: [
          'يوجد فرق في العهدة',
          'إيصال غير واضح',
          'رقم عملية ناقص',
          'طريقة الدفع غير مطابقة',
        ],
      ),
    );
    if (reason == null) return;
    final updated = await widget.controller.returnCashClosure(
      closureId: _closure.id,
      reason: reason,
    );
    if (!mounted) return;
    if (updated == null) {
      _showError();
      return;
    }
    setState(() => _closure = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم إرجاع العهدة للمراجعة')));
  }

  Future<void> _close() async {
    final updated = await widget.controller.closeCashClosure(_closure.id);
    if (!mounted) return;
    if (updated == null) {
      _showError();
      return;
    }
    setState(() => _closure = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم إغلاق العهدة')));
  }

  void _showError() {
    final error = widget.controller.actionErrorMessage;
    if (error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  num _amount(TextEditingController controller) {
    return num.tryParse(controller.text.trim()) ?? 0;
  }
}

class _ClosureCard extends StatelessWidget {
  const _ClosureCard({required this.closure, required this.onTap});

  final DailyCashClosure closure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              children: [
                _Row(label: 'رقم العهدة', value: closure.id, strong: true),
                _Row(label: 'المستخدم', value: closure.ownerName),
                _Row(label: 'الفرع', value: closure.branch),
                _Row(label: 'التاريخ', value: closure.date),
                _Row(label: 'النوع', value: closure.type.label),
                _Row(label: 'الحالة', value: closure.status.label),
                _Row(
                  label: 'عدد الطلبات',
                  value: closure.orderCount.toString(),
                ),
                _Row(
                  label: 'النقد',
                  value: formatCurrency(
                    closure.methodTotal(PaymentMethod.cash),
                  ),
                ),
                _Row(
                  label: 'الشبكة',
                  value: formatCurrency(
                    closure.methodTotal(PaymentMethod.card),
                  ),
                ),
                _Row(
                  label: 'التحويل',
                  value: formatCurrency(
                    closure.methodTotal(PaymentMethod.transfer),
                  ),
                ),
                _Row(
                  label: 'الإجمالي',
                  value: formatCurrency(closure.total),
                  strong: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosureHeader extends StatelessWidget {
  const _ClosureHeader({required this.closure});

  final DailyCashClosure closure;

  @override
  Widget build(BuildContext context) {
    final difference = closure.differenceAmount;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            closure.ownerName,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatCurrency(closure.total)} • ${closure.status.label}${difference == 0 ? '' : ' • فرق ${formatCurrency(difference)}'}',
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

class _ActualAmountsBox extends StatelessWidget {
  const _ActualAmountsBox({
    required this.cashController,
    required this.cardController,
    required this.transferController,
    required this.otherController,
    required this.notesController,
    required this.differenceReasonController,
    required this.onChanged,
    required this.difference,
  });

  final TextEditingController cashController;
  final TextEditingController cardController;
  final TextEditingController transferController;
  final TextEditingController otherController;
  final TextEditingController notesController;
  final TextEditingController differenceReasonController;
  final VoidCallback onChanged;
  final num difference;

  @override
  Widget build(BuildContext context) {
    return _Box(
      title: 'المبالغ الفعلية',
      child: Column(
        children: [
          _AmountField(
            label: 'النقد المستلم',
            controller: cashController,
            onChanged: onChanged,
          ),
          _AmountField(
            label: 'الشبكة المطابقة',
            controller: cardController,
            onChanged: onChanged,
          ),
          _AmountField(
            label: 'التحويل المطابق',
            controller: transferController,
            onChanged: onChanged,
          ),
          _AmountField(
            label: 'أخرى',
            controller: otherController,
            onChanged: onChanged,
          ),
          if (difference != 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'يوجد فرق: ${formatCurrency(difference)}',
                style: const TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (difference != 0) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'أسباب شائعة للفرق',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  const [
                    'فرق نقدي',
                    'عملية شبكة غير مطابقة',
                    'تحويل غير مؤكد',
                    'إيصال ناقص',
                  ].map((reason) {
                    return ActionChip(
                      label: Text(reason),
                      onPressed: () {
                        differenceReasonController.text = reason;
                        onChanged();
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: differenceReasonController,
            decoration: const InputDecoration(labelText: 'سبب الفرق إن وجد'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'ملاحظات أمين الصندوق',
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _PaymentsBox extends StatelessWidget {
  const _PaymentsBox({required this.payments});

  final List<OrderPayment> payments;

  @override
  Widget build(BuildContext context) {
    return _Box(
      title: 'الدفعات والإيصالات',
      child: Column(
        children: payments.map((payment) {
          return _Row(
            label: payment.orderId,
            value:
                '${payment.customer} • ${formatCurrency(payment.amount)} • ${payment.method.label}${payment.receiptPath.isEmpty ? '' : ' • إيصال'}',
          );
        }).toList(),
      ),
    );
  }
}

class _LogsBox extends StatelessWidget {
  const _LogsBox({required this.logsFuture});

  final Future<List<CashClosureLog>> logsFuture;

  @override
  Widget build(BuildContext context) {
    return _Box(
      title: 'سجل العهدة',
      child: FutureBuilder<List<CashClosureLog>>(
        future: logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator(color: AppColors.gold);
          }
          final logs = snapshot.data ?? const [];
          if (logs.isEmpty) return const Text('لا يوجد سجل بعد');
          return Column(
            children: logs.map((log) {
              return _Row(
                label: log.newStatus.label,
                value:
                    '${log.changedByName} • ${formatDate(log.changedAt)} ${formatTime(TimeOfDay.fromDateTime(log.changedAt))}${log.notes.isEmpty ? '' : ' • ${log.notes}'}',
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return _Box(
      title: title,
      child: Column(
        children: rows
            .map((row) => _Row(label: row.$1, value: row.$2))
            .toList(),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
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
            width: 112,
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
              value.isEmpty ? '-' : value,
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
