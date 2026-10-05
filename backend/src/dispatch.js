import { isSummaryTime, leadMinutes, localDayKey, wallNow, wallParts } from './care.js';
import { messaging } from './firebase.js';

export async function dispatchReminders(admin, now = new Date(), sender = messaging()) {
  await ensureMissingSettings(admin);
  const { data: settings, error } = await admin.from('user_settings').select('*');
  if (error) throw error;
  let sent = 0;
  for (const setting of settings ?? []) {
    sent += await dispatchUser(admin, sender, setting, now);
  }
  return sent;
}

async function ensureMissingSettings(admin) {
  const { data: profiles, error } = await admin.from('profiles').select('id');
  if (error) throw error;
  const { data: settings, error: settingsError } = await admin.from('user_settings').select('user_id');
  if (settingsError) throw settingsError;
  const have = new Set((settings ?? []).map((row) => row.user_id));
  const missing = (profiles ?? []).filter((row) => !have.has(row.id));
  if (!missing.length) return;
  const rows = missing.map((row) => ({
    user_id: row.id,
    reminders: true,
    overdue: true,
    summary: true,
    tips: false,
    preferred_slot: 'morning',
    lead: '30 min before',
    utc_offset_minutes: 0,
  }));
  const { error: insertError } = await admin.from('user_settings').insert(rows);
  if (insertError) console.error(insertError);
}

export async function dispatchForUser(admin, userId, now = new Date(), sender = messaging()) {
  const { data: setting, error } = await admin
    .from('user_settings')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();
  if (error) throw error;
  if (!setting) return 0;
  return dispatchUser(admin, sender, setting, now);
}

async function dispatchUser(admin, sender, setting, now) {
  const offsetMinutes = Number(setting.utc_offset_minutes) || 0;
  const { data: tokens } = await admin
    .from('device_tokens')
    .select('token')
    .eq('user_id', setting.user_id);
  const targets = (tokens ?? []).map((row) => row.token);

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
    const scheduleLead = leadBySchedule.get(task.schedule_id);
    const lead = leadMinutes(scheduleLead || setting.lead);
    const trigger = due - lead * 60000;
    const nowMs = now.getTime();
    if (setting.reminders && !task.reminded_at && nowMs >= trigger && nowMs < due) {
      const ok = await send(sender, admin, setting.user_id, targets, {
        title: 'Care reminder',
        body: `${label(task.action)} ${task.subject_name}`,
      });
      if (ok) {
        await admin.from('care_tasks').update({ reminded_at: now.toISOString() }).eq('id', task.id);
        task.reminded_at = now.toISOString();
        sent += 1;
      }
    } else if (setting.reminders && !task.reminded_at && nowMs >= due) {
      // Lead window was missed (late cron). Still send the care reminder once.
      const ok = await send(sender, admin, setting.user_id, targets, {
        title: 'Care reminder',
        body: `${label(task.action)} ${task.subject_name}`,
      });
      if (ok) {
        await admin.from('care_tasks').update({ reminded_at: now.toISOString() }).eq('id', task.id);
        task.reminded_at = now.toISOString();
        sent += 1;
      }
    } else if (
      setting.overdue &&
      !task.overdue_sent_at &&
      nowMs >= due
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
    isSummaryTime(wall) &&
    dueToday.length
  ) {
    const ok = await send(sender, admin, setting.user_id, targets, {
      title: 'Today on Sprout',
      body: `${dueToday.length} care task${dueToday.length === 1 ? '' : 's'} today.`,
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
    if (sender && tokens.length) {
      const response = await sender.sendEachForMulticast({
        tokens,
        notification: note,
        android: {
          priority: 'high',
          notification: {
            channelId: 'sprout_care',
            priority: 'high',
            defaultSound: true,
          },
        },
      });
      const stale = [];
      response.responses.forEach((item, index) => {
        const code = item.error?.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          stale.push(tokens[index]);
        }
      });
      if (stale.length) await admin.from('device_tokens').delete().in('token', stale);
    }
    await admin.from('push_notifications').insert({
      user_id: userId,
      title: note.title,
      body: note.body,
    });
    return true;
  } catch (error) {
    console.error(error);
    return false;
  }
}

