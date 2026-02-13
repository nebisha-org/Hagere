// places_v2_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/admin_items_api.dart';
import '../state/providers.dart';
import '../state/qc_admin_key_provider.dart';
import '../state/qc_mode.dart';
import '../widgets/qc_admin_key_dialog.dart';
import 'add_listing_screen.dart';
import 'place_detail_screen.dart';
import 'package:agerelige_flutter_client/widgets/tr_text.dart';
import 'package:agerelige_flutter_client/widgets/qc_editable_text.dart';

class Entity {
  final String name;
  final String phone;
  final String address;

  Entity({
    required this.name,
    required this.phone,
    required this.address,
  });

  factory Entity.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().trim();

    final phone = (json['formatted_phone_number'] ??
            json['international_phone_number'] ??
            json['phone'] ??
            '')
        .toString()
        .trim();

    final address =
        (json['formatted_address'] ?? json['address'] ?? '').toString().trim();

    return Entity(
      name: name.isEmpty ? '(no name)' : name,
      phone: phone,
      address: address,
    );
  }
}

class PlacesV2ListScreen extends ConsumerStatefulWidget {
  const PlacesV2ListScreen({super.key});

  @override
  ConsumerState<PlacesV2ListScreen> createState() => _PlacesV2ListScreenState();
}

class _PlacesV2ListScreenState extends ConsumerState<PlacesV2ListScreen> {
  @override
  void initState() {
    super.initState();
    Future(() async {
      try {
        await ref.read(locationControllerProvider).ensureLocationReady();
      } catch (_) {
        // Surface errors via the Enable Location button flow.
      }
    });
  }

  Future<void> _callPhone(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:${phone.trim()}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteEntity(Map<String, dynamic> raw) async {
    final pk = (raw['PK'] ?? '').toString().trim();
    final sk = (raw['SK'] ?? 'META').toString().trim();

    if (pk.isEmpty) {
      if (!mounted) return;
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
    if (!mounted) return;

    var adminKey = ref.read(qcAdminApiKeyProvider).trim();
    if (adminKey.isEmpty) {
      final entered = await showQcAdminKeyDialog(
        context: context,
        initialValue: adminKey,
      );
      if (entered == null) return;
      if (!mounted) return;
      await ref.read(qcAdminApiKeyProvider.notifier).setKey(entered);
      adminKey = entered.trim();
    }

    if (!mounted) return;
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
      await AdminItemsApi().deleteItem(pk: pk, sk: sk, adminKey: adminKey);

      if (mounted) {
        Navigator.of(context).pop(); // loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('Deleted')),
        );
      }

      // Force-refresh (bypass cached entities list).
      ref.read(entitiesRefreshProvider.notifier).state++;
      ref.invalidate(entitiesRawProvider);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(effectiveLocationProvider);
    final entitiesAsync = ref.watch(entitiesProvider);
    final qcState = ref.watch(qcEditStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('Nearby Businesses'),
        actions: (kQcMode && qcState.visible)
            ? [
                IconButton(
                  icon: Icon(
                    qcState.editing ? Icons.edit_off : Icons.edit,
                  ),
                  onPressed: () {
                    ref.read(qcEditStateProvider.notifier).toggleEditing();
                  },
                ),
              ]
            : null,
      ),
      body: (loc?.latitude == null || loc?.longitude == null)
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
          : entitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TrText('Error:'),
                    const SizedBox(height: 4),
                    Text(err.toString()),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        ref.read(entitiesRefreshProvider.notifier).state++;
                        ref.invalidate(entitiesRawProvider);
                      },
                      child: const TrText('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: SizedBox(
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
                          label: const TrText(
                              'Starting free promote your listing'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: TrText('No places found'))
                          : ListView.separated(
                              itemCount: items.length + 1,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                if (i == items.length) {
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
                                        label: const TrText('Reload'),
                                      ),
                                    ),
                                  );
                                }
                                final raw = items[i];
                                final e = Entity.fromJson(raw);
                                final entityId =
                                    (raw['id'] ?? raw['place_id'] ?? '')
                                        .toString();
                                final addressKey =
                                    (raw['formatted_address'] ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty
                                        ? 'formatted_address'
                                        : 'address';
                                final phoneKey =
                                    (raw['formatted_phone_number'] ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty
                                        ? 'formatted_phone_number'
                                        : ((raw['international_phone_number'] ??
                                                    '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty
                                            ? 'international_phone_number'
                                            : 'phone');

                                final tile = ListTile(
                                  title: QcEditableText(
                                    e.name,
                                    entityType: 'entity',
                                    entityId: entityId,
                                    fieldKey: 'name',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (e.address.isNotEmpty)
                                        QcEditableText(
                                          e.address,
                                          entityType: 'entity',
                                          entityId: entityId,
                                          fieldKey: addressKey,
                                        ),
                                      if (e.phone.isNotEmpty)
                                        QcEditableText(
                                          e.phone,
                                          entityType: 'entity',
                                          entityId: entityId,
                                          fieldKey: phoneKey,
                                        ),
                                    ],
                                  ),
                                  trailing: e.phone.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.phone),
                                          onPressed: () => _callPhone(e.phone),
                                        ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PlaceDetailScreen(entity: raw),
                                    ),
                                  ),
                                );

                                final showDelete = kQcMode &&
                                    qcState.visible &&
                                    qcState.editing;
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
                                        onPressed: () => _deleteEntity(raw),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
