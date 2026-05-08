import 'package:flutter/material.dart';

import '../models/app_models.dart';

class DeliveryProofDialog extends StatefulWidget {
  const DeliveryProofDialog({
    super.key,
    this.title = 'إثبات التسليم',
    this.requireReceiverName = true,
  });

  final String title;
  final bool requireReceiverName;

  @override
  State<DeliveryProofDialog> createState() => _DeliveryProofDialogState();
}

class _DeliveryProofDialogState extends State<DeliveryProofDialog> {
  final _formKey = GlobalKey<FormState>();
  final _receiverController = TextEditingController();
  final _proofController = TextEditingController();
  final _signatureController = TextEditingController();
  final _notesController = TextEditingController();
  bool _qrScanned = false;

  @override
  void dispose() {
    _receiverController.dispose();
    _proofController.dispose();
    _signatureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _receiverController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'اسم المستلم'),
                validator: (value) {
                  if (!widget.requireReceiverName) return null;
                  if ((value ?? '').trim().isEmpty) {
                    return 'اسم المستلم مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _proofController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'مسار/رابط صورة الإثبات',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _signatureController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'رابط التوقيع'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 2,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _qrScanned,
                onChanged: (value) =>
                    setState(() => _qrScanned = value ?? false),
                title: const Text('تم فحص QR'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('تأكيد التسليم')),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      DeliveryProofInput(
        receivedByName: _receiverController.text.trim(),
        proofImagePath: _proofController.text.trim(),
        signatureUrl: _signatureController.text.trim(),
        qrScanned: _qrScanned,
        notes: _notesController.text.trim(),
      ),
    );
  }
}
