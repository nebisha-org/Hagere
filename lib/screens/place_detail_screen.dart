import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/geo.dart';
import 'package:agerelige_flutter_client/widgets/tr_text.dart';
import '../state/qc_mode.dart';
import 'package:agerelige_flutter_client/widgets/qc_editable_text.dart';
import 'package:agerelige_flutter_client/widgets/qc_editable_image.dart';

class PlaceDetailScreen extends ConsumerStatefulWidget {
  const PlaceDetailScreen({super.key, required this.entity});

  final Map<String, dynamic> entity;

  @override
  ConsumerState<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends ConsumerState<PlaceDetailScreen> {
  static const _favoritesKey = 'favorite_places';
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  String _placeId(Map<String, dynamic> e) {
    return (e['place_id'] ??
            e['PK'] ??
            e['id'] ??
            '${e['name']}-${e['lat']}-${e['lon']}')
        .toString();
  }

  Future<void> _loadFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final set = prefs.getStringList(_favoritesKey) ?? const [];
    final id = _placeId(widget.entity);
    if (!mounted) return;
    setState(() => _isFavorite = set.contains(id));
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final set = prefs.getStringList(_favoritesKey)?.toSet() ?? <String>{};
    final id = _placeId(widget.entity);
    if (set.contains(id)) {
      set.remove(id);
      setState(() => _isFavorite = false);
    } else {
      set.add(id);
      setState(() => _isFavorite = true);
    }
    await prefs.setStringList(_favoritesKey, set.toList());
  }

  String _str(dynamic v) => (v ?? '').toString().trim();

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  List<String> _extractImages(Map<String, dynamic> e) {
    final out = <String>[];
    void addUrl(dynamic v) {
      final s = _str(v);
      if (s.isEmpty) return;
      if (s.startsWith('http://') || s.startsWith('https://')) {
        out.add(s);
      }
    }

    if (e['images'] is List) {
      for (final v in e['images'] as List) {
        addUrl(v);
      }
    }
    addUrl(e['image']);
    addUrl(e['photo']);
    addUrl(e['thumbnail']);
    addUrl(e['logo']);
    addUrl(e['image_url']);

    final raw = e['raw'];
    if (raw is Map) {
      final tags = raw['tags'];
      if (tags is Map) {
        addUrl(tags['image']);
        addUrl(tags['image:0']);
        addUrl(tags['image:1']);
        addUrl(tags['image:2']);
        addUrl(tags['photo']);
        addUrl(tags['logo']);
      }
    }

    final uniq = <String>{};
    final deduped = <String>[];
    for (final u in out) {
      if (uniq.add(u)) deduped.add(u);
    }
    return deduped;
  }

  List<String> _extractCategories(Map<String, dynamic> e) {
    final cats = <String>[];
    final c1 = e['categories'];
    final c2 = e['category_ids'];
    if (c1 is List) {
      cats.addAll(c1.map((v) => _str(v)).where((s) => s.isNotEmpty));
    }
    if (c2 is List) {
      cats.addAll(c2.map((v) => _str(v)).where((s) => s.isNotEmpty));
    }
    return cats.toSet().toList();
  }

  String? _openingHours(Map<String, dynamic> e) {
    final direct = _str(e['opening_hours']);
    if (direct.isNotEmpty) return direct;
    final raw = e['raw'];
    if (raw is Map) {
      final tags = raw['tags'];
      if (tags is Map) {
        final hours = _str(tags['opening_hours']);
        return hours.isEmpty ? null : hours;
      }
    }
    return null;
  }

  String? _website(Map<String, dynamic> e) {
    final candidates = [
      e['website'],
      e['url'],
      (e['raw'] is Map) ? (e['raw'] as Map)['website'] : null,
      (e['raw'] is Map && (e['raw'] as Map)['tags'] is Map)
          ? ((e['raw'] as Map)['tags'] as Map)['website']
          : null,
    ];
    for (final c in candidates) {
      final s = _str(c);
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  String? _phone(Map<String, dynamic> e) {
    final candidates = [
      e['phone'],
      e['contactPhone'],
      (e['raw'] is Map && (e['raw'] as Map)['tags'] is Map)
          ? ((e['raw'] as Map)['tags'] as Map)['phone']
          : null,
    ];
    for (final c in candidates) {
      final s = _str(c);
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  String? _address(Map<String, dynamic> e) {
    final candidates = [
      e['address'],
      e['formatted_address'],
      (e['raw'] is Map && (e['raw'] as Map)['tags'] is Map)
          ? ((e['raw'] as Map)['tags'] as Map)['addr:street']
          : null,
    ];
    for (final c in candidates) {
      final s = _str(c);
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  double? _lat(Map<String, dynamic> e) =>
      extractCoord(e, 'lat') ?? _toDouble(e['latitude']);
  double? _lon(Map<String, dynamic> e) =>
      extractCoord(e, 'lon') ?? _toDouble(e['longitude']);

  Widget _mapPreview(double lat, double lon) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(lat, lon),
        initialZoom: 15,
        interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.digitalnebi.allhabesha',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(lat, lon),
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 36,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openMaps(double lat, double lon, {String? name}) async {
    final label = Uri.encodeComponent(name ?? 'Destination');
    final apple = Uri.parse('https://maps.apple.com/?ll=$lat,$lon&q=$label');
    final google =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (!await launchUrl(apple, mode: LaunchMode.externalApplication)) {
      await launchUrl(google, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _share(Map<String, dynamic> e) async {
    final name = _str(e['name']);
    final addr = _address(e);
    final lat = _lat(e);
    final lon = _lon(e);
    final mapUrl =
        (lat != null && lon != null) ? 'https://maps.google.com/?q=$lat,$lon' : '';
    final parts = [
      if (name.isNotEmpty) name,
      if (addr != null && addr.isNotEmpty) addr,
      if (mapUrl.isNotEmpty) mapUrl,
    ];
    await Share.share(parts.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entity;
    final entityId = _str(e['id'] ?? e['place_id']);
    final name = _str(e['name']);
    final address = _address(e);
    final phone = _phone(e);
    final website = _website(e);
    final hours = _openingHours(e);
    final categories = _extractCategories(e);
    final distance = _toDouble(e['distanceKm']);
    final lat = _lat(e);
    final lon = _lon(e);
    final images = _extractImages(e);
    final qcState = ref.watch(qcEditStateProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            foregroundColor: Colors.white,
            expandedHeight: 280,
            actions: [
              IconButton(
                icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: _toggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _share(e),
              ),
              if (kQcMode && qcState.visible)
                IconButton(
                  icon: Icon(
                    qcState.editing ? Icons.edit_off : Icons.edit,
                  ),
                  onPressed: () {
                    ref.read(qcEditStateProvider.notifier).toggleEditing();
                  },
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: QcEditableText(
                name.isEmpty ? 'Details' : name,
                entityType: 'entity',
                entityId: entityId,
                fieldKey: 'name',
                onUpdated: (v) {
                  setState(() {
                    e['name'] = v;
                  });
                },
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 6,
                      color: Colors.black54,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  images.isNotEmpty
                      ? QcEditableImage(
                          entityType: 'entity',
                          entityId: entityId,
                          fieldKey: 'image',
                          imageUrl: images.first,
                          onUpdated: (v) {
                            setState(() {
                              e['image'] = v;
                            });
                          },
                          child: Image.network(
                            images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackHeader(),
                          ),
                        )
                      : _fallbackHeader(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x99000000),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address != null || phone != null || website != null)
                    _InfoCard(
                      title: 'Contact',
                      children: [
                        if (address != null)
                          _InfoRow(
                            icon: Icons.location_on,
                            text: address,
                            entityType: 'entity',
                            entityId: entityId,
                            fieldKey: 'address',
                            onUpdated: (v) {
                              setState(() {
                                e['address'] = v;
                              });
                            },
                          ),
                        if (phone != null)
                          _InfoRow(
                            icon: Icons.phone,
                            text: phone,
                            entityType: 'entity',
                            entityId: entityId,
                            fieldKey: 'phone',
                            onUpdated: (v) {
                              setState(() {
                                e['phone'] = v;
                              });
                            },
                            onTap: () => launchUrl(
                              Uri.parse('tel:${phone.trim()}'),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        if (website != null)
                          _InfoRow(
                            icon: Icons.public,
                            text: website,
                            entityType: 'entity',
                            entityId: entityId,
                            fieldKey: 'website',
                            onUpdated: (v) {
                              setState(() {
                                e['website'] = v;
                              });
                            },
                            onTap: () => launchUrl(
                              Uri.parse(website),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                      ],
                    ),
                  if (hours != null || categories.isNotEmpty || distance != null)
                    _InfoCard(
                      title: 'Details',
                      children: [
                        if (hours != null)
                          _InfoRow(
                            icon: Icons.schedule,
                            text: hours,
                            entityType: 'entity',
                            entityId: entityId,
                            fieldKey: 'opening_hours',
                            onUpdated: (v) {
                              setState(() {
                                e['opening_hours'] = v;
                              });
                            },
                          ),
                        if (distance != null)
                          _InfoRow(
                            icon: Icons.near_me,
                            text: '${distance.toStringAsFixed(2)} km away',
                          ),
                        if (categories.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: categories
                                .asMap()
                                .entries
                                .map(
                                  (entry) => Chip(
                                    label: QcEditableText(
                                      entry.value,
                                      entityType: 'entity',
                                      entityId: entityId,
                                      fieldKey: 'categories[${entry.key}]',
                                      onUpdated: (v) {
                                        setState(() {
                                          final list =
                                              (e['categories'] as List?)
                                                      ?.toList() ??
                                                  [];
                                          while (list.length <= entry.key) {
                                            list.add('');
                                          }
                                          list[entry.key] = v;
                                          e['categories'] = list;
                                        });
                                      },
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  if (lat != null && lon != null)
                    _InfoCard(
                      title: 'Map',
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 2,
                            child: _mapPreview(lat, lon),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openMaps(lat, lon, name: name),
                                icon: const Icon(Icons.directions),
                                label: const TrText('Directions'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final coord = '$lat,$lon';
                                  Clipboard.setData(ClipboardData(text: coord));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: TrText('Coordinates copied'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const TrText('Copy'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  if (images.length > 1)
                    _InfoCard(
                      title: 'Photos',
                      children: [
                        SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: min(images.length, 10),
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: QcEditableImage(
                                entityType: 'entity',
                                entityId: entityId,
                                fieldKey: 'images[$i]',
                                imageUrl: images[i],
                                onUpdated: (v) {
                                  setState(() {
                                    final list =
                                        (e['images'] as List?)?.toList() ?? [];
                                    while (list.length <= i) {
                                      list.add('');
                                    }
                                    list[i] = v;
                                    e['images'] = list;
                                  });
                                },
                                child: Image.network(
                                  images[i],
                                  width: 220,
                                  height: 160,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 220,
                                    height: 160,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.photo),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: phone == null
                              ? null
                              : () => launchUrl(
                                    Uri.parse('tel:${phone.trim()}'),
                                    mode: LaunchMode.externalApplication,
                                  ),
                          icon: const Icon(Icons.call),
                          label: const TrText('Call'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: website == null
                              ? null
                              : () => launchUrl(
                                    Uri.parse(website),
                                    mode: LaunchMode.externalApplication,
                                  ),
                          icon: const Icon(Icons.public),
                          label: const TrText('Website'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _share(e),
                    icon: const Icon(Icons.share),
                    label: const TrText('Share'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B1F3B), Color(0xFF3B3F68)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.storefront, size: 80, color: Colors.white70),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.onTap,
    this.entityType,
    this.entityId,
    this.fieldKey,
    this.onUpdated,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final String? entityType;
  final String? entityId;
  final String? fieldKey;
  final void Function(String value)? onUpdated;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: (entityType != null && entityId != null && fieldKey != null)
              ? QcEditableText(
                  text,
                  entityType: entityType!,
                  entityId: entityId!,
                  fieldKey: fieldKey!,
                  onUpdated: onUpdated,
                )
              : TrText(text),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: onTap == null
          ? row
          : InkWell(
              onTap: onTap,
              child: row,
            ),
    );
  }
}
