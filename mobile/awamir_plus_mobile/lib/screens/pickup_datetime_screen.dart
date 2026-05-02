import 'package:flutter/material.dart';

import '../screens/payment_screen.dart';
import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../core/utils/formatters.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class PickupDateTimeScreen extends StatefulWidget {
  const PickupDateTimeScreen({
    super.key,
    required this.controller,
    required this.onFinished,
  });

  final AppController controller;
  final VoidCallback onFinished;

  @override
  State<PickupDateTimeScreen> createState() => _PickupDateTimeScreenState();
}

class _PickupDateTimeScreenState extends State<PickupDateTimeScreen> {
  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _date = widget.controller.draft.pickupDate;
    _time = widget.controller.draft.pickupTime;
    _notesController = TextEditingController(
      text: widget.controller.draft.notes,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
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
          AppHeader(
            title: 'تاريخ ووقت الاستلام',
            compact: true,
            showBack: true,
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'موعد الاستلام'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        label: 'التاريخ',
                        value: formatDate(_date),
                        icon: Icons.calendar_today,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerTile(
                        label: 'الوقت',
                        value: formatTime(_time),
                        icon: Icons.access_time,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    hintText: 'ملاحظات إضافية...',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.controller.updatePickup(
                      date: _date,
                      time: _time,
                      notes: _notesController.text,
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(
                          controller: widget.controller,
                          onFinished: widget.onFinished,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('متابعة العربون والدفع'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final next = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      locale: const Locale('ar', 'SA'),
    );
    if (next != null) setState(() => _date = next);
  }

  Future<void> _pickTime() async {
    final next = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (next != null) setState(() => _time = next);
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.creamDark, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy, size: 21),
            const SizedBox(width: 9),
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
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
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
