import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/data/app_services.dart';
import 'package:sprout/data/models/care_settings.dart';
import 'package:sprout/data/models/pet.dart';
import 'package:sprout/data/models/plant.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/data/services/care_service.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/data/services/profile_service.dart';

/// The live or mock services, supplied by [SproutApp] as an override.
final appServicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('SproutApp overrides appServicesProvider.'),
);

// Plain handles for calling a service. Reading one of these does not rebuild
// on service changes; watch a data provider below for that.
final authServiceProvider = Provider<AuthService>(
  (ref) => ref.watch(appServicesProvider).auth,
);

final plantServiceProvider = Provider<PlantService>(
  (ref) => ref.watch(appServicesProvider).plants,
);

final petServiceProvider = Provider<PetService>(
  (ref) => ref.watch(appServicesProvider).pets,
);

final careServiceProvider = Provider<CareService>(
  (ref) => ref.watch(appServicesProvider).care,
);

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ref.watch(appServicesProvider).profile,
);

extension LoadFailed on AsyncValue<Object?> {
  /// The last load failed and there is nothing older to show instead.
  bool get failedEmpty => !hasValue && hasError && !isLoading;
}

/// Rebuilds the calling provider whenever [service] notifies.
///
/// The services keep their own caches and notify when those change, so a
/// rebuild reads the fresh result without another round trip.
T watchService<T extends Listenable>(Ref ref, T service) {
  void changed() => ref.invalidateSelf();
  service.addListener(changed);
  ref.onDispose(() => service.removeListener(changed));
  return service;
}

final currentUserProvider = Provider<UserProfile?>((ref) {
  return watchService(ref, ref.watch(authServiceProvider)).currentUser;
});

/// True while a confirmed email is still waiting for its password.
final pendingSignupProvider = Provider<bool>((ref) {
  return watchService(ref, ref.watch(authServiceProvider)).pendingSignup;
});

/// Everyone in the home, shared by Today, My care, History, and Profile.
class Home {
  const Home({required this.plants, required this.pets});

  final List<Plant> plants;
  final List<Pet> pets;

  bool get isEmpty => plants.isEmpty && pets.isEmpty;

  Set<String> get ids => {
    for (final plant in plants) plant.id,
    for (final pet in pets) pet.id,
  };

  Map<String, String> get photosById => {
    for (final plant in plants)
      if (plant.photoUrl != null) plant.id: plant.photoUrl!,
    for (final pet in pets)
      if (pet.photoUrl != null) pet.id: pet.photoUrl!,
  };

  Map<String, String> get photosByName => {
    for (final plant in plants)
      if (plant.photoUrl != null) plant.name: plant.photoUrl!,
    for (final pet in pets)
      if (pet.photoUrl != null) pet.name: pet.photoUrl!,
  };
}

final homeProvider = FutureProvider.autoDispose<Home>((ref) async {
  final plants = watchService(ref, ref.watch(plantServiceProvider));
  final pets = watchService(ref, ref.watch(petServiceProvider));
  final loaded = await (plants.listPlants(), pets.listPets()).wait;
  return Home(plants: loaded.$1, pets: loaded.$2);
});

/// The account's care settings, edited on Profile and used as defaults for
/// new care plans.
final careSettingsProvider =
    AsyncNotifierProvider.autoDispose<CareSettingsNotifier, CareSettings>(
      CareSettingsNotifier.new,
    );

class CareSettingsNotifier extends AsyncNotifier<CareSettings> {
  @override
  Future<CareSettings> build() => ref.watch(profileServiceProvider).settings();

  /// The settings as shown, which are the defaults until the saved ones load.
  CareSettings get current => state.value ?? CareSettings.defaults;

  /// Shows [next] at once, then saves it.
  Future<void> save(CareSettings next) async {
    state = AsyncData(next);
    await ref.read(profileServiceProvider).updateSettings(next);
  }
}
