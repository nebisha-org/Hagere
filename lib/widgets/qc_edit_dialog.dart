import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/providers.dart';
import '../state/translation_provider.dart';

Future<String?> showQcEditDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String entityType,
  required String entityId,
  required String fieldKey,
  required String initialValue,
  required String label,
  bool multiline = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final savedEditor = prefs.getString('qc_editor_name') ?? '';
  final editorController = TextEditingController(text: savedEditor);
  final valueController = TextEditingController(text: initialValue);
  final api = ref.read(overridesApiProvider);
  final lang = ref.read(translationControllerProvider).language.code;

  Future<void> saveEditorName(String name) async {
    if (name.trim().isEmpty) return;
    await prefs.setString('qc_editor_name', name.trim());
  }

  Future<void> showHistoryDialog(StateSetter setState) async {
    try {
      setState(() {});
      final history = await api.fetchHistory(
        entityType: entityType,
        entityId: entityId,
        fieldKey: fieldKey,
        locale: lang,
      );
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          if (history.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No history yet.'),
            );
          }
          return ListView.separated(
            itemCount: history.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = history[i];
              final value = (item['value'] ?? '').toString();
              final updatedAt = (item['createdAt'] ?? item['updatedAt'] ?? '')
                  .toString();
              final updatedBy = (item['updatedBy'] ?? '').toString();
              return ListTile(
                title: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    if (updatedAt.isNotEmpty) updatedAt,
                    if (updatedBy.isNotEmpty) 'by $updatedBy',
                  ].join(' • '),
                ),
                onTap: () {
                  valueController.text = value;
                  Navigator.of(ctx).pop();
                },
              );
            },
          );
        },
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load history')),
      );
    }
  }

  String? result;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text('Edit $label'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: valueController,
                    maxLines: multiline ? 6 : 1,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: editorController,
                    decoration: const InputDecoration(
                      labelText: 'Editor (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => showHistoryDialog(setState),
                child: const Text('History'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newValue = valueController.text.trim();
                  if (newValue.isEmpty) return;
                  try {
                    await api.upsertOverride(
                      entityType: entityType,
                      entityId: entityId,
                      fieldKey: fieldKey,
                      locale: lang,
                      value: newValue,
                      updatedBy: editorController.text.trim(),
                    );
                    await saveEditorName(editorController.text);
                    result = newValue;
                    if (context.mounted) Navigator.of(ctx).pop();
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Save failed')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  editorController.dispose();
  valueController.dispose();
  return result;
}
