create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '',
  email text not null default '',
  avatar_ref text,
  created_at timestamptz not null default now()
);

create table if not exists public.pending_profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '',
  email text not null default '',
  avatar_ref text,
  created_at timestamptz not null default now()
);

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  reminders boolean not null default true,
  overdue boolean not null default true,
  summary boolean not null default true,
  tips boolean not null default false,
  preferred_slot text not null default 'morning',
  lead text not null default '30 min before',
  summary_sent_on date,
  utc_offset_minutes integer not null default 0
);

alter table public.user_settings add column if not exists utc_offset_minutes integer not null default 0;

create table if not exists public.plants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  species text not null default '',
  photo_path text,
  location text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.pets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  species text not null default '',
  photo_path text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.care_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  subject_id uuid not null,
  subject_type text not null check (subject_type in ('plant', 'pet')),
  action text not null,
  frequency text not null,
  next_due timestamptz not null,
  times_per_day integer,
  reminders text[] not null default '{}',
  every_days integer,
  weekdays integer[] not null default '{}',
  last_done timestamptz
);

create table if not exists public.care_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  schedule_id uuid references public.care_schedules (id) on delete set null,
  subject_id uuid not null,
  subject_type text not null check (subject_type in ('plant', 'pet')),
  subject_name text not null,
  action text not null,
  due_at timestamptz not null,
  status text not null default 'due' check (status in ('due', 'done', 'skipped')),
  reminded_at timestamptz,
  overdue_sent_at timestamptz
);

create table if not exists public.care_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  task_id uuid,
  subject_id uuid,
  subject_name text not null,
  subject_type text not null default 'plant',
  action text not null,
  completed_at timestamptz not null default now(),
  note text
);

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('web', 'android')),
  created_at timestamptz not null default now()
);

create index if not exists plants_user_idx on public.plants (user_id, created_at);
create index if not exists pets_user_idx on public.pets (user_id, created_at);
create index if not exists schedules_subject_idx on public.care_schedules (user_id, subject_id);
create index if not exists tasks_due_idx on public.care_tasks (user_id, due_at);
create index if not exists history_user_idx on public.care_history (user_id, completed_at desc);

alter table public.profiles enable row level security;
alter table public.pending_profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.plants enable row level security;
alter table public.pets enable row level security;
alter table public.care_schedules enable row level security;
alter table public.care_tasks enable row level security;
alter table public.care_history enable row level security;
alter table public.device_tokens enable row level security;

drop policy if exists profiles_own on public.profiles;
drop policy if exists pending_profiles_own on public.pending_profiles;
drop policy if exists settings_own on public.user_settings;
drop policy if exists plants_own on public.plants;
drop policy if exists pets_own on public.pets;
drop policy if exists schedules_own on public.care_schedules;
drop policy if exists tasks_own on public.care_tasks;
drop policy if exists history_own on public.care_history;
drop policy if exists devices_own on public.device_tokens;

create policy profiles_own on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

create policy pending_profiles_own on public.pending_profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

create policy settings_own on public.user_settings
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy plants_own on public.plants
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy pets_own on public.pets
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy schedules_own on public.care_schedules
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy tasks_own on public.care_tasks
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy history_own on public.care_history
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy devices_own on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  person_name text := coalesce(new.raw_user_meta_data->>'name', '');
  person_email text := coalesce(new.email, '');
  person_avatar text := nullif(new.raw_user_meta_data->>'avatar', '');
begin
  if new.email_confirmed_at is not null then
    insert into public.profiles (id, name, email, avatar_ref)
    values (new.id, person_name, person_email, person_avatar)
    on conflict (id) do nothing;
  else
    insert into public.pending_profiles (id, name, email, avatar_ref)
    values (new.id, person_name, person_email, person_avatar)
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;

create or replace function public.handle_user_confirmed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.email_confirmed_at is null and new.email_confirmed_at is not null then
    insert into public.profiles (id, name, email, avatar_ref)
    select id, name, email, avatar_ref
    from public.pending_profiles
    where id = new.id
    on conflict (id) do nothing;
    insert into public.profiles (id, name, email)
    values (
      new.id,
      coalesce(new.raw_user_meta_data->>'name', ''),
      coalesce(new.email, '')
    )
    on conflict (id) do nothing;
    delete from public.pending_profiles where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

drop trigger if exists on_auth_user_confirmed on auth.users;
create trigger on_auth_user_confirmed
  after update of email_confirmed_at on auth.users
  for each row execute function public.handle_user_confirmed();

insert into storage.buckets (id, name, public)
values ('care-media', 'care-media', false)
on conflict (id) do nothing;

drop policy if exists care_media_read on storage.objects;
drop policy if exists care_media_insert on storage.objects;
drop policy if exists care_media_update on storage.objects;
drop policy if exists care_media_delete on storage.objects;

create policy care_media_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'care-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy care_media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'care-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy care_media_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'care-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy care_media_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'care-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
