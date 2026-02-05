import '../config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../utils/geo.dart';
import '../state/category_providers.dart';
import '../state/location_name_provider.dart';
import 'package:location/location.dart';
import 'add_listing_screen.dart';
import 'package:agerelige_flutter_client/widgets/add_listing_card.dart';
import 'package:agerelige_flutter_client/widgets/promote_category_tile.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedCategory?.title ?? 'Nearby'),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(entitiesRefreshProvider.notifier).state++;
              ref.invalidate(entitiesRawProvider);
            },
            icon: const Icon(Icons.refresh),
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
                    loading: () => const Text('Finding your area...'),
                    error: (e, _) => const Text('Near you'),
                    data: (name) => Text(
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
                            child: Text(
                              'Error:\n$err',
                              textAlign: TextAlign.center,
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
                                      child:
                                          Text('Could not load device id: $e'),
                                    ),
                                    data: (entityId) => PromoteCategoryTile(
                                      apiBaseUrl: apiBaseUrl,
                                      categoryId: categoryId,
                                      entityId: entityId,
                                    ),
                                  );
                                }

                                // -----------------------------
                                // NORMAL ENTITY ROW
                                // -----------------------------
                                final e = items[i];
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
                                  title:
                                      Text(e['name']?.toString() ?? 'Unknown'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ((e['address']?.toString() ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        Text(e['address'].toString()),
                                      if (phone.isNotEmpty) Text(phone),
                                      const SizedBox(height: 2),
                                      Text(
                                        distanceText,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                  ),
                                  trailing:
                                      Text(e['subtype']?.toString() ?? ''),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          }
        },
        child: const Text('Enable Location'),
      ),
    );
  }
}
