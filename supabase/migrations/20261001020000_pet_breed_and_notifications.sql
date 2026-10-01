alter table public.pets add column if not exists breed text not null default '';

alter table public.care_schedules add column if not exists lead text;

create table if not exists public.push_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists push_notifications_user_idx
  on public.push_notifications (user_id, created_at desc);

alter table public.push_notifications enable row level security;

drop policy if exists push_notifications_own on public.push_notifications;
create policy push_notifications_own on public.push_notifications
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
