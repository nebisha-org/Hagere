import '../config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_items_api.dart';
import '../state/providers.dart';
import '../utils/geo.dart';
import '../state/category_providers.dart';
import '../state/location_name_provider.dart';
import '../state/translation_provider.dart';
import '../state/qc_mode.dart';
import '../state/override_providers.dart';
import 'add_listing_screen.dart';
import 'package:agerelige_flutter_client/widgets/add_listing_card.dart';
import 'package:agerelige_flutter_client/widgets/promote_category_tile.dart';
import 'package:agerelige_flutter_client/widgets/tr_text.dart';
import 'package:agerelige_flutter_client/widgets/qc_editable_text.dart';

class _DeleteAuthPromptResult {
  final String deletedBy;
  final String password;

  const _DeleteAuthPromptResult({
    required this.deletedBy,
    required this.password,
  });
}

class EntitiesScreen extends ConsumerWidget {
  const EntitiesScreen({super.key});
  static const showAddListing = false;
  static const showPromote = false;

  Future<_DeleteAuthPromptResult?> _promptDeletePassword(
    BuildContext context,
  ) async {
    final deletedByCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscure = true;
    final result = await showDialog<_DeleteAuthPromptResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const TrText('Enter delete password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: deletedByCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Deleted by',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
                onSubmitted: (_) => Navigator.of(ctx).pop(
                  _DeleteAuthPromptResult(
                    deletedBy: deletedByCtrl.text.trim(),
                    password: passwordCtrl.text.trim(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const TrText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(
                _DeleteAuthPromptResult(
                  deletedBy: deletedByCtrl.text.trim(),
                  password: passwordCtrl.text.trim(),
                ),
              ),
              child: const TrText('Continue'),
            ),
          ],
        ),
      ),
    );
    deletedByCtrl.dispose();
    passwordCtrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(effectiveLocationProvider);
    final locNameAsync = ref.watch(locationNameProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final entityIdAsync = ref.watch(currentEntityIdProvider);
    final resolvedCats = ref.watch(resolvedCategoriesProvider);
    final selectedResolved = selectedCategory == null
        ? null
        : (resolvedCats.firstWhere(
            (c) => c.id == selectedCategory.id,
            orElse: () => selectedCategory,
          ));
    final qcState = ref.watch(qcEditStateProvider);
    final showDelete = kQcMode && qcState.visible && qcState.editing;

    Future<void> deleteEntity(Map<String, dynamic> raw) async {
      final pk = (raw['PK'] ?? '').toString().trim();
      final sk = (raw['SK'] ?? 'META').toString().trim();
      if (pk.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('Missing item PK')),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const TrText('Delete item?'),
          content: TrText(
            'This will remove it from the list and delete it on the backend.\n\nPK: $pk',
            translate: false,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const TrText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const TrText('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!context.mounted) return;

      final deleteAuth = await _promptDeletePassword(context);
      if (deleteAuth == null) return;
      if (deleteAuth.deletedBy.trim().isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('Deleted by required')),
        );
        return;
      }
      if (deleteAuth.password.trim().isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('Password required')),
        );
        return;
      }

      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: TrText('Deleting...')),
            ],
          ),
        ),
      );

      try {
        await AdminItemsApi().deleteItem(
          pk: pk,
          sk: sk,
          adminKey: deleteAuth.password,
          deletedBy: deleteAuth.deletedBy,
        );
        if (context.mounted) {
          Navigator.of(context).pop(); // loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TrText('Deleted')),
          );
        }

        ref.read(entitiesRefreshProvider.notifier).state++;
        ref.invalidate(entitiesRawProvider);
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: selectedResolved == null
            ? const TrText('Nearby')
            : QcEditableText(
                selectedResolved.title,
                entityType: 'category',
                entityId: selectedResolved.id,
                fieldKey: 'title',
              ),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(entitiesRefreshProvider.notifier).state++;
              ref.invalidate(entitiesRawProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
          if (kQcMode && qcState.visible)
            IconButton(
              icon: Icon(
                qcState.editing ? Icons.edit_off : Icons.edit,
              ),
              onPressed: () {
                ref.read(qcEditStateProvider.notifier).toggleEditing();
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loc == null
            ? const _LocationGate()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  locNameAsync.when(
                    loading: () => const TrText('Finding your area...'),
                    error: (e, _) => const TrText('Near you'),
                    data: (name) => TrText(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddListingScreen(
                            origin: AddListingOrigin.categoryList,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.trending_up),
                      label: const TrText('Starting free promote your listing'),
                    ),
                  ),
                  // Text(
                  //   'LOC: ${loc.latitude?.toStringAsFixed(6)}, '
                  //   '${loc.longitude?.toStringAsFixed(6)}',
                  // ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ref.watch(entitiesProvider).when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const TrText('Error:'),
                                const SizedBox(height: 4),
                                Text(err.toString()),
                              ],
                            ),
                          ),
                          data: (items) {
                            const extra =
                                (EntitiesScreen.showAddListing ? 1 : 0) +
                                    (EntitiesScreen.showPromote ? 1 : 0);
                            const reloadExtra = 1;
                            return ListView.separated(
                              itemCount: items.length + extra + reloadExtra,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                // -----------------------------
                                // ➕ ADD LISTING CARD
                                // -----------------------------
                                if (i == items.length) {
                                  return AddListingCard(
                                    subtitle:
                                        'Add your business to this category.',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const AddListingScreen(
                                          origin: AddListingOrigin.categoryList,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                // -----------------------------
                                // ⭐ PROMOTE CATEGORY TILE
                                // -----------------------------
                                if (i == items.length + 1) {
                                  final categoryId = selectedResolved?.id ?? '';
                                  if (categoryId.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return entityIdAsync.when(
                                    loading: () => const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                    error: (e, _) => Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: TrText(
                                          'Could not load device id: $e'),
                                    ),
                                    data: (entityId) => PromoteCategoryTile(
                                      paymentsBaseUrl: paymentsBaseUrl,
                                      categoryId: categoryId,
                                      entityId: entityId,
                                    ),
                                  );
                                }

                                if (i == items.length + extra) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Center(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          ref
                                              .read(entitiesLimitProvider
                                                  .notifier)
                                              .state += 1000;
                                          ref
                                              .read(entitiesRefreshProvider
                                                  .notifier)
                                              .state++;
                                          ref.invalidate(entitiesRawProvider);
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const TrText('Load more'),
                                      ),
                                    ),
                                  );
                                }

                                // -----------------------------
                                // NORMAL ENTITY ROW
                                // -----------------------------
                                final e = items[i];
                                final entityId =
                                    (e['id'] ?? e['place_id'] ?? '').toString();
                                final phone =
                                    (e['contactPhone'] ?? e['phone'] ?? '')
                                        .toString()
                                        .trim();
                                final lat = extractCoord(e, 'lat') ??
                                    toDouble(e['latitude']);
                                final lon = extractCoord(e, 'lon') ??
                                    toDouble(e['longitude']) ??
                                    toDouble(e['lng']);

                                String distanceText = '—';

                                if (lat != null &&
                                    lon != null &&
                                    loc.latitude != null &&
                                    loc.longitude != null) {
                                  final meters = distanceMeters(
                                    lat1: loc.latitude!,
                                    lon1: loc.longitude!,
                                    lat2: lat,
                                    lon2: lon,
                                  );

                                  distanceText = meters < 1000
                                      ? '${meters.round()} m'
                                      : '${(meters / 1000).toStringAsFixed(1)} km';
                                }

                                final tile = ListTile(
                                  title: QcEditableText(
                                    e['name']?.toString() ?? 'Unknown',
                                    entityType: 'entity',
                                    entityId: entityId,
                                    fieldKey: 'name',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ((e['address']?.toString() ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        QcEditableText(
                                          e['address'].toString(),
                                          entityType: 'entity',
                                          entityId: entityId,
                                          fieldKey: 'address',
                                        ),
                                      if (phone.isNotEmpty)
                                        QcEditableText(
                                          phone,
                                          entityType: 'entity',
                                          entityId: entityId,
                                          fieldKey: 'phone',
                                        ),
                                      const SizedBox(height: 2),
                                      TrText(
                                        distanceText,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                  ),
                                  trailing: QcEditableText(
                                    e['subtype']?.toString() ?? '',
                                    entityType: 'entity',
                                    entityId: entityId,
                                    fieldKey: 'subtype',
                                  ),
                                  isThreeLine: true,
                                );

                                if (!showDelete) return tile;

                                return Stack(
                                  children: [
                                    tile,
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: IconButton(
                                        tooltip: 'Delete',
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 34,
                                          minHeight: 34,
                                        ),
                                        onPressed: () => deleteEntity(e),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LocationGate extends ConsumerWidget {
  const _LocationGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          try {
            await ref.read(locationControllerProvider).ensureLocationReady();
          } catch (e) {
            if (context.mounted) {
              final translator = ref.read(translationControllerProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${translator.tr('Error:')} ${e.toString()}',
                  ),
                ),
              );
            }
          }
        },
        child: const TrText('Enable Location'),
      ),
    );
  }
}
