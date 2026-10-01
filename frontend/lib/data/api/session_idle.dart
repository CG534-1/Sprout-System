/// A half-finished sign up or password reset is dropped this soon after the
/// last activity, so coming back later starts the flow over.
const setupIdleLimit = Duration(minutes: 30);

/// A finished account keeps its session for this long between visits.
const sessionIdleLimit = Duration(days: 7);

/// Whether a stored session has sat untouched for too long.
///
/// A visitor part way through sign up or a password reset gets the short
/// limit, so returning hours later starts over at the splash instead of
/// dropping them back into a stale setup screen.
bool idledOut({
  required int? lastActive,
  required bool signedIn,
  required bool midSetup,
  DateTime? now,
}) {
  if (lastActive == null) return false;
  if (!signedIn && !midSetup) return false;
  final since = (now ?? DateTime.now()).difference(
    DateTime.fromMillisecondsSinceEpoch(lastActive),
  );
  return since > (midSetup ? setupIdleLimit : sessionIdleLimit);
}
