alter table public.user_settings
  add column if not exists slot_hours jsonb not null default '{}'::jsonb;

alter table public.care_schedules
  add column if not exists slot_hours jsonb not null default '{}'::jsonb;
