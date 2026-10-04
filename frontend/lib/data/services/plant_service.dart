import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sprout/data/models/plant.dart';

abstract class PlantService extends ChangeNotifier {
  void dropCache() {}

  Future<List<Plant>> listPlants();

  Future<Plant> getPlant(String id);

  Future<Plant> createPlant({
    required String name,
    required String species,
    String? location,
    String? notes,
    Uint8List? photoBytes,
  });

  Future<Plant> updatePlant(Plant plant);

  Future<void> deletePlant(String id);
}
