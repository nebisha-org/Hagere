// places_v2_list_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';
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
  static const int _radiusKm = 100;
  static const int _limit = 50;

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

  Future<List<Entity>> fetchEntities({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/entities').replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radiusKm': _radiusKm.toString(),
      'limit': _limit.toString(),
    });
    if (kDebugMode) {
      debugPrint('[PlacesV2] lat=$lat lon=$lon uri=$uri');
    }

    final res = await http.get(uri, headers: {'accept': 'application/json'});

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (kDebugMode) {
      final count = decoded is List
          ? decoded.length
          : (decoded is Map && decoded['items'] is List)
              ? (decoded['items'] as List).length
              : 0;
      debugPrint('[PlacesV2] response items=$count');
    }

    // Your API returns a LIST (you proved it via curl).
    final List<dynamic> list =
        decoded is List ? decoded : (decoded['items'] as List? ?? const []);

    return list
        .whereType<Map>()
        .map((e) => Entity.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _callPhone(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:${phone.trim()}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(userLocationProvider);
    final lat = loc?.latitude;
    final lon = loc?.longitude;

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Businesses')),
      body: (lat == null || lon == null)
          ? _EnableLocation(
              onEnable: () async {
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
              },
            )
          : FutureBuilder<List<Entity>>(
        future: fetchEntities(lat: lat, lon: lon),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final entities = snapshot.data ?? const <Entity>[];
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

class _EnableLocation extends StatelessWidget {
  const _EnableLocation({required this.onEnable});
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: onEnable,
        child: const Text('Enable Location'),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../state/providers.dart';
// import '../state/category_providers.dart';

// class PlacesV2ListScreen extends ConsumerWidget {
//   const PlacesV2ListScreen({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final loc = ref.watch(userLocationProvider);
//     final selectedCat = ref.watch(selectedCategoryProvider);

//     // If location is not yet available, prompt or show a message
//     if (loc?.latitude == null || loc?.longitude == null) {
//       return const Scaffold(
//         body: Center(child: Text('1No location yet')),
//       );
//     }

//     final entitiesAsync = ref.watch(entitiesProvider);
//     return Scaffold(
//       appBar: AppBar(title: Text(selectedCat?.title ?? 'Places')),  // Show category name or generic title
//       body: entitiesAsync.when(
//         loading: () => const Center(child: CircularProgressIndicator()),
//         error: (err, _) => Center(child: Text(err.toString())),
//         data: (entities) {
//           debugPrint('Loaded ${entities.length} places, first: ${entities.isNotEmpty ? entities.first : "NONE"}');
//           if (entities.isEmpty) {
//             return const Center(child: Text('2No places found'));
//           }
//           // List of places
//           return ListView.separated(
//             itemCount: entities.length,
//             separatorBuilder: (_, __) => const Divider(height: 1),
//             itemBuilder: (context, index) {
//               final place = entities[index];
//               // Extract fields with fallbacks for consistency
//               final name = (place['name'] ?? '').toString();
//               final address = (place['address'] ?? place['formatted_address'] ?? '').toString();
//               final phone = (place['formatted_phone_number'] ?? place['phone'] ?? place['contactPhone'] ?? '').toString().trim();

//               return ListTile(
//                 title: Text(name.isNotEmpty ? name : '(no name)'),
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     if (address.isNotEmpty) Text(address),
//                     if (phone.isNotEmpty) Text(phone),
//                   ],
//                 ),
//                 trailing: phone.isNotEmpty 
//                     ? IconButton(
//                         icon: const Icon(Icons.phone),
//                         onPressed: () => launchUrl(Uri.parse('tel:$phone')),
//                       )
//                     : null,
//                 isThreeLine: address.isNotEmpty && phone.isNotEmpty,
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }




//{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}




// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../state/providers.dart';
// import '../state/category_providers.dart';
// import 'package:flutter/foundation.dart';

// class PlacesV2ListScreen extends ConsumerWidget {
//   const PlacesV2ListScreen({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final loc = ref.watch(userLocationProvider);
//     debugPrint('LOC lat=${loc?.latitude} lon=${loc?.longitude}');

//     final cat = ref.watch(selectedCategoryProvider);

//     if (loc?.latitude == null || loc?.longitude == null) {
//       return const Scaffold(
//         body: Center(child: Text('No location yet')),
//       );
//     }

//     final itemsAsync = ref.watch(entitiesProvider);
//     debugPrint('PLACES_SCREEN build');

//     return Scaffold(
//       appBar: AppBar(title: Text(cat?.id ?? 'Places')),
//       body: itemsAsync.when(
//         loading: () => const Center(child: CircularProgressIndicator()),
//         error: (e, _) => Center(child: Text(e.toString())),
//         data: (items) {
//           debugPrint(
//             'UI items len=${items.length} first=${items.isNotEmpty ? items.first : "EMPTY"}',
//           );

//           if (items.isEmpty) {
//             return const Center(child: Text('No places found'));
//           }

//           return ListView.separated(
//             itemCount: items.length,
//             separatorBuilder: (_, __) => const Divider(height: 1),
//             itemBuilder: (context, i) {
//               final p = items[i];

//               final name = (p['name'] ?? '').toString();
//               final address =
//                   (p['address'] ?? p['formatted_address'] ?? '').toString();
//               final phone =
//                   (p['formatted_phone_number'] ?? p['phone'] ?? '')
//                       .toString()
//                       .trim();

//               return ListTile(
//                 title: Text(name.isEmpty ? '(no name)' : name),
//                 subtitle: Text(address),
//                 trailing: phone.isEmpty
//                     ? null
//                     : IconButton(
//                         icon: const Icon(Icons.phone),
//                         onPressed: () =>
//                             launchUrl(Uri.parse('tel:$phone')),
//                       ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
