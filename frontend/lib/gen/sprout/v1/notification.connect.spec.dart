//
//  Generated code. Do not modify.
//  source: sprout/v1/notification.proto
//

import "package:connectrpc/connect.dart" as connect;
import "notification.pb.dart" as sproutv1notification;

/// The bell on Today: reminders, overdue alerts, and the daily summary that
/// were sent to this account.
abstract final class NotificationService {
  /// Fully-qualified name of the NotificationService service.
  static const name = 'sprout.v1.NotificationService';

  /// Lists the newest notifications for the signed-in account. Notes read
  /// before today (in the caller's time zone) are cleared first.
  static const listNotifications = connect.Spec(
    '/$name/ListNotifications',
    connect.StreamType.unary,
    sproutv1notification.ListNotificationsRequest.new,
    sproutv1notification.ListNotificationsResponse.new,
  );
}
