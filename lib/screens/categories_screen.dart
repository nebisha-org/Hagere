import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/category_providers.dart';
import '../state/providers.dart';
import '../state/sponsored_providers.dart';

import 'entities_screen.dart';
import 'package:agerelige_flutter_client/screens/add_listing_screen.dart';
import 'package:agerelige_flutter_client/widgets/add_listing_carousel.dart';
// keep import even if hidden, no harm
import 'package:agerelige_flutter_client/widgets/promote_home_tile.dart';
import 'package:agerelige_flutter_client/screens/places_v2_list_screen.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    Future(() async {
      try {
        await ref.read(locationControllerProvider).ensureLocationReady();
      } catch (_) {
        // ignore on home; detail screens will surface if needed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.invalidate(homeSponsoredProvider);
    final loc = ref.watch(userLocationProvider);
    final catsAsync = ref.watch(availableCategoriesProvider);
    final entityIdAsync = ref.watch(currentEntityIdProvider);
    final sponsoredAsync = ref.watch(homeSponsoredProvider);
    final carouselAsync = ref.watch(carouselItemsProvider);

    if (loc == null || loc.latitude == null || loc.longitude == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('All Habesha'),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Getting your location...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Habesha'),
      ),
      body: catsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading categories...'),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(entitiesRawProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (cats) {
          // rows:
          // 0..cats.length-1 => categories
          // cats.length      => AddListingCard
          // cats.length+1    => Sponsored section
          final categoriesCount = cats.length;
          final addListingIndex = categoriesCount;
          final sponsoredIndex = categoriesCount + 1;
          final totalRows = categoriesCount + 2;

          return LayoutBuilder(
            builder: (context, constraints) {
              const double rowHeight = 64;
              const double minCarouselHeight = 140;
              const double padding = 32; // 16 top + 16 bottom
              final double available =
                  constraints.maxHeight - padding - (categoriesCount * rowHeight);
              final double carouselHeight =
                  available > minCarouselHeight ? available : minCarouselHeight;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: ListView.separated(
                  itemCount: totalRows,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                // 1) Category rows
                if (i < categoriesCount) {
                  final c = cats[i];
                  return ListTile(
                    leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
                    title: Text(c.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ref.read(selectedCategoryProvider.notifier).state = c;

                      // Don't block navigation on location permission flow.
                      Future(() async {
                        try {
                          await ref
                              .read(locationControllerProvider)
                              .ensureLocationReady();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      });

                      debugPrint('CATEGORY=${c.id} ${c.title}');
                      debugPrint('GOING TO PlacesV2ListScreen');
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PlacesV2ListScreen(),
                        ),
                      );
                    },
                  );
                }

                // 2) Add Listing card
                if (i == addListingIndex) {
                  return carouselAsync.when(
                    loading: () => AddListingCarousel(
                      height: carouselHeight,
                      onAddTap: () => Navigator.of(context).pushNamed(
                        AddListingScreen.routeName,
                      ),
                    ),
                    error: (_, __) => AddListingCarousel(
                      height: carouselHeight,
                      onAddTap: () => Navigator.of(context).pushNamed(
                        AddListingScreen.routeName,
                      ),
                    ),
                    data: (items) => AddListingCarousel(
                      height: carouselHeight,
                      items: items,
                      onAddTap: () => Navigator.of(context).pushNamed(
                        AddListingScreen.routeName,
                      ),
                    ),
                  );
                }

                // 3) Sponsored section at the bottom
                if (i == sponsoredIndex) {
                  return sponsoredAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (items) {
                      //if (items.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(
                              'Sponsored on Home',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ...items.take(5).map(
                                (e) => Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.star),
                                    title: Text((e['name'] ?? '').toString()),
                                    subtitle:
                                        Text((e['categoryId'] ?? '').toString()),
                                    onTap: () {
                                      // OPTIONAL: later route to details or category
                                    },
                                  ),
                                ),
                              ),
                          // Hidden sponsor tile (not removed) — just keep it disabled:
                          // If you want it back later, change SizedBox.shrink() to the tile.
                          entityIdAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (_) => const SizedBox.shrink(),
                            // data: (entityId) => PromoteHomeTile(
                            //   entityId: entityId,
                            //   paymentsBaseUrl: paymentsBaseUrl,
                            // ),
                          ),
                        ],
                      );
                    },
                  );
                }

                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
