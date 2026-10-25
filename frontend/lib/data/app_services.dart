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
import 'package:sprout/data/rpc/rpc_transport.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/data/services/care_service.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/data/services/profile_service.dart';
import 'package:sprout/gen/sprout/v1/notification.connect.client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppServices {
  AppServices({
    required this.auth,
    required this.plants,
    required this.pets,
    required this.care,
    required this.profile,
  }) {
    _homeUserId = auth.currentUser?.id;
    auth.addListener(_syncHomeCache);
  }

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
    final base = apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase;
    Future<String?> token() async => supabase.auth.currentSession?.accessToken;
    final client = ApiClient(baseUrl: base, token: token);
    final rpc = createRpcTransport(baseUrl: base, token: token);
    final auth = ApiAuthService(supabase, client);
    final care = ApiCareService(client);
    return AppServices(
      auth: auth,
      plants: ApiPlantService(supabase, client, onSubjectsChanged: care.dropCache),
      pets: ApiPetService(supabase, client, onSubjectsChanged: care.dropCache),
      care: care,
      profile: ApiProfileService(client, NotificationServiceClient(rpc)),
    );
  }

  final AuthService auth;
  final PlantService plants;
  final PetService pets;
  final CareService care;
  final ProfileService profile;
  String? _homeUserId;

  void _syncHomeCache() {
    final id = auth.currentUser?.id;
    if (id == _homeUserId) return;
    _homeUserId = id;
    plants.dropCache();
    pets.dropCache();
    care.dropCache();
  }

  void dispose() {
    auth.removeListener(_syncHomeCache);
    auth.dispose();
    plants.dispose();
    pets.dispose();
    care.dispose();
    profile.dispose();
  }
}
