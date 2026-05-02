import 'package:flutter/material.dart';

import '../screens/customer_details_screen.dart';
import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../core/utils/formatters.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({
    super.key,
    required this.controller,
    required this.onFinished,
  });

  final AppController controller;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canCreateOrder(controller.currentUser)) {
      return const Scaffold(body: AccessDeniedStateView());
    }

    return Scaffold(
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHeader(
                title: 'سلة / ملخص الطلب',
                compact: true,
                showBack: true,
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'المنتجات'),
              if (controller.cartLines.isEmpty)
                const _EmptyCart()
              else
                ...controller.cartLines.map((line) {
                  return _CartItem(
                    productName: line.key.name,
                    imageUrl: line.key.imageUrl,
                    subtotal: line.key.price * line.value,
                    quantity: line.value,
                    onIncrement: () =>
                        controller.changeProductQuantity(line.key, 1),
                    onDecrement: () =>
                        controller.changeProductQuantity(line.key, -1),
                  );
                }),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'إجمالي الطلب',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        formatCurrency(controller.cartTotal),
                        style: const TextStyle(
                          color: AppColors.goldDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton.icon(
                  onPressed: controller.cartCount == 0
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CustomerDetailsScreen(
                              controller: controller,
                              onFinished: onFinished,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('متابعة بيانات العميل'),
                ),
              ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  const _CartItem({
    required this.productName,
    required this.imageUrl,
    required this.subtotal,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String productName;
  final String imageUrl;
  final num subtotal;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: Image.network(
                imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 56,
                  height: 56,
                  color: AppColors.creamDark,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    formatCurrency(subtotal),
                    style: const TextStyle(
                      color: AppColors.goldDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  color: AppColors.red,
                  onTap: onDecrement,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$quantity',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add,
                  color: AppColors.green,
                  onTap: onIncrement,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: AppColors.white, size: 17),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            color: AppColors.textMuted,
            size: 52,
          ),
          SizedBox(height: 8),
          Text(
            'السلة فارغة',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
