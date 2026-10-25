import { localDayKey, wallToUtc } from './care.js';

/**
 * The bell's notes for one account, newest first and at most 50, in the
 * REST shape. Notes read before today (in the caller's time zone) are
 * deleted first. Shared by GET /api/me/notifications and Connect's
 * NotificationService.ListNotifications.
 */
export async function listNotes(db, userId, offsetMinutes) {
  await purgeReadNotes(db, userId, offsetMinutes);
  const { data, error } = await db
    .from('push_notifications')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) throw error;
  return (data ?? []).map(noteJson);
}

async function purgeReadNotes(db, userId, offsetMinutes) {
  const today = localDayKey(new Date().toISOString(), offsetMinutes);
  const [year, month, day] = today.split('-').map(Number);
  const startOfToday = wallToUtc(year, month, day, 0, offsetMinutes, 0).toISOString();
  const { error } = await db
    .from('push_notifications')
    .delete()
    .eq('user_id', userId)
    .not('read_at', 'is', null)
    .lt('read_at', startOfToday);
  if (error) throw error;
}

function noteJson(row) {
  return {
    id: row.id,
    title: row.title,
    body: row.body,
    createdAt: row.created_at,
    read: row.read_at != null,
  };
}
