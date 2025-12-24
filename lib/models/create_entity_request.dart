// lib/models/create_entity_request.dart

class CreateEntityRequest {
  CreateEntityRequest({
    required this.categoryId,
    required this.name,
    required this.address,
    required this.location,
    this.type,
    this.subtype,
    this.city,
    this.state,
    this.country,
    this.contactPhone,
    this.website,
    this.description,
    this.remote = false,
  });

  final String categoryId;
  final String name;
  final String address;

  /// {"lat": 38.9071923, "lon": -77.0368707}
  final Map<String, double> location;

  final String? type;
  final String? subtype;
  final String? city;
  final String? state;
  final String? country;
  final String? contactPhone;
  final String? website;
  final String? description;
  final bool remote;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      "categoryId": categoryId,
      "name": name,
      "type": type,
      "subtype": subtype,
      "address": address,
      "city": city,
      "state": state,
      "country": country,
      "location": location,
      "contactPhone": contactPhone,
      "website": website,
      "description": description,
      "remote": remote,
    };

    // remove nulls + empty strings (after trim)
    map.removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));

    return map;
  }
}
