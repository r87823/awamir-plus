import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../core/theme/app_theme.dart';

class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.onChanged,
  });

  final PaymentMethod selectedMethod;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: PaymentMethod.values.map((method) {
        final selected = method == selectedMethod;
        return Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: InkWell(
              onTap: () => onChanged(method),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFFFDE7) : AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: selected ? AppColors.gold : AppColors.creamDark,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(method.icon, color: AppColors.navy, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      method.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textBody,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
