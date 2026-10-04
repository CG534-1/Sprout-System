import assert from 'node:assert/strict';
import test from 'node:test';
import { localDayKey, nextDue, preferredHour, duesOnCycle, upcomingOnNextDay } from './care.js';

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

test('a new plan still starts today after the reminder hour', () => {
  const now = new Date('2026-09-30T22:00:00.000Z');
  const due = nextDue(
    { frequency: 'daily', reminders: ['morning'], weekdays: [] },
    0,
    now,
  );
  assert.equal(due, '2026-09-30T09:00:00.000Z');
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

test('a daily summary uses the saved time of day', () => {
  assert.equal(preferredHour('morning'), 9);
  assert.equal(preferredHour('afternoon'), 13);
  assert.equal(preferredHour('evening'), 18);
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
