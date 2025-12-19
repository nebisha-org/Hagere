import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../utils/geo.dart';

class EntitiesScreen extends ConsumerWidget {
  const EntitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(userLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(entitiesProvider),
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
                  Text(
                    'LOC: ${loc.latitude?.toStringAsFixed(6)}, ${loc.longitude?.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ref.watch(entitiesProvider).when(
                          data: (items) {
                            if (items.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No items returned.\n(API returned [] or your query is wrong.)',
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Items: ${items.length}'),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: items.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, i) {
                                      final e = items[i];

                                      // ✅ Pull from DynamoDB location.lat.N + location.lon.N
                                      final lat = extractCoord(e, 'lat') ??
                                          toDouble(e['latitude']);
                                      final lon = extractCoord(e, 'lon') ??
                                          toDouble(e['longitude']);

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
                                        title: Text(
                                            e['name']?.toString() ?? 'Unknown'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                e['address']?.toString() ?? ''),
                                            const SizedBox(height: 2),
                                            Text(
                                              distanceText,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall,
                                            ),
                                          ],
                                        ),
                                        trailing: Text(
                                            e['subtype']?.toString() ?? ''),
                                        isThreeLine: true,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(
                            child: Text(
                              'Error:\n$err',
                              textAlign: TextAlign.center,
                            ),
                          ),
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
          debugPrint('🔥 ENABLE LOCATION BUTTON TAPPED');
          try {
            await ref.read(locationControllerProvider).ensureLocationReady();
            debugPrint('UI: ensureLocationReady finished');
          } catch (e, st) {
            debugPrint('UI: ensureLocationReady FAILED: $e');
            debugPrintStack(stackTrace: st);
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
