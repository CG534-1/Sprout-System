const SLOTS = ['morning', 'afternoon', 'evening'];

export const DEFAULT_SLOT_HOURS = {
  morning: { hour: 9, minute: 0 },
  afternoon: { hour: 13, minute: 0 },
  evening: { hour: 18, minute: 0 },
};

const INTERVAL = {
  daily: 1,
  everyTwoDays: 2,
  everyThreeDays: 3,
  weekly: 7,
  custom: 1,
  setDays: 1,
};

export function utcOffsetMinutes(req) {
  const raw = Number(req?.headers?.['x-utc-offset-minutes'] ?? 0);
  return Number.isFinite(raw) ? raw : 0;
}

export function wallNow(offsetMinutes, now = new Date()) {
  return new Date(now.getTime() + offsetMinutes * 60000);
}

export function wallToUtc(year, month, day, hour, offsetMinutes, minute = 0) {
  return new Date(Date.UTC(year, month - 1, day, hour, minute ?? 0, 0) - offsetMinutes * 60000);
}

export function wallParts(date) {
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
    hour: date.getUTCHours(),
    minute: date.getUTCMinutes(),
    weekday: date.getUTCDay() === 0 ? 7 : date.getUTCDay(),
  };
}

export const SUMMARY_LOCAL = { hour: 8, minute: 45 };

export function isSummaryTime(wall) {
  return wall.hour === SUMMARY_LOCAL.hour && wall.minute >= SUMMARY_LOCAL.minute;
}

export function upcomingOnNextDay(rows, todayKey, offsetMinutes) {
  const future = (rows ?? [])
    .filter((row) => row.status === 'due' && localDayKey(row.due_at, offsetMinutes) > todayKey)
    .sort((a, b) => new Date(a.due_at) - new Date(b.due_at));
  if (!future.length) return [];
  const nextDay = localDayKey(future[0].due_at, offsetMinutes);
  return future.filter((row) => localDayKey(row.due_at, offsetMinutes) === nextDay);
}

export function localDayKey(instant, offsetMinutes) {
  const wall = wallNow(offsetMinutes, new Date(instant));
  const parts = wallParts(wall);
  const month = String(parts.month).padStart(2, '0');
  const day = String(parts.day).padStart(2, '0');
  return `${parts.year}-${month}-${day}`;
}

function clampHour(value) {
  const hour = Number(value);
  if (!Number.isFinite(hour)) return null;
  const whole = Math.trunc(hour);
  return whole >= 0 && whole <= 23 ? whole : null;
}

function clampMinute(value) {
  const minute = Number(value);
  if (!Number.isFinite(minute)) return 0;
  const whole = Math.trunc(minute);
  if (whole < 0 || whole > 59) return 0;
  return whole;
}

function readClock(value) {
  if (typeof value === 'number') {
    const hour = clampHour(value);
    return hour == null ? null : { hour, minute: 0 };
  }
  if (value && typeof value === 'object') {
    const hour = clampHour(value.hour);
    if (hour == null) return null;
    return { hour, minute: clampMinute(value.minute) };
  }
  return null;
}

export function overrideSlotHours(raw) {
  const out = {};
  if (!raw || typeof raw !== 'object') return out;
  for (const slot of SLOTS) {
    const clock = readClock(raw[slot]);
    if (clock) out[slot] = clock;
  }
  return out;
}

export function normalizeSlotHours(raw, fallback = DEFAULT_SLOT_HOURS) {
  return {
    morning: { ...fallback.morning },
    afternoon: { ...fallback.afternoon },
    evening: { ...fallback.evening },
    ...overrideSlotHours(raw),
  };
}

export function mergeSlotHours(settingsHours, overrideHours) {
  return normalizeSlotHours(overrideHours, normalizeSlotHours(settingsHours));
}

export function clockFor(slot, hours) {
  return hours?.[slot] ?? DEFAULT_SLOT_HOURS[slot] ?? DEFAULT_SLOT_HOURS.morning;
}

function minutesOf(clock) {
  return clock.hour * 60 + (clock.minute ?? 0);
}

function sortReminders(reminders, hours) {
  return [...(reminders ?? [])].sort(
    (a, b) => minutesOf(clockFor(a, hours)) - minutesOf(clockFor(b, hours)),
  );
}

function firstClock(reminders, hours) {
  return clockFor(sortReminders(reminders, hours)[0] ?? 'morning', hours);
}

function intervalDays(entry) {
  if (entry.frequency === 'custom') return entry.everyDays || 1;
  return INTERVAL[entry.frequency] ?? 1;
}

function afterLast(last, entry, clock, interval) {
  const day = new Date(Date.UTC(last.year, last.month - 1, last.day));
  if (entry.frequency === 'setDays' && entry.weekdays?.length) {
    for (let offset = 1; offset <= 7; offset += 1) {
      const next = new Date(day.getTime() + offset * 86400000);
      const weekday = next.getUTCDay() === 0 ? 7 : next.getUTCDay();
      if (entry.weekdays.includes(weekday)) {
        return {
          year: next.getUTCFullYear(),
          month: next.getUTCMonth() + 1,
          day: next.getUTCDate(),
          hour: clock.hour,
          minute: clock.minute,
        };
      }
    }
  }
  const next = new Date(day.getTime() + interval * 86400000);
  return {
    year: next.getUTCFullYear(),
    month: next.getUTCMonth() + 1,
    day: next.getUTCDate(),
    hour: clock.hour,
    minute: clock.minute,
  };
}

function entryHours(entry) {
  return normalizeSlotHours(entry.slotHours);
}

function atWall(year, month, day, clock, offsetMinutes) {
  return wallToUtc(year, month, day, clock.hour, offsetMinutes, clock.minute);
}

export function nextDue(entry, offsetMinutes, now = new Date()) {
  const hours = entryHours(entry);
  const wall = wallNow(offsetMinutes, now);
  const current = wallParts(wall);
  const reminders = sortReminders(entry.reminders, hours);
  const clock = firstClock(reminders, hours);
  const interval = intervalDays(entry);
  const last = entry.lastDone ? wallParts(wallNow(offsetMinutes, new Date(entry.lastDone))) : null;

  const asInstant = (parts) =>
    wallToUtc(parts.year, parts.month, parts.day, parts.hour, offsetMinutes, parts.minute ?? 0);

  if (last) {
    const fromLast = afterLast(last, entry, clock, interval);
    const instant = asInstant(fromLast);
    if (instant.getTime() >= now.getTime()) return instant.toISOString();
  } else if (entry.frequency !== 'setDays' || entry.weekdays?.includes(current.weekday)) {
    // A new plan starts today so Home is not blank after an evening add.
    return atWall(current.year, current.month, current.day, clock, offsetMinutes).toISOString();
  }

  if (entry.frequency === 'setDays' && entry.weekdays?.length) {
    for (let offset = 0; offset < 8; offset += 1) {
      const day = new Date(Date.UTC(current.year, current.month - 1, current.day + offset));
      const weekday = day.getUTCDay() === 0 ? 7 : day.getUTCDay();
      if (!entry.weekdays.includes(weekday)) continue;
      for (const slot of reminders) {
        const at = atWall(
          day.getUTCFullYear(),
          day.getUTCMonth() + 1,
          day.getUTCDate(),
          clockFor(slot, hours),
          offsetMinutes,
        );
        if (at.getTime() >= now.getTime()) return at.toISOString();
      }
    }
  }

  for (const slot of reminders) {
    const at = atWall(current.year, current.month, current.day, clockFor(slot, hours), offsetMinutes);
    if (at.getTime() >= now.getTime()) return at.toISOString();
  }

  const rolled = new Date(Date.UTC(current.year, current.month - 1, current.day + interval));
  return atWall(
    rolled.getUTCFullYear(),
    rolled.getUTCMonth() + 1,
    rolled.getUTCDate(),
    clock,
    offsetMinutes,
  ).toISOString();
}

export function duesOnCycle(entry, offsetMinutes, now = new Date()) {
  const hours = entryHours(entry);
  const first = nextDue(entry, offsetMinutes, now);
  const day = localDayKey(first, offsetMinutes);
  const [year, month, date] = day.split('-').map(Number);
  const reminders = sortReminders(entry.reminders, hours);
  const slots = reminders.length ? reminders : ['morning'];
  const times = slots
    .map((slot) => atWall(year, month, date, clockFor(slot, hours), offsetMinutes).toISOString())
    .filter((instant) => new Date(instant).getTime() >= now.getTime());
  return times.length ? times : [first];
}

export function leadMinutes(label) {
  if (label === '15 min before') return 15;
  if (label === '1 hour before') return 60;
  return 30;
}

export function preferredHour(slot) {
  return DEFAULT_SLOT_HOURS[slot]?.hour ?? 9;
}

export function clocksEqual(left, right) {
  const a = normalizeSlotHours(left);
  const b = normalizeSlotHours(right);
  return SLOTS.every(
    (slot) => a[slot].hour === b[slot].hour && a[slot].minute === b[slot].minute,
  );
}
