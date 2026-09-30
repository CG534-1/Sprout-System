import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/api/api_client.dart';
import 'package:sprout/data/models/plant.dart';
import 'package:sprout/data/services/plant_service.dart';

class ApiPlantService extends PlantService {
  ApiPlantService(this._supabase, this._client);

  final SupabaseClient _supabase;
  final ApiClient _client;

  @override
  Future<List<Plant>> listPlants() async {
    final data = await _client.send('GET', '/api/plants');
    return _list(data);
  }

  @override
  Future<Plant> getPlant(String id) async {
    final data = await _client.send('GET', '/api/plants/$id');
    return Plant.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<Plant> createPlant({
    required String name,
    required String species,
    String? location,
    String? notes,
    Uint8List? photoBytes,
  }) async {
    final photoPath = await _upload(photoBytes, 'plant');
    final data = await _client.send(
      'POST',
      '/api/plants',
      body: {
        'name': name,
        'species': species,
        'location': location,
        'notes': notes,
        'photoPath': photoPath,
      },
    );
    notifyListeners();
    return Plant.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<Plant> updatePlant(Plant plant) async {
    final photoPath = await _upload(plant.photoBytes, 'plant');
    final data = await _client.send(
      'PATCH',
      '/api/plants/${plant.id}',
      body: {
        'name': plant.name,
        'species': plant.species,
        'location': plant.location,
        'notes': plant.notes,
        if (photoPath != null) 'photoPath': photoPath,
      },
    );
    notifyListeners();
    return Plant.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> deletePlant(String id) async {
    await _client.send('DELETE', '/api/plants/$id');
    notifyListeners();
  }

  Future<String?> _upload(Uint8List? bytes, String kind) async {
    if (bytes == null) return null;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const AppException('Sign in to continue.');
    final path = '$userId/$kind-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _supabase.storage.from('care-media').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    return path;
  }

  List<Plant> _list(dynamic data) {
    return (data as List)
        .map((item) => Plant.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
