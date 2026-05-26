class SavedLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime savedAt;

  const SavedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedLocation.fromJson(Map<String, dynamic> json) => SavedLocation(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        savedAt: DateTime.parse(json['savedAt'] as String),
      );
}
