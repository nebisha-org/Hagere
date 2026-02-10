import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/category_providers.dart';
import '../state/providers.dart';
import '../state/location_name_provider.dart';
import '../state/sponsored_providers.dart';
import '../state/stripe_mode_provider.dart';
import '../state/translation_provider.dart';
import '../state/translation_strings.dart';
import '../state/qc_mode.dart';
import '../models/carousel_item.dart';

import 'entities_screen.dart';
import 'package:agerelige_flutter_client/screens/add_listing_screen.dart';
import 'package:agerelige_flutter_client/widgets/add_listing_carousel.dart';
import 'package:agerelige_flutter_client/widgets/tr_text.dart';
import 'package:agerelige_flutter_client/widgets/qc_editable_text.dart';
// keep import even if hidden, no harm
import 'package:agerelige_flutter_client/widgets/promote_home_tile.dart';
import 'package:agerelige_flutter_client/screens/places_v2_list_screen.dart';
import 'place_detail_screen.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _comingSoonShown = false;
  String? _lastCityKey;

  String _normalize(String raw) {
    return raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _extractCity(String label) {
    final cleaned = label.trim();
    if (cleaned.isEmpty || cleaned.toLowerCase() == 'near you') return null;
    final parts = cleaned.split(',');
    return parts.isEmpty ? null : parts.first.trim();
  }

  String? _extractState(String label) {
    final parts = label.split(',');
    if (parts.length < 2) return null;
    return parts[1].trim();
  }

  bool _isAllowedCity({required String city, String? state}) {
    final cityNorm = _normalize(city);
    final stateNorm = _normalize(state ?? '');

    if (cityNorm == 'dubai') return true;

    if (cityNorm == 'alexandria') {
      return stateNorm == 'va' || stateNorm == 'virginia';
    }

    if (cityNorm == 'silver spring') {
      return stateNorm == 'md' || stateNorm == 'maryland';
    }

    if (cityNorm == 'dc' || cityNorm == 'washington') {
      return true;
    }

    if (stateNorm == 'dc' || stateNorm == 'district of columbia') {
      return true;
    }

    return false;
  }

  void _showComingSoon(String city) {
    if (!mounted || _comingSoonShown) return;
    _comingSoonShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.green,
        content: Text(
          "comming soon to your city '$city'",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _openCarouselEntity(CarouselItem item) async {
    final entityId = item.entityId.trim();
    if (entityId.isEmpty) return;

    try {
      final api = ref.read(entitiesApiProvider);
      final lang = ref.read(translationControllerProvider).language.code;
      final entity = await api.fetchEntityById(entityId, locale: lang);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaceDetailScreen(entity: entity),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final translator = ref.read(translationControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${translator.tr('Could not open listing:')} ${e.toString()}',
          ),
        ),
      );
    }
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(translationControllerProvider);
      if (controller.language == AppLanguage.amharic) {
        controller.prefetch(kTranslationSeed);
      }
    });
    ref.listen<AsyncValue<String>>(locationNameProvider, (prev, next) {
      next.whenData((label) {
        final city = _extractCity(label);
        if (city == null) return;
        final state = _extractState(label);
        final cityKey = '${_normalize(city)}|${_normalize(state ?? '')}';
        if (_lastCityKey == cityKey) return;
        _lastCityKey = cityKey;
        if (_isAllowedCity(city: city, state: state)) return;
        _showComingSoon(city);
      });
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
          title: const TrText('All Habesha'),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              TrText('Getting your location...'),
            ],
          ),
        ),
      );
    }

    final qcState = ref.watch(qcEditStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: kQcMode
            ? GestureDetector(
                onLongPress: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: Icon(
                                qcState.editing ? Icons.edit_off : Icons.edit,
                              ),
                              title: TrText(
                                qcState.editing ? 'Stop edit' : 'Start edit',
                              ),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                ref
                                    .read(qcEditStateProvider.notifier)
                                    .toggleEditing();
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                qcState.visible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              title: TrText(
                                qcState.visible
                                    ? 'Hide edit option'
                                    : 'Show edit option',
                              ),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                final notifier =
                                    ref.read(qcEditStateProvider.notifier);
                                if (qcState.visible) {
                                  notifier.hideControls();
                                } else {
                                  notifier.showControls();
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.close),
                              title: const TrText('Cancel'),
                              onTap: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: const TrText('All Habesha'),
              )
            : const TrText('All Habesha'),
        actions: null,
      ),
      body: catsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              TrText('Loading categories...'),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TrText('Error:'),
              const SizedBox(height: 4),
              Text(e.toString()),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(entitiesRawProvider),
                child: const TrText('Retry'),
              ),
            ],
          ),
        ),
        data: (cats) {
          final displayCats = cats;
          // rows:
          // 0                => Language toggle
          // 0..cats.length-1 => categories
          // cats.length      => AddListingCard
          // cats.length+1    => Sponsored section
          // cats.length+2    => Stripe mode toggle (debug only)
          final showLanguageToggle = true;
          final languageToggleIndex = 0;
          final categoriesStart = showLanguageToggle ? 1 : 0;
          final categoriesCount = displayCats.length;
          final addListingIndex = categoriesStart + categoriesCount;
          final sponsoredIndex = categoriesStart + categoriesCount + 1;
          final showStripeToggle = kQcMode || !kReleaseMode;
          final stripeToggleIndex = categoriesStart + categoriesCount + 2;
          final totalRows =
              categoriesStart + categoriesCount + 2 + (showStripeToggle ? 1 : 0);

          return LayoutBuilder(
            builder: (context, constraints) {
              const double rowHeight = 64;
              const double minCarouselHeight = 140;
              final double bottomInset = MediaQuery.of(context).padding.bottom;
              final double padding = 32 + bottomInset; // 16 top + 16 bottom + safe area
              final double available =
                  constraints.maxHeight - padding - (categoriesCount * rowHeight);
              final double carouselHeight =
                  available > minCarouselHeight ? available : minCarouselHeight;

              return Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                child: ListView.separated(
                  itemCount: totalRows,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                // 0) Language toggle
                if (showLanguageToggle && i == languageToggleIndex) {
                  final controller =
                      ref.watch(translationControllerProvider);
                  return Row(
                    children: [
                      const Spacer(),
                      SegmentedButton<AppLanguage>(
                        segments: const [
                          ButtonSegment(
                            value: AppLanguage.english,
                            label: TrText('English', translate: false),
                          ),
                          ButtonSegment(
                            value: AppLanguage.amharic,
                            label: TrText('አማርኛ', translate: false),
                          ),
                        ],
                        selected: {controller.language},
                        onSelectionChanged: (value) {
                          if (value.isEmpty) return;
                          final selected = value.first;
                          controller.setLanguage(selected);
                          if (selected == AppLanguage.amharic) {
                            controller.prefetch(kTranslationSeed);
                          }
                        },
                      ),
                    ],
                  );
                }

                // 1) Category rows
                if (i >= categoriesStart &&
                    i < categoriesStart + categoriesCount) {
                  final c = displayCats[i - categoriesStart];
                  return ListTile(
                    leading: QcEditableText(
                      c.emoji,
                      entityType: 'category',
                      entityId: c.id,
                      fieldKey: 'emoji',
                      translate: false,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: QcEditableText(
                      c.title,
                      entityType: 'category',
                      entityId: c.id,
                      fieldKey: 'title',
                    ),
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
                      onEntityTap: _openCarouselEntity,
                      onAddTap: () => Navigator.of(context).pushNamed(
                        AddListingScreen.routeName,
                      ),
                    ),
                    error: (_, __) => AddListingCarousel(
                      height: carouselHeight,
                      onEntityTap: _openCarouselEntity,
                      onAddTap: () => Navigator.of(context).pushNamed(
                        AddListingScreen.routeName,
                      ),
                    ),
                    data: (items) => AddListingCarousel(
                      height: carouselHeight,
                      items: items,
                      onEntityTap: _openCarouselEntity,
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
                            child: TrText(
                              'Sponsored on Home',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ...items.take(5).map(
                                (e) {
                                  final entityId = (e['id'] ??
                                          e['item_id'] ??
                                          e['itemId'] ??
                                          '')
                                      .toString();
                                  final name = (e['name'] ?? '').toString();
                                  final categoryId =
                                      (e['categoryId'] ?? '').toString();
                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(Icons.star),
                                      title: entityId.isEmpty
                                          ? TrText(name)
                                          : QcEditableText(
                                              name,
                                              entityType: 'entity',
                                              entityId: entityId,
                                              fieldKey: 'name',
                                            ),
                                      subtitle: entityId.isEmpty
                                          ? TrText(categoryId)
                                          : QcEditableText(
                                              categoryId,
                                              entityType: 'entity',
                                              entityId: entityId,
                                              fieldKey: 'categoryId',
                                            ),
                                      onTap: () {
                                        // OPTIONAL: later route to details or category
                                      },
                                    ),
                                  );
                                },
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

                // 4) Stripe mode toggle (debug only)
                if (showStripeToggle && i == stripeToggleIndex) {
                  final stripeMode = ref.watch(stripeModeProvider);
                  final isTest = stripeMode == StripeMode.test;
                  return SwitchListTile(
                    key: const Key('stripe_mode_toggle'),
                    value: isTest,
                    onChanged: (on) {
                      ref
                          .read(stripeModeProvider.notifier)
                          .setMode(on ? StripeMode.test : StripeMode.live);
                    },
                    title: const TrText('Stripe mode'),
                    subtitle: TrText(isTest ? 'Test' : 'Live'),
                    secondary: const Icon(Icons.payment),
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
