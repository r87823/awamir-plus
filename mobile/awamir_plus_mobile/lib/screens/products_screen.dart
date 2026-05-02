import 'package:flutter/material.dart';

import '../screens/cart_screen.dart';
import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../core/utils/formatters.dart';
import '../widgets/product_card.dart';
import '../widgets/state_views.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.controller,
    required this.onFinished,
  });

  final AppController controller;
  final VoidCallback onFinished;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
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
          final products = widget.controller.currentDepartmentProducts(
            query: _searchController.text,
          );
          final selectedDepartment = widget.controller.selectedDepartment;
          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.zero,
                children: [
                  AppHeader(
                    title: 'اختيار المنتجات',
                    compact: true,
                    showBack: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final department = widget.controller.departments[index];
                        final selected =
                            department.id == selectedDepartment?.id;
                        return ChoiceChip(
                          selected: selected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(department.icon, size: 17),
                              const SizedBox(width: 5),
                              Text(department.name),
                            ],
                          ),
                          selectedColor: AppColors.navy,
                          backgroundColor: AppColors.white,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.white
                                : AppColors.textBody,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Tajawal',
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColors.navy
                                : AppColors.creamDark,
                            width: 1.5,
                          ),
                          onSelected: (_) =>
                              widget.controller.selectDepartment(department),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemCount: widget.controller.departments.length,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'ابحث عن منتج...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                    child: products.isEmpty
                        ? const SizedBox(
                            height: 220,
                            child: EmptyStateView(
                              message: 'لا توجد منتجات في هذا القسم',
                              icon: Icons.inventory_2_outlined,
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.68,
                                ),
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final quantity = widget.controller.quantityFor(
                                product,
                              );
                              return ProductCard(
                                product: product,
                                quantity: quantity,
                                onAdd: () =>
                                    widget.controller.addProduct(product),
                                onIncrement: () => widget.controller
                                    .changeProductQuantity(product, 1),
                                onDecrement: () => widget.controller
                                    .changeProductQuantity(product, -1),
                              );
                            },
                          ),
                  ),
                ],
              ),
              if (widget.controller.cartCount > 0)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: _CartBar(
                    count: widget.controller.cartCount,
                    total: widget.controller.cartTotal,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CartScreen(
                          controller: widget.controller,
                          onFinished: widget.onFinished,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.count,
    required this.total,
    required this.onTap,
  });

  final int count;
  final num total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.navy, AppColors.navyDark],
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.goldDark),
          boxShadow: AppShadows.strong,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.navyDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'السلة',
                    style: TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    formatCurrency(total),
                    style: const TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'إكمال الطلب',
                    style: TextStyle(
                      color: AppColors.navyDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_back, color: AppColors.navyDark, size: 17),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
