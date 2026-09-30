import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sprout/data/models/pet.dart';

abstract class PetService extends ChangeNotifier {
  Future<List<Pet>> listPets();

  Future<Pet> getPet(String id);

  Future<Pet> createPet({
    required String name,
    required String species,
    String? notes,
    Uint8List? photoBytes,
  });

  Future<Pet> updatePet(Pet pet);

  Future<void> deletePet(String id);
}
