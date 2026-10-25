import 'package:sprout/gen/sprout/v1/notification.pb.dart' as pb;

class PushNote {
  const PushNote({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// From the Connect `Notification` message. An unread note arrives without
  /// a `read` field, which the generated class reads back as false.
  factory PushNote.fromProto(pb.Notification note) {
    return PushNote(
      id: note.id,
      title: note.title,
      body: note.body,
      createdAt: note.createTime.toDateTime(),
      read: note.read,
    );
  }

  factory PushNote.fromJson(Map<String, dynamic> json) {
    return PushNote(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      read: json['read'] == true,
    );
  }
}
