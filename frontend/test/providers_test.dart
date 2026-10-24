import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/app_services.dart';
import 'package:sprout/data/mock/mock_auth_service.dart';
import 'package:sprout/data/mock/mock_care_service.dart';
import 'package:sprout/data/mock/mock_pet_service.dart';
import 'package:sprout/data/mock/mock_plant_service.dart';
import 'package:sprout/data/mock/mock_profile_service.dart';
import 'package:sprout/data/mock/mock_store.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_task.dart';
import 'package:sprout/data/providers.dart';
import 'package:sprout/features/today/today_providers.dart';

/// A care service whose saves never reach the server.
class _OfflineCare extends MockCareService {
  _OfflineCare(super.store);

  @override
  Future<void> completeTask(String taskId) async {
    throw const AppException('That did not save.');
  }
}

MockStore _storeWithTaskAtNoon() {
  final store = MockStore.seeded(delay: Duration.zero);
  final now = DateTime.now();
  store.tasks
    ..clear()
    ..add(
      CareTask(
        id: 'task-water-monstera',
        scheduleId: 'schedule-water-monstera',
        subjectId: 'plant-monstera',
        subjectType: CareSubjectType.plant,
        subjectName: 'Monstera',
        action: CareAction.water,
        // Noon keeps the task on today whatever time the suite runs.
        dueAt: DateTime(now.year, now.month, now.day, 12),
        status: TaskStatus.due,
      ),
    );
  return store;
}

ProviderContainer _container(AppServices services) {
  final container = ProviderContainer(
    overrides: [appServicesProvider.overrideWithValue(services)],
    retry: (retryCount, error) => null,
  );
  // Teardown runs last in first out, so the providers let go of the services
  // before the services are disposed.
  addTearDown(services.dispose);
  addTearDown(container.dispose);
  return container;
}

AppServices _services(MockStore store, {MockCareService? care}) {
  final auth = MockAuthService(store);
  return AppServices(
    auth: auth,
    plants: MockPlantService(store),
    pets: MockPetService(store),
    care: care ?? MockCareService(store),
    profile: MockProfileService(store, auth),
  );
}

TaskStatus _statusOf(ProviderContainer container, String taskId) {
  final today = container.read(todayCareProvider).value!.today;
  return today.firstWhere((task) => task.id == taskId).status;
}

void main() {
  test('the current user follows sign in and sign out', () async {
    final services = _services(MockStore.seeded(delay: Duration.zero));
    final container = _container(services);
    container.listen(currentUserProvider, (previous, next) {});

    expect(container.read(currentUserProvider), isNull);

    await services.auth.signIn(email: 'ama@sprout.app', password: 'secret1');
    expect(container.read(currentUserProvider)?.email, 'ama@sprout.app');

    await services.auth.signOut();
    expect(container.read(currentUserProvider), isNull);
  });

  test('home reloads after someone leaves it', () async {
    final services = _services(MockStore.seeded(delay: Duration.zero));
    final container = _container(services);
    container.listen(homeProvider, (previous, next) {});

    final before = await container.read(homeProvider.future);
    expect(before.plants.map((plant) => plant.id), contains('plant-aloe'));
    expect(before.pets, isNotEmpty);

    await services.plants.deletePlant('plant-aloe');

    final after = await container.read(homeProvider.future);
    expect(after.plants.map((plant) => plant.id), isNot(contains('plant-aloe')));
    expect(after.pets.length, before.pets.length);
  });

  test('marking a task done shows at once and is saved', () async {
    final store = _storeWithTaskAtNoon();
    final services = _services(store);
    final container = _container(services);
    container.listen(todayCareProvider, (previous, next) {});

    final care = await container.read(todayCareProvider.future);
    final task = care.today.single;
    expect(care.hasHome, isTrue);

    final saving = container.read(todayCareProvider.notifier).toggle(task);
    expect(_statusOf(container, task.id), TaskStatus.done);

    await saving;
    await container.read(todayCareProvider.future);
    expect(_statusOf(container, task.id), TaskStatus.done);
    expect(store.tasks.single.status, TaskStatus.done);
    expect(store.history.map((entry) => entry.subjectName), contains('Monstera'));
  });

  test('a failed save puts the task back and reports the error', () async {
    final store = _storeWithTaskAtNoon();
    final services = _services(store, care: _OfflineCare(store));
    final container = _container(services);
    container.listen(todayCareProvider, (previous, next) {});

    final task = (await container.read(todayCareProvider.future)).today.single;

    await expectLater(
      container.read(todayCareProvider.notifier).toggle(task),
      throwsA(isA<AppException>()),
    );

    await container.read(todayCareProvider.future);
    expect(_statusOf(container, task.id), TaskStatus.due);
  });

  test('care settings show a change at once and save it', () async {
    final services = _services(MockStore.seeded(delay: Duration.zero));
    final container = _container(services);
    container.listen(careSettingsProvider, (previous, next) {});

    final settings = await container.read(careSettingsProvider.future);
    expect(settings.tips, isFalse);

    final notifier = container.read(careSettingsProvider.notifier);
    final saving = notifier.save(settings.copyWith(tips: true, lead: '1 hour before'));
    expect(container.read(careSettingsProvider).value?.tips, isTrue);

    await saving;
    final stored = await services.profile.settings();
    expect(stored.tips, isTrue);
    expect(stored.lead, '1 hour before');
  });
}
