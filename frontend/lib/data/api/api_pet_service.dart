import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/api/api_client.dart';
import 'package:sprout/data/models/pet.dart';
import 'package:sprout/data/services/pet_service.dart';

class ApiPetService extends PetService {
  ApiPetService(this._supabase, this._client);

  final SupabaseClient _supabase;
  final ApiClient _client;

  @override
  Future<List<Pet>> listPets() async {
    final data = await _client.send('GET', '/api/pets');
    return (data as List)
        .map((item) => Pet.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
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
        'notes': notes,
        'photoPath': photoPath,
      },
    );
    notifyListeners();
    return Pet.fromJson(Map<String, dynamic>.from(data as Map));
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
        'notes': pet.notes,
        if (photoPath != null) 'photoPath': photoPath,
      },
    );
    notifyListeners();
    return Pet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> deletePet(String id) async {
    await _client.send('DELETE', '/api/pets/$id');
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
