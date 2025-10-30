class User {
  final String userID;
  final String name;
  final String age;
  final String gender;
  final String bio;
  final String imageUrl;
  final String latitude;
  final String longitude;
  final String city;
  final String state;

  User({
    required this.userID,
    required this.name,
    required this.age,
    required this.gender,
    required this.bio,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.state,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userID: (json['UserID'] ?? '').toString(),
      name: (json['Name'] ?? '').toString(),
      age: (json['Age'] ?? '').toString(),
      gender: (json['Gender'] ?? '').toString(),
      bio: (json['Bio'] ?? '').toString(),
      imageUrl: (json['ImageUrl'] ?? '').toString(),
      latitude: (json['Latitude'] ?? '').toString(),
      longitude: (json['Longitude'] ?? '').toString(),
      city: (json['City'] ?? '').toString(),
      state: (json['State'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toCreatePayload() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'bio': bio,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'state': state,
    };
  }
}
