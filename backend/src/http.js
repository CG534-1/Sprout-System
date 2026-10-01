import cors from 'cors';
import express from 'express';
import { createClient } from '@supabase/supabase-js';
import { localDayKey, utcOffsetMinutes, duesOnCycle } from './care.js';
import { dispatchReminders } from './dispatch.js';

const bucket = 'care-media';

export function createApp() {
  const app = express();
  const origin = process.env.CLIENT_ORIGIN;
  app.use(cors({ origin: origin ? origin.split(',').map((item) => item.trim()) : true }));
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });

  app.post('/api/internal/dispatch-reminders', async (req, res, next) => {
    try {
      const secret = process.env.CRON_SECRET;
      if (!secret || req.headers['x-cron-secret'] !== secret) {
        res.status(401).json({ message: 'Not allowed.' });
        return;
      }
      const admin = service();
      const sent = await dispatchReminders(admin);
      res.json({ sent });
    } catch (error) {
      next(error);
    }
  });

  app.use('/api', async (req, res, next) => {
    try {
      if (!process.env.SUPABASE_URL || !process.env.SUPABASE_ANON_KEY) {
        res.status(503).json({ message: 'API is not configured.' });
        return;
      }
      const header = req.headers.authorization ?? '';
      const token = header.startsWith('Bearer ') ? header.slice(7) : '';
      if (!token) {
        res.status(401).json({ message: 'Sign in to continue.' });
        return;
      }
      const admin = service();
      const { data, error } = await admin.auth.getUser(token);
      if (error || !data.user) {
        res.status(401).json({ message: 'Sign in to continue.' });
        return;
      }
      req.user = data.user;
      req.admin = admin;
      await admin
        .from('user_settings')
        .update({ utc_offset_minutes: utcOffsetMinutes(req) })
        .eq('user_id', data.user.id);
      req.db = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
        accessToken: async () => token,
        auth: { persistSession: false, autoRefreshToken: false },
      });
      next();
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/me', async (req, res, next) => {
    try {
      res.json(await profileJson(req));
    } catch (error) {
      next(error);
    }
  });

  app.patch('/api/me', async (req, res, next) => {
    try {
      const name = String(req.body.name ?? '').trim();
      const email = String(req.body.email ?? req.user.email ?? '').trim();
      if (!name) throw httpError(400, 'Enter your name.');
      if (!email.includes('@')) throw httpError(400, 'Enter a valid email.');
      const avatarRef = req.body.avatarPath ?? req.body.avatarUrl ?? undefined;
      const patch = { id: req.user.id, name, email };
      if (avatarRef !== undefined) patch.avatar_ref = avatarRef || null;
      const { error } = await req.db.from('profiles').upsert(patch, { onConflict: 'id' });
      if (error) throw error;
      await req.db.from('pending_profiles').delete().eq('id', req.user.id);
      res.json(await profileJson(req));
    } catch (error) {
      next(error);
    }
  });

  app.delete('/api/me', async (req, res, next) => {
    try {
      await wipeAccount(req.admin, req.user.id);
      res.status(204).end();
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/me/settings', async (req, res, next) => {
    try {
      var { data, error } = await req.db
          .from('user_settings')
          .select('*')
          .eq('user_id', req.user.id)
          .maybeSingle();
      if (error) throw error;
      res.json(settingsJson(data));
    } catch (error) {
      next(error);
    }
  });

  app.put('/api/me/settings', async (req, res, next) => {
    try {
      const patch = {
        user_id: req.user.id,
        reminders: Boolean(req.body.reminders),
        overdue: Boolean(req.body.overdue),
        summary: Boolean(req.body.summary),
        tips: Boolean(req.body.tips),
        preferred_slot: req.body.preferred || 'morning',
        lead: req.body.lead || '30 min before',
        utc_offset_minutes: utcOffsetMinutes(req),
      };
      const { data, error } = await req.db
        .from('user_settings')
        .upsert(patch, { onConflict: 'user_id' })
        .select('*')
        .single();
      if (error) throw error;
      res.json(settingsJson(data));
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/me/notifications', async (req, res, next) => {
    try {
      const { data, error } = await req.db
        .from('push_notifications')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(50);
      if (error) throw error;
      res.json((data ?? []).map(noteJson));
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/me/notifications/read', async (req, res, next) => {
    try {
      const { error } = await req.db
        .from('push_notifications')
        .update({ read_at: new Date().toISOString() })
        .is('read_at', null);
      if (error) throw error;
      res.status(204).end();
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/devices', async (req, res, next) => {
    try {
      const token = String(req.body.token ?? '');
      const platform = req.body.platform === 'web' ? 'web' : 'android';
      if (!token) throw httpError(400, 'Missing device token.');
      const { error } = await req.admin.from('device_tokens').upsert(
        { user_id: req.user.id, token, platform },
        { onConflict: 'token' },
      );
      if (error) throw error;
      res.status(204).end();
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/plants', async (req, res, next) => {
    try {
      const { data, error } = await req.db
        .from('plants')
        .select('*')
        .order('created_at', { ascending: true });
      if (error) throw error;
      res.json(await Promise.all(data.map((row) => plantJson(req.admin, row))));
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/plants/:id', async (req, res, next) => {
    try {
      res.json(await plantJson(req.admin, await one(req.db, 'plants', req.params.id)));
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/plants', async (req, res, next) => {
    try {
      const name = String(req.body.name ?? '').trim();
      if (!name) throw httpError(400, 'Name is required.');
      const { data, error } = await req.db
        .from('plants')
        .insert({
          user_id: req.user.id,
          name,
          species: String(req.body.species ?? '').trim(),
          location: emptyToNull(req.body.location),
          notes: emptyToNull(req.body.notes),
          photo_path: emptyToNull(req.body.photoPath),
        })
        .select('*')
        .single();
      if (error) throw error;
      res.status(201).json(await plantJson(req.admin, data));
    } catch (error) {
      next(error);
    }
  });

  app.patch('/api/plants/:id', async (req, res, next) => {
    try {
      const name = String(req.body.name ?? '').trim();
      if (!name) throw httpError(400, 'Name is required.');
      const patch = {
        name,
        species: String(req.body.species ?? '').trim(),
        location: emptyToNull(req.body.location),
        notes: emptyToNull(req.body.notes),
      };
      if (req.body.photoPath) patch.photo_path = req.body.photoPath;
      const { data, error } = await req.db
        .from('plants')
        .update(patch)
        .eq('id', req.params.id)
        .select('*')
        .single();
      if (error) throw error;
      res.json(await plantJson(req.admin, data));
    } catch (error) {
      next(error);
    }
  });

  app.delete('/api/plants/:id', async (req, res, next) => {
    try {
      await removeSubject(req, 'plants', req.params.id);
      res.status(204).end();
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/pets', async (req, res, next) => {
    try {
      const { data, error } = await req.db
        .from('pets')
        .select('*')
        .order('created_at', { ascending: true });
      if (error) throw error;
      res.json(await Promise.all(data.map((row) => petJson(req.admin, row))));
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/pets/:id', async (req, res, next) => {
    try {
      res.json(await petJson(req.admin, await one(req.db, 'pets', req.params.id)));
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/pets', async (req, res, next) => {
    try {
      const name = String(req.body.name ?? '').trim();
      if (!name) throw httpError(400, 'Name is required.');
      const { data, error } = await req.db
        .from('pets')
        .insert({
          user_id: req.user.id,
          name,
          species: String(req.body.species ?? '').trim(),
          breed: String(req.body.breed ?? '').trim(),
          notes: emptyToNull(req.body.notes),
          photo_path: emptyToNull(req.body.photoPath),
        })
        .select('*')
        .single();
      if (error) throw error;
      res.status(201).json(await petJson(req.admin, data));
    } catch (error) {
      next(error);
    }
  });

  app.patch('/api/pets/:id', async (req, res, next) => {
    try {
      const name = String(req.body.name ?? '').trim();
      if (!name) throw httpError(400, 'Name is required.');
      const patch = {
        name,
        species: String(req.body.species ?? '').trim(),
        breed: String(req.body.breed ?? '').trim(),
        notes: emptyToNull(req.body.notes),
      };
      if (req.body.photoPath) patch.photo_path = req.body.photoPath;
      const { data, error } = await req.db
        .from('pets')
        .update(patch)
        .eq('id', req.params.id)
        .select('*')
        .single();
      if (error) throw error;
      res.json(await petJson(req.admin, data));
    } catch (error) {
      next(error);
    }
  });

  app.delete('/api/pets/:id', async (req, res, next) => {
    try {
      await removeSubject(req, 'pets', req.params.id);
      res.status(204).end();
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/schedules', async (req, res, next) => {
    try {
      let query = req.db.from('care_schedules').select('*');
      if (req.query.subjectId) query = query.eq('subject_id', req.query.subjectId);
      const { data, error } = await query;
      if (error) throw error;
      res.json(data.map(scheduleJson));
    } catch (error) {
      next(error);
    }
  });

  app.put('/api/schedules', async (req, res, next) => {
    try {
      const subjectId = req.body.subjectId;
      const subjectName = String(req.body.subjectName ?? '').trim();
      const subjectType = req.body.subjectType === 'pet' ? 'pet' : 'plant';
      if (!subjectId || !subjectName) throw httpError(400, 'A plant or pet is required.');
      const entries = Array.isArray(req.body.entries) ? req.body.entries : [];
      const offset = utcOffsetMinutes(req);
      const { error: dropSchedules } = await req.db
        .from('care_schedules')
        .delete()
        .eq('subject_id', subjectId);
      if (dropSchedules) throw dropSchedules;
      const { error: dropTasks } = await req.db
        .from('care_tasks')
        .delete()
        .eq('subject_id', subjectId)
        .neq('status', 'done');
      if (dropTasks) throw dropTasks;
      for (const entry of entries) {
        const plan = {
          frequency: entry.frequency,
          reminders: entry.reminders ?? [],
          everyDays: entry.everyDays,
          weekdays: entry.weekdays ?? [],
          lastDone: entry.lastDone,
        };
        const times = duesOnCycle(plan, offset);
        const { data: schedule, error } = await req.db
          .from('care_schedules')
          .insert({
            user_id: req.user.id,
            subject_id: subjectId,
            subject_type: subjectType,
            action: entry.action,
            frequency: entry.frequency,
            next_due: times[0],
            times_per_day: entry.timesPerDay ?? null,
            reminders: entry.reminders ?? [],
            every_days: entry.everyDays ?? null,
            weekdays: entry.weekdays ?? [],
            last_done: entry.lastDone ?? null,
            lead: entry.lead || null,
          })
          .select('*')
          .single();
        if (error) throw error;
        for (const due of times) {
          const { error: taskError } = await req.db.from('care_tasks').insert({
            user_id: req.user.id,
            schedule_id: schedule.id,
            subject_id: subjectId,
            subject_type: subjectType,
            subject_name: subjectName,
            action: entry.action,
            due_at: due,
            status: 'due',
          });
          if (taskError) throw taskError;
        }
      }
      res.status(204).end();
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/tasks', async (req, res, next) => {
    try {
      const offset = utcOffsetMinutes(req);
      const date = req.query.date || localDayKey(new Date().toISOString(), offset);
      const { data, error } = await req.db.from('care_tasks').select('*');
      if (error) throw error;
      if (req.query.upcoming === '1') {
        const next = (data ?? [])
          .filter((row) => row.status === 'due' && localDayKey(row.due_at, offset) > date)
          .sort((a, b) => new Date(a.due_at) - new Date(b.due_at))[0];
        res.json(next ? [taskJson(next)] : []);
        return;
      }
      const tasks = data
        .filter((row) => localDayKey(row.due_at, offset) === date)
        .map(taskJson)
        .sort((a, b) => {
          const rank = (status) => (status === 'due' ? 0 : 1);
          const byStatus = rank(a.status) - rank(b.status);
          if (byStatus !== 0) return byStatus;
          return a.subjectName.localeCompare(b.subjectName);
        });
      res.json(tasks);
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/tasks/:id/complete', async (req, res, next) => {
    try {
      const task = await one(req.db, 'care_tasks', req.params.id, 'This task could not be found.');
      if (task.status !== 'done') {
        const { error } = await req.db.from('care_tasks').update({ status: 'done' }).eq('id', task.id);
        if (error) throw error;
        const { error: historyError } = await req.db.from('care_history').insert({
          user_id: req.user.id,
          task_id: task.id,
          subject_id: task.subject_id,
          subject_name: task.subject_name,
          subject_type: task.subject_type,
          action: task.action,
          completed_at: new Date().toISOString(),
        });
        if (historyError) throw historyError;
      }
      res.status(204).end();
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/tasks/:id/reopen', async (req, res, next) => {
    try {
      const task = await one(req.db, 'care_tasks', req.params.id, 'This task could not be found.');
      if (task.status === 'done') {
        const { error } = await req.db.from('care_tasks').update({ status: 'due' }).eq('id', task.id);
        if (error) throw error;
        const { error: historyError } = await req.db.from('care_history').delete().eq('task_id', task.id);
        if (historyError) throw historyError;
      }
      res.status(204).end();
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/care-history', async (req, res, next) => {
    try {
      const { data, error } = await req.db
        .from('care_history')
        .select('*')
        .order('completed_at', { ascending: false });
      if (error) throw error;
      res.json(data.map(historyJson));
    } catch (error) {
      next(error);
    }
  });

  app.use((error, _req, res, _next) => {
    const status = error.status || 500;
    const message = error.message || 'Something went wrong.';
    if (status >= 500) console.error(error);
    res.status(status).json({ message });
  });

  return app;
}

function service() {
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    throw httpError(503, 'API is not configured.');
  }
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function emptyToNull(value) {
  if (value == null) return null;
  const trimmed = String(value).trim();
  return trimmed ? trimmed : null;
}

async function one(db, table, id, missing = 'This could not be found.') {
  const { data, error } = await db.from(table).select('*').eq('id', id).maybeSingle();
  if (error) throw error;
  if (!data) throw httpError(404, missing);
  return data;
}

async function removeSubject(req, table, id) {
  const row = await one(
    req.db,
    table,
    id,
    table === 'plants' ? 'This plant could not be found.' : 'This pet could not be found.',
  );
  if (row.photo_path) {
    await req.admin.storage.from(bucket).remove([row.photo_path]);
  }
  await req.db.from('care_schedules').delete().eq('subject_id', id);
  await req.db.from('care_tasks').delete().eq('subject_id', id);
  await req.db.from('care_history').delete().eq('subject_id', id);
  const { error } = await req.db.from(table).delete().eq('id', id);
  if (error) throw error;
}

async function wipeAccount(admin, userId) {
  const { data: files } = await admin.storage.from(bucket).list(userId);
  if (files?.length) {
    await admin.storage.from(bucket).remove(files.map((file) => `${userId}/${file.name}`));
  }
  const tables = [
    'care_history',
    'care_tasks',
    'care_schedules',
    'plants',
    'pets',
    'device_tokens',
    'push_notifications',
    'user_settings',
    'pending_profiles',
    'profiles',
  ];
  for (const table of tables) {
    const column = table === 'profiles' || table === 'pending_profiles' ? 'id' : 'user_id';
    const { error } = await admin.from(table).delete().eq(column, userId);
    if (error) throw error;
  }
  const { error } = await admin.auth.admin.deleteUser(userId);
  if (error) throw error;
}

async function signedUrl(admin, ref) {
  if (!ref) return null;
  if (String(ref).startsWith('assets/')) return ref;
  const { data, error } = await admin.storage.from(bucket).createSignedUrl(ref, 60 * 60 * 6);
  if (error || !data?.signedUrl) return null;
  return data.signedUrl;
}

async function profileJson(req) {
  let { data, error } = await req.db.from('profiles').select('*').eq('id', req.user.id).maybeSingle();
  if (error) throw error;
  if (!data) {
    if (req.user.user_metadata?.password_set !== true) {
      throw httpError(409, 'Choose a password to finish creating your account.');
    }
    const created = await req.db
      .from('profiles')
      .insert({
        id: req.user.id,
        name: req.user.user_metadata?.name ?? '',
        email: req.user.email ?? '',
      })
      .select('*')
      .single();
    if (created.error) throw created.error;
    data = created.data;
  }
  return {
    id: data.id,
    name: data.name,
    email: data.email || req.user.email,
    avatarUrl: await signedUrl(req.admin, data.avatar_ref),
  };
}

function settingsJson(row) {
  return {
    reminders: row?.reminders ?? true,
    overdue: row?.overdue ?? true,
    summary: row?.summary ?? true,
    tips: row?.tips ?? false,
    preferred: row?.preferred_slot ?? 'morning',
    lead: row?.lead ?? '30 min before',
  };
}

async function plantJson(admin, row) {
  return {
    id: row.id,
    name: row.name,
    species: row.species,
    photoUrl: await signedUrl(admin, row.photo_path),
    location: row.location,
    notes: row.notes,
    createdAt: row.created_at,
  };
}

async function petJson(admin, row) {
  return {
    id: row.id,
    name: row.name,
    species: row.species,
    breed: row.breed ?? '',
    photoUrl: await signedUrl(admin, row.photo_path),
    notes: row.notes,
    createdAt: row.created_at,
  };
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

function scheduleJson(row) {
  return {
    id: row.id,
    subjectId: row.subject_id,
    subjectType: row.subject_type,
    action: row.action,
    frequency: row.frequency,
    nextDue: row.next_due,
    timesPerDay: row.times_per_day,
    reminders: row.reminders ?? [],
    everyDays: row.every_days,
    weekdays: row.weekdays ?? [],
    lastDone: row.last_done,
    lead: row.lead ?? null,
  };
}

function taskJson(row) {
  return {
    id: row.id,
    scheduleId: row.schedule_id ?? '',
    subjectId: row.subject_id,
    subjectType: row.subject_type,
    subjectName: row.subject_name,
    action: row.action,
    dueAt: row.due_at,
    status: row.status,
  };
}

function historyJson(row) {
  return {
    id: row.id,
    taskId: row.task_id ?? '',
    subjectName: row.subject_name,
    subjectType: row.subject_type,
    action: row.action,
    completedAt: row.completed_at,
    note: row.note,
  };
}
