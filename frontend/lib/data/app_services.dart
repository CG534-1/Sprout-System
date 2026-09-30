import 'package:sprout/data/api/api_auth_service.dart';
import 'package:sprout/data/api/api_care_service.dart';
import 'package:sprout/data/api/api_client.dart';
import 'package:sprout/data/api/api_pet_service.dart';
import 'package:sprout/data/api/api_plant_service.dart';
import 'package:sprout/data/api/api_profile_service.dart';
import 'package:sprout/data/mock/mock_auth_service.dart';
import 'package:sprout/data/mock/mock_care_service.dart';
import 'package:sprout/data/mock/mock_pet_service.dart';
import 'package:sprout/data/mock/mock_plant_service.dart';
import 'package:sprout/data/mock/mock_profile_service.dart';
import 'package:sprout/data/mock/mock_store.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/data/services/care_service.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/data/services/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppServices {
  AppServices({
    required this.auth,
    required this.plants,
    required this.pets,
    required this.care,
    required this.profile,
  });

  factory AppServices.mock({
    Duration delay = const Duration(milliseconds: 300),
  }) {
    final store = MockStore.seeded(delay: delay);
    final auth = MockAuthService(store);
    return AppServices(
      auth: auth,
      plants: MockPlantService(store),
      pets: MockPetService(store),
      care: MockCareService(store),
      profile: MockProfileService(store, auth),
    );
  }

  factory AppServices.remote({
    required SupabaseClient supabase,
    required String apiBase,
  }) {
    final client = ApiClient(
      baseUrl: apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase,
      token: () async => supabase.auth.currentSession?.accessToken,
    );
    final auth = ApiAuthService(supabase, client);
    return AppServices(
      auth: auth,
      plants: ApiPlantService(supabase, client),
      pets: ApiPetService(supabase, client),
      care: ApiCareService(client),
      profile: ApiProfileService(client),
    );
  }

  final AuthService auth;
  final PlantService plants;
  final PetService pets;
  final CareService care;
  final ProfileService profile;

  void dispose() {
    auth.dispose();
    plants.dispose();
    pets.dispose();
    care.dispose();
    profile.dispose();
  }
}
