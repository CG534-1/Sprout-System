// The settings row every signed-in account has. Shared by the /api auth
// check (which creates it on first use) and the settings routes.

export async function ensureSettings(admin, userId, offsetMinutes = 0) {
  const { data: existing, error } = await admin
    .from('user_settings')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();
  if (error) throw error;
  if (existing) {
    if (existing.utc_offset_minutes !== offsetMinutes) {
      const { data, error: updateError } = await admin
        .from('user_settings')
        .update({ utc_offset_minutes: offsetMinutes })
        .eq('user_id', userId)
        .select('*')
        .single();
      if (updateError) throw updateError;
      return data;
    }
    return existing;
  }
  const { data, error: insertError } = await admin
    .from('user_settings')
    .insert({
      user_id: userId,
      reminders: true,
      overdue: true,
      summary: true,
      tips: false,
      preferred_slot: 'morning',
      lead: '30 min before',
      utc_offset_minutes: offsetMinutes,
      slot_hours: {},
    })
    .select('*')
    .single();
  if (insertError) {
    // Signup can hit /api before a profile row exists.
    if (insertError.code === '23503') return null;
    if (missingColumn(insertError, 'slot_hours')) {
      const retry = await admin
        .from('user_settings')
        .insert({
          user_id: userId,
          reminders: true,
          overdue: true,
          summary: true,
          tips: false,
          preferred_slot: 'morning',
          lead: '30 min before',
          utc_offset_minutes: offsetMinutes,
        })
        .select('*')
        .single();
      if (retry.error) {
        if (retry.error.code === '23503') return null;
        throw retry.error;
      }
      return retry.data;
    }
    throw insertError;
  }
  return data;
}

export function missingColumn(error, column) {
  const text = `${error?.message ?? ''} ${error?.details ?? ''} ${error?.hint ?? ''} ${error?.code ?? ''}`;
  return text.includes(column) || error?.code === 'PGRST204' || error?.code === '42703';
}
