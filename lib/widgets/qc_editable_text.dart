import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/qc_mode.dart';
import '../state/override_providers.dart';
import '../state/providers.dart';
import '../state/sponsored_providers.dart';
import '../state/translation_provider.dart';
import 'qc_edit_dialog.dart';

class QcEditableText extends ConsumerWidget {
  const QcEditableText(
    this.value, {
    super.key,
    required this.entityType,
    required this.entityId,
    required this.fieldKey,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.translate = true,
    this.onUpdated,
    this.label,
  });

  final String value;
  final String entityType;
  final String entityId;
  final String fieldKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final bool translate;
  final void Function(String value)? onUpdated;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(translationControllerProvider);
    final display = translate ? controller.tr(value) : value;

    final textWidget = Text(
      display,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );

    if (!kQcMode || entityId.trim().isEmpty) {
      return textWidget;
    }

    final editMode = ref.watch(qcEditModeProvider);
    if (!editMode) {
      return textWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: textWidget),
        IconButton(
          icon: const Icon(Icons.edit, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () async {
            final updated = await showQcEditDialog(
              context: context,
              ref: ref,
              entityType: entityType,
              entityId: entityId,
              fieldKey: fieldKey,
              initialValue: value,
              label: label ?? fieldKey,
              multiline: (maxLines ?? 1) > 1,
            );
            if (updated == null) return;
            onUpdated?.call(updated);
            ref.invalidate(entitiesRawProvider);
            ref.invalidate(categoryOverridesProvider);
            ref.invalidate(carouselItemsProvider);
            ref.invalidate(homeSponsoredProvider);
          },
        ),
      ],
    );
  }
}
