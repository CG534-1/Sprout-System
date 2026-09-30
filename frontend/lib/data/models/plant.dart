import 'dart:typed_data';

class Plant {
  const Plant({
    required this.id,
    required this.name,
    required this.species,
    required this.createdAt,
    this.photoUrl,
    this.photoBytes,
    this.location,
    this.notes,
  });

  final String id;
  final String name;
  final String species;
  final String? photoUrl;
  final Uint8List? photoBytes;
  final String? location;
  final String? notes;
  final DateTime createdAt;

  Plant copyWith({
    String? name,
    String? species,
    String? photoUrl,
    Uint8List? photoBytes,
    String? location,
    String? notes,
  }) {
    return Plant(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBytes: photoBytes ?? this.photoBytes,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'photoUrl': photoUrl,
      'location': location,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      photoUrl: json['photoUrl'] as String?,
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
