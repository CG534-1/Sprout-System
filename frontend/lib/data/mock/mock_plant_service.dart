import 'dart:typed_data';

import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/mock/mock_store.dart';
import 'package:sprout/data/models/plant.dart';
import 'package:sprout/data/services/plant_service.dart';

class MockPlantService extends PlantService {
  MockPlantService(this._store);

  final MockStore _store;

  @override
  Future<List<Plant>> listPlants() async {
    await _store.pause();
    final plants = List<Plant>.of(_store.plants)
      ..sort((a, b) => a.name.compareTo(b.name));
    return plants;
  }

  @override
  Future<Plant> getPlant(String id) async {
    await _store.pause();
    for (final plant in _store.plants) {
      if (plant.id == id) return plant;
    }
    throw const AppException('This plant could not be found.');
  }

  @override
  Future<Plant> createPlant({
    required String name,
    required String species,
    String? location,
    String? notes,
    Uint8List? photoBytes,
  }) async {
    await _store.pause();
    final trimmedName = name.trim();
    final trimmedSpecies = species.trim();
    if (trimmedName.isEmpty) {
      throw const AppException('Name is required.');
    }
    final plant = Plant(
      id: _store.nextId('plant'),
      name: trimmedName,
      species: trimmedSpecies,
      location: emptyToNull(location),
      notes: emptyToNull(notes),
      photoBytes: photoBytes,
      createdAt: DateTime.now(),
    );
    _store.plants.add(plant);
    notifyListeners();
    return plant;
  }

  @override
  Future<Plant> updatePlant(Plant plant) async {
    await _store.pause();
    final index = _store.plants.indexWhere((item) => item.id == plant.id);
    if (index == -1) {
      throw const AppException('This plant could not be found.');
    }
    _store.plants[index] = plant;
    notifyListeners();
    return plant;
  }

  @override
  Future<void> deletePlant(String id) async {
    await _store.pause();
    final removed = _store.plants.length;
    _store.plants.removeWhere((item) => item.id == id);
    if (_store.plants.length == removed) {
      throw const AppException('This plant could not be found.');
    }
    _store.removeSubject(id);
    notifyListeners();
  }
}
