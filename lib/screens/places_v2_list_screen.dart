// places_v2_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/providers.dart';
import '../state/qc_mode.dart';
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
  const PlacesV2ListScreen({Key? key}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(userLocationProvider);
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
                if (items.isEmpty) {
                  return const Center(child: TrText('No places found'));
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final raw = items[i];
                    final e = Entity.fromJson(raw);
                    final entityId = (raw['id'] ?? raw['place_id'] ?? '').toString();
                    final addressKey =
                        (raw['formatted_address'] ?? '').toString().trim().isNotEmpty
                            ? 'formatted_address'
                            : 'address';
                    final phoneKey = (raw['formatted_phone_number'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty
                        ? 'formatted_phone_number'
                        : ((raw['international_phone_number'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty
                                ? 'international_phone_number'
                                : 'phone');

                    return ListTile(
                      title: QcEditableText(
                        e.name,
                        entityType: 'entity',
                        entityId: entityId,
                        fieldKey: 'name',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          builder: (_) => PlaceDetailScreen(entity: raw),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
