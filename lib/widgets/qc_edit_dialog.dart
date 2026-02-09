import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/overrides_api.dart';
import '../state/providers.dart';
import '../state/translation_provider.dart';
import 'tr_text.dart';

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
  final api = ref.read(overridesApiProvider);
  final controller = ref.read(translationControllerProvider);
  final lang = controller.language.code;

  var displayValue = initialValue;
  if (controller.language == AppLanguage.amharic && initialValue.trim().isNotEmpty) {
    try {
      await controller.prefetch([initialValue]);
      displayValue = controller.tr(initialValue);
    } catch (_) {
      displayValue = controller.tr(initialValue);
    }
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) => _QcEditDialog(
      entityType: entityType,
      entityId: entityId,
      fieldKey: fieldKey,
      initialValue: displayValue,
      label: label,
      multiline: multiline,
      prefs: prefs,
      api: api,
      locale: lang,
    ),
  );
}

class _QcEditDialog extends StatefulWidget {
  const _QcEditDialog({
    required this.entityType,
    required this.entityId,
    required this.fieldKey,
    required this.initialValue,
    required this.label,
    required this.multiline,
    required this.prefs,
    required this.api,
    required this.locale,
  });

  final String entityType;
  final String entityId;
  final String fieldKey;
  final String initialValue;
  final String label;
  final bool multiline;
  final SharedPreferences prefs;
  final OverridesApi api;
  final String locale;

  @override
  State<_QcEditDialog> createState() => _QcEditDialogState();
}

class _QcEditDialogState extends State<_QcEditDialog> {
  late final TextEditingController _editorController;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    final savedEditor = widget.prefs.getString('qc_editor_name') ?? '';
    _editorController = TextEditingController(text: savedEditor);
    _valueController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _editorController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _saveEditorName(String name) async {
    if (name.trim().isEmpty) return;
    await widget.prefs.setString('qc_editor_name', name.trim());
  }

  Future<void> _showHistoryDialog() async {
    try {
      final history = await widget.api.fetchHistory(
        entityType: widget.entityType,
        entityId: widget.entityId,
        fieldKey: widget.fieldKey,
        locale: widget.locale,
      );
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          if (history.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: TrText('No history yet.'),
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
                title: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (updatedAt.isNotEmpty) updatedAt,
                    if (updatedBy.isNotEmpty) 'by $updatedBy',
                  ].join(' • '),
                ),
                onTap: () {
                  _valueController.text = value;
                  Navigator.of(ctx).pop();
                },
              );
            },
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('Failed to load history')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: TrText('Edit ${widget.label}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _valueController,
              maxLines: widget.multiline ? 6 : 1,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editorController,
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
          onPressed: _showHistoryDialog,
          child: const TrText('History'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final newValue = _valueController.text.trim();
            if (newValue.isEmpty) return;
            try {
              await widget.api.upsertOverride(
                entityType: widget.entityType,
                entityId: widget.entityId,
                fieldKey: widget.fieldKey,
                locale: widget.locale,
                value: newValue,
                updatedBy: _editorController.text.trim(),
              );
              await _saveEditorName(_editorController.text);
              if (mounted) Navigator.of(context).pop(newValue);
            } catch (_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: TrText('Save failed')),
              );
            }
          },
          child: const TrText('Save'),
        ),
      ],
    );
  }
}
