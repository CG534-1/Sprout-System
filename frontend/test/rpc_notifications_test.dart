import 'dart:convert';
import 'dart:typed_data';

import 'package:connectrpc/connect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout/data/api/api_client.dart';
import 'package:sprout/data/api/api_profile_service.dart';
import 'package:sprout/data/rpc/rpc_transport.dart';
import 'package:sprout/gen/sprout/v1/notification.connect.client.dart';

/// Stands in for the Node API: records the request and replies with [body].
HttpClient fakeApi(int status, String body, List<HttpRequest> seen) {
  return (request) async {
    seen.add(request);
    return HttpResponse(
      status,
      Headers()..['content-type'] = 'application/json',
      Stream.value(Uint8List.fromList(utf8.encode(body))),
      Headers(),
    );
  };
}

ApiProfileService profileWith(HttpClient api) {
  Future<String?> token() async => 'test-token';
  final rpc = createRpcTransport(
    baseUrl: 'https://api.test',
    token: token,
    httpClient: api,
  );
  return ApiProfileService(
    ApiClient(baseUrl: 'https://api.test', token: token),
    NotificationServiceClient(rpc),
  );
}

void main() {
  test('the bell asks Connect the way REST did and keeps unread notes unread', () async {
    final seen = <HttpRequest>[];
    // The JSON the Node API sends for ListNotifications.
    final profile = profileWith(fakeApi(200, jsonEncode({
      'notifications': [
        {
          'id': 'note-2',
          'title': 'Water Monstera',
          'body': 'Due at 9:00 AM',
          'createTime': '2026-10-25T09:00:00.123Z',
        },
        {
          'id': 'note-1',
          'title': 'Daily summary',
          'body': '3 tasks today',
          'createTime': '2026-10-24T04:45:00Z',
          'read': true,
        },
      ],
    }), seen));

    final notes = await profile.notifications();

    expect(notes.map((note) => note.id), ['note-2', 'note-1']);
    expect(notes.map((note) => note.read), [false, true]);
    expect(notes.first.title, 'Water Monstera');
    expect(notes.first.body, 'Due at 9:00 AM');
    expect(notes.first.createdAt, DateTime.utc(2026, 10, 25, 9, 0, 0, 123));

    final request = seen.single;
    expect(request.method, 'POST');
    expect(request.url, 'https://api.test/sprout.v1.NotificationService/ListNotifications');
    expect(request.header['authorization'], 'Bearer test-token');
    expect(request.header['x-utc-offset-minutes'], isNotNull);
    expect(request.header['content-type'], 'application/json');
    expect(request.header['connect-protocol-version'], '1');
    final body = await request.body!.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    expect(utf8.decode(body), '{}');
  });

  test('no notes at all comes back as an empty bell', () async {
    final profile = profileWith(fakeApi(200, '{}', []));
    expect(await profile.notifications(), isEmpty);
  });

  test('a signed out or failed call still shows an empty bell', () async {
    final signedOut = profileWith(fakeApi(
      401,
      jsonEncode({'code': 'unauthenticated', 'message': 'Sign in to continue.'}),
      [],
    ));
    expect(await signedOut.notifications(), isEmpty);

    Future<HttpResponse> offline(HttpRequest request) async {
      throw Exception('No connection');
    }

    expect(await profileWith(offline).notifications(), isEmpty);
  });
}
