import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

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
            ? _LocationGate()
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
                                  'No items returned.\n(That means API returned [] or your query is wrong.)',
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
                                      return ListTile(
                                        title: Text(
                                            e['name']?.toString() ?? 'Unknown'),
                                        subtitle: Text(
                                            e['address']?.toString() ?? ''),
                                        trailing: Text(
                                            e['subtype']?.toString() ?? ''),
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
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          // ignore: avoid_print
          print('Enable Location tapped');
          print('🔥🔥🔥 ENABLE LOCATION BUTTON TAPPED 🔥🔥🔥');
          try {
            await ref.read(locationControllerProvider).ensureLocationReady();
            debugPrint('UI: ensureLocationReady finished');
          } catch (e, st) {
            debugPrint('UI: ensureLocationReady FAILED: $e');
            debugPrintStack(stackTrace: st);
          }
          // try {
          //   await ref.read(locationControllerProvider).ensureLocationReady();
          //   //ref.invalidate(entitiesProvider);
          //   ref.refresh(userLocationProvider);
          // } catch (e) {
          //   if (context.mounted) {
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       SnackBar(content: Text(e.toString())),
          //     );
          //   }
          // }
        },
        child: const Text('Enable Location'),
      ),
    );
  }
}
