import 'dart:typed_data';

import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/mock/mock_store.dart';
import 'package:sprout/data/models/pet.dart';
import 'package:sprout/data/services/pet_service.dart';

class MockPetService extends PetService {
  MockPetService(this._store);

  final MockStore _store;

  @override
  Future<List<Pet>> listPets() async {
    await _store.pause();
    final pets = List<Pet>.of(_store.pets)
      ..sort((a, b) => a.name.compareTo(b.name));
    return pets;
  }

  @override
  Future<Pet> getPet(String id) async {
    await _store.pause();
    for (final pet in _store.pets) {
      if (pet.id == id) return pet;
    }
    throw const AppException('This pet could not be found.');
  }

  @override
  Future<Pet> createPet({
    required String name,
    required String species,
    String? notes,
    Uint8List? photoBytes,
  }) async {
    await _store.pause();
    final trimmedName = name.trim();
    final trimmedSpecies = species.trim();
    if (trimmedName.isEmpty) {
      throw const AppException('Name is required.');
    }
    final pet = Pet(
      id: _store.nextId('pet'),
      name: trimmedName,
      species: trimmedSpecies,
      notes: emptyToNull(notes),
      photoBytes: photoBytes,
      createdAt: DateTime.now(),
    );
    _store.pets.add(pet);
    notifyListeners();
    return pet;
  }

  @override
  Future<Pet> updatePet(Pet pet) async {
    await _store.pause();
    final index = _store.pets.indexWhere((item) => item.id == pet.id);
    if (index == -1) {
      throw const AppException('This pet could not be found.');
    }
    _store.pets[index] = pet;
    notifyListeners();
    return pet;
  }

  @override
  Future<void> deletePet(String id) async {
    await _store.pause();
    final removed = _store.pets.length;
    _store.pets.removeWhere((item) => item.id == id);
    if (_store.pets.length == removed) {
      throw const AppException('This pet could not be found.');
    }
    _store.removeSubject(id);
    notifyListeners();
  }
}
