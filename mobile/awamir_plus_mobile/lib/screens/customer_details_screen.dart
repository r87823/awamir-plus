import 'package:flutter/material.dart';

import '../screens/pickup_datetime_screen.dart';
import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.controller,
    required this.onFinished,
  });

  final AppController controller;
  final VoidCallback onFinished;

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  late final TextEditingController _phoneController;
  late final TextEditingController _nameController;
  late bool _isCompany;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: widget.controller.draft.customerPhone,
    );
    _nameController = TextEditingController(
      text: widget.controller.draft.customerName,
    );
    _isCompany = widget.controller.draft.isCompany;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canCreateOrder(widget.controller.currentUser)) {
      return const Scaffold(body: AccessDeniedStateView());
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppHeader(title: 'بيانات العميل', compact: true, showBack: true),
          const SizedBox(height: 18),
          const SectionHeader(title: 'معلومات العميل'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الجوال *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'اسم العميل'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'نوع العميل',
                  style: TextStyle(
                    color: AppColors.textBody,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TypeChip(
                        label: 'فرد',
                        selected: !_isCompany,
                        onTap: () => setState(() => _isCompany = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TypeChip(
                        label: 'شركة',
                        selected: _isCompany,
                        onTap: () => setState(() => _isCompany = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.controller.updateCustomer(
                      phone: _phoneController.text,
                      name: _nameController.text,
                      isCompany: _isCompany,
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PickupDateTimeScreen(
                          controller: widget.controller,
                          onFinished: widget.onFinished,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('متابعة تاريخ الاستلام'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.creamDark,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.white : AppColors.textBody,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
