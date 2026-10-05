import assert from 'node:assert/strict';
import test from 'node:test';
import {
  isSummaryTime,
  localDayKey,
  mergeSlotHours,
  nextDue,
  preferredHour,
  duesOnCycle,
  upcomingOnNextDay,
} from './care.js';

test('next care later today stays on today', () => {
  const now = new Date('2026-09-30T07:00:00.000Z');
  const due = nextDue(
    { frequency: 'daily', reminders: ['morning'], weekdays: [] },
    0,
    now,
  );
  assert.equal(due, '2026-09-30T09:00:00.000Z');
});

test('a missed morning slot moves to the next interval', () => {
  const now = new Date('2026-09-30T10:00:00.000Z');
  const due = nextDue(
    {
      frequency: 'daily',
      reminders: ['morning'],
      weekdays: [],
      lastDone: '2026-09-30T09:00:00.000Z',
    },
    0,
    now,
  );
  assert.equal(due, '2026-10-01T09:00:00.000Z');
});

test('a late-night custom clock lands tonight, not this morning', () => {
  const now = new Date('2026-10-04T23:56:00.000Z');
  const due = nextDue(
    {
      frequency: 'daily',
      reminders: ['evening'],
      weekdays: [],
      slotHours: { evening: { hour: 0, minute: 8 } },
    },
    0,
    now,
  );
  assert.equal(due, '2026-10-05T00:08:00.000Z');
});

test('a new plan still starts today after the reminder hour', () => {
  const now = new Date('2026-09-30T22:00:00.000Z');
  const due = nextDue(
    { frequency: 'daily', reminders: ['morning'], weekdays: [] },
    0,
    now,
  );
  assert.equal(due, '2026-09-30T09:00:00.000Z');
});

test('last watered today still keeps a later slot today', () => {
  const now = new Date('2026-10-05T15:00:00.000Z');
  const times = duesOnCycle(
    {
      frequency: 'daily',
      reminders: ['morning', 'evening'],
      weekdays: [],
      lastDone: '2026-10-05T09:00:00.000Z',
    },
    0,
    now,
  );
  assert.deepEqual(times, ['2026-10-05T18:00:00.000Z']);
});

test('last care counts forward, then the next slot if that time has passed', () => {
  const now = new Date('2026-09-30T12:00:00.000Z');
  const due = nextDue(
    {
      frequency: 'everyTwoDays',
      reminders: ['morning'],
      weekdays: [],
      lastDone: '2026-09-29T09:00:00.000Z',
    },
    0,
    now,
  );
  assert.equal(due, '2026-10-01T09:00:00.000Z');
});

test('set days uses the next selected weekday', () => {
  const now = new Date('2026-09-30T10:00:00.000Z');
  const due = nextDue(
    { frequency: 'setDays', reminders: ['evening'], weekdays: [5] },
    0,
    now,
  );
  assert.equal(due, '2026-10-02T18:00:00.000Z');
});

test('preferred care hours stay on the plant and pet slots', () => {
  assert.equal(preferredHour('morning'), 9);
  assert.equal(preferredHour('afternoon'), 13);
  assert.equal(preferredHour('evening'), 18);
});

test('daily summary is 8:45 local, not a care slot', () => {
  assert.equal(isSummaryTime({ hour: 8, minute: 44 }), false);
  assert.equal(isSummaryTime({ hour: 8, minute: 45 }), true);
  assert.equal(isSummaryTime({ hour: 9, minute: 0 }), true);
  assert.equal(isSummaryTime({ hour: 9, minute: 14 }), true);
  assert.equal(isSummaryTime({ hour: 9, minute: 15 }), false);
});

test('each selected reminder becomes its own task on that day', () => {
  const now = new Date('2026-10-01T08:00:00.000Z');
  const times = duesOnCycle(
    { frequency: 'daily', reminders: ['morning', 'afternoon', 'evening'], weekdays: [] },
    0,
    now,
  );
  assert.deepEqual(times, [
    '2026-10-01T09:00:00.000Z',
    '2026-10-01T13:00:00.000Z',
    '2026-10-01T18:00:00.000Z',
  ]);
});

test('local day follows the phone offset', () => {
  const key = localDayKey('2026-09-30T23:30:00.000Z', 120);
  assert.equal(key, '2026-10-01');
});

test('coming up keeps every due task on the next occupied day', () => {
  const rows = [
    { status: 'due', due_at: '2026-10-03T09:00:00.000Z', action: 'water' },
    { status: 'due', due_at: '2026-10-02T18:00:00.000Z', action: 'feed' },
    { status: 'due', due_at: '2026-10-02T09:00:00.000Z', action: 'walk' },
    { status: 'done', due_at: '2026-10-02T13:00:00.000Z', action: 'mist' },
    { status: 'due', due_at: '2026-10-01T09:00:00.000Z', action: 'today' },
  ];
  const next = upcomingOnNextDay(rows, '2026-10-01', 0);
  assert.deepEqual(
    next.map((row) => row.action),
    ['walk', 'feed'],
  );
});

test('coming up is empty when nothing is due after today', () => {
  const rows = [
    { status: 'due', due_at: '2026-10-01T09:00:00.000Z' },
    { status: 'done', due_at: '2026-10-02T09:00:00.000Z' },
  ];
  assert.deepEqual(upcomingOnNextDay(rows, '2026-10-01', 0), []);
});

test('a custom evening clock is used for that care', () => {
  const now = new Date('2026-09-30T10:00:00.000Z');
  const due = nextDue(
    {
      frequency: 'daily',
      reminders: ['evening'],
      weekdays: [],
      slotHours: { evening: { hour: 19, minute: 0 } },
    },
    0,
    now,
  );
  assert.equal(due, '2026-09-30T19:00:00.000Z');
});

test('a care override wins over the account clock', () => {
  const hours = mergeSlotHours(
    { evening: { hour: 18, minute: 0 } },
    { evening: { hour: 20, minute: 0 } },
  );
  assert.equal(hours.evening.hour, 20);
  assert.equal(hours.morning.hour, 9);
});

test('custom minutes stay on the due time', () => {
  const now = new Date('2026-10-01T08:00:00.000Z');
  const times = duesOnCycle(
    {
      frequency: 'daily',
      reminders: ['morning', 'evening'],
      weekdays: [],
      slotHours: {
        morning: { hour: 8, minute: 15 },
        evening: { hour: 20, minute: 0 },
      },
    },
    0,
    now,
  );
  assert.deepEqual(times, ['2026-10-01T08:15:00.000Z', '2026-10-01T20:00:00.000Z']);
});
