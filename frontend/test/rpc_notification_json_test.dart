import 'package:flutter_test/flutter_test.dart';
import 'package:sprout/gen/sprout/v1/notification.pb.dart';

void main() {
  test('a note left without read decodes as unread', () {
    // What the Node API sends for ListNotifications in JSON. Protobuf JSON
    // leaves out fields at their default, so the unread note has no `read`.
    const wire = {
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
    };

    final response = ListNotificationsResponse()..mergeFromProto3Json(wire);
    final [unread, read] = response.notifications;

    expect(unread.read, isFalse);
    expect(unread.hasRead(), isFalse);
    expect(read.read, isTrue);
    expect(
      unread.createTime.toDateTime(),
      DateTime.utc(2026, 10, 25, 9, 0, 0, 123),
    );
    expect(unread.title, 'Water Monstera');
  });
}
