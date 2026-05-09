import 'package:flutter/material.dart';

class ReasonInputDialog extends StatefulWidget {
  const ReasonInputDialog({
    super.key,
    required this.title,
    required this.label,
    required this.emptyMessage,
    this.suggestions = const [],
  });

  final String title;
  final String label;
  final String emptyMessage;
  final List<String> suggestions;

  @override
  State<ReasonInputDialog> createState() => _ReasonInputDialogState();
}

class _ReasonInputDialogState extends State<ReasonInputDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.suggestions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.suggestions.map((suggestion) {
                  return ChoiceChip(
                    label: Text(suggestion),
                    selected: _controller.text.trim() == suggestion,
                    onSelected: (_) {
                      setState(() {
                        _controller.text = suggestion;
                        _errorText = null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.label,
                errorText: _errorText,
                alignLabelWithHint: true,
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isEmpty) {
              setState(() => _errorText = widget.emptyMessage);
              return;
            }
            Navigator.pop(context, value);
          },
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}
