import { timestampFromDate } from '@bufbuild/protobuf/wkt';
import { Code, ConnectError, createContextKey } from '@connectrpc/connect';
import { authenticate } from './auth.js';
import { offsetFromHeader } from './care.js';
import { NotificationService } from './gen/sprout/v1/notification_pb.js';
import { listNotes } from './notifications.js';

/** The signed-in account for one call, set by `requireSession`. */
export const sessionKey = createContextKey(null, { description: 'Sprout session' });

const codes = {
  400: Code.InvalidArgument,
  401: Code.Unauthenticated,
  404: Code.NotFound,
  409: Code.FailedPrecondition,
  503: Code.Unavailable,
};

/** Gives an `httpError` the matching Connect code and the same message REST sends. */
export function toConnectError(error) {
  if (error instanceof ConnectError) return error;
  const status = error?.status || 500;
  // The REST error handler logs these too.
  if (status >= 500) console.error(error);
  return new ConnectError(error?.message || 'Something went wrong.', codes[status] ?? Code.Internal);
}

/**
 * Signs the caller in the same way the /api REST middleware does, before any
 * handler runs, and turns any failure into a Connect error.
 */
export const requireSession = (next) => async (req) => {
  try {
    const offsetMinutes = offsetFromHeader(req.header.get('x-utc-offset-minutes'));
    const session = await authenticate({
      authorization: req.header.get('authorization'),
      offsetMinutes,
    });
    req.contextValues.set(sessionKey, { ...session, offsetMinutes });
    return await next(req);
  } catch (error) {
    throw toConnectError(error);
  }
};

export function routes(router) {
  router.service(NotificationService, {
    async listNotifications(_request, context) {
      const { user, db, offsetMinutes } = context.values.get(sessionKey);
      const notes = await listNotes(db, user.id, offsetMinutes);
      return {
        notifications: notes.map((note) => ({
          id: note.id,
          title: note.title,
          body: note.body,
          createTime: timestampFromDate(new Date(note.createdAt)),
          read: note.read,
        })),
      };
    },
  });
}
