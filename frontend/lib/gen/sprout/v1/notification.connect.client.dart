//
//  Generated code. Do not modify.
//  source: sprout/v1/notification.proto
//

import "package:connectrpc/connect.dart" as connect;
import "notification.pb.dart" as sproutv1notification;
import "notification.connect.spec.dart" as specs;

/// The bell on Today: reminders, overdue alerts, and the daily summary that
/// were sent to this account.
extension type NotificationServiceClient (connect.Transport _transport) {
  /// Lists the newest notifications for the signed-in account. Notes read
  /// before today (in the caller's time zone) are cleared first.
  Future<sproutv1notification.ListNotificationsResponse> listNotifications(
    sproutv1notification.ListNotificationsRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.NotificationService.listNotifications,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }
}
