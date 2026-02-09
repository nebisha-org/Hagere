import '../config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../utils/geo.dart';
import '../state/category_providers.dart';
import '../state/location_name_provider.dart';
import '../state/translation_provider.dart';
import '../state/qc_mode.dart';
import 'package:location/location.dart';
import 'add_listing_screen.dart';
import 'package:agerelige_flutter_client/widgets/add_listing_card.dart';
import 'package:agerelige_flutter_client/widgets/promote_category_tile.dart';
import 'package:agerelige_flutter_client/widgets/tr_text.dart';
import 'package:agerelige_flutter_client/widgets/qc_editable_text.dart';

class EntitiesScreen extends ConsumerWidget {
  const EntitiesScreen({super.key});
  static const showAddListing = false;
  static const showPromote = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(userLocationProvider);
    final locNameAsync = ref.watch(locationNameProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final entityIdAsync = ref.watch(currentEntityIdProvider);
    final qcState = ref.watch(qcEditStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: selectedCategory == null
            ? const TrText('Nearby')
            : QcEditableText(
                selectedCategory.title,
                entityType: 'category',
                entityId: selectedCategory.id,
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
                            return ListView.separated(
                              itemCount: items.length + extra,
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
                                    onTap: () =>
                                        Navigator.of(context).pushNamed(
                                      AddListingScreen.routeName,
                                    ),
                                  );
                                }

                                // -----------------------------
                                // ⭐ PROMOTE CATEGORY TILE
                                // -----------------------------
                                if (i == items.length + 1) {
                                  final categoryId = selectedCategory?.id ?? '';
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

                                // -----------------------------
                                // NORMAL ENTITY ROW
                                // -----------------------------
                                final e = items[i];
                                final entityId =
                                    (e['id'] ?? e['place_id'] ?? '')
                                        .toString();
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

                                return ListTile(
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
                                  trailing:
                                      QcEditableText(
                                        e['subtype']?.toString() ?? '',
                                        entityType: 'entity',
                                        entityId: entityId,
                                        fieldKey: 'subtype',
                                      ),
                                  isThreeLine: true,
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
              final translator =
                  ref.read(translationControllerProvider);
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
