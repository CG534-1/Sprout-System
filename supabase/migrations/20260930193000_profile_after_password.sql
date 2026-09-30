-- A Sprout profile is created when the person chooses a password.
-- Confirming the email only keeps the pending row.

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
  insert into public.pending_profiles (id, name, email, avatar_ref)
  values (new.id, person_name, person_email, person_avatar)
  on conflict (id) do nothing;
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
    insert into public.pending_profiles (id, name, email, avatar_ref)
    values (
      new.id,
      coalesce(new.raw_user_meta_data->>'name', ''),
      coalesce(new.email, ''),
      nullif(new.raw_user_meta_data->>'avatar', '')
    )
    on conflict (id) do update
      set email = excluded.email,
          name = excluded.name;
  end if;
  return new;
end;
$$;
