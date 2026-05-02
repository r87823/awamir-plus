import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../core/utils/formatters.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.controller,
    required this.onFinished,
  });

  final AppController controller;
  final VoidCallback onFinished;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final TextEditingController _depositController;

  @override
  void initState() {
    super.initState();
    _depositController = TextEditingController(
      text: widget.controller.draft.depositAmount.toString(),
    );
  }

  @override
  void dispose() {
    _depositController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canCreateOrder(widget.controller.currentUser)) {
      return const Scaffold(body: AccessDeniedStateView());
    }

    return Scaffold(
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHeader(
                title: 'العربون وطريقة الدفع',
                compact: true,
                showBack: true,
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'ملخص الدفع'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'إجمالي الطلب',
                      value: formatCurrency(widget.controller.cartTotal),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _depositController,
                            keyboardType: TextInputType.number,
                            onChanged: widget.controller.updateDeposit,
                            decoration: const InputDecoration(
                              labelText: 'مبلغ العربون',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 58,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: AppColors.creamDark,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'المتبقي',
                                  style: TextStyle(
                                    color: AppColors.textBody,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  formatCurrency(
                                    widget.controller.remainingAmount,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'طريقة الدفع',
                        style: TextStyle(
                          color: AppColors.textBody,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PaymentMethodSelector(
                      selectedMethod: widget.controller.draft.paymentMethod,
                      onChanged: widget.controller.updatePaymentMethod,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed:
                          widget.controller.cartCount == 0 ||
                              widget.controller.isActionLoading
                          ? null
                          : () => _submit(context),
                      icon: widget.controller.isActionLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.navyDark,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        widget.controller.isActionLoading
                            ? 'جاري الإرسال...'
                            : 'إرسال للموافقة',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: widget.controller.isActionLoading
                          ? null
                          : () async {
                              final saved = await widget.controller.saveDraft();
                              if (!context.mounted) return;
                              final message = saved
                                  ? 'تم حفظ الطلب كمسودة'
                                  : widget.controller.actionErrorMessage ??
                                        'تعذر حفظ الطلب كمسودة';
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ كمسودة'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final order = await widget.controller.submitDraft();
    if (!context.mounted) return;

    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.actionErrorMessage ?? 'تعذر إرسال الطلب للموافقة',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم إرسال ${order.id} للموافقة')));
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onFinished();
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.goldDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
