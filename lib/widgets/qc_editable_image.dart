import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/entities_cache.dart';
import '../state/qc_mode.dart';
import '../state/override_providers.dart';
import '../state/providers.dart';
import '../state/sponsored_providers.dart';
import 'qc_edit_dialog.dart';

class QcEditableImage extends ConsumerWidget {
  const QcEditableImage({
    super.key,
    required this.child,
    required this.entityType,
    required this.entityId,
    required this.fieldKey,
    required this.imageUrl,
    this.onUpdated,
    this.label,
  });

  final Widget child;
  final String entityType;
  final String entityId;
  final String fieldKey;
  final String imageUrl;
  final void Function(String value)? onUpdated;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kQcMode || entityId.trim().isEmpty) {
      return child;
    }
    final editState = ref.watch(qcEditStateProvider);
    if (!editState.visible || !editState.editing) {
      return child;
    }
    return Stack(
      children: [
        child,
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black.withOpacity(0.5),
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.edit, size: 16, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () async {
                final updated = await showQcEditDialog(
                  context: context,
                  ref: ref,
                  entityType: entityType,
                  entityId: entityId,
                  fieldKey: fieldKey,
                  initialValue: imageUrl,
                  label: label ?? fieldKey,
                  multiline: false,
                );
                if (updated == null) return;
                onUpdated?.call(updated);
                await EntitiesCache.clearAll();
                ref.invalidate(entitiesRawProvider);
                ref.invalidate(categoryOverridesProvider);
                ref.invalidate(carouselItemsProvider);
                ref.invalidate(homeSponsoredProvider);
              },
            ),
          ),
        ),
      ],
    );
  }
}
