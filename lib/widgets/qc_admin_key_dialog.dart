import 'package:flutter/material.dart';

import 'tr_text.dart';

Future<String?> showQcAdminKeyDialog({
  required BuildContext context,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const TrText('QC Admin Key'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'X-Admin-Key',
              border: OutlineInputBorder(),
            ),
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const TrText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isEmpty) return;
                Navigator.of(ctx).pop(trimmed);
              },
              child: const TrText('Save'),
            ),
          ],
        );
      },
    );
    final trimmed = result?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  } finally {
    controller.dispose();
  }
}
