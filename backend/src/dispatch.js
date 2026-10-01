import { leadMinutes, localDayKey, preferredHour, wallNow, wallParts } from './care.js';
import { messaging } from './firebase.js';

export async function dispatchReminders(admin, now = new Date()) {
  const sender = messaging();
  const { data: settings, error } = await admin.from('user_settings').select('*');
  if (error) throw error;
  let sent = 0;
  for (const setting of settings ?? []) {
    sent += await dispatchUser(admin, sender, setting, now);
  }
  return sent;
}

async function dispatchUser(admin, sender, setting, now) {
  const offsetMinutes = Number(setting.utc_offset_minutes) || 0;
  const { data: tokens } = await admin
    .from('device_tokens')
    .select('token')
    .eq('user_id', setting.user_id);
  const targets = (tokens ?? []).map((row) => row.token);
  if (!targets.length || !sender) return 0;

  const { data: tasks } = await admin
    .from('care_tasks')
    .select('*')
    .eq('user_id', setting.user_id)
    .eq('status', 'due');
  const open = tasks ?? [];
  let sent = 0;
  const { data: schedules } = await admin
    .from('care_schedules')
    .select('id, lead')
    .eq('user_id', setting.user_id);
  const leadBySchedule = new Map((schedules ?? []).map((row) => [row.id, row.lead]));

  for (const task of open) {
    const due = new Date(task.due_at).getTime();
    const lead = leadMinutes(leadBySchedule.get(task.schedule_id) || setting.lead);
    const trigger = due - lead * 60000;
    if (setting.reminders && !task.reminded_at && now.getTime() >= trigger && now.getTime() < due) {
      const ok = await send(sender, admin, setting.user_id, targets, {
        title: 'Care reminder',
        body: `${label(task.action)} ${task.subject_name}`,
      });
      if (ok) {
        await admin.from('care_tasks').update({ reminded_at: now.toISOString() }).eq('id', task.id);
        sent += 1;
      }
    } else if (
      setting.overdue &&
      !task.overdue_sent_at &&
      now.getTime() >= due
    ) {
      const ok = await send(sender, admin, setting.user_id, targets, {
        title: 'Overdue care',
        body: `${label(task.action)} ${task.subject_name} is still open`,
      });
      if (ok) {
        await admin.from('care_tasks').update({ overdue_sent_at: now.toISOString() }).eq('id', task.id);
        sent += 1;
      }
    }
  }

  const wall = wallParts(wallNow(offsetMinutes, now));
  const today = localDayKey(now.toISOString(), offsetMinutes);
  const dueToday = open.filter((task) => localDayKey(task.due_at, offsetMinutes) === today);
  if (
    setting.summary &&
    setting.summary_sent_on !== today &&
    wall.hour === preferredHour(setting.preferred_slot) &&
    dueToday.length
  ) {
    const tip = setting.tips ? ' A little progress, every day.' : '';
    const ok = await send(sender, admin, setting.user_id, targets, {
      title: 'Today on Sprout',
      body: `${dueToday.length} care task${dueToday.length === 1 ? '' : 's'} today.${tip}`,
    });
    if (ok) {
      await admin.from('user_settings').update({ summary_sent_on: today }).eq('user_id', setting.user_id);
      sent += 1;
    }
  }
  return sent;
}

function label(action) {
  const names = {
    water: 'Water',
    mist: 'Mist',
    fertilize: 'Fertilize',
    feed: 'Feed',
    walk: 'Walk',
    groom: 'Groom',
    waterBowl: 'Refill',
  };
  return names[action] ?? 'Care for';
}

async function send(sender, admin, userId, tokens, note) {
  try {
    const response = await sender.sendEachForMulticast({
      tokens,
      notification: note,
    });
    const stale = [];
    response.responses.forEach((item, index) => {
      const code = item.error?.code;
      if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
        stale.push(tokens[index]);
      }
    });
    if (stale.length) await admin.from('device_tokens').delete().in('token', stale);
    if (response.successCount > 0) {
      await admin.from('push_notifications').insert({
        user_id: userId,
        title: note.title,
        body: note.body,
      });
      return true;
    }
    return false;
  } catch (error) {
    console.error(error);
    return false;
  }
}

