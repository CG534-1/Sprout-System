const SLOT_HOUR = { morning: 9, afternoon: 13, evening: 18 };

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

export function wallToUtc(year, month, day, hour, offsetMinutes) {
  return new Date(Date.UTC(year, month - 1, day, hour, 0, 0) - offsetMinutes * 60000);
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

function slotHour(reminders) {
  const hours = (reminders ?? [])
    .map((slot) => SLOT_HOUR[slot])
    .filter((hour) => hour != null)
    .sort((a, b) => a - b);
  return hours[0] ?? 9;
}

function intervalDays(entry) {
  if (entry.frequency === 'custom') return entry.everyDays || 1;
  return INTERVAL[entry.frequency] ?? 1;
}

function afterLast(last, entry, hour, interval) {
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
          hour,
        };
      }
    }
  }
  const next = new Date(day.getTime() + interval * 86400000);
  return {
    year: next.getUTCFullYear(),
    month: next.getUTCMonth() + 1,
    day: next.getUTCDate(),
    hour,
  };
}

export function nextDue(entry, offsetMinutes, now = new Date()) {
  const wall = wallNow(offsetMinutes, now);
  const current = wallParts(wall);
  const reminders = [...(entry.reminders ?? [])].sort(
    (a, b) => (SLOT_HOUR[a] ?? 99) - (SLOT_HOUR[b] ?? 99),
  );
  const hour = slotHour(reminders);
  const interval = intervalDays(entry);
  const last = entry.lastDone ? wallParts(wallNow(offsetMinutes, new Date(entry.lastDone))) : null;

  const asInstant = (parts) => wallToUtc(parts.year, parts.month, parts.day, parts.hour, offsetMinutes);

  if (last) {
    const fromLast = afterLast(last, entry, hour, interval);
    const instant = asInstant(fromLast);
    if (instant.getTime() >= now.getTime()) return instant.toISOString();
  } else if (entry.frequency !== 'setDays' || entry.weekdays?.includes(current.weekday)) {
    // A new plan starts today so Home is not blank after an evening add.
    return wallToUtc(current.year, current.month, current.day, hour, offsetMinutes).toISOString();
  }

  if (entry.frequency === 'setDays' && entry.weekdays?.length) {
    for (let offset = 0; offset < 8; offset += 1) {
      const day = new Date(Date.UTC(current.year, current.month - 1, current.day + offset));
      const weekday = day.getUTCDay() === 0 ? 7 : day.getUTCDay();
      if (!entry.weekdays.includes(weekday)) continue;
      for (const slot of reminders) {
        const at = wallToUtc(
          day.getUTCFullYear(),
          day.getUTCMonth() + 1,
          day.getUTCDate(),
          SLOT_HOUR[slot],
          offsetMinutes,
        );
        if (at.getTime() >= now.getTime()) return at.toISOString();
      }
    }
  }

  for (const slot of reminders) {
    const at = wallToUtc(current.year, current.month, current.day, SLOT_HOUR[slot], offsetMinutes);
    if (at.getTime() >= now.getTime()) return at.toISOString();
  }

  const rolled = new Date(Date.UTC(current.year, current.month - 1, current.day + interval));
  return wallToUtc(
    rolled.getUTCFullYear(),
    rolled.getUTCMonth() + 1,
    rolled.getUTCDate(),
    hour,
    offsetMinutes,
  ).toISOString();
}

export function duesOnCycle(entry, offsetMinutes, now = new Date()) {
  const first = nextDue(entry, offsetMinutes, now);
  const day = localDayKey(first, offsetMinutes);
  const [year, month, date] = day.split('-').map(Number);
  const reminders = [...(entry.reminders ?? [])].sort(
    (a, b) => (SLOT_HOUR[a] ?? 99) - (SLOT_HOUR[b] ?? 99),
  );
  const slots = reminders.length ? reminders : ['morning'];
  const times = slots
    .map((slot) => wallToUtc(year, month, date, SLOT_HOUR[slot] ?? 9, offsetMinutes).toISOString())
    .filter((instant) => new Date(instant).getTime() >= now.getTime());
  return times.length ? times : [first];
}

export function leadMinutes(label) {
  if (label === '15 min before') return 15;
  if (label === '1 hour before') return 60;
  return 30;
}

const PREFERRED_HOUR = { morning: 9, afternoon: 13, evening: 18 };

export function preferredHour(slot) {
  return PREFERRED_HOUR[slot] ?? 9;
}
