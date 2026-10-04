import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/api/api_client.dart';
import 'package:sprout/data/models/pet.dart';
import 'package:sprout/data/services/pet_service.dart';

class ApiPetService extends PetService {
  ApiPetService(this._supabase, this._client, {this.onSubjectsChanged});

  final SupabaseClient _supabase;
  final ApiClient _client;
  final VoidCallback? onSubjectsChanged;
  List<Pet>? _pets;

  @override
  void dropCache() {
    _pets = null;
    notifyListeners();
  }

  @override
  Future<List<Pet>> listPets() async {
    if (_pets != null) return _pets!;
    final data = await _client.send('GET', '/api/pets');
    _pets = (data as List)
        .map((item) => Pet.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return _pets!;
  }

  @override
  Future<Pet> getPet(String id) async {
    final data = await _client.send('GET', '/api/pets/$id');
    return Pet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<Pet> createPet({
    required String name,
    required String species,
    String breed = '',
    String? notes,
    Uint8List? photoBytes,
  }) async {
    final photoPath = await _upload(photoBytes);
    final data = await _client.send(
      'POST',
      '/api/pets',
      body: {
        'name': name,
        'species': species,
        'breed': breed,
        'notes': notes,
        'photoPath': photoPath,
      },
    );
    _pets = null;
    notifyListeners();
    final created = Pet.fromJson(Map<String, dynamic>.from(data as Map));
    return created.copyWith(photoBytes: photoBytes, photoUrl: created.photoUrl);
  }

  @override
  Future<Pet> updatePet(Pet pet) async {
    final photoPath = await _upload(pet.photoBytes);
    final data = await _client.send(
      'PATCH',
      '/api/pets/${pet.id}',
      body: {
        'name': pet.name,
        'species': pet.species,
        'breed': pet.breed,
        'notes': pet.notes,
        if (photoPath != null) 'photoPath': photoPath,
      },
    );
    _pets = null;
    notifyListeners();
    final updated = Pet.fromJson(Map<String, dynamic>.from(data as Map));
    return updated.copyWith(photoBytes: pet.photoBytes, photoUrl: updated.photoUrl);
  }

  @override
  Future<void> deletePet(String id) async {
    await _client.send('DELETE', '/api/pets/$id');
    _pets = null;
    onSubjectsChanged?.call();
    notifyListeners();
  }

  Future<String?> _upload(Uint8List? bytes) async {
    if (bytes == null) return null;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const AppException('Sign in to continue.');
    final path = '$userId/pet-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _supabase.storage.from('care-media').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    return path;
  }
}
