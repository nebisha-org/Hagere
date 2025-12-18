class EthEntity {
  final String id;
  final String name;
  final String type;
  final String subtype;
  final String address;
  final String city;
  final String state;
  final String country;
  final String website;
  final String contactPhone;
  final double lat;
  final double lon;
  final List<String> tags;
  final List<String> images;

  EthEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.subtype,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.website,
    required this.contactPhone,
    required this.lat,
    required this.lon,
    required this.tags,
    required this.images,
  });

  factory EthEntity.fromJson(Map<String, dynamic> j) {
    final loc = (j['location'] as Map<String, dynamic>?) ?? const {};
    return EthEntity(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      type: (j['type'] ?? '').toString(),
      subtype: (j['subtype'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      city: (j['city'] ?? '').toString(),
      state: (j['state'] ?? '').toString(),
      country: (j['country'] ?? '').toString(),
      website: (j['website'] ?? '').toString(),
      contactPhone: (j['contactPhone'] ?? '').toString(),
      lat: (loc['lat'] is num) ? (loc['lat'] as num).toDouble() : 0.0,
      lon: (loc['lon'] is num) ? (loc['lon'] as num).toDouble() : 0.0,
      tags: (j['tags'] is List) ? List<String>.from(j['tags']) : const [],
      images: (j['images'] is List) ? List<String>.from(j['images']) : const [],
    );
  }
}
