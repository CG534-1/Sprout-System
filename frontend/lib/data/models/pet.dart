import 'dart:typed_data';

class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    required this.createdAt,
    this.breed = '',
    this.photoUrl,
    this.photoBytes,
    this.notes,
  });

  final String id;
  final String name;
  final String species;
  final String breed;
  final String? photoUrl;
  final Uint8List? photoBytes;
  final String? notes;
  final DateTime createdAt;

  Pet copyWith({
    String? name,
    String? species,
    String? breed,
    String? photoUrl,
    Uint8List? photoBytes,
    String? notes,
  }) {
    return Pet(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBytes: photoBytes ?? this.photoBytes,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'photoUrl': photoUrl,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      name: json['name'] as String,
      species: json['species'] as String? ?? '',
      breed: json['breed'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
