// places_v2_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/providers.dart';

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
      address: address.isEmpty ? '(no address)' : address,
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

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Businesses')),
      body: (loc?.latitude == null || loc?.longitude == null)
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Getting your location...'),
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
                    Text('Error: $err'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        ref.read(entitiesRefreshProvider.notifier).state++;
                        ref.invalidate(entitiesRawProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                final entities =
                    items.map((e) => Entity.fromJson(e)).toList();
                if (entities.isEmpty) {
                  return const Center(child: Text('No places found'));
                }

                return ListView.separated(
                  itemCount: entities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = entities[i];

                    return ListTile(
                      title: Text(e.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.address),
                          Text(e.phone.isEmpty ? '(no phone)' : e.phone),
                        ],
                      ),
                      trailing: e.phone.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.phone),
                              onPressed: () => _callPhone(e.phone),
                            ),
                    );
                  },
                );
              },
            ),
    );
  }
}
