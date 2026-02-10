import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/entities_cache.dart';
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

    final editState = ref.watch(qcEditStateProvider);
    if (!editState.visible || !editState.editing) {
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
            final lang = ref.read(translationControllerProvider).language.code;
            await EntitiesCache.applyOverrideToAll(
              entityId: entityId,
              fieldKey: fieldKey,
              value: updated,
              locale: lang,
            );
            if (entityType == 'category') {
              ref.read(categoryOverridesLocalProvider.notifier).update((state) {
                final next =
                    Map<String, Map<String, Map<String, String>>>.from(state);
                final perLang = Map<String, Map<String, String>>.from(
                  next[lang] ?? const <String, Map<String, String>>{},
                );
                final perCat = Map<String, String>.from(
                  perLang[entityId] ?? const <String, String>{},
                );
                perCat[fieldKey] = updated;
                perLang[entityId] = perCat;
                next[lang] = perLang;
                return next;
              });
            }
            ref.invalidate(entitiesRawProvider);
            if (entityType == 'carousel') {
              ref.invalidate(carouselItemsProvider);
            } else if (entityType == 'entity') {
              ref.invalidate(homeSponsoredProvider);
            }
          },
        ),
      ],
    );
  }
}
