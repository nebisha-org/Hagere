import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/category_providers.dart';
import '../state/providers.dart';
import '../state/location_name_provider.dart';
import '../state/sponsored_providers.dart';
import '../state/payment_type_provider.dart';
import '../state/stripe_mode_provider.dart';
import '../state/translation_provider.dart';
import '../state/translation_strings.dart';
import '../state/qc_mode.dart';
import '../state/qc_city_provider.dart';
import '../state/override_providers.dart';
import '../models/carousel_item.dart';

import 'package:agerelige_flutter_client/screens/add_listing_screen.dart';
import 'package:agerelige_flutter_client/widgets/add_listing_carousel.dart';
import 'package:agerelige_flutter_client/widgets/location_required_gate.dart';
import 'package:agerelige_flutter_client/widgets/tr_text.dart';
import 'package:agerelige_flutter_client/widgets/qc_editable_text.dart';
import 'package:agerelige_flutter_client/screens/places_v2_list_screen.dart';
import 'package:agerelige_flutter_client/screens/my_posted_items_screen.dart';
import 'feedback_screen.dart';
import 'place_detail_screen.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _comingSoonShown = false;
  String? _lastCityKey;
  static const Duration _qcLongPressDuration = Duration(seconds: 6);
  late final ProviderSubscription<AsyncValue<String>> _locationNameSub;

  void _cycleQcState() {
    final qcState = ref.read(qcEditStateProvider);
    final notifier = ref.read(qcEditStateProvider.notifier);
    if (qcState.visible || qcState.editing) {
      notifier.hideControls();
      return;
    }
    notifier.startEditing();
  }

  void _setAppTitleOverride(String value) {
    final lang = ref.read(translationControllerProvider).language.code;
    ref.read(appTextOverridesLocalProvider.notifier).update((state) {
      final next = Map<String, Map<String, String>>.from(state);
      final perLang = Map<String, String>.from(next[lang] ?? const {});
      perLang['title'] = value;
      next[lang] = perLang;
      return next;
    });
  }

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

  void _openMyPostedItems() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MyPostedItemsScreen(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (kQcMode) {
      // Enforce owner intent on launch: keep QC enabled, but hidden/non-editing
      // until the 6-second title long-press is used.
      ref.read(qcEditStateProvider.notifier).hideControls();
    }
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
    _locationNameSub = ref
        .listenManual<AsyncValue<String>>(locationNameProvider, (prev, next) {
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
  void dispose() {
    _locationNameSub.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.invalidate(homeSponsoredProvider);
    final loc = ref.watch(effectiveLocationProvider);
    final catsAsync = ref.watch(availableCategoriesProvider);
    final entityIdAsync = ref.watch(currentEntityIdProvider);
    final sponsoredAsync = ref.watch(homeSponsoredProvider);
    final carouselAsync = ref.watch(carouselItemsProvider);
    final locationBlockReason = ref.watch(locationBlockReasonProvider);
    final appTitle = ref.watch(resolvedAppTitleProvider);
    final appTitleWidget = QcEditableText(
      appTitle,
      entityType: 'app',
      entityId: 'title',
      fieldKey: 'title',
      translate: false,
      onUpdated: _setAppTitleOverride,
    );

    if (loc == null || loc.latitude == null || loc.longitude == null) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: kQcMode
              ? RawGestureDetector(
                  gestures: {
                    LongPressGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                            LongPressGestureRecognizer>(
                      () => LongPressGestureRecognizer(
                        duration: _qcLongPressDuration,
                      ),
                      (instance) {
                        instance.onLongPress = _cycleQcState;
                      },
                    ),
                  },
                  child: appTitleWidget,
                )
              : appTitleWidget,
          actions: [
            IconButton(
              onPressed: _openMyPostedItems,
              icon: const Icon(Icons.inventory_2_outlined),
              tooltip:
                  ref.read(translationControllerProvider).tr('My posted items'),
            ),
          ],
        ),
        body: locationBlockReason == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    TrText('Getting your location...'),
                  ],
                ),
              )
            : const LocationRequiredGate(),
      );
    }

    final qcState = ref.watch(qcEditStateProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: kQcMode
            ? RawGestureDetector(
                gestures: {
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer(
                      duration: _qcLongPressDuration,
                    ),
                    (instance) {
                      instance.onLongPress = _cycleQcState;
                    },
                  ),
                },
                child: appTitleWidget,
              )
            : appTitleWidget,
        actions: [
          IconButton(
            onPressed: _openMyPostedItems,
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip:
                ref.read(translationControllerProvider).tr('My posted items'),
          ),
        ],
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
          // cats.length+2    => Feedback / Contact us
          // (optional)       => Payment type toggle (QC/edit only)
          // (optional)       => Stripe mode toggle (QC/edit only)
          const bool showLanguageToggle = true;
          const int languageToggleIndex = 0;
          const int categoriesStart = 1;
          final categoriesCount = displayCats.length;
          final qcActive = qcState.visible || qcState.editing;
          final showPaymentTypeToggle = kQcMode && qcState.editing;
          final showStripeToggle = kQcMode && qcActive;
          final showQcCityToggle = showStripeToggle;

          var nextIndex = categoriesStart + categoriesCount;
          final addListingIndex = nextIndex++;
          final sponsoredIndex = nextIndex++;
          final feedbackIndex = nextIndex++;
          final int? paymentTypeToggleIndex =
              showPaymentTypeToggle ? nextIndex++ : null;
          final int? stripeToggleIndex = showStripeToggle ? nextIndex++ : null;
          final int? qcCityToggleIndex = showQcCityToggle ? nextIndex++ : null;
          final totalRows = nextIndex;

          return LayoutBuilder(
            builder: (context, constraints) {
              const double rowHeight = 64;
              const double minCarouselHeight = 140;
              final double bottomInset = MediaQuery.of(context).padding.bottom;
              final double padding =
                  32 + bottomInset; // 16 top + 16 bottom + safe area
              final double available = constraints.maxHeight -
                  padding -
                  (categoriesCount * rowHeight);
              final double carouselHeight =
                  available > minCarouselHeight ? available : minCarouselHeight;
              final bool isTablet = constraints.maxWidth >= 700;

              void openCategory(dynamic c) {
                ref.read(selectedCategoryProvider.notifier).state = c;
                ref.invalidate(entitiesRawProvider);

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
              }

              Widget buildLanguageToggle() {
                final controller = ref.watch(translationControllerProvider);
                return Row(
                  children: [
                    const Spacer(),
                    SegmentedButton<AppLanguage>(
                      segments: const [
                        ButtonSegment(
                          value: AppLanguage.english,
                          label: TrText('EN', translate: false),
                        ),
                        ButtonSegment(
                          value: AppLanguage.amharic,
                          label: TrText('አማ', translate: false),
                        ),
                      ],
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        minimumSize: WidgetStatePropertyAll(Size(0, 32)),
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                      ),
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

              Widget buildAddListingSection(double sectionHeight) {
                return carouselAsync.when(
                  loading: () => AddListingCarousel(
                    height: sectionHeight,
                    onEntityTap: _openCarouselEntity,
                    onAddTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddListingScreen(
                          origin: AddListingOrigin.carousel,
                        ),
                      ),
                    ),
                  ),
                  error: (_, __) => AddListingCarousel(
                    height: sectionHeight,
                    onEntityTap: _openCarouselEntity,
                    onAddTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddListingScreen(
                          origin: AddListingOrigin.carousel,
                        ),
                      ),
                    ),
                  ),
                  data: (items) => AddListingCarousel(
                    height: sectionHeight,
                    items: items,
                    onEntityTap: _openCarouselEntity,
                    onAddTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddListingScreen(
                          origin: AddListingOrigin.carousel,
                        ),
                      ),
                    ),
                  ),
                );
              }

              Widget buildSponsoredSection() {
                return sponsoredAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: TrText(
                          'No sponsored listings yet.',
                          translate: false,
                        ),
                      );
                    }
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
                            final entityId =
                                (e['id'] ?? e['item_id'] ?? e['itemId'] ?? '')
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

              Widget buildFeedbackTile() {
                return ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: const TrText('Feedback / Contact us'),
                  subtitle: const TrText(
                    'Report a bug or request a feature.',
                    translate: false,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed(
                    FeedbackScreen.routeName,
                  ),
                );
              }

              Widget buildTabletFeedbackPanel() {
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).pushNamed(
                      FeedbackScreen.routeName,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.feedback_outlined, size: 30),
                          SizedBox(height: 14),
                          TrText(
                            'Feedback / Contact us',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 10),
                          TrText(
                            'Report a bug, request a feature, or share improvements for All Habesha.',
                            style: TextStyle(fontSize: 15),
                            translate: false,
                          ),
                          Spacer(),
                          Row(
                            children: [
                              Spacer(),
                              Icon(Icons.arrow_forward),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              Widget buildTabletSponsoredPanel() {
                return Card(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: buildSponsoredSection(),
                  ),
                );
              }

              Widget buildTabletPromotePanel() {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.campaign_outlined, size: 30),
                        const SizedBox(height: 14),
                        const TrText(
                          'Promote your listing',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                          translate: false,
                        ),
                        const SizedBox(height: 10),
                        const TrText(
                          'No sponsored items yet. Add or promote a listing to appear here.',
                          style: TextStyle(fontSize: 15),
                          translate: false,
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddListingScreen(
                                origin: AddListingOrigin.carousel,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.add_business),
                          label: const TrText('Add listing', translate: false),
                        ),
                      ],
                    ),
                  ),
                );
              }

              Widget buildPaymentTypeToggle() {
                final paymentType = ref.watch(paymentTypeProvider);
                final isSubscription = paymentType == PaymentType.subscription;
                return SwitchListTile(
                  key: const Key('payment_type_toggle'),
                  value: isSubscription,
                  onChanged: (on) {
                    ref.read(paymentTypeProvider.notifier).setType(
                          on ? PaymentType.subscription : PaymentType.oneTime,
                        );
                  },
                  title: const TrText('Payment option'),
                  subtitle: TrText(
                    isSubscription ? 'Subscription (every 7 days)' : 'One-time',
                  ),
                  secondary: const Icon(Icons.repeat),
                );
              }

              Widget buildStripeToggle() {
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

              Widget buildQcCityToggle() {
                final selectedKey = ref.watch(qcCityOverrideProvider);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.location_city),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedKey,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            label: TrText('QC city', translate: false),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          hint: const TrText('Choose city', translate: false),
                          items: qcCityOptions
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.key,
                                  child: Text(c.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            ref
                                .read(qcCityOverrideProvider.notifier)
                                .setOverride(value);
                            ref.read(entitiesLimitProvider.notifier).state =
                                1000;
                            ref.invalidate(locationNameProvider);
                            ref.invalidate(carouselItemsProvider);
                            ref.invalidate(entitiesRawProvider);
                            ref.invalidate(availableCategoriesProvider);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (isTablet) {
                final int gridColumns = constraints.maxWidth >= 1000 ? 3 : 2;
                final double gridAspect =
                    constraints.maxWidth >= 1000 ? 4.8 : 4.0;
                final int gridRows =
                    ((categoriesCount + gridColumns - 1) / gridColumns).floor();
                final double tabletGridHeight =
                    (gridRows * 68.0) + ((gridRows - 1).clamp(0, 100) * 10.0);
                final double tabletCarouselHeight =
                    (constraints.maxHeight * 0.28)
                        .clamp(220.0, 320.0)
                        .toDouble();
                final bool hasSponsoredItems = sponsoredAsync.maybeWhen(
                  data: (items) => items.isNotEmpty,
                  orElse: () => false,
                );
                return Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
                  child: Column(
                    children: [
                      buildLanguageToggle(),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: tabletGridHeight,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridColumns,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: gridAspect,
                          ),
                          itemCount: categoriesCount,
                          itemBuilder: (context, index) {
                            final c = displayCats[index];
                            return Material(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => openCategory(c),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Row(
                                    children: [
                                      QcEditableText(
                                        c.emoji,
                                        entityType: 'category',
                                        entityId: c.id,
                                        fieldKey: 'emoji',
                                        translate: false,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: QcEditableText(
                                          c.title,
                                          entityType: 'category',
                                          entityId: c.id,
                                          fieldKey: 'title',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 17),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      buildAddListingSection(tabletCarouselHeight),
                      if (paymentTypeToggleIndex != null)
                        buildPaymentTypeToggle(),
                      if (stripeToggleIndex != null) buildStripeToggle(),
                      if (qcCityToggleIndex != null) buildQcCityToggle(),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: hasSponsoredItems ? 320 : 240,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: buildTabletFeedbackPanel()),
                            const SizedBox(width: 16),
                            Expanded(
                              child: hasSponsoredItems
                                  ? buildTabletSponsoredPanel()
                                  : buildTabletPromotePanel(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                child: ListView.separated(
                  itemCount: totalRows,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    // 0) Language toggle
                    if (showLanguageToggle && i == languageToggleIndex) {
                      return buildLanguageToggle();
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
                        onTap: () => openCategory(c),
                      );
                    }

                    // 2) Add Listing card
                    if (i == addListingIndex) {
                      return buildAddListingSection(carouselHeight);
                    }

                    // 3) Sponsored section at the bottom
                    if (i == sponsoredIndex) {
                      return buildSponsoredSection();
                    }

                    // 4) Feedback / Contact us
                    if (i == feedbackIndex) {
                      return buildFeedbackTile();
                    }

                    // 4) Payment type toggle (QC/edit only)
                    if (paymentTypeToggleIndex != null &&
                        i == paymentTypeToggleIndex) {
                      return buildPaymentTypeToggle();
                    }

                    // 5) Stripe mode toggle (QC/edit only)
                    if (stripeToggleIndex != null && i == stripeToggleIndex) {
                      return buildStripeToggle();
                    }

                    if (qcCityToggleIndex != null && i == qcCityToggleIndex) {
                      return buildQcCityToggle();
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
