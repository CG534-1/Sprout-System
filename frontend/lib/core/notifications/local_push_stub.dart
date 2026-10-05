class LocalPush {
  Future<void> prepare() async {}

  Future<void> show({
    required int id,
    required String? title,
    required String? body,
  }) async {}
}

LocalPush createLocalPush() => LocalPush();
