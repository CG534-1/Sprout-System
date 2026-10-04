import assert from 'node:assert/strict';
import test from 'node:test';
import { dispatchReminders } from './dispatch.js';

function createAdmin({ settings = [], tokens = [], tasks = [], schedules = [] } = {}) {
  const store = {
    user_settings: settings.map((row) => ({ ...row })),
    device_tokens: tokens.map((row) => ({ ...row })),
    care_tasks: tasks.map((row) => ({ ...row })),
    care_schedules: schedules.map((row) => ({ ...row })),
    push_notifications: [],
  };
  return {
    store,
    from(table) {
      const filters = [];
      const builder = {
        select() {
          return builder;
        },
        eq(column, value) {
          filters.push([column, value]);
          return builder;
        },
        update(patch) {
          return {
            eq(column, value) {
              for (const row of store[table]) {
                if (row[column] === value) Object.assign(row, patch);
              }
              return Promise.resolve({ data: null, error: null });
            },
          };
        },
        insert(row) {
          const rows = Array.isArray(row) ? row : [row];
          store[table].push(...rows);
          return Promise.resolve({ data: rows, error: null });
        },
        delete() {
          return {
            in(column, values) {
              store[table] = store[table].filter((row) => !values.includes(row[column]));
              return Promise.resolve({ error: null });
            },
          };
        },
        then(resolve, reject) {
          let data = store[table];
          for (const [column, value] of filters) {
            data = data.filter((row) => row[column] === value);
          }
          return Promise.resolve({ data, error: null }).then(resolve, reject);
        },
      };
      return builder;
    },
  };
}

function senderOk() {
  return {
    sendEachForMulticast: async ({ tokens }) => ({
      successCount: tokens.length,
      responses: tokens.map(() => ({})),
    }),
  };
}

const setting = {
  user_id: 'user-1',
  utc_offset_minutes: 0,
  reminders: true,
  overdue: true,
  summary: false,
  tips: false,
  lead: '30 min before',
  preferred_slot: 'morning',
};

test('dispatch does nothing without a sender or device token', async () => {
  const admin = createAdmin({
    settings: [setting],
    tokens: [],
    tasks: [{ id: 't1', user_id: 'user-1', status: 'due', due_at: '2026-10-04T09:00:00.000Z', action: 'walk', subject_name: 'Milo' }],
  });
  assert.equal(await dispatchReminders(admin, new Date('2026-10-04T08:50:00.000Z'), senderOk()), 0);
  assert.equal(await dispatchReminders(admin, new Date('2026-10-04T08:50:00.000Z'), null), 0);
});

test('a due task in the lead window sends a reminder once', async () => {
  const admin = createAdmin({
    settings: [setting],
    tokens: [{ user_id: 'user-1', token: 'tok-1' }],
    tasks: [{
      id: 't1',
      user_id: 'user-1',
      status: 'due',
      due_at: '2026-10-04T09:00:00.000Z',
      action: 'walk',
      subject_name: 'Milo',
      reminded_at: null,
    }],
  });
  const now = new Date('2026-10-04T08:50:00.000Z');
  assert.equal(await dispatchReminders(admin, now, senderOk()), 1);
  assert.equal(admin.store.care_tasks[0].reminded_at, now.toISOString());
  assert.equal(admin.store.push_notifications.length, 1);
  assert.equal(admin.store.push_notifications[0].title, 'Care reminder');
  assert.equal(await dispatchReminders(admin, now, senderOk()), 0);
});

test('an open task past due sends an overdue notice', async () => {
  const admin = createAdmin({
    settings: [setting],
    tokens: [{ user_id: 'user-1', token: 'tok-1' }],
    tasks: [{
      id: 't1',
      user_id: 'user-1',
      status: 'due',
      due_at: '2026-10-04T09:00:00.000Z',
      action: 'walk',
      subject_name: 'Milo',
      overdue_sent_at: null,
    }],
  });
  const now = new Date('2026-10-04T15:24:00.000Z');
  assert.equal(await dispatchReminders(admin, now, senderOk()), 1);
  assert.equal(admin.store.care_tasks[0].overdue_sent_at, now.toISOString());
  assert.equal(admin.store.push_notifications[0].title, 'Overdue care');
});

test('daily summary sends at 8:45 local, not the care preference slot', async () => {
  const admin = createAdmin({
    settings: [{ ...setting, summary: true, overdue: false, preferred_slot: 'evening' }],
    tokens: [{ user_id: 'user-1', token: 'tok-1' }],
    tasks: [{
      id: 't1',
      user_id: 'user-1',
      status: 'due',
      due_at: '2026-10-04T13:00:00.000Z',
      action: 'walk',
      subject_name: 'Milo',
    }],
  });
  assert.equal(await dispatchReminders(admin, new Date('2026-10-04T08:00:00.000Z'), senderOk()), 0);
  assert.equal(await dispatchReminders(admin, new Date('2026-10-04T08:30:00.000Z'), senderOk()), 0);
  assert.equal(await dispatchReminders(admin, new Date('2026-10-04T08:45:00.000Z'), senderOk()), 1);
  assert.equal(admin.store.push_notifications[0].title, 'Today on Sprout');
  assert.equal(admin.store.user_settings[0].summary_sent_on, '2026-10-04');
  assert.equal(await dispatchReminders(admin, new Date('2026-10-04T18:00:00.000Z'), senderOk()), 0);
});

test('stale device tokens are dropped and do not count as sent', async () => {
  const admin = createAdmin({
    settings: [setting],
    tokens: [{ user_id: 'user-1', token: 'dead' }],
    tasks: [{
      id: 't1',
      user_id: 'user-1',
      status: 'due',
      due_at: '2026-10-04T09:00:00.000Z',
      action: 'walk',
      subject_name: 'Milo',
    }],
  });
  const sender = {
    sendEachForMulticast: async () => ({
      successCount: 0,
      responses: [{ error: { code: 'messaging/registration-token-not-registered' } }],
    }),
  };
  assert.equal(await dispatchReminders(admin, new Date('2026-10-04T08:50:00.000Z'), sender), 0);
  assert.equal(admin.store.device_tokens.length, 0);
  assert.equal(admin.store.push_notifications.length, 0);
});
