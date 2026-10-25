import assert from 'node:assert/strict';
import test from 'node:test';
import { fromJson, toJson } from '@bufbuild/protobuf';
import { timestampDate } from '@bufbuild/protobuf/wkt';
import { Code, ConnectError, createClient, createRouterTransport } from '@connectrpc/connect';
import { requireSession, routes, sessionKey, toConnectError } from './connect.js';
import { httpError } from './auth.js';
import {
  ListNotificationsResponseSchema,
  NotificationService,
} from './gen/sprout/v1/notification_pb.js';
import { listNotes } from './notifications.js';

const rows = [
  {
    id: 'note-2',
    user_id: 'user-1',
    title: 'Water Monstera',
    body: 'Due at 9:00 AM',
    created_at: '2026-10-25T09:00:00.123456+00:00',
    read_at: null,
  },
  {
    id: 'note-1',
    user_id: 'user-1',
    title: 'Daily summary',
    body: '3 tasks today',
    created_at: '2026-10-24T04:45:00+00:00',
    read_at: '2026-10-24T08:00:00+00:00',
  },
];

// Just enough of the Supabase query builder for listNotes.
function createDb(data = rows) {
  const calls = [];
  return {
    calls,
    from(table) {
      const call = { table, steps: [] };
      calls.push(call);
      const builder = {
        then(resolve) {
          resolve({ data: call.steps[0][0] === 'select' ? data : null, error: null });
        },
      };
      for (const step of ['select', 'delete', 'eq', 'not', 'lt', 'order', 'limit']) {
        builder[step] = (...args) => {
          call.steps.push([step, ...args]);
          return builder;
        };
      }
      return builder;
    },
  };
}

function signedIn(db) {
  return (next) => (req) => {
    req.contextValues.set(sessionKey, { user: { id: 'user-1' }, db, offsetMinutes: 240 });
    return next(req);
  };
}

test('the REST shape is unchanged', async () => {
  const notes = await listNotes(createDb(), 'user-1', 240);
  assert.deepEqual(notes, [
    {
      id: 'note-2',
      title: 'Water Monstera',
      body: 'Due at 9:00 AM',
      createdAt: '2026-10-25T09:00:00.123456+00:00',
      read: false,
    },
    {
      id: 'note-1',
      title: 'Daily summary',
      body: '3 tasks today',
      createdAt: '2026-10-24T04:45:00+00:00',
      read: true,
    },
  ]);
});

test('ListNotifications returns the same notes as REST', async () => {
  const db = createDb();
  const transport = createRouterTransport(routes, { router: { interceptors: [signedIn(db)] } });
  const client = createClient(NotificationService, transport);

  const { notifications } = await client.listNotifications({});

  assert.deepEqual(
    notifications.map(({ id, title, body, read }) => ({ id, title, body, read })),
    [
      { id: 'note-2', title: 'Water Monstera', body: 'Due at 9:00 AM', read: false },
      { id: 'note-1', title: 'Daily summary', body: '3 tasks today', read: true },
    ],
  );
  assert.equal(timestampDate(notifications[0].createTime).toISOString(), '2026-10-25T09:00:00.123Z');
  assert.equal(timestampDate(notifications[1].createTime).toISOString(), '2026-10-24T04:45:00.000Z');

  // Same queries as REST: the purge is limited to this user, then the newest 50.
  const [purge, list] = db.calls;
  assert.deepEqual(purge.steps.slice(0, 3), [
    ['delete'],
    ['eq', 'user_id', 'user-1'],
    ['not', 'read_at', 'is', null],
  ]);
  assert.deepEqual(list.steps, [
    ['select', '*'],
    ['order', 'created_at', { ascending: false }],
    ['limit', 50],
  ]);
});

test('read: false is left out of the JSON and comes back as false', async () => {
  const transport = createRouterTransport(routes, {
    router: { interceptors: [signedIn(createDb())] },
  });
  const response = await createClient(NotificationService, transport).listNotifications({});

  const wire = toJson(ListNotificationsResponseSchema, response);
  assert.equal('read' in wire.notifications[0], false);
  assert.equal(wire.notifications[1].read, true);
  assert.equal(wire.notifications[0].createTime, '2026-10-25T09:00:00.123Z');

  const decoded = fromJson(ListNotificationsResponseSchema, wire);
  assert.equal(decoded.notifications[0].read, false);
  assert.equal(decoded.notifications[1].read, true);
});

test('no token is unauthenticated with the REST message', async () => {
  const saved = { url: process.env.SUPABASE_URL, anon: process.env.SUPABASE_ANON_KEY };
  process.env.SUPABASE_URL = 'https://example.supabase.co';
  process.env.SUPABASE_ANON_KEY = 'anon';
  try {
    const transport = createRouterTransport(routes, { router: { interceptors: [requireSession] } });
    await assert.rejects(
      createClient(NotificationService, transport).listNotifications({}),
      (error) => {
        assert.ok(error instanceof ConnectError);
        assert.equal(error.code, Code.Unauthenticated);
        assert.equal(error.rawMessage, 'Sign in to continue.');
        return true;
      },
    );
  } finally {
    process.env.SUPABASE_URL = saved.url ?? '';
    process.env.SUPABASE_ANON_KEY = saved.anon ?? '';
    if (saved.url === undefined) delete process.env.SUPABASE_URL;
    if (saved.anon === undefined) delete process.env.SUPABASE_ANON_KEY;
  }
});

test('REST error statuses map to Connect codes', () => {
  const cases = [
    [400, Code.InvalidArgument],
    [401, Code.Unauthenticated],
    [404, Code.NotFound],
    [409, Code.FailedPrecondition],
    [503, Code.Unavailable],
  ];
  // 500-level errors are logged, as the REST error handler does.
  const original = console.error;
  console.error = () => {};
  try {
    for (const [status, code] of cases) {
      const error = toConnectError(httpError(status, `status ${status}`));
      assert.equal(error.code, code, `status ${status}`);
      assert.equal(error.rawMessage, `status ${status}`);
    }
    assert.equal(toConnectError(new Error('db down')).code, Code.Internal);
  } finally {
    console.error = original;
  }
});
